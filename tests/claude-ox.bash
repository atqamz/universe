#!/usr/bin/env bash
set -euo pipefail

wrapper_script=${1:?usage: claude-ox.bash SCRIPT}
bash_path=$(command -v bash)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
secret_value=sk-or-test-value

bin=$test_root/bin
home=$test_root/home
store=$home/.password-store
entry_file=$store/openrouter/api-key.gpg
mkdir -p "$bin" "$store/openrouter" "$test_root/nothing"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

make_fake_pass() {
  {
    printf '#!%s\n' "$bash_path"
    cat <<'EOF'
if [ -n "${PASS_FAKE_LOG:-}" ]; then
  printf 'invoked\n' >>"$PASS_FAKE_LOG"
fi
if [ -n "${PASS_FAKE_FAIL:-}" ]; then
  echo "error: decryption failed" >&2
  exit 1
fi
printf '%s' "$PASS_FAKE_SECRET"
EOF
  } >"$bin/pass"
  chmod +x "$bin/pass"
}

make_fake_claude() {
  {
    printf '#!%s\n' "$bash_path"
    cat <<'EOF'
for arg in "$@"; do
  printf 'arg:%s\n' "$arg" >>"$CLAUDE_FAKE_ARGS"
done
for name in ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY \
  ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL \
  ANTHROPIC_DEFAULT_HAIKU_MODEL CLAUDE_CODE_SUBAGENT_MODEL \
  CLAUDE_CODE_MAX_CONTEXT_TOKENS; do
  printf '%s=%s\n' "$name" "${!name-}" >>"$CLAUDE_FAKE_ENV"
done
EOF
  } >"$bin/claude"
  chmod +x "$bin/claude"
}

run_wrapper() {
  run_status=0
  rm -f "$CLAUDE_FAKE_ARGS" "$CLAUDE_FAKE_ENV"
  PATH="$bin:$PATH" HOME="$home" "$bash_path" "$wrapper_script" "$@" \
    >"$test_root/out.stdout" 2>"$test_root/out.stderr" || run_status=$?
}

assert_failure() {
  [ "$run_status" -ne 0 ] || fail "wrapper succeeded but should have failed: $1"
}

assert_claude_not_invoked() {
  [ ! -e "$CLAUDE_FAKE_ARGS" ] || fail "claude was invoked in a failure case"
}

assert_failure_message() {
  grep -Fq "$1" "$test_root/out.stderr" || fail "stderr is missing '$1'"
}

assert_no_secret_in_output() {
  if grep -Fq "$secret_value" "$test_root/out.stdout" "$test_root/out.stderr"; then
    fail "the secret leaked into wrapper output"
  fi
}

export PASS_FAKE_SECRET=$secret_value$'\nmetadata: ignored'
export CLAUDE_FAKE_ARGS=$test_root/claude.args
export CLAUDE_FAKE_ENV=$test_root/claude.env
export PASS_FAKE_LOG=$test_root/pass.log
make_fake_pass
make_fake_claude

printf '%s\n' \
  "ANTHROPIC_BASE_URL=https://openrouter.ai/api" \
  "ANTHROPIC_AUTH_TOKEN=$secret_value" \
  "ANTHROPIC_API_KEY=" \
  "ANTHROPIC_DEFAULT_OPUS_MODEL=stealth/ox-alpha" \
  "ANTHROPIC_DEFAULT_SONNET_MODEL=stealth/ox-alpha" \
  "ANTHROPIC_DEFAULT_HAIKU_MODEL=stealth/ox-alpha" \
  "CLAUDE_CODE_SUBAGENT_MODEL=stealth/ox-alpha" \
  "CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000" >"$test_root/expected.env"

user_args=("some dir/" "-p" 'prompt with "quotes" and spaces' --dangerously-skip-permissions "")
printf 'encrypted' >"$entry_file"
{
  printf '%s\n' "arg:--model" "arg:stealth/ox-alpha"
  printf 'arg:%s\n' "${user_args[@]}"
} >"$test_root/expected.args"

run_status=0
rm -f "$CLAUDE_FAKE_ARGS" "$CLAUDE_FAKE_ENV"
env \
  ANTHROPIC_BASE_URL=https://api.anthropic.com \
  ANTHROPIC_AUTH_TOKEN=wrong \
  ANTHROPIC_API_KEY=anthropic-secret \
  ANTHROPIC_DEFAULT_SONNET_MODEL=some-other-model \
  PATH="$bin:$PATH" HOME="$home" \
  "$bash_path" "$wrapper_script" "${user_args[@]}" \
  >"$test_root/out.stdout" 2>"$test_root/out.stderr" || run_status=$?
[ "$run_status" -eq 0 ] || {
  cat "$test_root/out.stderr" >&2
  fail "wrapper failed despite a valid secret"
}
cmp "$test_root/expected.args" "$CLAUDE_FAKE_ARGS" || fail "argv was not forwarded exactly"
cmp "$test_root/expected.env" "$CLAUDE_FAKE_ENV" || fail "routing environment did not override ambient values"
assert_no_secret_in_output

export PASS_FAKE_FAIL=1
run_wrapper
unset PASS_FAKE_FAIL
assert_failure "pass reported a decryption failure"
assert_claude_not_invoked
assert_failure_message "failed to read pass entry 'openrouter/api-key'"
assert_no_secret_in_output

for empty_secret in "" $'\nmetadata: ignored'; do
  export PASS_FAKE_SECRET=$empty_secret
  run_wrapper
  assert_failure "pass returned an empty key"
  assert_claude_not_invoked
  assert_failure_message "has an empty first line"
done

export PASS_FAKE_SECRET=$secret_value
run_wrapper --version
[ "$run_status" -eq 0 ] || fail "wrapper failed although the entry file exists"

rm -f "$entry_file" "$PASS_FAKE_LOG"
run_wrapper
assert_failure "the pass entry file is missing"
assert_claude_not_invoked
assert_failure_message "pass insert openrouter/api-key"
[ ! -e "$PASS_FAKE_LOG" ] || fail "pass was invoked even though the entry file is missing"

run_status=0
rm -f "$CLAUDE_FAKE_ARGS"
PATH="$test_root/nothing" HOME="$home" "$bash_path" "$wrapper_script" \
  >"$test_root/out.stdout" 2>"$test_root/out.stderr" || run_status=$?
assert_failure "pass is unavailable"
assert_claude_not_invoked
assert_failure_message "pass is not available"

if grep -qF "$secret_value" "$test_root"/out.stdout "$test_root"/out.stderr; then
  fail "the secret appeared somewhere in wrapper output"
fi
printf 'PASS: claude-ox wrapper contract\n'
