{ cfg, nix-clawdbot, ... }:

let
  clawdCfg = cfg.clawdbot;
in
{
  config = {
    home-manager.users.root = {
      imports = [ nix-clawdbot.homeManagerModules.clawdbot ];
      programs.clawdbot = {
        enable = clawdCfg.enable;
        instances.default = {
          enable = clawdCfg.enable;
          agent = {
            model = clawdCfg.agent.model;
            thinkingDefault = clawdCfg.agent.thinkingDefault;
          };
          providers.telegram = {
            enable = clawdCfg.telegram.enable;
            botTokenFile = clawdCfg.telegram.botTokenFile;
            allowFrom = clawdCfg.telegram.allowFrom;
          };
          providers.anthropic.apiKeyFile = clawdCfg.anthropic.apiKeyFile;
        };
      };
      home.stateVersion = cfg.stateVersion;
    };
  };
}
