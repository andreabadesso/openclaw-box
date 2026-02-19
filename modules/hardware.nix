{ cfg, lib, modulesPath, ... }:

let
  isEfi = cfg.boot.mode == "efi";
in
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" "nvme" ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  boot.loader = if isEfi then {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  } else {
    grub = {
      enable = true;
      devices = lib.mkForce [ cfg.disk.device ];
      efiSupport = false;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
