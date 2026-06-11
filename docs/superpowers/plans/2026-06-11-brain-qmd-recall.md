# Brain qmd Retrieval + brain-recall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make local hybrid retrieval over `~/brain` work: validate qmd on NixOS (spike first), package it declaratively, register it as a global MCP server in `dotai`'s `settings.json`, build the index over the brain, and ship `bin/brain-recall` (qmd-backed with a grep fallback so recall functions even if qmd is down).

**Architecture:** qmd (`@tobilu/qmd`, MIT, Node ≥ 22) does BM25 (FTS5) + vector (sqlite-vec) + local-GGUF rerank. Its native deps (`better-sqlite3`, `node-llama-cpp`) are exactly the kind that break on NixOS, so a **validation spike runs before any wiring**. If the spike passes, qmd is provided through an FHS-env wrapper (the robust path for native-node + downloaded GGUF on NixOS), registered as an MCP server in the version-controlled `dotai/claude/settings.json`, and the index (~2GB GGUF + sqlite) lives machine-local in `~/.cache/qmd`. `bin/brain-recall` is the shell entry point: it queries qmd when available and falls back to `grep` over `index.md`/`notes/` when not.

**Tech Stack:** qmd (npm), Nix `buildFHSEnv` / `writeShellApplication`, home-manager, Claude Code MCP (`settings.json` `mcpServers`), bash, `jq`.

**Depends on:** `2026-06-11-brain-foundation.md` (the `dotai`/`brain` repos and `~/brain` must exist; `modules/home/dotai.nix` symlinks `dotai/claude/*` into `~/.claude`).

---

## Context the engineer must know

- `universe` flake at `/home/atqa/universe`, branch `12-persistent-memory`, host `pavg15`, nixpkgs `nixos-unstable`.
- `~/brain` exists (foundation plan): `log/`, `notes/`, `index.md`, `CLAUDE.md`. `~/dotai/claude/` holds the AI config, symlinked into `~/.claude`.
- **qmd CLI corrections (carry these exactly):**
  - There is **no `qmd update --pull` flag**. Pull is a per-collection `update-cmd` (set to `git pull`) that `qmd update` runs first.
  - The CLI subcommand is `qmd multi-get` (hyphen); the MCP tool is `multi_get` (underscore).
  - MCP tools exposed: `query`, `get`, `multi_get`, `status`.
- **MCP registration is version-controlled.** Claude Code reads a `mcpServers` map from `settings.json`. Because `dotai/claude/settings.json` is symlinked to `~/.claude/settings.json` (foundation plan), adding qmd there makes it declarative and machine-portable — unlike `~/.claude.json` (volatile, untracked, holds auth). Do NOT put qmd in `~/.claude.json`.
- **NixOS + native node modules.** Global `npm install` of packages with native addons usually fails on NixOS because the dynamic linker can't find `libstdc++`/`libc` at the expected paths, and `node-llama-cpp` downloads/builds a native backend at install/run time. An FHS env (`pkgs.buildFHSEnv`) gives a normal `/usr/lib`-style filesystem so these "just work"; this is the expected install path. `buildNpmPackage` is the alternative but needs a vendored `package-lock.json` and patched native builds — heavier; only fall back to it if the FHS approach fails in the spike.
- **Models + index are machine-local, never committed.** `~/.cache/qmd/` holds ~2GB of GGUF weights and the sqlite index, rebuilt per machine.
- **Graceful degradation is a hard requirement.** If qmd is absent or `qmd status` fails, `brain-recall` must still return useful hits via grep. The agent's recall instruction (foundation plan, in `dotai/claude/CLAUDE.md`) already works index-first without qmd.
- **Global git rules:** GPG sign always; never `--no-verify`; imperative lowercase commit subjects, no trailing period, no planning jargon. `dotai` commits go to `atqamz/dotai` `main`; `universe` changes go on branch `12-persistent-memory`.

---

## File structure (what this plan creates / modifies)

**In `dotai` (`~/dotai`):**
- Create: `claude/bin/brain-recall` — qmd-backed recall CLI with grep fallback (executable).
- Modify: `claude/settings.json` — add the `mcpServers.qmd` entry.

**In `universe`:**
- Create: `modules/home/qmd.nix` — provides the `qmd` command (FHS-env wrapper) as a home package; gated on the spike outcome.
- Modify: `modules/home/default.nix` — import `./qmd.nix`.
- Modify: `modules/home/dotai.nix` — add the `bin/brain-recall` symlink.
- Modify: `parts/apps.nix` — extend `brain-bootstrap` to run `qmd collection add` + `qmd embed` after clone (build the index).

**Spike artifact:**
- Create: `docs/superpowers/notes/qmd-nixos-spike.md` — records what worked (install method, versions, commands) or the packaging gap if it failed. This is the decision record the rest of the plan branches on.

---

## Task 1: NixOS validation spike — does qmd run at all?

**Files:**
- Create: `docs/superpowers/notes/qmd-nixos-spike.md`

This task is exploratory by design. Run the commands, observe, and **write down the outcome**. Tasks 2+ assume the spike PASSED via the FHS path; the decision gate at the end of this task says what to do if it didn't.

- [ ] **Step 1: Try qmd inside an FHS env with Node 22**

```bash
cat > /tmp/qmd-fhs.nix <<'EOF'
let pkgs = import <nixpkgs> {}; in
(pkgs.buildFHSEnv {
  name = "qmd-fhs";
  targetPkgs = p: with p; [ nodejs_22 python3 gcc gnumake stdenv.cc.cc.lib zlib openssl ];
  runScript = "bash";
}).env
EOF
nix-shell /tmp/qmd-fhs.nix --run '
  export NPM_CONFIG_PREFIX=$HOME/.cache/qmd-npm
  npm install -g @tobilu/qmd 2>&1 | tail -20
  $HOME/.cache/qmd-npm/bin/qmd --version
'
```
Expected (PASS): prints a qmd version with no native-module load error (`Error: ... .node ... cannot open shared object file` = FAIL).

- [ ] **Step 2: Exercise the heavy paths — embed + query**

```bash
nix-shell /tmp/qmd-fhs.nix --run '
  export NPM_CONFIG_PREFIX=$HOME/.cache/qmd-npm
  export PATH=$HOME/.cache/qmd-npm/bin:$PATH
  mkdir -p /tmp/qmd-spike/notes
  echo "# spike note\nThe brain stores cross-session memory." > /tmp/qmd-spike/notes/spike.md
  qmd collection add spike --path /tmp/qmd-spike 2>&1 | tail -10
  qmd embed 2>&1 | tail -20          # downloads ~2GB GGUF on first run
  qmd query "what does the brain store" 2>&1 | tail -20
'
```
Expected (PASS): `qmd embed` downloads the model and completes; `qmd query` returns the spike note as a ranked hit. `node-llama-cpp` failing to load its backend = FAIL.

- [ ] **Step 2b: If Step 1 or 2 FAILED, try the prebuilt-binary escape hatch**

`node-llama-cpp` ships prebuilt binaries; the failure is usually the linker. Retry inside the same FHS shell with the loader hint:

```bash
nix-shell /tmp/qmd-fhs.nix --run '
  export NPM_CONFIG_PREFIX=$HOME/.cache/qmd-npm
  export PATH=$HOME/.cache/qmd-npm/bin:$PATH
  export LD_LIBRARY_PATH=$(nix eval --raw nixpkgs#stdenv.cc.cc.lib)/lib:$LD_LIBRARY_PATH
  qmd embed 2>&1 | tail -20
'
```
Expected: if this is what fixes it, record `LD_LIBRARY_PATH` as a required wrapper env in the spike note (Task 2 bakes it into the FHS wrapper).

- [ ] **Step 3: Record the outcome**

Write `docs/superpowers/notes/qmd-nixos-spike.md` with: PASS or FAIL; the exact install method that worked (FHS env contents, any `LD_LIBRARY_PATH`/env needed); qmd version; Node version; observed model download size; and any deviation from the commands above.

```markdown
# qmd on NixOS — spike result (2026-06-11)

**Verdict:** PASS | FAIL

**Install method that worked:** <FHS env with targetPkgs [...]; npm -g prefix ~/.cache/qmd-npm; env: ...>

**Versions:** qmd <x>, node <y>. Model: <name>, ~<n>GB.

**Commands proven:** `qmd collection add`, `qmd embed`, `qmd query` (paste the working invocations).

**Gaps / caveats:** <none | what broke and the workaround | hard blocker>
```

- [ ] **DECISION GATE:**
  - **PASS** → continue to Task 2 (package qmd, register MCP, wire index, qmd-backed `brain-recall`).
  - **FAIL (hard blocker)** → SKIP Tasks 2, 4, 5. Do Task 3 (`brain-recall`) in **grep-only** form (omit the qmd branch), commit it, and stop. Recall stays index+grep until qmd is packageable. The foundation recall instruction already works without qmd. Note the gap in the spike file and surface it to the user.

## Task 2: Package qmd declaratively (`modules/home/qmd.nix`)

**Files:**
- Create: `modules/home/qmd.nix`
- Modify: `modules/home/default.nix`

> Assumes Task 1 PASSED. Use the exact `targetPkgs` / env the spike recorded; the list below is the spike's expected starting point — reconcile it with `qmd-nixos-spike.md` before committing.

- [ ] **Step 1: Write `modules/home/qmd.nix`**

```nix
{ pkgs, ... }:
let
  # FHS env so node-llama-cpp / better-sqlite3 find a normal libc/libstdc++.
  # Reconcile targetPkgs + any LD_LIBRARY_PATH with docs/superpowers/notes/qmd-nixos-spike.md.
  qmdFhs = pkgs.buildFHSEnv {
    name = "qmd";
    targetPkgs =
      p: with p; [
        nodejs_22
        python3
        gcc
        gnumake
        stdenv.cc.cc.lib
        zlib
        openssl
      ];
    runScript = pkgs.writeShellScript "qmd-run" ''
      export NPM_CONFIG_PREFIX="$HOME/.cache/qmd-npm"
      export PATH="$HOME/.cache/qmd-npm/bin:$PATH"
      # First run installs qmd into the machine-local npm prefix; cheap no-op after.
      if ! command -v qmd >/dev/null 2>&1; then
        echo "==> installing @tobilu/qmd (first run)" >&2
        npm install -g @tobilu/qmd >&2
      fi
      exec qmd "$@"
    '';
  };
in
{
  home.packages = [ qmdFhs ];
}
```

- [ ] **Step 2: Import it in `modules/home/default.nix`**

Add `./qmd.nix` to the `imports` list:

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
    ./qmd.nix
  ];
```

- [ ] **Step 3: Evaluate**

Run: `nix eval ~/universe#nixosConfigurations.pavg15.config.home-manager.users.atqa.home.packages --apply 'ps: builtins.length ps' 2>&1 | tail -3`
Expected: prints an integer (package count), no evaluation error.

- [ ] **Step 4: Build the wrapper and prove `qmd` runs from the Nix-provided command**

Run: `nix build ~/universe#nixosConfigurations.pavg15.config.home-manager.users.atqa.home.packages --no-link 2>&1 | tail -5` then, after a `nixos-rebuild switch` on the host (deploy section), `qmd --version`.
Expected: builds; on the host `qmd --version` prints the version (first invocation installs into `~/.cache/qmd-npm`).

## Task 3: `bin/brain-recall` — qmd-backed CLI with grep fallback

**Files:**
- Create: `~/dotai/claude/bin/brain-recall`
- Modify: `modules/home/dotai.nix` (add the symlink)

- [ ] **Step 1: Write `~/dotai/claude/bin/brain-recall`**

```bash
#!/usr/bin/env bash
# brain-recall: query the canonical brain (~/brain).
# Uses qmd when available; falls back to grep over index.md + notes/ when not.
set -euo pipefail

brain="${BRAIN_DIR:-$HOME/brain}"
query="$*"

if [ -z "$query" ]; then
  echo "usage: brain-recall <query>" >&2
  exit 2
fi

# Prefer qmd (hybrid ranked retrieval) when it is installed AND healthy.
if command -v qmd >/dev/null 2>&1 && qmd status >/dev/null 2>&1; then
  qmd query "$query" --collection brain
  exit 0
fi

# Fallback: grep the index first (cheap), then the note bodies. Case-insensitive,
# show file + matching line so the agent can open the right note.
echo "# brain-recall (grep fallback — qmd unavailable)"
echo "## index hits"
grep -in -- "$query" "$brain/index.md" 2>/dev/null || echo "(none)"
echo "## note hits"
grep -rin --include='*.md' -- "$query" "$brain/notes/" 2>/dev/null || echo "(none)"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x ~/dotai/claude/bin/brain-recall
```

- [ ] **Step 3: Test the grep fallback (works without qmd)**

```bash
mkdir -p ~/brain/notes
echo "cross-session memory lives in the brain" > ~/brain/notes/_recall-test.md
BRAIN_DIR=~/brain PATH=/usr/bin:/bin ~/dotai/claude/bin/brain-recall "cross-session"
rm ~/brain/notes/_recall-test.md
```
Expected: prints the grep-fallback header and a `note hits` line citing `_recall-test.md`. (Forcing `PATH` without `qmd` exercises the fallback branch deterministically.)

- [ ] **Step 4: Add the `bin/brain-recall` symlink to `modules/home/dotai.nix`**

In the `home.file` attrset, add the line:

```nix
    ".claude/bin/brain-recall".source = link "${dotai}/bin/brain-recall";
```

so the block reads:

```nix
  home.file = {
    ".claude/CLAUDE.md".source = link "${dotai}/CLAUDE.md";
    ".claude/context".source = link "${dotai}/context";
    ".claude/settings.json".source = link "${dotai}/settings.json";
    ".claude/fetch-usage.sh".source = link "${dotai}/fetch-usage.sh";
    ".claude/statusline-command.sh".source = link "${dotai}/statusline-command.sh";
    ".claude/hooks/context-warn.sh".source = link "${dotai}/hooks/context-warn.sh";
    ".claude/bin/brain-recall".source = link "${dotai}/bin/brain-recall";
  };
```

- [ ] **Step 5: Evaluate the new symlink**

Run: `nix eval --raw ~/universe#nixosConfigurations.pavg15.config.home-manager.users.atqa.home.file.".claude/bin/brain-recall".source 2>&1 | tail -3`
Expected: prints `/home/atqa/dotai/claude/bin/brain-recall`, no error.

## Task 4: Register qmd as an MCP server in `dotai/claude/settings.json`

**Files:**
- Modify: `~/dotai/claude/settings.json`

> Assumes Task 1 PASSED. Skip if the spike was a hard blocker.

- [ ] **Step 1: Inspect the current settings.json shape**

```bash
jq 'keys' ~/dotai/claude/settings.json
```
Expected: lists existing top-level keys (e.g. `hooks`, `statusLine`, `model`, `enabledPlugins`). Note whether `mcpServers` already exists.

- [ ] **Step 2: Add the `qmd` MCP server with `jq`**

qmd runs as a stdio MCP server. The `qmd` command is the Nix FHS wrapper from Task 2 (on `PATH` after switch). Use `mcp` as the stdio subcommand (confirm against the spike's `qmd --help`; adjust if the subcommand differs).

```bash
tmp=$(mktemp)
jq '.mcpServers = (.mcpServers // {}) + {
  "qmd": {
    "command": "qmd",
    "args": ["mcp", "--collection", "brain"]
  }
}' ~/dotai/claude/settings.json > "$tmp" && mv "$tmp" ~/dotai/claude/settings.json
```

- [ ] **Step 3: Verify the JSON is valid and the entry landed**

Run: `jq -e '.mcpServers.qmd.command == "qmd"' ~/dotai/claude/settings.json`
Expected: prints `true`, exit 0 (valid JSON, entry present).

## Task 5: Build the index on bootstrap (`parts/apps.nix`)

**Files:**
- Modify: `parts/apps.nix`

> Assumes Task 1 PASSED. The `brain-bootstrap` app already clones `dotai` + `brain` (foundation plan). Extend it to register the brain collection and embed.

- [ ] **Step 1: Add `qmd` to the bootstrap runtime and the embed step**

The `brain-bootstrap` app (foundation plan Task 7) loops over `dotai`/`brain`. After the clone loop, append the collection-add + embed. qmd is provided as a home package, not in `rt`; reference it on `PATH` (present post-switch) and no-op gracefully if absent so bootstrap never hard-fails on a host where the spike didn't pass:

```nix
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

          if command -v qmd >/dev/null 2>&1; then
            echo "==> building brain index (qmd)"
            qmd collection add brain --path "$HOME/brain" --update-cmd "git pull" 2>/dev/null || true
            qmd embed
          else
            echo "==> qmd not installed; skipping index build (grep recall still works)"
          fi
```

- [ ] **Step 2: Evaluate**

Run: `nix eval ~/universe#apps.x86_64-linux.brain-bootstrap.program 2>&1 | tail -3`
Expected: prints a store path, no error.

## Task 6: Commit

**Files:** (git on `~/dotai` and `~/universe`)

- [ ] **Step 1: Commit the `dotai` changes**

```bash
git -C ~/dotai add claude/bin/brain-recall claude/settings.json
git -C ~/dotai commit -m "add brain-recall cli and register qmd mcp server"
git -C ~/dotai push
```

- [ ] **Step 2: Commit the `universe` changes** (branch `12-persistent-memory`)

```bash
git -C ~/universe add modules/home/qmd.nix modules/home/default.nix modules/home/dotai.nix parts/apps.nix docs/superpowers/notes/qmd-nixos-spike.md docs/superpowers/plans/2026-06-11-brain-qmd-recall.md
git -C ~/universe commit -m "package qmd and wire brain index build"
cd ~/universe && nix fmt 2>&1 | tail -5
```
Expected: GPG-signed commits; `nix fmt` leaves nothing uncommitted (amend if it reformats).

## Task 7: Build verify

- [ ] **Step 1: Build the host config**

Run: `nixos-rebuild build --flake ~/universe#pavg15 2>&1 | tail -15`
Expected: builds to completion, no error.

## Deploy & acceptance (user action on `pavg15`, after the PR merges)

- [ ] **Switch:** `git -C ~/universe pull --ff-only && sudo nixos-rebuild switch --flake ~/universe#pavg15`.
- [ ] **qmd present:** `qmd --version` prints a version (first run installs into `~/.cache/qmd-npm`).
- [ ] **Index builds:** `nix run ~/universe#brain-bootstrap` → `qmd embed` completes; `qmd query "memory" --collection brain` returns ranked hits.
- [ ] **MCP available in-session:** start a new Claude session, confirm the `qmd` MCP tools (`query`/`get`/`multi_get`/`status`) are listed.
- [ ] **brain-recall via qmd:** `brain-recall "cross-session memory"` returns ranked qmd hits.
- [ ] **Graceful fallback:** with qmd stopped/uninstalled, `brain-recall "cross-session memory"` still returns grep hits over `index.md`/`notes/`.

## Out of scope (other plans)

- Auto-capture Stop hook → `brain/log/` — `2026-06-11-brain-capture.md`.
- Migration of auto-memory → `notes/` and graphify retirement — `2026-06-11-brain-migration.md`.
- Promotion PR timer (lint agent `log/`→`notes/`) — deferred follow-up.
