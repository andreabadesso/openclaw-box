#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a standalone openclaw-box directory.
# Usage: nix run github:andreabadesso/openclaw-box -- bootstrap

if [ -f "flake.nix" ]; then
  echo "Error: flake.nix already exists in this directory." >&2
  exit 1
fi

echo "Scaffolding openclaw-box in $(pwd)..."

# flake.nix
cat > flake.nix << 'FLAKE'
{
  inputs.openclaw-box.url = "github:andreabadesso/openclaw-box";
  outputs = { self, openclaw-box, ... }:
    openclaw-box.lib.mkBox self ./.;
}
FLAKE

# box.toml
cat > box.toml << 'TOML'
system = "x86_64-linux"  # or "aarch64-linux" for ARM (e.g. AWS Graviton)
hostname = "openclaw-box"
timezone = "UTC"
locale = "en_US.UTF-8"
stateVersion = "25.11"

[boot]
mode = "bios"  # "bios" or "efi"

[disk]
device = "/dev/sda"

[swap]
size = 4096  # MB, 0 to disable

[networking]
ports = [22, 80, 443]
[[networking.portRanges]]
from = 3000
to = 9999

[docker]
enable = true

[tailscale]
enable = false
authKeyFile = ""

# Secrets are at secrets/secrets.yaml (relative to this flake)
# Only override defaultSopsFile if you need a custom path
[sops]
ageKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]
secrets = ["anthropic_api_key", "telegram_bot_token"]

packages = []

[root]
sshKeys = [
  "ssh-ed25519 AAAA... you@example.com",
]

[[users]]
name = "myuser"
shell = "zsh"
groups = ["wheel", "docker"]
sshKeys = [
  "ssh-ed25519 AAAA... you@example.com",
]
[users.git]
email = "you@example.com"
name = "Your Name"
signByDefault = false
[users.devTools]
enable = true
tmux = true
direnv = true
fzf = true
mcfly = true
gitDelta = true
htop = true

[openclaw]
enable = true
[openclaw.agents]
model = "kimi-coding/k2p5"
thinkingDefault = "medium"
[openclaw.telegram]
tokenFile = "/run/secrets/telegram_bot_token"
allowFrom = [123456789]  # Your Telegram user ID
[openclaw.env]
KIMI_API_KEY = "/run/secrets/kimi_api_key"
TOML

# secrets directory
mkdir -p secrets

# .sops.yaml
cat > .sops.yaml << 'SOPS'
keys:
  - &server_key age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
creation_rules:
  - path_regex: secrets/.*\.yaml$
    key_groups:
      - age:
          - *server_key
SOPS

# .gitignore
cat > .gitignore << 'GITIGNORE'
result
.direnv
GITIGNORE

echo ""
echo "Done! Next steps:"
echo "  1. Edit box.toml with your server config"
echo "  2. Edit .sops.yaml with your age public key"
echo "  3. Create secrets:  sops secrets/secrets.yaml"
echo "  4. git init && git add -A"
echo "  5. Deploy:  nix run .#deploy -- <target-ip>"
