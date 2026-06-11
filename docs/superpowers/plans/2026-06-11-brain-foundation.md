# Brain Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up two new repos (`dotai`, `brain`) and wire them into the `universe` NixOS/home-manager config so Claude's operating rules are declaratively symlinked into `~/.claude` and a canonical memory store (`~/brain`) is auto-pulled on every machine — recalled on demand, no qmd, no auto-capture yet.

**Architecture:** `dotai` holds the stable AI config (CLAUDE.md, context/, settings.json, bin/) and is symlinked live into `~/.claude` via home-manager `mkOutOfStoreSymlink` (edit = instantly live, no rebuild). `brain` holds churny memory (`log/` append-only, `notes/` canon, `index.md` catalogue) and is cloned to `~/brain`, auto-pulled by a home-manager systemd user timer mirroring the existing `secrets-sync` pattern. A standing instruction in `dotai`'s CLAUDE.md tells the agent to consult `~/brain/index.md` then the relevant note when a prompt might be answered from memory. This plan deliberately ships index-only retrieval and manual capture; auto-capture (Plan 2) and retirement/migration (Plan 3) follow.

**Tech Stack:** Nix flake-parts, home-manager (`mkOutOfStoreSymlink`, `systemd.user`), `gh` CLI, git, bash (`pkgs.writeShellApplication`).

---

## Context the engineer must know

- This is the `universe` flake at `/home/atqa/universe`, branch `12-persistent-memory`. The only live host is `pavg15`. nixpkgs is `nixos-unstable`.
- **Existing pattern to mirror — secrets-sync.** Read these two files before starting; the brain modules are near-clones:
  - `modules/home/secrets-sync.nix` — a `pkgs.writeShellApplication` wrapped in a `systemd.user.services.<name>` (oneshot) + `systemd.user.timers.<name>` (OnStartupSec=2min, OnUnitActiveSec=1d, Persistent). Vault path is `$HOME/secrets`. The sync script guards: skip if not cloned, skip + `notify-send` if the worktree is dirty, then `git pull --ff-only`.
  - `parts/apps.nix` — a `bootstrap` app (`apps.secrets-bootstrap`) that `gh repo clone`s the repo if absent else `git pull --ff-only`, then runs a script. Uses `gh` (the universe repo is public, vault clone needs gh auth).
- **Home-manager wiring.** `lib/mkHost.nix` imports `inputs.home-manager.nixosModules.home-manager` and sets `home-manager.users.atqa = ../modules/home;` with `useGlobalPkgs`, `backupFileExtension = "bak"`, and `extraSpecialArgs = { inherit inputs; }`. So HM modules receive `pkgs`, `config`, `lib`, and `inputs`. `mkOutOfStoreSymlink` is reached via `config.lib.file.mkOutOfStoreSymlink`. Because `backupFileExtension = "bak"` is set, any pre-existing file/symlink at a managed path is moved aside to `<name>.bak` on activation rather than causing a collision error.
- **`modules/home/default.nix`** has an `imports = [ ... ];` list; new HM modules must be added there.
- **Current `~/.claude` config** is a set of MANUAL stow symlinks into `~/dotfiles/claude/.claude/` (`CLAUDE.md`, `context`, `settings.json`, `fetch-usage.sh`, plus `hooks/`, `statusline-command.sh`). This plan introduces HM-owned symlinks pointing at `~/dotai` instead. Plan 3 deletes the dotfiles copies; this plan leaves them in place (the `.bak` rename keeps the old ones recoverable).
- **Source AI config to copy into `dotai`** lives at `~/dotfiles/claude/.claude/`: `CLAUDE.md`, `context/{GIT,GITHUB,CODING,COMMUNICATION,SECURITY,CONTEXT,MEMORY,GRAPHIFY}.md`, `settings.json`, `fetch-usage.sh`, `statusline-command.sh`, `hooks/context-warn.sh`.
- **Repos do not exist yet.** `atqamz/dotai` and `atqamz/brain` must be created with `gh`. `dotai` is **public** (operating config, no secrets); `brain` is **private** (work memory). Neither repo contains secrets.
- **Global git rules (from CLAUDE.md):** GPG sign always (never `--no-gpg-sign`); never `--no-verify`; branch `<issue#>-<slug>`; imperative lowercase commit subjects, no trailing period, no planning jargon (no "phase"/"step"/"stage"); `--assignee atqamz` on PRs; merge via `gh pr merge --merge` only; never force-push default branch. The `universe` changes in this plan go on branch `12-persistent-memory` (already checked out) and ship as one PR (`Fixes #12` is premature — #12 spans 3 plans; reference it without auto-closing).
- **Path convention:** clones live directly in `$HOME` (matches `~/secrets`): `~/dotai`, `~/brain`.

---

## File structure (what this plan creates / modifies)

**In the `brain` repo (`~/brain`, new):**
- `CLAUDE.md` — conventions: what `log/` vs `notes/` are, append-only rule, provenance, how the agent should read (index first).
- `index.md` — thin catalogue of `notes/` (starts near-empty).
- `log/.gitkeep`, `notes/.gitkeep` — keep empty dirs tracked.

**In the `dotai` repo (`~/dotai`, new):**
- `claude/CLAUDE.md` — copied from dotfiles, plus a new brain-awareness + recall section.
- `claude/context/*.md` — copied verbatim from dotfiles.
- `claude/settings.json` — copied verbatim (hooks/statusline paths stay `/home/atqa/.claude/...`, still valid).
- `claude/fetch-usage.sh`, `claude/statusline-command.sh`, `claude/hooks/context-warn.sh` — copied so the symlinked settings.json's referenced scripts resolve.
- `README.md` — one line describing the repo.

**In the `universe` repo (modify):**
- Create: `modules/home/dotai.nix` — `mkOutOfStoreSymlink` of `~/dotai/claude/*` into `~/.claude/*`.
- Create: `modules/home/brain-sync.nix` — systemd user service+timer auto-pulling `~/brain`.
- Modify: `modules/home/default.nix` — add the two new imports.
- Modify: `parts/apps.nix` — add `apps.brain-bootstrap` (clone dotai + brain).

---

## Task 1: Create the `brain` repo skeleton

**Files:**
- Create: `~/brain/CLAUDE.md`
- Create: `~/brain/index.md`
- Create: `~/brain/log/.gitkeep`
- Create: `~/brain/notes/.gitkeep`

- [ ] **Step 1: Make the directory tree and seed files**

```bash
mkdir -p ~/brain/log ~/brain/notes
touch ~/brain/log/.gitkeep ~/brain/notes/.gitkeep
```

- [ ] **Step 2: Write `~/brain/CLAUDE.md`**

```markdown
# brain

Canonical, cross-session, cross-machine memory for Claude. Source of truth is git.

## Layout

- `log/` — append-only session digests. One new uniquely-named file per session
  (timestamp + session id). Never edit or delete existing files here. Machine-
  written (Plan 2 Stop hook); may contain unverified claims. Low stakes.
- `notes/` — canon. Promoted from `log/` only through a reviewed PR. This is what
  you trust and cite. One fact (or tightly-related cluster) per file.
- `index.md` — thin catalogue of `notes/`: one line per note, `slug — one-line hook`.

## How to read

When a prompt might be answered from memory, read `index.md` first, then open only
the note(s) whose hook matches. Do not bulk-read `notes/` or `log/`. `log/` is
provenance, not canon — prefer `notes/`; consult `log/` only to verify a claim's source.

## Write rules

- `log/` is append-only; concurrent machines never conflict because filenames are unique.
- Nothing reaches `notes/` except via PR (the canon gate).
- Every digest records provenance (session id, cwd, files/commits touched).
```

- [ ] **Step 3: Write `~/brain/index.md`**

```markdown
# notes index

One line per note in `notes/`: `slug — one-line hook`. Read this first, then open
only the matching note.

<!-- entries added as notes/ is populated (Plan 3 migration) -->
```

- [ ] **Step 4: Verify the tree**

Run: `find ~/brain -type f | sort`
Expected: prints `~/brain/CLAUDE.md`, `~/brain/index.md`, `~/brain/log/.gitkeep`, `~/brain/notes/.gitkeep`

## Task 2: Publish the `brain` repo

**Files:** (none — git/gh operations on `~/brain`)

- [ ] **Step 1: Init and commit**

```bash
git -C ~/brain init
git -C ~/brain add -A
git -C ~/brain commit -m "seed brain skeleton"
```
Expected: one commit created, GPG-signed (global config).

- [ ] **Step 2: Create the GitHub repo (CONFIRM VISIBILITY FIRST)**

Before running, confirm with the user that `--private` is correct (default yes; brain holds work memory). Then:

```bash
gh repo create atqamz/brain --private --source=~/brain --remote=origin --push
```
Expected: repo created, `origin` set, `main` pushed. Verify: `gh repo view atqamz/brain --json visibility,defaultBranchRef`

- [ ] **Step 3: Verify push**

Run: `git -C ~/brain log --oneline -1 && git -C ~/brain remote -v`
Expected: the seed commit and `origin git@github.com:atqamz/brain.git` (or https).

## Task 3: Build the `dotai` repo from the dotfiles AI config

**Files:**
- Create: `~/dotai/claude/CLAUDE.md`
- Create: `~/dotai/claude/context/` (8 files copied)
- Create: `~/dotai/claude/settings.json`
- Create: `~/dotai/claude/fetch-usage.sh`, `~/dotai/claude/statusline-command.sh`, `~/dotai/claude/hooks/context-warn.sh`
- Create: `~/dotai/README.md`

- [ ] **Step 1: Copy the existing AI config verbatim**

```bash
mkdir -p ~/dotai/claude/hooks
cp ~/dotfiles/claude/.claude/CLAUDE.md          ~/dotai/claude/CLAUDE.md
cp -r ~/dotfiles/claude/.claude/context         ~/dotai/claude/context
cp ~/dotfiles/claude/.claude/settings.json      ~/dotai/claude/settings.json
cp ~/dotfiles/claude/.claude/fetch-usage.sh     ~/dotai/claude/fetch-usage.sh
cp ~/dotfiles/claude/.claude/statusline-command.sh ~/dotai/claude/statusline-command.sh
cp ~/dotfiles/claude/.claude/hooks/context-warn.sh ~/dotai/claude/hooks/context-warn.sh
```

- [ ] **Step 2: Verify the copy**

Run: `find ~/dotai -type f | sort`
Expected: `CLAUDE.md`, `context/{GIT,GITHUB,CODING,COMMUNICATION,SECURITY,CONTEXT,MEMORY,GRAPHIFY}.md`, `settings.json`, `fetch-usage.sh`, `statusline-command.sh`, `hooks/context-warn.sh` under `~/dotai/claude/`.

- [ ] **Step 3: Add the brain-awareness + recall section to `~/dotai/claude/CLAUDE.md`**

The current file ends with the `@PROJECTS.md` import block. Append this new section after it (do NOT remove the existing `@context/*.md` or `@PROJECTS.md` imports — they stay):

```markdown

# Brain — canonical memory

`~/brain` is the cross-session, cross-machine memory store (git source of truth,
auto-pulled by home-manager). When a prompt might be answered from past work — a
decision, an outcome, a non-obvious learning, regardless of current directory —
consult the brain before answering:

1. Read `~/brain/index.md` (thin catalogue).
2. Open only the `~/brain/notes/<slug>.md` whose hook matches. Cite it.

`notes/` is canon (trust it). `log/` is append-only provenance (verify, do not cite blindly).
Do not bulk-read the brain; index first, then the one matching note.
```

- [ ] **Step 4: Write `~/dotai/README.md`**

```markdown
# dotai

Claude operating config (CLAUDE.md, context rules, settings, hooks). Symlinked live
into `~/.claude` by the `universe` home-manager config (`modules/home/dotai.nix`)
via `mkOutOfStoreSymlink` — edits are instantly live, no rebuild. Stable; rarely
commits. Memory lives in the separate `brain` repo.
```

- [ ] **Step 5: Verify CLAUDE.md still parses its imports**

Run: `grep -c '^@context/' ~/dotai/claude/CLAUDE.md`
Expected: `8` (all eight context imports preserved). And `grep -q 'Brain — canonical memory' ~/dotai/claude/CLAUDE.md && echo OK` prints `OK`.

## Task 4: Publish the `dotai` repo

**Files:** (none — git/gh operations on `~/dotai`)

- [ ] **Step 1: Init and commit**

```bash
git -C ~/dotai init
git -C ~/dotai add -A
git -C ~/dotai commit -m "import claude config from dotfiles, add brain awareness"
```

- [ ] **Step 2: Create the GitHub repo**

dotai is public (no secrets; just operating config). Then:

```bash
gh repo create atqamz/dotai --public --source=~/dotai --remote=origin --push
```
Expected: repo created and pushed.

- [ ] **Step 3: Verify**

Run: `gh repo view atqamz/dotai --json visibility,defaultBranchRef && git -C ~/dotai remote -v`
Expected: visibility=PUBLIC, `origin` set.

## Task 5: Add the `dotai.nix` home-manager module (live symlink into `~/.claude`)

**Files:**
- Create: `modules/home/dotai.nix`
- Modify: `modules/home/default.nix`

- [ ] **Step 1: Write `modules/home/dotai.nix`**

```nix
{ config, ... }:
let
  dotai = "${config.home.homeDirectory}/dotai/claude";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  # Live symlinks into ~/.claude: editing the dotai checkout is instantly live,
  # no rebuild. Volatile ~/.claude state (projects/, auth, history) is untouched.
  home.file = {
    ".claude/CLAUDE.md".source = link "${dotai}/CLAUDE.md";
    ".claude/context".source = link "${dotai}/context";
    ".claude/settings.json".source = link "${dotai}/settings.json";
    ".claude/fetch-usage.sh".source = link "${dotai}/fetch-usage.sh";
    ".claude/statusline-command.sh".source = link "${dotai}/statusline-command.sh";
    ".claude/hooks/context-warn.sh".source = link "${dotai}/hooks/context-warn.sh";
  };
}
```

- [ ] **Step 2: Add the import to `modules/home/default.nix`**

In the `imports = [ ... ];` list, add `./dotai.nix` after `./secrets-sync.nix`:

```nix
  imports = [
    ./packages.nix
    ./caelestia.nix
    ./clipboard.nix
    ./hypr.nix
    ./cursor.nix
    ./yazi.nix
    ./secrets-sync.nix
    ./dotai.nix
  ];
```

- [ ] **Step 3: Evaluate the module (catches nix syntax/type errors without a full build)**

Run: `nix eval ~/universe#nixosConfigurations.pavg15.config.home-manager.users.atqa.home.file.".claude/CLAUDE.md".source 2>&1 | tail -3`
Expected: prints a store path or the mkOutOfStoreSymlink-resolved target string (an out-of-store symlink path under the home dir); NO evaluation error. If it errors with "attribute missing", the import in Step 2 is wrong.

## Task 6: Add the `brain-sync.nix` home-manager module (auto-pull `~/brain`)

**Files:**
- Create: `modules/home/brain-sync.nix`
- Modify: `modules/home/default.nix`

- [ ] **Step 1: Write `modules/home/brain-sync.nix`** (mirrors `secrets-sync.nix`)

```nix
{ pkgs, ... }:
let
  brain = "$HOME/brain";
  sync = pkgs.writeShellApplication {
    name = "brain-sync";
    runtimeInputs = with pkgs; [
      git
      coreutils
      libnotify
    ];
    text = ''
      brain="${brain}"
      if [ ! -d "$brain/.git" ]; then
        echo "brain not bootstrapped; run: nix run .#brain-bootstrap" >&2
        exit 0
      fi

      # Never clobber local work; a divergent worktree means a Stop-hook push
      # (Plan 2) or manual edit hasn't landed yet. Skip and notify, never reset.
      if [ -n "$(git -C "$brain" status --porcelain)" ]; then
        notify-send "brain-sync" "local brain changes uncommitted — skipping pull" || true
        echo "brain dirty, skipping pull" >&2
        exit 0
      fi

      git -C "$brain" pull --ff-only || \
        notify-send "brain-sync" "brain pull not fast-forward — diverged, skipping" || true
    '';
  };
in
{
  systemd.user.services.brain-sync = {
    Unit.Description = "Pull canonical brain memory";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/brain-sync";
    };
  };

  systemd.user.timers.brain-sync = {
    Unit.Description = "Periodic brain sync";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "1d";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
```

- [ ] **Step 2: Add the import to `modules/home/default.nix`**

```nix
  imports = [
    ./packages.nix
    ./caelestia.nix
    ./clipboard.nix
    ./hypr.nix
    ./cursor.nix
    ./yazi.nix
    ./secrets-sync.nix
    ./dotai.nix
    ./brain-sync.nix
  ];
```

- [ ] **Step 3: Evaluate**

Run: `nix eval ~/universe#nixosConfigurations.pavg15.config.systemd.user.services.brain-sync.Service.ExecStart 2>&1 | tail -3`
Expected: prints a `/nix/store/.../bin/brain-sync` path, no error.

## Task 7: Add the `brain-bootstrap` app (clone dotai + brain on a fresh machine)

**Files:**
- Modify: `parts/apps.nix`

- [ ] **Step 1: Add a `brain-bootstrap` app to `parts/apps.nix`**

Inside the `let ... in` of the `perSystem` block, after the existing `bootstrap` definition (and before the `in`), add a new `brainBootstrap`. The `rt` list already includes `git` and `gh`; reuse it. Add this definition:

```nix
      brainBootstrap = pkgs.writeShellApplication {
        name = "brain-bootstrap";
        runtimeInputs = rt;
        text = ''
          for repo in dotai brain; do
            dest="$HOME/$repo"
            if [ ! -d "$dest/.git" ]; then
              echo "==> cloning $repo"
              gh repo clone "atqamz/$repo" "$dest"
            else
              echo "==> updating $repo"
              git -C "$dest" pull --ff-only
            fi
          done
        '';
      };
```

- [ ] **Step 2: Register the app in the returned attrset**

In the `{ apps.secrets-export = ...; apps.secrets-bootstrap = ...; }` block, add:

```nix
      apps.brain-bootstrap = {
        type = "app";
        program = "${brainBootstrap}/bin/brain-bootstrap";
      };
```

- [ ] **Step 3: Evaluate the app**

Run: `nix eval ~/universe#apps.x86_64-linux.brain-bootstrap.program 2>&1 | tail -3`
Expected: prints a `/nix/store/.../bin/brain-bootstrap` path, no error.

## Task 8: Commit the `universe` changes

**Files:** (git operations on `~/universe`, branch `12-persistent-memory`)

- [ ] **Step 1: Confirm branch and stage**

```bash
git -C ~/universe branch --show-current   # must print 12-persistent-memory
git -C ~/universe add modules/home/dotai.nix modules/home/brain-sync.nix modules/home/default.nix parts/apps.nix
```

- [ ] **Step 2: Commit**

```bash
git -C ~/universe commit -m "wire dotai and brain into home-manager"
```
Expected: GPG-signed commit. (The plan doc under `docs/superpowers/plans/` can be added in the same or a separate commit.)

- [ ] **Step 3: Run treefmt / pre-commit**

Run: `cd ~/universe && nix fmt 2>&1 | tail -5`
Expected: no formatting changes left uncommitted (if it reformats, `git add -A && git commit --amend --no-edit`). Pre-commit hooks must pass (never `--no-verify`).

## Task 9: Build and verify the full config evaluates

**Files:** (none — verification)

- [ ] **Step 1: Build the host config (does not switch)**

Run: `nixos-rebuild build --flake ~/universe#pavg15 2>&1 | tail -15`
Expected: builds to completion, produces a `result` symlink, no evaluation/build error. (This proves the three module/app additions are sound before any deploy.)

- [ ] **Step 2: Sanity-check the activation will create the symlinks**

Run: `nix eval --raw ~/universe#nixosConfigurations.pavg15.config.home-manager.users.atqa.home.file.".claude/settings.json".source`
Expected: prints `/home/atqa/dotai/claude/settings.json` (the out-of-store target).

## Deploy & acceptance (user action on `pavg15`, after the PR merges)

These are performed by the user on the live host once the `universe` PR is merged; they are the acceptance tests for this plan.

- [ ] **Bootstrap the repos:** `cd ~/universe && nix run .#brain-bootstrap` → `~/dotai` and `~/brain` cloned (or already present). Confirm `gh auth status` is logged in first.
- [ ] **Switch:** `git -C ~/universe pull --ff-only && sudo nixos-rebuild switch --flake ~/universe#pavg15`.
- [ ] **Symlinks live:** `ls -l ~/.claude/CLAUDE.md ~/.claude/context ~/.claude/settings.json` → all point into `~/dotai/claude/`. Any prior manual symlinks were moved to `*.bak`.
- [ ] **Live edit, no rebuild:** append a comment line to `~/dotai/claude/CLAUDE.md`, start a new Claude session → the edit is present immediately (no `nixos-rebuild`).
- [ ] **Volatile `~/.claude` untouched:** `~/.claude/projects/`, `~/.claude/.credentials.json`, history still present and unmanaged.
- [ ] **Brain auto-pull works:** `systemctl --user start brain-sync.service && journalctl --user -u brain-sync.service -n 20` → pulls `~/brain` ff-only, no error; `systemctl --user list-timers | grep brain-sync` shows the timer armed.
- [ ] **Cross-machine sync:** commit a trivial note on machine A and push; on machine B (or after `brain-sync` runs) the file appears under `~/brain` with no token cost.
- [ ] **On-demand recall:** from an unrelated directory, ask a question answerable by a `~/brain/notes/` entry → the agent reads `index.md`, opens the matching note, and cites it (proves global awareness + index-first recall). (Meaningful once Plan 3 migrates real notes; until then, drop a test note manually.)

## Out of scope for this plan (deferred to sibling plans)

This is the first of four sequenced plans for issue #12. Execute in this order:

1. **`2026-06-11-brain-foundation.md`** (this plan) — repos + symlink + sync + bootstrap; index-only recall, manual capture.
2. **`2026-06-11-brain-qmd-recall.md`** — qmd hybrid retrieval (NixOS validation spike first) + `bin/brain-recall` (qmd-backed, grep fallback) + qmd MCP registration. This plan creates `bin/brain-recall`; the foundation ships without it (index-first recall via the CLAUDE.md instruction works on its own).
3. **`2026-06-11-brain-capture.md`** — Stop hook auto-capture → `brain/log/`.
4. **`2026-06-11-brain-migration.md`** — migrate auto-memory → `brain/notes/`, retire graphify (timer + MCP), make `dotfiles` AI-free.

Still deferred beyond all four:

- **Promotion PR timer (lint agent `log/`→`notes/`)** — separate follow-up; reuses the graphify-sync local-`claude -p` pattern. Needs `log/` populated by the Stop hook first; the canon gate works manually meanwhile.
- **`dotfiles` → `dotfiles-universe` repo rename** — broader repo migration, not part of standing up the brain.

This plan leaves the dotfiles AI config in place; HM `.bak` renames keep the old `~/.claude` symlinks recoverable until the migration plan removes them.
