{
  inputs,
  self,
  lib,
  ...
}:
{
  perSystem =
    { config, pkgs, ... }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      sfx14 = self.nixosConfigurations.sfx14;
      gpuService = sfx14.config.systemd.services.gpu-undervolt;
      gpuExec = gpuService.serviceConfig.ExecStart;
      resumeExec = sfx14.config.systemd.services.sleep-actions.serviceConfig.ExecStop;
      gpuUnit =
        pkgs.writeText "sfx14-gpu-undervolt.service"
          sfx14.config.systemd.units."gpu-undervolt.service".text;
      targetModule = "${sfx14.config.hardware.nvidia.package.open}/lib/modules/${sfx14.config.boot.kernelPackages.kernel.modDirVersion}/kernel/drivers/video/nvidia.ko.xz";
      targetSmi = "${sfx14.config.hardware.nvidia.package.bin}/bin/nvidia-smi";
      claude =
        (import inputs.nixpkgs {
          system = pkgs.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        }).claude-code;
      opencodeProviderContract = import ../lib/opencode-provider-contract.nix;
      opencodeProviderHealthy = pkgs.writeText "opencode-provider-healthy.json" (
        builtins.toJSON {
          provider.fixture-provider = {
            npm = "@ai-sdk/openai-compatible";
            options.baseURL = "https://fixture.invalid/v1";
            models.A = { };
          };
        }
      );
      opencodeProviderMissing = pkgs.writeText "opencode-provider-missing.json" (
        builtins.toJSON { provider = { }; }
      );
      opencodeProviderWrongNpm = pkgs.writeText "opencode-provider-wrong-npm.json" (
        builtins.toJSON {
          provider.fixture-provider = {
            npm = "other-sdk";
            options.baseURL = "https://fixture.invalid/v1";
            models.A = { };
          };
        }
      );
      opencodeProviderWrongUrl = pkgs.writeText "opencode-provider-wrong-url.json" (
        builtins.toJSON {
          provider.fixture-provider = {
            npm = "@ai-sdk/openai-compatible";
            options.baseURL = "https://other.example/v1";
            models.A = { };
          };
        }
      );
      opencodeProviderEmptyModels = pkgs.writeText "opencode-provider-empty-models.json" (
        builtins.toJSON {
          provider.fixture-provider = {
            npm = "@ai-sdk/openai-compatible";
            options.baseURL = "https://fixture.invalid/v1";
            models = { };
          };
        }
      );
      opencodeProviderNonObjectModels = pkgs.writeText "opencode-provider-nonobject-models.json" (
        builtins.toJSON {
          provider.fixture-provider = {
            npm = "@ai-sdk/openai-compatible";
            options.baseURL = "https://fixture.invalid/v1";
            models = [ "A" ];
          };
        }
      );
      opencodeProviderMalformed = pkgs.writeText "opencode-provider-malformed.json" "{";
      opencodeDoctorManifest =
        pkgs.writeText "opencode-doctor-manifest.json"
          self.nixosConfigurations.sfx14.config.home-manager.users.atqa.xdg.configFile."universe/doctor.json".text;
      opencodeDoctorHealthy = pkgs.writeShellScriptBin "opencode-doctor-healthy" ''
        printf '%s\n' '{"provider":{"mocin":{"npm":"@ai-sdk/openai-compatible","options":{"baseURL":"https://beta.masven.dev/v1"},"models":{"A":{}}}}}'
      '';
      opencodeDoctorMissing = pkgs.writeShellScriptBin "opencode-doctor-missing" ''
        printf '%s\n' '{"provider":{}}'
      '';
    in
    {
      pre-commit.settings = {
        hooks = {
          actionlint.enable = true;
          deadnix.enable = true;
          shellcheck.enable = true;
          statix.enable = true;
          treefmt = {
            enable = true;
            excludes = [
              "configs/dotagents/claude/fetch-usage.sh"
              "configs/dotagents/claude/statusline-command.sh"
            ];
            packageOverrides.treefmt = config.treefmt.build.wrapper;
          };
        };
      };

      checks =
        assert lib.elem "gpu-undervolt" sfx14.config.universe.doctor.activeSystemServices;
        lib.mapAttrs' (
          name: host: lib.nameValuePair "toplevel-${name}" host.config.system.build.toplevel
        ) self.nixosConfigurations
        // {
          sfx14-gpu-lifecycle =
            pkgs.runCommand "sfx14-gpu-lifecycle"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  gnugrep
                  systemd
                ];
              }
              ''
                ${pkgs.bash}/bin/bash ${../tests/sfx14-gpu-lifecycle.bash} \
                  ${lib.escapeShellArg gpuExec} \
                  ${lib.escapeShellArg resumeExec} \
                  ${lib.escapeShellArg gpuUnit} \
                  ${lib.escapeShellArg targetModule} \
                  ${lib.escapeShellArg targetSmi} \
                  ${lib.escapeShellArg sfx14.config.hardware.nvidia.package.version}
                touch "$out"
              '';
          no-mistakes-reconcile =
            pkgs.runCommand "no-mistakes-reconcile-test"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  gawk
                  gnugrep
                  gnused
                  jq
                ];
              }
              ''
                bash ${../tests/no-mistakes-reconcile.bash} ${../modules/home/no-mistakes-reconcile.sh}
                touch $out
              '';
          migration-doctor =
            pkgs.runCommand "migration-doctor-test"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  git
                  gnugrep
                ];
              }
              ''
                bash ${../tests/migration-doctor.bash} \
                  ${lib.escapeShellArg self.apps.${system}.doctor.program}
                touch $out
              '';
          migration-config-contract =
            let
              manifestText = sfx14.config.home-manager.users.atqa.xdg.configFile."universe/doctor.json".text;
              manifest = pkgs.writeText "universe-doctor-manifest.json" manifestText;
            in
            pkgs.runCommand "migration-config-contract"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  jq
                ];
              }
              ''
                expect_link() {
                  jq -e --arg path "$1" --arg target "$2" '.symlinks[$path] == $target' ${manifest} >/dev/null
                }

                jq -e '.paths | index("universe/configs/dotfiles")' ${manifest} >/dev/null
                jq -e '.paths | index("universe/configs/dotagents")' ${manifest} >/dev/null
                expect_link .config/foot/foot.ini universe/configs/dotfiles/foot/foot.ini
                expect_link .config/hypr universe/configs/dotfiles/hypr
                expect_link .claude/CLAUDE.md universe/configs/dotagents/CLAUDE.md
                expect_link .config/opencode/AGENTS.md universe/configs/dotagents/AGENTS.md
                expect_link .codex/AGENTS.md universe/configs/dotagents/AGENTS.md
                expect_link .config/opencode/dynamic-models universe/configs/dotagents/opencode/dynamic-models
                expect_link .claude/settings.json universe/configs/dotagents/claude/settings.json
                expect_link .config/opencode/opencode.json universe/configs/dotagents/opencode/opencode.json
                expect_link .no-mistakes/config.yaml universe/configs/dotagents/no-mistakes/config.yaml
                touch $out
              '';
          claude-skill-root-contract =
            pkgs.runCommand "claude-skill-root-contract"
              {
                nativeBuildInputs = with pkgs; [
                  claude
                  coreutils
                  gnugrep
                ];
              }
              ''
                help=$(claude plugin init --help)
                grep -Fq 'Scaffold a new plugin at ~/.claude/skills/<name>/' <<<"$help"
                grep -Fq 'auto-loads next session' <<<"$help"
                touch "$out"
              '';
          opencode-provider-contract =
            pkgs.runCommand "opencode-provider-contract"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  jq
                ];
              }
              ''
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME/.config/universe"
                cp ${opencodeDoctorManifest} "$HOME/.config/universe/doctor.json"

                expect_success() {
                  if ! "$@" >/dev/null; then
                    echo "expected command to succeed: $*" >&2
                    exit 1
                  fi
                }

                expect_failure() {
                  if "$@" >/dev/null 2>&1; then
                    echo "expected command to fail: $*" >&2
                    exit 1
                  fi
                }

                provider_args=(--arg p fixture-provider --arg n '@ai-sdk/openai-compatible' --arg u 'https://fixture.invalid/v1')
                expect_success jq -e "''${provider_args[@]}" '${opencodeProviderContract.provider}' ${opencodeProviderHealthy}
                expect_success jq -e --arg p fixture-provider '${opencodeProviderContract.models}' ${opencodeProviderHealthy}
                expect_failure jq -e "''${provider_args[@]}" '${opencodeProviderContract.provider}' ${opencodeProviderMissing}
                expect_failure jq -e "''${provider_args[@]}" '${opencodeProviderContract.provider}' ${opencodeProviderWrongNpm}
                expect_failure jq -e "''${provider_args[@]}" '${opencodeProviderContract.provider}' ${opencodeProviderWrongUrl}
                expect_failure jq -e --arg p fixture-provider '${opencodeProviderContract.models}' ${opencodeProviderEmptyModels}
                expect_failure jq -e --arg p fixture-provider '${opencodeProviderContract.models}' ${opencodeProviderNonObjectModels}
                expect_failure jq -e . ${opencodeProviderMalformed}

                expect_success env \
                  UNIVERSE_DOCTOR_OPENCODE=${opencodeDoctorHealthy}/bin/opencode-doctor-healthy \
                  UNIVERSE_DOCTOR_PROVIDER_ONLY=1 \
                  ${self.apps.${system}.doctor.program}
                expect_failure env \
                  UNIVERSE_DOCTOR_OPENCODE=${opencodeDoctorMissing}/bin/opencode-doctor-missing \
                  UNIVERSE_DOCTOR_PROVIDER_ONLY=1 \
                  ${self.apps.${system}.doctor.program}
                touch "$out"
              '';
        };
    };
}
