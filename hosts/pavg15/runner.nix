{ lib, pkgs, ... }:
let
  count = 4;
  runnerName = "pavg15";
  image = "docker.io/myoung34/github-runner:2.335.1-ubuntu-noble";
  memory = "7g";
  cpus = "2.5";
  appPemPath = "/var/lib/github-runner/app-key.pem";
  appId = "4084467";
  installationId = "141074387";
  orgName = "yes2games";
  tokenGroup = "github-runner-token";
  tokenDir = "/run/github-runner-token";
  tokenEnv = "${tokenDir}/token.env";
  hookInContainer = "/opt/runner-hooks/job-completed.sh";
  runnerIndices = lib.range 1 count;
  runnerUserFor = n: "github-runner-${toString n}";
  runnerHomeFor = n: "/var/lib/${runnerUserFor n}";
  workDirFor = n: "/_work/${runnerName}-${toString n}";
  containerNameFor = n: "${runnerName}-${toString n}-runner";
  podmanRuntimeFor = n: "${runnerUserFor n}-podman";
  podmanSocketFor = n: "/run/${podmanRuntimeFor n}/podman.sock";

  claudeTrustedRepos = [
    "nsr"
    "yes2infra"
    "yes2dashboard"
    "yes2sdk-mcp"
    "rujak"
  ];

  claudeTrust = pkgs.writeText "claude-trust.json" (
    builtins.toJSON {
      projects = lib.listToAttrs (
        lib.concatMap (
          n:
          map (repo: {
            name = "${workDirFor n}/${repo}/${repo}";
            value.hasTrustDialogAccepted = true;
          }) claudeTrustedRepos
        ) runnerIndices
      );
    }
  );

  jobCompletedHook = pkgs.writeTextFile {
    name = "github-runner-job-completed";
    executable = true;
    text = ''
      #!/bin/sh
      set -eu
      work="''${RUNNER_WORKDIR:-}"
      [ -n "$work" ] && [ -d "$work" ] || exit 0
      find "$work" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    '';
  };

  tokenRefresh = pkgs.writeShellApplication {
    name = "github-runner-token-refresh";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      openssl
    ];
    text = ''
      PEM_PATH=''${1:?pem path}
      APP_ID=''${2:?app id}
      INSTALLATION_ID=''${3:?installation id}
      ORG_NAME=''${4:?organization name}
      OUT_FILE=''${5:?output env file}

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
      [[ "$http" = 201 ]] || { echo "refresh: access token request returned HTTP $http" >&2; exit 1; }
      access_token=$(jq -er '.token' "$resp")

      http=$(curl -sS -o "$resp" -w '%{http_code}' -X POST \
        --retry 3 --retry-delay 5 --retry-connrefused --max-time 30 \
        -H "Authorization: Bearer ''${access_token}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "User-Agent: universe-github-runner" \
        "https://api.github.com/orgs/''${ORG_NAME}/actions/runners/registration-token")
      access_token=""
      [[ "$http" = 201 ]] || { echo "refresh: runner token request returned HTTP $http" >&2; exit 1; }
      runner_token=$(jq -er '.token' "$resp")

      printf 'RUNNER_TOKEN=%s\n' "$runner_token" >"$tmp_env"
      runner_token=""
      chgrp ${tokenGroup} "$tmp_env"
      chmod 0640 "$tmp_env"
      mv -f "$tmp_env" "$OUT_FILE"
    '';
  };

  mkPodmanService = n: {
    description = "Rootless Podman API for ${runnerUserFor n}";
    wantedBy = [ "multi-user.target" ];
    environment = {
      HOME = runnerHomeFor n;
      XDG_RUNTIME_DIR = "/run/${podmanRuntimeFor n}";
    };
    serviceConfig = {
      User = runnerUserFor n;
      Group = runnerUserFor n;
      RuntimeDirectory = podmanRuntimeFor n;
      RuntimeDirectoryMode = "0700";
      Delegate = true;
      UMask = "0077";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.podman}/bin/podman system service --time=0 unix://${podmanSocketFor n}";
    };
  };

  cleanupFor =
    n:
    pkgs.writeShellApplication {
      name = "github-runner-${toString n}-cleanup";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.podman
      ];
      text = ''
        podman rm --all --force
        podman pod rm --all --force
        podman volume rm --all --force
        podman image rm --all --force
        podman network prune --force
        work="${workDirFor n}"
        [ -d "$work" ] && find "$work" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
      '';
    };

  mkRunnerService = n: {
    description = "GitHub Actions self-hosted runner (${orgName}, ${runnerNameFor n})";
    after = [
      "network-online.target"
      "github-runner-token-refresh.service"
      "github-runner-podman-${toString n}.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "github-runner-token-refresh.service"
      "github-runner-podman-${toString n}.service"
    ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = tokenEnv;
    environment = {
      HOME = runnerHomeFor n;
      XDG_RUNTIME_DIR = "/run/${podmanRuntimeFor n}";
    };
    serviceConfig = {
      User = runnerUserFor n;
      Group = runnerUserFor n;
      Restart = "always";
      RestartSec = "10s";
      CPUWeight = 20;
      Nice = 10;
      ExecStartPre = "-${pkgs.podman}/bin/podman rm -f ${containerNameFor n}";
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.podman}/bin/podman run --rm --replace --pull=always --name ${containerNameFor n}"
        "--env-file ${tokenEnv}"
        "-e RUNNER_SCOPE=org"
        "-e ORG_NAME=${orgName}"
        "-e RUNNER_NAME=${runnerNameFor n}"
        "-e LABELS=self-hosted,${runnerName},light"
        "-e EPHEMERAL=true"
        "-e DISABLE_AUTO_UPDATE=true"
        "-e DISABLE_AUTOMATIC_DEREGISTRATION=true"
        "-e RUNNER_WORKDIR=${workDirFor n}"
        "-e ACTIONS_RUNNER_HOOK_JOB_COMPLETED=${hookInContainer}"
        "-v ${podmanSocketFor n}:/var/run/docker.sock"
        "-v ${workDirFor n}:${workDirFor n}"
        "-v ${claudeTrust}:/root/.claude.json:ro"
        "-v ${jobCompletedHook}:${hookInContainer}:ro"
        "--memory=${memory}"
        "--cpus=${cpus}"
        image
      ];
      ExecStopPost = "${cleanupFor n}/bin/github-runner-${toString n}-cleanup";
    };
  };

  runnerNameFor = n: "${runnerName}-${toString n}";

  runnerUsers = lib.listToAttrs (
    map (n: {
      name = runnerUserFor n;
      value = {
        isSystemUser = true;
        group = runnerUserFor n;
        extraGroups = [ tokenGroup ];
        home = runnerHomeFor n;
        createHome = true;
        homeMode = "0750";
        autoSubUidGidRange = true;
      };
    }) runnerIndices
  );

  runnerGroups = lib.listToAttrs (
    map (n: {
      name = runnerUserFor n;
      value = { };
    }) runnerIndices
  );
in
{
  universe.doctor = {
    activeSystemServices =
      map (n: "github-runner-${toString n}") runnerIndices
      ++ map (n: "github-runner-podman-${toString n}") runnerIndices;
    systemTimers = [ "github-runner-token-refresh" ];
  };

  users.users = {
    github-runner = {
      isSystemUser = true;
      group = "github-runner";
      extraGroups = [ tokenGroup ];
      home = "/var/lib/github-runner";
      createHome = true;
      homeMode = "0750";
    };
  }
  // runnerUsers;

  users.groups = {
    github-runner = { };
    ${tokenGroup} = { };
  }
  // runnerGroups;

  systemd = {
    tmpfiles.rules = [
      "d ${tokenDir} 2750 github-runner ${tokenGroup} - -"
    ]
    ++ map (n: "d ${workDirFor n} 0750 ${runnerUserFor n} ${runnerUserFor n} - -") runnerIndices;

    services = {
      github-runner-token-refresh = {
        description = "Mint short-lived registration tokens for pavg15 runners";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        unitConfig.ConditionPathExists = appPemPath;
        serviceConfig = {
          Type = "oneshot";
          User = "github-runner";
          Group = "github-runner";
          ExecStart = "${tokenRefresh}/bin/github-runner-token-refresh ${appPemPath} ${appId} ${installationId} ${orgName} ${tokenEnv}";
        };
      };
    }
    // lib.listToAttrs (
      map (n: {
        name = "github-runner-podman-${toString n}";
        value = mkPodmanService n;
      }) runnerIndices
    )
    // lib.listToAttrs (
      map (n: {
        name = "github-runner-${toString n}";
        value = mkRunnerService n;
      }) runnerIndices
    );

    timers.github-runner-token-refresh = {
      description = "Refresh pavg15 runner registration tokens";
      wantedBy = [ "timers.target" ];
      unitConfig.ConditionPathExists = appPemPath;
      timerConfig = {
        OnActiveSec = "1min";
        OnUnitActiveSec = "20min";
        AccuracySec = "1min";
      };
    };
  };
}
