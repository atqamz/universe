#!/usr/bin/env bash
set -euo pipefail

wrapper_script=${1:?usage: hyprwhspr-toggle.bash SCRIPT}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

[ -f "$wrapper_script" ] || {
  printf '%s\n' "FAIL: wrapper script missing: $wrapper_script" >&2
  exit 1
}

bash_path=$(command -v bash)
bin="$test_root/bin"
mkdir -p "$bin"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

make_fake_hyprwhspr() {
  {
    printf '#!%s\n' "$bash_path"
    cat <<'EOF'
case "$2" in
  status)
    if [ "$(<"$HYPRWHSPR_TEST_STATE")" = recording ]; then
      printf '%s\n' '[INFO] Status: Recording in progress'
    else
      printf '%s\n' '[INFO] Status: Idle'
    fi
    ;;
  toggle)
    if [ "$(<"$HYPRWHSPR_TEST_STATE")" = recording ]; then
      printf '%s\n' idle >"$HYPRWHSPR_TEST_STATE"
    else
      printf '%s\n' recording >"$HYPRWHSPR_TEST_STATE"
    fi
    ;;
  *) exit 2 ;;
esac
EOF
  } >"$bin/hyprwhspr"
  chmod +x "$bin/hyprwhspr"
}

make_fake_notify() {
  {
    printf '#!%s\n' "$bash_path"
    cat <<'EOF'
printf '%s\n' "$*" >>"$HYPRWHSPR_TEST_NOTIFICATIONS"
EOF
  } >"$bin/notify-send"
  chmod +x "$bin/notify-send"
}

run_case() {
  local initial=$1 expected=$2
  printf '%s\n' "$initial" >"$test_root/state"
  : >"$test_root/notifications"
  PATH="$bin:$PATH" \
    HOME="$test_root/home" \
    HYPRWHSPR_TEST_STATE="$test_root/state" \
    HYPRWHSPR_TEST_NOTIFICATIONS="$test_root/notifications" \
    bash "$wrapper_script"
  grep -Fq "$expected" "$test_root/notifications" || fail "notification missing '$expected'"
}

make_fake_hyprwhspr
make_fake_notify
mkdir -p "$test_root/home"
run_case idle "Recording started"
run_case recording "Transcribing..."
printf '%s\n' 'hyprwhspr-toggle test: PASS'
