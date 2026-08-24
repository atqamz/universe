#!/usr/bin/env bash
set -euo pipefail

reconciler="$1"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

state="$test_root/state"
calls="$test_root/calls"
output="$test_root/output"
export WARP_TEST_STATE="$state"
export WARP_TEST_CALLS="$calls"

: >"$calls"
printf '%s' wireguard >"$state"
"$reconciler"
if [ -s "$calls" ]; then
  echo "already-correct WireGuard state invoked a protocol change" >&2
  exit 1
fi

printf '%s' masque >"$state"
"$reconciler"
grep -Fxq set "$calls"
grep -Fxq wireguard "$state"

printf '%s' masque >"$state"
if WARP_TEST_KEEP_MASQUE=1 "$reconciler" >"$output" 2>&1; then
  echo "failed verification was reported as success" >&2
  exit 1
fi
grep -Fq 'WARP tunnel protocol is not WireGuard after reconciliation' "$output"
