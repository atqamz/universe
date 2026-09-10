{
  config,
  lib,
  pkgs,
  ...
}:
let
  orgName = "yes2games";
  hostLabel = "pavg15";
  imageRepo = "docker.io/myoung34/github-runner";
  imageTag = "2.335.1-ubuntu-noble";
  imageDigest = "sha256:65e12ef91693ca37a71ecf2194260e4c9903b89cea3b2312d545469b62680fc8";

  localImage = "localhost/github-runner:${imageTag}-${lib.substring 7 12 imageDigest}";
  imageCacheDir = "${hotRoot}/image-cache";
  imageArchive = "${imageCacheDir}/runner.tar";
  imageStamp = "${imageCacheDir}/digest";

  unityRuntimePackages = [
    "libasound2t64"
    "libatk1.0-0t64"
    "libcairo-gobject2"
    "libcairo2"
    "libdbus-1-3"
    "libdecor-0-0"
    "libfontconfig1"
    "libgbm1"
    "libgdk-pixbuf-2.0-0"
    "libgl1"
    "libglu1-mesa"
    "libgtk-3-0t64"
    "libharfbuzz0b"
    "libnss3"
    "libpango-1.0-0"
    "libpangocairo-1.0-0"
    "libwayland-client0"
    "libwayland-cursor0"
    "libx11-6"
    "libxcursor1"
    "libxi6"
    "libxrandr2"
    "libxtst6"
  ];
  unityImage = "localhost/github-runner-unity:${imageTag}-${lib.substring 7 12 imageDigest}-${
    lib.substring 0 12 (builtins.hashString "sha256" (lib.concatStringsSep " " unityRuntimePackages))
  }";
  unityArchive = "${imageCacheDir}/runner-unity.tar";
  unityStamp = "${imageCacheDir}/unity-image";
  appPemPath = "/var/lib/github-runner/app-key.pem";
  appId = "4084467";
  installationId = "141074387";
  tokenGroup = "github-runner-token";
  tokenDir = "/run/github-runner-token";
  tokenEnv = "${tokenDir}/token.env";
  hookInContainer = "/opt/runner-hooks/job-completed.sh";

  hotRoot = "/var/lib/ci";
  bulkRoot = "${hotRoot}/bulk";

  wrapperPath = dirOf config.security.wrapperDir;

  classes = {
    heavy = {
      count = 2;
      memory = "14g";
      cpus = "9";
      cpuWeight = 100;
      nice = 0;
      warm = true;
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
  toolCacheFor = r: "${toolCacheRoot}/${r.name}";
  denoCacheFor = r: "${denoCacheRoot}/${r.name}";
  runtimeFor = r: "${userFor r}-podman";
  socketFor = r: "/run/${runtimeFor r}/podman.sock";
  runnerNameFor = r: "${hostLabel}-${r.name}";
  containerFor = r: "${runnerNameFor r}-runner";
  podmanUnitFor = r: "github-runner-podman-${r.name}";
  runnerUnitFor = r: "github-runner-${r.name}";

  # Every mirrored repo runs jobs here, so any of them can gain a Claude workflow.
  # Deriving trust from the mirror list keeps the two from drifting apart: an
  # untrusted workspace makes claude-code-action write to the read-only
  # /root/.claude.json and die with a bare "[Errno 30] Read-only file system".
  claudeTrustedRepos = lib.unique (
    mirroredRepos
    ++ [
      "yes2infra"
      "yes2dashboard"
      "yes2sdk-mcp"
    ]
  );

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

  mirrorRoot = "${hotRoot}/mirrors";
  mirroredRepos = [
    "nsr"
    "butler"
    "nsr-nakama"
    "nsr-webtransport"
    "rujak"
  ];
  startedHookInContainer = "/opt/runner-hooks/job-started.sh";

  toolCacheRoot = "${hotRoot}/toolcache";
  toolCacheInContainer = "/opt/hostedtoolcache";

  denoCacheRoot = "${hotRoot}/denocache";
  denoCacheInContainer = "/opt/denocache";

  ciTools = pkgs.buildEnv {
    name = "pavg15-ci-tools";
    paths = [
      pkgs.shellcheck
      (pkgs.dotnetCorePackages.combinePackages [
        pkgs.dotnetCorePackages.sdk_8_0
        pkgs.dotnetCorePackages.sdk_9_0
      ])
    ];
  };
  ciToolsInContainer = "/opt/ci-tools";

  editorRoot = "${hotRoot}/editors";
  editorInContainer = "/root/Unity/Hub/Editor";
  unityEditors = [
    {
      version = "6000.3.16f1";
      changeset = "a56f230f6470";
      modules = [
        "WebGL"
        "Linux-Server"
      ];
    }
  ];

  mirrorRefresh = pkgs.writeShellApplication {
    name = "github-runner-mirror-refresh";
    runtimeInputs = with pkgs; [
      appToken
      coreutils
      git
    ];
    text = ''
      token=$(github-app-token ${appPemPath} ${appId} ${installationId})
      # Environment avoids persisting the token in the remote URL or process list.
      GIT_CONFIG_VALUE_0="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$token" | base64 -w0)"
      token=""
      export GIT_CONFIG_COUNT=1
      export GIT_CONFIG_KEY_0=http.extraheader
      export GIT_CONFIG_VALUE_0

      install -d -m 0755 ${mirrorRoot}
      repos=(${lib.concatMapStringsSep " " lib.escapeShellArg mirroredRepos})
      failed=0
      for repo in "''${repos[@]}"; do
        dir=${mirrorRoot}/$repo.git
        if ! (
          set -e
          if [ -d "$dir" ]; then
            git -C "$dir" remote update --prune
          else
            rm -rf "$dir.new"
            git clone --mirror "https://github.com/${orgName}/$repo.git" "$dir.new"
            # Borrowing clones require the mirror to retain every referenced object.
            git -C "$dir.new" config gc.auto 0
            git -C "$dir.new" config gc.pruneExpire never
            mv "$dir.new" "$dir"
          fi
          chmod -R a+rX "$dir"
        ); then
          echo "mirror refresh failed for $repo" >&2
          failed=$((failed + 1))
        fi
      done
      # One broken repository must not block refreshes for the rest of the fleet.
      [ "$failed" -lt "''${#repos[@]}" ]
    '';
  };

  jobStartedHook = pkgs.writeTextFile {
    name = "github-runner-job-started";
    executable = true;
    text = ''
      #!/bin/sh
      set -u
      [ -n "''${GITHUB_REPOSITORY:-}" ] || exit 0
      [ -n "''${RUNNER_WORKDIR:-}" ] || exit 0
      name=''${GITHUB_REPOSITORY##*/}
      mirror=${mirrorRoot}/$name.git
      dir=$RUNNER_WORKDIR/$name/$name
      [ -d "$mirror" ] || exit 0
      [ -z "$(ls -A "$dir" 2>/dev/null)" ] || exit 0
      mkdir -p "$dir" || exit 0
      # Rootless ownership requires safe.directory from a temporary global config.
      cfg=$RUNNER_WORKDIR/.git-mirror-config
      printf '[safe]\n\tdirectory = %s\n' "$mirror" > "$cfg" || exit 0
      if ! GIT_CONFIG_GLOBAL=$cfg git clone --shared --no-checkout "$mirror" "$dir"; then
        rm -f "$cfg"
        rm -rf "$dir"
        exit 0
      fi
      rm -f "$cfg"
      git -C "$dir" remote set-url origin "https://github.com/$GITHUB_REPOSITORY"
    '';
  };

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

  appToken = pkgs.writeShellApplication {
    name = "github-app-token";
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

      [[ -r "$PEM_PATH" ]] || { echo "token: PEM not readable at $PEM_PATH" >&2; exit 1; }

      umask 077
      resp=$(mktemp)
      trap 'rm -f "$resp"' EXIT

      b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

      now=$(date +%s)
      header=$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | b64url)
      claims=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$((now - 30))" "$((now + 540))" "$APP_ID" | b64url)
      signing_input="''${header}.''${claims}"
      sig=$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign "$PEM_PATH" -binary | b64url)

      http=$(curl -sS -o "$resp" -w '%{http_code}' -X POST \
        --retry 3 --retry-delay 5 --retry-connrefused --max-time 30 \
        -H "Authorization: Bearer ''${signing_input}.''${sig}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "User-Agent: universe-github-runner" \
        "https://api.github.com/app/installations/''${INSTALLATION_ID}/access_tokens")
      [[ "$http" = 201 ]] || { echo "token: access token request returned HTTP $http" >&2; exit 1; }
      jq -er '.token' "$resp"
    '';
  };

  tokenRefresh = pkgs.writeShellApplication {
    name = "github-runner-token-refresh";
    runtimeInputs = with pkgs; [
      appToken
      coreutils
      curl
      jq
    ];
    text = ''
      PEM_PATH=''${1:?pem path}
      APP_ID=''${2:?app id}
      INSTALLATION_ID=''${3:?installation id}
      ORG_NAME=''${4:?organization name}
      OUT_FILE=''${5:?output env file}

      umask 077
      out_dir=$(dirname "$OUT_FILE")
      mkdir -p "$out_dir"
      resp=$(mktemp)
      tmp_env=$(mktemp "''${out_dir}/.token.XXXXXX")
      trap 'rm -f "$resp" "$tmp_env"' EXIT

      access_token=$(github-app-token "$PEM_PATH" "$APP_ID" "$INSTALLATION_ID")

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

  runnerDirs = pkgs.writeShellApplication {
    name = "github-runner-dirs";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      install -d -m 0755 ${mirrorRoot} ${editorRoot} ${toolCacheRoot} ${denoCacheRoot}
    ''
    + lib.concatMapStringsSep "\n" (
      r:
      ''
        install -d -o ${userFor r} -g ${userFor r} -m 0750 ${baseFor r} ${homeFor r} ${workFor r}
        install -d -o ${userFor r} -g ${userFor r} -m 0750 ${toolCacheFor r} ${denoCacheFor r}
      ''
      + lib.optionalString r.warm ''
        install -d -o ${userFor r} -g ${userFor r} -m 0750 ${containerRootFor r}
        [ -e ${containerRootFor r}/.claude.json ] \
          || install -o ${userFor r} -g ${userFor r} -m 0640 /dev/null ${containerRootFor r}/.claude.json
      ''
    ) runners;
  };

  editorCache = pkgs.writeShellApplication {
    name = "github-runner-editor-cache";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnutar
      xz
    ];
    text = ''
      base=https://download.unity3d.com/download_unity

      # A file-backed transfer can resume after the home WiFi link drops.
      fetch() {
        url=$1
        into=$2
        file=$3/''${url##*/}
        # xz validates a resumed file even when curl answers 416 for a complete archive.
        curl -fL --retry 10 --retry-all-errors --retry-delay 5 -C - -o "$file" "$url" || true
        xz -t "$file"
        tar -xJf "$file" -C "$into"
      }

      seed() {
        version=$1
        changeset=$2
        shift 2
        want="$changeset $*"
        if [ "$(cat ${editorRoot}/"$version"/.seeded 2>/dev/null)" = "$want" ]; then
          echo "editor $version already seeded"
          return 0
        fi

        cache=${editorRoot}/.cache-$version
        staging=${editorRoot}/.staging-$version
        install -d -m 0755 "$cache"
        rm -rf "$staging"
        install -d -m 0755 "$staging"

        echo "fetching editor $version ($changeset)"
        fetch "$base/$changeset/LinuxEditorInstaller/Unity.tar.xz" "$staging" "$cache"
        for module in "$@"; do
          echo "fetching module $module"
          fetch "$base/$changeset/LinuxEditorTargetInstaller/UnitySetup-$module-Support-for-Editor-$version.tar.xz" \
            "$staging" "$cache"
        done

        test -x "$staging/Editor/Unity"
        printf '%s' "$want" > "$staging/.seeded"
        chmod -R a+rX "$staging"
        rm -rf ${editorRoot}/"$version"
        mv "$staging" ${editorRoot}/"$version"
        rm -rf "$cache"
        echo "editor $version seeded"
      }

    ''
    + lib.concatMapStringsSep "\n" (
      e: "seed ${e.version} ${e.changeset} ${lib.concatStringsSep " " e.modules}"
    ) unityEditors;
  };

  imageCache = pkgs.writeShellApplication {
    name = "github-runner-image-cache";
    runtimeInputs = with pkgs; [
      coreutils
      skopeo
    ];
    text = ''
      if [ -f ${imageStamp} ] && [ -f ${imageArchive} ] \
        && [ "$(cat ${imageStamp})" = "${imageDigest}" ]; then
        exit 0
      fi
      install -d -m 0755 ${imageCacheDir}
      skopeo copy --retry-times 5 \
        docker://${imageRepo}@${imageDigest} docker-archive:${imageArchive}.new:${localImage}
      chmod 0644 ${imageArchive}.new
      mv -f ${imageArchive}.new ${imageArchive}
      printf '%s' '${imageDigest}' > ${imageStamp}
      chmod 0644 ${imageStamp}
    '';
  };

  unityContainerfile = pkgs.writeText "runner-unity.Containerfile" ''
    FROM ${localImage}
    RUN apt-get update \
      && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ${lib.concatStringsSep " " unityRuntimePackages} \
      && rm -rf /var/lib/apt/lists/*
  '';

  unityImageBuild = pkgs.writeShellApplication {
    name = "github-runner-unity-image-build";
    runtimeInputs = with pkgs; [
      coreutils
      podman
    ];
    text = ''
      if [ -f ${unityStamp} ] && [ -f ${unityArchive} ] \
        && [ "$(cat ${unityStamp})" = "${unityImage}" ]; then
        exit 0
      fi
      install -d -m 0755 ${imageCacheDir}
      podman image exists ${localImage} || podman load -i ${imageArchive}
      podman build --pull=never -t ${unityImage} \
        -f ${unityContainerfile} ${pkgs.emptyDirectory}
      podman save -o ${unityArchive}.new ${unityImage}
      chmod 0644 ${unityArchive}.new
      mv -f ${unityArchive}.new ${unityArchive}
      printf '%s' '${unityImage}' > ${unityStamp}
      chmod 0644 ${unityStamp}
    '';
  };

  imageLoad = pkgs.writeShellApplication {
    name = "github-runner-image-load";
    runtimeInputs = [ pkgs.podman ];
    text = ''
      podman image exists ${unityImage} || podman load -i ${unityArchive}
    '';
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
    after = [
      "github-runner-dirs.service"
      "github-runner-unity-image.service"
    ];
    requires = [
      "github-runner-dirs.service"
      "github-runner-unity-image.service"
    ];
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
      "github-runner-unity-image.service"
      "github-runner-token-refresh.service"
      "${podmanUnitFor r}.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "github-runner-dirs.service"
      "github-runner-unity-image.service"
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
      ExecStartPre = [
        "-${pkgs.podman}/bin/podman rm -f ${containerFor r}"
        "${imageLoad}/bin/github-runner-image-load"
      ];
      ExecStart = lib.concatStringsSep " " (
        [
          "${pkgs.podman}/bin/podman run --rm --replace --pull=never --name ${containerFor r}"
          "--env-file ${tokenEnv}"
          "-e RUNNER_SCOPE=org"
          "-e ORG_NAME=${orgName}"
          "-e RUNNER_NAME=${runnerNameFor r}"
          "-e LABELS=${lib.concatStringsSep "," r.labels}"
          "-e EPHEMERAL=true"
          "-e DISABLE_AUTO_UPDATE=true"
          "-e DISABLE_AUTOMATIC_DEREGISTRATION=true"
          "-e RUNNER_WORKDIR=${workFor r}"
          "-e PATH=${ciToolsInContainer}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          "-e DOTNET_ROOT=${ciToolsInContainer}"
          "-e DOTNET_CLI_TELEMETRY_OPTOUT=1"
          "-e DOTNET_NOLOGO=1"
          "-e AGENT_TOOLSDIRECTORY=${toolCacheInContainer}"
          "-e DENO_DIR=${denoCacheInContainer}"
        ]
        ++ lib.optional (!r.warm) "-e ACTIONS_RUNNER_HOOK_JOB_COMPLETED=${hookInContainer}"
        ++ [
          "-e ACTIONS_RUNNER_HOOK_JOB_STARTED=${startedHookInContainer}"
        ]
        ++ [
          "-v ${socketFor r}:/var/run/docker.sock"
          "-v ${workFor r}:${workFor r}"
        ]
        ++ lib.optional r.warm "-v ${containerRootFor r}:/root"
        ++ [
          "-v ${claudeTrust}:/root/.claude.json:ro"
          "-v ${editorRoot}:${editorInContainer}:O"
        ]
        ++ [
          "-v ${mirrorRoot}:${mirrorRoot}:ro"
          "-v ${toolCacheFor r}:${toolCacheInContainer}"
          "-v ${denoCacheFor r}:${denoCacheInContainer}"
          "-v ${ciTools}:${ciToolsInContainer}:ro"
          "-v /nix/store:/nix/store:ro"
          "-v ${jobStartedHook}:${startedHookInContainer}:ro"
        ]
        ++ lib.optional (!r.warm) "-v ${jobCompletedHook}:${hookInContainer}:ro"
        ++ [
          "--memory=${r.memory}"
          "--cpus=${r.cpus}"
          unityImage
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

      github-runner-image-cache = {
        description = "Fetch the GitHub Actions runner image into a local archive";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        unitConfig.RequiresMountsFor = [ hotRoot ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${imageCache}/bin/github-runner-image-cache";
        };
      };

      github-runner-unity-image = {
        description = "Add the Unity Editor's runtime libraries to the runner image";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "github-runner-image-cache.service"
        ];
        wants = [ "network-online.target" ];
        requires = [ "github-runner-image-cache.service" ];
        unitConfig.RequiresMountsFor = [ hotRoot ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${unityImageBuild}/bin/github-runner-unity-image-build";
          TimeoutStartSec = "1h";
        };
      };

      github-runner-editor-cache = {
        description = "Seed the Unity Editors the fleet builds against";
        after = [
          "network-online.target"
          "github-runner-dirs.service"
        ];
        wants = [ "network-online.target" ];
        requires = [ "github-runner-dirs.service" ];
        unitConfig.RequiresMountsFor = [ hotRoot ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${editorCache}/bin/github-runner-editor-cache";
          TimeoutStartSec = "6h";
        };
      };

      github-runner-mirror-refresh = {
        description = "Refresh bare mirrors of the mirrored repositories";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        unitConfig.RequiresMountsFor = [ hotRoot ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${mirrorRefresh}/bin/github-runner-mirror-refresh";
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

    timers = {
      github-runner-editor-cache = {
        description = "Seed or resume the Unity Editor download";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "15min";
          OnUnitActiveSec = "30min";
          RandomizedDelaySec = "2min";
          Persistent = true;
        };
      };

      github-runner-mirror-refresh = {
        description = "Periodic refresh of the repository mirrors";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "10min";
          OnUnitActiveSec = "30min";
          RandomizedDelaySec = "2min";
          Persistent = true;
        };
      };

      github-runner-token-refresh = {
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
  };
}
