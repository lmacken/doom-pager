#!/bin/bash
# Title: Doom
# Description: Play the classic Doom game on your WiFi Pineapple Pager!
# Author: Doom Port for WiFi Pineapple Pager
# Version: 1.0
# Category: Games

# Hardcoded path - the payload system runs scripts from /tmp
# so we must use the absolute installation path
PAYLOAD_DIR="/root/payloads/user/games/doom-pager"

cd "$PAYLOAD_DIR" || {
    LOG red "ERROR: Cannot change to directory: $PAYLOAD_DIR"
    exit 1
}

# Check if doomgeneric exists
if [ ! -f "$PAYLOAD_DIR/doomgeneric" ]; then
    LOG red "ERROR: doomgeneric binary not found in $PAYLOAD_DIR!"
    LOG "Current directory: $(pwd)"
    LOG "Files in directory: $(ls -1 | tr '\n' ' ')"
    exit 1
fi

# Make sure it's executable
chmod +x "$PAYLOAD_DIR/doomgeneric" 2>/dev/null

# Try to find a WAD file
WAD_FILE=""
for wad in freedoom1.wad freedoom2.wad doom1.wad doom.wad doom2.wad; do
    if [ -f "$PAYLOAD_DIR/$wad" ]; then
        WAD_FILE="$PAYLOAD_DIR/$wad"
        break
    fi
done

if [ -z "$WAD_FILE" ]; then
    LOG red "ERROR: No WAD file found!"
    LOG ""
    LOG "Please place a WAD file in this directory:"
    LOG "  - freedoom1.wad or freedoom2.wad (free, from https://freedoom.github.io/)"
    LOG "  - doom1.wad, doom.wad, or doom2.wad (if you own Doom)"
    LOG ""
    LOG "Press any button to exit..."
    WAIT_FOR_INPUT >/dev/null 2>&1
    exit 1
fi

LOG green "Starting Doom..."
LOG "Using WAD file: $WAD_FILE"
LOG ""
LOG "Controls:"
LOG "  D-pad = Move and turn"
LOG "  Red Button = Fire weapon"
LOG "  Green Button = Select/Confirm (menus)"
LOG "  Green + Up = Open doors/switches"
LOG "  Green + Down = Automap"
LOG "  Green + Left/Right = Strafe"
LOG "  Red + Green = Menu (to quit)"
LOG ""
LOG "Press any button to start..."
WAIT_FOR_INPUT >/dev/null 2>&1

# Stop ALL pineapple services and processes
/etc/init.d/pineapplepager stop 2>/dev/null
/etc/init.d/pineapd stop 2>/dev/null
sleep 0.2
# Kill any remaining pineapple processes
killall -9 pineapple 2>/dev/null
sleep 0.2

# Clear framebuffer
dd if=/dev/zero of=/dev/fb0 bs=213120 count=1 2>/dev/null

# Run Doom
"$PAYLOAD_DIR/doomgeneric" -iwad "$WAD_FILE" 2>/dev/null

# Restart services
/etc/init.d/pineapplepager start 2>/dev/null &
/etc/init.d/pineapd start 2>/dev/null &

# Return to menu when Doom exits
LOG ""
LOG "Doom has exited."
LOG "Press any button to return to menu..."
WAIT_FOR_INPUT >/dev/null 2>&1

