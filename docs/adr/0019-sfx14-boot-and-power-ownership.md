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
Upstream `undervolt-sleep.service` writes the configured fallback RAPL limits from a stop hook on the resume path, exactly like `sleep-actions.service` runs `powerManagement.resumeCommands` from `preStop`, and nothing orders those two hooks against each other.
`undervolt-sleep.service` is therefore ordered `After=sleep-actions.service`, which reverses when both stop, so the upstream fallback write happens first and `sfx14-power restore` writes the selected mode last instead of racing it.

`modules/nixos/network.nix` is shared by every host and every `-minimal` variant, so the Tailscale decisions below are repo-wide even though the boot problem was observed on SFX14.
`tailscaled.service` remains a normal `multi-user.target` service.
`tailscaled-autoconnect.service` and `tailscaled-set.service` have no install target.
`tailscale-bootstrap.timer` is the only installed helper trigger, with `OnBootSec=30s` and `Unit=tailscale-bootstrap.service`, and is wanted by `timers.target`.
The retryable `tailscale-bootstrap.service` starts `tailscaled-autoconnect.service` and waits for it to succeed before starting `tailscaled-set.service`.
`tailscaled-set.service` also requires `tailscaled-autoconnect.service`, in addition to its existing `After=tailscaled.service tailscaled-autoconnect.service` ordering.
The bootstrap service uses systemd `Restart=on-failure` with a 30-second delay and a finite 300-second `TimeoutStartSec`, so an offline boot retries until authentication succeeds and then remains active without periodic polling.
The explicit outer timeout is required because `Type=oneshot` disables the start timeout by default, so a helper wedged on the tailscaled LocalAPI socket would otherwise leave the bootstrap service `activating` forever and `Restart=on-failure` would never fire.
A timed-out start is a failed start, so the hang becomes an observable failure that retries on the same 30-second delay.
`tailscaled-set.service` carries the same finite 300-second `TimeoutStartSec`, because it is the one generated helper that is `Type=oneshot` and therefore had no start bound of its own; `tailscaled-autoconnect.service` is `Type=notify` and is already capped by `DefaultTimeoutStartSec`.
Without that inner bound the outer timeout would terminate only the bootstrap cgroup while the enqueued `tailscaled-set` job kept sitting in `activating`, and every retry would re-attach to the same stuck job instead of re-running the command.
Because only the timer is in the normal boot graph, neither `multi-user.target` nor `graphical.target` waits for the bootstrap service or either helper.
No `DefaultDependencies=no` override or boot-path sleep is used.

The SFX14 systemd-boot timeout is intentionally one second.

## Consequence

Power ownership is deterministic and the recurring timer cannot overwrite runtime modes.
PPD failures remain observable without arbitrary waits.
Tailscale authentication and configuration are triggered after boot, retry on failure, and remain declarative without delaying local desktop availability.
Doctor asserts both that `tailscale-bootstrap.timer` is enabled and that `tailscale-bootstrap.service` is active.
Because the service sets `RemainAfterExit=true`, `active` means the last bootstrap succeeded, so a host stuck on offline authentication, expired credentials, or a wedged helper is a doctor failure instead of a green check with Tailscale SSH down.
The one false alarm is running doctor within the first 30 seconds after boot, before the timer has fired.
Changing `extraSetFlags` therefore takes effect at the next bootstrap run rather than at `nixos-rebuild switch`, and the manual escape hatch is `systemctl restart tailscale-bootstrap.service`, since starting an already-active `RemainAfterExit` oneshot does not re-run it.
`extraUpFlags` are not reapplied by that restart, or by a reboot, because upstream `tailscaled-autoconnect` invokes `tailscale up` only from `NeedsLogin`, `NeedsMachineAuth`, or `Stopped` and exits as soon as the backend reports `Running`.
Changed up flags land when the node next takes the upstream authentication path, and forcing them earlier is an explicit operator action rather than a reimplementation of `tailscale up` inside the bootstrap.
The GPU policy, GameMode integration, resume restoration, UWSM, Hyprland, and Caelestia architecture remain separate invariants.
