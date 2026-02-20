{ lib }:

let
  defaults = import ./defaults.nix;

  # Deep merge: TOML values override defaults entirely (including lists)
  # Missing keys fall back to defaults
  deepMerge = base: override:
    let
      mergeAttr = name:
        if builtins.hasAttr name override then
          let
            baseVal = base.${name} or null;
            overVal = override.${name};
          in
          if builtins.isAttrs baseVal && builtins.isAttrs overVal && !(builtins.isList overVal)
          then deepMerge baseVal overVal
          else overVal
        else
          base.${name};
    in
    builtins.listToAttrs (
      map (name: { inherit name; value = mergeAttr name; })
        (lib.unique (builtins.attrNames base ++ builtins.attrNames override))
    );

  userDefaults = {
    shell = "bash";
    groups = [];
    sshKeys = [];
    git = {
      email = "";
      name = "";
      signByDefault = false;
    };
    devTools = {
      enable = false;
      tmux = false;
      direnv = false;
      fzf = false;
      mcfly = false;
      gitDelta = false;
      htop = false;
    };
  };

  mergeUser = user: deepMerge userDefaults user;

  containerDefaults = {
    name = "";
    image = "";
    port = 0;
    domain = "";
    volumes = [];
    env = {};
  };

  mergeContainer = container: deepMerge containerDefaults container;

in
tomlPath:
  let
    raw = builtins.fromTOML (builtins.readFile tomlPath);
    merged = deepMerge defaults raw;
  in
  merged // {
    users = map mergeUser merged.users;
    containers = map mergeContainer merged.containers;
  }
