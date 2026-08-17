#!/usr/bin/env bash
set -euo pipefail

reconcile_script=${1:?usage: opencode-no-mistakes.bash RECONCILE OPENCODE SKILL}
opencode_bin=${2:?usage: opencode-no-mistakes.bash RECONCILE OPENCODE SKILL}
skill_source=${3:?usage: opencode-no-mistakes.bash RECONCILE OPENCODE SKILL}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
opencode_dir=$(dirname "$opencode_bin")
real_flock=$(command -v flock)
real_bash=$(command -v bash)
export PATH="$test_root/bin:$opencode_dir:$PATH"

mkdir -p "$HOME/.agents/skills/no-mistakes" "$HOME/.claude/skills/no-mistakes"
mkdir -p "$test_root/bin"
install -m 0644 "$skill_source" "$HOME/.agents/skills/no-mistakes/SKILL.md"
install -m 0644 "$skill_source" "$HOME/.claude/skills/no-mistakes/SKILL.md"

bash "$reconcile_script" discover opencode

: >"$test_root/flock-requests"
mkfifo "$test_root/release"
printf '0\n' >"$test_root/flock-count"
cat >"$test_root/bin/flock" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'request\n' >>"$OPENCODE_FLOCK_REQUESTS"
count=$(cat "$OPENCODE_FLOCK_COUNT")
count=$((count + 1))
printf '%s\n' "$count" >"$OPENCODE_FLOCK_COUNT"
if ((count == 1)); then
  exec "$REAL_FLOCK" -w 30 "$3" "$REAL_BASH" -c '
    cat "$OPENCODE_RELEASE" >/dev/null
    exec "$@"
  ' bash "${@:4}"
fi
exec "$REAL_FLOCK" "$@"
EOF
sed -i "1c#!$real_bash" "$test_root/bin/flock"
chmod +x "$test_root/bin/flock"
export REAL_FLOCK=$real_flock
export REAL_BASH=$real_bash
export OPENCODE_FLOCK_REQUESTS="$test_root/flock-requests"
export OPENCODE_FLOCK_COUNT="$test_root/flock-count"
export OPENCODE_RELEASE="$test_root/release"
bash "$reconcile_script" discover opencode >"$test_root/concurrent-first.stdout" 2>"$test_root/concurrent-first.stderr" &
first_pid=$!
for attempt in $(seq 1 100000); do
  request_count=$(wc -l <"$test_root/flock-requests")
  ((request_count >= 1)) && break
  kill -0 "$first_pid" || fail 'first pinned OpenCode discovery exited before requesting the lock'
  ((attempt < 100000)) || fail 'first pinned OpenCode discovery did not request the lock'
done
bash "$reconcile_script" discover opencode >"$test_root/concurrent-second.stdout" 2>"$test_root/concurrent-second.stderr" &
second_pid=$!
for attempt in $(seq 1 100000); do
  request_count=$(wc -l <"$test_root/flock-requests")
  ((request_count >= 2)) && break
  kill -0 "$first_pid" || fail 'first pinned OpenCode discovery exited before the second requested the lock'
  kill -0 "$second_pid" || fail 'second pinned OpenCode discovery exited before requesting the lock'
  ((attempt < 100000)) || fail 'second pinned OpenCode discovery did not request the lock'
done
((request_count >= 2)) || fail 'second pinned OpenCode discovery did not request the lock'
printf 'release\n' >"$test_root/release"
first_status=0
second_status=0
wait "$first_pid" || first_status=$?
wait "$second_pid" || second_status=$?
if ((first_status != 0 || second_status != 0)); then
  cat "$test_root/concurrent-first.stdout" >&2
  cat "$test_root/concurrent-first.stderr" >&2
  cat "$test_root/concurrent-second.stdout" >&2
  cat "$test_root/concurrent-second.stderr" >&2
  fail 'concurrent pinned OpenCode discovery failed'
fi

printf 'PASS: pinned OpenCode no-mistakes discovery\n'
