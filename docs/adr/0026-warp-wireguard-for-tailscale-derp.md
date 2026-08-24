# 0026 - WARP uses WireGuard to preserve Tailscale DERP connectivity

## Context

On `sfx14`, Tailscale SSH from an Android phone was reliable over a direct Wi-Fi path but hung when cellular service forced the peer path through the Singapore DERP relay. WARP remained connected. Disabling WARP immediately restored DERP SSH, and re-enabling WARP with WireGuard instead of the default MASQUE transport preserved both WARP and Tailscale DERP connectivity.

The failure reproduced against the Tailscale IP directly, excluding MagicDNS and the host SSH configuration as causes. Cloudflare defaults WARP to MASQUE, so a reinstall or client-state reset can silently restore the failing combination.

## Decision

Universe pins the Cloudflare WARP tunnel protocol to WireGuard. `modules/nixos/warp.nix` owns an idempotent systemd reconciler that first observes the effective protocol through `warp-cli --json settings`, changes it only when necessary, verifies the result, runs immediately as part of normal system activation and whenever `cloudflare-warp.service` starts, and periodically rechecks the invariant.

Transient daemon or IPC failures get a bounded fast retry budget from systemd: at most six starts inside sixty seconds with five seconds between restart attempts. The periodic five-minute timer remains the long-horizon retry owner after that burst, preventing an unavailable WARP daemon from causing an unbounded restart loop or journal churn.

`universe-doctor` independently reads the effective protocol through the exact Nix-owned `warp-cli` path exported in its generated manifest. Doctor also requires the WARP daemon to be active and the reconciliation timer to be enabled, so the runtime invariant is checked directly rather than inferred from a previously successful oneshot.

Do not work around this by exposing SSH outside Tailscale or weakening the host firewall policy.

## Consequences

- WARP and Tailscale remain enabled simultaneously.
- Tailscale direct paths remain unchanged; DERP remains the fallback when carrier NAT prevents direct connectivity.
- Normal rebuilds and WARP restarts do not reset an already-correct WireGuard tunnel merely to restate the same setting.
- A later client-state or profile change that restores MASQUE is detected immediately by doctor and reconciled automatically by the periodic systemd owner.
- Reconciliation failures remain observable through failed systemd state and `universe-doctor` without an unbounded retry loop.
- Doctor verifies transport configuration, not whether WARP is currently connected; connection state remains outside this PR's policy boundary.
- A network that blocks Cloudflare WireGuard can make WARP unavailable. That failure is preferable to silently falling back to MASQUE and losing remote tailnet access.
- Cloudflare local proxy mode requires MASQUE, so it is intentionally incompatible with this policy and must not be enabled without revisiting this ADR.
- Reconsider MASQUE only after reproducing stable Tailscale DERP connectivity with WARP enabled.
