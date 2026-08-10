{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  corpus = osConfig.universe.capabilities.knowledgeCorpus;
  bin = "${config.home.profileDirectory}/bin/qmd";
  github = "${config.home.homeDirectory}/github";

  collections = {
    atqamz-universe = {
      path = "${config.home.homeDirectory}/universe";
      subdir = "docs";
      context = "NixOS workstation fleet: host composition, state ownership, ADRs, install and recovery runbooks.";
    };
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

  paths = lib.mapAttrs (_: entry: "${entry.path}/${entry.subdir}") collections;

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
      pkgs.qmd
      pkgs.coreutils
    ];
    text = ''
      missing=0
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: path: ''
          if [ ! -d ${lib.escapeShellArg path} ]; then
            echo "qmd-refresh: collection ${name} source missing: ${path}" >&2
            missing=$((missing + 1))
          fi
        '') paths
      )}
      if [ "$missing" -gt 0 ]; then
        echo "qmd-refresh: $missing configured collections have no source directory" >&2
        exit 1
      fi

      qmd update
      qmd embed
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
      qmdCollections = lib.mkIf corpus paths;
    };
  };

  home.packages = lib.mkIf corpus [ refresh ];

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
