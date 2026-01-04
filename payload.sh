#!/bin/bash
# Title: DOOM
# Description: The classic 1993 FPS on your WiFi Pineapple Pager!
# Author: DOOM Pager Port
# Version: 1.0
# Category: Games

PAYLOAD_DIR="/root/payloads/user/games/doom-pager"
cd "$PAYLOAD_DIR" || { LOG red "ERROR: $PAYLOAD_DIR not found"; exit 1; }

[ ! -f "./doomgeneric" ] && { LOG red "ERROR: doomgeneric not found"; exit 1; }
chmod +x ./doomgeneric 2>/dev/null

WAD_FILE=$(ls "$PAYLOAD_DIR"/*.wad 2>/dev/null | head -1)
[ -z "$WAD_FILE" ] && { LOG red "ERROR: No .wad file found"; exit 1; }

LOG "DOOM - $WAD_FILE"
LOG ""
LOG "D-pad=Move  Red=Fire  Green=Select"
LOG "Green+Up=Use  Green+Down=Map"
LOG "Green+Left/Right=Strafe"
LOG "Red+Green=Quit"
LOG ""
LOG "Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1

/etc/init.d/pineapplepager stop 2>/dev/null
/etc/init.d/pineapd stop 2>/dev/null
sleep 0.2
killall -9 pineapple 2>/dev/null
sleep 0.2

dd if=/dev/zero of=/dev/fb0 bs=213120 count=1 2>/dev/null
"$PAYLOAD_DIR/doomgeneric" -iwad "$WAD_FILE" 2>/dev/null

/etc/init.d/pineapplepager start 2>/dev/null &
/etc/init.d/pineapd start 2>/dev/null &

LOG ""
LOG "DOOM exited. Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1

