{
  description = "NixOS server with OpenClaw - deployed via nixos-anywhere";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-clawdbot = {
      url = "github:clawdbot/nix-clawdbot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, home-manager, sops-nix, nix-clawdbot, ... }@inputs: {
    nixosConfigurations.openclaw-box = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        ./hosts/nixos/disko-config.nix
        ./hosts/nixos/configuration.nix
        ./hosts/nixos/hardware-configuration.nix
        home-manager.nixosModules.home-manager
        {
          nixpkgs.overlays = [ nix-clawdbot.overlays.default ];
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.root = {
            imports = [ nix-clawdbot.homeManagerModules.clawdbot ];
            programs.clawdbot = {
              enable = true;
              instances.default = {
                enable = true;
                agent = {
                  model = "anthropic/claude-sonnet-4-20250514";
                  thinkingDefault = "medium";
                };
                providers.telegram = {
                  enable = true;
                  botTokenFile = "/run/secrets/telegram_bot_token";
                  allowFrom = [ 35767074 ];
                };
                providers.anthropic.apiKeyFile = "/run/secrets/anthropic_api_key";
              };
            };
            home.stateVersion = "25.11";
          };
          home-manager.users.openclaw = { pkgs, ... }: {
            home.stateVersion = "25.11";

            programs.zsh.enable = false;

            programs.mcfly = {
              enable = true;
              fuzzySearchFactor = 3;
              enableZshIntegration = true;
            };

            programs.bash.enable = false;

            programs.git = {
              enable = true;
              userEmail = "andre.abadesso@gmail.com";
              userName = "André Abadesso";
              signing = {
                key = "";
                signByDefault = false;
              };
              delta.enable = true;
            };

            programs.direnv = {
              enable = true;
              nix-direnv.enable = true;
            };

            programs.fzf = {
              enable = true;
              tmux.enableShellIntegration = true;
            };

            programs.htop.enable = true;

            programs.tmux = {
              enable = true;
              baseIndex = 1;
              clock24 = true;
              shortcut = "a";
              keyMode = "vi";
              terminal = "screen-256color";
              shell = "${pkgs.zsh}/bin/zsh";
              extraConfig = ''
                set -g default-command "${pkgs.zsh}/bin/zsh"
                set -g focus-events off
                set -sg focus-events off
                set -g default-terminal "tmux-256color"
                set -ag terminal-overrides ",xterm-256color:RGB"
                set -g status-position bottom
                set -g status-justify left
                set -g status-style 'bg=#0d1117,fg=#6e7681'
                set -g status-interval 2
                set -g status-left-length 100
                set -g status-right-length 100
                set -g status-left '#[bg=#161b22,fg=#58a6ff,bold]  #H |  #S #[bg=#0d1117,fg=#161b22]#[default]  '
                set -g window-status-format '#[fg=#6e7681] #I #W '
                set -g window-status-current-format '#[fg=#58a6ff,bold] #I #[fg=#c9d1d9]#W '
                set -g window-status-separator '#[fg=#ff7f50]-#[default]'
                set -g status-right '#[fg=#2d333b]#[bg=#2d333b,fg=#7ee787]  #{?client_prefix,#[fg=#d29922]󰌌 ,}#[fg=#6e7681]%H:%M #[fg=#161b22]#[bg=#161b22,fg=#bc8cff]  %d %b #[default]'
                set -g pane-border-style 'fg=#2d333b'
                set -g pane-active-border-style 'fg=#58a6ff'
                set -g message-style 'bg=#161b22,fg=#79c0ff,bold'
                set -g message-command-style 'bg=#161b22,fg=#d29922'
                set -g mode-style 'bg=#2d333b,fg=#c9d1d9'
                set -g clock-mode-colour '#58a6ff'
                set -g clock-mode-style 24

                is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
                    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
                bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
                bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
                bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
                bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'

                bind-key -T copy-mode-vi 'C-h' select-pane -L
                bind-key -T copy-mode-vi 'C-j' select-pane -D
                bind-key -T copy-mode-vi 'C-k' select-pane -U
                bind-key -T copy-mode-vi 'C-l' select-pane -R

                bind h select-pane -L
                bind j select-pane -D
                bind k select-pane -U
                bind l select-pane -R

                bind-key -r -T prefix K resize-pane -U 5
                bind-key -r -T prefix J resize-pane -D 5
                bind-key -r -T prefix H resize-pane -L 5
                bind-key -r -T prefix L resize-pane -R 5
                bind-key -r -T prefix z resize-pane -Z

                bind | split-window -h -c "#{pane_current_path}"
                bind - split-window -v -c "#{pane_current_path}"
                bind c new-window -c "#{pane_current_path}"
                bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"
              '';
              plugins = with pkgs; [
                tmuxPlugins.sensible
                tmuxPlugins.resurrect
                tmuxPlugins.continuum
                tmuxPlugins.yank
              ];
            };

            home.packages = with pkgs; [
              xclip
              wl-clipboard
            ];
          };
        }
      ];
    };
  };
}
