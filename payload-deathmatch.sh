#!/bin/bash
# Title: DOOM Deathmatch
# Description: Multiplayer deathmatch with item respawns!
# Author: @lmacken
# Version: 5.1
# Category: Games

PAYLOAD_DIR="/root/payloads/user/games/doom-deathmatch"
CONFIG_FILE="$PAYLOAD_DIR/server.conf"

# Defaults - optimized for fun on Pager
DEFAULT_SERVER_IP="64.227.99.100"
DEFAULT_PLAYER_NAME="Pager"
DEFAULT_CONNECTION_MODE="automatch"
DEFAULT_MAP="E1M1"
DEFAULT_TIMELIMIT="10"

# Load saved config
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Apply defaults
: "${PLAYER_NAME:=$DEFAULT_PLAYER_NAME}"
: "${CONNECTION_MODE:=$DEFAULT_CONNECTION_MODE}"
: "${SERVER_IP:=$DEFAULT_SERVER_IP}"
: "${SERVER_PORT:=2342}"
: "${MAP:=$DEFAULT_MAP}"
: "${TIMELIMIT:=$DEFAULT_TIMELIMIT}"

cd "$PAYLOAD_DIR" || { LOG red "ERROR: $PAYLOAD_DIR not found"; exit 1; }
[ ! -f "./doomgeneric" ] && { LOG red "ERROR: doomgeneric not found"; exit 1; }
chmod +x ./doomgeneric

WAD_FILE=$(ls "$PAYLOAD_DIR"/*.wad 2>/dev/null | head -1)
[ -z "$WAD_FILE" ] && { LOG red "ERROR: No .wad file found"; exit 1; }

# Show intro
LOG "DOOM DEATHMATCH

Player: $PLAYER_NAME
Map: $MAP  Time: ${TIMELIMIT}m

D-pad=Move  Red=Fire
Green+Up=Use  Green+L/R=Strafe
Red+Green=Quit"

sleep 1

# Quick settings
resp=$(CONFIRMATION_DIALOG "Change settings?")
if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    # Connection mode
    mode_choice=$(NUMBER_PICKER "1=Auto 2=Browse 3=IP" "1")
    case "$mode_choice" in
        1) CONNECTION_MODE="automatch" ;;
        2) CONNECTION_MODE="browse" ;;
        3) CONNECTION_MODE="direct" ;;
    esac

    # Player name
    new_name=$(TEXT_PICKER "Name" "$PLAYER_NAME")
    [ -n "$new_name" ] && PLAYER_NAME="$new_name"

    # Direct connect
    if [ "$CONNECTION_MODE" = "direct" ]; then
        new_ip=$(IP_PICKER "Server IP" "$SERVER_IP")
        [ -n "$new_ip" ] && SERVER_IP="$new_ip"
    fi

    # Save
    cat > "$CONFIG_FILE" << EOF
PLAYER_NAME="$PLAYER_NAME"
CONNECTION_MODE="$CONNECTION_MODE"
SERVER_IP="$SERVER_IP"
SERVER_PORT="$SERVER_PORT"
MAP="$MAP"
TIMELIMIT="$TIMELIMIT"
EOF
    LOG "Saved!"
fi

LOG "Press any button..."
sleep 0.1
WAIT_FOR_INPUT >/dev/null 2>&1

# Show spinner
SPINNER_ID=$(START_SPINNER "Loading DOOM...")

# Stop services
/etc/init.d/php8-fpm stop 2>/dev/null
/etc/init.d/nginx stop 2>/dev/null
/etc/init.d/bluetoothd stop 2>/dev/null
/etc/init.d/pineapplepager stop 2>/dev/null
/etc/init.d/pineapd stop 2>/dev/null

STOP_SPINNER "$SPINNER_ID" 2>/dev/null
sleep 0.5

# Parse map (E1M4 -> 1 4)
EPISODE=$(echo "$MAP" | sed -n 's/^E\([0-9]\)M[0-9]$/\1/p')
MAP_NUM=$(echo "$MAP" | sed -n 's/^E[0-9]M\([0-9]\)$/\1/p')
[ -z "$EPISODE" ] && EPISODE=1
[ -z "$MAP_NUM" ] && MAP_NUM=1

# Build args:
# -altdeath: Items respawn after 30 sec (more action!)
# -skill 3: Normal damage (default "Hurt Me Plenty")
# -nomonsters: No monsters in deathmatch
ARGS="-iwad $WAD_FILE -name $PLAYER_NAME -warp $EPISODE $MAP_NUM"
ARGS="$ARGS -altdeath -skill 3 -nomonsters"
[ "$TIMELIMIT" -gt 0 ] 2>/dev/null && ARGS="$ARGS -timer $TIMELIMIT"

case "$CONNECTION_MODE" in
    automatch) ARGS="$ARGS -automatch" ;;
    browse)    ARGS="$ARGS -browse" ;;
    direct)    ARGS="$ARGS -connect $SERVER_IP:$SERVER_PORT" ;;
    *)         ARGS="$ARGS -automatch" ;;
esac

# Run DOOM
"$PAYLOAD_DIR/doomgeneric" $ARGS >/tmp/doom.log 2>&1

# Restore services
/etc/init.d/php8-fpm start 2>/dev/null &
/etc/init.d/nginx start 2>/dev/null &
/etc/init.d/bluetoothd start 2>/dev/null &
/etc/init.d/pineapplepager start 2>/dev/null &
/etc/init.d/pineapd start 2>/dev/null &

LOG "DOOM exited."
WAIT_FOR_INPUT >/dev/null 2>&1
