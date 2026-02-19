# openclaw-box

A ready-to-deploy NixOS server running [OpenClaw](https://github.com/clawdbot/nix-clawdbot), deployed via [nixos-anywhere](https://github.com/nix-community/nixos-anywhere).

## Overview

This project shows how to:
- Deploy NixOS to a VM/server using nixos-anywhere (no ISO needed)
- Run OpenClaw as a systemd user service on Linux
- Use disko for declarative disk partitioning
- Optionally manage secrets with sops-nix

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
   - `hosts/nixos/configuration.nix` - Add your SSH keys and set password
   - `flake.nix` - Configure OpenClaw providers (Telegram, Anthropic API key, etc.)

3. **Deploy:**
   ```bash
   # If you can build x86_64-linux locally:
   ./deploy.sh root@<target-ip>

   # If building from macOS, use a Linux build host:
   ./deploy.sh <target-ip> user@<linux-build-host>
   ```

## Configuration

### OpenClaw Setup

Edit `flake.nix` to configure your OpenClaw instance:

```nix
programs.clawdbot = {
  enable = true;
  instances.default = {
    enable = true;
    agent = {
      model = "anthropic/claude-sonnet-4-20250514";
      thinkingDefault = "medium";
    };
    providers.telegram = {
      enable = true;
      botTokenFile = "/run/secrets/telegram_bot_token";
      allowFrom = [ 123456789 ]; # Your Telegram user ID
    };
    providers.anthropic.apiKeyFile = "/run/secrets/anthropic_api_key";
  };
};
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

3. Reference in configuration.nix:
   ```nix
   sops.secrets = {
     telegram_bot_token = {};
     anthropic_api_key = {};
   };
   ```

## File Structure

```
.
├── flake.nix                 # Main flake with OpenClaw config
├── flake.lock
├── deploy.sh                 # Deployment helper script
├── hosts/
│   └── nixos/
│       ├── configuration.nix      # System configuration
│       ├── hardware-configuration.nix  # Boot/hardware settings
│       ├── disko-config.nix       # Disk partitioning
│       └── secrets/               # sops-nix secrets (optional)
└── README.md
```

## After Deployment

SSH into your server and check the OpenClaw service:

```bash
# Check service status
systemctl --user status clawdbot-gateway

# View logs
journalctl --user -u clawdbot-gateway -f

# Service is managed by home-manager, runs under root user
```

## Troubleshooting

### Build fails on macOS
Use a Linux build host with the `--build-on` flag or remote builder.

### VM gets different IP after kexec
nixos-anywhere kexecs into an installer, which may get a different DHCP IP. Use `--phases disko,install,reboot` if you're already in the kexec environment.

### GRUB not installing
For BIOS boot with GPT, ensure you have an EF02 partition and `boot.loader.grub.devices` is set correctly.

## License

MIT
