{ cfg, lib, pkgs, ... }:

let
  hasContainers = cfg.containers != [];
  containersWithDomain = builtins.filter (c: c.domain != "") cfg.containers;
  hasProxy = containersWithDomain != [];
  containersWithModels = builtins.filter (c: c.models != []) cfg.containers;

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

  mkModelPullService = c: {
    name = "${c.name}-model-pull";
    value = {
      description = "Pull models for ${c.name}";
      after = [ "docker-${c.name}.service" ];
      requires = [ "docker-${c.name}.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.curl pkgs.jq ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = let
        url = "http://127.0.0.1:${toString c.port}";
        pullCommands = lib.concatMapStringsSep "\n" (model: ''
          if curl -sf ${url}/api/tags | jq -e '.models[] | select(.name == "${model}")' > /dev/null 2>&1; then
            echo "${model} already present, skipping."
          else
            echo "Pulling ${model}..."
            curl -sf ${url}/api/pull -d '{"name": "${model}"}' | while read -r line; do
              echo "$line" | jq -r '.status // empty' 2>/dev/null || true
            done
          fi
        '') c.models;
      in ''
        echo "Waiting for ${c.name} at ${url}..."
        until curl -sf ${url}/api/tags > /dev/null 2>&1; do
          sleep 2
        done
        ${pullCommands}
        echo "All models ready."
      '';
    };
  };

in
lib.mkIf hasContainers {
  virtualisation.oci-containers = {
    backend = "docker";
    containers = builtins.listToAttrs (map mkContainer cfg.containers);
  };

  systemd.services = builtins.listToAttrs (map mkModelPullService containersWithModels);

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
