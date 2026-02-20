{ self, disko, sops-nix, home-manager, nix-openclaw }:

[
  disko.nixosModules.disko
  sops-nix.nixosModules.sops
  home-manager.nixosModules.home-manager
  "${self}/modules/disko.nix"
  "${self}/modules/hardware.nix"
  "${self}/modules/system.nix"
  "${self}/modules/users.nix"
  "${self}/modules/containers.nix"
  "${self}/modules/home/dev-tools.nix"
  "${self}/modules/home/openclaw.nix"
  {
    nixpkgs.overlays = [ nix-openclaw.overlays.default ];
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "bak";
  }
]
