{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:
let
  enabled = osConfig.universe.capabilities.handFleet;

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

      # a transient GitHub outage must not fail activation; only a failed checksum verification does.
      if ! curl -fsSLO "$base_url/$asset"; then
        echo "hand-install: download of $asset failed, leaving hand uninstalled" >&2
        exit 0
      fi
      if ! curl -fsSLO "$base_url/checksums.txt"; then
        echo "hand-install: download of checksums.txt failed, leaving hand uninstalled" >&2
        exit 0
      fi

      line="$(grep -E '${assetLinePattern}' checksums.txt)" || {
        echo "hand-install: checksums.txt has no entry for $asset, refusing to install" >&2
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
lib.mkIf enabled {
  home.activation.handInstall = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${install}/bin/hand-install "${target}"
  '';

  universe.doctor.paths = [ ".local/bin/hand" ];
}
