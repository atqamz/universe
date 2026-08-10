# dotagents

Model-agnostic operating config for AI coding agents.

One canonical rule set, shared across Claude Code, Codex, opencode, and any other agent that reads an instruction file at session start.
Symlinked live from my NixOS config ([universe](https://github.com/atqamz/universe), `modules/home/dotagents.nix`) via `mkOutOfStoreSymlink`, so edits apply instantly with no rebuild.

## Layout

- `AGENTS.md` - the canonical rules, including the always-on efficiency rules; `CLAUDE.md` is a symlink to it so every agent shares one source
- `claude/` - Claude Code tooling: `settings.json`, hooks, statusline, usage script
- `opencode/` - opencode config (`opencode.json`), including the MCP servers every harness shares

Skills are not listed here. Universe (`modules/home/skills-sync.nix`) owns the allowlist of source repositories and wanted skills, and runs `bunx skills` for every Agent Skills-compatible harness (Claude Code, Codex, opencode).

Plugin-free by design: no Claude-only plugins. Behavior rules live in `AGENTS.md` (Claude Code, Codex, and opencode all read it), on-demand tooling comes from skills. Nothing is tied to one agent.

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

## License

MIT, see [LICENSE](LICENSE).
This is a personal repo: read it, fork it, open an issue.
Pull requests are not accepted, see [CONTRIBUTING.md](CONTRIBUTING.md).
