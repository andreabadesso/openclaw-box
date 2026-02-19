{ cfg, nix-openclaw, ... }:

let
  openclawCfg = cfg.openclaw;
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
            env.vars = openclawCfg.env;
          };
        };
      };
      home.stateVersion = cfg.stateVersion;
    };
  };
}
