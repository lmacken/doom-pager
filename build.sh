#!/bin/bash
#
# DOOM for WiFi Pineapple Pager
# Build and deploy in one command
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
PAGER="root@172.16.52.1"
DEST="/root/payloads/user/games/doom"

SDK_URL="https://downloads.openwrt.org/releases/22.03.5/targets/ramips/mt76x8/openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64.tar.xz"
DOOMGENERIC_REPO="https://github.com/ozkl/doomgeneric.git"
WAD_URL="https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad"

echo "========================================"
echo "  DOOM for WiFi Pineapple Pager"
echo "========================================"

# Check for qemu on non-x86_64 hosts
if ! uname -m | grep -q "x86_64"; then
    if ! command -v qemu-x86_64 &> /dev/null; then
        echo "ERROR: qemu-x86_64 required (sudo apt install qemu-user-static)"
        exit 1
    fi
fi

mkdir -p "$BUILD_DIR"

# Download OpenWrt SDK
if [ ! -d "$BUILD_DIR/openwrt-sdk" ]; then
    echo "[*] Downloading OpenWrt SDK..."
    curl -L "$SDK_URL" | tar -xJ -C "$BUILD_DIR"
    mv "$BUILD_DIR"/openwrt-sdk-* "$BUILD_DIR/openwrt-sdk"
fi
echo "[✓] SDK ready"

# Clone doomgeneric
if [ ! -d "$BUILD_DIR/doomgeneric" ]; then
    echo "[*] Cloning doomgeneric..."
    git clone --depth 1 "$DOOMGENERIC_REPO" "$BUILD_DIR/doomgeneric"
else
    echo "[*] Resetting doomgeneric..."
    cd "$BUILD_DIR/doomgeneric"
    git checkout . && git clean -fd
fi
echo "[✓] Source ready"

# Download doom1.wad if needed
if [ ! -f "$BUILD_DIR/doomgeneric/doomgeneric/doom1.wad" ]; then
    echo "[*] Downloading doom1.wad..."
    curl -L "$WAD_URL" -o "$BUILD_DIR/doomgeneric/doomgeneric/doom1.wad"
fi
echo "[✓] WAD ready"

# Apply patch
echo "[*] Applying patch..."
cd "$BUILD_DIR/doomgeneric"
git apply "$SCRIPT_DIR/patches/wifi-pineapple-pager.patch"
echo "[✓] Patch applied"

# Build
echo "[*] Building..."
cd "$BUILD_DIR/doomgeneric/doomgeneric"
export OPENWRT_SDK="$BUILD_DIR/openwrt-sdk"
make -f Makefile.mipsel -j$(nproc)
echo "[✓] Build complete"

# Show checksums
echo ""
echo "SHA256:"
sha256sum doomgeneric doom1.wad

# Deploy
echo ""
echo "[*] Deploying to $PAGER..."
ssh "$PAGER" "mkdir -p $DEST"
scp doomgeneric doom1.wad "$SCRIPT_DIR/payload.sh" "$PAGER:$DEST/"
ssh "$PAGER" "chmod +x $DEST/doomgeneric $DEST/payload.sh"

echo ""
echo "========================================"
echo "  Done! Find DOOM in Payloads menu"
echo "========================================"
