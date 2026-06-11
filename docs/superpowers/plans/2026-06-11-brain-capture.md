# Brain Auto-Capture (Stop Hook) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cure the root pain (E: not auto-updating) — a global Stop hook digests every Claude Code session into a provenance-stamped, append-only file under `~/brain/log/`, then commits and pushes to `main`, with no review gate on capture.

**Architecture:** A Stop hook declared in `dotai/claude/settings.json` runs `~/.claude/hooks/brain-capture.sh` when any session ends, in any directory. The script reads the hook's JSON stdin (`session_id`, `transcript_path`, `cwd`, `stop_hook_active`), runs headless `claude -p` to extract a grounded digest from the transcript, writes it to a uniquely-named `~/brain/log/` file with provenance, and commits + pushes. Append-only + unique filenames mean concurrent machines never conflict. A recursion guard and a substantiality gate keep it from looping or capturing trivial sessions.

**Tech Stack:** Claude Code Stop hooks, `claude -p` (headless, on the subscription — no API key), bash, `jq`, git.

**Depends on:** `2026-06-11-brain-foundation.md` (`~/brain` with `log/` must exist; `dotai/claude/settings.json` symlinked to `~/.claude/settings.json`; `dotai/claude/hooks/` symlinked).

---

## Context the engineer must know

- `~/brain/log/` is append-only: each session writes ONE new uniquely-named file; existing files are never edited or deleted. This is what makes concurrent-device capture conflict-free and contains any hallucination to `log/` (never `notes/`).
- **Stop hook contract (Claude Code).** On session stop, the hook receives a JSON object on **stdin** with at least: `session_id`, `transcript_path` (path to the session JSONL), `cwd`, and `stop_hook_active` (true when a Stop hook is already in progress — used to prevent loops). A hook command exiting non-zero with stderr surfaces feedback; exit 0 is the normal path. The hook is configured under `hooks.Stop` in `settings.json` as `[{ "matcher": "", "hooks": [{ "type": "command", "command": "<path>" }] }]`.
- **Recursion is the main risk.** The digest step runs `claude -p`, which is itself a Claude Code session whose end would fire this same Stop hook → infinite spawn. Two independent guards: (1) honor `stop_hook_active` (Claude Code sets it when re-entering); (2) export `BRAIN_CAPTURE=1` before calling `claude -p` and bail at the top of the script if it is set (the child inherits the env). Belt and suspenders.
- **`claude -p` headless.** `claude -p "<prompt>"` runs non-interactively and prints the model's final text to stdout. It reads the prompt from the argument; the transcript is supplied by including the (truncated) transcript content in the prompt or passing its path for the model to read. Keep token cost bounded — cap how much transcript is fed.
- **Provenance is mandatory.** Every digest records `session_id`, `cwd`, the date (UTC), and the files/commits touched, so the later promotion/lint pass can verify claims against reality. Unsourced claims are deletion candidates.
- **Direct to `main`.** `log/` is low-stakes and append-only, so the hook pushes straight to `main`. Push can race across machines; handle with `pull --rebase --autostash` then retry once.
- **Hooks must be fast and never block the user destructively.** Run the heavy `claude -p` + git work in the background (`&`, detached) so session exit isn't stalled, OR accept the latency (the user explicitly accepted session-end latency). This plan runs it inline but guards every external call so a failure degrades to "no digest this session" rather than an error.
- **Date in scripts is fine.** Hook scripts may call `date` (only the *model* is barred from `Date.now()`-style calls; this is a bash hook).
- **Global git rules:** GPG sign always; never `--no-verify`. The hook's commits are GPG-signed via the user's global git config (the gpg-agent is available in the session env). Imperative lowercase commit subjects.

---

## File structure (what this plan creates / modifies)

**In `dotai` (`~/dotai`):**
- Create: `claude/hooks/brain-capture.sh` — the Stop hook (executable).
- Modify: `claude/settings.json` — register the `Stop` hook.

**In `universe`:**
- Modify: `modules/home/dotai.nix` — add the `hooks/brain-capture.sh` symlink.

---

## Task 1: Write the capture hook script

**Files:**
- Create: `~/dotai/claude/hooks/brain-capture.sh`

- [ ] **Step 1: Write `~/dotai/claude/hooks/brain-capture.sh`**

```bash
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
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x ~/dotai/claude/hooks/brain-capture.sh
```

## Task 2: Test the hook in isolation (simulated stop event)

**Files:** (none — exercises the script with a fake transcript)

- [ ] **Step 1: Build a fake transcript and feed the hook the Stop JSON**

This proves the parsing, substantiality gate, write, and git path without ending a real session. The recursion guard means the real `claude -p` will run; for a deterministic offline test, stub `claude` on `PATH`.

```bash
# Stub `claude` so the test is offline and deterministic.
mkdir -p /tmp/braincap-bin
cat > /tmp/braincap-bin/claude <<'EOF'
#!/usr/bin/env bash
echo "## Test session"
echo "- Proved the brain-capture hook writes a log entry."
EOF
chmod +x /tmp/braincap-bin/claude

# Fake transcript with >= 8 lines.
ft=/tmp/braincap-transcript.jsonl
seq 1 12 | sed 's/.*/{"type":"line"}/' > "$ft"

# Run the hook with a throwaway brain.
rm -rf /tmp/braincap-brain && mkdir -p /tmp/braincap-brain/log
git -C /tmp/braincap-brain init -q
git -C /tmp/braincap-brain commit -q --allow-empty -m init

printf '{"session_id":"abcd1234-feed","transcript_path":"%s","cwd":"/tmp/x","stop_hook_active":false}' "$ft" \
  | PATH=/tmp/braincap-bin:$PATH BRAIN_DIR=/tmp/braincap-brain bash ~/dotai/claude/hooks/brain-capture.sh

ls /tmp/braincap-brain/log/ && cat /tmp/braincap-brain/log/*.md
```
Expected: one `*-abcd1234.md` file under `log/`, containing the stub digest plus a `**Provenance:** session abcd1234-feed ...` footer; `git -C /tmp/braincap-brain log --oneline` shows a `session digest` commit (push fails silently — no remote — which is the intended non-blocking behavior).

- [ ] **Step 2: Verify the substantiality gate skips trivial sessions**

```bash
seq 1 3 | sed 's/.*/{"type":"line"}/' > /tmp/braincap-short.jsonl
rm -rf /tmp/braincap-brain2 && mkdir -p /tmp/braincap-brain2/log
git -C /tmp/braincap-brain2 init -q
printf '{"session_id":"short","transcript_path":"/tmp/braincap-short.jsonl","cwd":"/tmp","stop_hook_active":false}' \
  | PATH=/tmp/braincap-bin:$PATH BRAIN_DIR=/tmp/braincap-brain2 bash ~/dotai/claude/hooks/brain-capture.sh
ls /tmp/braincap-brain2/log/ | wc -l
```
Expected: `0` (3-line transcript is below the 8-line gate → no entry).

- [ ] **Step 3: Verify the recursion guard**

```bash
printf '{"session_id":"x","transcript_path":"%s","cwd":"/tmp","stop_hook_active":false}' /tmp/braincap-transcript.jsonl \
  | BRAIN_CAPTURE=1 PATH=/tmp/braincap-bin:$PATH BRAIN_DIR=/tmp/braincap-brain2 bash ~/dotai/claude/hooks/brain-capture.sh
echo "exit=$?"; ls /tmp/braincap-brain2/log/ | wc -l
```
Expected: `exit=0`, `0` entries — `BRAIN_CAPTURE=1` short-circuits at the top.

- [ ] **Step 4: Clean up the test artifacts**

```bash
rm -rf /tmp/braincap-bin /tmp/braincap-brain /tmp/braincap-brain2 /tmp/braincap-transcript.jsonl /tmp/braincap-short.jsonl
```

## Task 3: Register the Stop hook in `dotai/claude/settings.json`

**Files:**
- Modify: `~/dotai/claude/settings.json`

- [ ] **Step 1: Inspect existing hooks**

```bash
jq '.hooks | keys' ~/dotai/claude/settings.json
```
Expected: lists current hook events (e.g. `UserPromptSubmit`). Note whether `Stop` already exists.

- [ ] **Step 2: Add the `Stop` hook with `jq`**

The command points at the symlinked path (`~/.claude/hooks/brain-capture.sh`), consistent with how `context-warn.sh` is referenced.

```bash
tmp=$(mktemp)
jq '.hooks.Stop = ((.hooks.Stop // []) + [
  { "matcher": "", "hooks": [ { "type": "command", "command": "/home/atqa/.claude/hooks/brain-capture.sh" } ] }
])' ~/dotai/claude/settings.json > "$tmp" && mv "$tmp" ~/dotai/claude/settings.json
```

- [ ] **Step 3: Verify**

Run: `jq -e '.hooks.Stop[0].hooks[0].command | endswith("brain-capture.sh")' ~/dotai/claude/settings.json`
Expected: `true`, exit 0 (valid JSON, hook registered).

## Task 4: Symlink the hook via home-manager

**Files:**
- Modify: `modules/home/dotai.nix`

- [ ] **Step 1: Add the `hooks/brain-capture.sh` symlink**

In the `home.file` attrset of `modules/home/dotai.nix`, add:

```nix
    ".claude/hooks/brain-capture.sh".source = link "${dotai}/hooks/brain-capture.sh";
```

- [ ] **Step 2: Evaluate**

Run: `nix eval --raw ~/universe#nixosConfigurations.pavg15.config.home-manager.users.atqa.home.file.".claude/hooks/brain-capture.sh".source 2>&1 | tail -3`
Expected: prints `/home/atqa/dotai/claude/hooks/brain-capture.sh`, no error.

## Task 5: Commit

**Files:** (git on `~/dotai` and `~/universe`)

- [ ] **Step 1: Commit `dotai`**

```bash
git -C ~/dotai add claude/hooks/brain-capture.sh claude/settings.json
git -C ~/dotai commit -m "add stop hook that digests sessions into brain log"
git -C ~/dotai push
```

- [ ] **Step 2: Commit `universe`** (branch `12-persistent-memory`)

```bash
git -C ~/universe add modules/home/dotai.nix docs/superpowers/plans/2026-06-11-brain-capture.md
git -C ~/universe commit -m "symlink brain-capture stop hook"
cd ~/universe && nix fmt 2>&1 | tail -5
```
Expected: GPG-signed commits; `nix fmt` clean.

## Task 6: Build verify

- [ ] **Step 1: Build the host config**

Run: `nixos-rebuild build --flake ~/universe#pavg15 2>&1 | tail -15`
Expected: builds to completion, no error.

## Deploy & acceptance (user action on `pavg15`, after the PR merges)

- [ ] **Switch:** `git -C ~/universe pull --ff-only && sudo nixos-rebuild switch --flake ~/universe#pavg15`. Confirm `~/.claude/hooks/brain-capture.sh` symlinks into `~/dotai`.
- [ ] **Live capture:** run a short substantive Claude session in any directory, exit it; within moments `~/brain/log/` gains a new `<ts>-<sid>.md` with a digest + provenance footer, and `git -C ~/brain log --oneline -1` shows a `session digest` commit pushed to `origin/main`.
- [ ] **No recursion:** the `claude -p` digest does NOT itself spawn another digest (no second `log/` file, no runaway processes).
- [ ] **Trivial session skipped:** a one-line throwaway session produces no `log/` entry and no commit.
- [ ] **Cross-machine:** the pushed digest auto-pulls onto another machine via `brain-sync` (foundation plan).

## Out of scope (other plans / deferred)

- Retrieval (qmd / `brain-recall`) — `2026-06-11-brain-qmd-recall.md`.
- Migration + graphify retirement — `2026-06-11-brain-migration.md`.
- Promotion of `log/` → `notes/` (lint agent + scheduled PR) — deferred follow-up; needs `log/` populated (this plan) first.
- Background/async execution of the hook to remove session-end latency — refinement; the user accepted the latency.
