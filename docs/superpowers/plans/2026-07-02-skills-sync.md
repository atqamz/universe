# Cross-Agent Skills Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one `bunx skills` sync path for OpenCode and Claude Code, remove duplicate plugin-based skill setup, and keep real RTK binary integrations for Claude and OpenCode.

**Architecture:** `/home/atqa/dotagents/skills/manifest.txt` is the canonical skills source list.
`/home/atqa/universe/modules/home/skills-sync.nix` installs those skills into OpenCode and Claude Code global skill directories and runs daily via user systemd.
RTK remains outside the skills manifest and is initialized with its native Claude and OpenCode hooks.

**Tech Stack:** Nix home-manager module, `pkgs.writeShellApplication`, `bunx`, Vercel `skills` CLI, user systemd timer, Claude plugin CLI, RTK CLI.

## Global Constraints

- Do not include `rtk-ai/rtk` in the skills manifest.
- Keep real RTK binary behavior through existing `rtk` package, `@RTK.md`, and `Prefer rtk <cmd>` guidance in `/home/atqa/dotagents/AGENTS.md`.
- Initialize RTK for OpenCode with `rtk init -g --opencode`.
- Keep existing Claude RTK hook healthy with `rtk init -g --auto-patch` if verification shows it missing or stale.
- Keep always-on caveman and ponytail policy in `/home/atqa/dotagents/AGENTS.md`.
- Run `bunx skills` commands sequentially, never parallel, to avoid Bun cache extraction races.
- Use `bunx --yes skills add "$source" -g -a opencode -a claude-code --skill '*' -y` for each manifest source.
- Restart OpenCode and Claude Code after changing skills, plugins, or config because both load these at startup.

---

## File Structure

- Create `/home/atqa/dotagents/skills/manifest.txt`.
  It lists one skills repository per line and is read by `skills-sync`.
- Create `/home/atqa/universe/modules/home/skills-sync.nix`.
  It defines the `skills-sync` command plus `skills-sync.service` and `skills-sync.timer`.
- Modify `/home/atqa/universe/modules/home/default.nix`.
  It imports `./skills-sync.nix` and stops importing `./claude-plugins.nix`.
- Delete `/home/atqa/universe/modules/home/claude-plugins.nix`.
  Its plugin update job is replaced by `skills-sync` plus direct runtime plugin cleanup.
- Modify `/home/atqa/dotagents/opencode/opencode.json`.
  It removes OpenCode plugin entries replaced by `skills-sync` and RTK's own OpenCode plugin.
- Runtime cleanup removes `/home/atqa/.config/opencode/skills/*`, `/home/atqa/.config/opencode/plugins/caveman/`, and Claude plugins `caveman@caveman`, `ponytail@ponytail`, `superpowers@claude-plugins-official`.

---

### Task 1: Add The Shared Skills Manifest

**Files:**
- Create: `/home/atqa/dotagents/skills/manifest.txt`

**Interfaces:**
- Consumes: no prior task output.
- Produces: newline-separated source list for `skills-sync`.

- [ ] **Step 1: Create manifest directory**

Run:

```bash
mkdir -p /home/atqa/dotagents/skills
```

Expected: command exits `0`.

- [ ] **Step 2: Write manifest**

Create `/home/atqa/dotagents/skills/manifest.txt` with exactly:

```text
juliusbrussee/caveman
dietrichgebert/ponytail
obra/superpowers
pbakaus/impeccable
kunchenguid/gh-axi
```

- [ ] **Step 3: Verify RTK skills are excluded**

Run:

```bash
grep -n 'rtk-ai/rtk' /home/atqa/dotagents/skills/manifest.txt || true
```

Expected: no output.

- [ ] **Step 4: Commit manifest**

Run:

```bash
cd /home/atqa/dotagents
```

Expected: commit succeeds and includes only `skills/manifest.txt`.

---

### Task 2: Add Skills Sync Module And Remove Claude Plugin Timer

**Files:**
- Create: `/home/atqa/universe/modules/home/skills-sync.nix`
- Modify: `/home/atqa/universe/modules/home/default.nix`
- Delete: `/home/atqa/universe/modules/home/claude-plugins.nix`

**Interfaces:**
- Consumes: `/home/atqa/dotagents/skills/manifest.txt` from Task 1.
- Produces: `skills-sync` command, `skills-sync.service`, and `skills-sync.timer`.

- [ ] **Step 1: Write `skills-sync.nix`**

Create `/home/atqa/universe/modules/home/skills-sync.nix` with exactly:

```nix
{ pkgs, ... }:
let
  manifest = "$HOME/dotagents/skills/manifest.txt";
  sync = pkgs.writeShellApplication {
    name = "skills-sync";
    runtimeInputs = with pkgs; [
      bun
      coreutils
    ];
    text = ''
      manifest="${manifest}"

      if [ ! -f "$manifest" ]; then
        echo "skills-sync: missing manifest: $manifest" >&2
        exit 1
      fi

      while IFS= read -r source || [ -n "$source" ]; do
        case "$source" in
          ""|\#*) continue ;;
        esac

        echo "skills-sync: installing $source"
        bunx --yes skills add "$source" -g -a opencode -a claude-code --skill '*' -y
      done < "$manifest"
    '';
  };
in
{
  home.packages = [ sync ];

  systemd.user.services.skills-sync = {
    Unit.Description = "Sync global agent skills";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/skills-sync";
    };
  };

  systemd.user.timers.skills-sync = {
    Unit.Description = "Periodic global agent skills sync";
    Timer = {
      OnStartupSec = "3min";
      OnUnitActiveSec = "1d";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
```

- [ ] **Step 2: Update home imports**

In `/home/atqa/universe/modules/home/default.nix`, remove:

```nix
    ./claude-plugins.nix
```

Add `./skills-sync.nix` after `./dotagents-sync.nix`:

```nix
    ./dotagents-sync.nix
    ./skills-sync.nix
    ./passmenu.nix
```

- [ ] **Step 3: Delete old Claude plugin updater module**

Run:

```bash
rm /home/atqa/universe/modules/home/claude-plugins.nix
```

Expected: file no longer exists.

- [ ] **Step 4: Format and check Nix**

Run:

```bash
cd /home/atqa/universe
nix fmt
nix flake check --no-build
```

Expected: `nix fmt` exits `0` and `nix flake check --no-build` ends with `all checks passed!`.

- [ ] **Step 5: Commit Nix changes**

Run:

```bash
cd /home/atqa/universe
```

Expected: commit succeeds and includes the new module, default import change, and old module deletion.

---

### Task 3: Remove Replaced OpenCode Plugin Entries

**Files:**
- Modify: `/home/atqa/dotagents/opencode/opencode.json`

**Interfaces:**
- Consumes: Task 2 `skills-sync` installs `caveman`, `ponytail`, and `superpowers` as skills.
- Produces: OpenCode config no longer loads duplicate skill plugins.

- [ ] **Step 1: Remove the plugin key**

In `/home/atqa/dotagents/opencode/opencode.json`, remove this full block:

```json
  "plugin": [
    "./plugins/caveman/plugin.js",
    "superpowers@git+https://github.com/obra/superpowers.git",
    "@dietrichgebert/ponytail"
  ],
```

Keep the JSON valid by ensuring `compaction` is followed by `permission` with one comma between them.

- [ ] **Step 2: Validate JSON**

Run:

```bash
nix shell nixpkgs#jq -c jq empty /home/atqa/dotagents/opencode/opencode.json
```

Expected: no output and exit `0`.

- [ ] **Step 3: Confirm removed plugin strings are gone**

Run:

```bash
grep -nE 'plugins/caveman|superpowers@git|dietrichgebert/ponytail' /home/atqa/dotagents/opencode/opencode.json || true
```

Expected: no output.

- [ ] **Step 4: Commit OpenCode config cleanup**

Run:

```bash
cd /home/atqa/dotagents
```

Expected: commit succeeds and includes only `opencode/opencode.json`.

---

### Task 4: Apply, Clean Runtime Duplicates, Run Sync, And Initialize RTK OpenCode

**Files:**
- Runtime cleanup: `/home/atqa/.config/opencode/skills/*`
- Runtime cleanup: `/home/atqa/.config/opencode/plugins/caveman/`
- Runtime cleanup: Claude plugins `caveman@caveman`, `ponytail@ponytail`, `superpowers@claude-plugins-official`

**Interfaces:**
- Consumes: `skills-sync` from Task 2 and OpenCode plugin cleanup from Task 3.
- Produces: OpenCode and Claude global skills installed by `skills` CLI, RTK OpenCode plugin installed, old plugin duplicates removed.

- [ ] **Step 1: Apply system config**

Run:

```bash
cd /home/atqa/universe
sudo nixos-rebuild switch --flake .#pavg15
```

Expected: command exits `0` and reports a new configuration path.

- [ ] **Step 2: Remove old OpenCode skills and caveman plugin**

Run:

```bash
rm -rf /home/atqa/.config/opencode/skills/*
rm -rf /home/atqa/.config/opencode/plugins/caveman
```

Expected: the old caveman plugin directory is absent and the OpenCode skills directory is empty.

- [ ] **Step 3: Remove old Claude plugins**

Run:

```bash
claude plugin remove caveman@caveman || true
claude plugin remove ponytail@ponytail || true
claude plugin remove superpowers@claude-plugins-official || true
claude plugin prune || true
```

Expected: each plugin is removed or already absent.

- [ ] **Step 4: Initialize RTK hooks for Claude and OpenCode**

Run:

```bash
rtk init -g --auto-patch
rtk init -g --opencode
```

Expected: Claude hook remains configured and RTK installs an OpenCode plugin.

- [ ] **Step 5: Run skills sync manually**

Run:

```bash
skills-sync
```

Expected: command exits `0` and prints one `skills-sync: installing <source>` line for each manifest source.

- [ ] **Step 6: Verify OpenCode skills**

Run:

```bash
test -f /home/atqa/.config/opencode/skills/caveman/SKILL.md
```

Expected: all tests exit `0`.

- [ ] **Step 7: Verify Claude skills**

Run:

```bash
test -f /home/atqa/.claude/skills/caveman/SKILL.md
```

Expected: all tests exit `0`.

- [ ] **Step 8: Verify RTK and timer**

Run:

```bash
rtk --version
rtk gain
rtk init --show
systemctl --user list-timers skills-sync.timer --no-pager
```

Expected: `rtk gain` shows token savings stats, `rtk init --show` reports OpenCode plugin configured, and timer output contains `skills-sync.timer`.

- [ ] **Step 9: Verify Claude plugins are gone**

Run:

```bash
claude plugin list | grep -E 'caveman|ponytail|superpowers' || true
```

Expected: no output for those plugin names.

---

### Task 5: Ship Changes

**Files:**
- Repos: `/home/atqa/dotagents`, `/home/atqa/universe`

**Interfaces:**
- Consumes: commits from Tasks 1, 2, and 3.
- Produces: merged PRs and updated local `master` branches.

- [ ] **Step 1: Push and PR dotagents**

Run from the dotagents feature branch:

```bash
cd /home/atqa/dotagents
- Add shared skills manifest for OpenCode and Claude Code
- Remove duplicate OpenCode skill plugin entries

## Test plan
- [x] jq validates opencode.json
- [ ] skills-sync installs all manifest sources"
```

Expected: GitHub prints a PR URL.

- [ ] **Step 2: Push and PR universe**

Run from the universe feature branch:

```bash
cd /home/atqa/universe
- Add skills-sync command using bunx skills add
- Add user systemd service and daily timer
- Remove Claude plugin updater replaced by skills-sync

## Test plan
- [x] nix fmt
- [x] nix flake check --no-build
- [ ] nixos-rebuild switch
- [ ] skills-sync installs OpenCode and Claude Code skills
- [ ] rtk init --show reports OpenCode plugin configured"
```

Expected: GitHub prints a PR URL.

- [ ] **Step 3: Merge PRs after checks pass**

Run for the dotagents PR after checks pass:

```bash
cd /home/atqa/dotagents
gh pr merge --merge
```

Run for the universe PR after checks pass:

```bash
cd /home/atqa/universe
gh pr merge --merge
```

Expected: both PRs merge successfully.

- [ ] **Step 4: Clean local branches**

Run in dotagents, replacing `skills-sync-dotagents` with the branch name used during execution if different:

```bash
cd /home/atqa/dotagents
git checkout master
git pull --ff-only
git branch -d skills-sync-dotagents
```

Run in universe, replacing `skills-sync-universe` with the branch name used during execution if different:

```bash
cd /home/atqa/universe
git checkout master
git pull --ff-only
git branch -d skills-sync-universe
```

Expected: local master contains merged changes and feature branch is deleted.

---

## Self-Review

- Spec coverage: manifest, bunx sync, sequential execution, timer, OpenCode cleanup, Claude plugin cleanup, always-on caveman and ponytail, real RTK preservation, RTK OpenCode hook, and verification are covered.
- Placeholder scan: no placeholder markers, undefined commands, or missing file paths remain.
- Interface consistency: Task 2 reads the manifest from Task 1, Task 4 consumes `skills-sync`, and Task 5 ships the repo changes.
