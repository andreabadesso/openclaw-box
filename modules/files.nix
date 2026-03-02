{ cfg, self, lib, ... }:

let
  hasFiles = cfg.files != [];

  mkEtcFile = f: {
    name = lib.removePrefix "/etc/" f.target;
    value = {
      source = self + "/${f.source}";
      mode = f.mode;
    };
  };

in
lib.mkIf hasFiles {
  environment.etc = builtins.listToAttrs (map mkEtcFile cfg.files);
}
