{
  pkgs,
  lib,
  hostname,
  ...
}:
let
  # Hosts that run the auto-update writer. Keep it to one host until the dedup
  # window below is proven; the logic already tolerates several writers racing.
  enabledHosts = [ "pavg15" ];

  repo = "$HOME/universe";
  slug = "atqamz/universe";
  branch = "master";

  update = pkgs.writeShellApplication {
    name = "flake-autoupdate";
    runtimeInputs = with pkgs; [
      git
      gh
      nix
      coreutils
      libnotify
    ];
    text = ''
      repo="${repo}"
      branch="${branch}"
      anon="https://github.com/${slug}.git"
      # Daily cadence: if flake.lock was bumped within this window another device
      # already ran today, so we skip rather than push a duplicate.
      window=$((20 * 3600))

      log() { logger -t flake-autoupdate -- "$*"; printf '%s\n' "$*"; }
      notify() { notify-send "flake-autoupdate" "$1" || true; }

      token=$(gh auth token 2>/dev/null) || { log "gh auth token unavailable, skipping"; exit 0; }
      push_url="https://x-access-token:''${token}@github.com/${slug}.git"

      # Network git must ignore the user gitconfig: its insteadOf rewrite turns
      # https into ssh, which would demand a pinentry the timer cannot answer.
      git_net() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -C "$repo" "$@"; }

      if [ ! -d "$repo/.git" ]; then
        log "cloning $anon -> $repo"
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
          git clone --quiet "$anon" "$repo" || { log "clone failed, skipping"; exit 0; }
      fi

      cur=$(git -C "$repo" rev-parse --abbrev-ref HEAD)
      if [ "$cur" != "$branch" ]; then
        log "on '$cur' not '$branch', skipping"
        exit 0
      fi
      if [ -n "$(git -C "$repo" status --porcelain)" ]; then
        notify "local universe changes uncommitted — skipping auto-update"
        log "dirty tree, skipping"
        exit 0
      fi

      # Pull first: another device may already have bumped the lock.
      if ! git_net fetch --quiet "$anon" "$branch"; then
        log "fetch failed, skipping"
        exit 0
      fi
      if ! git -C "$repo" merge --ff-only --quiet FETCH_HEAD; then
        notify "universe diverged from origin/$branch — skipping auto-update"
        log "non-fast-forward, skipping"
        exit 0
      fi

      last=$(git -C "$repo" log -1 --format=%ct -- flake.lock 2>/dev/null || echo 0)
      now=$(date +%s)
      if [ $((now - last)) -lt "$window" ]; then
        log "flake.lock bumped $(((now - last) / 3600))h ago (< window), skipping"
        exit 0
      fi

      export NIX_CONFIG="access-tokens = github.com=''${token}"
      before=$(sha256sum "$repo/flake.lock" | cut -d' ' -f1)
      if ! nix flake update --flake "$repo"; then
        log "nix flake update failed"
        exit 1
      fi
      after=$(sha256sum "$repo/flake.lock" | cut -d' ' -f1)
      if [ "$before" = "$after" ]; then
        log "inputs already current, nothing to push"
        exit 0
      fi

      git -C "$repo" add flake.lock
      # Unattended path: no tty for pinentry. Signing is intentionally waived for
      # these machine-generated lock bumps only.
      git -C "$repo" commit --no-gpg-sign --quiet -m "flake.lock: auto-update inputs"

      # Suppress stderr on push: a rejected push echoes the tokenized URL.
      if git_net push "$push_url" "HEAD:$branch" 2>/dev/null; then
        log "pushed flake.lock update"
        notify "flake.lock auto-updated and pushed"
        exit 0
      fi

      log "push rejected (race), rebasing once"
      if git_net fetch --quiet "$anon" "$branch" \
        && git -C "$repo" rebase --quiet FETCH_HEAD \
        && git_net push "$push_url" "HEAD:$branch" 2>/dev/null; then
        log "pushed after rebase"
        exit 0
      fi

      log "still rejected, conceding race and resetting to origin"
      git -C "$repo" rebase --abort 2>/dev/null || true
      git_net fetch --quiet "$anon" "$branch" && git -C "$repo" reset --hard --quiet FETCH_HEAD
      exit 0
    '';
  };
in
lib.mkIf (lib.elem hostname enabledHosts) {
  systemd.user.services.flake-autoupdate = {
    Unit.Description = "Refresh universe flake.lock and push";
    Service = {
      Type = "oneshot";
      ExecStart = "${update}/bin/flake-autoupdate";
    };
  };

  systemd.user.timers.flake-autoupdate = {
    Unit.Description = "Daily universe flake auto-update";
    Timer = {
      OnStartupSec = "5min";
      OnCalendar = "daily";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
