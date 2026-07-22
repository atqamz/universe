{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.pavg15Runner;

  runnerHome = "/var/lib/github-runner";
  workDir = "/_work/${cfg.name}";
  tokenEnv = "${runnerHome}/token.env";
  hookInContainer = "/opt/runner-hooks/job-completed.sh";
  runtimeDir = "/run/github-runner";

  claudeTrust = pkgs.writeText "claude-trust.json" (
    builtins.toJSON {
      projects = lib.listToAttrs (
        map (repo: {
          name = "${workDir}/${repo}/${repo}";
          value.hasTrustDialogAccepted = true;
        }) cfg.claudeTrustedRepos
      );
    }
  );

  jobCompletedHook = pkgs.writeShellApplication {
    name = "github-runner-job-completed";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      work="''${RUNNER_WORKDIR:-${workDir}}"
      [ -d "$work" ] || exit 0
      chown -R runner:runner "$work" 2>/dev/null || chown -R "$(id -u):$(id -g)" "$work" || true
    '';
  };

  tokenRefresh = pkgs.writeShellApplication {
    name = "github-runner-token-refresh";
    runtimeInputs = with pkgs; [
      openssl
      curl
      coreutils
      gnused
    ];
    text = ''
      set -Eeuo pipefail

      PEM_PATH=''${1:?pem path}
      APP_ID=''${2:?app id}
      INSTALLATION_ID=''${3:?installation id}
      OUT_FILE=''${4:?output env file}

      [[ -r "$PEM_PATH" ]] || { echo "refresh: PEM not readable at $PEM_PATH" >&2; exit 1; }

      umask 077
      out_dir=$(dirname "$OUT_FILE")
      mkdir -p "$out_dir"

      resp=$(mktemp)
      tmp_env=$(mktemp "''${out_dir}/.token.XXXXXX")
      trap 'rm -f "$resp" "$tmp_env"' EXIT

      b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

      now=$(date +%s)
      header=$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | b64url)
      claims=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$((now - 30))" "$((now + 540))" "$APP_ID" | b64url)
      signing_input="''${header}.''${claims}"
      sig=$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign "$PEM_PATH" -binary | b64url)
      jwt="''${signing_input}.''${sig}"

      http=$(curl -sS -o "$resp" -w '%{http_code}' -X POST \
        --retry 3 --retry-delay 5 --retry-connrefused --max-time 30 \
        -H "Authorization: Bearer ''${jwt}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "User-Agent: universe-github-runner" \
        "https://api.github.com/app/installations/''${INSTALLATION_ID}/access_tokens")
      jwt=""

      if [[ "$http" != "201" ]]; then
        echo "refresh: access_tokens returned HTTP ''${http}" >&2
        exit 1
      fi

      token=$(sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$resp")
      [[ -n "$token" ]] || { echo "refresh: no token field in access_tokens response" >&2; exit 1; }

      printf 'ACCESS_TOKEN=%s\n' "$token" > "$tmp_env"
      token=""
      chmod 600 "$tmp_env"
      mv -f "$tmp_env" "$OUT_FILE"
    '';
  };
in
{
  options.services.pavg15Runner = {
    enable = lib.mkEnableOption "GitHub Actions self-hosted runner (yes2games org) on pavg15";

    name = lib.mkOption {
      type = lib.types.str;
      default = "pavg15";
      description = "Runner name and DooD work-directory suffix (/_work/<name>).";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/myoung34/github-runner:2.335.1-ubuntu-noble";
      description = "Runner container image, pinned by tag (matches the tencent/bakso fleet).";
    };

    appPemPath = lib.mkOption {
      type = lib.types.str;
      default = "${runnerHome}/app-key.pem";
      description = ''
        Path to the butler GitHub App PEM used to mint installation tokens.
        Provide this later via sops (owner github-runner, mode 0400); until it
        exists the token-refresh and runner units stay inactive by condition.
      '';
    };

    appId = lib.mkOption {
      type = lib.types.str;
      default = "4084467";
      description = "Butler GitHub App id (non-secret constant, matches yes2infra).";
    };

    installationId = lib.mkOption {
      type = lib.types.str;
      default = "141074387";
      description = "Butler GitHub App installation id (non-secret constant, matches yes2infra).";
    };

    memory = lib.mkOption {
      type = lib.types.str;
      default = "4g";
      description = "Container memory cap (half the laptop's resources).";
    };

    cpus = lib.mkOption {
      type = lib.types.str;
      default = "2";
      description = "Container CPU cap (half the laptop's resources).";
    };

    claudeTrustedRepos = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "nsr"
        "yes2infra"
        "yes2dashboard"
        "yes2sdk-mcp"
        "rujak"
      ];
      description = ''
        Repo checkout-dir names pre-trusted in /root/.claude.json so
        claude-code-action jobs are not SIGKILLed by the workspace-trust gate
        (yes2infra#350). Each pre-trusts /_work/<name>/<repo>/<repo>.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.github-runner = {
      isSystemUser = true;
      group = "github-runner";
      extraGroups = [ "docker" ];
      home = runnerHome;
      createHome = true;
      homeMode = "0750";
      autoSubUidGidRange = true;
    };
    users.groups.github-runner = { };

    systemd = {
      tmpfiles.rules = [
        "d ${workDir} 0755 github-runner github-runner - -"
      ];

      services.github-runner-token-refresh = {
        description = "Refresh butler App installation token for the pavg15 org runner";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        unitConfig.ConditionPathExists = cfg.appPemPath;
        serviceConfig = {
          Type = "oneshot";
          User = "github-runner";
          Group = "github-runner";
          ExecStart = "${tokenRefresh}/bin/github-runner-token-refresh ${cfg.appPemPath} ${cfg.appId} ${cfg.installationId} ${tokenEnv}";
        };
      };

      timers.github-runner-token-refresh = {
        description = "Periodic butler App token refresh for the pavg15 org runner";
        wantedBy = [ "timers.target" ];
        unitConfig.ConditionPathExists = cfg.appPemPath;
        timerConfig = {
          OnActiveSec = "1min";
          OnUnitActiveSec = "20min";
          AccuracySec = "1min";
        };
      };

      services.github-runner = {
        description = "GitHub Actions self-hosted runner (yes2games org, ${cfg.name} light)";
        after = [
          "network-online.target"
          "github-runner-token-refresh.service"
        ];
        wants = [ "network-online.target" ];
        requires = [ "github-runner-token-refresh.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.podman ];
        unitConfig.ConditionPathExists = tokenEnv;
        environment = {
          HOME = runnerHome;
          XDG_RUNTIME_DIR = runtimeDir;
        };
        serviceConfig = {
          User = "github-runner";
          Group = "github-runner";
          RuntimeDirectory = "github-runner";
          Restart = "always";
          RestartSec = "10s";
          CPUWeight = 20;
          Nice = 10;
          ExecStartPre = "-${pkgs.podman}/bin/podman rm -f ${cfg.name}-runner";
          ExecStart = lib.concatStringsSep " " [
            "${pkgs.podman}/bin/podman run --rm --replace --name ${cfg.name}-runner"
            "--env-file ${tokenEnv}"
            "-e RUNNER_SCOPE=org"
            "-e ORG_NAME=yes2games"
            "-e RUNNER_NAME=${cfg.name}"
            "-e LABELS=self-hosted,${cfg.name},light"
            "-e EPHEMERAL=true"
            "-e DISABLE_AUTO_UPDATE=true"
            "-e RUNNER_WORKDIR=${workDir}"
            "-e ACTIONS_RUNNER_HOOK_JOB_COMPLETED=${hookInContainer}"
            "-v /run/docker.sock:/var/run/docker.sock"
            "-v ${workDir}:${workDir}"
            "-v ${claudeTrust}:/root/.claude.json:ro"
            "-v ${jobCompletedHook}/bin/github-runner-job-completed:${hookInContainer}:ro"
            "--group-add keep-groups"
            "--memory=${cfg.memory}"
            "--cpus=${cfg.cpus}"
            cfg.image
          ];
          ExecStopPost = "-${pkgs.podman}/bin/podman rm -f ${cfg.name}-runner";
        };
      };
    };
  };
}
