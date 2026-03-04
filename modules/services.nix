{ cfg, packages, lib, pkgs, ... }:

let
  hasServices = cfg.services != [];

  mkService = svc:
    let
      pkg = packages.${svc.package};

      # Separate secret env vars (read from files at runtime) from literal env vars
      secretEnvExports = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: path: ''export ${name}="$(cat ${path})"'') svc.secretEnv
      );

      execCommand =
        if svc.command != ""
        then svc.command
        else "${pkg}/bin/${svc.name}";

      wrapper = pkgs.writeShellScript "${svc.name}-start" ''
        ${secretEnvExports}
        exec ${execCommand}
      '';

      extraAfter = map (a: "${a}") svc.after;
    in
    {
      name = svc.name;
      value = {
        description = "${svc.name} service";
        after = [ "network-online.target" ] ++ extraAfter;
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          User = svc.user;
          ExecStart = wrapper;
          Restart = "on-failure";
          RestartSec = 5;
          Environment = lib.mapAttrsToList (name: value: "${name}=${value}") svc.env;
        };
      };
    };

in
lib.mkIf hasServices {
  systemd.services = builtins.listToAttrs (map mkService cfg.services);

  networking.firewall.allowedTCPPorts =
    builtins.filter (p: p > 0) (map (svc: svc.port) cfg.services);
}
