{ pkgs, ... }:

{
  networking.hostName = "clawd-box";
  networking.networkmanager.enable = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEaT/b47r3sHQdrwhShHrw8XXVEaXN9WzQk5kOxu1y5R andre.abadesso@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHR6yQ7mgE+2lVn04k04eWjErRwk5tacrT8euIvYdlgx opencode-deploy"
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
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

  environment.systemPackages = with pkgs; [
    vim
    curl
    git
    htop
  ];

  system.stateVersion = "25.11";
}
