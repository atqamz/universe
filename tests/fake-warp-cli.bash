#!/usr/bin/env bash
set -euo pipefail

state="${WARP_TEST_STATE:?}"
calls="${WARP_TEST_CALLS:?}"

case "${*}" in
"--json settings")
  if [ -n "${WARP_TEST_SETTINGS_FAILURES_FILE:-}" ]; then
    failures="$(<"$WARP_TEST_SETTINGS_FAILURES_FILE")"
    if [ "$failures" -gt 0 ]; then
      printf '%s' "$((failures - 1))" >"$WARP_TEST_SETTINGS_FAILURES_FILE"
      exit 1
    fi
  fi
  protocol="$(<"$state")"
  printf '{"settings":{"warp_tunnel_protocol":"%s"}}\n' "$protocol"
  ;;
"tunnel protocol set WireGuard")
  printf '%s\n' set >>"$calls"
  if [ "${WARP_TEST_KEEP_MASQUE:-0}" != 1 ]; then
    printf '%s' wireguard >"$state"
  fi
  ;;
*)
  printf 'unexpected warp-cli arguments: %s\n' "${*}" >&2
  exit 2
  ;;
esac
