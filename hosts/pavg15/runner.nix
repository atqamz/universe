{
  config,
  lib,
  pkgs,
  ...
}:
let
  orgName = "yes2games";
  hostLabel = "pavg15";
  image = "docker.io/myoung34/github-runner:2.335.1-ubuntu-noble@sha256:65e12ef91693ca37a71ecf2194260e4c9903b89cea3b2312d545469b62680fc8";
  appPemPath = "/var/lib/github-runner/app-key.pem";
  appId = "4084467";
  installationId = "141074387";
  tokenGroup = "github-runner-token";
  tokenDir = "/run/github-runner-token";
  tokenEnv = "${tokenDir}/token.env";
  hookInContainer = "/opt/runner-hooks/job-completed.sh";

  hotRoot = "/var/lib/ci";
  bulkRoot = "${hotRoot}/bulk";

  # Rootless Podman resolves newuidmap through PATH, and the store copy carries no
  # setuid bit; only the wrapper does. systemd's `path` runs through makeBinPath,
  # which re-appends /bin, so it takes the parent of security.wrapperDir.
  wrapperPath = dirOf config.security.wrapperDir;

  # A warm runner keeps its container HOME between jobs, so `unity install` finds
  # the Editor already there and `actions/checkout` fetches into an existing clone
  # instead of downloading ~13 GB of Editor and re-cloning 20 GB of nsr every run.
  # That state is cross-job, so warm runners are only safe on repositories that
  # take no fork pull requests; the light class stays disposable for everything else.
  classes = {
    heavy = {
      count = 2;
      memory = "14g";
      cpus = "9";
      cpuWeight = 100;
      nice = 0;
      warm = true;
      # Only the first runner of a class carries these. GitHub requires a runner to
      # hold every label in `runs-on`, so a build job asking for `builder` pins to one
      # runner while the other stays free for tests; a constant `concurrency:` group
      # would instead cancel every matrix leg past the first pending one.
      soleLabels = [ "builder" ];
      stateRoot = hotRoot;
    };
    light = {
      count = 6;
      memory = "2g";
      cpus = "2";
      cpuWeight = 20;
      nice = 10;
      warm = false;
      stateRoot = bulkRoot;
    };
  };

  runners = lib.concatMap (
    class:
    map (n: {
      inherit class;
      inherit (classes.${class})
        memory
        cpus
        cpuWeight
        nice
        warm
        stateRoot
        ;
      labels = [
        "self-hosted"
        hostLabel
        class
      ]
      ++ lib.optionals (n == 1) (classes.${class}.soleLabels or [ ]);
      name = "${class}-${toString n}";
    }) (lib.range 1 classes.${class}.count)
  ) (lib.attrNames classes);

  userFor = r: "github-runner-${r.name}";
  baseFor = r: "${r.stateRoot}/${r.name}";
  homeFor = r: "${baseFor r}/home";
  containerRootFor = r: "${baseFor r}/root";
  workFor = r: "${baseFor r}/work";
  runtimeFor = r: "${userFor r}-podman";
  socketFor = r: "/run/${runtimeFor r}/podman.sock";
  runnerNameFor = r: "${hostLabel}-${r.name}";
  containerFor = r: "${runnerNameFor r}-runner";
  podmanUnitFor = r: "github-runner-podman-${r.name}";
  runnerUnitFor = r: "github-runner-${r.name}";

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
          r:
          map (repo: {
            name = "${workFor r}/${repo}/${repo}";
            value.hasTrustDialogAccepted = true;
          }) claudeTrustedRepos
        ) runners
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

  # systemd-tmpfiles cannot create these: on a live switch it runs in the same
  # transaction as the bulk mount, so anything it writes under bulkRoot is created
  # on the underlying directory and then shadowed the moment sda2 mounts over it.
  # This oneshot is ordered after the mount instead.
  runnerDirs = pkgs.writeShellApplication {
    name = "github-runner-dirs";
    runtimeInputs = [ pkgs.coreutils ];
    text = lib.concatMapStringsSep "\n" (
      r:
      ''
        install -d -o ${userFor r} -g ${userFor r} -m 0750 ${baseFor r} ${homeFor r} ${workFor r}
      ''
      + lib.optionalString r.warm ''
        install -d -o ${userFor r} -g ${userFor r} -m 0750 ${containerRootFor r}
        [ -e ${containerRootFor r}/.claude.json ] \
          || install -o ${userFor r} -g ${userFor r} -m 0640 /dev/null ${containerRootFor r}/.claude.json
      ''
    ) runners;
  };
  cleanupFor =
    r:
    pkgs.writeShellApplication {
      name = "github-runner-${r.name}-cleanup";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.podman
      ];
      text = ''
        podman rm --all --force
        podman pod rm --all --force
        podman volume rm --all --force
        podman network prune --force
        work="${workFor r}"
        [ -d "$work" ] && find "$work" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
      '';
    };

  mkPodmanService = r: {
    description = "Rootless Podman API for ${userFor r}";
    after = [ "github-runner-dirs.service" ];
    requires = [ "github-runner-dirs.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ wrapperPath ];
    unitConfig.RequiresMountsFor = [ r.stateRoot ];
    environment = {
      HOME = homeFor r;
      XDG_RUNTIME_DIR = "/run/${runtimeFor r}";
    };
    serviceConfig = {
      User = userFor r;
      Group = userFor r;
      RuntimeDirectory = runtimeFor r;
      RuntimeDirectoryMode = "0700";
      Delegate = true;
      UMask = "0077";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.podman}/bin/podman system service --time=0 unix://${socketFor r}";
    };
  };

  mkRunnerService = r: {
    description = "GitHub Actions self-hosted runner (${orgName}, ${runnerNameFor r})";
    after = [
      "network-online.target"
      "github-runner-dirs.service"
      "github-runner-token-refresh.service"
      "${podmanUnitFor r}.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "github-runner-dirs.service"
      "github-runner-token-refresh.service"
      "${podmanUnitFor r}.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [ wrapperPath ];
    unitConfig = {
      ConditionPathExists = tokenEnv;
      RequiresMountsFor = [ r.stateRoot ];
    };
    environment = {
      HOME = homeFor r;
      XDG_RUNTIME_DIR = "/run/${runtimeFor r}";
    };
    serviceConfig = {
      User = userFor r;
      Group = userFor r;
      Restart = "always";
      RestartSec = "10s";
      CPUWeight = r.cpuWeight;
      Nice = r.nice;
      ExecStartPre = "-${pkgs.podman}/bin/podman rm -f ${containerFor r}";
      ExecStart = lib.concatStringsSep " " (
        [
          # The image is pinned by digest, so `missing` pulls exactly once per bump
          # instead of re-downloading it on every ephemeral restart.
          "${pkgs.podman}/bin/podman run --rm --replace --pull=missing --name ${containerFor r}"
          "--env-file ${tokenEnv}"
          "-e RUNNER_SCOPE=org"
          "-e ORG_NAME=${orgName}"
          "-e RUNNER_NAME=${runnerNameFor r}"
          "-e LABELS=${lib.concatStringsSep "," r.labels}"
          "-e EPHEMERAL=true"
          "-e DISABLE_AUTO_UPDATE=true"
          "-e DISABLE_AUTOMATIC_DEREGISTRATION=true"
          "-e RUNNER_WORKDIR=${workFor r}"
        ]
        ++ lib.optional (!r.warm) "-e ACTIONS_RUNNER_HOOK_JOB_COMPLETED=${hookInContainer}"
        ++ [
          "-v ${socketFor r}:/var/run/docker.sock"
          # Container actions run `docker run -v` from inside the runner, so the
          # workdir must exist at the same path on the host.
          "-v ${workFor r}:${workFor r}"
        ]
        # The warm /root must be bound before the trust file that lands inside it.
        ++ lib.optional r.warm "-v ${containerRootFor r}:/root"
        ++ [
          "-v ${claudeTrust}:/root/.claude.json:ro"
        ]
        ++ lib.optional (!r.warm) "-v ${jobCompletedHook}:${hookInContainer}:ro"
        ++ [
          "--memory=${r.memory}"
          "--cpus=${r.cpus}"
          image
        ]
      );
    }
    // lib.optionalAttrs (!r.warm) {
      ExecStopPost = "${cleanupFor r}/bin/github-runner-${r.name}-cleanup";
    };
  };
in
{
  universe.doctor = {
    activeSystemServices = map runnerUnitFor runners ++ map podmanUnitFor runners;
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
  // lib.listToAttrs (
    map (r: {
      name = userFor r;
      value = {
        isSystemUser = true;
        group = userFor r;
        extraGroups = [ tokenGroup ];
        home = homeFor r;
        # The light class lives on a mount that systemd-tmpfiles brings up; user
        # activation runs too early to create directories there.
        createHome = false;
        autoSubUidGidRange = true;
      };
    }) runners
  );

  users.groups = {
    github-runner = { };
    ${tokenGroup} = { };
  }
  // lib.listToAttrs (
    map (r: {
      name = userFor r;
      value = { };
    }) runners
  );

  systemd = {
    tmpfiles.rules = [
      "d ${tokenDir} 2750 github-runner ${tokenGroup} - -"
      "d ${hotRoot} 0755 root root - -"
    ];

    services = {
      github-runner-dirs = {
        description = "Create GitHub Actions runner state directories";
        wantedBy = [ "multi-user.target" ];
        unitConfig.RequiresMountsFor = [
          hotRoot
          bulkRoot
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${runnerDirs}/bin/github-runner-dirs";
        };
      };

      github-runner-token-refresh = {
        description = "Mint short-lived registration tokens for ${hostLabel} runners";
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
      map (r: {
        name = podmanUnitFor r;
        value = mkPodmanService r;
      }) runners
    )
    // lib.listToAttrs (
      map (r: {
        name = runnerUnitFor r;
        value = mkRunnerService r;
      }) runners
    );

    timers.github-runner-token-refresh = {
      description = "Refresh ${hostLabel} runner registration tokens";
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
