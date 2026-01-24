{
  description = "NixOS server with Clawdbot - deployed via nixos-anywhere";

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
    nixosConfigurations.clawd-box = nixpkgs.lib.nixosSystem {
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
              # Configure your Clawdbot instance
              instances.default = {
                enable = true;
                agent = {
                  model = "anthropic/claude-sonnet-4-20250514";
                  thinkingDefault = "medium";
                };
                # Uncomment and configure providers:
                # providers.telegram = {
                #   enable = true;
                #   botTokenFile = "/run/secrets/telegram_bot_token";
                #   allowFrom = [ 123456789 ]; # Your Telegram user ID
                # };
                # providers.anthropic.apiKeyFile = "/run/secrets/anthropic_api_key";
              };
            };
            home.stateVersion = "25.11";
          };
        }
      ];
    };
  };
}
