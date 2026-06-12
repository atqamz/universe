#!/usr/bin/env bash
# Stop hook: digest the just-ended session into ~/brain/log/, commit, push.
# Append-only, provenance-stamped, pushes straight to main (log/ is low-stakes).
set -uo pipefail   # NOT -e: a failed digest must degrade to a no-op, not error the session.

brain="${BRAIN_DIR:-$HOME/brain}"

# --- Guard 1: recursion. The digest runs `claude -p`, itself a session whose
# end would re-fire this hook. Bail if we're already inside a capture, or if
# Claude Code reports a Stop hook already active.
if [ "${BRAIN_CAPTURE:-0}" = "1" ]; then exit 0; fi

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
stop_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false')

if [ "$stop_active" = "true" ]; then exit 0; fi
if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then exit 0; fi
if [ ! -d "$brain/.git" ]; then exit 0; fi

# --- Guard 2: substantiality. Skip trivial sessions (a few lines of transcript
# aren't worth a digest or a commit).
lines=$(wc -l < "$transcript" 2>/dev/null || echo 0)
if [ "$lines" -lt 8 ]; then exit 0; fi

# --- Provenance the script can compute without the model.
ts=$(date -u +%Y%m%dT%H%M%SZ)
short_sid=${session_id:0:8}
logfile="$brain/log/${ts}-${short_sid}.md"

# Bound token cost: feed only the tail of the transcript (recent turns carry the
# outcome) to the digester.
transcript_tail=$(tail -c 60000 "$transcript" 2>/dev/null || true)

prompt=$(cat <<PROMPT
You are writing one append-only brain log entry from a Claude Code session transcript (JSONL below, possibly truncated to the tail).

Record ONLY what is grounded in the transcript: decisions made, work completed, outcomes, and non-obvious learnings. No speculation, no restating the prompt, no filler. If nothing substantive happened, output exactly: SKIP

Output GitHub-flavored markdown, this shape, nothing else:

## <one-line title of what this session was about>
- <decision/outcome/learning, one per bullet, grounded>

Transcript:
$transcript_tail
PROMPT
)

# --- Run the digester with both guards active in the child env.
digest=$(BRAIN_CAPTURE=1 claude -p "$prompt" 2>/dev/null || true)

# Empty or explicit SKIP → no entry, no commit.
if [ -z "$digest" ] || printf '%s' "$digest" | head -1 | grep -q '^SKIP$'; then
  exit 0
fi

# --- Write the entry with a provenance footer.
{
  printf '%s\n\n' "$digest"
  printf -- '---\n'
  printf '**Provenance:** session \`%s\` · cwd \`%s\` · %s\n' "$session_id" "$cwd" "$ts"
} > "$logfile"

# --- Commit + push to main. Pull-rebase first to absorb other machines' pushes;
# retry the push once. Never clobber, never block on failure.
git -C "$brain" add "$logfile" >/dev/null 2>&1
git -C "$brain" commit -m "session digest ${ts}-${short_sid}" >/dev/null 2>&1 || exit 0
git -C "$brain" pull --rebase --autostash >/dev/null 2>&1 || true
git -C "$brain" push >/dev/null 2>&1 || {
  git -C "$brain" pull --rebase --autostash >/dev/null 2>&1 || true
  git -C "$brain" push >/dev/null 2>&1 || true
}
exit 0
