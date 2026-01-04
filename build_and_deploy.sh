#!/bin/bash
# Build and deploy Doom to WiFi Pineapple Pager

set -e

PAGER_HOST="root@172.16.52.1"
DOOM_DIR="/home/l/code/pineapple/doom/doomgeneric/doomgeneric"
REMOTE_DIR="/tmp/doom"

echo "=== Building Doom for MIPS ==="
cd "$DOOM_DIR"

# Check if cross-compiler is available
if ! command -v mipsel-linux-gnu-gcc &> /dev/null; then
    echo "ERROR: mipsel-linux-gnu-gcc not found!"
    echo "Please install it with: sudo apt-get install gcc-mipsel-linux-gnu binutils-mipsel-linux-gnu"
    exit 1
fi

# Clean and build
echo "Cleaning previous build..."
make -f Makefile.mipsel clean || true

echo "Building Doom..."
make -f Makefile.mipsel

if [ ! -f "$DOOM_DIR/doomgeneric" ]; then
    echo "ERROR: Build failed!"
    exit 1
fi

echo "Build successful!"
ls -lh "$DOOM_DIR/doomgeneric"

# Check for WAD file
WAD_FILE=""
if [ -f "doom1.wad" ]; then
    WAD_FILE="doom1.wad"
elif [ -f "../doom1.wad" ]; then
    WAD_FILE="../doom1.wad"
else
    echo "WARNING: No WAD file found. You'll need to provide doom1.wad"
    echo "You can download the shareware version from:"
    echo "  https://distro.ibiblio.org/pub/linux/distributions/slitaz/sources/packages/d/doom1.wad"
fi

echo ""
echo "=== Transferring to WiFi Pineapple ==="
ssh "$PAGER_HOST" "mkdir -p $REMOTE_DIR"

echo "Copying doomgeneric binary..."
scp "$DOOM_DIR/doomgeneric" "$PAGER_HOST:$REMOTE_DIR/"

if [ -n "$WAD_FILE" ]; then
    echo "Copying WAD file..."
    scp "$DOOM_DIR/$WAD_FILE" "$PAGER_HOST:$REMOTE_DIR/" || \
    scp "$(dirname "$DOOM_DIR")/$WAD_FILE" "$PAGER_HOST:$REMOTE_DIR/"
fi

echo ""
echo "=== Setup complete! ==="
echo "To run Doom on the device, SSH in and run:"
echo "  ssh $PAGER_HOST"
echo "  cd $REMOTE_DIR"
if [ -n "$WAD_FILE" ]; then
    echo "  ./doomgeneric -iwad doom1.wad"
else
    echo "  ./doomgeneric -iwad <path-to-wad-file>"
fi

