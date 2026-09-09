# 0013. Self-hosted runner workloads do not control the host container engine

## Context

Mounting a rootful Docker-compatible Podman socket into a GitHub Actions runner gives workflow code the authority of that host container API.
Ephemeral runners reduce assignment persistence but do not make a shared privileged host socket safe.

## Decision

The pavg15 runner fleet is a host-specific feature and lives under `hosts/pavg15/runner.nix`.

Each concurrent runner instance has:

- a distinct system user and subordinate UID/GID range,
- a distinct rootless Podman service and socket,
- a distinct work directory and rootless container state,
- an ephemeral GitHub runner registration that processes one job.

The GitHub App private key stays with the separate `github-runner` authentication user.
That user mints short-lived organization runner registration tokens; runner users can read only the registration-token file, never the App private key or installation token.

The rootful host Docker-compatible socket is disabled.
Light-runner work and rootless container artifacts are removed after each job.

Shared immutable payloads are prepared once on the host and loaded or mounted into each isolated runner.
This includes the runner image archive, an Ubuntu-based Unity runtime image, Unity Editors fetched directly from the CDN, repository mirrors, and the read-only Nix store tools.
The Unity runtime libraries come from Ubuntu because the Editor is linked against Ubuntu's glibc.

Heavy runners retain their home and work state only for trusted repositories that do not accept fork pull requests.
Light runners remain disposable.
Repository mirrors are shared read-only, while tool and Deno caches remain per-runner to avoid concurrent writers corrupting a shared cache.
The Unity Editor mount uses a per-container copy-on-write layer because licensing and the Editor write inside the installation.

Latency-sensitive mirrors, Editors, and warm runner state live on NVMe under `/var/lib/ci`.
The existing HDD mounted at `/var/lib/ci/bulk` holds disposable light-runner state and other seek-tolerant data.
The filesystem is mounted by UUID outside disko so its existing contents survive configuration changes.

GitHub App credentials are passed through process environments and never persisted in repository URLs or command arguments.
Registration and mirror credentials share one token-minting implementation.

## Consequence

A compromised job can control its own runner instance's rootless containers, but not the host root container engine, another runner user's engine, or the long-lived GitHub App private key.
Changing this boundary requires an explicit architecture decision rather than a convenience bind mount.
