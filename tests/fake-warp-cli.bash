#!/usr/bin/env bash
set -euo pipefail

state="${WARP_TEST_STATE:?}"
calls="${WARP_TEST_CALLS:?}"

case "${*}" in
"--json settings")
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
