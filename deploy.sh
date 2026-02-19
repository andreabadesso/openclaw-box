#!/usr/bin/env bash
set -euo pipefail

# Usage: ./deploy.sh <target-ip> [box-name] [build-host]
#
# Examples:
#   ./deploy.sh 10.0.0.100                        # Deploy "default" box, build locally
#   ./deploy.sh 10.0.0.100 staging                 # Deploy "staging" box, build locally
#   ./deploy.sh 10.0.0.100 default user@10.0.0.50  # Deploy "default" box, build on remote host

TARGET_IP=${1:?Usage: ./deploy.sh <target-ip> [box-name] [build-host]}
BOX_NAME=${2:-default}
BUILD_HOST=${3:-}

echo "Deploying NixOS box '$BOX_NAME' to $TARGET_IP..."

if [ -n "$BUILD_HOST" ]; then
    echo "Building on $BUILD_HOST..."
    rsync -avz --exclude='.git' --exclude='deploy.log' ./ "$BUILD_HOST:~/nixos-deploy/"
    ssh "$BUILD_HOST" "cd ~/nixos-deploy && nix run github:nix-community/nixos-anywhere -- --flake '.#$BOX_NAME' root@$TARGET_IP"
else
    nix run github:nix-community/nixos-anywhere -- --flake ".#$BOX_NAME" "root@$TARGET_IP"
fi
