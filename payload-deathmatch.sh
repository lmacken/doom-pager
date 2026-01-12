#!/bin/bash
# Title: DOOM Deathmatch
# Description: Connect to DOOM server for multiplayer deathmatch!
# Author: @lmacken
# Version: 5.0
# Category: Games

PAYLOAD_DIR="/root/payloads/user/games/doom-deathmatch"
CONFIG_FILE="$PAYLOAD_DIR/server.conf"

# Default settings
DEFAULT_SERVER_IP="64.227.99.100"
DEFAULT_SERVER_PORT="2342"
DEFAULT_MAP="E1M1"
DEFAULT_NOMONSTERS="yes"
DEFAULT_TIMELIMIT="10"
DEFAULT_SKILL="4"
DEFAULT_PLAYER_NAME="Pager"
DEFAULT_CONNECTION_MODE="automatch"

# Load saved config or use defaults
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    SERVER_IP="$DEFAULT_SERVER_IP"
    SERVER_PORT="$DEFAULT_SERVER_PORT"
    MAP="$DEFAULT_MAP"
    NOMONSTERS="$DEFAULT_NOMONSTERS"
    TIMELIMIT="$DEFAULT_TIMELIMIT"
    SKILL="$DEFAULT_SKILL"
    PLAYER_NAME="$DEFAULT_PLAYER_NAME"
    CONNECTION_MODE="$DEFAULT_CONNECTION_MODE"
fi

# Ensure defaults
[ -z "$MAP" ] && MAP="$DEFAULT_MAP"
[ -z "$NOMONSTERS" ] && NOMONSTERS="$DEFAULT_NOMONSTERS"
[ -z "$TIMELIMIT" ] && TIMELIMIT="$DEFAULT_TIMELIMIT"
[ -z "$SKILL" ] && SKILL="$DEFAULT_SKILL"
[ -z "$PLAYER_NAME" ] && PLAYER_NAME="$DEFAULT_PLAYER_NAME"
[ -z "$CONNECTION_MODE" ] && CONNECTION_MODE="$DEFAULT_CONNECTION_MODE"

cd "$PAYLOAD_DIR" || {
    LOG red "ERROR: $PAYLOAD_DIR not found"
    exit 1
}

# Verify required files
[ ! -f "./doomgeneric" ] && {
    LOG red "ERROR: doomgeneric not found"
    exit 1
}
chmod +x ./doomgeneric

WAD_FILE=$(ls "$PAYLOAD_DIR"/*.wad 2>/dev/null | head -1)
[ -z "$WAD_FILE" ] && {
    LOG red "ERROR: No .wad file found"
    exit 1
}

# Show intro - all in one LOG call for speed
LOG "DOOM DEATHMATCH

Player: $PLAYER_NAME
Map: $MAP  Skill: $SKILL

D-pad=Move  Red=Fire
Green+Up=Use  Green+L/R=Strafe
Red+Green=Quit"

sleep 1

# Quick settings check
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
    new_name=$(TEXT_PICKER "Player Name" "$PLAYER_NAME")
    [ -n "$new_name" ] && PLAYER_NAME="$new_name"

    # Direct connect settings
    if [ "$CONNECTION_MODE" = "direct" ]; then
        new_ip=$(IP_PICKER "Server IP" "$SERVER_IP")
        [ -n "$new_ip" ] && SERVER_IP="$new_ip"
        new_port=$(NUMBER_PICKER "Port" "$SERVER_PORT")
        [ -n "$new_port" ] && SERVER_PORT="$new_port"
    fi

    # Save config
    cat > "$CONFIG_FILE" << EOF
PLAYER_NAME="$PLAYER_NAME"
SERVER_IP="$SERVER_IP"
SERVER_PORT="$SERVER_PORT"
MAP="$MAP"
NOMONSTERS="$NOMONSTERS"
TIMELIMIT="$TIMELIMIT"
SKILL="$SKILL"
CONNECTION_MODE="$CONNECTION_MODE"
EOF
    LOG "Settings saved!"
fi

LOG "Press any button..."
sleep 0.1
WAIT_FOR_INPUT >/dev/null 2>&1

# Stop services
/etc/init.d/php8-fpm stop 2>/dev/null
/etc/init.d/nginx stop 2>/dev/null
/etc/init.d/bluetoothd stop 2>/dev/null
/etc/init.d/pineapplepager stop 2>/dev/null
/etc/init.d/pineapd stop 2>/dev/null
sleep 1

# Parse map format
EPISODE=$(echo "$MAP" | sed -n 's/^E\([0-9]\)M[0-9]$/\1/p')
MAP_NUM=$(echo "$MAP" | sed -n 's/^E[0-9]M\([0-9]\)$/\1/p')
[ -z "$EPISODE" ] && EPISODE=1
[ -z "$MAP_NUM" ] && MAP_NUM=1

# Build args
BASE_ARGS="-iwad $WAD_FILE -name $PLAYER_NAME -warp $EPISODE $MAP_NUM -deathmatch"
[ "$NOMONSTERS" = "yes" ] && BASE_ARGS="$BASE_ARGS -nomonsters"
[ "$TIMELIMIT" -gt 0 ] 2>/dev/null && BASE_ARGS="$BASE_ARGS -timer $TIMELIMIT"
[ "$SKILL" -ge 1 ] && [ "$SKILL" -le 5 ] 2>/dev/null && BASE_ARGS="$BASE_ARGS -skill $SKILL"

case "$CONNECTION_MODE" in
    automatch) CONN_ARGS="-automatch" ;;
    browse)    CONN_ARGS="-browse" ;;
    direct)    CONN_ARGS="-connect $SERVER_IP:$SERVER_PORT" ;;
    *)         CONN_ARGS="-automatch" ;;
esac

# Run DOOM
"$PAYLOAD_DIR/doomgeneric" $BASE_ARGS $CONN_ARGS >/tmp/doom.log 2>&1

# Restore services
/etc/init.d/php8-fpm start 2>/dev/null &
/etc/init.d/nginx start 2>/dev/null &
/etc/init.d/bluetoothd start 2>/dev/null &
/etc/init.d/pineapplepager start 2>/dev/null &
/etc/init.d/pineapd start 2>/dev/null &

LOG "DOOM exited."
WAIT_FOR_INPUT >/dev/null 2>&1
