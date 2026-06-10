# Universe — Align Keybindings

Date: 2026-06-10
Status: approved (design)
Issues: #2

## Purpose

Curate the Hyprland keybindings declared in `modules/home/hypr.nix` for the
`pavg15` host. Issue #2 is framed as "adjust keybindings with existing on
dotfiles/dotnix/dotmachines", but the goal is **not** a literal copy. The
canonical reference (`~/dotfiles/hypr/.config/hypr/hyprland.lua`) targets a
different shell and a script ecosystem that universe does not have, so this is
a deliberate curation: keep what fits, add what universe can support natively,
drop what depends on machinery universe lacks.

## Findings that shape the design

- **The two machines run different shells.** dotfiles `shell.qml` is a
  hand-rolled quickshell config that "avoids caelestia's compiled Qt6 plugin
  (not packaged on Fedora)". universe runs the real upstream
  `caelestia-shell`. dotfiles binds invoke `qs ipc call <target>` against that
  hand-rolled shell and ~40 custom scripts in `~/dotfiles/scripts/`; none of
  those scripts exist in universe.
- **dotmachines / dotnix carry no keybindings.** dotmachines only installs
  Hyprland via Ansible; dotnix has no Hypr config. The sole keybinding source
  is the dotfiles lua file.
- **Use caelestia's own features where they exist.** The real caelestia ships
  bindable global shortcuts and a CLI that cover most of what the dotfiles
  scripts did:
  - Global shortcuts (`global, caelestia:<name>`): `launcher`, `session`,
    `lock`, `dashboard`, `sidebar`, `mediaToggle/Prev/Next/Stop`,
    `brightnessUp/Down` (with OSD), `screenshot`, `screenshotFreeze`,
    `screenshotClip`, `screenshotFreezeClip`, `clearNotifs`.
  - CLI (`programs.caelestia.cli.enable` already on): `caelestia clipboard`,
    `caelestia emoji`, `caelestia shell ipc call <target> <fn>` (e.g. the
    `audio` target for volume with OSD), plus `record`, `wallpaper`, `scheme`.
  - caelestia bundles `emojis.txt`; it has **no** color-picker (use the
    already-installed `hyprpicker`).
- **caelestia clipboard/emoji require `fuzzel` + `cliphist`.** Both CLI
  subcommands shell out to `fuzzel --dmenu` and (for clipboard) `cliphist`.
  These are not in the caelestia closure, so universe must provide them — this
  is satisfying caelestia's own runtime dependency, not building a bespoke
  picker. No `bemoji`, no `wtype` (caelestia's emoji is copy-only).
- **Backend stays `hyprlang`.** Every chosen bind is a native dispatcher,
  `global`, `exec`, or `bindel` line — all parse under the existing
  `configType = "hyprlang"`. No move to the lua backend (which universe
  rejected because HM 26.05's lua backend lacks `bindel`).

## Decisions

### Final keybinding map

Variables: `mod = SUPER`, `terminal = alacritty`, `fileExplorer = "alacritty -e yazi"`.

**Apps**

| Key | Action |
|---|---|
| `mod, Return` | `exec, alacritty` |
| `mod, E` | `exec, alacritty -e yazi` |
| `mod, C` | `exec, hyprpicker -a` (color picker) |

(`mod, B` browser and the `mod, C` editor bind are removed; the editor and
browser launch from the caelestia launcher.)

**Shell / caelestia**

| Key | Action |
|---|---|
| `mod, Space` | `global, caelestia:launcher` |
| `mod, L` | `global, caelestia:session` |
| `mod SHIFT, L` | `global, caelestia:lock` |
| `mod, V` | `exec, caelestia clipboard` |
| `mod, period` | `exec, caelestia emoji --picker` |

**Window**

| Key | Action |
|---|---|
| `mod SHIFT, Q` | `killactive` |
| `mod, Q` | `togglefloating` |
| `mod, F` | `fullscreen` |
| `mod, J` | `togglesplit` |
| `mod, P` | `pseudo` |
| `mod SHIFT, left/right/up/down` | `swapwindow, l/r/u/d` |
| `mod CTRL, up/down` | `resizeactive, 0 -50` / `0 50` |
| `mod, G` | `togglegroup` |
| `mod ALT, G` | `moveoutofgroup` |
| `mod ALT, left/right/up/down` | `moveintogroup, l/r/u/d` |
| `mod CTRL, left/right` | `changegroupactive, b` / `f` |

The current `mod, M` (exit Hyprland) bind is removed — exit/logout is reachable
through the caelestia session menu (`mod, L`).

**Focus / workspace**

| Key | Action |
|---|---|
| `mod, left/right/up/down` | `movefocus, l/r/u/d` |
| `CTRL ALT, Tab` | `focusmonitor, +1` |
| `mod, mouse_down` / `mouse_up` | `workspace, e+1` / `e-1` |
| `mod, 1..5` | `workspace, 1..5` |
| `mod SHIFT, 1..5` | `movetoworkspace, 1..5` |

Workspace count stays at 5 (not expanded to dotfiles' 10).

**Media / hardware** (`bindel` where repeat/locked matters)

| Key | Action |
|---|---|
| `XF86MonBrightnessUp` / `Down` | `global, caelestia:brightnessUp` / `brightnessDown` |
| `XF86AudioRaiseVolume` / `Lower` / `Mute` | `exec, caelestia shell ipc call audio incrementVolume` / `decrementVolume` / `toggleMute` |
| `XF86AudioNext` / `Prev` / `Play` | `global, caelestia:mediaNext` / `mediaPrev` / `mediaToggle` |
| `Print` | `global, caelestia:screenshotClip` |
| `mod SHIFT, S` | `global, caelestia:screenshot` |

The raw `wpctl` / `brightnessctl` `bindel` block is replaced by the caelestia
equivalents so the on-screen display appears consistently.

**Mouse** (`bindm`, unchanged)

| Key | Action |
|---|---|
| `mod, mouse:272` | `movewindow` |
| `mod, mouse:273` | `resizewindow` |

### Dependencies

Add to the Home-Manager closure:

- `fuzzel` and `cliphist` — required by `caelestia clipboard` and
  `caelestia emoji`.
- A systemd user service running `wl-paste --watch cliphist store` so the
  clipboard history is populated (clipboard picker is empty without it).

`hyprpicker`, `wl-clipboard`, `playerctl`, `grim`, `slurp` are already present.
No `bemoji`, no `wtype`.

## Changes

1. `modules/home/hypr.nix` — rewrite the `bind`, `bindel` lists per the map
   above; drop the `editor`, `browser` let-bindings (now unused); keep
   `terminal`, `fileExplorer`, `mod`; keep `bindm` as-is.
2. `modules/home/packages.nix` — add `fuzzel`, `cliphist`.
3. `modules/home/` — add the `wl-paste --watch cliphist store` systemd user
   service (in `hypr.nix` alongside the session concern, or a small dedicated
   module — implementer's call, one concern per unit).

## Verification (definition of done)

- `nix flake check` passes.
- `nix build .#nixosConfigurations.pavg15.config.system.build.toplevel`
  succeeds; the generated `hm_hyprhyprland.conf` contains the new binds and no
  longer contains `bind=SUPER, B`, `bind=SUPER, M, exit`, or the raw
  `wpctl`/`brightnessctl` `bindel` lines.
- `fuzzel` and `cliphist` appear in the built closure; the
  `cliphist store` systemd user unit is present in the HM generation.
- Implementation-time verification (do not guess): confirm the exact CLI form
  of `caelestia shell ipc call audio <fn>` (and the real volume-control
  function names — `incrementVolume`/`decrementVolume`/mute) and the
  `caelestia emoji` picker flag (`--picker` vs `-p`) against the installed
  caelestia version before committing. Adjust the binds to match.

## Out of scope

- Cross-machine reconciliation of the dotfiles lua config itself — this issue
  only curates universe's binds.
- The dotfiles script-dependent features with no caelestia equivalent:
  workspace-pair/grid + the `wsrows` submap, `text-extract`,
  `notification-{time,battery,weather}`, `monitor-internal`/`scaling`,
  `toggle-{touchpad,idle,nightlight}`, `keyboard-brightness`, `zoom`,
  `power-profile`, `refresh`.
- Optional caelestia CLI features left unbound for now: `caelestia record`
  (screen recording), `caelestia wallpaper`, `caelestia scheme`.
- Secret Service / clipboard-manager persistence policy — unrelated to #2.
