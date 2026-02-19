# openclaw-box

A ready-to-deploy NixOS server running [OpenClaw](https://github.com/openclaw/nix-openclaw), deployed via [nixos-anywhere](https://github.com/nix-community/nixos-anywhere).

## Overview

This project shows how to:
- Deploy NixOS to a VM/server using nixos-anywhere (no ISO needed)
- Run OpenClaw as a systemd user service on Linux
- Use disko for declarative disk partitioning
- Manage secrets with sops-nix
- Define multiple box configs via TOML files

## Prerequisites

1. [Determinate Nix](https://docs.determinate.systems/determinate-nix/) installed
2. A target machine accessible via SSH (can be a fresh Linux install or live ISO)
3. SSH key access to the target

## Quick Start

1. **Clone and customize:**
   ```bash
   git clone https://github.com/andreabadesso/openclaw-box
   cd openclaw-box
   ```

2. **Edit configuration:**
   - `boxes/default.toml` — hostname, SSH keys, users, OpenClaw settings, etc.

3. **Deploy:**
   ```bash
   # Deploy the "default" box, build locally:
   ./deploy.sh <target-ip>

   # Deploy a specific box:
   ./deploy.sh <target-ip> staging

   # Build on a remote Linux host:
   ./deploy.sh <target-ip> default user@<linux-build-host>
   ```

## Configuration

All configuration lives in `boxes/*.toml`. Each file generates a `nixosConfiguration` automatically — `boxes/default.toml` becomes `nixosConfigurations.default`, `boxes/staging.toml` becomes `nixosConfigurations.staging`, etc.

### TOML Config Example

```toml
hostname = "openclaw-box"
timezone = "UTC"
locale = "en_US.UTF-8"
stateVersion = "25.11"

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

[sops]
defaultSopsFile = "hosts/nixos/secrets/secrets.yaml"
ageKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]
secrets = ["anthropic_api_key", "telegram_bot_token"]

[root]
sshKeys = ["ssh-ed25519 AAAA..."]

[[users]]
name = "openclaw"
shell = "zsh"
groups = ["wheel", "docker"]
sshKeys = ["ssh-ed25519 AAAA..."]
[users.git]
email = "you@example.com"
name = "Your Name"
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
model = "anthropic/claude-sonnet-4-20250514"
thinkingDefault = "medium"
[openclaw.telegram]
tokenFile = "/run/secrets/telegram_bot_token"
allowFrom = [123456789]  # Your Telegram user ID
[openclaw.env]
ANTHROPIC_API_KEY = "/run/secrets/anthropic_api_key"
```

### Secrets with sops-nix

1. Create secrets file:
   ```bash
   mkdir -p hosts/nixos/secrets
   sops hosts/nixos/secrets/secrets.yaml
   ```

2. Add secrets:
   ```yaml
   telegram_bot_token: "your-bot-token"
   anthropic_api_key: "sk-ant-..."
   ```

3. Reference them in your TOML config:
   ```toml
   [sops]
   secrets = ["anthropic_api_key", "telegram_bot_token"]
   ```

## File Structure

```
.
├── flake.nix                      # Scans boxes/*.toml, generates nixosConfigurations
├── flake.lock
├── deploy.sh                      # ./deploy.sh <ip> [box-name] [build-host]
├── boxes/
│   └── default.toml               # Default box config
├── lib/
│   ├── defaults.nix               # Default values for all config fields
│   └── load-config.nix            # TOML loader + deep merge with defaults
├── modules/
│   ├── disko.nix                  # Parameterized disk partitioning
│   ├── hardware.nix               # Boot/kernel config
│   ├── system.nix                 # System config (networking, packages, etc.)
│   ├── users.nix                  # User creation from config
│   └── home/
│       ├── openclaw.nix           # OpenClaw home-manager setup for root
│       ├── dev-tools.nix          # Per-user dev tools (git, tmux, fzf, etc.)
│       └── tmux-config.nix        # Tmux theme and keybindings
└── hosts/
    └── nixos/
        └── secrets/               # sops-nix encrypted secrets
```

## After Deployment

SSH into your server and check the OpenClaw service:

```bash
# Check service status
systemctl --user status openclaw-gateway

# View logs
journalctl --user -u openclaw-gateway -f

# Service is managed by home-manager, runs under root user
```

## Creating a New Box

1. Copy `boxes/default.toml` to `boxes/mybox.toml`
2. Customize hostname, SSH keys, users, etc.
3. Deploy: `./deploy.sh <target-ip> mybox`

## Troubleshooting

### Build fails on macOS
Use a Linux build host: `./deploy.sh <target-ip> default user@<linux-build-host>`

### VM gets different IP after kexec
nixos-anywhere kexecs into an installer, which may get a different DHCP IP. Use `--phases disko,install,reboot` if you're already in the kexec environment.

### GRUB not installing
For BIOS boot with GPT, ensure you have an EF02 partition and `boot.loader.grub.devices` is set correctly in `modules/hardware.nix`.

## License

MIT
