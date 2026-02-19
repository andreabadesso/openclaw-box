{ cfg, pkgs, lib, ... }:

let
  tmuxConfig = import ./tmux-config.nix { inherit pkgs; };

  mkUserHome = user: {
    name = user.name;
    value = { pkgs, ... }: {
      home.stateVersion = cfg.stateVersion;

      programs.zsh.enable = false;
      programs.bash.enable = false;

      programs.git = lib.mkIf (user.git.email != "") {
        enable = true;
        userEmail = user.git.email;
        userName = user.git.name;
        signing = {
          key = "";
          signByDefault = user.git.signByDefault;
        };
        delta.enable = user.devTools.gitDelta;
      };

      programs.mcfly = lib.mkIf user.devTools.mcfly {
        enable = true;
        fuzzySearchFactor = 3;
        enableZshIntegration = true;
      };

      programs.direnv = lib.mkIf user.devTools.direnv {
        enable = true;
        nix-direnv.enable = true;
      };

      programs.fzf = lib.mkIf user.devTools.fzf {
        enable = true;
        tmux.enableShellIntegration = true;
      };

      programs.htop = lib.mkIf user.devTools.htop {
        enable = true;
      };

      programs.tmux = lib.mkIf user.devTools.tmux tmuxConfig;

      home.packages = with pkgs; [
        xclip
        wl-clipboard
      ];
    };
  };

  enabledUsers = builtins.filter (u: u.devTools.enable) cfg.users;
in
{
  config = {
    home-manager.users = builtins.listToAttrs (map mkUserHome enabledUsers);
  };
}
