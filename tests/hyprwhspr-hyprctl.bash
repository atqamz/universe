#!/usr/bin/env bash
set -euo pipefail

hyprctl_shim=${1:?usage: hyprwhspr-hyprctl.bash SHIM LIBRARY_PATH}
library_path=${2:?usage: hyprwhspr-hyprctl.bash SHIM LIBRARY_PATH}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -x "$hyprctl_shim" ] || fail "hyprctl shim is not executable: $hyprctl_shim"

status=0
output="$(
  HYPRLAND_INSTANCE_SIGNATURE=missing \
    LD_LIBRARY_PATH="$library_path" \
    "$hyprctl_shim" version 2>&1
)" || status=$?

case "$output" in
*GLIBCXX* | *"error while loading shared libraries"*)
  fail 'hyprctl inherited an incompatible LD_LIBRARY_PATH'
  ;;
esac

printf '%s\n' "hyprwhspr-hyprctl test: PASS (exit $status)"
