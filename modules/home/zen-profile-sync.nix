{
  pkgs,
  config,
  lib,
  hostname,
  ...
}:
let
  recipient = "age14ye9kvq4prahqgjntj5tv2gfg2d8kxsv79vfusxzzw8ssezfyqeq8hh94e";
  committerName = "zen-profile-sync";
  committerEmail = "zen-profile-sync@users.noreply.github.com";
  pushHost = "sfx14";
  isPushHost = hostname == pushHost;

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

      if zen_running; then
        echo "zen-profile: Zen running, pull skipped"
        exit 0
      fi
      [ -f "$IDENTITY" ] || die "no identity at $IDENTITY - provision from vault"
      ensure_repo
      git -C "$REPO" pull --ff-only
      [ -f "$REPO/$BLOB" ] || die "remote has no $BLOB yet - run zen-profile-push on ${pushHost} first"
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
      gnupg
      age
      gnutar
      coreutils
      gnugrep
      gawk
      gnused
      procps
      util-linux
    ];
    text = ''
      ${common}
      LOCK="''${XDG_RUNTIME_DIR:-$HOME/.cache}/zen-profile-push.lock"
      mkdir -p "$(dirname "$LOCK")"
      exec 9>"$LOCK"
      flock -n 9 || { echo "zen-profile: push already running"; exit 0; }

      FILES=(prefs.js zen-sessions.jsonlz4 containers.json sessionstore-backups/recovery.jsonlz4)
      HASH_STATE="$REPO/.git/zen-profile-source.sha256"
      ensure_repo

      if zen_running; then
        echo "zen-profile: Zen running, snapshot skipped"
      else
        pdir="$(profile_dir)"
        present=()
        for f in "''${FILES[@]}"; do [ -e "$pdir/$f" ] && present+=("$f"); done
        [ ''${#present[@]} -gt 0 ] || die "no profile files found in $pdir"

        profile_hash="$(
          {
            for f in "''${present[@]}"; do
              printf '%s\0' "$f"
              sha256sum <"$pdir/$f" | cut -d ' ' -f1
            done
          } | sha256sum | cut -d ' ' -f1
        )"

        if [ "$(cat "$HASH_STATE" 2>/dev/null || true)" = "$profile_hash" ]; then
          echo "zen-profile: profile content unchanged"
        else
          tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
          tar czf "$tmp" -C "$pdir" "''${present[@]}"
          age -r "${recipient}" -o "$REPO/$BLOB" "$tmp"
          git -C "$REPO" add "$BLOB"
          git -C "$REPO" \
            -c commit.gpgsign=false \
            -c user.name="${committerName}" \
            -c user.email="${committerEmail}" \
            commit -m "update from $(uname -n) $(date -u +%Y-%m-%dT%H:%MZ)"
          printf '%s\n' "$profile_hash" >"$HASH_STATE"
        fi
      fi

      if [ -z "$(git -C "$REPO" log --oneline '@{u}..' 2>/dev/null)" ]; then
        echo "zen-profile: nothing to push"
        exit 0
      fi
      git -C "$REPO" push
      echo "zen-profile: pushed"
    '';
  };

  pushOnStop = pkgs.writeShellApplication {
    name = "zen-profile-push-onstop";
    runtimeInputs = [
      push
      pkgs.procps
      pkgs.coreutils
    ];
    text = ''
      zen_alive() {
        pgrep -x zen >/dev/null 2>&1 && return 0
        pgrep -f '\.zen-wrapped' >/dev/null 2>&1 && return 0
        pgrep -if 'zen-browser' >/dev/null 2>&1 && return 0
        return 1
      }
      for _ in $(seq 1 60); do zen_alive || break; sleep 1; done
      zen-profile-push
    '';
  };

  watchClose = pkgs.writeShellApplication {
    name = "zen-profile-watch-close";
    runtimeInputs = [
      push
      pkgs.procps
      pkgs.coreutils
    ];
    text = ''
      zen_alive() {
        pgrep -x zen >/dev/null 2>&1 && return 0
        pgrep -f '\.zen-wrapped' >/dev/null 2>&1 && return 0
        pgrep -if 'zen-browser' >/dev/null 2>&1 && return 0
        return 1
      }

      was_running=0
      while true; do
        if zen_alive; then
          was_running=1
        elif [ "$was_running" -eq 1 ]; then
          echo "zen-profile: Zen closed, syncing profile"
          if zen-profile-push; then
            was_running=0
          else
            echo "zen-profile: close sync failed; retrying in 60s" >&2
            sleep 60
          fi
        fi
        sleep 5
      done
    '';
  };
in
{
  home.packages = [ pull ] ++ lib.optional isPushHost push;

  services.userTimers.zen-profile-sync = {
    description = "Pull Zen profile from sync repo";
    timerDescription = "Periodic Zen profile pull";
    command = "${pull}/bin/zen-profile-pull";
    timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };

  systemd.user.services = lib.optionalAttrs isPushHost {
    zen-profile-close-watcher = {
      Unit = {
        Description = "Push Zen profile after Zen closes";
        After = [ "gpg-agent.service" ];
      };
      Service = {
        ExecStart = "${watchClose}/bin/zen-profile-watch-close";
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStopSec = "10s";
      };
      Install.WantedBy = [ "default.target" ];
    };

    zen-profile-logout-push = {
      Unit = {
        Description = "Push Zen profile on logout";
        After = [ "gpg-agent.service" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
        ExecStop = "${pushOnStop}/bin/zen-profile-push-onstop";
        TimeoutStopSec = "120s";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
