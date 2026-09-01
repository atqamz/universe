# Architecture decision records

One file per decision that is expensive to rediscover.
Short by design: context, decision, consequence.
`AGENTS.md` states the resulting rules and points here for the reasoning.

| ADR | Decision |
| --- | --- |
| [0001](0001-host-attr-resolution.md) | Never name a host attr when rebuilding a live machine |
| [0002](0002-cross-repo-layout.md) | Repository boundaries follow trust and mutation semantics |
| [0003](0003-live-editable-dotfiles.md) | Dotfiles are out-of-store symlinks, not store copies |
| [0004](0004-per-host-ssh-keys-as-sops-recipients.md) | Per-host SSH keys decrypt system secrets headlessly |
| [0005](0005-cachix-only-substituter.md) | Cachix is the only extra substituter, in CI and on machines |
| [0006](0006-minimal-host-variants.md) | Every host gets a genuinely minimal variant |
| [0007](0007-no-comments-in-nix.md) | Nix files carry no comments; rationale lives here |
| [0008](0008-unity-uses-one-shared-fhs-runtime.md) | Unity uses one shared FHS runtime for every entry point |
| [0009](0009-gpu-benchmarks-fetch-unversioned-urls.md) | OCCT is quarantined in its own module |
| [0010](0010-host-capabilities-not-hostname-flags.md) | Shared modules consume capabilities, not hostname flags |
| [0011](0011-explicit-update-ownership.md) | Every mutable artifact has one update owner |
| [0012](0012-automation-failures-are-observable.md) | Automation distinguishes skips from failures |
| [0013](0013-runner-workloads-are-rootless-and-isolated.md) | Self-hosted runner workloads are rootless and isolated |
| [0015](0015-one-owner-ai-harness-integration.md) | One module owns AI harness integration for all three harnesses |
| [0016](0016-qmd-mcp-search-is-collection-scoped.md) | qmd MCP search must name its collections, so profiles cannot leak into one result set |
| [0017](0017-foot-default-and-wezterm-backup.md) | Foot is the boring default terminal; WezTerm is an isolated graphical backup |
| [0018](0018-treehouse-prune-is-audit-only.md) | The weekly Treehouse prune job is audit-only |
| [0019](0019-sfx14-boot-and-power-ownership.md) | SFX14 power policy and boot helpers have explicit owners |
| [0020](0020-no-mistakes-integration.md) | no-mistakes policy, runtime, and skill ownership is explicit |
| [0021](0021-omanixy-presentation-ownership.md) | Omanixy owns desktop presentation; Universe owns host capabilities and policy |
| [0022](0022-runtime-opencode-model-discovery.md) | OpenCode runtime model discovery is generic and provider-scoped |
| [0023](0023-codedb-generic-stale-index-gc.md) | CodeDB generic stale-index garbage collection owns arbitrary project cleanup |
| [0024](0024-opencode-visibility-probe-isolated-database.md) | OpenCode visibility probes use disposable database state |
| [0025](0025-treehouse-nix-test-compatibility.md) | Latest Treehouse tests remain compatible with the Nix sandbox |
| [0026](0026-warp-wireguard-for-tailscale-derp.md) | WARP uses WireGuard to preserve Tailscale DERP connectivity |
