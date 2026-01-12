#!/bin/bash
# Title: DOOM
# Description: The classic FPS, optimized for Pager
# Author: @lmacken
# Version: 4.2
# Category: Games

PAYLOAD_DIR="/root/payloads/user/games/doom"
DOOM_BIN="$PAYLOAD_DIR/doomgeneric"
CONFIG_FILE="$PAYLOAD_DIR/perf.conf"

# Default settings
USE_RENDERPF="yes"
USE_FPSDEBUG="no"

# Load saved config
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Find WAD file
WAD_FILE=$(ls "$PAYLOAD_DIR"/*.wad 2>/dev/null | head -1)
[ -z "$WAD_FILE" ] && WAD_FILE="$PAYLOAD_DIR/doom1.wad"
[ ! -f "$WAD_FILE" ] && {
    LOG red "ERROR: No WAD file found"
    exit 1
}

# Check binary
[ ! -f "$DOOM_BIN" ] && {
    LOG red "ERROR: doomgeneric not found"
    exit 1
}
chmod +x "$DOOM_BIN"

# Build command line flags from settings
build_flags() {
    FLAGS=""
    [ "$USE_RENDERPF" != "yes" ] && FLAGS="$FLAGS -noprefetch"
    [ "$USE_FPSDEBUG" = "yes" ] && FLAGS="$FLAGS -fpsdebug"
    echo "$FLAGS"
}

# Save config
save_config() {
    cat > "$CONFIG_FILE" << EOF
USE_RENDERPF="$USE_RENDERPF"
USE_FPSDEBUG="$USE_FPSDEBUG"
EOF
}

# Run DOOM
run_doom() {
    local flags=$(build_flags)
    
    LOG ""
    LOG "Starting DOOM..."
    [ -n "$flags" ] && LOG "Flags:$flags"
    sleep 0.3
    
    # Stop services
    /etc/init.d/php8-fpm stop 2>/dev/null
    /etc/init.d/nginx stop 2>/dev/null
    /etc/init.d/bluetoothd stop 2>/dev/null
    /etc/init.d/pineapplepager stop 2>/dev/null
    /etc/init.d/pineapd stop 2>/dev/null
    sleep 1
    
    # Run DOOM
    "$DOOM_BIN" -iwad "$WAD_FILE" $flags >/tmp/doom.log 2>&1
    
    # Restart services
    /etc/init.d/php8-fpm start 2>/dev/null &
    /etc/init.d/nginx start 2>/dev/null &
    /etc/init.d/bluetoothd start 2>/dev/null &
    /etc/init.d/pineapplepager start 2>/dev/null &
    /etc/init.d/pineapd start 2>/dev/null &
}

# Show current settings summary
show_settings_summary() {
    LOG "Settings:"
    [ "$USE_RENDERPF" = "yes" ]  && LOG "  RenderPF=ON" || LOG "  RenderPF=OFF"
    [ "$USE_FPSDEBUG" = "yes" ]  && LOG "  FPSDebug=ON" || LOG "  FPSDebug=OFF"
}

# Main
LOG "DOOM"
LOG ""
LOG "D-pad=Move  Red=Fire  Green=Select"
LOG "Green+Up=Use  Green+L/R=Strafe"
LOG "Red+Green=Quit"
LOG ""
show_settings_summary
LOG ""

sleep 1

# Ask to change settings
resp=$(CONFIRMATION_DIALOG "Change settings?")
if [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    
    # Render prefetch
    resp=$(CONFIRMATION_DIALOG "Render Prefetch?")
    [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ] && USE_RENDERPF="yes" || USE_RENDERPF="no"
    
    # FPS debug
    resp=$(CONFIRMATION_DIALOG "FPS logging?")
    [ "$resp" = "$DUCKYSCRIPT_USER_CONFIRMED" ] && USE_FPSDEBUG="yes" || USE_FPSDEBUG="no"
    
    # Save and show new settings
    save_config
    LOG ""
    LOG "Settings saved!"
    show_settings_summary
    LOG ""
fi

LOG "Press any button to start..."
sleep 0.1
WAIT_FOR_INPUT >/dev/null 2>&1

run_doom

LOG ""
LOG "DOOM exited."

# Show FPS stats if debug was enabled
if [ "$USE_FPSDEBUG" = "yes" ] && [ -f /tmp/fps.log ]; then
    stats=$(awk '{ sum+=$2; n++; if(NR==1||$2<min)min=$2; if(NR==1||$2>max)max=$2 } END { if(n>0) printf "avg=%.1f min=%.0f max=%.0f", sum/n, min, max }' /tmp/fps.log)
    LOG "FPS: $stats"
fi

LOG ""
LOG "Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1
