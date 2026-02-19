{
  hostname = "openclaw";
  timezone = "UTC";
  locale = "en_US.UTF-8";
  system = "x86_64-linux";
  stateVersion = "25.11";

  boot = {
    mode = "bios"; # "bios" or "efi"
  };

  disk = {
    device = "/dev/sda";
  };

  swap = {
    size = 4096;
  };

  networking = {
    ports = [ 22 80 443 ];
    portRanges = [];
  };

  docker = {
    enable = true;
  };

  tailscale = {
    enable = false;
    authKeyFile = "";
  };

  sops = {
    defaultSopsFile = "";
    ageKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = [];
  };

  packages = [];

  root = {
    sshKeys = [];
  };

  users = [];

  openclaw = {
    enable = false;
    agents = {
      model = "kimi-coding/k2p5";
      thinkingDefault = "medium";
    };
    telegram = {
      tokenFile = "";
      allowFrom = [];
    };
    env = {};
  };
}
