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
      moduleList = import ./lib/module-list.nix {
        inherit self disko sops-nix home-manager nix-openclaw;
      };

      # Scan boxes/ for directories containing box.toml
      boxEntries = builtins.readDir ./boxes;
      boxDirs = lib.filterAttrs (name: type: type == "directory") boxEntries;

      mkSystem = boxName:
        let
          cfg = loadConfig ./boxes/${boxName}/box.toml;
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
            modules = moduleList;
          };
        };

      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      mkBootstrapApp = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          bootstrapScript = pkgs.writeShellScript "openclaw-box" ''
            if [ "''${1:-}" = "bootstrap" ]; then
              exec ${pkgs.bash}/bin/bash ${./bootstrap.sh}
            else
              echo "Usage: nix run github:andreabadesso/openclaw-box -- bootstrap"
              echo ""
              echo "Commands:"
              echo "  bootstrap  Scaffold a new openclaw-box directory"
              exit 1
            fi
          '';
        in
        {
          type = "app";
          program = toString bootstrapScript;
        };
    in
    {
      lib.mkBox = import ./lib/mk-box.nix { inherit self inputs; };

      nixosConfigurations = builtins.listToAttrs (
        map mkSystem (builtins.attrNames boxDirs)
      );

      apps = lib.genAttrs allSystems (system: {
        default = mkBootstrapApp system;
      });
    };
}
