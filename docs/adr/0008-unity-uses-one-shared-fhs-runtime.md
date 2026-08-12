# 0008. Unity uses one shared FHS runtime

## Context

Unity has three user-facing launch paths: `unityhub`, `unity`, and `unity-editor`.

Before this decision, Hub and `unity-editor` entered nixpkgs' Unity FHS environment, while the official CLI launched an installed Editor directly.

The old process trees were:

```text
unityhub -> FHS -> Hub -> Editor
unity-editor -> FHS -> Editor
unity -> official CLI -> raw Editor -> nix-ld
```

The raw Editor could load selected shared libraries through `programs.nix-ld`, but it did not receive the FHS userspace used by Hub.

That made executable subprocesses such as `python3` and `ffmpeg` depend on the launch path.

The official CLI was observed launching `unityhub-unity-editor-*` with `-useHub` and `-hubIPC` arguments.

## Decision

`modules/home/unity.nix` defines `unityBase` from `pkgs.unityhub.override`.

Its `extraPkgs` explicitly owns `ffmpeg`, `python3`, and `shared-mime-info`.

`ffmpeg` is load-bearing: Unity's FSBTool shells out to it to encode AAC audio for WebGL builds, and fails the build with no useful message when it is absent.

`unityBase.fhsEnv` is the canonical runtime boundary for every Unity entry point.

The new process trees are:

```text
unityhub -> unityBase.fhsEnv -> Hub -> Editor
unity -> unityBase.fhsEnv -> official CLI -> Editor helper
unity-editor -> unityBase.fhsEnv -> Editor
```

The `unity` wrapper is workstation integration around `pkgs.unity-cli`.

The `pkgs/unity-cli` package remains responsible for the upstream binary, its CLI dependencies, certificates, and update metadata.

PRIME environment variables are exported by each workstation wrapper before entering the shared runtime.

The offload environment itself stays factored into `lib/prime.nix` and is shared with `modules/nixos/gaming.nix` and `modules/home/benchmarks.nix` instead of being written per consumer.

The upstream `unityhub-fhs-env` executable name is retained because it is an implementation detail of the nixpkgs package.

## nix-ld boundary

The explicit Unity graphics, GTK, ICU, and X11 library list was removed from `modules/nixos/nix-ld.nix`.

The installed Editor starts through the FHS wrapper and the generated FHS rootfs contains the required runtime tools, including `/usr/bin/python3`, `/usr/bin/ffmpeg`, `/usr/bin/git`, and `/usr/bin/clang`.

`programs.nix-ld.enable` remains enabled for other foreign binaries, including Zed's prebuilt language-server runtime.

The nix-ld module stays in the full NixOS composition and is not imported by minimal host variants.

## Consequences

Hub, CLI, and direct Editor launches now share executable and library availability.

Adding a shared Editor subprocess dependency is a change to `unityBase`, not a PATH-only change to one launcher.

The full Unity FHS closure remains a full-host concern and does not enter minimal host variants.

Future Unity or nixpkgs changes must be checked against the shared FHS boundary and the Editor subprocess contract.
