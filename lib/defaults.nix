{
  hostname = "openclaw";
  timezone = "UTC";
  locale = "en_US.UTF-8";
  stateVersion = "25.11";

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
    defaultSopsFile = "hosts/nixos/secrets/secrets.yaml";
    ageKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = [];
  };

  packages = [];

  root = {
    sshKeys = [];
  };

  users = [];

  clawdbot = {
    enable = false;
    agent = {
      model = "anthropic/claude-sonnet-4-20250514";
      thinkingDefault = "medium";
    };
    telegram = {
      enable = false;
      botTokenFile = "";
      allowFrom = [];
    };
    anthropic = {
      apiKeyFile = "";
    };
  };
}
