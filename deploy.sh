#!/usr/bin/env bash
set -euo pipefail

# Usage: ./deploy.sh <target-ip> [build-host]
#
# Examples:
#   ./deploy.sh 10.0.0.100                    # Build locally, deploy to target
#   ./deploy.sh 10.0.0.100 user@10.0.0.50     # Build on remote host, deploy to target

TARGET_IP=${1:?Usage: ./deploy.sh <target-ip> [build-host]}
BUILD_HOST=${2:-}

echo "Deploying NixOS to $TARGET_IP..."

if [ -n "$BUILD_HOST" ]; then
    echo "Building on $BUILD_HOST..."
    # Copy flake to build host and run nixos-anywhere from there
    rsync -avz --exclude='.git' --exclude='deploy.log' ./ "$BUILD_HOST:~/nixos-deploy/"
    ssh "$BUILD_HOST" "cd ~/nixos-deploy && nix run github:nix-community/nixos-anywhere -- --flake '.#clawd-box' root@$TARGET_IP"
else
    # Build locally and deploy
    nix run github:nix-community/nixos-anywhere -- --flake ".#clawd-box" "root@$TARGET_IP"
fi
