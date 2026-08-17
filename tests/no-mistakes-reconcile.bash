#!/usr/bin/env bash
set -euo pipefail

reconcile_script=${1:?usage: no-mistakes-reconcile.bash SCRIPT}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

real_readlink=$(command -v readlink)
real_mv=$(command -v mv)
bash_path=$(command -v bash)
test_pid=$$

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  local file=$1
  local expected=$2
  grep -Fqx "$expected" "$file" || fail "${file} does not contain ${expected}"
}

assert_file_contains_fragment() {
  local file=$1
  local expected=$2
  grep -Fq "$expected" "$file" || fail "${file} does not contain ${expected}"
}

assert_success() {
  local label=$1
  shift
  "$@" >"$test_root/${label}.stdout" 2>"$test_root/${label}.stderr" || {
    cat "$test_root/${label}.stdout" >&2
    cat "$test_root/${label}.stderr" >&2
    fail "$label unexpectedly failed"
  }
}

assert_failure() {
  local label=$1
  shift
  if "$@" >"$test_root/${label}.stdout" 2>"$test_root/${label}.stderr"; then
    cat "$test_root/${label}.stdout" >&2
    cat "$test_root/${label}.stderr" >&2
    fail "$label unexpectedly succeeded"
  fi
}

new_case() {
  case_root=$(mktemp -d "$test_root/case.XXXXXX")
  mkdir -p \
    "$case_root/bin" \
    "$case_root/home/.agents/skills/no-mistakes" \
    "$case_root/home/.claude/skills/no-mistakes" \
    "$case_root/home/.no-mistakes" \
    "$case_root/home/.config/systemd/user"
  printf '{}\n' >"$case_root/home/.claude/settings.json"
  printf 'generated skill\n' >"$case_root/home/.agents/skills/no-mistakes/SKILL.md"
  cp "$case_root/home/.agents/skills/no-mistakes/SKILL.md" "$case_root/home/.claude/skills/no-mistakes/SKILL.md"
  : >"$case_root/codex-output"
  printf '0\n' >"$case_root/codex-status"
  : >"$case_root/opencode-output"
  printf '0\n' >"$case_root/opencode-status"
  cat >"$case_root/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == app-server ]]; then
  cat "$FAKE_CODEX_OUTPUT_FILE"
  exit "$(cat "$FAKE_CODEX_STATUS_FILE")"
fi
exit 64
EOF
  sed -i "1c#!$bash_path" "$case_root/bin/codex"
  chmod +x "$case_root/bin/codex"
  cat >"$case_root/bin/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == debug && ${2:-} == skill ]]; then
  cat "$FAKE_OPENCODE_OUTPUT_FILE"
  exit "$(cat "$FAKE_OPENCODE_STATUS_FILE")"
fi
exit 64
EOF
  sed -i "1c#!$bash_path" "$case_root/bin/opencode"
  chmod +x "$case_root/bin/opencode"
  : >"$case_root/restarts"
  : >"$case_root/starts"
  printf '0\n' >"$case_root/active-runs"
  : >"$case_root/doctor-output"
  printf '0\n' >"$case_root/doctor-status"
  printf 'old\n' >"$case_root/daemon-executable"
  cat >"$case_root/bin/readlink" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${2:-} == /proc/*/exe ]]; then
  cat "$FAKE_DAEMON_EXECUTABLE_FILE"
else
  exec "$REAL_READLINK" "$@"
fi
EOF
  sed -i "1c#!$bash_path" "$case_root/bin/readlink"
  chmod +x "$case_root/bin/readlink"
  cat >"$case_root/bin/sqlite3" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat "$FAKE_ACTIVE_RUNS_FILE"
EOF
  sed -i "1c#!$bash_path" "$case_root/bin/sqlite3"
  chmod +x "$case_root/bin/sqlite3"
  cat >"$case_root/bin/no-mistakes" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == daemon && ${2:-} == status ]]; then
  if [[ -f "$FAKE_RUNNING_FILE" ]]; then
    printf 'daemon running\n'
  else
    printf 'daemon not running\n'
  fi
  exit 0
fi
if [[ ${1:-} == doctor ]]; then
  cat "$FAKE_DOCTOR_OUTPUT_FILE"
  exit "$(cat "$FAKE_DOCTOR_STATUS_FILE")"
fi
if [[ ${1:-} == daemon && ${2:-} == restart ]]; then
  printf 'restart\n' >>"$FAKE_RESTARTS_FILE"
  if [[ ${FAKE_RESTART_FAILURE:-0} == 1 ]]; then
    exit 1
  fi
  printf '%s\n' "$FAKE_CURRENT_EXECUTABLE" >"$FAKE_DAEMON_EXECUTABLE_FILE"
  touch "$FAKE_RUNNING_FILE"
  printf '{"pid":%s}\n' "$FAKE_TEST_PID" >"$FAKE_NM_HOME/daemon.pid"
  sed -i "s#^ExecStart=.*#ExecStart=$FAKE_CURRENT_EXECUTABLE daemon run --root $FAKE_NM_HOME#" "$FAKE_SERVICE_FILE"
  exit 0
fi
if [[ ${1:-} == daemon && ${2:-} == start ]]; then
  printf 'start\n' >>"$FAKE_STARTS_FILE"
  printf '%s\n' "$FAKE_CURRENT_EXECUTABLE" >"$FAKE_DAEMON_EXECUTABLE_FILE"
  touch "$FAKE_RUNNING_FILE"
  printf '{"pid":%s}\n' "$FAKE_TEST_PID" >"$FAKE_NM_HOME/daemon.pid"
  sed -i "s#^ExecStart=.*#ExecStart=$FAKE_CURRENT_EXECUTABLE daemon run --root $FAKE_NM_HOME#" "$FAKE_SERVICE_FILE"
  exit 0
fi
exit 64
EOF
  sed -i "1c#!$bash_path" "$case_root/bin/no-mistakes"
  chmod +x "$case_root/bin/no-mistakes"
  cat >"$case_root/run" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export HOME=$case_root/home
export XDG_CONFIG_HOME=$case_root/home/.config
export XDG_STATE_HOME=$case_root/home/.local/state
export PATH=$case_root/bin:$case_root/bin:$PATH
export REAL_READLINK=$real_readlink
export FAKE_DAEMON_EXECUTABLE_FILE=$case_root/daemon-executable
export FAKE_TEST_PID=$test_pid
export FAKE_ACTIVE_RUNS_FILE=$case_root/active-runs
export FAKE_DOCTOR_OUTPUT_FILE=$case_root/doctor-output
export FAKE_DOCTOR_STATUS_FILE=$case_root/doctor-status
export FAKE_CODEX_OUTPUT_FILE=$case_root/codex-output
export FAKE_CODEX_STATUS_FILE=$case_root/codex-status
export FAKE_OPENCODE_OUTPUT_FILE=$case_root/opencode-output
export FAKE_OPENCODE_STATUS_FILE=$case_root/opencode-status
export FAKE_OPENCODE_REQUEST_LOG=$case_root/opencode-request.log
export REAL_MV=$real_mv
export FAKE_MV_COUNT_FILE=$case_root/mv-count
export FAKE_REFRESH_PARTIAL_FILE=$case_root/refresh-partial
export FAKE_REFRESH_RELEASE_FIFO=$case_root/refresh-release
export FAKE_OPENCODE_RELEASE_FIFO=$case_root/opencode-release
export FAKE_RESTARTS_FILE=$case_root/restarts
export FAKE_STARTS_FILE=$case_root/starts
export FAKE_RUNNING_FILE=$case_root/running
export FAKE_NM_HOME=$case_root/home/.no-mistakes
export FAKE_CURRENT_EXECUTABLE=$case_root/bin/no-mistakes
export FAKE_SERVICE_FILE=$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service
bash "$reconcile_script" "\$@"
EOF
  sed -i "1c#!$bash_path" "$case_root/run"
  chmod +x "$case_root/run"
}

new_case
printf 'warning rovodev not found\ngate validation  codex is runnable\n' >"$case_root/doctor-output"
assert_success doctor_healthy bash "$case_root/run" doctor

new_case
printf 'gate validation  codex is runnable\nsome checks failed\n' >"$case_root/doctor-output"
assert_failure doctor_soft_failure bash "$case_root/run" doctor
assert_file_contains "$test_root/doctor_soft_failure.stdout" 'some checks failed'

new_case
printf 'gate validation  no configured agents are runnable\n' >"$case_root/doctor-output"
assert_failure doctor_gate_failure bash "$case_root/run" doctor
assert_file_contains "$test_root/doctor_gate_failure.stdout" 'gate validation  no configured agents are runnable'

new_case
printf 'fatal doctor process error\n' >"$case_root/doctor-output"
printf '17\n' >"$case_root/doctor-status"
assert_failure doctor_process_failure bash "$case_root/run" doctor
assert_file_contains "$test_root/doctor_process_failure.stdout" 'fatal doctor process error'

new_case
assert_success claude_discovery_default bash "$case_root/run" discover claude

new_case
printf '{"skillOverrides":{"no-mistakes":"on"}}\n' >"$case_root/home/.claude/settings.json"
assert_success claude_discovery_on bash "$case_root/run" discover claude

new_case
printf '{"skillOverrides":{"no-mistakes":"name-only"}}\n' >"$case_root/home/.claude/settings.json"
assert_success claude_discovery_name_only bash "$case_root/run" discover claude

new_case
printf '{"skillOverrides":{"no-mistakes":"user-invocable-only"}}\n' >"$case_root/home/.claude/settings.json"
assert_success claude_discovery_user_invocable_only bash "$case_root/run" discover claude

new_case
printf '{"skillOverrides":{"no-mistakes":"off"}}\n' >"$case_root/home/.claude/settings.json"
assert_failure claude_discovery_off bash "$case_root/run" discover claude
assert_file_contains_fragment "$test_root/claude_discovery_off.stderr" 'skillOverrides.no-mistakes is off'

new_case
printf '{"skillOverrides":{"no-mistakes":\n' >"$case_root/home/.claude/settings.json"
assert_failure claude_discovery_malformed_settings bash "$case_root/run" discover claude
assert_file_contains_fragment "$test_root/claude_discovery_malformed_settings.stdout" 'parse error'

new_case
printf '{"skillOverrides":{"no-mistakes":"unsupported"}}\n' >"$case_root/home/.claude/settings.json"
assert_failure claude_discovery_invalid_override bash "$case_root/run" discover claude
assert_file_contains_fragment "$test_root/claude_discovery_invalid_override.stdout" 'unsupported skill override'

new_case
printf '{"id":2,"result":{"data":[{"cwd":"/tmp","skills":[{"name":"no-mistakes","path":"%s","scope":"user","enabled":true}],"errors":[]}]}}\n' \
  "$case_root/home/.agents/skills/no-mistakes/SKILL.md" >"$case_root/codex-output"
assert_success codex_discovery bash "$case_root/run" discover codex

new_case
printf '{"id":2,"result":{"data":[{"cwd":"/tmp","skills":[{"name":"other-skill","path":"%s","scope":"user","enabled":true}],"errors":[]}]}}\n' \
  "$case_root/home/.agents/skills/other-skill/SKILL.md" >"$case_root/codex-output"
assert_failure codex_discovery_missing bash "$case_root/run" discover codex
assert_file_contains_fragment "$test_root/codex_discovery_missing.stdout" 'other-skill'

new_case
printf '{"id":2,"result":{"data":[{"cwd":"/tmp","skills":[{"name":"no-mistakes","path":"%s","scope":"repo","enabled":true}],"errors":[]}]}}\n' \
  "$case_root/project/.agents/skills/no-mistakes/SKILL.md" >"$case_root/codex-output"
assert_failure codex_discovery_project_shadow bash "$case_root/run" discover codex
assert_file_contains_fragment "$test_root/codex_discovery_project_shadow.stdout" '"scope":"repo"'

new_case
printf 'codex app-server failed\n' >"$case_root/codex-output"
printf '17\n' >"$case_root/codex-status"
assert_failure codex_discovery_process_failure bash "$case_root/run" discover codex
assert_file_contains "$test_root/codex_discovery_process_failure.stdout" 'codex app-server failed'

new_case
printf '[\n  {"name": "no-mistakes", "location": "%s"},\n  {"name": "no-mistakes", "location": "%s"}\n]\n' \
  "$case_root/home/.agents/skills/no-mistakes/SKILL.md" \
  "$case_root/home/.claude/skills/no-mistakes/SKILL.md" >"$case_root/opencode-output"
assert_success opencode_discovery bash "$case_root/run" discover opencode

new_case
printf '[\n  {"name": "other-skill", "location": "%s"}\n]\n' \
  "$case_root/home/.agents/skills/other-skill/SKILL.md" >"$case_root/opencode-output"
assert_failure opencode_discovery_missing bash "$case_root/run" discover opencode
assert_file_contains_fragment "$test_root/opencode_discovery_missing.stdout" 'other-skill'

new_case
printf '[{"name":"no-mistakes-extra","location":"%s"}]\n' \
  "$case_root/home/.agents/skills/no-mistakes/SKILL.md" >"$case_root/opencode-output"
assert_failure opencode_discovery_similar_name bash "$case_root/run" discover opencode

new_case
printf '[{"name":"no-mistakes","location":"%s"}]\n' \
  "$case_root/home/.agents/skills/wrong-skill/SKILL.md" >"$case_root/opencode-output"
assert_failure opencode_discovery_wrong_location bash "$case_root/run" discover opencode

new_case
printf '[{"name":"no-mistakes-extra","location":"%s"}]\n' \
  "$case_root/home/.agents/skills/wrong-skill/SKILL.md" >"$case_root/opencode-output"
assert_failure opencode_discovery_wrong_name_and_location bash "$case_root/run" discover opencode

new_case
printf '{\n' >"$case_root/opencode-output"
assert_failure opencode_discovery_malformed bash "$case_root/run" discover opencode

new_case
cat >"$case_root/bin/timeout" <<'EOF'
#!/usr/bin/env bash
exit 124
EOF
sed -i "1c#!$bash_path" "$case_root/bin/timeout"
chmod +x "$case_root/bin/timeout"
assert_failure opencode_discovery_timeout bash "$case_root/run" discover opencode
assert_file_contains_fragment "$test_root/opencode_discovery_timeout.stderr" 'command failed'

new_case
printf 'opencode debug skill failed\n' >"$case_root/opencode-output"
printf '17\n' >"$case_root/opencode-status"
assert_failure opencode_discovery_process_failure bash "$case_root/run" discover opencode
assert_file_contains "$test_root/opencode_discovery_process_failure.stdout" 'opencode debug skill failed'

new_case
: >"$case_root/opencode-request.log"
mkfifo "$case_root/opencode-release"
printf '[{"name":"no-mistakes","location":"%s"}]\n' \
  "$case_root/home/.agents/skills/no-mistakes/SKILL.md" >"$case_root/opencode-output"
cat >"$case_root/bin/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == debug && ${2:-} == skill ]]; then
  printf 'request\n' >>"$FAKE_OPENCODE_REQUEST_LOG"
  cat "$FAKE_OPENCODE_RELEASE_FIFO" >/dev/null
  cat "$FAKE_OPENCODE_OUTPUT_FILE"
  exit 0
fi
exit 64
EOF
sed -i "1c#!$bash_path" "$case_root/bin/opencode"
chmod +x "$case_root/bin/opencode"
bash "$case_root/run" discover opencode >"$test_root/opencode_concurrent_first.stdout" 2>"$test_root/opencode_concurrent_first.stderr" &
first_pid=$!
for attempt in $(seq 1 100000); do
  request_count=$(wc -l <"$case_root/opencode-request.log")
  ((request_count >= 1)) && break
  kill -0 "$first_pid" || fail 'first concurrent OpenCode discovery exited before starting'
  ((attempt < 100000)) || fail 'first concurrent OpenCode discovery did not start'
done
((request_count >= 1)) || fail 'first concurrent OpenCode discovery did not start'
bash "$case_root/run" discover opencode >"$test_root/opencode_concurrent_second.stdout" 2>"$test_root/opencode_concurrent_second.stderr" &
second_pid=$!
for attempt in $(seq 1 100000); do
  request_count=$(wc -l <"$case_root/opencode-request.log")
  ((request_count >= 2)) && break
  kill -0 "$second_pid" || fail 'second concurrent OpenCode discovery exited before starting'
  ((attempt < 100000)) || fail 'second concurrent OpenCode discovery did not start'
done
((request_count >= 2)) || fail 'second concurrent OpenCode discovery did not start'
printf 'release\n' >"$case_root/opencode-release"
first_status=0
second_status=0
wait "$first_pid" || first_status=$?
if kill -0 "$second_pid" 2>/dev/null; then
  printf 'release\n' >"$case_root/opencode-release"
fi
wait "$second_pid" || second_status=$?
((first_status == 0)) || fail 'first concurrent OpenCode discovery failed'
if ((second_status != 0)); then
  cat "$test_root/opencode_concurrent_second.stdout" >&2
  cat "$test_root/opencode_concurrent_second.stderr" >&2
  fail 'concurrent OpenCode discovery failed'
fi

new_case
assert_success absent bash "$case_root/run" reconcile

new_case
touch "$case_root/running"
printf '{"pid":%s}\n' "$test_pid" >"$case_root/home/.no-mistakes/daemon.pid"
printf '%s\n' "$case_root/bin/no-mistakes" >"$case_root/daemon-executable"
cat >"$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service" <<EOF
[Service]
WorkingDirectory=$case_root/home/.no-mistakes
ExecStart=$case_root/bin/no-mistakes daemon run --root $case_root/home/.no-mistakes
EOF
export FAKE_SERVICE_FILE="$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service"
assert_success current bash "$case_root/run" reconcile
assert_success current_check bash "$case_root/run" check
[[ ! -s "$case_root/restarts" ]] || fail 'current daemon was restarted'

new_case
touch "$case_root/running"
printf '{"pid":%s}\n' "$test_pid" >"$case_root/home/.no-mistakes/daemon.pid"
cat >"$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service" <<EOF
[Service]
WorkingDirectory=$case_root/home/.no-mistakes
ExecStart=/nix/store/old-no-mistakes/bin/no-mistakes daemon run --root $case_root/home/.no-mistakes
EOF
printf '%s\n' "$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service" >"$case_root/service-path"
export FAKE_SERVICE_FILE="$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service"
printf '1\n' >"$case_root/active-runs"
: >"$case_root/home/.no-mistakes/state.sqlite"
assert_success deferred bash "$case_root/run" reconcile
assert_file_contains "$case_root/home/.local/state/universe/no-mistakes-reconcile" 'deferred=active-run'
assert_failure deferred_check bash "$case_root/run" check
[[ ! -s "$case_root/restarts" ]] || fail 'active daemon was restarted'

new_case
touch "$case_root/running"
printf '{"pid":%s}\n' "$test_pid" >"$case_root/home/.no-mistakes/daemon.pid"
cat >"$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service" <<EOF
[Service]
WorkingDirectory=$case_root/home/.no-mistakes
ExecStart=/nix/store/old-no-mistakes/bin/no-mistakes daemon run --root $case_root/home/.no-mistakes
EOF
export FAKE_SERVICE_FILE="$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service"
assert_success restarted bash "$case_root/run" reconcile
assert_file_contains "$case_root/restarts" restart
assert_file_contains "$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service" "ExecStart=$case_root/bin/no-mistakes daemon run --root $case_root/home/.no-mistakes"

new_case
touch "$case_root/running"
printf '{"pid":%s}\n' "$test_pid" >"$case_root/home/.no-mistakes/daemon.pid"
cat >"$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service" <<EOF
[Service]
WorkingDirectory=$case_root/home/.no-mistakes
ExecStart=/nix/store/old-no-mistakes/bin/no-mistakes daemon run --root $case_root/home/.no-mistakes
EOF
export FAKE_SERVICE_FILE="$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service"
export FAKE_RESTART_FAILURE=1
assert_failure restart_failure bash "$case_root/run" reconcile
unset FAKE_RESTART_FAILURE

new_case
touch "$case_root/running"
printf '{"pid":%s}\n' "$test_pid" >"$case_root/home/.no-mistakes/daemon.pid"
cat >"$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service" <<EOF
[Service]
WorkingDirectory=$case_root/home/.no-mistakes
ExecStart=/nix/store/old-no-mistakes/bin/no-mistakes daemon run --root $case_root/home/.no-mistakes
EOF
export FAKE_SERVICE_FILE="$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service"
printf '1\n' >"$case_root/active-runs"
: >"$case_root/home/.no-mistakes/state.sqlite"
export FAKE_RESTART_FAILURE=1
assert_success race_deferred bash "$case_root/run" reconcile
assert_file_contains "$case_root/home/.local/state/universe/no-mistakes-reconcile" 'deferred=active-run'
unset FAKE_RESTART_FAILURE

new_case
cat >"$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service" <<EOF
[Service]
WorkingDirectory=$case_root/home/.no-mistakes
ExecStart=/nix/store/old-no-mistakes/bin/no-mistakes daemon run --root $case_root/home/.no-mistakes
EOF
export FAKE_SERVICE_FILE="$case_root/home/.config/systemd/user/no-mistakes-daemon-test.service"
assert_success stale_unit bash "$case_root/run" reconcile
assert_file_contains "$case_root/starts" start

new_case
skill_source="$case_root/source/SKILL.md"
mkdir -p "$(dirname "$skill_source")"
printf 'generated skill\n' >"$skill_source"
assert_success skill_refresh bash "$case_root/run" refresh "$skill_source"
assert_file_contains "$case_root/home/.agents/skills/no-mistakes/SKILL.md" 'generated skill'
assert_file_contains "$case_root/home/.claude/skills/no-mistakes/SKILL.md" 'generated skill'

new_case
skill_source="$case_root/source/SKILL.md"
mkdir -p "$(dirname "$skill_source")"
printf 'new generated skill\n' >"$skill_source"
printf 'old generated skill\n' >"$case_root/home/.agents/skills/no-mistakes/SKILL.md"
cp "$case_root/home/.agents/skills/no-mistakes/SKILL.md" "$case_root/home/.claude/skills/no-mistakes/SKILL.md"
: >"$case_root/opencode-request.log"
mkfifo "$case_root/refresh-release" "$case_root/opencode-release"
printf '0\n' >"$case_root/mv-count"
cat >"$case_root/bin/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
"$REAL_MV" "$@"
count=$(cat "$FAKE_MV_COUNT_FILE")
count=$((count + 1))
printf '%s\n' "$count" >"$FAKE_MV_COUNT_FILE"
if ((count == 1)); then
  : >"$FAKE_REFRESH_PARTIAL_FILE"
  cat "$FAKE_REFRESH_RELEASE_FIFO" >/dev/null
fi
EOF
sed -i "1c#!$bash_path" "$case_root/bin/mv"
chmod +x "$case_root/bin/mv"
cat >"$case_root/bin/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == debug && ${2:-} == skill ]]; then
  printf 'request\n' >>"$FAKE_OPENCODE_REQUEST_LOG"
  cat "$FAKE_OPENCODE_RELEASE_FIFO" >/dev/null
  printf '[{"name":"no-mistakes","location":"%s"}]\n' "$HOME/.agents/skills/no-mistakes/SKILL.md"
  exit 0
fi
exit 64
EOF
sed -i "1c#!$bash_path" "$case_root/bin/opencode"
chmod +x "$case_root/bin/opencode"
bash "$case_root/run" refresh "$skill_source" >"$test_root/refresh_concurrent.stdout" 2>"$test_root/refresh_concurrent.stderr" &
refresh_pid=$!
for attempt in $(seq 1 100000); do
  [[ -e $case_root/refresh-partial ]] && break
  kill -0 "$refresh_pid" || fail 'skill refresh exited before exposing its partial fixture state'
  ((attempt < 100000)) || fail 'skill refresh did not reach its partial fixture state'
done
[[ -e $case_root/refresh-partial ]] || fail 'skill refresh did not reach its partial fixture state'
bash "$case_root/run" discover opencode >"$test_root/discover_during_refresh.stdout" 2>"$test_root/discover_during_refresh.stderr" &
discover_pid=$!
request_count=0
for attempt in $(seq 1 100000); do
  request_count=$(wc -l <"$case_root/opencode-request.log")
  ((request_count >= 1)) && break
  kill -0 "$refresh_pid" || fail 'skill refresh exited before concurrent discovery started'
  kill -0 "$discover_pid" || fail 'discovery exited before the refresh completed'
  ((attempt < 100000)) || fail 'discovery did not start during the sequential refresh'
done
((request_count >= 1)) || fail 'discovery did not start during the sequential refresh'
printf 'release\n' >"$case_root/opencode-release"
discover_status=0
wait "$discover_pid" || discover_status=$?
((discover_status == 0)) || fail 'discovery failed during the sequential refresh'
printf 'release\n' >"$case_root/refresh-release"
refresh_status=0
wait "$refresh_pid" || refresh_status=$?
((refresh_status == 0)) || fail 'concurrent skill refresh failed'
assert_file_contains "$case_root/home/.agents/skills/no-mistakes/SKILL.md" 'new generated skill'
assert_file_contains "$case_root/home/.claude/skills/no-mistakes/SKILL.md" 'new generated skill'

printf 'PASS: no-mistakes reconciliation lifecycle\n'
