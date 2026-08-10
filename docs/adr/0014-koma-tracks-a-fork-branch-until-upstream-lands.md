# 0014. koma tracks a fork branch until its flake lands upstream

## Context

`koma` is a terminal AI coding agent. Upstream is `aula-id/koma`, which ships release binaries and an `install.sh` but no flake.

The flake that builds it lives on `atqamz/koma` branch `157-nix-flake` and is proposed upstream as `aula-id/koma#159`, closing `aula-id/koma#157`. That pull request is open, so upstream has no flake output to consume yet.

Every other input in `flake.nix` points at a project's own repository, usually at a release tag. This is the only one aimed at a personal fork branch, and `.nix` files here carry no comments (`0007-no-comments-in-nix.md`), so there is nowhere in the code to say that the fork is temporary or what ends it.

The alternatives were worse. Vendoring the derivation into `pkgs/` would fork the packaging logic too, and then upstream landing its own flake would leave a second, silently diverging copy to notice and delete. Installing the upstream `install.sh` payload would put a self-updating binary on the machine, which `0011-explicit-update-ownership.md` rules out.

## Decision

Pin the `koma` input to `github:atqamz/koma/157-nix-flake` and install `packages.${system}.default` from `modules/home/ai-tools.nix`.

When `aula-id/koma#159` merges, change the input URL to upstream and delete this ADR's rule from `AGENTS.md`. Nothing else moves: the upstream flake is the same file, and the attribute path does not change.

Track only `default`, the TUI build. The `gui` package additionally builds a frontend with `npm` inside the sandbox and pulls in `webkitgtk`, which is a much larger closure for a capability nothing here asks for.

## Consequence

A branch is not an immutable reference. `flake.lock` pins the exact revision, so builds stay reproducible, but `nix flake update` follows the branch rather than a tag, and a force-push on the fork changes what that name means.

The fork is under the same owner as this repo, so that is a controlled risk rather than a third-party one. It is still the reason this input deserves a written exit condition instead of being left to look like every other entry in the list.
