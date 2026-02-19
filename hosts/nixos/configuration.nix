{ pkgs, ... }:

{
  networking.hostName = "openclaw-box";
  networking.networkmanager.enable = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Root user
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEaT/b47r3sHQdrwhShHrw8XXVEaXN9WzQk5kOxu1y5R andre.abadesso@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHR6yQ7mgE+2lVn04k04eWjErRwk5tacrT8euIvYdlgx opencode-deploy"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMh5PUo1BDe3MURD9g7EHO8OTq2bxerdAp2ICeYqy4CE andre@nixos"
  ];

  security.sudo.wheelNeedsPassword = false;

  # Openclaw user
  users.users.openclaw = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEaT/b47r3sHQdrwhShHrw8XXVEaXN9WzQk5kOxu1y5R andre.abadesso@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMh5PUo1BDe3MURD9g7EHO8OTq2bxerdAp2ICeYqy4CE andre@nixos"
    ];
  };

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      UseDns = false;
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      anthropic_api_key = {};
      telegram_bot_token = {};
    };
  };

  # Docker
  virtualisation.docker.enable = true;

  # Zsh
  programs.zsh.enable = true;

  # Firewall - wide open for dev
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
  networking.firewall.allowedTCPPortRanges = [{ from = 3000; to = 9999; }];

  # Swap
  swapDevices = [{
    device = "/var/swapfile";
    size = 4096;
  }];

  environment.variables.EDITOR = "vim";

  environment.systemPackages = with pkgs; [
    curl
    wget
    htop
    procps
    git
    vim
    direnv
    ripgrep
    fd
    unzip
    gcc
    gnumake
    cmake
    pkg-config
    python3
    nodejs_22
  ];

  system.stateVersion = "25.11";
}
