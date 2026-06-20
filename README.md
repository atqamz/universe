# dotai

Model-agnostic operating config for AI coding agents. `AGENTS.md` holds canonical rules; `CLAUDE.md` and `GEMINI.md` are thin `@AGENTS.md` imports so Claude Code, Codex, Gemini CLI, and other tools share one source.

Claude-specific tooling (settings, hooks, statusline, bin) lives under `claude/`. Symlinked live by `universe` home-manager config (`modules/home/dotai.nix`) via `mkOutOfStoreSymlink` — edits instantly live, no rebuild. Stable; rarely commits. Memory in separate `brain` repo.
