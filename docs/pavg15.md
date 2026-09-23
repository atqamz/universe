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
