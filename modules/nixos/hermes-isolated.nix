{ pkgs, ... }:
{
  users.groups.hermes = { };

  users.users.hermes = {
    isSystemUser = true;
    group = "hermes";
    home = "/var/lib/hermes-isolated";
    createHome = true;
  };

  systemd.services.hermes-9router = {
    description = "Hermes isolated 9Router";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      User = "hermes";
      Group = "hermes";
      WorkingDirectory = "/var/lib/hermes-isolated/state/9router";
      StateDirectory = [
        "hermes-isolated"
        "hermes-isolated/state/9router"
      ];
      Environment = [
        "HOME=/var/lib/hermes-isolated/state/9router/home"
        "npm_config_cache=/var/lib/hermes-isolated/state/9router/npm-cache"
        "PATH=${pkgs.bash}/bin:${pkgs.nodejs_24}/bin:/run/current-system/sw/bin"
      ];
      ExecStart = "${pkgs.nodejs_24}/bin/npx --yes 9router@0.5.15 --host 127.0.0.1 --port 20128 --no-browser --log --skip-update";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  systemd.services.hermes = {
    description = "Hermes isolated WhatsApp assistant";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "hermes-9router.service"
    ];
    wants = [
      "network-online.target"
      "hermes-9router.service"
    ];
    serviceConfig = {
      User = "hermes";
      Group = "hermes";
      WorkingDirectory = "/var/lib/hermes-isolated/runtime";
      StateDirectory = [
        "hermes-isolated"
        "hermes-isolated/state/hermes"
      ];
      Environment = [
        "PATH=/var/lib/hermes-isolated/state/hermes:/run/current-system/sw/bin"
        "HERMES_STATE_DIR=/var/lib/hermes-isolated/state/hermes"
        "HERMES_ATQA_WHATSAPP_ID=181011614855423@lid"
        "HERMES_ONYIS_WHATSAPP_ID=68693790855191@lid"
        "HERMES_LLM_BASE_URL=http://127.0.0.1:20128/v1"
        "HERMES_LLM_MODEL=ollama/glm-5"
        "PUPPETEER_EXECUTABLE_PATH=${pkgs.chromium}/bin/chromium"
      ];
      ExecStart = "${pkgs.nodejs_24}/bin/node dist/main.js run";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
