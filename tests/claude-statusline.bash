#!/usr/bin/env bash
set -euo pipefail

usage_script="$1"
statusline_script="$2"
tmp="$(mktemp -d)"
holder_pid=""

cleanup() {
  if [ -n "$holder_pid" ]; then
    kill "$holder_pid" 2>/dev/null || true
    wait "$holder_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp" "/tmp/claude-ctx-test-$$.json"
}

trap cleanup EXIT

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

mkdir -p "$tmp/home/.claude" "$tmp/bin" "$tmp/sync"
printf '%s\n' '{"claudeAiOauth":{"accessToken":"test-token"}}' >"$tmp/home/.claude/.credentials.json"
mkdir -p "$tmp/home/.cache/claude/statusline"
printf '%s\n' legacy-token >"$tmp/home/.cache/claude/statusline/token.cache"

cat >"$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
response=""
headers=""
auth_header=""
case "$*" in
*test-token*)
  exit 1
  ;;
esac
while [ "$#" -gt 0 ]; do
  case "$1" in
  -H)
    if [ "$2" = "@-" ]; then
      IFS= read -r auth_header || true
    fi
    shift 2
    ;;
  -o)
    response="$2"
    shift 2
    ;;
  -D)
    headers="$2"
    shift 2
    ;;
  *) shift ;;
  esac
done
printf '%s\n' "$$" >>"$CALL_LOG"
printf '%s\n' "$auth_header" >"$HEADER_LOG"
printf '%s\n' '{"five_hour":{"utilization":12.5,"resets_at":"2999-01-01T00:00:00Z"},"seven_day":{"utilization":34.5,"resets_at":"2999-01-07T00:00:00Z"},"extra_usage":{"is_enabled":true,"monthly_limit":100,"used_credits":20,"utilization":20}}' >"$response"
: >"$headers"
printf '200'
EOF
sed -i "1c #!$(command -v bash)" "$tmp/bin/curl"
chmod +x "$tmp/bin/curl"

export HOME="$tmp/home"
export PATH="$tmp/bin:$PATH"
export CALL_LOG="$tmp/calls"
export HEADER_LOG="$tmp/header"

printf '%s\n' '{"sessionUsage":1,"sessionResetAt":"2999-01-01T00:00:00Z","weeklyUsage":2}' >"$HOME/.cache/claude/statusline/usage.json"
bash "$usage_script" >/dev/null
[ ! -e "$HOME/.cache/claude/statusline/token.cache" ] || fail "cached usage left the legacy OAuth token on disk"
rm -f "$HOME/.cache/claude/statusline/usage.json"

output="$(bash "$usage_script")"
jq -e '. == {sessionUsage: 12.5, sessionResetAt: "2999-01-01T00:00:00Z", weeklyUsage: 34.5}' <<<"$output" >/dev/null ||
  fail "fetch-usage returned fields the statusline does not consume"
[ "$(cat "$HEADER_LOG")" = "Authorization: Bearer test-token" ] || fail "fetch-usage did not send the OAuth token through stdin"
[ ! -e "$HOME/.cache/claude/statusline/token.cache" ] || fail "fetch-usage persisted the OAuth token"

rm -f "$HOME/.cache/claude/statusline/usage.json" "$HOME/.cache/claude/statusline/usage.lock" "$CALL_LOG"
workers=8
export workers usage_script
for _ in $(seq 1 "$workers"); do
  bash -c '
    source "$usage_script"
    get_usage_token() {
      : >"$HOME/../sync/$$"
      while [ "$(find "$HOME/../sync" -type f | wc -l)" -lt "$workers" ]; do
        sleep 0.01
      done
      printf "%s\n" test-token
    }
    fetch_usage_data >/dev/null || true
  ' &
done
wait
[ "$(wc -l <"$CALL_LOG")" -eq 1 ] || fail "concurrent refreshes issued more than one API request"

rm -f "$HOME/.cache/claude/statusline/usage.json" "$HOME/.cache/claude/statusline/usage.lock" "$CALL_LOG"
lock_file="$HOME/.cache/claude/statusline/refresh.flock"
(
  exec 9>"$lock_file"
  flock 9
  touch -d @1 "$lock_file"
  : >"$tmp/lock-held"
  while [ ! -e "$tmp/release-lock" ]; do
    sleep 0.01
  done
) &
holder_pid=$!
while [ ! -e "$tmp/lock-held" ]; do
  sleep 0.01
done
bash "$usage_script" >/dev/null 2>&1 || true
[ ! -e "$CALL_LOG" ] || fail "refresh ignored an old lock held by another process"
touch "$tmp/release-lock"
wait "$holder_pid"
holder_pid=""

session="test-$$"
printf '%s\n' '{"model":{"display_name":"Sonnet","id":"claude-sonnet-4"},"cwd":"/tmp","session_id":"'"$session"'","context_window":{"context_window_size":200000,"remaining_percentage":90,"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"effort":{"level":"high"},"thinking":{"enabled":true},"fast_mode":false}' |
  bash "$statusline_script" >/dev/null
[ ! -e "/tmp/claude-ctx-$session.json" ] || fail "statusline wrote the retired context bridge"
