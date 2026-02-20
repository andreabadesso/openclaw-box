#!/usr/bin/env bash
set -euo pipefail

# Usage: ./update.sh <target-ip> [box-name] [build-host]
#
# Push a config update to a running box (nixos-rebuild switch).
# For initial provisioning, use deploy.sh instead.
#
# If build-host is provided, the build happens there (useful when
# the local machine can't build x86_64-linux, e.g. macOS).
#
# Examples:
#   ./update.sh 100.48.77.202 augusto
#   ./update.sh 54.224.254.109 abadesso andre@10.69.1.217

TARGET_IP=${1:?Usage: ./update.sh <target-ip> [box-name] [build-host]}
BOX_NAME=${2:-default}
BUILD_HOST=${3:-}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Nix flakes ignore files inside embedded git repos.
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

echo "Updating NixOS box '$BOX_NAME' at $TARGET_IP..."

if [ -n "$BUILD_HOST" ]; then
    echo "Building on $BUILD_HOST..."
    rsync -avz --delete --exclude='.git' --exclude='deploy.log' "$SCRIPT_DIR/" "$BUILD_HOST:~/nixos-deploy/"
    ssh "$BUILD_HOST" "cd ~/nixos-deploy && rm -rf .git && git init -q && git add -A && git add --force boxes/ && git -c user.name=deploy -c user.email=deploy commit -q -m deploy --allow-empty && nixos-rebuild switch --flake '.#$BOX_NAME' --target-host root@$TARGET_IP"
else
    nixos-rebuild switch \
        --flake "$SCRIPT_DIR#$BOX_NAME" \
        --target-host "root@$TARGET_IP"
fi
