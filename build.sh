#!/bin/bash
#
# DOOM for WiFi Pineapple Pager
# Copyright (C) 2026
#
# Fetch, patch, build, and package - all in one
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
RELEASE_DIR="$SCRIPT_DIR/payloads/user/games/doom"
RELEASE_DIR_DM="$SCRIPT_DIR/payloads/user/games/doom-deathmatch"
PAGER="${PAGER_HOST:-root@172.16.52.1}"
DEST="/root/payloads/user/games"

SDK_URL="https://downloads.openwrt.org/releases/22.03.5/targets/ramips/mt76x8/openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64.tar.xz"
DOOMGENERIC_REPO="https://github.com/ozkl/doomgeneric.git"
WAD_URL="https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad"

# Parse args
SKIP_DEPLOY=0
SKIP_RELEASE=0
DEPLOY_ONLY=0
for arg in "$@"; do
    case $arg in
        --no-deploy) SKIP_DEPLOY=1 ;;
        --no-release) SKIP_RELEASE=1 ;;
        --deploy-only|--sync) DEPLOY_ONLY=1 ;;
        --clean) rm -rf "$BUILD_DIR"; echo "Cleaned build dir"; exit 0 ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --no-deploy   Skip deploying to Pager"
            echo "  --no-release  Skip populating release directory"
            echo "  --deploy-only Sync release files to Pager without building"
            echo "  --clean       Remove build directory and exit"
            exit 0
            ;;
    esac
done

# Deploy-only mode: just sync existing release files
if [ "$DEPLOY_ONLY" = "1" ]; then
    echo "Deploying release files to $PAGER..."
    if [ ! -d "$RELEASE_DIR" ] || [ ! -d "$RELEASE_DIR_DM" ]; then
        echo "ERROR: Release directories not found. Run build first."
        exit 1
    fi
    ssh "$PAGER" "mkdir -p $DEST/doom $DEST/doom-deathmatch" 2>/dev/null || { echo "Cannot connect to $PAGER"; exit 1; }
    scp "$RELEASE_DIR"/* "$PAGER:$DEST/doom/"
    scp "$RELEASE_DIR_DM"/* "$PAGER:$DEST/doom-deathmatch/"
    ssh "$PAGER" "chmod +x $DEST/doom/doomgeneric $DEST/doom/*.sh $DEST/doom-deathmatch/doomgeneric $DEST/doom-deathmatch/*.sh"
    echo "Done! Synced to $PAGER:$DEST/"
    exit 0
fi

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
    echo "[1/6] Downloading OpenWrt SDK..."
    rm -rf "$BUILD_DIR/openwrt-sdk"
    curl -L "$SDK_URL" | tar -xJ -C "$BUILD_DIR"
    mv "$BUILD_DIR"/openwrt-sdk-* "$BUILD_DIR/openwrt-sdk"
else
    echo "[1/6] SDK ready"
fi

# 2. Clone/reset doomgeneric
if [ ! -d "$BUILD_DIR/doomgeneric/.git" ]; then
    echo "[2/6] Cloning doomgeneric..."
    rm -rf "$BUILD_DIR/doomgeneric"
    git clone --depth 1 "$DOOMGENERIC_REPO" "$BUILD_DIR/doomgeneric"
else
    echo "[2/6] Resetting doomgeneric..."
    git -C "$BUILD_DIR/doomgeneric" checkout . 
    git -C "$BUILD_DIR/doomgeneric" clean -fd
fi

# 3. Download WAD
if [ ! -f "$BUILD_DIR/doomgeneric/doomgeneric/doom1.wad" ]; then
    echo "[3/6] Downloading doom1.wad..."
    curl -L "$WAD_URL" -o "$BUILD_DIR/doomgeneric/doomgeneric/doom1.wad"
else
    echo "[3/6] WAD ready"
fi

# 4. Apply patches & build
echo "[4/6] Patching and building..."
echo "  - Applying wifi-pineapple-pager.patch..."
git -C "$BUILD_DIR/doomgeneric" apply "$SCRIPT_DIR/patches/wifi-pineapple-pager.patch"
echo "  - Applying multiplayer.patch..."
git -C "$BUILD_DIR/doomgeneric" apply "$SCRIPT_DIR/patches/multiplayer.patch"

export OPENWRT_SDK="$BUILD_DIR/openwrt-sdk"
make -C "$BUILD_DIR/doomgeneric/doomgeneric" -f Makefile.mipsel clean
make -C "$BUILD_DIR/doomgeneric/doomgeneric" -f Makefile.mipsel -j$(nproc)

BINARY="$BUILD_DIR/doomgeneric/doomgeneric/doomgeneric"
WAD="$BUILD_DIR/doomgeneric/doomgeneric/doom1.wad"

echo ""
echo "Build complete:"
ls -lh "$BINARY" "$WAD"

# 5. Populate release directories
if [ "$SKIP_RELEASE" = "0" ]; then
    echo ""
    echo "[5/6] Populating release directories..."
    mkdir -p "$RELEASE_DIR" "$RELEASE_DIR_DM"
    
    # Single-player: doom/
    cp "$BINARY" "$RELEASE_DIR/"
    cp "$WAD" "$RELEASE_DIR/"
    cp "$SCRIPT_DIR/payload.sh" "$RELEASE_DIR/"
    chmod +x "$RELEASE_DIR/doomgeneric" "$RELEASE_DIR/payload.sh"
    (cd "$RELEASE_DIR" && sha256sum doomgeneric doom1.wad payload.sh > SHA256SUMS)
    
    # Deathmatch: doom-deathmatch/
    cp "$BINARY" "$RELEASE_DIR_DM/"
    cp "$WAD" "$RELEASE_DIR_DM/"
    # Fix path in deathmatch payload (careful to only match full path)
    sed 's|/user/games/doom"|/user/games/doom-deathmatch"|g' \
        "$SCRIPT_DIR/payload-deathmatch.sh" > "$RELEASE_DIR_DM/payload.sh"
    chmod +x "$RELEASE_DIR_DM/doomgeneric" "$RELEASE_DIR_DM/payload.sh"
    (cd "$RELEASE_DIR_DM" && sha256sum doomgeneric doom1.wad payload.sh > SHA256SUMS)
    
    echo ""
    echo "Release: $RELEASE_DIR"
    ls -lh "$RELEASE_DIR"
    echo ""
    echo "Release: $RELEASE_DIR_DM"
    ls -lh "$RELEASE_DIR_DM"
else
    echo ""
    echo "[5/6] Skipping release (--no-release)"
fi

# 6. Deploy to Pager
if [ "$SKIP_DEPLOY" = "0" ]; then
    echo ""
    echo "[6/6] Deploying to $PAGER..."
    ssh "$PAGER" "mkdir -p $DEST/doom $DEST/doom-deathmatch" 2>/dev/null || { echo "Cannot connect to $PAGER (use --no-deploy to skip)"; exit 1; }
    scp "$RELEASE_DIR"/* "$PAGER:$DEST/doom/"
    scp "$RELEASE_DIR_DM"/* "$PAGER:$DEST/doom-deathmatch/"
    ssh "$PAGER" "chmod +x $DEST/doom/doomgeneric $DEST/doom/*.sh $DEST/doom-deathmatch/doomgeneric $DEST/doom-deathmatch/*.sh"
    echo ""
    echo "========================================"
    echo "  Done! Find DOOM & DOOM Deathmatch"
    echo "  in the Payloads > Games menu"
    echo "========================================"
else
    echo ""
    echo "[6/6] Skipping deploy (--no-deploy)"
    echo ""
    echo "To deploy manually:"
    echo "  scp $RELEASE_DIR/* $PAGER:$DEST/doom/"
    echo "  scp $RELEASE_DIR_DM/* $PAGER:$DEST/doom-deathmatch/"
fi
