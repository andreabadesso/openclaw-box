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

      # Scan boxes/ for directories containing box.toml
      boxEntries = builtins.readDir ./boxes;
      boxDirs = lib.filterAttrs (name: type: type == "directory") boxEntries;

      mkSystem = boxName:
        let
          cfg = loadConfig ./boxes/${boxName}/box.toml;
          # Auto-derive sops path when not explicitly set
          sopsFile =
            if cfg.sops.defaultSopsFile != ""
            then cfg.sops.defaultSopsFile
            else "boxes/${boxName}/secrets/secrets.yaml";
          finalCfg = cfg // {
            sops = cfg.sops // { defaultSopsFile = sopsFile; };
          };
        in
        {
          name = boxName;
          value = nixpkgs.lib.nixosSystem {
            system = finalCfg.system;
            specialArgs = { inherit self inputs nix-openclaw; cfg = finalCfg; };
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
                home-manager.backupFileExtension = "bak";
              }
            ];
          };
        };
    in
    {
      nixosConfigurations = builtins.listToAttrs (
        map mkSystem (builtins.attrNames boxDirs)
      );
    };
}
