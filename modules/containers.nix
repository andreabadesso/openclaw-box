{ cfg, lib, pkgs, ... }:

let
  hasContainers = cfg.containers != [];
  containersWithDomain = builtins.filter (c: c.domain != "") cfg.containers;
  hasProxy = containersWithDomain != [];

  mkContainer = c: {
    name = c.name;
    value = {
      image = c.image;
      ports = [ "${toString c.port}:${toString c.port}" ];
      volumes = c.volumes;
      environment = builtins.mapAttrs (_: v: toString v) c.env;
    };
  };

  mkVhost = c: {
    name = c.domain;
    value = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString c.port}";
        proxyWebsockets = true;
      };
    };
  };

in
lib.mkIf hasContainers {
  virtualisation.oci-containers = {
    backend = "docker";
    containers = builtins.listToAttrs (map mkContainer cfg.containers);
  };

  services.nginx = lib.mkIf hasProxy {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    virtualHosts = builtins.listToAttrs (map mkVhost containersWithDomain);
  };

  security.acme = lib.mkIf hasProxy {
    acceptTerms = true;
    defaults.email = cfg.proxy.email;
  };
}
