#!/bin/bash
# Build and deploy DOOM to WiFi Pineapple Pager

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOOM_DIR="$SCRIPT_DIR/doomgeneric/doomgeneric"
PAGER="root@172.16.52.1"
DEST="/root/payloads/user/games/doom-pager"

echo "=== Building DOOM ==="
cd "$DOOM_DIR"
make -f Makefile.mipsel

echo ""
echo "=== Deploying to Pager ==="
scp doomgeneric doom1.wad "$SCRIPT_DIR/payload.sh" "$PAGER:$DEST/"
ssh "$PAGER" "chmod +x $DEST/doomgeneric $DEST/payload.sh"

echo ""
echo "=== Done! ==="

