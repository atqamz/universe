#!/usr/bin/env bash
set -euo pipefail

reconcile_script=${1:?usage: opencode-no-mistakes.bash RECONCILE OPENCODE SKILL}
opencode_bin=${2:?usage: opencode-no-mistakes.bash RECONCILE OPENCODE SKILL}
skill_source=${3:?usage: opencode-no-mistakes.bash RECONCILE OPENCODE SKILL}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_skill() {
  local output=$1
  jq -e \
    --arg agents "$HOME/.agents/skills/no-mistakes/SKILL.md" \
    --arg claude "$HOME/.claude/skills/no-mistakes/SKILL.md" \
    'any(.[]; .name == "no-mistakes" and (.location == $agents or .location == $claude))' \
    "$output" >/dev/null || fail "OpenCode output did not contain the canonical no-mistakes skill: $output"
}

wait_jobs() {
  local label=$1
  shift
  local failed=0
  local pid
  for pid in "$@"; do
    wait "$pid" || failed=1
  done
  if ((failed)); then
    for stderr in "$test_root"/"$label"*.stderr; do
      [[ -e $stderr ]] || continue
      cat "$stderr" >&2
    done
    fail "$label failed"
  fi
}

run_discovery() {
  local output=$1
  bash "$reconcile_script" discover opencode >"$output" 2>"$output.stderr"
}

run_raw_discovery() {
  local output=$1
  OPENCODE_DB=:memory: "$opencode_bin" debug skill --pure >"$output" 2>"$output.stderr"
}

export HOME="$test_root/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$HOME/.agents/skills/no-mistakes" "$HOME/.claude/skills/no-mistakes"
install -m 0644 "$skill_source" "$HOME/.agents/skills/no-mistakes/SKILL.md"
install -m 0644 "$skill_source" "$HOME/.claude/skills/no-mistakes/SKILL.md"

run_discovery "$test_root/serial.stdout"
run_raw_discovery "$test_root/serial-raw.stdout"
assert_skill "$test_root/serial-raw.stdout"

first_output="$test_root/cooperating-first.stdout"
second_output="$test_root/cooperating-second.stdout"
run_discovery "$first_output" &
first_pid=$!
run_discovery "$second_output" &
second_pid=$!
wait_jobs cooperating "$first_pid" "$second_pid"

raw_output="$test_root/raw-overlap.stdout"
probe_output="$test_root/probe-overlap.stdout"
run_raw_discovery "$raw_output" &
raw_pid=$!
run_discovery "$probe_output" &
probe_pid=$!
wait_jobs raw-overlap "$raw_pid" "$probe_pid"
assert_skill "$raw_output"

raw_pids=()
for index in $(seq 1 8); do
  run_raw_discovery "$test_root/raw-$index.stdout" &
  raw_pids+=("$!")
done
wait_jobs raw- "${raw_pids[@]}"
for index in $(seq 1 8); do
  assert_skill "$test_root/raw-$index.stdout"
done

printf 'PASS: pinned OpenCode no-mistakes discovery concurrency\n'
