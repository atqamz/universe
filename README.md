# dotagents

Model-agnostic operating config for AI coding agents.

One canonical rule set, shared across Claude Code, opencode, and any other agent that reads an instruction file at session start.
Symlinked live from my NixOS config ([universe](https://github.com/atqamz/universe), `modules/home/dotagents.nix`) via `mkOutOfStoreSymlink`, so edits apply instantly with no rebuild.

## Layout

- `AGENTS.md` - the canonical rules; `CLAUDE.md` is a symlink to it so every agent shares one source
- `claude/` - Claude Code tooling: `settings.json`, hooks, statusline, usage script
- `opencode/` - opencode config (`opencode.json`)
- `skills/manifest.txt` - the skill set, installed by universe's `skills-sync` timer via `npx skills`

## Force-read convention

Agent tools auto-load one instruction file at session start, by filename: `CLAUDE.md` (Claude Code), `AGENTS.md` (opencode, Copilot, Cursor, Zed; the cross-vendor standard).
Canonical rules live in `AGENTS.md` for the broadest support, with `CLAUDE.md` symlinked to it.

Global locations, all symlinked to this `AGENTS.md` by `dotagents.nix`: `~/.claude/CLAUDE.md`, `~/.config/opencode/AGENTS.md`.
Same filenames at a project root override these globals.

## License

MIT, see [LICENSE](LICENSE).
This is a personal repo: read it, fork it, open an issue.
Pull requests are not accepted, see [CONTRIBUTING.md](CONTRIBUTING.md).
