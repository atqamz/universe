# Align Keybindings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Curate the Hyprland keybindings in `modules/home/hypr.nix` for the `pavg15` host so they drive the real upstream `caelestia-shell` and its CLI, dropping binds that depended on the dotfiles script ecosystem universe lacks.

**Architecture:** All binds stay native to the existing `configType = "hyprlang"` backend — every line is a Hyprland dispatcher, a `global, caelestia:<name>` shortcut, an `exec` of the `caelestia` CLI, or a `bindel`. Two new runtime deps (`fuzzel`, `cliphist`) satisfy `caelestia clipboard`/`caelestia emoji`'s own shell-outs, and a `wl-paste --watch` user service populates the clipboard history so the picker is not empty.

**Tech Stack:** Nix / Home-Manager (NixOS flake-parts, host `pavg15`), Hyprland (hyprlang config backend), caelestia-shell + its CLI, systemd user units.

---

## Background context for the implementer

- This is a **NixOS + Home-Manager flake**. There is no unit-test framework for the
  window-manager config. The "test" for a config change is: render the generated
  Hyprland config text and assert on its contents, then do a full build. The
  red-green loop below uses a fast eval that renders the config without building
  the whole system:

  ```bash
  nix eval --raw .#nixosConfigurations.pavg15.config.home-manager.users.atqa.xdg.configFile.\"hypr/hyprland.conf\".text
  ```

  This prints the exact `bind=`/`bindel=`/`bindm=` lines HM will write. Grepping it
  is the assertion mechanism throughout this plan.

- **Commit style (repo convention + user GIT.md):** imperative, lowercase start, no
  trailing period, **no** conventional-commit type prefix (`feat:`/`fix:`), **no**
  `Co-Authored-By` trailer. GPG signing stays on (never `--no-gpg-sign`). One logical
  change per commit. Work happens on the current branch `2-align-keybindings`; do not
  push or open a PR unless asked.

- **Files touched:**
  - Modify: `modules/home/hypr.nix` — rewrite `bind` + `bindel`, drop the `browser`
    and `editor` `let`-bindings.
  - Modify: `modules/home/packages.nix` — add `fuzzel`, `cliphist`.
  - Create: `modules/home/clipboard.nix` — the `cliphist store` user service
    (one concern per unit; keeps `hypr.nix` argument-free).
  - Modify: `modules/home/default.nix` — import `./clipboard.nix`.

---

## Task 1: Add fuzzel + cliphist to the Home-Manager closure

`caelestia clipboard` and `caelestia emoji` shell out to `fuzzel --dmenu` and (for
clipboard) `cliphist`. Neither is in the caelestia closure, so universe must provide
them. `wl-clipboard`, `hyprpicker`, `playerctl`, `grim`, `slurp` are already present.

**Files:**
- Modify: `modules/home/packages.nix:10-26`

- [ ] **Step 1: Assert the packages are absent (red)**

Run:
```bash
nix eval --json --apply 'map (p: p.pname or p.name or "")' \
  .#nixosConfigurations.pavg15.config.home-manager.users.atqa.home.packages \
  | grep -E 'fuzzel|cliphist' || echo "ABSENT"
```
Expected: prints `ABSENT` (neither package in the closure yet).

- [ ] **Step 2: Add the packages**

Edit `modules/home/packages.nix`. Add `fuzzel` and `cliphist` to the list. The list is
not alphabetised; place them next to the other Wayland clipboard/UI tools. After the
edit the `home.packages` list reads:

```nix
  home.packages = lib.mkAfter (
    with pkgs;
    [
      alacritty
      zed-editor
      inputs.zen-browser.packages.${pkgs.system}.default
      bibata-cursors
      jq
      hyprpicker
      grim
      slurp
      wl-clipboard
      cliphist
      fuzzel
      brightnessctl
      playerctl
      pavucontrol
    ]
  );
```

- [ ] **Step 3: Assert the packages are present (green)**

Run:
```bash
nix eval --json --apply 'map (p: p.pname or p.name or "")' \
  .#nixosConfigurations.pavg15.config.home-manager.users.atqa.home.packages \
  | grep -E 'fuzzel|cliphist'
```
Expected: prints two matching lines containing `fuzzel` and `cliphist`.

- [ ] **Step 4: Commit**

```bash
git add modules/home/packages.nix
git commit -m "add fuzzel and cliphist for caelestia clipboard and emoji"
```

---

## Task 2: Add the cliphist clipboard-history user service

The clipboard picker is empty unless something watches the Wayland selection and feeds
it to `cliphist store`. Add a `wl-paste --watch cliphist store` user service bound to
the graphical session (uwsm owns the session; `caelestia.nix` already targets
`graphical-session.target`). Put it in its own module so `hypr.nix` stays
argument-free (`_:`) and the unit owns exactly one concern.

**Files:**
- Create: `modules/home/clipboard.nix`
- Modify: `modules/home/default.nix:2-8`

- [ ] **Step 1: Create the service module**

Create `modules/home/clipboard.nix`:

```nix
{ pkgs, ... }:
{
  # caelestia clipboard reads cliphist's history; nothing populates it unless
  # wl-paste watches the selection. Bind to the graphical session uwsm owns.
  systemd.user.services.cliphist = {
    Unit = {
      Description = "Clipboard history (cliphist via wl-paste)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
```

- [ ] **Step 2: Import the module**

Edit `modules/home/default.nix`. Add `./clipboard.nix` to `imports`:

```nix
  imports = [
    ./packages.nix
    ./caelestia.nix
    ./clipboard.nix
    ./hypr.nix
    ./cursor.nix
    ./yazi.nix
  ];
```

- [ ] **Step 3: Assert the unit renders with the right ExecStart (green)**

Run:
```bash
nix eval --raw .#nixosConfigurations.pavg15.config.home-manager.users.atqa.systemd.user.services.cliphist.Service.ExecStart
```
Expected: a store path string ending in `/bin/wl-paste --watch /nix/store/...-cliphist-*/bin/cliphist store`.

- [ ] **Step 4: Commit**

```bash
git add modules/home/clipboard.nix modules/home/default.nix
git commit -m "add cliphist clipboard-history user service"
```

---

## Task 3: Confirm the caelestia CLI / shortcut forms before editing binds

The design flags two things as **do-not-guess, verify against the installed
caelestia**: the audio IPC function names and the emoji picker flag. `pavg15` is the
live host running this caelestia, so verify there (or on the build itself). Do this
BEFORE Task 4 so the bind strings match reality. **No file edits in this task** — it
only resolves the exact strings Task 4 hard-codes.

**Files:** none (verification only).

- [ ] **Step 1: List the caelestia global shortcuts**

Run (on the running pavg15 session):
```bash
hyprctl globalshortcuts | grep -i caelestia
```
Expected: confirms the `caelestia:` names the binds use exist —
`launcher`, `session`, `lock`, `brightnessUp`, `brightnessDown`,
`mediaNext`, `mediaPrev`, `mediaToggle`, `screenshot`, `screenshotClip`.
If a name differs, note it and adjust the matching bind in Task 4.

- [ ] **Step 2: Confirm the audio IPC function names**

Run:
```bash
caelestia shell ipc call audio
```
Expected: prints the callable functions for the `audio` target. Confirm the exact
names for volume up / volume down / mute toggle. This plan assumes
`incrementVolume`, `decrementVolume`, `toggleMute`. If the installed version names
them differently (e.g. `setVolume`/`mute`), record the real names — Task 4 Step 2
uses them verbatim.

- [ ] **Step 3: Confirm the emoji picker flag**

Run:
```bash
caelestia emoji --help
```
Expected: shows the picker flag. This plan assumes `--picker`. If it is `-p` only,
use that in Task 4. Likewise confirm `caelestia clipboard` takes no required args.

- [ ] **Step 4: Record findings**

Write the confirmed strings (audio fn names + emoji flag + any renamed shortcut) as a
short note in the PR/commit body for Task 4, or inline as a comment if one deviated.
No commit in this task.

---

## Task 4: Rewrite the Hyprland binds for caelestia

Replace the `bind` and `bindel` lists in `modules/home/hypr.nix` with the curated map,
and drop the now-unused `browser`/`editor` `let`-bindings. `bindm` stays as-is. Use the
exact strings confirmed in Task 3 where they differ from the assumptions below.

Key changes from the current config:
- `mod, M` (exit) removed — logout via `mod, L` caelestia session menu.
- `mod, B` (browser) and `mod, C` (editor) removed — launched from the caelestia launcher;
  `mod, C` is reused for the `hyprpicker` color picker.
- `mod, Q` was killactive → now `mod SHIFT, Q`; `mod, Q` becomes togglefloating.
- `mod, V` was togglefloating → now `caelestia clipboard`.
- The raw `wpctl`/`brightnessctl` `bindel` block becomes the caelestia equivalents
  (volume via IPC, brightness via `global`) so the OSD shows consistently.
- New: window grouping/splitting, swap/resize, monitor focus, scroll-to-switch-workspace,
  emoji picker, media transport keys, screenshots.

**Files:**
- Modify: `modules/home/hypr.nix:8-12` (the `let` block) and `modules/home/hypr.nix:43-81` (`bind` + `bindel`).

- [ ] **Step 1: Assert the old binds are present and the new ones absent (red)**

Run:
```bash
GEN='nix eval --raw .#nixosConfigurations.pavg15.config.home-manager.users.atqa.xdg.configFile.\"hypr/hyprland.conf\".text'
eval "$GEN" | grep -E 'bind=SUPER, B,|bind=SUPER, M, exit|bind=SUPER, X,|bindel=,XF86AudioRaiseVolume, exec, wpctl' && echo "OLD STILL PRESENT"
eval "$GEN" | grep -E 'caelestia:lock|swapwindow|caelestia clipboard' || echo "NEW ABSENT"
```
Expected: prints the old-bind lines followed by `OLD STILL PRESENT`, then `NEW ABSENT`.

- [ ] **Step 2: Rewrite `hypr.nix`**

Edit `modules/home/hypr.nix`. Change the `let` block to drop `browser` and `editor`:

```nix
  wayland.windowManager.hyprland =
    let
      terminal = "alacritty";
      fileExplorer = "alacritty -e yazi";
      mod = "SUPER";
    in
```

Then replace the `bind` list (currently lines 43-68) with:

```nix
        bind = [
          "${mod}, Return, exec, ${terminal}"
          "${mod}, E, exec, ${fileExplorer}"
          "${mod}, C, exec, hyprpicker -a"

          "${mod}, Space, global, caelestia:launcher"
          "${mod}, L, global, caelestia:session"
          "${mod} SHIFT, L, global, caelestia:lock"
          "${mod}, V, exec, caelestia clipboard"
          "${mod}, period, exec, caelestia emoji --picker"

          "${mod} SHIFT, Q, killactive,"
          "${mod}, Q, togglefloating,"
          "${mod}, F, fullscreen,"
          "${mod}, J, togglesplit,"
          "${mod}, P, pseudo,"
          "${mod} SHIFT, left, swapwindow, l"
          "${mod} SHIFT, right, swapwindow, r"
          "${mod} SHIFT, up, swapwindow, u"
          "${mod} SHIFT, down, swapwindow, d"
          "${mod} CTRL, up, resizeactive, 0 -50"
          "${mod} CTRL, down, resizeactive, 0 50"
          "${mod}, G, togglegroup,"
          "${mod} ALT, G, moveoutofgroup,"
          "${mod} ALT, left, moveintogroup, l"
          "${mod} ALT, right, moveintogroup, r"
          "${mod} ALT, up, moveintogroup, u"
          "${mod} ALT, down, moveintogroup, d"
          "${mod} CTRL, left, changegroupactive, b"
          "${mod} CTRL, right, changegroupactive, f"

          "${mod}, left, movefocus, l"
          "${mod}, right, movefocus, r"
          "${mod}, up, movefocus, u"
          "${mod}, down, movefocus, d"
          "CTRL ALT, Tab, focusmonitor, +1"
          "${mod}, mouse_down, workspace, e+1"
          "${mod}, mouse_up, workspace, e-1"
          "${mod}, 1, workspace, 1"
          "${mod}, 2, workspace, 2"
          "${mod}, 3, workspace, 3"
          "${mod}, 4, workspace, 4"
          "${mod}, 5, workspace, 5"
          "${mod} SHIFT, 1, movetoworkspace, 1"
          "${mod} SHIFT, 2, movetoworkspace, 2"
          "${mod} SHIFT, 3, movetoworkspace, 3"
          "${mod} SHIFT, 4, movetoworkspace, 4"
          "${mod} SHIFT, 5, movetoworkspace, 5"

          ",XF86AudioNext, global, caelestia:mediaNext"
          ",XF86AudioPrev, global, caelestia:mediaPrev"
          ",XF86AudioPlay, global, caelestia:mediaToggle"
          ",Print, global, caelestia:screenshotClip"
          "${mod} SHIFT, S, global, caelestia:screenshot"
        ];
```

Then replace the `bindel` list (currently lines 75-81) with:

```nix
        bindel = [
          ",XF86AudioRaiseVolume, exec, caelestia shell ipc call audio incrementVolume"
          ",XF86AudioLowerVolume, exec, caelestia shell ipc call audio decrementVolume"
          ",XF86AudioMute, exec, caelestia shell ipc call audio toggleMute"
          ",XF86MonBrightnessUp, global, caelestia:brightnessUp"
          ",XF86MonBrightnessDown, global, caelestia:brightnessDown"
        ];
```

Leave `bindm` (lines 70-73) unchanged.

> If Task 3 found different audio function names or a different emoji flag, substitute
> them in the four affected lines above (`incrementVolume`/`decrementVolume`/`toggleMute`,
> `emoji --picker`) before continuing.

- [ ] **Step 3: Assert the new binds render and the old ones are gone (green)**

Run:
```bash
GEN='nix eval --raw .#nixosConfigurations.pavg15.config.home-manager.users.atqa.xdg.configFile.\"hypr/hyprland.conf\".text'
eval "$GEN" | grep -E 'caelestia:lock|caelestia:session|swapwindow, l|caelestia clipboard|caelestia emoji --picker|caelestia:brightnessUp|caelestia shell ipc call audio incrementVolume'
echo "--- these must print NOTHING ---"
eval "$GEN" | grep -E 'bind=SUPER, B,|bind=SUPER, M, exit|bind=SUPER, X,|bindel=,XF86AudioRaiseVolume, exec, wpctl|bindel=,XF86MonBrightnessUp, exec, brightnessctl' && echo "FAIL: old bind survived"
```
Expected: the first command prints the matching new lines; nothing prints after the
`--- ... ---` marker (no `FAIL:` line).

- [ ] **Step 4: Commit**

```bash
git add modules/home/hypr.nix
git commit -m "align hyprland keybindings with caelestia features"
```

---

## Task 5: Full build + flake check (definition of done)

The fast evals above confirm content; this task confirms the whole host still builds.

**Files:** none (verification only).

- [ ] **Step 1: flake check**

Run:
```bash
nix flake check
```
Expected: completes with no error.

- [ ] **Step 2: Build the host toplevel**

Run:
```bash
nix build .#nixosConfigurations.pavg15.config.system.build.toplevel
```
Expected: builds successfully (produces `./result`).

- [ ] **Step 3: Final content + closure assertions**

Run:
```bash
GEN='nix eval --raw .#nixosConfigurations.pavg15.config.home-manager.users.atqa.xdg.configFile.\"hypr/hyprland.conf\".text'
# new binds present:
eval "$GEN" | grep -qE 'caelestia:lock' && echo "OK lock"
eval "$GEN" | grep -qE 'caelestia clipboard' && echo "OK clipboard"
eval "$GEN" | grep -qE 'caelestia shell ipc call audio' && echo "OK audio ipc"
# removed binds absent:
eval "$GEN" | grep -qE 'bind=SUPER, B,' || echo "OK no browser bind"
eval "$GEN" | grep -qE 'bind=SUPER, M, exit' || echo "OK no exit bind"
eval "$GEN" | grep -qE 'XF86AudioRaiseVolume, exec, wpctl' || echo "OK no raw wpctl bindel"
# deps + service:
nix eval --json --apply 'map (p: p.pname or p.name or "")' \
  .#nixosConfigurations.pavg15.config.home-manager.users.atqa.home.packages \
  | grep -E 'fuzzel|cliphist'
nix eval --raw .#nixosConfigurations.pavg15.config.home-manager.users.atqa.systemd.user.services.cliphist.Service.ExecStart
```
Expected: six `OK ...` lines, the two package matches, and the cliphist ExecStart store path.

- [ ] **Step 4: (optional, on pavg15) activate and smoke-test**

After the host is rebuilt/switched on `pavg15`, sanity-check the live binds:
`mod, Space` opens the launcher, `mod, V` opens the clipboard picker (non-empty after
copying something — proves the `cliphist` service runs), `mod, period` opens the emoji
picker, volume/brightness keys show the caelestia OSD. Deployment itself is out of scope
for this plan unless asked.

---

## Out of scope (from the design spec)

- Cross-machine reconciliation of the dotfiles lua config.
- dotfiles script-dependent features with no caelestia equivalent (workspace grid +
  `wsrows` submap, `text-extract`, notification toggles, monitor scaling, touchpad/idle/
  nightlight toggles, keyboard-brightness, zoom, power-profile, refresh).
- Unbound caelestia CLI extras: `caelestia record`, `wallpaper`, `scheme`.
- Secret Service / clipboard persistence policy.
