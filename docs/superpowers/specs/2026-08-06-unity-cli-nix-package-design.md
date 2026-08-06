# Nix-managed Unity CLI

## Goal

Nix manages the Unity Hub and Unity CLI executables. Unity Hub and the CLI continue to manage Unity Editor installations, modules, projects, authentication, and other mutable state in the user's home directory.

The existing `~/.unity/bin` installation and `home.sessionPath` entry are no longer part of the active configuration.

## Package

Add `pkgs/unity-cli/default.nix` and register it in `pkgs/default.nix`.

The package fetches Unity's official versioned standalone Linux binary from the Unity CLI CDN with a fixed hash. It supports the Linux architectures published in Unity's release manifest, patches the ELF interpreter and runtime libraries for NixOS, and makes the binary available as `unity`.

Runtime programs declared by Unity's Linux package, including GnuPG and `unzip`, are placed on the CLI's execution path. The wrapper sets `SSL_CERT_FILE` to the Nix-provided CA bundle by default while preserving an explicit user override.

The package metadata marks the CLI as proprietary, Linux-only, and experimental. Its main program is `unity`.

## Home Manager integration

`modules/home/unity.nix` installs `pkgs.unity-cli` alongside the existing wrapped `unityhub` and `unity-editor` launcher. The current Unity Hub GPU offload, FHS environment, desktop entry, and editor launcher behavior remain unchanged.

Remove `${config.home.homeDirectory}/.unity/bin` from `home.sessionPath`. Existing files under `~/.unity` are not deleted automatically because they can contain CLI state in addition to the obsolete binary. After activation, the Nix profile's `unity` command wins without relying on that directory.

Unity Editors and their modules remain outside the Nix store. Commands such as `unity install`, `unity install-modules`, and Unity Hub may continue writing them under the configured Unity installation directory.

## Updates

The package pins a beta version because Unity currently distributes the experimental CLI through its beta channel. A package-specific update script reads Unity's official `latest-beta.json`, extracts the published version, and invokes `nix-update` so both the version and fixed-output hash are refreshed.

The weekly package workflow uses each package's `passthru.updateScript`. Existing local packages retain their current `nix-update-script` behavior, while Unity CLI can use its manifest-aware updater without a package-name special case in the workflow.

The CLI's own `unity upgrade` command is not the update mechanism for this installation. The Nix store is immutable, and upgrades arrive through the repository's package update and rebuild flow.

## Verification

The implementation is complete when:

- `nix build .#unity-cli` succeeds.
- The built `unity --version` reports the pinned version on NixOS without relying on `programs.nix-ld`.
- `unity --help` succeeds with the Nix package first on `PATH`.
- `unityhub` and `unity-editor` retain their current behavior.
- The manifest-aware updater makes no change when current and refreshes the package when given a newer manifest version.
- `nix fmt` and `nix flake check` pass.

## Non-goals

- Packaging Unity Editor releases in the Nix store.
- Declaratively managing installed Editor versions or modules.
- Deleting Unity CLI state or old binaries from the user's home directory.
- Replacing the existing Unity Hub wrapper or GPU/FHS integration.
