{ lib, pkgs, ... }:
let
  passmenu = pkgs.writeShellApplication {
    name = "passmenu";
    runtimeInputs = with pkgs; [
      pass
      fuzzel
      wl-clipboard
    ];
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
      pass show -c "$entry" || exit 0
    '';
  };
in
{
  home.packages = [
    (lib.hiPrio passmenu)
    pkgs.pass
  ];
}
