# 0014. koma comes from its upstream flake

## Context

`koma` is a terminal AI coding agent.
Upstream is `aula-id/koma`, which ships release binaries and an `install.sh`.

It had no flake when Universe first installed it, so the input pointed at the fork branch `github:atqamz/koma/157-nix-flake` while `aula-id/koma#159` was open.
That pull request merged into upstream `main` on 2026-08-10, so the fork is no longer needed and the input names upstream directly.

Installing the upstream `install.sh` payload was never an option: it puts a self-updating binary on the machine, which `0011-explicit-update-ownership.md` rules out.
Vendoring the derivation into `pkgs/` was rejected for the same reason it is usually rejected, that it forks packaging logic upstream already maintains.

## Decision

Take `koma` from `github:aula-id/koma` and install `packages.${system}.default` from `modules/home/ai-tools.nix`.

Track only `default`, the TUI build.
The `gui` package additionally builds a frontend with `npm` inside the sandbox and pulls in `webkitgtk`, which is a much larger closure for a capability nothing here asks for.

## Consequence

The input tracks upstream's default branch, like most inputs here, so `flake.lock` is what pins the exact revision and the weekly Dependabot `nix` update is what moves it.

The binary keeps its own self-update path: a `koma update` command, the `https://koma.run/install.sh` route, a version check against `https://koma.run/api/v1/version`, and an update nag.
It exposes no opt-out environment variable, unlike opencode's `OPENCODE_DISABLE_AUTOUPDATE`.
Running `koma update` would install an unmanaged copy outside Nix ownership and violate `0011-explicit-update-ownership.md`, so the rule is not to run it.
Update koma by bumping the flake input.
