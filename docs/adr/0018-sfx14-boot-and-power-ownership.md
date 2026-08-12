# 0018. SFX14 power policy and boot helpers have explicit owners

## Context

SFX14's initial RAPL limits, runtime power modes, PPD profile, and CPU EPP were being written by both `services.undervolt` and the custom `sfx14-power` wrapper.
The recurring undervolt timer caused repeated writes and journal wakeups.
The custom default mode also ran before the package-provided PPD unit exposed profiles, producing a 25-second failed boot path.
Tailscale's declarative auth helpers were ordered before `multi-user.target`, so network authentication delayed local desktop availability.

## Decision

`services.undervolt` applies initial RAPL limits once and does not run a recurring timer.
`sfx14-power` owns runtime RAPL, EPP, and PPD mode transitions for the 15 W, 20 W, and 25 W SFX14 modes.
The default mode service is wanted by `graphical.target` and requires the package-provided PPD service after the initial undervolt service.
Tailscale's daemon and auth helpers remain automatic, but the helpers are target wants without target ordering, so authentication does not hold `multi-user.target` or `graphical.target`.
The SFX14 systemd-boot timeout is intentionally one second.

## Consequence

Power ownership is deterministic and the recurring timer cannot overwrite runtime modes.
PPD failures remain observable without arbitrary waits.
Tailscale can authenticate asynchronously while the local desktop remains usable.
The GPU policy, GameMode integration, resume restoration, UWSM, Hyprland, and Caelestia architecture remain separate invariants.
