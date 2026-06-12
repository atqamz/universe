# Universe — passmenu + mod+shift+LMB resize

Date: 2026-06-13
Status: approved (design)
Issues: #18, #20 (both partial — this is a deliberately small first slice)

## Purpose

Issue #18 asks to import un-migrated Hyprland keybinds from the old
`~/dotfiles` config (notably a 3-finger workspace gesture, `mod+shift+LMB`
resize, and `passmenu` at `mod+alt+p`), and #20 asks to make the upstream
`caelestia-shell` fully come in. Research showed both are large and coupled:
the old config targets a hand-rolled quickshell fork plus ~25 system scripts,
and caelestia 1.0.0 moved most of its bindable actions out of Hyprland
GlobalShortcuts into `caelestia shell ipc call`, leaving several current
`hypr.nix` binds dead.

This slice intentionally covers **only passmenu and the LMB-resize bind**.
Everything else — the caelestia dispatch repair, the 3-finger gesture, drawer
toggles, workspace→monitor, and the broader script fleet — is deferred to
later issues. #18 and #20 stay open.

## Findings that shape the design

- **caelestia has no password-store feature.** The launcher modes are
  `actions, apps, calc, scheme, variant, wallpapers, z`; there is no pass
  integration. The old `qs ipc call pass toggle` drove the custom fork's
  `PassMenu.qml`, which universe does not have. So passmenu must be provided
  outside caelestia: `pass` + a fuzzel menu. This is the single allowed
  exception to "no scripts this pass" because it is an explicit ask.
- **`fuzzel` and `wl-clipboard` are already in `home.packages`.** Only `pass`
  is new; the wrapper reuses what is present.
- **`mod+shift+LMB` resize is pure Hyprland** — one `bindm` line, no deps.
  The current `bindm` block already has `mod, mouse:272 → movewindow` and
  `mod, mouse:273 → resizewindow`; this adds the shift variant.
- **`resize_on_border` is explicitly skipped** for this slice.

## Decisions

### New module: `modules/home/passmenu.nix`

A `pkgs.writeShellApplication` named `passmenu`:

- Lists entries: walk `~/.password-store`, strip the prefix and the `.gpg`
  suffix, feed the relative paths to `fuzzel --dmenu`.
- On selection: `pass show -c <entry>`, which copies the first line to the
  Wayland clipboard and auto-clears after 45s (pass uses `wl-copy` when
  available).
- `runtimeInputs = [ pass fuzzel wl-clipboard ]`.
- Also expose `pass` itself on PATH (add to `home.packages` or via the
  module) so the store can be managed from a terminal.

The wrapper handles an empty/absent store gracefully (no entries → exit
quietly).

### `modules/home/default.nix`

Add `./passmenu.nix` to `imports`.

### `modules/home/hypr.nix`

Two additions only; no existing bind is modified or removed:

- `bind += "${mod} ALT, P, exec, passmenu"`
- `bindm += "${mod} SHIFT, mouse:272, resizewindow"`

`${mod}` is the existing `SUPER` let-binding; the `passmenu` reference resolves
to the wrapper on PATH.

## Out of scope (deferred)

- Repairing caelestia 1.0.0 dead dispatch (`caelestia:lock`,
  `caelestia:mediaNext/Prev/Toggle`, `caelestia:screenshot[Clip]`,
  `caelestia:brightnessUp/Down`) → rewrite to `caelestia shell ipc call`.
- 3-finger workspace gesture + `workspace_swipe` options.
- `mod+W` close, `mod+shift+alt+left/right` workspace→monitor, dashboard/
  sidebar drawer toggles.
- The ~25 system scripts (power-profile, monitor toggles, workspace-pair/grid,
  webapp-*, zoom, etc.).
- `general.resize_on_border`.

## Testing

- `nix build .#nixosConfigurations.pavg15.config.system.build.toplevel` green.
- Deploy pavg15.
- `mod+alt+P` opens a fuzzel list of password entries; selecting one copies
  the secret (verify clipboard, auto-clear).
- `mod+shift+LMB` drag resizes the focused window.

Assumes a populated `~/.password-store` on pavg15.
