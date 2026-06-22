{ pkgs, config, ... }:
let
  recipient = "age14ye9kvq4prahqgjntj5tv2gfg2d8kxsv79vfusxzzw8ssezfyqeq8hh94e";

  common = ''
    REPO="$HOME/.local/share/zen-profile"
    BLOB="zen-profile.tar.age"

    die() { echo "zen-profile: $*" >&2; exit 1; }

    zen_root() {
      local r
      for r in "$HOME/.zen" "$HOME/.config/zen" "$HOME/.var/app/app.zen_browser.zen/zen"; do
        [ -f "$r/profiles.ini" ] && { echo "$r"; return 0; }
      done
      die "no Zen profiles.ini found"
    }

    profile_dir() {
      local root rel
      root="$(zen_root)" || exit 1
      rel="$(grep -m1 '^Default=' "$root/installs.ini" 2>/dev/null | sed 's/^Default=//')"
      [ -z "$rel" ] && rel="$(awk '
        function flush(){ if (p != "") { if (f == "") f = p; if (d == "1") c = p } }
        /^\[/ { flush(); p=""; d=""; next }
        /^Path=/ { p = substr($0, 6) }
        /^Default=/ { d = substr($0, 9) }
        END { flush(); print (c != "" ? c : f) }
      ' "$root/profiles.ini")"
      [ -z "$rel" ] && die "cannot resolve default profile"
      echo "$root/$rel"
    }

    zen_running() {
      pgrep -x zen >/dev/null 2>&1 && return 0
      pgrep -f '\.zen-wrapped' >/dev/null 2>&1 && return 0
      pgrep -if 'zen-browser' >/dev/null 2>&1 && return 0
      return 1
    }

    ensure_repo() {
      [ -d "$REPO/.git" ] && return 0
      local sock
      sock="$(gpgconf --list-dirs agent-ssh-socket)"
      GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" SSH_AUTH_SOCK="$sock" \
        git clone git@github.com:atqamz/zen-profile.git "$REPO"
    }
  '';

  pull = pkgs.writeShellApplication {
    name = "zen-profile-pull";
    runtimeInputs = [
      config.programs.zen-browser.finalPackage
    ]
    ++ (with pkgs; [
      git
      gh
      gnupg
      age
      gnutar
      coreutils
      gnugrep
      gawk
      gnused
      procps
    ]);
    text = ''
      ${common}
      IDENTITY="$HOME/.config/zen-profile/identity"

      ensure_profile() {
        for r in "$HOME/.zen" "$HOME/.config/zen" "$HOME/.var/app/app.zen_browser.zen/zen"; do
          [ -f "$r/profiles.ini" ] && return 0
        done
        echo "zen-profile: no local profile, seeding headlessly"
        zen-beta --headless >/dev/null 2>&1 &
        seed_pid=$!
        for _ in $(seq 1 30); do
          [ -f "$HOME/.config/zen/profiles.ini" ] && break
          sleep 1
        done
        kill "$seed_pid" 2>/dev/null || true
        wait "$seed_pid" 2>/dev/null || true
        [ -f "$HOME/.config/zen/profiles.ini" ] || die "headless profile seed failed"
      }

      if zen_running; then die "close Zen before pull (last-push-wins clobbers live session)"; fi
      [ -f "$IDENTITY" ] || die "no identity at $IDENTITY — provision from vault"
      ensure_repo
      git -C "$REPO" pull --ff-only
      [ -f "$REPO/$BLOB" ] || die "remote has no $BLOB yet — run zen-profile-push first"
      ensure_profile
      pdir="$(profile_dir)"
      tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
      age -d -i "$IDENTITY" -o "$tmp" "$REPO/$BLOB"
      tar xzf "$tmp" -C "$pdir"
      echo "zen-profile: pulled into $pdir"
    '';
  };

  push = pkgs.writeShellApplication {
    name = "zen-profile-push";
    runtimeInputs = with pkgs; [
      git
      gh
      gnupg
      age
      gnutar
      coreutils
      gnugrep
      gawk
      gnused
      procps
    ];
    text = ''
      ${common}
      FILES=(prefs.js zen-sessions.jsonlz4 containers.json sessionstore-backups/recovery.jsonlz4)
      if zen_running; then die "close Zen before push"; fi
      ensure_repo
      pdir="$(profile_dir)"
      tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
      present=()
      for f in "''${FILES[@]}"; do [ -e "$pdir/$f" ] && present+=("$f"); done
      [ ''${#present[@]} -gt 0 ] || die "no profile files found in $pdir"
      tar czf "$tmp" -C "$pdir" "''${present[@]}"
      age -r "${recipient}" -o "$REPO/$BLOB" "$tmp"
      git -C "$REPO" add "$BLOB"
      if git -C "$REPO" diff --cached --quiet; then
        echo "zen-profile: no changes"; exit 0
      fi
      git -C "$REPO" commit -m "update from $(hostname) $(date -u +%Y-%m-%dT%H:%MZ)"
      git -C "$REPO" push
      echo "zen-profile: pushed"
    '';
  };
in
{
  home.packages = [
    pull
    push
  ];

  systemd.user.services.zen-profile-sync = {
    Unit.Description = "Pull Zen profile from sync repo";
    Service = {
      Type = "oneshot";
      ExecStart = "${pull}/bin/zen-profile-pull";
    };
  };
  systemd.user.timers.zen-profile-sync = {
    Unit.Description = "Pull Zen profile on startup";
    Timer = {
      OnStartupSec = "1min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
