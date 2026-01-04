#!/bin/bash
#
# DOOM for WiFi Pineapple Pager - Build Script
#
# Downloads dependencies, applies patches, builds MIPS binary.
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR="$SCRIPT_DIR/release"

SDK_URL="https://downloads.openwrt.org/releases/22.03.5/targets/ramips/mt76x8/openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64.tar.xz"
DOOMGENERIC_REPO="https://github.com/ozkl/doomgeneric.git"

echo "========================================"
echo "  DOOM for WiFi Pineapple Pager"
echo "========================================"
echo ""

# Check for qemu on non-x86_64 hosts
if ! uname -m | grep -q "x86_64"; then
    if ! command -v qemu-x86_64 &> /dev/null; then
        echo "ERROR: qemu-x86_64 required on $(uname -m) hosts"
        echo "Install: sudo apt install qemu-user-static"
        exit 1
    fi
    echo "[✓] QEMU available"
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Download OpenWrt SDK
if [ ! -d "$BUILD_DIR/openwrt-sdk" ]; then
    echo "[*] Downloading OpenWrt SDK (~400MB)..."
    curl -L "$SDK_URL" | tar -xJ -C "$BUILD_DIR"
    mv "$BUILD_DIR"/openwrt-sdk-* "$BUILD_DIR/openwrt-sdk"
    echo "[✓] SDK ready"
else
    echo "[✓] SDK exists"
fi

# Clone doomgeneric
if [ ! -d "$BUILD_DIR/doomgeneric" ]; then
    echo "[*] Cloning doomgeneric..."
    git clone --depth 1 "$DOOMGENERIC_REPO" "$BUILD_DIR/doomgeneric"
    echo "[✓] Source cloned"
else
    echo "[✓] Source exists"
    echo "[*] Resetting source..."
    cd "$BUILD_DIR/doomgeneric"
    git checkout .
    git clean -fd
fi

# Apply patches
echo "[*] Applying patches..."
cd "$BUILD_DIR/doomgeneric"
git apply "$SCRIPT_DIR/patches/doomgeneric-pager.patch"
echo "[✓] Patches applied"

# Build
echo "[*] Building..."
cd "$BUILD_DIR/doomgeneric/doomgeneric"
export OPENWRT_SDK="$BUILD_DIR/openwrt-sdk"
make -f Makefile.mipsel clean
make -f Makefile.mipsel

if [ ! -f "doomgeneric" ]; then
    echo "ERROR: Build failed"
    exit 1
fi
echo "[✓] Build complete"

# Create release
echo "[*] Creating release..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cp doomgeneric "$OUTPUT_DIR/"
cp doom1.wad "$OUTPUT_DIR/" 2>/dev/null || cp "$SCRIPT_DIR/doom1.wad" "$OUTPUT_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/payload.sh" "$OUTPUT_DIR/"
chmod +x "$OUTPUT_DIR/doomgeneric" "$OUTPUT_DIR/payload.sh"

# Checksums
echo ""
echo "========================================"
echo "  Build Complete"
echo "========================================"
echo ""
cd "$OUTPUT_DIR"
echo "Files:"
ls -la
echo ""
echo "SHA256:"
sha256sum * | tee SHA256SUMS
echo ""
echo "Deploy: scp release/* root@172.16.52.1:/root/payloads/user/games/doom-pager/"
