# Universe Structure & Tooling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the `universe` flake into the idiomatic flake-parts multi-host layout (Layout A from the ground-rules spec) and add formatting/lint/CI tooling, without changing the built `pavg15` system.

**Architecture:** `flake.nix` becomes a thin `flake-parts.lib.mkFlake` call. Per-aspect flakeModules live in `parts/`. The host moves to `hosts/pavg15/`, system config splits into one-concern `modules/nixos/*`, user config into `modules/home/*`, and a `lib/mkHost` factory wires Home-Manager as a NixOS module. Each step is a behaviour-preserving refactor verified by building the same system closure.

**Tech Stack:** Nix flakes, flake-parts, home-manager, treefmt-nix (nixfmt), git-hooks.nix (statix, deadnix, treefmt), GitHub Actions.

**Branch:** `3-ground-rules` (already checked out; spec committed). Implements issue #3.

**Invariant for every task:** the system closure path printed by
`nix build --no-link --print-out-paths .#nixosConfigurations.pavg15.config.system.build.toplevel`
must keep building. Behaviour-preserving refactors (Tasks 1, 2, 5, 6) must not change the *set* of enabled options; the closure hash may shift only when an input is added/locked (Tasks 3, 4).

---

## Target file layout

```
flake.nix              inputs + flake-parts mkFlake (thin)
flake.lock
.envrc                 use flake
.gitignore
README.md
parts/
  formatter.nix        perSystem.treefmt -> nixfmt
  checks.nix           perSystem.pre-commit.settings.hooks (statix, deadnix, treefmt)
  devshells.nix        perSystem.devShells.default
  hosts.nix            flake.nixosConfigurations.pavg15 via lib/mkHost
lib/
  mkHost.nix           host factory; wires Home-Manager-as-module
hosts/
  pavg15/
    default.nix        host-specific: hostname, kernel, gpu bus ids, system pkgs, stateVersion
    hardware.nix       generated (was hardware-configuration.nix)
modules/
  nixos/
    default.nix        imports the system modules below
    nix.nix            flakes, allowUnfree
    boot.nix           systemd-boot + EFI
    network.nix        NetworkManager, openssh, tailscale, firewall
    gpu.nix            nvidia + PRIME offload (bus ids set by host)
    desktop.nix        hyprland, greetd, polkit, gnome-keyring, fonts, printing
    audio.nix          pipewire
    power.nix          power-profiles-daemon, upower, bluetooth
    users.nix          user atqa + passwordless sudo
    locale.nix         timezone, i18n
  home/
    default.nix        imports home modules below + home.* identity
    packages.nix       home.packages
    caelestia.nix      caelestia-shell module + writable shell.json
    hypr.nix           wayland.windowManager.hyprland
    cursor.nix         home.pointerCursor
```

---

## Task 1: Relocate host/home files into directories

Pure move + path fixups. Stays a plain (non-flake-parts) flake so the build is verified before the bigger conversion.

**Files:**
- Move: `configuration.nix` -> `hosts/pavg15/default.nix`
- Move: `hardware-configuration.nix` -> `hosts/pavg15/hardware.nix`
- Move: `home.nix` -> `modules/home/default.nix`
- Modify: `hosts/pavg15/default.nix` (import path)
- Modify: `flake.nix` (module paths)

- [ ] **Step 1: Record the baseline closure**

Run:
```bash
cd /home/atqa/universe
nix build --no-link --print-out-paths .#nixosConfigurations.pavg15.config.system.build.toplevel | tee /tmp/universe-baseline.path
```
Expected: prints a `/nix/store/...-nixos-system-pavg15-...` path with no error. Save it; later tasks compare against it.

- [ ] **Step 2: Move the files with git**

Run:
```bash
mkdir -p hosts/pavg15 modules/home
git mv configuration.nix hosts/pavg15/default.nix
git mv hardware-configuration.nix hosts/pavg15/hardware.nix
git mv home.nix modules/home/default.nix
```
Expected: no error; `git status` shows three renames.

- [ ] **Step 3: Fix the hardware import inside the host file**

In `hosts/pavg15/default.nix`, change the import line:
```nix
  imports = [ ./hardware-configuration.nix ];
```
to:
```nix
  imports = [ ./hardware.nix ];
```

- [ ] **Step 4: Point flake.nix at the new paths**

In `flake.nix`, change the two module paths in `outputs`:
```nix
      modules = [
        ./hosts/pavg15/default.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "bak";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.atqa = import ./modules/home;
        }
      ];
```
(`import ./modules/home` resolves `modules/home/default.nix`.)

- [ ] **Step 5: Verify the closure is unchanged**

Run:
```bash
nix build --no-link --print-out-paths .#nixosConfigurations.pavg15.config.system.build.toplevel
```
Expected: prints the SAME path as `/tmp/universe-baseline.path` (a pure file move must not change the closure).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "move pavg15 config into hosts/ and modules/home/"
```

---

## Task 2: Convert flake.nix to flake-parts + mkHost factory

flake-parts is consumed as a library: `flake-parts.lib.mkFlake { inherit inputs; } { ... }`. `nixosConfigurations` is a top-level output declared under `flake`. A `lib/mkHost.nix` factory builds the machine and wires Home-Manager-as-module.

**Files:**
- Create: `lib/mkHost.nix`
- Create: `parts/hosts.nix`
- Modify: `flake.nix`

- [ ] **Step 1: Create the host factory**

Create `lib/mkHost.nix`. It imports only the host file and the Home-Manager wiring for now; Task 5 Step 4 adds `../modules/nixos` once that module set exists:
```nix
{ inputs }:
{ hostname, system ? "x86_64-linux" }:
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = { inherit inputs hostname; };
  modules = [
    ../hosts/${hostname}
    inputs.home-manager.nixosModules.home-manager
    {
      nixpkgs.hostPlatform = system;
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        extraSpecialArgs = { inherit inputs; };
        users.atqa = ../modules/home;
      };
    }
  ];
}
```

`../hosts/${hostname}` resolves to `hosts/pavg15/default.nix` (the monolithic host file from Task 1) and `../modules/home` to `modules/home/default.nix` (moved in Task 1) — both already exist, so no stub is needed.

- [ ] **Step 2: Create parts/hosts.nix**

Create `parts/hosts.nix`:
```nix
{ inputs, ... }:
{
  flake.nixosConfigurations.pavg15 =
    import ../lib/mkHost.nix { inherit inputs; } { hostname = "pavg15"; };
}
```

- [ ] **Step 3: Rewrite flake.nix as mkFlake**

Replace the whole `flake.nix` with:
```nix
{
  description = "universe — NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        ./parts/hosts.nix
      ];
    };
}
```

- [ ] **Step 4: Lock the new flake-parts input**

Run:
```bash
nix flake lock
```
Expected: `flake.lock` gains a `flake-parts` node (and its `nixpkgs-lib` follow). No error.

- [ ] **Step 5: Verify the closure is unchanged**

Run:
```bash
nix build --no-link --print-out-paths .#nixosConfigurations.pavg15.config.system.build.toplevel
```
Expected: SAME path as `/tmp/universe-baseline.path`. Adding flake-parts as a pure-eval library and setting `nixpkgs.hostPlatform` instead of `system` does not change the closure.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "adopt flake-parts and mkHost factory"
```

---

## Task 3: Add treefmt formatter (nixfmt)

`treefmt-nix.flakeModule` provides `perSystem.treefmt`. The option is `programs.nixfmt.enable` — `pkgs.nixfmt` is the RFC-style formatter today (`nixfmt-rfc-style` is a deprecated alias). The module auto-wires `nix fmt` and adds `checks.<system>.treefmt`.

**Files:**
- Create: `parts/formatter.nix`
- Modify: `flake.nix` (add input + imports)

- [ ] **Step 1: Create parts/formatter.nix**

Create `parts/formatter.nix`:
```nix
{ ... }:
{
  perSystem =
    { ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
      };
    };
}
```

- [ ] **Step 2: Add the treefmt-nix input and import**

In `flake.nix`, add to `inputs`:
```nix
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```
and change `imports` to:
```nix
      imports = [
        inputs.treefmt-nix.flakeModule
        ./parts/formatter.nix
        ./parts/hosts.nix
      ];
```

- [ ] **Step 3: Lock and verify the formatter exists**

Run:
```bash
nix flake lock
nix fmt -- --version
```
Expected: lock gains `treefmt-nix`; the version command prints a treefmt version with no error (confirms `nix fmt` is wired).

- [ ] **Step 4: Format the whole repo**

Run:
```bash
nix fmt
```
Expected: reformats `.nix` files in place to nixfmt style. Review `git diff` — only whitespace/layout changes, no semantic change.

- [ ] **Step 5: Verify the treefmt check passes**

Run:
```bash
nix flake check 2>&1 | tail -20
```
Expected: includes the `treefmt` check and reports no formatting diff (exit 0). If it fails on formatting, run `nix fmt` again and re-check.

- [ ] **Step 6: Verify closure still builds**

Run:
```bash
nix build --no-link --print-out-paths .#nixosConfigurations.pavg15.config.system.build.toplevel
```
Expected: builds successfully (path may differ from baseline only if reformatting changed a string; it should not — confirm the diff was whitespace-only).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "add treefmt-nix formatter with nixfmt"
```

---

## Task 4: Add git-hooks (statix, deadnix, treefmt) + devShell

`git-hooks.nix` (input named `git-hooks-nix`) provides `perSystem.pre-commit.settings.hooks`. The pre-commit `treefmt` hook reuses the treefmt-nix-built wrapper. A devShell installs the hooks on entry; `.envrc` auto-loads it via direnv.

**Files:**
- Create: `parts/checks.nix`
- Create: `parts/devshells.nix`
- Create: `.envrc`
- Modify: `flake.nix` (add input + imports)

- [ ] **Step 1: Create parts/checks.nix**

Create `parts/checks.nix`:
```nix
{ ... }:
{
  perSystem =
    { config, ... }:
    {
      pre-commit.settings.hooks = {
        statix.enable = true;
        deadnix.enable = true;
        treefmt = {
          enable = true;
          packageOverrides.treefmt = config.treefmt.build.wrapper;
        };
      };
    };
}
```
(The dedicated `nixfmt-rfc-style` hook is intentionally omitted: the `treefmt` hook already runs nixfmt via the wrapper, so enabling both would format twice.)

- [ ] **Step 2: Create parts/devshells.nix**

Create `parts/devshells.nix`:
```nix
{ ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        shellHook = config.pre-commit.installationScript;
        packages = [
          config.treefmt.build.wrapper
          pkgs.statix
          pkgs.deadnix
        ];
      };
    };
}
```

- [ ] **Step 3: Create .envrc**

Create `.envrc`:
```bash
use flake
```

- [ ] **Step 4: Add the git-hooks-nix input and imports**

In `flake.nix`, add to `inputs`:
```nix
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```
and change `imports` to:
```nix
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks-nix.flakeModule
        ./parts/formatter.nix
        ./parts/checks.nix
        ./parts/devshells.nix
        ./parts/hosts.nix
      ];
```

- [ ] **Step 5: Lock the input**

Run:
```bash
nix flake lock
```
Expected: lock gains `git-hooks-nix` (and its `gitignore`/`flake-compat` deps). No error.

- [ ] **Step 6: Run the checks and fix findings**

Run:
```bash
nix flake check 2>&1 | tail -40
```
Expected: builds `checks.x86_64-linux.{pre-commit,treefmt}`. The `pre-commit` check runs `statix`, `deadnix`, and `treefmt`.

- If `statix` reports a lint, fix the flagged construct per its suggestion (e.g. collapse a redundant pattern), then re-run.
- If `deadnix` reports an unused binding or lambda argument, remove it. Common case: a module head `{ config, pkgs, ... }` where `config` is unused — change it to `{ pkgs, ... }` (keep `...`). Then re-run.
- Re-run `nix flake check` until it exits 0.

- [ ] **Step 7: Verify the dev shell installs hooks**

Run:
```bash
nix develop --command bash -c 'ls -l .git/hooks/pre-commit'
```
Expected: `.git/hooks/pre-commit` exists as a symlink/script installed by the hook manager, no error.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "add git-hooks pre-commit checks and dev shell"
```

---

## Task 5: Split system config into modules/nixos/*

Decompose the monolithic `hosts/pavg15/default.nix` into one-concern system modules. Host-specific knobs (hostname, kernel, GPU bus ids, system packages, stateVersion) stay in the host file. This is a behaviour-preserving split: the union of all modules must equal the original config exactly.

**Files:**
- Create: `modules/nixos/default.nix`, `nix.nix`, `boot.nix`, `network.nix`, `gpu.nix`, `desktop.nix`, `audio.nix`, `power.nix`, `users.nix`, `locale.nix`
- Modify: `hosts/pavg15/default.nix` (reduce to host-specific only)
- Modify: `lib/mkHost.nix` (import `../modules/nixos`)

- [ ] **Step 1: Create the module aggregator**

Create `modules/nixos/default.nix`:
```nix
{ ... }:
{
  imports = [
    ./nix.nix
    ./boot.nix
    ./network.nix
    ./gpu.nix
    ./desktop.nix
    ./audio.nix
    ./power.nix
    ./users.nix
    ./locale.nix
  ];
}
```

- [ ] **Step 2: Create the system modules**

Create `modules/nixos/nix.nix`:
```nix
{ ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;
}
```

Create `modules/nixos/boot.nix`:
```nix
{ ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
```

Create `modules/nixos/network.nix`:
```nix
{ config, ... }:
{
  networking.networkmanager.enable = true;

  services.openssh.enable = true;
  services.tailscale.enable = true;
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
```

Create `modules/nixos/gpu.nix`:
```nix
{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    open = true; # Turing supports the open kernel modules
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime.offload = {
      enable = true;
      enableOffloadCmd = true;
    };
  };
}
```

Create `modules/nixos/desktop.nix`:
```nix
{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland'";
      user = "greeter";
    };
  };

  services.printing.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.polkit.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];
}
```

Create `modules/nixos/audio.nix`:
```nix
{ ... }:
{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
```

Create `modules/nixos/power.nix`:
```nix
{ ... }:
{
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  hardware.bluetooth.enable = true;
}
```

Create `modules/nixos/users.nix`:
```nix
{ ... }:
{
  users.users.atqa = {
    isNormalUser = true;
    description = "Atqa Munzir";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
    ];
  };

  security.sudo.wheelNeedsPassword = false;
}
```

Create `modules/nixos/locale.nix`:
```nix
{ ... }:
{
  time.timeZone = "Asia/Jakarta";
  i18n.defaultLocale = "en_US.UTF-8";
}
```

- [ ] **Step 3: Reduce the host file to host-specific config**

Replace the whole `hosts/pavg15/default.nix` with:
```nix
{ pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  networking.hostName = "pavg15";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.nvidia.prime = {
    amdgpuBusId = "PCI:5:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
  ];

  system.stateVersion = "26.05";
}
```

- [ ] **Step 4: Wire the module set into the factory**

In `lib/mkHost.nix`, add `../modules/nixos` to the `modules` list:
```nix
  modules = [
    ../hosts/${hostname}
    ../modules/nixos
    inputs.home-manager.nixosModules.home-manager
    {
```

- [ ] **Step 5: Verify the closure is unchanged**

Run:
```bash
nix build --no-link --print-out-paths .#nixosConfigurations.pavg15.config.system.build.toplevel
```
Expected: SAME path as `/tmp/universe-baseline.path`. A correct split changes nothing the evaluator sees. If the path differs, diff the evaluated config to find the missing or extra option:
```bash
nix eval --json .#nixosConfigurations.pavg15.config.system.build.toplevel.drvPath
```
and re-check that every option from the original `configuration.nix` is present exactly once.

- [ ] **Step 6: Format and lint**

Run:
```bash
nix fmt && nix flake check 2>&1 | tail -20
```
Expected: exit 0 (treefmt clean, statix/deadnix clean for the new modules). Fix any deadnix unused-arg findings by trimming the module head.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "split system config into modules/nixos"
```

---

## Task 6: Split home config into modules/home/*

Decompose `modules/home/default.nix` into one-concern Home-Manager modules. Behaviour-preserving.

**Files:**
- Create: `modules/home/packages.nix`, `caelestia.nix`, `hypr.nix`, `cursor.nix`
- Modify: `modules/home/default.nix` (reduce to imports + identity)

- [ ] **Step 1: Create modules/home/packages.nix**

```nix
{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    alacritty
    nautilus
    zed-editor
    inputs.zen-browser.packages.${pkgs.system}.default
    bibata-cursors
    jq
    hyprpicker
    grim
    slurp
    wl-clipboard
    brightnessctl
    playerctl
    pavucontrol
  ];
}
```

- [ ] **Step 2: Create modules/home/caelestia.nix**

```nix
{ pkgs, lib, inputs, ... }:
{
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  programs.caelestia = {
    enable = true;
    cli.enable = true;
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };
  };

  # caelestia self-mutates shell.json at runtime; an immutable store symlink
  # makes that fail with "Read-only file system". Seed a writable copy and
  # re-assert declarative keys via jq.
  home.activation.caelestiaShellJson = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfgDir="$HOME/.config/caelestia"
    f="$cfgDir/shell.json"
    run mkdir -p "$cfgDir"
    if [ -L "$f" ]; then run rm -f "$f"; fi
    base="{}"
    if [ -f "$f" ]; then base="$(cat "$f")"; fi
    printf '%s' "$base" | ${pkgs.jq}/bin/jq \
      '.general.idle.lockBeforeSleep=false
       | .general.idle.timeouts=[]
       | .paths.wallpaperDir="~/Pictures/Wallpapers"' \
      > "$f.tmp" && run mv "$f.tmp" "$f"
  '';
}
```

- [ ] **Step 3: Create modules/home/cursor.nix**

```nix
{ pkgs, ... }:
{
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
  };
}
```

- [ ] **Step 4: Create modules/home/hypr.nix**

Move the entire `wayland.windowManager.hyprland = let ... in { ... };` block (lines 74-147 of the original `home.nix`) into this file verbatim:
```nix
{ ... }:
{
  # configType "hyprlang": the HM 26.05 default lua backend has no `bindel`
  # and wants split bind args, so comma-strings would not parse.
  wayland.windowManager.hyprland =
    let
      terminal = "alacritty";
      browser = "zen-browser";
      editor = "zeditor";
      fileExplorer = "nautilus";
      mod = "SUPER";
    in
    {
      enable = true;
      systemd.enable = false; # uwsm owns the session
      configType = "hyprlang";
      settings = {
        monitor = [
          "eDP-1,preferred,auto,1"
          "HDMI-A-1,preferred,auto,auto"
        ];

        env = [
          "HYPRCURSOR_THEME,Bibata-Modern-Classic"
          "XCURSOR_THEME,Bibata-Modern-Classic"
          "XCURSOR_SIZE,24"
        ];

        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          layout = "dwindle";
        };

        input = {
          kb_layout = "us";
          follow_mouse = 1;
          touchpad.natural_scroll = true;
        };

        bind = [
          "${mod}, Return, exec, ${terminal}"
          "${mod}, Q, killactive,"
          "${mod}, M, exit,"
          "${mod}, E, exec, ${fileExplorer}"
          "${mod}, B, exec, ${browser}"
          "${mod}, C, exec, ${editor}"
          "${mod}, V, togglefloating,"
          "${mod}, F, fullscreen,"
          "${mod}, left, movefocus, l"
          "${mod}, right, movefocus, r"
          "${mod}, up, movefocus, u"
          "${mod}, down, movefocus, d"
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
          "${mod}, Space, global, caelestia:launcher"
          "${mod}, X, global, caelestia:session"
        ];

        bindm = [
          "${mod}, mouse:272, movewindow"
          "${mod}, mouse:273, resizewindow"
        ];

        bindel = [
          ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86MonBrightnessUp, exec, brightnessctl s 5%+"
          ",XF86MonBrightnessDown, exec, brightnessctl s 5%-"
        ];
      };
    };
}
```

- [ ] **Step 5: Reduce modules/home/default.nix to imports + identity**

Replace the whole file with:
```nix
{ ... }:
{
  imports = [
    ./packages.nix
    ./caelestia.nix
    ./hypr.nix
    ./cursor.nix
  ];

  home.username = "atqa";
  home.homeDirectory = "/home/atqa";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
```

- [ ] **Step 6: Verify the closure is unchanged**

Run:
```bash
nix build --no-link --print-out-paths .#nixosConfigurations.pavg15.config.system.build.toplevel
```
Expected: SAME path as `/tmp/universe-baseline.path`.

- [ ] **Step 7: Format and lint**

Run:
```bash
nix fmt && nix flake check 2>&1 | tail -20
```
Expected: exit 0.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "split home config into modules/home"
```

---

## Task 7: Update README and add CI

Document the new layout and add a GitHub Actions workflow that runs `nix flake check` and builds `pavg15` on PRs.

**Files:**
- Modify: `README.md`
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Rewrite README.md**

Replace `README.md` with:
```markdown
# universe

Personal NixOS configuration as a flake.

## Hosts

| Host   | Description                          |
| ------ | ------------------------------------ |
| pavg15 | HP Pavilion Gaming 15 — Hyprland + caelestia |

## Layout

- `flake.nix` — inputs + flake-parts entry point
- `parts/` — flake-parts modules (hosts, formatter, checks, dev shell)
- `hosts/<name>/` — host-specific config + generated hardware
- `modules/nixos/` — one-concern system modules
- `modules/home/` — one-concern Home-Manager modules
- `lib/mkHost.nix` — host factory (wires Home-Manager as a NixOS module)

## Build

```bash
sudo nixos-rebuild switch --flake .#pavg15
```

## Develop

```bash
nix develop      # or: direnv allow
nix fmt          # format
nix flake check  # lint + build checks
```
```

- [ ] **Step 2: Create the CI workflow**

Create `.github/workflows/ci.yml`:
```yaml
name: ci

on:
  pull_request:
  push:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v31
        with:
          extra_nix_config: |
            experimental-features = nix-command flakes
      - name: flake check
        run: nix flake check --print-build-logs
      - name: build pavg15
        run: nix build --print-build-logs .#nixosConfigurations.pavg15.config.system.build.toplevel
```

- [ ] **Step 3: Format and final verify**

Run:
```bash
nix fmt
nix flake check 2>&1 | tail -20
nix build --no-link --print-out-paths .#nixosConfigurations.pavg15.config.system.build.toplevel
```
Expected: flake check exit 0; build prints the baseline path.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "document layout and add nix flake check ci"
```

---

## Self-review notes

- **Spec coverage:** §2 layout -> Tasks 1,2,5,6. §3 inputs/wiring -> Tasks 2,3,4. §4 module conventions (one concern, host thin, programs.* over raw) -> Tasks 5,6. §5 code style (minimal comments, nixfmt) -> Task 3 + module bodies. §7 DoD (`nix flake check` + `nixos-rebuild build` + CI) -> verify steps + Task 7. §8 secrets -> deferred (no task, by design). §9 #1/#2 -> deferred (no task, by design).
- **No closure-changing behaviour:** Tasks 1, 2, 5, 6 are assert-same-path refactors. Tasks 3, 4, 7 add tooling/inputs/CI only; they must not edit any NixOS/home option.
- **gnome-keyring + nautilus stay** in this plan (Task 5 `desktop.nix`, Task 6 `packages.nix`) — removed in issue #1's own work, not here.
- **Type consistency:** `lib/mkHost.nix` signature `{ inputs }: { hostname, system ? "x86_64-linux" }` is referenced once, from `parts/hosts.nix`. The factory imports `../modules/home` (created in Task 1) and `../hosts/${hostname}` (created in Task 1) from the start; `../modules/nixos` is added to the factory only in Task 5 Step 4, the same task that creates `modules/nixos/default.nix` — so no import ever points at a missing path.
```
