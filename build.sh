#!/bin/bash
#
# DOOM for WiFi Pineapple Pager
# Fetch, patch, build, deploy - all in one
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
PAGER="${PAGER_HOST:-root@172.16.52.1}"
DEST="/root/payloads/user/games/doom"

SDK_URL="https://downloads.openwrt.org/releases/22.03.5/targets/ramips/mt76x8/openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64.tar.xz"
DOOMGENERIC_REPO="https://github.com/ozkl/doomgeneric.git"
WAD_URL="https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad"

# Parse args
SKIP_DEPLOY=0
for arg in "$@"; do
    case $arg in
        --no-deploy) SKIP_DEPLOY=1 ;;
        --clean) rm -rf "$BUILD_DIR"; echo "Cleaned build dir" ;;
    esac
done

echo "========================================"
echo "  DOOM for WiFi Pineapple Pager"
echo "========================================"

# Check dependencies
command -v curl >/dev/null || { echo "ERROR: curl required"; exit 1; }
command -v git >/dev/null || { echo "ERROR: git required"; exit 1; }
command -v make >/dev/null || { echo "ERROR: make required"; exit 1; }

# Check for qemu on non-x86_64 hosts
if ! uname -m | grep -q "x86_64"; then
    command -v qemu-x86_64 >/dev/null || { echo "ERROR: qemu-x86_64 required (apt install qemu-user-static)"; exit 1; }
fi

mkdir -p "$BUILD_DIR"

# 1. OpenWrt SDK
if [ ! -f "$BUILD_DIR/openwrt-sdk/staging_dir/toolchain-mipsel_24kc_gcc-11.2.0_musl/bin/mipsel-openwrt-linux-musl-gcc" ]; then
    echo "[1/5] Downloading OpenWrt SDK..."
    rm -rf "$BUILD_DIR/openwrt-sdk"
    curl -L "$SDK_URL" | tar -xJ -C "$BUILD_DIR"
    mv "$BUILD_DIR"/openwrt-sdk-* "$BUILD_DIR/openwrt-sdk"
else
    echo "[1/5] SDK ready"
fi

# 2. Clone/reset doomgeneric
if [ ! -d "$BUILD_DIR/doomgeneric/.git" ]; then
    echo "[2/5] Cloning doomgeneric..."
    rm -rf "$BUILD_DIR/doomgeneric"
    git clone --depth 1 "$DOOMGENERIC_REPO" "$BUILD_DIR/doomgeneric"
else
    echo "[2/5] Resetting doomgeneric..."
    git -C "$BUILD_DIR/doomgeneric" checkout . 
    git -C "$BUILD_DIR/doomgeneric" clean -fd
fi

# 3. Download WAD
if [ ! -f "$BUILD_DIR/doomgeneric/doomgeneric/doom1.wad" ]; then
    echo "[3/5] Downloading doom1.wad..."
    curl -L "$WAD_URL" -o "$BUILD_DIR/doomgeneric/doomgeneric/doom1.wad"
else
    echo "[3/5] WAD ready"
fi

# 4. Apply patch & build
echo "[4/5] Patching and building..."
git -C "$BUILD_DIR/doomgeneric" apply "$SCRIPT_DIR/patches/wifi-pineapple-pager.patch"
export OPENWRT_SDK="$BUILD_DIR/openwrt-sdk"
make -C "$BUILD_DIR/doomgeneric/doomgeneric" -f Makefile.mipsel clean
make -C "$BUILD_DIR/doomgeneric/doomgeneric" -f Makefile.mipsel -j$(nproc)

# Show results
BINARY="$BUILD_DIR/doomgeneric/doomgeneric/doomgeneric"
WAD="$BUILD_DIR/doomgeneric/doomgeneric/doom1.wad"
echo ""
echo "Build complete:"
ls -lh "$BINARY" "$WAD"
echo ""
echo "SHA256:"
sha256sum "$BINARY" "$WAD"

# 5. Deploy
if [ "$SKIP_DEPLOY" = "0" ]; then
    echo ""
    echo "[5/5] Deploying to $PAGER..."
    ssh "$PAGER" "mkdir -p $DEST" 2>/dev/null || { echo "Cannot connect to $PAGER (use --no-deploy to skip)"; exit 1; }
    scp "$BINARY" "$WAD" "$SCRIPT_DIR/payload.sh" "$PAGER:$DEST/"
    ssh "$PAGER" "chmod +x $DEST/doomgeneric $DEST/payload.sh"
    echo ""
    echo "========================================"
    echo "  Done! Find DOOM in Payloads menu"
    echo "========================================"
else
    echo ""
    echo "[5/5] Skipping deploy (--no-deploy)"
    echo ""
    echo "To deploy manually:"
    echo "  scp $BINARY $WAD payload.sh $PAGER:$DEST/"
fi
