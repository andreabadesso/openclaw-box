#!/usr/bin/env bash
set -euo pipefail

# Usage: ./update.sh <target-ip> [box-name]
#
# Push a config update to a running box (nixos-rebuild switch).
# For initial provisioning, use deploy.sh instead.
#
# Examples:
#   ./update.sh 100.48.77.202 augusto

TARGET_IP=${1:?Usage: ./update.sh <target-ip> [box-name]}
BOX_NAME=${2:-default}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Nix flakes ignore files inside embedded git repos.
# Temporarily hide .git dirs in boxes/ so nix can see the files,
# then git-add them so they appear in the flake source tree.
hidden_gits=()
cleanup() {
    # Unstage box files and restore .git dirs
    git -C "$SCRIPT_DIR" rm --cached -r --quiet boxes/ 2>/dev/null || true
    for d in "${hidden_gits[@]}"; do
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
nixos-rebuild switch \
    --flake "$SCRIPT_DIR#$BOX_NAME" \
    --target-host "root@$TARGET_IP"
