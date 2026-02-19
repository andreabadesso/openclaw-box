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
    nix-openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, home-manager, sops-nix, nix-openclaw, ... }@inputs:
    let
      lib = nixpkgs.lib;
      loadConfig = import ./lib/load-config.nix { inherit lib; };

      # Scan boxes/*.toml and generate a nixosConfiguration for each
      boxFiles = builtins.readDir ./boxes;
      tomlFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".toml" name) boxFiles;

      mkSystem = filename:
        let
          boxName = lib.removeSuffix ".toml" filename;
          cfg = loadConfig ./boxes/${filename};
        in
        {
          name = boxName;
          value = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit self inputs cfg nix-openclaw; };
            modules = [
              disko.nixosModules.disko
              sops-nix.nixosModules.sops
              home-manager.nixosModules.home-manager
              ./modules/disko.nix
              ./modules/hardware.nix
              ./modules/system.nix
              ./modules/users.nix
              ./modules/home/dev-tools.nix
              ./modules/home/openclaw.nix
              {
                nixpkgs.overlays = [ nix-openclaw.overlays.default ];
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
              }
            ];
          };
        };
    in
    {
      nixosConfigurations = builtins.listToAttrs (
        map mkSystem (builtins.attrNames tomlFiles)
      );
    };
}
