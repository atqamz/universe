{
  pkgs,
  config,
  lib,
  osConfig,
  ...
}:
let
  recipient = "age14ye9kvq4prahqgjntj5tv2gfg2d8kxsv79vfusxzzw8ssezfyqeq8hh94e";
  committerName = "zen-profile-sync";
  committerEmail = "zen-profile-sync@users.noreply.github.com";
  isPushHost = osConfig.universe.roles.zenProfileWriter;

  common = ''
    REPO="$HOME/.local/share/zen-profile"
    BLOB="zen-profile.tar.age"
    IDENTITY="$HOME/.config/zen-profile/identity"
    LOCK="''${XDG_RUNTIME_DIR:-$HOME/.cache}/zen-profile-sync.lock"
    FILES=(prefs.js zen-sessions.jsonlz4 containers.json sessionstore-backups/recovery.jsonlz4)

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

    open_lock() {
      mkdir -p "$(dirname "$LOCK")"
      exec 9>"$LOCK"
    }

    git_auth() {
      SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
      export SSH_AUTH_SOCK
      GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"
      export GIT_SSH_COMMAND
    }

    ensure_repo() {
      [ -d "$REPO/.git" ] && return 0
      git_auth
      git clone git@github.com:atqamz/zen-profile.git "$REPO"
    }
  '';

  pull = pkgs.writeShellApplication {
    name = "zen-profile-pull";
    runtimeInputs = [
      config.programs.zen-browser.finalPackage
    ]
    ++ (with pkgs; [
      age
      coreutils
      gawk
      git
      gnugrep
      gnupg
      gnused
      gnutar
      openssh
      procps
      util-linux
    ]);
    text = ''
      ${common}

      ensure_profile() {
        local r
        for r in "$HOME/.zen" "$HOME/.config/zen" "$HOME/.var/app/app.zen_browser.zen/zen"; do
          [ -f "$r/profiles.ini" ] && return 0
        done
        echo "zen-profile: no local profile, seeding headlessly"
        zen-beta --headless >/dev/null 2>&1 &
        seed_pid=$!
        for _ in $(seq 1 30); do
          for r in "$HOME/.zen" "$HOME/.config/zen" "$HOME/.var/app/app.zen_browser.zen/zen"; do
            [ -f "$r/profiles.ini" ] && break 2
          done
          sleep 1
        done
        kill "$seed_pid" 2>/dev/null || true
        wait "$seed_pid" 2>/dev/null || true
        for r in "$HOME/.zen" "$HOME/.config/zen" "$HOME/.var/app/app.zen_browser.zen/zen"; do
          [ -f "$r/profiles.ini" ] && return 0
        done
        die "headless profile seed failed"
      }

      if zen_running; then
        echo "zen-profile: Zen running; pull skipped"
        exit 0
      fi
      [ -f "$IDENTITY" ] || die "no identity at $IDENTITY; provision from vault"

      open_lock
      flock -n 9 || { echo "zen-profile: another sync is active; pull skipped"; exit 0; }
      ensure_repo
      git_auth
      git -C "$REPO" pull --ff-only
      [ -f "$REPO/$BLOB" ] || die "remote has no $BLOB yet; run zen-profile-push on the writer host"
      ensure_profile

      tmpdir="$(mktemp -d)"
      archive="$tmpdir/profile.tar"
      stage="$tmpdir/stage"
      mkdir -p "$stage"
      trap 'rm -rf "$tmpdir"' EXIT
      age -d -i "$IDENTITY" -o "$archive" "$REPO/$BLOB"

      while IFS= read -r entry; do
        allowed=0
        for f in "''${FILES[@]}"; do
          [ "$entry" = "$f" ] && allowed=1
        done
        [ "$allowed" -eq 1 ] || die "unexpected archive entry: $entry"
      done < <(tar tf "$archive")
      tar xf "$archive" -C "$stage"

      if zen_running; then
        echo "zen-profile: Zen started during pull; apply skipped"
        exit 0
      fi

      pdir="$(profile_dir)"
      for f in "''${FILES[@]}"; do
        target="$pdir/$f"
        rm -f -- "$target"
        if [ -e "$stage/$f" ]; then
          mkdir -p "$(dirname "$target")"
          cp -a -- "$stage/$f" "$target"
        fi
      done
      echo "zen-profile: pulled into $pdir"
    '';
  };

  push = pkgs.writeShellApplication {
    name = "zen-profile-push";
    runtimeInputs = with pkgs; [
      age
      coreutils
      gawk
      git
      gnugrep
      gnupg
      gnused
      gnutar
      openssh
      procps
      util-linux
    ];
    text = ''
      ${common}

      if zen_running; then
        echo "zen-profile: Zen running; snapshot skipped"
        exit 0
      fi
      [ -f "$IDENTITY" ] || die "no identity at $IDENTITY; provision from vault"

      open_lock
      flock -w 120 9 || die "timed out waiting for sync lock"
      ensure_repo
      git_auth
      git -C "$REPO" pull --ff-only
      if zen_running; then
        echo "zen-profile: Zen started while waiting; snapshot skipped"
        exit 0
      fi

      pdir="$(profile_dir)"
      present=()
      for f in "''${FILES[@]}"; do
        [ -e "$pdir/$f" ] && present+=("$f")
      done
      [ ''${#present[@]} -gt 0 ] || die "no profile files found in $pdir"

      tmpdir="$(mktemp -d)"
      snapshot="$tmpdir/profile.tar"
      previous="$tmpdir/previous.tar"
      encrypted="$tmpdir/$BLOB"
      trap 'rm -rf "$tmpdir"' EXIT
      tar --format=gnu --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
        -cf "$snapshot" -C "$pdir" "''${present[@]}"

      if zen_running; then
        echo "zen-profile: Zen started during snapshot; snapshot discarded"
        exit 0
      fi

      changed=1
      if [ -f "$REPO/$BLOB" ]; then
        age -d -i "$IDENTITY" -o "$previous" "$REPO/$BLOB"
        if cmp -s "$snapshot" "$previous"; then
          changed=0
        fi
      fi

      if [ "$changed" -eq 1 ]; then
        age -r "${recipient}" -o "$encrypted" "$snapshot"
        mv "$encrypted" "$REPO/$BLOB"
        git -C "$REPO" add "$BLOB"
        git -C "$REPO" \
          -c commit.gpgsign=false \
          -c user.name="${committerName}" \
          -c user.email="${committerEmail}" \
          commit -m "update from $(uname -n) $(date -u +%Y-%m-%dT%H:%MZ)"
      else
        echo "zen-profile: profile content unchanged"
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
      pkgs.coreutils
      pkgs.procps
      pkgs.systemd
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
          echo "zen-profile: Zen closed; scheduling profile push"
          systemctl --user start --no-block zen-profile-push.service
          was_running=0
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

  universe.doctor.activeUserServices = lib.optional isPushHost "zen-profile-close-watcher";

  systemd.user = lib.mkIf isPushHost {
    services = {
      zen-profile-push = {
        Unit = {
          Description = "Push the Zen profile snapshot";
          After = [ "gpg-agent.service" ];
          OnFailure = [
            "notify-failure@%n.service"
            "zen-profile-push-retry.timer"
          ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${push}/bin/zen-profile-push";
          TimeoutStartSec = "180s";
        };
      };

      zen-profile-close-watcher = {
        Unit = {
          Description = "Detect Zen close events";
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
          X-SwitchMethod = "keep-old";
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

    timers.zen-profile-push-retry = {
      Unit.Description = "Retry a failed Zen profile push";
      Timer = {
        OnActiveSec = "5min";
        Unit = "zen-profile-push.service";
      };
    };
  };
}
