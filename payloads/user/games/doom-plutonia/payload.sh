#!/bin/bash
# Title: Final DOOM: Plutonia
# Description: Final DOOM: Plutonia Experiment
# Author: @lmacken
# Version: 1.0
# Category: Games

PAYLOAD_DIR="/root/payloads/user/games/doom-plutonia"

cd "$PAYLOAD_DIR" || {
    LOG red "ERROR: $PAYLOAD_DIR not found"
    exit 1
}

# Verify required files exist
[ ! -f "./doomgeneric" ] && {
    LOG red "ERROR: doomgeneric not found"
    exit 1
}
chmod +x ./doomgeneric

LOG "Final DOOM: Plutonia"
LOG "Final DOOM: Plutonia Experiment"
LOG ""
LOG "Controls:"
LOG "D-pad=Move  Red=Fire"
LOG "Green=Select/Use"
LOG "Red+Green=Quit"
LOG ""
LOG "Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1

# Stop the Pager UI
/etc/init.d/pineapplepager stop 2>/dev/null
/etc/init.d/pineapd stop 2>/dev/null

sleep 1

# Build command line
DOOM_ARGS="-iwad \"$PAYLOAD_DIR/plutonia.wad\""

# Run DOOM!
eval "$PAYLOAD_DIR/doomgeneric $DOOM_ARGS" >/tmp/doom.log 2>&1

# Restore Pager UI
/etc/init.d/pineapplepager start 2>/dev/null &
/etc/init.d/pineapd start 2>/dev/null &

LOG ""
LOG "DOOM exited. Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1
