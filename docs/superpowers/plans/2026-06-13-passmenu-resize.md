# passmenu + mod+shift+LMB resize Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `passmenu` launcher (mod+alt+P) backed by `pass` + fuzzel, and a `mod+shift+LMB` window-resize bind.

**Architecture:** New home-manager module `modules/home/passmenu.nix` ships a `writeShellApplication` wrapper that lists `~/.password-store` entries through `fuzzel --dmenu` and copies the selected secret with `pass show -c`. Two binds added to `modules/home/hypr.nix` (one `bind`, one `bindm`). No existing bind modified.

**Tech Stack:** Nix (home-manager, flake-parts), `pkgs.writeShellApplication`, `pass`, `fuzzel`, `wl-clipboard`, Hyprland hyprlang config.

---

### Task 1: passmenu module

**Files:**
- Create: `modules/home/passmenu.nix`
- Modify: `modules/home/default.nix:13` (add `./passmenu.nix` to imports)

- [ ] **Step 1: Create the module**

`modules/home/passmenu.nix`:

```nix
{ pkgs, ... }:
let
  # pass has no launcher of its own and caelestia ships no password feature, so
  # this wrapper bridges the two: list store entries, pick via fuzzel, then
  # `pass show -c` copies the first line to the Wayland clipboard (pass uses
  # wl-copy when present) and auto-clears after 45s. Empty/absent store exits
  # quietly instead of opening an empty menu.
  passmenu = pkgs.writeShellApplication {
    name = "passmenu";
    runtimeInputs = with pkgs; [ pass fuzzel wl-clipboard ];
    text = ''
      store="''${PASSWORD_STORE_DIR:-$HOME/.password-store}"
      [ -d "$store" ] || exit 0

      entry=$(
        find "$store" -name '*.gpg' -type f -printf '%P\n' 2>/dev/null \
          | sed 's/\.gpg$//' \
          | sort \
          | fuzzel --dmenu
      ) || exit 0

      [ -n "$entry" ] || exit 0
      pass show -c "$entry"
    '';
  };
in
{
  home.packages = [ passmenu pkgs.pass ];
}
```

- [ ] **Step 2: Register the module**

In `modules/home/default.nix`, add `./passmenu.nix` to the `imports` list (e.g. after `./qmd.nix`):

```nix
    ./qmd.nix
    ./passmenu.nix
```

- [ ] **Step 3: git add (flake purity — new file must be tracked before build sees it)**

Run:
```bash
git add modules/home/passmenu.nix modules/home/default.nix
```

- [ ] **Step 4: Commit**

```bash
git commit -S -m "home: add passmenu (pass + fuzzel) launcher"
```

---

### Task 2: Hyprland binds

**Files:**
- Modify: `modules/home/hypr.nix` (`bind` block ~line 50, `bindm` block ~line 97)

- [ ] **Step 1: Add passmenu bind**

In `modules/home/hypr.nix`, in the `bind = [ ... ]` block, after the existing
`"${mod}, period, exec, caelestia emoji --picker"` line (line 50), add:

```nix
          "${mod} ALT, P, exec, passmenu"
```

- [ ] **Step 2: Add resize bind**

In the `bindm = [ ... ]` block (lines 97-100), after
`"${mod}, mouse:273, resizewindow"`, add:

```nix
          "${mod} SHIFT, mouse:272, resizewindow"
```

- [ ] **Step 3: Commit**

```bash
git add modules/home/hypr.nix
git commit -S -m "hypr: bind passmenu (mod+alt+P) and mod+shift+LMB resize"
```

---

### Task 3: Build, deploy, verify

- [ ] **Step 1: Build toplevel**

Run:
```bash
NIX_CONFIG="access-tokens = github.com=$(gh auth token)" \
  nix build .#nixosConfigurations.pavg15.config.system.build.toplevel
```
Expected: builds green (shellcheck runs on the wrapper via writeShellApplication).

- [ ] **Step 2: Push + open PR**

```bash
git push -u origin 18-passmenu-resize
gh pr create --assignee atqamz --title "passmenu + mod+shift+LMB resize" \
  --body "## Summary
- add passmenu launcher (mod+alt+P) via pass + fuzzel
- bind mod+shift+LMB to resizewindow

Partial for #18, #20 — first small slice; caelestia dispatch repair, gestures, and scripts deferred.

## Test plan
- pavg15 toplevel builds green
- mod+alt+P lists pass entries, selection copies + auto-clears 45s
- mod+shift+LMB resizes focused window"
```

- [ ] **Step 3: Merge + deploy (only on user go)**

```bash
gh pr merge --merge --delete-branch
ssh pavg15 'sudo nixos-rebuild switch --flake github:atqamz/universe#pavg15 --refresh'
```

- [ ] **Step 4: Verify on pavg15**

- `mod+alt+P` → fuzzel lists password entries; selecting one copies the secret (auto-clears 45s).
- `mod+shift+LMB` drag resizes the focused window.

Assumes a populated `~/.password-store` on pavg15.
