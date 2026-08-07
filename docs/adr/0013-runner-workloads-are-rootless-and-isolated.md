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
Runner work and rootless container artifacts are removed after each job.

## Consequence

A compromised job can control its own runner instance's rootless containers, but not the host root container engine, another runner user's engine, or the long-lived GitHub App private key.
Changing this boundary requires an explicit architecture decision rather than a convenience bind mount.
