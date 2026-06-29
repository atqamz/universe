# dotai

Model-agnostic operating config for AI coding agents. `AGENTS.md` holds the canonical rules; `CLAUDE.md` is a symlink to it so every agent shares one source.

Claude-specific tooling (settings, hooks, statusline, bin) lives under `claude/`. Symlinked live by `universe` home-manager config (`modules/home/dotai.nix`) via `mkOutOfStoreSymlink`, so edits are instantly live with no rebuild.

## Force-read convention

Agent tools auto-load one instruction file at session start, by filename: `CLAUDE.md` (Claude Code), `AGENTS.md` (opencode, Copilot, Cursor, Zed; the cross-vendor standard). Canonical rules live in `AGENTS.md` for the broadest support, with `CLAUDE.md` symlinked to it.

Global locations, all symlinked to this `AGENTS.md` by `dotai.nix`: `~/.claude/CLAUDE.md`, `~/.config/opencode/AGENTS.md`. Same filenames at a project root override these globals.
