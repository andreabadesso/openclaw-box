{ self, inputs }:

let
  inherit (inputs) nixpkgs disko sops-nix home-manager nix-openclaw;
  lib = nixpkgs.lib;
  loadConfig = import ./load-config.nix { inherit lib; };
  moduleList = import ./module-list.nix {
    inherit self disko sops-nix home-manager nix-openclaw;
  };

  allSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

in
boxSelf: boxDir:
  let
    cfg = loadConfig (boxDir + "/box.toml");
    sopsFile =
      if cfg.sops.defaultSopsFile != ""
      then cfg.sops.defaultSopsFile
      else "secrets/secrets.yaml";
    finalCfg = cfg // {
      sops = cfg.sops // { defaultSopsFile = sopsFile; };
    };
    hostname = finalCfg.hostname;
    targetSystem = finalCfg.system;

    mkApp = program: {
      type = "app";
      program = toString program;
    };

    mkDeployScript = hostSystem:
      let
        pkgs = nixpkgs.legacyPackages.${hostSystem};
      in
      pkgs.writeShellScript "deploy-${hostname}" ''
        set -euo pipefail
        TARGET_IP=''${1:?Usage: deploy <target-ip> [ssh-user]}
        SSH_USER=''${2:-admin}
        echo "Deploying NixOS box '${hostname}' to $SSH_USER@$TARGET_IP..."
        nix run github:nix-community/nixos-anywhere -- \
          --build-on remote \
          --flake ".#${hostname}" \
          "$SSH_USER@$TARGET_IP"
      '';

    mkUpdateScript = hostSystem:
      let
        pkgs = nixpkgs.legacyPackages.${hostSystem};
      in
      pkgs.writeShellScript "update-${hostname}" ''
        set -euo pipefail
        TARGET_IP=''${1:?Usage: update <target-ip>}
        echo "Updating NixOS box '${hostname}' at $TARGET_IP..."
        NIX_SSHOPTS="-o StrictHostKeyChecking=no" \
          nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch \
          --flake ".#${hostname}" \
          --target-host "root@$TARGET_IP" \
          --sudo
      '';

  in
  {
    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      system = targetSystem;
      specialArgs = {
        self = boxSelf;
        inherit inputs nix-openclaw;
        cfg = finalCfg;
      };
      modules = moduleList;
    };

    apps = lib.genAttrs allSystems (hostSystem: {
      deploy = mkApp (mkDeployScript hostSystem);
      update = mkApp (mkUpdateScript hostSystem);
    });
  }
