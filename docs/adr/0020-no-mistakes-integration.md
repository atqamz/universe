# No-mistakes has explicit policy, runtime, and skill owners

## Context

Universe installed no-mistakes v1.51.1, but its effective routing depended on upstream `agent: auto` discovery order.
The interactive Claude model and interactive Codex configuration also leaked into gate workers.
Nix upgrades could leave the user daemon and systemd user unit pointing at an old store executable.
The generated no-mistakes skill had no explicit refresh owner outside `no-mistakes init`.

## Decision

`dotagents/no-mistakes/config.yaml` owns the live-editable global policy.
It selects Codex first and Claude second, and carries no-mistakes-only Codex model/reasoning and Claude model overrides.
Interactive Claude settings, interactive Codex settings, and OpenCode configuration remain owned by their existing integrations.

`modules/home/no-mistakes.nix` is the single Universe owner for the package installation, global config link, daemon reconciliation timer, skill refresh, and doctor contract.
The package exposes the deterministic generated skill from the pinned source.
Universe refreshes that file into `.agents/skills/no-mistakes` and `.claude/skills/no-mistakes` without adding it to the general skills ledger.

The reconciliation command compares the current Nix executable, the running daemon executable, and the managed service `ExecStart`.
It queries the no-mistakes SQLite state database read-only for `pending` and `running` rows.
It returns success and records a state marker when active runs defer replacement.
When no run is active, it uses the upstream `daemon restart` or `daemon start` command and verifies the process and service paths afterward.
It never kills an arbitrary PID and never requires an old store path after successful repair.

Repository `.no-mistakes.yaml` remains policy from the trusted default branch.
Universe commits an explicit Codex-to-Claude route for reproducibility.
dotagents has no repository-local route because it has no distinct routing requirement.

## Consequences

Fallback is intentional but not instantaneous.
Upstream retries transient failures within the selected native agent before trying the next configured agent, and only startup or process-exit failures trigger cross-agent fallback.
Malformed structured findings do not trigger fallback.

The v1.51.1 configuration model supports per-agent argument overrides but not separate models for review, test, documentation, lint, CI, and fixer steps.
No downstream scheduler or upstream fork is introduced for that unsupported capability.

An active validation run can leave the daemon stale across a rebuild until the bounded user timer retries.
The marker makes that degraded state visible to `nix run .#doctor`.
The timer is non-blocking during activation, but a genuine repair failure remains a failed systemd unit and triggers the existing notification path.
