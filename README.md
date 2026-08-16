# dotagents

Model-agnostic operating config for AI coding agents.

One canonical rule set, shared across Claude Code, Codex, opencode, and any other agent that reads an instruction file at session start.
Symlinked live from my NixOS config ([universe](https://github.com/atqamz/universe), `modules/home/dotagents.nix`) via `mkOutOfStoreSymlink`, so edits apply instantly with no rebuild.

## Layout

- `AGENTS.md` - the canonical rules, including the always-on efficiency rules; `CLAUDE.md` is a symlink to it so every agent shares one source
- `claude/` - Claude Code tooling: `settings.json`, hooks, statusline, usage script
- `opencode/` - opencode config (`opencode.json`) and plugins, including the MCP servers every harness shares

The opencode integration keeps provider intent and curated metadata in `opencode/opencode.json`, with runtime-specific behavior isolated under `opencode/plugins/`.

Skills are not listed here. Universe (`modules/home/skills-sync.nix`) owns the allowlist of source repositories and wanted skills, and runs `bunx skills` for every Agent Skills-compatible harness (Claude Code, Codex, opencode).
The independently managed no-mistakes skill is the exception and is refreshed by `modules/home/no-mistakes.nix` from the pinned package.

No Claude-only plugins. Behavior rules live in `AGENTS.md` (Claude Code, Codex, and opencode all read it), on-demand tooling comes from skills, and opencode-specific integrations stay under `opencode/`.

## Force-read convention

Agent tools auto-load one instruction file at session start, by filename: `CLAUDE.md` (Claude Code), `AGENTS.md` (Codex, opencode, Copilot, Cursor, Zed; the cross-vendor standard).
Canonical rules live in `AGENTS.md` for the broadest support, with `CLAUDE.md` symlinked to it.

Instruction fan-out, from this repo's canonical `AGENTS.md` to each harness's global instruction file:

```text
dotagents/AGENTS.md
    |
    +-> ~/.claude/CLAUDE.md            (Claude Code)
    +-> ~/.codex/AGENTS.md             (Codex)
    +-> ~/.config/opencode/AGENTS.md   (opencode)
```

This repo owns the source file.
Universe (`modules/home/dotagents.nix`) owns the actual filesystem symlinks.
Same filenames at a project root override these globals.

## No-Mistakes

`no-mistakes/config.yaml` is the live-editable global no-mistakes policy.
Universe (`modules/home/no-mistakes.nix`) links it to `~/.no-mistakes/config.yaml` and owns the daemon, skill refresh, and doctor checks.

The workstation route is Codex first and Claude second.
The Codex worker uses the locally verified `gpt-5.6-luna` model with medium reasoning effort, while the Claude fallback uses `sonnet`.
These overrides apply only to no-mistakes child invocations and do not change interactive Claude settings or `~/.codex/config.toml`.

Repositories may commit `.no-mistakes.yaml` on their trusted default branch when they have a genuine routing requirement.
No-mistakes resolves that repository policy before the global policy, while arbitrary pushed branches cannot select host processes.
Universe commits its explicit `codex` to `claude` route for reproducibility.

No-mistakes retries transient failures within the selected native agent before moving to the next fallback agent.
Fallback is for upstream-defined agent startup or process-exit failures, not malformed structured findings.
Version 1.51.1 has per-agent overrides but no per-pipeline-step model routing.

Universe refreshes the generated no-mistakes skill from the pinned package into the global Claude and agent skill roots.
Do not add it to the general `skills-sync` ledger.

Use `no-mistakes stats --agents` for aggregate agent, model, duration, fallback, error, token, and tool telemetry.
Use `no-mistakes stats --run <run-id>` for one pipeline's detailed invocation timings.

## License

MIT, see [LICENSE](LICENSE).
This is a personal repo: read it, fork it, open an issue.
Pull requests are not accepted, see [CONTRIBUTING.md](CONTRIBUTING.md).
