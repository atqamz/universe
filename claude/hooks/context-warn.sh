#!/usr/bin/env bash
# UserPromptSubmit hook: surface the live context counter to Claude every turn,
# and warn when it passes a token threshold.
#
# Claude cannot read the statusline counter directly — it only ever sees what a
# hook injects. statusline-command.sh writes the live numbers to a bridge file
# (/tmp/claude-ctx-<session>.json: tokens, used_pct, remaining_percentage); this
# hook reads that file and injects them as additionalContext on EVERY prompt, so
# Claude always knows the current usage. Over THRESHOLD it ALSO emits a
# user-facing banner (systemMessage) and a stronger reminder to suggest
# /clear or /compact and to chunk remaining work.

THRESHOLD=100000

input=$(cat)
session=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$session" ] && exit 0

bridge="/tmp/claude-ctx-${session}.json"
[ -f "$bridge" ] || exit 0

tokens=$(jq -r '.tokens // 0' "$bridge" 2>/dev/null)
[[ "$tokens" =~ ^[0-9]+$ ]] || exit 0

used_pct=$(jq -r '.used_pct // 0' "$bridge" 2>/dev/null)
remaining=$(jq -r '.remaining_percentage // empty' "$bridge" 2>/dev/null)
tk=$(awk "BEGIN{printf \"%.0f\", $tokens/1000}")

if [ "$tokens" -lt "$THRESHOLD" ]; then
  # Below threshold: silently feed the live counter to Claude, no banner.
  jq -n --arg tk "$tk" --arg pct "$used_pct" '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: ("Live context counter: ~" + $tk + "K tokens used (" + $pct + "% of the usable window). Under the 100K chunk threshold — no action needed yet.")
    }
  }'
  exit 0
fi

jq -n --arg tk "$tk" '{
  systemMessage: ("Context ~" + $tk + "K (>100K). /clear for a new task, /compact to keep this one."),
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: ("Context is ~" + $tk + "K tokens, past 100K. Proactively tell the user their options: /clear if this prompt starts unrelated work, /compact to continue the current thread. Keep remaining work in chunks small enough to fit ~100K of context: finish one self-contained chunk, then recommend compact/clear before starting the next.")
  }
}'
