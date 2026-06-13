{ lib, pkgs, ... }:
let
  # pass has no launcher of its own and caelestia ships no password feature, so
  # this wrapper bridges the two: list store entries, pick via fuzzel, then
  # `pass show -c` copies the first line to the Wayland clipboard (pass uses
  # wl-copy when present) and auto-clears after 45s. Empty/absent store exits
  # quietly instead of opening an empty menu.
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
      # A decrypt failure (locked gpg, missing key) should die quietly under
      # set -e, not abort the launcher with a stray non-zero exit.
      pass show -c "$entry" || exit 0
    '';
  };
in
{
  # pkgs.pass ships its own dmenu-based `passmenu`; hiPrio lets our Wayland/fuzzel
  # variant win the buildEnv merge instead of colliding on the same bin path.
  home.packages = [
    (lib.hiPrio passmenu)
    pkgs.pass
  ];
}
