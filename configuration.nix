{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel. (cachyos kernel to be swapped in as a follow-up rebuild)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "pavg15";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Jakarta";
  i18n.defaultLocale = "en_US.UTF-8";

  # Flakes.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # NVIDIA Optimus: AMD Renoir iGPU drives the only live output (eDP-1),
  # NVIDIA GTX 1650 (Turing) is offload-only for the disconnected HDMI.
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
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      amdgpuBusId = "PCI:5:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Hyprland + uwsm session.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # Login: greetd + tuigreet launching hyprland via uwsm.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland'";
      user = "greeter";
    };
  };

  # Printing.
  services.printing.enable = true;

  # Power profiles + battery + bluetooth (caelestia shell queries these).
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  hardware.bluetooth.enable = true;

  # Sound (pipewire).
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Keyring + polkit for the desktop session.
  services.gnome.gnome-keyring.enable = true;
  security.polkit.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];

  users.users."atqa" = {
    isNormalUser = true;
    description = "Atqa Munzir";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };

  nixpkgs.config.allowUnfree = true;

  # Passwordless sudo for wheel (per user request; native NixOS, the
  # /etc/sudoers.d drop-in is not honored).
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
  ];

  # SSH + Tailscale.
  services.openssh.enable = true;
  services.tailscale.enable = true;
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  system.stateVersion = "26.05";
}
