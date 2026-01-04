#!/bin/bash
# Transfer Doom binary to WiFi Pineapple Pager
# Run this when USB keyboard is NOT connected (to maintain SSH access)

PAGER_HOST="root@172.16.52.1"
DOOM_DIR="/home/l/code/pineapple/doom/doomgeneric/doomgeneric"
REMOTE_DIR="/tmp/doom"

echo "=== Transferring Doom to WiFi Pineapple ==="

if [ ! -f "$DOOM_DIR/doomgeneric" ]; then
    echo "ERROR: doomgeneric binary not found at $DOOM_DIR/doomgeneric"
    echo "Please build it first with: cd $DOOM_DIR && make -f Makefile.mipsel"
    exit 1
fi

echo "Copying doomgeneric binary..."
scp "$DOOM_DIR/doomgeneric" "$PAGER_HOST:$REMOTE_DIR/"

if [ -f "$DOOM_DIR/doom1.wad" ]; then
    echo "Copying WAD file..."
    scp "$DOOM_DIR/doom1.wad" "$PAGER_HOST:$REMOTE_DIR/"
fi

echo ""
echo "=== Transfer complete! ==="
echo "Now you can:"
echo "  1. Unplug USB keyboard (if connected)"
echo "  2. SSH to the device: ssh $PAGER_HOST"
echo "  3. Run Doom: cd $REMOTE_DIR && ./doomgeneric -iwad doom1.wad"
echo ""
echo "GPIO Button Mappings:"
echo "  - Volume Up/Down: Move forward/backward"
echo "  - Power/Back: Escape/Menu"
echo "  - Home/Select/OK: Use/Open"
echo "  - Menu: Map/Status (TAB)"
echo "  - Search: Fire weapon"
echo "  - Arrow keys: Turn left/right, move forward/backward"

