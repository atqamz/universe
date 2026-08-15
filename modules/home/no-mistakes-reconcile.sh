#!/usr/bin/env bash
set -euo pipefail

action=${1:-reconcile}
nm_home=${NM_HOME:-$HOME/.no-mistakes}
unit_dir=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
marker_file=${XDG_STATE_HOME:-$HOME/.local/state}/universe/no-mistakes-reconcile
state_db=$nm_home/state.sqlite
skill_name=no-mistakes
agents_skill="$HOME/.agents/skills/$skill_name/SKILL.md"
claude_skill="$HOME/.claude/skills/$skill_name/SKILL.md"

die() {
  printf 'no-mistakes reconciliation failed: %s\n' "$1" >&2
  exit 1
}

current_executable() {
  local command_path
  command_path=$(command -v no-mistakes) || die 'no-mistakes is not on PATH'
  readlink -f "$command_path"
}

find_managed_service() {
  managed_service=
  managed_service_executable=
  local unit exec_line
  shopt -s nullglob
  for unit in "$unit_dir"/no-mistakes-daemon-*.service; do
    [[ -f $unit ]] || continue
    exec_line=$(sed -n 's/^ExecStart=//p' "$unit" | head -n 1)
    [[ $exec_line == *" daemon run --root $nm_home" ]] || continue
    managed_service=$unit
    managed_service_executable=${exec_line%% daemon run --root *}
    break
  done
  shopt -u nullglob
}

daemon_status() {
  local output
  output=$(no-mistakes daemon status 2>&1) || die "daemon status failed: $output"
  [[ $output == *'daemon running'* ]]
}

daemon_executable() {
  local pid
  [[ -r $nm_home/daemon.pid ]] || die 'daemon status reports running without daemon.pid'
  pid=$(jq -er '.pid | numbers' "$nm_home/daemon.pid") || die 'daemon.pid does not contain a numeric pid'
  [[ $pid -gt 0 ]] || die 'daemon.pid contains an invalid pid'
  [[ -e /proc/$pid/exe ]] || die "daemon pid $pid does not exist"
  readlink -f "/proc/$pid/exe"
}

active_runs() {
  [[ -e $state_db ]] || {
    printf '0\n'
    return
  }
  local count
  count=$(sqlite3 -readonly -batch -noheader "$state_db" "SELECT count(*) FROM runs WHERE status IN ('pending', 'running');") || die 'could not query active no-mistakes runs'
  count=${count//$'\n'/}
  [[ $count =~ ^[0-9]+$ ]] || die "active-run query returned invalid count: $count"
  printf '%s\n' "$count"
}

doctor() {
  local output_file gate_line gate_agent line
  output_file=$(mktemp)
  if ! NO_COLOR=1 TERM=dumb no-mistakes doctor >"$output_file" 2>&1; then
    cat "$output_file"
    rm -f "$output_file"
    die 'no-mistakes doctor process failed'
  fi
  if grep -Fq 'some checks failed' "$output_file"; then
    cat "$output_file"
    rm -f "$output_file"
    die 'no-mistakes doctor reported failed checks'
  fi
  gate_line=
  while IFS= read -r line; do
    if [[ $line == *'gate validation'* && $line == *'is runnable'* ]]; then
      gate_line=$line
      break
    fi
  done <"$output_file"
  if [[ -z $gate_line ]]; then
    cat "$output_file"
    rm -f "$output_file"
    die 'no-mistakes doctor did not report a runnable gate agent'
  fi
  gate_agent=${gate_line#*gate validation}
  gate_agent=${gate_agent%% is runnable*}
  gate_agent=$(printf '%s' "$gate_agent" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [[ -z $gate_agent ]] || ! command -v "$gate_agent" >/dev/null 2>&1; then
    cat "$output_file"
    rm -f "$output_file"
    die "no-mistakes doctor reported an unavailable gate agent: $gate_agent"
  fi
  rm -f "$output_file"
}

discovery_failure() {
  local output=$1
  local message=$2
  printf '%s\n' "${output:0:12000}"
  die "$message"
}

discover_claude() {
  local output
  if [[ ! -f $claude_skill ]]; then
    die "Claude skill discovery contract is missing $claude_skill"
  fi
  if ! output=$(cd /tmp && timeout 10 claude plugin init --help 2>&1); then
    discovery_failure "$output" 'Claude skill discovery contract command failed: claude plugin init --help'
  fi
  if ! printf '%s\n' "$output" | grep -Fq 'Scaffold a new plugin at ~/.claude/skills/<name>/' ||
    ! printf '%s\n' "$output" | grep -Fq 'auto-loads next session'; then
    discovery_failure "$output" 'Claude skill discovery contract does not advertise ~/.claude/skills/<name>/ as an auto-loaded root'
  fi
}

discover_codex() {
  local output
  if [[ ! -f $agents_skill ]]; then
    die "Codex skill discovery is missing $agents_skill"
  fi
  if ! output=$(
    {
      printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"universe-doctor","version":"1"},"capabilities":{}}}'
      printf '%s\n' '{"jsonrpc":"2.0","method":"initialized","params":{}}'
      printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"skills/list","params":{"cwds":["/tmp"],"forceReload":true}}'
      sleep 2
    } | (cd /tmp && timeout 10 codex app-server --listen stdio:// 2>&1)
  ); then
    discovery_failure "$output" 'Codex skill discovery command failed: codex app-server skills/list'
  fi
  if ! printf '%s\n' "$output" | jq -e -s --arg path "$agents_skill" '
    any(.[];
      .id == 2
      and any((.result.data // [])[];
        any((.skills // [])[];
          .name == "no-mistakes"
          and .path == $path
          and .scope == "user"
          and .enabled == true
        )
      )
    )
  ' >/dev/null; then
    discovery_failure "$output" "Codex did not enumerate the user skill no-mistakes from $agents_skill"
  fi
}

discover_opencode() {
  local output
  if [[ ! -f $agents_skill && ! -f $claude_skill ]]; then
    die "OpenCode skill discovery has no expected no-mistakes skill root"
  fi
  if ! output=$(cd /tmp && timeout 10 opencode debug skill --pure 2>&1); then
    discovery_failure "$output" 'OpenCode skill discovery command failed: opencode debug skill --pure'
  fi
  if ! printf '%s\n' "$output" | awk \
    -v expected_name="$skill_name" \
    -v agents_path="$agents_skill" \
    -v claude_path="$claude_skill" '
      /"name"[[:space:]]*:/ {
        name = $0
        sub(/^.*"name"[[:space:]]*:[[:space:]]*"/, "", name)
        sub(/".*$/, "", name)
      }
      /"location"[[:space:]]*:/ {
        location = $0
        sub(/^.*"location"[[:space:]]*:[[:space:]]*"/, "", location)
        sub(/".*$/, "", location)
        if (name == expected_name && (location == agents_path || location == claude_path)) {
          found = 1
        }
      }
      END { exit found ? 0 : 1 }
    '; then
    discovery_failure "$output" "OpenCode did not enumerate the user skill no-mistakes from $agents_skill or $claude_skill"
  fi
}

discover() {
  local harness=${2:?usage: no-mistakes-reconcile discover HARNESS}
  case $harness in
  claude)
    discover_claude
    ;;
  codex)
    discover_codex
    ;;
  opencode)
    discover_opencode
    ;;
  *)
    die "unknown discovery harness: $harness"
    ;;
  esac
}

write_deferred_marker() {
  local current=$1
  local daemon=$2
  local service=$3
  local runs=$4
  local marker_dir tmp
  marker_dir=$(dirname "$marker_file")
  mkdir -p "$marker_dir"
  tmp=$(mktemp "$marker_file.tmp.XXXXXX")
  printf 'deferred=active-run\ncurrent=%s\ndaemon=%s\nservice=%s\nactive_runs=%s\n' "$current" "$daemon" "$service" "$runs" >"$tmp"
  mv "$tmp" "$marker_file"
}

clear_marker() {
  rm -f "$marker_file"
}

observe() {
  current=$(current_executable)
  find_managed_service
  daemon_running=0
  daemon=
  if daemon_status; then
    daemon_running=1
    daemon=$(daemon_executable)
  fi
  stale=0
  if ((daemon_running)) && [[ $daemon != "$current" ]]; then
    stale=1
  fi
  if [[ -n $managed_service ]] && [[ $managed_service_executable != "$current" ]]; then
    stale=1
  fi
}

verify_reconciled() {
  local current=$1
  find_managed_service
  [[ -n $managed_service ]] || die 'daemon repair did not install a managed service'
  [[ $managed_service_executable == "$current" ]] || die "managed service still points to $managed_service_executable"
  daemon_status || die 'daemon repair did not leave the daemon running'
  [[ $(daemon_executable) == "$current" ]] || die 'daemon repair left a stale daemon executable'
}

reconcile() {
  observe
  if ((!stale)); then
    clear_marker
    if ((daemon_running)); then
      printf 'no-mistakes daemon is current\n'
    else
      printf 'no-mistakes daemon is not running; no stale managed service found\n'
    fi
    return
  fi

  local runs
  runs=$(active_runs)
  if ((runs > 0)); then
    write_deferred_marker "$current" "$daemon" "$managed_service_executable" "$runs"
    printf 'no-mistakes daemon replacement deferred for %s active run(s)\n' "$runs"
    return
  fi

  if ((daemon_running)); then
    if ! no-mistakes daemon restart; then
      runs=$(active_runs)
      if ((runs > 0)); then
        write_deferred_marker "$current" "$daemon" "$managed_service_executable" "$runs"
        printf 'no-mistakes daemon replacement deferred for %s active run(s)\n' "$runs"
        return
      fi
      die 'supported daemon restart failed'
    fi
  else
    no-mistakes daemon start || die 'supported daemon start failed'
  fi
  verify_reconciled "$current"
  clear_marker
  printf 'no-mistakes daemon reconciled to %s\n' "$current"
}

check() {
  observe
  if ((!stale)); then
    [[ ! -e $marker_file ]] || die 'deferred reconciliation marker remains after the daemon became current'
    printf 'no-mistakes daemon identity is current or not installed\n'
    return
  fi
  local runs
  runs=$(active_runs)
  if ((runs > 0)); then
    die "daemon replacement is deferred for $runs active run(s)"
  fi
  die 'daemon executable or managed service is stale'
}

refresh_skill() {
  local source=$2
  [[ -f $source ]] || die "skill source does not exist: $source"
  local base destination
  for base in .agents/skills .claude/skills; do
    destination=$HOME/$base/no-mistakes/SKILL.md
    mkdir -p "$(dirname "$destination")"
    install -m 0644 "$source" "$destination"
  done
}

case $action in
doctor)
  doctor
  ;;
discover)
  discover "$@"
  ;;
check)
  check
  ;;
reconcile)
  reconcile
  ;;
refresh)
  refresh_skill "$@"
  ;;
*)
  die "unknown action: $action"
  ;;
esac
