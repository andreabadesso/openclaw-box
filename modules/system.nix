{ cfg, self, pkgs, lib, ... }:

let
  extraPkgs = map (name: pkgs.${name}) cfg.packages;
  userNames = map (u: u.name) cfg.users;
in
{
  networking.hostName = cfg.hostname;
  networking.networkmanager.enable = true;

  time.timeZone = cfg.timezone;
  i18n.defaultLocale = cfg.locale;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      UseDns = false;
    };
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" ] ++ userNames;
  };

  sops = {
    defaultSopsFile = self + "/${cfg.sops.defaultSopsFile}";
    age.sshKeyPaths = cfg.sops.ageKeyPaths;
    secrets = builtins.listToAttrs (
      map (name: { inherit name; value = {}; }) cfg.sops.secrets
    );
  };

  virtualisation.docker = lib.mkIf cfg.docker.enable {
    enable = true;
  };

  services.tailscale = lib.mkIf cfg.tailscale.enable {
    enable = true;
    authKeyFile = lib.mkIf (cfg.tailscale.authKeyFile != "") cfg.tailscale.authKeyFile;
  };

  programs.zsh.enable = lib.any (u: u.shell == "zsh") cfg.users;

  security.sudo.wheelNeedsPassword = false;

  networking.firewall.allowedTCPPorts = cfg.networking.ports;
  networking.firewall.allowedTCPPortRanges = cfg.networking.portRanges;

  swapDevices = lib.mkIf (cfg.swap.size > 0) [{
    device = "/var/swapfile";
    size = cfg.swap.size;
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
  ] ++ extraPkgs;

  system.stateVersion = cfg.stateVersion;
}
