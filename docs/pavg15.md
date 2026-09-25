# pavg15

pavg15 is the only NixOS host managed by Universe.

## Secrets

System secrets under `modules/nixos/secrets` decrypt headlessly from the persistent SSH host key via sops-nix. The personal GPG key remains a recovery/edit recipient. The host key must therefore be restored before rebuilding a replacement server; Vault owns its recovery copy.

## Cache

`atqamz-universe.cachix.org` is the only extra Nix substituter. CI builds the pavg15 toplevel and pushes through the matching Cachix workflow. Do not add a competing GitHub Actions store cache that can make CI green without producing Cachix paths.

## Runner isolation

`hosts/pavg15/runner.nix` owns the self-hosted GitHub runner fleet.

Each runner has its own system user, subordinate IDs, rootless Podman service/socket, work directory, and container state. Workflow jobs do not receive a rootful host container socket. The GitHub App private key stays with the authentication user; runner users receive only short-lived registration material.

Heavy runners may retain trusted warm state. Light runners are disposable. Shared immutable payloads may be reused read-only, while writable tool/container state remains isolated per runner. NVMe under `/var/lib/ci` holds latency-sensitive state; the existing bulk disk holds seek-tolerant disposable state.

Changing the rootless isolation or long-lived credential boundary requires an explicit architecture decision.

## Runner image bumps

GitHub stops sending jobs to a runner version 30 days after the next `actions/runner` release. `hosts/pavg15/runner.nix` pins `myoung34/github-runner` by `imageTag` and `linux/amd64` `imageDigest` and runs it with `DISABLE_AUTO_UPDATE=true`. Self-update cannot replace the pin: the image runs `Runner.Listener run --startuptype service`, so an update exits the listener, `--rm` removes the container, and systemd restarts the old image in a loop.

`.github/workflows/runner-image.yaml` checks daily for a new release and opens or updates one pull request from `bump/runner-image`. It validates the edit with `nix fmt` and `nix flake check` itself, because pull requests made with the workflow token do not trigger `ci.yaml`. It needs "Allow GitHub Actions to create and approve pull requests" enabled in the repository's Actions settings.

Merging does not reach the runners. Auto-upgrade uses `operation = "boot"`, so the new image applies only at the next reboot. To apply it now, wait until no pavg15 runner is busy, because a switch restarts every changed runner unit. Then, on pavg15:

1. Switch in a detached unit, so the switch survives the SSH session dropping:

   ```sh
   sudo systemd-run --unit=universe-switch --collect \
     nixos-rebuild switch --flake git+https://github.com/atqamz/universe#pavg15 --refresh
   journalctl -fu universe-switch
   ```

2. After the switch finishes, re-apply the Tailscale settings. A switch does not re-apply `services.tailscale.extraSetFlags`, and `tailscale-bootstrap.timer` fires only at boot:

   ```sh
   sudo systemctl start tailscale-bootstrap.service
   ```

The first start of each runner loads the new image, which `TimeoutStartSec = "30min"` covers.
