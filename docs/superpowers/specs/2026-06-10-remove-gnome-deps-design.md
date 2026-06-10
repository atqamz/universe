# Universe — Remove GNOME Dependencies

Date: 2026-06-10
Status: approved (design)
Issues: #1

## Purpose

Remove every GNOME dependency from the `pavg15` system by **not installing**
it (no purging, no overlays). Decide and wire the replacements for the three
roles GNOME components currently fill or leave vacant: file manager, Secret
Service, and polkit agent.

## Current footprint (measured)

`nix path-info -r <toplevel> | grep -iE 'gnome|nautilus'` on the current
closure shows seven GNOME store paths, all rooted in exactly two
declarations:

| Root declaration | Pulls in |
|---|---|
| `nautilus` (`modules/home/packages.nix`) | nautilus, gnome-autoar, gnome-desktop, gnome-user-share, gnome-settings-daemon schemas |
| `services.gnome.gnome-keyring.enable` (`modules/nixos/desktop.nix`) | gnome-keyring, security-wrapper-gnome-keyring-daemon |

One reference completes the picture: `fileExplorer = "nautilus"` in
`modules/home/hypr.nix` (the Super+E bind).

There is additionally **no graphical polkit agent at all** — only
`security.polkit.enable = true` (the freedesktop policy daemon, not GNOME).
GUI authentication prompts cannot appear in the Hyprland session today.

## Decisions

- **File manager: `yazi`, plain.** Terminal file manager via the
  Home-Manager module (`programs.yazi`), launched from Super+E inside
  alacritty. No drag-and-drop companion (ripdrag/dragon) — browser uploads
  use zen's native GTK file dialog, which needs no portal, keyring, or
  nautilus. Rejected: Thunar/Dolphin (native DnD but extra GTK/KIO stacks),
  yazi+ripdrag (DnD not needed).
- **Secret Service: drop without replacement, revisit in #4.** Passwords
  already live in the external `password-store` (pass). If an application
  later needs the Secret Service API, the provider is decided in issue #4 —
  natural candidate `pass-secret-service` (bridges to pass), since it
  requires pass+GPG bootstrap, which is #4 scope. ssh-agent / gpg-agent
  provisioning is likewise #4 scope, not this issue.
- **Polkit agent: `hyprpolkitagent`.** Official Hypr-ecosystem agent (Qt6,
  matches caelestia/quickshell), enabled via the Home-Manager module as a
  systemd user service. `security.polkit.enable = true` stays — polkit
  itself is freedesktop and is the backend the agent talks to.

## Changes

1. `modules/nixos/desktop.nix` — delete
   `services.gnome.gnome-keyring.enable = true;`.
2. `modules/home/hypr.nix` — add `services.hyprpolkitagent.enable = true;`
   (hypr-session concern stays in one file); change
   `fileExplorer = "nautilus"` to `fileExplorer = "alacritty -e yazi"`.
3. `modules/home/yazi.nix` (new) — `programs.yazi.enable = true;` with
   `enableBashIntegration = true;` (repo convention: `programs.*` over a raw
   package). Imported from `modules/home/default.nix`.
4. `modules/home/packages.nix` — remove `nautilus` from `home.packages`.

## Verification (definition of done)

- `nix flake check` passes.
- `nix build .#nixosConfigurations.pavg15.config.system.build.toplevel`
  succeeds. The closure **changes** by design (this is not a
  behaviour-preserving refactor).
- `nix path-info -r <new toplevel> | grep -iE 'gnome|nautilus'` returns
  empty. If an unavoidable transitive GNOME path remains, it is documented
  here with its dependency chain (`nix why-depends`).

  **Documented exception (measured on the new closure):** two GNOME
  *library* paths remain — `gnome-desktop-44.5` and
  `gnome-settings-daemon-50.1-gsettings-schemas` — both via the single
  chain `system-path → xdg-desktop-portal-gtk`. The GTK portal backend is
  added upstream by `programs.hyprland` (NixOS module) and provides the
  FileChooser portal this design relies on (plain yazi, uploads through the
  file picker). They are linked libraries of the portal, not installed GNOME
  components; removing them would mean removing the portal itself. All seven
  previously-measured GNOME paths rooted in nautilus/gnome-keyring are gone.
- CI green on the PR.
- The systemd user unit `hyprpolkitagent.service` exists in the built
  home-manager generation.

## Out of scope

- Secret Service provider, ssh-agent, gpg-agent, pass/GPG bootstrap — issue #4.
- Keybinding alignment beyond the Super+E command swap — issue #2.
