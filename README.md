<div align="center">

# openclaw-box

**Deploy a fully-configured [OpenClaw](https://github.com/openclaw/nix-openclaw) server in one command.**

NixOS + nixos-anywhere + TOML config = zero-touch provisioning.

[Quick Start](#quick-start) &bull; [Configuration](#configuration) &bull; [Secrets](#secrets) &bull; [Deployment](#deployment) &bull; [Troubleshooting](#troubleshooting)

</div>

---

## What is this?

A declarative NixOS framework for deploying machines running **OpenClaw** — an AI agent gateway with Telegram bot integration. Point it at any SSH-accessible server, run one command, and get a fully provisioned system with:

- Declarative disk partitioning via [disko](https://github.com/nix-community/disko) (BIOS or EFI)
- Encrypted secrets via [sops-nix](https://github.com/Mic92/sops-nix) + age
- Per-user dev environments via [home-manager](https://github.com/nix-community/home-manager)
- OpenClaw gateway as a systemd service with Telegram bot support
- Docker, Tailscale, and a curated set of dev tools — all opt-in

Each machine ("box") is defined by a single TOML file. The Nix flake auto-discovers boxes and generates complete `nixosConfigurations` — no manual wiring needed.

## Prerequisites

- [Determinate Nix](https://docs.determinate.systems/determinate-nix/) installed
- A target machine accessible via SSH (fresh Linux install or live ISO)
- SSH key access to the target

## Quick Start

**1. Clone**

```bash
git clone https://github.com/andreabadesso/openclaw-box
cd openclaw-box
```

**2. Create a box**

```bash
mkdir -p boxes/mybox/secrets
cp boxes/example.toml boxes/mybox/box.toml
```

Edit `boxes/mybox/box.toml` with your hostname, SSH keys, users, and OpenClaw settings.

**3. Set up secrets**

```bash
# Create per-box sops config
cat > boxes/mybox/.sops.yaml <<'EOF'
creation_rules:
  - path_regex: secrets/.*\.yaml$
    age: <your-age-public-key>
EOF

# Create and edit encrypted secrets
cd boxes/mybox && sops secrets/secrets.yaml
```

**4. Stage for Nix** (flakes only see git-tracked files)

```bash
git add -f boxes/mybox/
```

> The `.gitignore` prevents `git add .` from picking up box directories, but `-f` forces staging. Files stay local and won't be pushed.

**5. Deploy**

```bash
./deploy.sh <target-ip> mybox
```

That's it. The target machine will be partitioned, formatted, and fully provisioned over SSH.

## Configuration

Each box lives in its own directory under `boxes/`. The flake scans for `boxes/*/box.toml` and generates one NixOS configuration per box. Missing keys fall back to sensible defaults via deep merge.

### Full Schema

```toml
# --- System ---
system      = "x86_64-linux"     # or "aarch64-linux"
hostname    = "openclaw-box"
timezone    = "UTC"
locale      = "en_US.UTF-8"
stateVersion = "25.11"
packages    = []                  # extra nixpkgs packages

# --- Boot & Disk ---
[boot]
mode = "bios"                     # "bios" (GRUB) or "efi" (systemd-boot)

[disk]
device = "/dev/sda"

[swap]
size = 4096                       # MB, 0 to disable

# --- Networking ---
[networking]
ports = [22, 80, 443]
[[networking.portRanges]]
from = 3000
to = 9999

# --- Services ---
[docker]
enable = true

[tailscale]
enable = false
authKeyFile = ""

# --- Secrets (sops-nix + age) ---
[sops]
ageKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]
secrets = ["kimi_api_key", "telegram_bot_token"]
# defaultSopsFile auto-derived to boxes/<name>/secrets/secrets.yaml

# --- Root ---
[root]
sshKeys = ["ssh-ed25519 AAAA..."]

# --- Users ---
[[users]]
name = "openclaw"
shell = "zsh"                     # "zsh", "bash", or "fish"
groups = ["wheel", "docker"]
sshKeys = ["ssh-ed25519 AAAA..."]

[users.git]
email = "you@example.com"
name = "Your Name"
signByDefault = false

[users.devTools]
enable = true
tmux     = true
direnv   = true
fzf      = true
mcfly    = true
gitDelta = true
htop     = true

# --- OpenClaw ---
[openclaw]
enable = true

[openclaw.agents]
model = "kimi-coding/k2p5"       # provider auto-detected from prefix
thinkingDefault = "medium"

[openclaw.telegram]
tokenFile = "/run/secrets/telegram_bot_token"
allowFrom = [123456789]           # Telegram user IDs

[openclaw.env]
KIMI_API_KEY = "/run/secrets/kimi_api_key"
```

### How Config Loading Works

1. `lib/load-config.nix` parses the TOML with `builtins.fromTOML`
2. Deep-merges against `lib/defaults.nix` — attribute sets merge recursively, scalars and lists override
3. Each entry in `[[users]]` gets its own merge against user defaults
4. The sops secrets file path is auto-derived to `boxes/<name>/secrets/secrets.yaml`

## Secrets

Each box has its own `.sops.yaml` and encrypted secrets file:

```
boxes/mybox/
  box.toml
  .sops.yaml            # age public key config
  secrets/
    secrets.yaml         # encrypted with sops
```

### Setup

**1.** Create `.sops.yaml` pointing to your age public key:

```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    age: age1abc...your-public-key
```

**2.** Create and populate secrets:

```bash
cd boxes/mybox
sops secrets/secrets.yaml
```

```yaml
kimi_api_key: "sk-..."
telegram_bot_token: "123456:ABC-DEF..."
```

**3.** Reference them in TOML:

```toml
[sops]
secrets = ["kimi_api_key", "telegram_bot_token"]
```

At deploy time, sops-nix decrypts secrets using the host's SSH ed25519 key and makes them available as files under `/run/secrets/<name>`. The OpenClaw service reads these at startup.

## Deployment

### Basic

```bash
./deploy.sh <target-ip> mybox
```

### With a Remote Build Host

If you're on macOS or want to offload the build:

```bash
./deploy.sh <target-ip> mybox user@linux-build-host
```

This rsyncs the project to the build host and runs nixos-anywhere there.

### What Happens

1. **kexec** — nixos-anywhere kexecs the target into a NixOS installer (no reboot needed)
2. **disko** — partitions and formats the disk per your config
3. **install** — installs the full NixOS system
4. **reboot** — boots into the new system

### After Deployment

```bash
ssh root@<target-ip>

# Check the OpenClaw service
systemctl status openclaw-gateway

# Follow logs
journalctl -u openclaw-gateway -f
```

## Project Structure

```
.
├── flake.nix                 # Auto-discovers boxes/*/box.toml, generates nixosConfigurations
├── flake.lock                # Pinned dependencies
├── deploy.sh                 # ./deploy.sh <ip> <box> [build-host]
│
├── boxes/
│   ├── example.toml          # Full schema reference (tracked in git)
│   └── <name>/               # Per-box directory (gitignored)
│       ├── box.toml
│       ├── .sops.yaml
│       └── secrets/
│           └── secrets.yaml
│
├── lib/
│   ├── defaults.nix          # Default values for all config fields
│   └── load-config.nix       # TOML loader + deep merge
│
└── modules/
    ├── disko.nix             # Disk partitioning (BIOS/EFI aware)
    ├── hardware.nix          # Boot loader + kernel config
    ├── system.nix            # Networking, SSH, packages, sops, docker, swap
    ├── users.nix             # User accounts from config
    └── home/
        ├── openclaw.nix      # OpenClaw gateway systemd service
        ├── dev-tools.nix     # Per-user dev tools (git, tmux, fzf, etc.)
        └── tmux-config.nix   # Tmux theme + keybindings
```

### Module Breakdown

| Module | Responsibility |
|---|---|
| `disko.nix` | GPT partition table — BIOS: 1 MB EF02 + ext4 root; EFI: 512 MB vfat `/boot` + ext4 root |
| `hardware.nix` | QEMU guest profile, virtio drivers, GRUB or systemd-boot based on `boot.mode` |
| `system.nix` | Hostname, timezone, locale, SSH hardening, firewall, Nix flakes, Docker, Tailscale, swap, default packages |
| `users.nix` | Creates system users with shell, groups, and SSH keys from `[[users]]` config |
| `openclaw.nix` | Configures OpenClaw via home-manager, creates a wrapper script that injects sops secrets as env vars, runs as a systemd service |
| `dev-tools.nix` | Per-user home-manager config: git + delta, mcfly, direnv, fzf, htop, tmux |
| `tmux-config.nix` | Ctrl-A prefix, vi mode, vim-aware pane navigation, GitHub dark theme, session persistence |

### Default System Packages

Every box ships with: `curl`, `wget`, `htop`, `procps`, `git`, `vim`, `direnv`, `ripgrep`, `fd`, `unzip`, `gcc`, `gnumake`, `cmake`, `pkg-config`, `python3`, `nodejs_22` — plus anything in your `packages` list.

## Troubleshooting

**Build fails on macOS**
Use a remote Linux build host: `./deploy.sh <ip> mybox user@linux-host`

**VM gets a different IP after kexec**
nixos-anywhere kexecs into an installer that may get a new DHCP lease. Use `--phases disko,install,reboot` if you're already in the kexec environment.

**GRUB not installing**
For BIOS boot with GPT, ensure `boot.mode = "bios"` in your TOML — this creates the required EF02 partition.

**Nix can't find `box.toml`**
Flakes only see git-tracked files. Run `git add -f boxes/<name>/` to stage your box.

## License

MIT
