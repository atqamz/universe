{ config, pkgs, ... }:

{
  imports = [ ./hardware.nix ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # Use latest kernel. (cachyos kernel to be swapped in as a follow-up rebuild)
    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking = {
    hostName = "pavg15";
    networkmanager.enable = true;
    firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };
  };

  time.timeZone = "Asia/Jakarta";
  i18n.defaultLocale = "en_US.UTF-8";

  # Flakes.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # NVIDIA Optimus: AMD Renoir iGPU drives the only live output (eDP-1),
  # NVIDIA GTX 1650 (Turing) is offload-only for the disconnected HDMI.
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      modesetting.enable = true;
      open = true; # Turing supports the open kernel modules
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        amdgpuBusId = "PCI:5:0:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
    bluetooth.enable = true;
  };

  services = {
    xserver.videoDrivers = [ "nvidia" ];

    # Hyprland + uwsm session.
    # Login: greetd + tuigreet launching hyprland via uwsm.
    greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland'";
        user = "greeter";
      };
    };

    # Printing.
    printing.enable = true;

    # Power profiles + battery + bluetooth (caelestia shell queries these).
    power-profiles-daemon.enable = true;
    upower.enable = true;

    # Sound (pipewire).
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Keyring + polkit for the desktop session.
    gnome.gnome-keyring.enable = true;

    # SSH + Tailscale.
    openssh.enable = true;
    tailscale.enable = true;
  };

  # Hyprland + uwsm session.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  security = {
    rtkit.enable = true;
    polkit.enable = true;
    # Passwordless sudo for wheel (per user request; native NixOS, the
    # /etc/sudoers.d drop-in is not honored).
    sudo.wheelNeedsPassword = false;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];

  users.users."atqa" = {
    isNormalUser = true;
    description = "Atqa Munzir";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
  ];

  system.stateVersion = "26.05";
}
