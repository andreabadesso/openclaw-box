#!/usr/bin/env bash
set -euo pipefail

# Usage: ./deploy.sh <target-ip> [box-name] [ssh-user] [build-host]
#
# Examples:
#   ./deploy.sh 10.0.0.100                              # Deploy "default" box as admin@
#   ./deploy.sh 10.0.0.100 staging                       # Deploy "staging" box as admin@
#   ./deploy.sh 10.0.0.100 staging ec2-user              # Deploy as ec2-user@
#   ./deploy.sh 10.0.0.100 default admin user@10.0.0.50  # Build on remote host

TARGET_IP=${1:?Usage: ./deploy.sh <target-ip> [box-name] [ssh-user] [build-host]}
BOX_NAME=${2:-default}
SSH_USER=${3:-admin}
BUILD_HOST=${4:-}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Nix flakes ignore files inside embedded git repos and gitignored paths.
# Temporarily hide .git dirs in boxes/ so nix can see the files,
# then git-add them so they appear in the flake source tree.
hidden_gits=()
cleanup() {
    git -C "$SCRIPT_DIR" rm --cached -r --quiet boxes/ 2>/dev/null || true
    for d in "${hidden_gits[@]+"${hidden_gits[@]}"}"; do
        mv "$d/.git.bak" "$d/.git" 2>/dev/null || true
    done
}
trap cleanup EXIT

for gitdir in "$SCRIPT_DIR"/boxes/*/.git; do
    [ -d "$gitdir" ] || continue
    box_dir="$(dirname "$gitdir")"
    mv "$box_dir/.git" "$box_dir/.git.bak"
    hidden_gits+=("$box_dir")
done

git -C "$SCRIPT_DIR" add --force boxes/ 2>/dev/null || true

echo "Deploying NixOS box '$BOX_NAME' to $SSH_USER@$TARGET_IP..."

if [ -n "$BUILD_HOST" ]; then
    echo "Building on $BUILD_HOST..."
    rsync -avz --delete --exclude='.git' --exclude='deploy.log' "$SCRIPT_DIR/" "$BUILD_HOST:~/nixos-deploy/"
    ssh "$BUILD_HOST" "cd ~/nixos-deploy && rm -rf .git && git init -q && git add -A && git add --force boxes/ && git -c user.name=deploy -c user.email=deploy commit -q -m deploy && nix run github:nix-community/nixos-anywhere -- --flake '.#$BOX_NAME' $SSH_USER@$TARGET_IP"
else
    nix run github:nix-community/nixos-anywhere -- --build-on remote --flake ".#$BOX_NAME" "$SSH_USER@$TARGET_IP"
fi
