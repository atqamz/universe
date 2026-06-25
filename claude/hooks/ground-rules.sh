#!/usr/bin/env bash
set -uo pipefail

cat <<'RULES'
GROUND RULES (re-injected; AGENTS.md is authoritative):
- Comments: write ZERO by default. Allowed only for a "why" code can't show, or a functional pragma. Uncertain → omit. Never restate code, narrate "what", add banners, or docstring self-evident functions. Delete obvious comments in files you touch.
- No emojis in code, commits, responses.
- Design/discussion intent → discuss only, no edits until explicit go. Named/mechanical task → do it.
- No push/PR/commit unless asked. GPG sign always, never --no-verify.
RULES
