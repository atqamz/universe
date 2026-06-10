# Remove GNOME Dependencies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every GNOME store path from the pavg15 closure by not installing nautilus and gnome-keyring, and wire the replacements: yazi (file manager), hyprpolkitagent (polkit agent), no Secret Service provider (deferred to #4).

**Architecture:** Three one-concern module edits plus one new Home-Manager module, on branch `1-remove-gnome-deps`. The closure changes by design — verification is `nix flake check` + toplevel build + an empty `grep -iE 'gnome|nautilus'` over the new closure, not closure-path equality.

**Tech Stack:** NixOS flake (flake-parts), Home-Manager as NixOS module, yazi HM module, hyprpolkitagent HM module.

**Spec:** `docs/superpowers/specs/2026-06-10-remove-gnome-deps-design.md`

---

### Task 1: Drop gnome-keyring from the system

**Files:**
- Modify: `modules/nixos/desktop.nix`

- [ ] **Step 1: Remove the gnome-keyring line**

In `modules/nixos/desktop.nix`, delete this line from the `services` attrset (leave `printing.enable` and everything else untouched):

```nix
    gnome.gnome-keyring.enable = true;
```

The `services` attrset becomes:

```nix
  services = {
    greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland'";
        user = "greeter";
      };
    };

    printing.enable = true;
  };
```

`security.polkit.enable = true;` stays — polkit is freedesktop, not GNOME, and is the backend for the agent added in Task 3.

- [ ] **Step 2: Verify evaluation**

Run: `nix flake check`
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/desktop.nix
git commit -m "drop gnome-keyring"
```

---

### Task 2: Replace nautilus with yazi

**Files:**
- Create: `modules/home/yazi.nix`
- Modify: `modules/home/default.nix`
- Modify: `modules/home/packages.nix`

- [ ] **Step 1: Create the yazi module**

Create `modules/home/yazi.nix` with exactly:

```nix
_: {
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
  };
}
```

- [ ] **Step 2: Import it**

In `modules/home/default.nix`, add `./yazi.nix` to the `imports` list, keeping the list alphabetical if it currently is (current imports: `./caelestia.nix ./cursor.nix ./hypr.nix ./packages.nix` — insert `./yazi.nix` last).

- [ ] **Step 3: Remove nautilus from packages**

In `modules/home/packages.nix`, delete the line:

```nix
      nautilus
```

Nothing else in the list changes.

- [ ] **Step 4: Verify evaluation**

Run: `nix flake check`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add modules/home/yazi.nix modules/home/default.nix modules/home/packages.nix
git commit -m "replace nautilus with yazi"
```

---

### Task 3: Add hyprpolkitagent and point Super+E at yazi

**Files:**
- Modify: `modules/home/hypr.nix`

- [ ] **Step 1: Enable the agent and swap the file explorer**

In `modules/home/hypr.nix`:

(a) Change the let-binding:

```nix
      fileExplorer = "nautilus";
```

to:

```nix
      fileExplorer = "alacritty -e yazi";
```

(b) Add the agent at the top level of the returned attrset (sibling of `wayland.windowManager.hyprland`), so the file starts:

```nix
_: {
  services.hyprpolkitagent.enable = true;

  # configType "hyprlang": the HM 26.05 default lua backend has no `bindel`
  # and wants split bind args, so comma-strings would not parse.
  wayland.windowManager.hyprland =
```

If the Home-Manager option is named differently in the locked HM revision, find the real name with `nix repl` or the HM manual for the locked rev — the option must create a `hyprpolkitagent.service` systemd user unit. Do not fall back to a raw package + manual exec-once without flagging it.

- [ ] **Step 2: Verify evaluation**

Run: `nix flake check`
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add modules/home/hypr.nix
git commit -m "add hyprpolkitagent and open yazi from super+e"
```

---

### Task 4: Verify the closure is GNOME-free

**Files:** none (verification only)

- [ ] **Step 1: Build the new toplevel**

Run:
```bash
nix build --no-link --print-out-paths .#nixosConfigurations.pavg15.config.system.build.toplevel
```
Expected: exit 0. Record the new store path (it differs from the old `vg95dph7...` baseline by design).

- [ ] **Step 2: Scan the closure**

Run:
```bash
nix path-info -r <new-toplevel-path> | grep -iE "gnome|nautilus|seahorse"
```
Expected: empty output (exit 1 from grep). If any path remains, run `nix why-depends <new-toplevel-path> <offending-path>` and report the chain — do not silently accept it.

- [ ] **Step 3: Confirm the polkit agent unit exists**

Run:
```bash
nix path-info -r <new-toplevel-path> | grep hyprpolkitagent
```
Expected: at least one `hyprpolkitagent` store path present.

- [ ] **Step 4: Confirm yazi is present**

Run:
```bash
nix path-info -r <new-toplevel-path> | grep -E "\-yazi-"
```
Expected: at least one yazi store path.

- [ ] **Step 5: Report**

No commit. Report the new toplevel path and the three scan results to the controller.
