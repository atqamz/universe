# Brain Migration + Retirement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `brain` the sole canonical memory store — migrate the existing per-project auto-memory facts into `brain/notes/` (building `index.md`), then retire graphify (stop its timer, drop its MCP servers) and strip all AI config out of the old `dotfiles` repo, so nothing competes with the brain.

**Architecture:** A migration script flattens `~/.claude/projects/*/memory/*.md` (125 fact files across 21 projects, excluding the per-project `MEMORY.md` indexes) into `~/brain/notes/`, names each `<project>__<name>.md`, and regenerates `~/brain/index.md` from each note's frontmatter. Retirement then disables `graphify-sync.timer`, removes the `graphify-personal`/`graphify-memory` MCP servers from the volatile `~/.claude.json`, deletes the graphify + claude AI config from the `dotfiles` repo (now living in `dotai`), and drops the dangling `@context/GRAPHIFY.md` + `@PROJECTS.md` imports from `dotai`'s `CLAUDE.md`.

**Tech Stack:** bash, `jq`, `awk`/`sed` (frontmatter extraction), `systemctl --user`, git (two repos: `brain`, `dotfiles`), Claude Code `~/.claude.json`.

**Depends on:** `2026-06-11-brain-foundation.md` (`~/brain/notes` + `index.md` exist; `dotai` is live, symlinked into `~/.claude`, so the dotfiles AI config is no longer the source). Best run AFTER `2026-06-11-brain-capture.md` so the Stop hook is already capturing into `log/` before the old per-project memory is abandoned.

---

## Context the engineer must know

- **Source data — auto-memory.** `~/.claude/projects/<project-slug>/memory/` holds, per project: a `MEMORY.md` index plus N individual fact files, each with frontmatter (`name:`, `description:`, `metadata.type:`) and a markdown body. Measured today: **125 fact files across 21 projects**. The `MEMORY.md` files are per-project indexes — they are NOT migrated as notes (the brain has one global `index.md`); their content is already reflected in the individual files' frontmatter.
- **Target — brain notes.** `~/brain/notes/` holds one fact per file; `~/brain/index.md` is one line per note (`slug — hook`). Notes keep their frontmatter so provenance/type survive.
- **`~/.claude.json` is volatile and untracked** (holds auth + MCP config). It is NOT in any repo. Edit it in place with `jq`; never commit it, never echo its full contents (it may contain tokens). Touch only the `mcpServers` keys.
- **graphify wiring discovered:**
  - `~/.claude.json` `mcpServers` contains `graphify-personal` and `graphify-memory` (two, not three).
  - `graphify-sync.timer` (enabled) and `graphify-sync.service` are **stow symlinks** in `~/.config/systemd/user/` pointing at `~/dotfiles/scripts/.config/systemd/user/`. Disabling the timer and removing the symlinks stops the daily rebuild/rsync/push job. The job's script lives in `~/dotfiles/scripts/`.
  - The graphify-sync job also regenerated `~/.claude/PROJECTS.md` (the cross-project map imported by the global `CLAUDE.md`). Retiring graphify means that map goes stale; the brain (notes + recall) replaces it, so the `@PROJECTS.md` import is dropped too.
- **dotfiles caveat (sfx14).** The old `dotfiles` repo still serves the legacy host `sfx14` via stow. `pavg15` (the only host migrated to `universe`) now gets its AI config from `dotai`, NOT dotfiles. Removing AI config from `dotfiles` is safe for `pavg15` but would strip it from `sfx14` if `sfx14` is ever re-stowed. The user has accepted retiring the old setup; this plan removes the AI/graphify config from `dotfiles` and records the caveat. The eventual `dotfiles` → `dotfiles-universe` repo rename is OUT of scope here.
- **Idempotent + reversible-by-git.** The migration copies (never moves) from `~/.claude/projects/` so the source auto-memory stays intact until the user is satisfied; abandonment is just "stop writing there," which the updated `context/MEMORY.md` instruction handles. dotfiles deletions are recoverable via git history.
- **Global git rules:** GPG sign always; never `--no-verify`; imperative lowercase commit subjects, no trailing period, no planning jargon. `brain` commits → `atqamz/brain` `main`; `dotai` commits → `atqamz/dotai` `main`; `dotfiles` commits → its own default branch; `universe` doc changes → branch `12-persistent-memory`.

---

## File structure (what this plan creates / modifies)

**In `brain` (`~/brain`):**
- Create: `notes/<project>__<name>.md` × ~125 (migrated facts).
- Modify: `index.md` (regenerated from note frontmatter).

**In `dotai` (`~/dotai`):**
- Modify: `claude/CLAUDE.md` — drop `@context/GRAPHIFY.md` and `@PROJECTS.md` imports.
- Delete: `claude/context/GRAPHIFY.md`.
- Modify: `claude/context/MEMORY.md` — redirect the memory convention from per-project auto-memory to the brain.

**In `dotfiles` (`~/dotfiles`, separate repo):**
- Delete: `claude/` (AI config now in `dotai`), `scripts/` graphify pieces, the graphify systemd units.

**Machine-local (not a repo):**
- Edit: `~/.claude.json` — remove `graphify-personal`, `graphify-memory` MCP servers.
- Disable + remove: `graphify-sync.timer`/`.service` user units.

**In `universe`:**
- Modify: nothing functional; the plan doc itself is committed on `12-persistent-memory`.

---

## Task 1: Write and run the auto-memory migration script

**Files:**
- Create: `~/brain/notes/*` (output), regenerated `~/brain/index.md`

- [ ] **Step 1: Dry-run inventory (confirm the source set)**

```bash
find ~/.claude/projects -path '*/memory/*.md' -not -name 'MEMORY.md' | wc -l
find ~/.claude/projects -path '*/memory/*.md' -not -name 'MEMORY.md' | head -5
```
Expected: a count near `125` and sample paths like `~/.claude/projects/-home-atqa-universe/memory/universe-brain.md`.

- [ ] **Step 2: Copy each fact file into `notes/` with a collision-proof name**

```bash
mkdir -p ~/brain/notes
while IFS= read -r f; do
  # project slug = the projects/<slug>/ segment, leading dash stripped
  proj=$(printf '%s' "$f" | sed -E 's#.*/projects/-?([^/]+)/memory/.*#\1#')
  base=$(basename "$f")
  dest="$HOME/brain/notes/${proj}__${base}"
  cp -n "$f" "$dest"
done < <(find ~/.claude/projects -path '*/memory/*.md' -not -name 'MEMORY.md')
ls ~/brain/notes | wc -l
```
Expected: `notes/` now holds ~125 `<project>__<name>.md` files (`cp -n` = no clobber; rerun-safe).

- [ ] **Step 3: Regenerate `~/brain/index.md` from note frontmatter**

```bash
{
  echo "# notes index"
  echo
  echo "One line per note in \`notes/\`: \`slug — hook\`. Read this first, then open only the matching note."
  echo
  for n in ~/brain/notes/*.md; do
    [ -e "$n" ] || continue
    slug=$(basename "$n" .md)
    # description: first non-empty value of a `description:` frontmatter key
    desc=$(awk -F': ' '/^description:/ {sub(/^description: */,""); print; exit}' "$n")
    [ -z "$desc" ] && desc="(no description)"
    printf -- '- `%s` — %s\n' "$slug" "$desc"
  done
} > ~/brain/index.md
wc -l ~/brain/index.md && head -8 ~/brain/index.md
```
Expected: `index.md` has a header plus ~125 `- \`slug\` — desc` lines.

- [ ] **Step 4: Spot-check a migrated note kept its frontmatter + body**

Run: `head -12 ~/brain/notes/*universe-brain.md`
Expected: the `---` frontmatter (`name:`, `description:`, `metadata:`) and the body are intact.

## Task 2: Commit the migrated notes to `brain`

**Files:** (git on `~/brain`)

- [ ] **Step 1: Stage and commit**

```bash
git -C ~/brain add notes index.md
git -C ~/brain commit -m "migrate per-project auto-memory into brain notes"
git -C ~/brain push
```
Expected: GPG-signed commit pushed to `origin/main`; `git -C ~/brain log --oneline -1` shows it.

- [ ] **Step 2: Verify recall over the migrated notes** (if the qmd/recall plan shipped)

Run: `brain-recall "persistent memory"` (or grep fallback)
Expected: returns the `universe-brain` note among the hits — proves migrated facts are recallable.

## Task 3: Redirect the memory convention in `dotai` and drop graphify imports

**Files:**
- Modify: `~/dotai/claude/CLAUDE.md`
- Delete: `~/dotai/claude/context/GRAPHIFY.md`
- Modify: `~/dotai/claude/context/MEMORY.md`

- [ ] **Step 1: Remove the dangling graphify + projects imports from `CLAUDE.md`**

The copied `CLAUDE.md` imports `@context/GRAPHIFY.md` and `@PROJECTS.md`, both graphify-era. Delete those two import lines (leave the other `@context/*.md` imports). After editing:

```bash
grep -n '@context/GRAPHIFY.md\|@PROJECTS.md' ~/dotai/claude/CLAUDE.md
```
Expected: no output (both imports removed).

- [ ] **Step 2: Delete the graphify context file**

```bash
rm ~/dotai/claude/context/GRAPHIFY.md
grep -c '^@context/' ~/dotai/claude/CLAUDE.md
```
Expected: `7` (was 8; GRAPHIFY dropped).

- [ ] **Step 3: Rewrite `~/dotai/claude/context/MEMORY.md` to point at the brain**

Replace its body (which currently describes per-project `~/.claude/projects/*/memory/` writes) with the brain workflow:

```markdown
# Memory

- Canonical memory is `~/brain` (git, auto-pulled). It supersedes the old
  per-project `~/.claude/projects/*/memory/`. Do not write per-project memory.
- Capture is automatic: the Stop hook digests each session into `~/brain/log/`.
  You do not hand-write `log/`.
- Recall: when a prompt might be answered from past work, consult the brain —
  read `~/brain/index.md`, open the matching `~/brain/notes/<slug>.md`, cite it.
  Use `brain-recall <query>` (qmd-ranked, grep fallback) when available.
- Canon (`notes/`) changes only through a reviewed PR on the `brain` repo. Do not
  edit `notes/` casually; propose promotions from `log/` via PR.
```

- [ ] **Step 4: Commit `dotai`**

```bash
git -C ~/dotai add claude/CLAUDE.md claude/context/MEMORY.md
git -C ~/dotai rm --cached claude/context/GRAPHIFY.md 2>/dev/null || true
git -C ~/dotai add -A claude/context
git -C ~/dotai commit -m "retire graphify imports, point memory convention at brain"
git -C ~/dotai push
```
Expected: GPG-signed commit; `GRAPHIFY.md` gone from the tree.

## Task 4: Retire the graphify runtime (timer + MCP servers)

**Files:** (machine-local: systemd user units, `~/.claude.json`)

- [ ] **Step 1: Disable and stop the graphify timer**

```bash
systemctl --user disable --now graphify-sync.timer
systemctl --user list-timers | grep -i graphify || echo "timer gone"
```
Expected: timer disabled/stopped; `list-timers` no longer shows it (`timer gone`).

- [ ] **Step 2: Remove the stow-symlinked units from the user unit dir**

These are symlinks into `~/dotfiles/scripts/...`; removing the symlinks here detaches them. (The dotfiles source is deleted in Task 5.)

```bash
rm -f ~/.config/systemd/user/graphify-sync.timer ~/.config/systemd/user/graphify-sync.service
systemctl --user daemon-reload
```
Expected: no error; units no longer linked.

- [ ] **Step 3: Remove the graphify MCP servers from `~/.claude.json`**

Edit only the two keys; never print the file.

```bash
tmp=$(mktemp)
jq 'del(.mcpServers["graphify-personal"], .mcpServers["graphify-memory"])' ~/.claude.json > "$tmp" && mv "$tmp" ~/.claude.json
jq -r '.mcpServers | keys[]' ~/.claude.json | grep -i graphify && echo "STILL PRESENT" || echo "graphify mcp removed"
```
Expected: `graphify mcp removed` (both keys deleted; remaining MCP servers untouched).

## Task 5: Strip AI + graphify config out of the `dotfiles` repo

**Files:** (git on `~/dotfiles`, separate repo) — see the sfx14 caveat in Context.

- [ ] **Step 1: Locate the AI + graphify pieces to remove**

```bash
ls -d ~/dotfiles/claude 2>/dev/null
ls ~/dotfiles/scripts/.config/systemd/user/ 2>/dev/null | grep -i graphify
ls ~/dotfiles/scripts/ 2>/dev/null | grep -i graphify
```
Expected: lists `~/dotfiles/claude/` (the AI config, now in `dotai`), the two graphify unit files, and `graphify-sync.sh` (+ any helper like `gen-projects-registry.sh`).

- [ ] **Step 2: Remove them from the repo**

```bash
git -C ~/dotfiles rm -r claude
git -C ~/dotfiles rm scripts/.config/systemd/user/graphify-sync.timer scripts/.config/systemd/user/graphify-sync.service
git -C ~/dotfiles rm scripts/graphify-sync.sh
# remove the projects-registry generator if it exists (graphify-only)
git -C ~/dotfiles rm scripts/gen-projects-registry.sh 2>/dev/null || true
```
Expected: files staged for deletion.

- [ ] **Step 3: Commit the dotfiles cleanup**

```bash
git -C ~/dotfiles commit -m "remove claude ai config and graphify; superseded by dotai and brain"
```
Expected: GPG-signed commit. (Push per the user's usual dotfiles flow — only if asked.)

- [ ] **Step 4: Verify pavg15 is unaffected**

Run: `ls -l ~/.claude/CLAUDE.md`
Expected: still symlinks into `~/dotai/claude/CLAUDE.md` (foundation plan's HM symlink), NOT into `~/dotfiles`. AI config on `pavg15` is fully served by `dotai`.

## Task 6: Commit the plan doc and build verify

**Files:** (git on `~/universe`, branch `12-persistent-memory`)

- [ ] **Step 1: Commit the plan doc**

```bash
git -C ~/universe add docs/superpowers/plans/2026-06-11-brain-migration.md
git -C ~/universe commit -m "add brain migration and retirement plan"
```

- [ ] **Step 2: Build verify (no functional universe change, but confirm clean eval)**

Run: `nixos-rebuild build --flake ~/universe#pavg15 2>&1 | tail -10`
Expected: builds to completion, no error.

## Acceptance

- [ ] `~/brain/notes/` holds the migrated facts (~125 files); `~/brain/index.md` lists them; all pushed to `origin/main`.
- [ ] `brain-recall` (or grep) surfaces a migrated fact from an unrelated directory.
- [ ] `graphify-sync.timer` is disabled/removed; `systemctl --user list-timers` shows no graphify; `~/.claude.json` has no `graphify-*` MCP server.
- [ ] `dotai`'s `CLAUDE.md` has no `@context/GRAPHIFY.md`/`@PROJECTS.md` import; `context/GRAPHIFY.md` is gone; `context/MEMORY.md` points at the brain.
- [ ] `dotfiles` no longer contains `claude/` or the graphify scripts/units; `pavg15`'s `~/.claude` still resolves through `dotai` (unaffected).
- [ ] Source auto-memory under `~/.claude/projects/*/memory/` is left intact (copied, not moved) until the user confirms; the convention no longer writes there.

## Out of scope (other plans / deferred)

- Retrieval engine (qmd / `brain-recall` implementation) — `2026-06-11-brain-qmd-recall.md`.
- Auto-capture Stop hook — `2026-06-11-brain-capture.md`.
- Promotion of `log/` → `notes/` (lint agent + scheduled PR) — deferred follow-up.
- `dotfiles` → `dotfiles-universe` repo rename and full sfx14 retirement — broader repo migration, separate effort.
