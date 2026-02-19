{ cfg, pkgs, ... }:

let
  shellPkg = shell:
    if shell == "zsh" then pkgs.zsh
    else if shell == "fish" then pkgs.fish
    else pkgs.bash;

  mkUser = user: {
    name = user.name;
    value = {
      isNormalUser = true;
      extraGroups = user.groups;
      shell = shellPkg user.shell;
      openssh.authorizedKeys.keys = user.sshKeys;
    };
  };
in
{
  users.users = builtins.listToAttrs (map mkUser cfg.users) // {
    root.openssh.authorizedKeys.keys = cfg.root.sshKeys;
  };
}
