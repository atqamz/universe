{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  corpus = osConfig.universe.capabilities.knowledgeCorpus;
  system = pkgs.stdenv.hostPlatform.system;
  upstreamQmd = inputs.qmd.packages.${system}.default;
  qmd = upstreamQmd.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./qmd-mcp-require-explicit-collections.patch ];
    postFixup = (old.postFixup or "") + ''
      sed -i '2i export QMD_LLAMA_GPU=false' "$out/bin/qmd"
    '';
  });
  bin = "${config.home.profileDirectory}/bin/qmd";
  github = "${config.home.homeDirectory}/github";

  requiredCollections = {
    atqamz-universe = {
      path = "${config.home.homeDirectory}/universe";
      subdir = "docs";
      context = "NixOS workstation fleet: host composition, state ownership, ADRs, install and recovery runbooks.";
    };
  };

  optionalCollections = {
    atqamz-secondhand = {
      path = "${github}/atqamz/secondhand";
      subdir = "docs";
      context = "Secondhand marketplace application: architecture, data model, and operational notes.";
    };
    atqamz-rucika = {
      path = "${github}/atqamz/rucika";
      subdir = "docs";
      context = "Rucika project design notes and implementation decisions.";
    };
    atqamz-omanixy = {
      path = "${github}/atqamz/omanixy";
      subdir = "docs";
      context = "Omanixy project design notes and implementation decisions.";
    };
    yes2games-infra = {
      path = "${github}/yes2games/yes2infra";
      subdir = "docs";
      context = "yes2games infrastructure: environments, deployment pipelines, and platform runbooks.";
    };
    yes2games-sdk-mcp = {
      path = "${github}/yes2games/yes2sdk-mcp";
      subdir = "docs";
      context = "yes2games SDK MCP server: tool surface, protocol contracts, and integration guides.";
    };
    yes2games-dashboard = {
      path = "${github}/yes2games/yes2dashboard";
      subdir = "docs";
      context = "yes2games dashboard: product documentation and architecture.";
    };
    yes2games-dashboard-specs = {
      path = "${github}/yes2games/yes2dashboard";
      subdir = "internal/specs";
      context = "yes2games dashboard internal specifications and feature contracts.";
    };
    yes2games-rujak = {
      path = "${github}/yes2games/rujak";
      subdir = "docs";
      context = "Rujak service documentation and design decisions.";
    };
    yes2games-butler = {
      path = "${github}/yes2games/butler";
      subdir = "docs";
      context = "Butler GitHub App: authentication model, workflows, and automation contracts.";
    };
    hage-hageinfra = {
      path = "${github}/hagelabs/hageinfra";
      subdir = "docs";
      context = "hage infrastructure documentation and operational runbooks.";
    };
    hage-hagegames = {
      path = "${github}/hagelabs/hagegames";
      subdir = "docs";
      context = "hage games project documentation and design notes.";
    };
  };

  collections = requiredCollections // optionalCollections;
  paths = lib.mapAttrs (_: entry: "${entry.path}/${entry.subdir}") collections;
  requiredPaths = [ "universe/docs" ];
  requiredSource = "${config.home.homeDirectory}/${builtins.head requiredPaths}";

  index = {
    global_context = "Durable project documentation only, one collection per repository documentation root, named <profile>-<repo>. Source code is not indexed here: navigate code with codedb instead.";
    collections = lib.mapAttrs (name: entry: {
      path = paths.${name};
      pattern = "**/*.md";
      context = {
        "/" = entry.context;
      };
    }) collections;
    models = {
      embed = "hf:ggml-org/embeddinggemma-300M-GGUF/embeddinggemma-300M-Q8_0.gguf";
      generate = "hf:tobil/qmd-query-expansion-1.7B-gguf/qmd-query-expansion-1.7B-q4_k_m.gguf";
      rerank = "hf:ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/qwen3-reranker-0.6b-q8_0.gguf";
    };
  };

  refresh = pkgs.writeShellApplication {
    name = "qmd-refresh";
    runtimeInputs = [
      qmd
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      config_dir="$(mktemp -d)"
      trap 'rm -rf "$config_dir"' EXIT
      if [ ! -d ${lib.escapeShellArg requiredSource} ]; then
        echo "qmd-refresh: required collection atqamz-universe source is absent" >&2
        exit 1
      fi
      cp ${lib.escapeShellArg "${config.xdg.configHome}/qmd/index.yml"} "$config_dir/index.yml"
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: entry: ''
          if [ ! -d ${lib.escapeShellArg "${entry.path}/${entry.subdir}"} ]; then
            echo "qmd-refresh: skipping optional collection ${name}: ${entry.path}/${entry.subdir} is absent" >&2
            jq --arg name ${lib.escapeShellArg name} 'del(.collections[$name])' "$config_dir/index.yml" >"$config_dir/index.yml.tmp"
            mv "$config_dir/index.yml.tmp" "$config_dir/index.yml"
          fi
        '') optionalCollections
      )}
      QMD_CONFIG_DIR="$config_dir" qmd update
      QMD_CONFIG_DIR="$config_dir" qmd embed
      qmd status >/dev/null
    '';
  };
in
{
  universe = {
    aiHarness.mcpServers.qmd = {
      command = bin;
      args = [ "mcp" ];
      env = { };
    };

    doctor = {
      commands = [ "qmd" ];
      paths = lib.mkIf corpus requiredPaths;
      qmdCollections = lib.mkIf corpus paths;
      qmdRequiredCollections = lib.mkIf corpus (lib.attrNames requiredCollections);
    };
  };

  home.packages = [ qmd ] ++ lib.optional corpus refresh;

  xdg.configFile."qmd/index.yml" = lib.mkIf corpus {
    source = (pkgs.formats.yaml { }).generate "qmd-index.yml" index;
  };

  services.userTimers = lib.mkIf corpus {
    qmd-refresh = {
      description = "Re-index and embed qmd documentation collections";
      timerDescription = "Daily qmd documentation index refresh";
      command = "${refresh}/bin/qmd-refresh";
      timer = {
        OnStartupSec = "20min";
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };
}
