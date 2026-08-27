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

  # Eight rootless users mean eight container stores, so pulling from the registry
  # costs eight downloads of the same image over one home WiFi link. The image is
  # fetched once into a local archive instead and loaded per runner from disk. The
  # local tag carries the digest, so a bump invalidates it without a manual edit.
  localImage = "localhost/github-runner:${imageTag}-${lib.substring 7 12 imageDigest}";
  imageCacheDir = "${hotRoot}/image-cache";
  imageArchive = "${imageCacheDir}/runner.tar";
  imageStamp = "${imageCacheDir}/digest";

  # The Unity Editor is a desktop binary even when every job runs it with
  # `-batchmode -nographics`: GTK, cairo, pango and X11 sit in its DT_NEEDED list, so
  # it does not load at all without them. A GitHub-hosted runner has them because its
  # image carries a desktop's worth of libraries; this one has to be told. They come
  # from Ubuntu rather than from nixpkgs because they are loaded into a process linked
  # against Ubuntu's glibc, where a library built against a newer one fails its symbol
  # lookups.
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
  # Tagged with the package list as well as the base digest, so editing the list is
  # enough to make every runner rebuild and reload rather than keep an image whose
  # name no longer describes it.
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

  # Rootless Podman resolves newuidmap through PATH, and the store copy carries no
  # setuid bit; only the wrapper does. systemd's `path` runs through makeBinPath,
  # which re-appends /bin, so it takes the parent of security.wrapperDir.
  wrapperPath = dirOf config.security.wrapperDir;

  # A warm runner keeps its container HOME and workdir between jobs, so
  # `actions/checkout` fetches into an existing clone and `git lfs` finds most of its
  # objects already there instead of re-cloning nsr and pulling 4.7 GB of LFS content
  # every run. The Editor is seeded on the host and shared read-only with every class,
  # so it costs a warm runner nothing. The carried state is cross-job, so warm runners
  # are only safe on repositories that take no fork pull requests; the light class
  # stays disposable for everything else.
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
  toolCacheFor = r: "${toolCacheRoot}/${r.name}";
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

  # One bare mirror per repository, refreshed once for all eight runners instead of
  # each runner fetching the same objects over the same home WiFi link. A job's
  # workdir is seeded from it with `git clone --shared`, so actions/checkout finds a
  # repository that already has the refs and borrows the objects, and fetches only
  # the commits that landed since the last refresh.
  mirrorRoot = "${hotRoot}/mirrors";
  mirroredRepos = [
    "nsr"
    "butler"
    "nsr-nakama"
    "nsr-webtransport"
    "rujak"
  ];
  startedHookInContainer = "/opt/runner-hooks/job-started.sh";

  # The Actions runner puts its tool cache at `<workdir>/_tool` unless
  # `AGENT_TOOLSDIRECTORY` says otherwise, and the light class wipes everything under
  # its workdir after every job - so every `setup-node`, `setup-go` and `setup-deno`
  # downloaded its toolchain again on every single run. Measured at 55 s per job for
  # `denoland/setup-deno` against near zero on a GitHub-hosted runner, which has the
  # toolchains in its image. Pointing the variable at a host directory takes the cache
  # out of the workdir, so it survives both the wipe and a container restart.
  #
  # One directory per runner rather than one shared by all eight. Sharing would save
  # five of the six first downloads and cost a race: `@actions/tool-cache` copies into
  # `<tool>/<version>` and only then writes the `.complete` marker beside it, so two
  # jobs installing the same missing version concurrently - which is exactly what a
  # matrix of five jobs does - can have one rewriting files the other has already
  # published. Per-runner, a version is fetched at most eight times ever instead of
  # once per job, and nothing can corrupt anyone else's copy.
  toolCacheRoot = "${hotRoot}/toolcache";
  toolCacheInContainer = "/opt/hostedtoolcache";

  # The runner image is the minimal `myoung34/github-runner`, not the GitHub-hosted
  # `ubuntu-latest` image with its several hundred preinstalled toolchains, so a
  # workflow that calls a tool by bare name finds nothing. The gap is filled from
  # the host's own store rather than by rebuilding the image: the tools stay
  # declarative, a new one is one line here, and nothing has to be fetched over
  # WiFi. /nix/store rides along read-only because every one of these binaries
  # resolves its interpreter and libraries back into it.
  ciTools = pkgs.buildEnv {
    name = "pavg15-ci-tools";
    paths = [
      pkgs.shellcheck
      # nsr compiles Unity's generated csproj without an Editor on the fast path.
      # Both SDKs, because the GitHub-hosted image carries both and nothing in the
      # repo pins which one the generated project asks for.
      (pkgs.dotnetCorePackages.combinePackages [
        pkgs.dotnetCorePackages.sdk_8_0
        pkgs.dotnetCorePackages.sdk_9_0
      ])
    ];
  };
  ciToolsInContainer = "/opt/ci-tools";

  # Unity's CLI is a driver, not an installer: `unity install` hands the work to the
  # Unity Hub, an Electron AppImage this container cannot run - no /dev/fuse to mount
  # it, no D-Bus, no display - so it gives up after a fixed 60 s having downloaded
  # nothing at all. It reads an Editor that is simply present on disk, though:
  # `unity editors --installed` scans the install path rather than any Hub state. So
  # the Editor is fetched straight from Unity's CDN here, once for the whole fleet,
  # and the Hub never enters the picture. Unpacking each module archive at the Editor
  # root is also what lands it where the Editor looks, which is the defect nsr's own
  # unity_cli_repair_modules.sh exists to undo after the beta installer nests it one
  # tree too deep.
  editorRoot = "${hotRoot}/editors";
  editorInContainer = "/root/Unity/Hub/Editor";
  unityEditors = [
    {
      version = "6000.3.16f1";
      changeset = "a56f230f6470";
      # The two nsr asks for: `webgl` for the client builds, `linux-server` for the
      # dedicated server image. Named as the CDN spells them, not as the Hub does.
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
      # Passed through the environment rather than the remote URL or the command
      # line: the URL would persist the credential into the mirror's config, and an
      # argument would show up in every ps listing on the box.
      GIT_CONFIG_VALUE_0="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$token" | base64 -w0)"
      token=""
      export GIT_CONFIG_COUNT=1
      export GIT_CONFIG_KEY_0=http.extraheader
      export GIT_CONFIG_VALUE_0

      install -d -m 0755 ${mirrorRoot}
      repos=(${lib.concatMapStringsSep " " lib.escapeShellArg mirroredRepos})
      # Each repository is refreshed in a subshell so one that has been renamed, made
      # private to another installation, or simply is unreachable this minute costs
      # only its own mirror. The others were the whole point of doing this once for
      # the fleet, and a job whose mirror is missing falls back to a plain clone.
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
            # A borrowing clone references objects this repository owns, so it must
            # never garbage-collect them out from under a running job.
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
      # Non-zero only if every mirror failed, which is a credential or network fault
      # rather than one repository's problem, and worth surfacing as a failed unit.
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
      # Anything already on disk belongs to actions/checkout, which knows how to
      # reuse or replace it. Seeding only ever fills an empty slot.
      [ -z "$(ls -A "$dir" 2>/dev/null)" ] || exit 0
      mkdir -p "$dir" || exit 0
      # The mirror is bind-mounted from a root-owned host directory, which maps to
      # `nobody` inside the rootless user namespace, so git rejects it as dubious
      # ownership. `safe.directory` is honoured only from global or system scope,
      # never from `-c` or the environment, hence the throwaway global config.
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

  # Both the runner registration token and the mirror fetch credential start from
  # the same App installation token, so the JWT signing lives in exactly one place.
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

  # systemd-tmpfiles cannot create these: on a live switch it runs in the same
  # transaction as the bulk mount, so anything it writes under bulkRoot is created
  # on the underlying directory and then shadowed the moment sda2 mounts over it.
  # This oneshot is ordered after the mount instead.
  runnerDirs = pkgs.writeShellApplication {
    name = "github-runner-dirs";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      install -d -m 0755 ${mirrorRoot} ${editorRoot} ${toolCacheRoot}
    ''
    + lib.concatMapStringsSep "\n" (
      r:
      ''
        install -d -o ${userFor r} -g ${userFor r} -m 0750 ${baseFor r} ${homeFor r} ${workFor r}
        install -d -o ${userFor r} -g ${userFor r} -m 0750 ${toolCacheFor r}
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

      # Downloaded to a file rather than piped into tar. This runs over a 2 MB/s home
      # WiFi link, where a 4 GB transfer that drops has to resume where it stopped; a
      # retry on a pipe restarts the archive from byte zero with tar mid-stream.
      fetch() {
        url=$1
        into=$2
        file=$3/''${url##*/}
        # A file already complete answers 416 to the resume request, which is success
        # as far as this is concerned. `xz -t` is what decides whether the bytes on
        # disk are a whole archive.
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

        # The whole point of the seed is that the CLI finds this exact path, so a
        # layout change upstream should fail here rather than an hour into a build.
        test -x "$staging/Editor/Unity"
        printf '%s' "$want" > "$staging/.seeded"
        chmod -R a+rX "$staging"
        rm -rf ${editorRoot}/"$version"
        mv "$staging" ${editorRoot}/"$version"
        # The archives exist only to survive an interrupted download.
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

  # Built once as root and handed to the eight rootless stores as an archive, for the
  # same reason the base image is: one apt transaction over this link, not eight.
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
          # The image comes from the on-disk archive the cache oneshot wrote, never
          # from the registry: `never` turns a missing local image into a fast
          # failure instead of a silent eight-fold download.
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
          # Prepended, not replaced: the suffix is the image's own PATH, and the
          # runner's entrypoint needs it intact.
          "-e PATH=${ciToolsInContainer}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          "-e DOTNET_ROOT=${ciToolsInContainer}"
          "-e DOTNET_CLI_TELEMETRY_OPTOUT=1"
          "-e DOTNET_NOLOGO=1"
          "-e AGENT_TOOLSDIRECTORY=${toolCacheInContainer}"
        ]
        ++ lib.optional (!r.warm) "-e ACTIONS_RUNNER_HOOK_JOB_COMPLETED=${hookInContainer}"
        ++ [
          "-e ACTIONS_RUNNER_HOOK_JOB_STARTED=${startedHookInContainer}"
        ]
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
          # Overlaid rather than read-only: one seeded tree is shared by every runner,
          # and `unity license activate` and the Editor itself both write inside it.
          # Writes land in a per-container upper layer that dies with the container,
          # so no runner can corrupt the copy the others read.
          "-v ${editorRoot}:${editorInContainer}:O"
        ]
        ++ [
          # Seeding writes a `.git/objects/info/alternates` holding an absolute path,
          # so the mirror has to answer to the same path inside the container too.
          "-v ${mirrorRoot}:${mirrorRoot}:ro"
          "-v ${toolCacheFor r}:${toolCacheInContainer}"
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
        # Started by its timer rather than multi-user.target, so a transfer that
        # drops halfway is retried and resumed instead of leaving the fleet without
        # an Editor until the next boot.
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
          # Around 13 GB over a home WiFi link on a cold host. Deliberately not a
          # dependency of the runner units: a runner that starts without an Editor
          # fails one Unity job with a clear error, where blocking startup would
          # hold the whole fleet - light runners included - for hours.
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
          # Same reasoning as the mirror: gigabytes over a link the runners also use,
          # so it waits for the boot to settle. The half-hour beat is what turns a
          # dropped transfer into a resumed one; the seed stamp makes every run after
          # the first a no-op.
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
          # The first fetch is a full clone of a repository measured in gigabytes, so
          # it waits for the boot to settle rather than racing the runners for the link.
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
