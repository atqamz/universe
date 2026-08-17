# No-mistakes has explicit policy, runtime, and skill owners

## Context

Universe installed no-mistakes v1.51.1, but its effective routing depended on upstream `agent: auto` discovery order.
The interactive Claude model and interactive Codex configuration also leaked into gate workers.
Nix upgrades could leave the user daemon and systemd user unit pointing at an old store executable.
The generated no-mistakes skill had no explicit refresh owner outside `no-mistakes init`.

## Decision

`configs/dotagents/no-mistakes/config.yaml` owns the live-editable global policy.
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

The pinned skill is version-coupled to the no-mistakes package and remains outside the generic skills-sync ledger.
The no-mistakes doctor contract checks exact content in both `.agents/skills/no-mistakes/SKILL.md` and `.claude/skills/no-mistakes/SKILL.md`, then verifies discovery through each supported harness without inference.
Claude Code has no supported read-only skill enumeration surface in the installed version, so Universe uses the dotagents-owned user settings file at `~/.claude/settings.json` and the exact file check for source/filesystem-backed discovery and visibility verification.
The Claude visibility contract accepts an absent override and `on`, `name-only`, or `user-invocable-only`; it fails only `skillOverrides.no-mistakes: off` or malformed relevant settings.
`user-invocable-only` hides the skill from Claude's model listing but keeps it available in the user's slash-command menu, so invocation permissions remain outside this discovery contract.
The check is intentionally limited to user scope: neutral `/tmp` excludes project and local settings, while managed policy is outside the dotagents-owned workstation contract.
The installed `claude plugin init --help` wording remains a pinned-version `claude-skill-root-contract` regression check, not a runtime doctor predicate.
Codex is checked through the read-only app-server `skills/list` method from `/tmp`, requiring an enabled user-scoped entry whose path is the `.agents` skill.
OpenCode is checked through `opencode debug skill --pure` from `/tmp`, requiring a `no-mistakes` entry from either intended global root so its compatible duplicate visibility is valid.
The reconciliation probe sets `OPENCODE_DB=:memory:` because the pinned command eagerly initializes its unrelated SQLite instance state before emitting skill JSON.
The real home, configuration, and both canonical skill roots remain visible to that probe.
No additional Codex or OpenCode skill copies are created.

v1.51.1 has no machine-readable configuration validation command.
Its `doctor` command records a failed check as telemetry status `error` but returns exit status zero.
The Universe reconciliation helper therefore invokes `doctor` with `NO_COLOR=1` and `TERM=dumb`, rejects `some checks failed`, requires the stable `gate validation ... is runnable` result, and verifies the reported effective agent with `command -v`.
It preserves the upstream output when this predicate fails.
Optional missing-agent warnings remain warnings unless they make the effective gate agent unavailable.

An active validation run can leave the daemon stale across a rebuild until the bounded user timer retries.
The marker makes that degraded state visible to `nix run .#doctor`.
The timer is non-blocking during activation, but a genuine repair failure remains a failed systemd unit and triggers the existing notification path.

## Deployment

The no-mistakes policy and its Universe owner now land together in the same repository, so there is no cross-repository ordering guarantee to respect.
The historical sequence that landed `no-mistakes/config.yaml` via `atqamz/dotagents#30` ahead of `atqamz/universe#43` predates the `configs/dotagents` consolidation and no longer applies.
Verify a live change in order:

1. Apply the repository-approved NixOS rebuild.
2. Run the full live Universe doctor.
3. Run `no-mistakes doctor` and inspect its output.
4. Run `no-mistakes-reconcile check`.
5. Verify the CLI executable, daemon `/proc/<pid>/exe`, and systemd `ExecStart` agree.
6. Verify both installed `SKILL.md` files equal the pinned package skill.
7. Verify existing no-mistakes history and state remain intact.
