{ cfg, ... }:

let
  isEfi = cfg.boot.mode == "efi";
in
{
  disko.devices = {
    disk = {
      main = {
        device = cfg.disk.device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = if isEfi then {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            } else {
              size = "1M";
              type = "EF02";
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
