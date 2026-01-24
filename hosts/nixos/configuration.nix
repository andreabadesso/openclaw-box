{ pkgs, ... }:

{
  networking.hostName = "clawdbot-server";
  networking.networkmanager.enable = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Generate with: mkpasswd -m sha-512
  users.users.root.hashedPassword = "$6$example$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";

  users.users.root.openssh.authorizedKeys.keys = [
    # Add your SSH public key(s) here
    # "ssh-ed25519 AAAA... your-key@example.com"
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Optional: sops-nix for secrets management
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    validateSopsFiles = false;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      # anthropic_api_key = {};
      # telegram_bot_token = {};
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
