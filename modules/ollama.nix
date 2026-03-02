{ cfg, lib, pkgs, ... }:

lib.mkIf cfg.ollama.enable {
  services.ollama = {
    enable = true;
    host = cfg.ollama.host;
    port = cfg.ollama.port;
  };

  systemd.services.ollama-model-pull = lib.mkIf (cfg.ollama.models != []) {
    description = "Pull Ollama models";
    after = [ "ollama.service" ];
    requires = [ "ollama.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.curl pkgs.jq ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = let
      url = "http://${cfg.ollama.host}:${toString cfg.ollama.port}";
      pullCommands = lib.concatMapStringsSep "\n" (model: ''
        if curl -sf ${url}/api/tags | jq -e '.models[] | select(.name == "${model}")' > /dev/null 2>&1; then
          echo "${model} already present, skipping."
        else
          echo "Pulling ${model}..."
          curl -sf ${url}/api/pull -d '{"name": "${model}"}' | while read -r line; do
            echo "$line" | jq -r '.status // empty' 2>/dev/null || true
          done
        fi
      '') cfg.ollama.models;
    in ''
      echo "Waiting for Ollama at ${url}..."
      until curl -sf ${url}/api/tags > /dev/null 2>&1; do
        sleep 2
      done
      ${pullCommands}
      echo "All models ready."
    '';
  };
}
