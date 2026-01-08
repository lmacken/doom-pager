#!/bin/bash
# Take a screenshot of the WiFi Pineapple Pager display
# Usage: ./screenshot.sh [output.png] [--rotate]
#
# Options:
#   --rotate, -r    Rotate 90° CW to show as DOOM renders it (landscape)
#   --no-rotate     Keep as displayed on Pager (portrait, default)

OUTPUT="pager_screenshot.png"
ROTATE=1  # Default: rotate to landscape
PAGER_IP="${PAGER_IP:-172.16.52.1}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --no-rotate|-n)
            ROTATE=0
            ;;
        --rotate|-r)
            ROTATE=1
            ;;
        -*)
            echo "Unknown option: $arg"
            exit 1
            ;;
        *)
            OUTPUT="$arg"
            ;;
    esac
done

# Pager display specs
WIDTH=222
HEIGHT=480

echo "Capturing Pager framebuffer..."

# Capture framebuffer and convert to PNG
ssh -i "$SSH_KEY" -o ConnectTimeout=5 "root@$PAGER_IP" "cat /dev/fb0" 2>/dev/null | python3 -c "
from PIL import Image
import struct
import sys

WIDTH, HEIGHT = $WIDTH, $HEIGHT
ROTATE = $ROTATE
data = sys.stdin.buffer.read()

if len(data) < WIDTH * HEIGHT * 2:
    print(f'Error: Got {len(data)} bytes, expected {WIDTH * HEIGHT * 2}', file=sys.stderr)
    sys.exit(1)

img = Image.new('RGB', (WIDTH, HEIGHT))
pixels = img.load()

for y in range(HEIGHT):
    for x in range(WIDTH):
        offset = (y * WIDTH + x) * 2
        pixel = struct.unpack('<H', data[offset:offset+2])[0]
        # RGB565 to RGB888
        r = ((pixel >> 11) & 0x1F) << 3
        g = ((pixel >> 5) & 0x3F) << 2
        b = (pixel & 0x1F) << 3
        pixels[x, y] = (r, g, b)

if ROTATE:
    # Rotate 90° counter-clockwise to show landscape right-side up
    img = img.rotate(90, expand=True)
    print(f'Screenshot saved to \"$OUTPUT\" ({HEIGHT}x{WIDTH})')
else:
    print(f'Screenshot saved to \"$OUTPUT\" ({WIDTH}x{HEIGHT}, portrait)')

img.save('$OUTPUT')
"

if [ -f "$OUTPUT" ]; then
    ls -la "$OUTPUT"
else
    echo "Error: Failed to capture screenshot"
    exit 1
fi

