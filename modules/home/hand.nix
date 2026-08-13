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
      target="$1"

      if [ -e "$target" ] || [ -L "$target" ]; then
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
      trap 'cleanup; exit 130' INT
      trap 'cleanup; exit 143' TERM
      cd "$workdir" || exit 1

      # a transient GitHub outage must not fail activation; only a failed checksum verification does.
      if ! curl -fsSLO --connect-timeout 10 --speed-limit 1 --speed-time 30 "$base_url/$asset"; then
        echo "hand-install: download of $asset failed, leaving hand uninstalled" >&2
        exit 0
      fi
      if ! curl -fsSLO --connect-timeout 10 --speed-limit 1 --speed-time 30 "$base_url/checksums.txt"; then
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
      staged="$(mktemp "$(dirname "$target")/.$(basename "$target").XXXXXX")"
      install -m755 hand "$staged"
      if ! link_error="$(ln "$staged" "$target" 2>&1)"; then
        if [ -e "$target" ] || [ -L "$target" ]; then
          echo "hand-install: $target appeared during download, leaving it untouched" >&2
          exit 0
        fi
        echo "hand-install: could not publish $target: $link_error" >&2
        exit 1
      fi
      rm -f "$staged"
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
