# openclaw-box

A ready-to-deploy NixOS server running [OpenClaw](https://github.com/openclaw/nix-openclaw), deployed via [nixos-anywhere](https://github.com/nix-community/nixos-anywhere).

## Overview

This project shows how to:
- Deploy NixOS to a VM/server using nixos-anywhere (no ISO needed)
- Run OpenClaw as a systemd user service on Linux
- Use disko for declarative disk partitioning
- Manage secrets with sops-nix
- Define multiple box configs via TOML files in isolated directories

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

2. **Create your box config:**
   ```bash
   mkdir -p boxes/mybox/secrets
   cp boxes/example.toml boxes/mybox/box.toml
   ```
   Edit `boxes/mybox/box.toml` — hostname, SSH keys, users, OpenClaw settings, etc.

3. **Set up secrets:**
   ```bash
   # Create .sops.yaml in your box directory
   cat > boxes/mybox/.sops.yaml <<'EOF'
   creation_rules:
     - path_regex: secrets/.*\.yaml$
       age: <your-age-public-key>
   EOF

   # Create and edit secrets
   cd boxes/mybox
   sops secrets/secrets.yaml
   ```

4. **Track your box for Nix (required — flakes only see git-tracked files):**
   ```bash
   git add -f boxes/mybox/
   ```
   The `.gitignore` prevents `git add .` from picking up box directories, but `-f` forces staging. Files stay staged locally and won't be pushed.

5. **Deploy:**
   ```bash
   # Deploy the "mybox" box, build locally:
   ./deploy.sh <target-ip> mybox

   # Build on a remote Linux host:
   ./deploy.sh <target-ip> mybox user@<linux-build-host>
   ```

## Configuration

Each box lives in its own directory under `boxes/` — `boxes/mybox/box.toml` generates `nixosConfigurations.mybox`. Box directories are gitignored so personal data (SSH keys, secrets) stays out of the repo.

A tracked `boxes/example.toml` is provided as a schema reference (it's a flat file, not a directory, so it's not scanned by the flake).

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

# Secrets auto-discovered at boxes/<name>/secrets/secrets.yaml
[sops]
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
model = "kimi-coding/k2p5"
thinkingDefault = "medium"
[openclaw.telegram]
tokenFile = "/run/secrets/telegram_bot_token"
allowFrom = [123456789]  # Your Telegram user ID
[openclaw.env]
KIMI_API_KEY = "/run/secrets/kimi_api_key"
```

### Secrets with sops-nix

Each box has its own `.sops.yaml` and secrets directory:

```
boxes/mybox/
  box.toml
  .sops.yaml          # Per-box age key config
  secrets/
    secrets.yaml       # Encrypted secrets
```

The sops file path is auto-derived — no need to set `defaultSopsFile` in your TOML config.

1. Create your `.sops.yaml`:
   ```yaml
   creation_rules:
     - path_regex: secrets/.*\.yaml$
       age: <your-age-public-key>
   ```

2. Create and edit secrets:
   ```bash
   cd boxes/mybox
   sops secrets/secrets.yaml
   ```

3. Add secrets:
   ```yaml
   telegram_bot_token: "your-bot-token"
   kimi_api_key: "sk-..."
   ```

4. Reference them in your TOML config:
   ```toml
   [sops]
   secrets = ["kimi_api_key", "telegram_bot_token"]
   ```

## File Structure

```
.
├── flake.nix                      # Scans boxes/*/box.toml, generates nixosConfigurations
├── flake.lock
├── deploy.sh                      # ./deploy.sh <ip> <box-name> [build-host]
├── boxes/
│   ├── example.toml               # Schema reference (tracked, not scanned)
│   └── <name>/                    # Per-box directory (gitignored)
│       ├── box.toml               # Box configuration
│       ├── .sops.yaml             # Per-box age key
│       └── secrets/
│           └── secrets.yaml       # Encrypted secrets
├── lib/
│   ├── defaults.nix               # Default values for all config fields
│   └── load-config.nix            # TOML loader + deep merge with defaults
└── modules/
    ├── disko.nix                  # Parameterized disk partitioning
    ├── hardware.nix               # Boot/kernel config
    ├── system.nix                 # System config (networking, packages, etc.)
    ├── users.nix                  # User creation from config
    └── home/
        ├── openclaw.nix           # OpenClaw home-manager setup for root
        ├── dev-tools.nix          # Per-user dev tools (git, tmux, fzf, etc.)
        └── tmux-config.nix        # Tmux theme and keybindings
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

1. Create the box directory:
   ```bash
   mkdir -p boxes/mybox/secrets
   cp boxes/example.toml boxes/mybox/box.toml
   ```
2. Customize `box.toml` — hostname, SSH keys, users, etc.
3. Set up `.sops.yaml` and secrets (see above)
4. Track for Nix: `git add -f boxes/mybox/`
5. Deploy: `./deploy.sh <target-ip> mybox`

## Troubleshooting

### Build fails on macOS
Use a Linux build host: `./deploy.sh <target-ip> mybox user@<linux-build-host>`

### VM gets different IP after kexec
nixos-anywhere kexecs into an installer, which may get a different DHCP IP. Use `--phases disko,install,reboot` if you're already in the kexec environment.

### GRUB not installing
For BIOS boot with GPT, ensure you have an EF02 partition and `boot.loader.grub.devices` is set correctly in `modules/hardware.nix`.

### Nix can't find box.toml
Nix flakes only see git-tracked files. Run `git add -f boxes/<name>/` to stage your box directory.

## License

MIT
