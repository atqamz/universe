# AGENTS.md

Repo-specific rules. Global rules (`~/universe/configs/dotagents/AGENTS.md`) apply unless overridden here.

## Layout

See the Layout section of [README.md](README.md).

## Rules

- No comments in the codebase. Code speaks. None at all, not even "why" - stricter than global.
- Keep functional pragmas only (shebangs, `# shellcheck disable=`).
- Lua must parse clean under Hyprland's lua provider: `hyprctl keyword`/`dispatch` are rejected for config calls - use `hyprctl eval 'hl.foo(...)'`.
