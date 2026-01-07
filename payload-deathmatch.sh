#!/bin/bash
# Title: DOOM Deathmatch
# Description: Connect to DOOM server for multiplayer deathmatch!
# Author: @lmacken
# Version: 2.1
# Category: Games

PAYLOAD_DIR="/root/payloads/user/games/doom"
CONFIG_FILE="$PAYLOAD_DIR/server.conf"

# Default server (Pineapple DOOM central server)
DEFAULT_SERVER_IP="64.227.99.100"
DEFAULT_SERVER_PORT="2342"

# Load saved config or use defaults
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    SERVER_IP="$DEFAULT_SERVER_IP"
    SERVER_PORT="$DEFAULT_SERVER_PORT"
fi

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

# Find any WAD file
WAD_FILE=$(ls "$PAYLOAD_DIR"/*.wad 2>/dev/null | head -1)
[ -z "$WAD_FILE" ] && {
    LOG red "ERROR: No .wad file found"
    exit 1
}

# Show current server and offer to configure
LOG "DOOM DEATHMATCH"
LOG ""
LOG "Server: $SERVER_IP:$SERVER_PORT"
LOG ""

resp=$(CONFIRMATION_DIALOG "Change server?")
if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    # Get new IP
    new_ip=$(IP_PICKER "Server IP" "$SERVER_IP")
    case $? in
        $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
            LOG "Cancelled"
            exit 1
            ;;
    esac
    
    # Get new port
    new_port=$(NUMBER_PICKER "Server Port" "$SERVER_PORT")
    case $? in
        $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
            LOG "Cancelled"
            exit 1
            ;;
    esac
    
    SERVER_IP="$new_ip"
    SERVER_PORT="$new_port"
    
    # Save config
    echo "SERVER_IP=\"$SERVER_IP\"" > "$CONFIG_FILE"
    echo "SERVER_PORT=\"$SERVER_PORT\"" >> "$CONFIG_FILE"
    
    LOG "Saved: $SERVER_IP:$SERVER_PORT"
fi

# Display controls
LOG ""
LOG "Controls:"
LOG "D-pad=Move  Red=Fire"
LOG "Green=Select/Use"
LOG "Red+Green=Quit"
LOG ""
LOG "Press any button to connect..."
WAIT_FOR_INPUT >/dev/null 2>&1

# Stop the Pager UI
/etc/init.d/pineapplepager stop 2>/dev/null
/etc/init.d/pineapd stop 2>/dev/null

# Clear framebuffer
dd if=/dev/zero of=/dev/fb0 bs=61440 count=1 2>/dev/null
sleep 1

# Run DOOM!
"$PAYLOAD_DIR/doomgeneric" -iwad "$WAD_FILE" -connect "$SERVER_IP:$SERVER_PORT" >/tmp/doom.log 2>&1

# Restore Pager UI
/etc/init.d/pineapplepager start 2>/dev/null &
/etc/init.d/pineapd start 2>/dev/null &

LOG ""
LOG "DOOM exited. Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1
