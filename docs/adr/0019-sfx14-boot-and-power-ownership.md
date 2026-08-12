# 0019. SFX14 power policy and boot helpers have explicit owners

## Context

SFX14's initial RAPL limits, runtime power modes, PPD profile, and CPU EPP were being written by both `services.undervolt` and the custom `sfx14-power` wrapper.
The recurring undervolt timer caused repeated writes and journal wakeups.
The custom default mode also ran before the package-provided PPD unit exposed profiles, producing a 25-second failed boot path.
Tailscale's declarative auth helpers were wanted by `multi-user.target`, and the target's automatic ordering made authentication part of the boot critical path.

## Decision

`services.undervolt` applies initial RAPL limits once and does not run a recurring timer.
`sfx14-power` owns runtime RAPL, EPP, and PPD mode transitions for the 15 W, 20 W, and 25 W SFX14 modes.
The default mode service is wanted by `graphical.target` and requires the package-provided PPD service after the initial undervolt service.

`tailscaled.service` remains a normal `multi-user.target` service.
`tailscaled-autoconnect.service` and `tailscaled-set.service` have no install target.
`tailscale-bootstrap.timer` is the only installed helper trigger, with `OnBootSec=30s` and `Unit=tailscale-bootstrap.target`, and is wanted by `timers.target`.
The private `tailscale-bootstrap.target` wants both helper services.
The existing `After=tailscaled.service tailscaled-autoconnect.service` on `tailscaled-set.service` keeps configuration after authentication.
Because only the timer is in the normal boot graph, neither `multi-user.target` nor `graphical.target` waits for either helper.
No `DefaultDependencies=no` override or boot-path sleep is used.

The SFX14 systemd-boot timeout is intentionally one second.

## Consequence

Power ownership is deterministic and the recurring timer cannot overwrite runtime modes.
PPD failures remain observable without arbitrary waits.
Tailscale authentication and configuration are triggered after boot and remain declarative without delaying local desktop availability.
The timer is doctor-visible as an enabled system timer.
The GPU policy, GameMode integration, resume restoration, UWSM, Hyprland, and Caelestia architecture remain separate invariants.
