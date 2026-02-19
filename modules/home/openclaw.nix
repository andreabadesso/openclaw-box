{ cfg, nix-openclaw, pkgs, lib, ... }:

let
  openclawCfg = cfg.openclaw;

  # Build env var loading script from sops secret paths
  envExports = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: path: ''export ${name}="$(cat ${path})"'') openclawCfg.env
  );

  gatewayWrapper = pkgs.writeShellScript "openclaw-gateway-start" ''
    ${envExports}
    exec ${pkgs.openclaw-gateway}/bin/openclaw gateway
  '';

  # Derive provider name from model string (e.g. "kimi-coding/k2p5" -> "kimi-coding")
  provider = builtins.head (lib.splitString "/" openclawCfg.agents.model);
in
{
  config = {
    home-manager.users.root = {
      imports = [ nix-openclaw.homeManagerModules.openclaw ];
      programs.openclaw = {
        enable = openclawCfg.enable;
        instances.default = {
          enable = openclawCfg.enable;
          config = {
            gateway.mode = "local";
            auth.profiles.default = {
              inherit provider;
              mode = "api_key";
            };
            auth.order."*" = [ "default" ];
            agents.defaults = {
              model = {
                primary = openclawCfg.agents.model;
              };
              thinkingDefault = openclawCfg.agents.thinkingDefault;
            };
            channels.telegram = {
              tokenFile = openclawCfg.telegram.tokenFile;
              allowFrom = openclawCfg.telegram.allowFrom;
            };
          };
        };
      };
      home.stateVersion = cfg.stateVersion;
    };

    systemd.services.openclaw-gateway = lib.mkIf openclawCfg.enable {
      description = "OpenClaw Gateway";
      after = [ "network-online.target" "home-manager-root.service" ];
      wants = [ "network-online.target" ];
      requires = [ "home-manager-root.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        ExecStart = gatewayWrapper;
        Restart = "on-failure";
        RestartSec = 5;
        Environment = [
          "HOME=/root"
          "NODE_ENV=production"
        ];
      };
    };
  };
}
