# 0008. Unity runs on nix-ld, not an FHS wrapper

## Context

`unityhub` from nixpkgs is wrapped, but Unity's CLI tools are not reachable through that wrapper.
`modules/home/unity.nix` puts `${config.home.homeDirectory}/.unity/bin` on the login PATH, and the tools there exec the editor binary raw - no FHS wrapper anywhere in the chain.
So the editor's own dynamic loading has to succeed on its own, against a NixOS filesystem with no `/usr/lib`.

Two further wrinkles are Unity-specific rather than general packaging:

- Unity's FSBTool shells out to `ffmpeg` to encode AAC audio for WebGL builds, and fails the build with no useful message when it is absent.
- The editor needs the NVIDIA PRIME offload environment to render on the discrete GPU, and so does everything in `modules/nixos/gaming.nix`.

## Decision

Satisfy the editor's unresolved libraries through `programs.nix-ld.libraries` (`modules/nixos/nix-ld.nix`) rather than by wrapping it in an FHS environment.
The library list is the empirically minimal set of the editor's unresolved `ldd` entries - GL, X11, GTK, ICU - not the full FHS superset.

`modules/home/unity.nix` prefixes `ffmpeg` onto PATH for both the hub and the `unity-editor` wrapper it defines.
The PRIME offload env is factored into `lib/prime.nix` and shared with `modules/nixos/gaming.nix` instead of being written twice.

## Consequence

`programs.nix-ld` is load-bearing for Unity, and separately for Zed, which downloads and runs its own prebuilt `node` for the JS language servers.
It is therefore imported from `modules/nixos/default.nix` and not from `minimal.nix` - see ADR 0006.

The library list is empirical, so a Unity upgrade that links something new fails at editor startup with a missing-library error rather than at build time.
The fix is to `ldd` the editor binary and add what is unresolved, not to switch to an FHS wrapper.
