{
  pkgs,
  lib,
  config,
  ...
}:
let
  channel = "edge";

  asset = "hand-linux-amd64.tar.gz";

  assetLinePattern = " \\*?${lib.escapeRegex asset}$";

  target = "${config.home.homeDirectory}/.local/bin/hand";

  install = pkgs.writeShellApplication {
    name = "hand-install";
    runtimeInputs = with pkgs; [
      curl
      gnutar
      coreutils
      gnugrep
      gzip
    ];
    text = ''
      target="''${1:-$HOME/.local/bin/hand}"

      if [ -e "$target" ]; then
        # hand update owns overwriting this file and switching channels; activation must never race it.
        exit 0
      fi

      channel="${channel}"
      asset="${asset}"
      base_url="https://github.com/atqamz/hand/releases/download/$channel"

      workdir="$(mktemp -d)"
      staged=""
      cleanup() {
        rm -rf "$workdir"
        if [ -n "$staged" ]; then
          rm -f "$staged"
        fi
      }
      trap cleanup EXIT
      cd "$workdir" || exit 1

      curl -fsSLO "$base_url/$asset"
      curl -fsSLO "$base_url/checksums.txt"

      line="$(grep -E '${assetLinePattern}' checksums.txt)" || {
        echo "hand-install: checksums.txt has no entry for $asset" >&2
        exit 1
      }

      if ! sha256sum -c - <<<"$line"; then
        echo "hand-install: checksum mismatch for $asset, refusing to install" >&2
        exit 1
      fi

      tar -xzf "$asset" hand

      mkdir -p "$(dirname "$target")"
      staged="$(mktemp "$target.XXXXXX")"
      install -m755 hand "$staged"
      mv -f "$staged" "$target"
      staged=""
    '';
  };
in
{
  home.activation.handInstall = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${install}/bin/hand-install "${target}"
  '';

  universe.doctor.paths = [ ".local/bin/hand" ];
}
