#!/usr/bin/env bash
set -euo pipefail

reconcile_script=${1:?usage: no-mistakes-reconcile.bash SCRIPT}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

real_readlink=$(command -v readlink)
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
  mkdir -p "$case_root/bin" "$case_root/home/.no-mistakes" "$case_root/home/.config/systemd/user"
  : >"$case_root/restarts"
  : >"$case_root/starts"
  printf '0\n' >"$case_root/active-runs"
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

printf 'PASS: no-mistakes reconciliation lifecycle\n'
