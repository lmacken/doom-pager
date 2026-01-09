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
DOOMGENERIC_REPO="https://github.com/lmacken/doomgeneric-pager.git"
DOOMGENERIC_BRANCH="pager"
WAD_URL="https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad"

# Parse args
SKIP_DEPLOY=0
SKIP_RELEASE=0
DEPLOY_ONLY=0
USE_DEV_BRANCH=0
USE_LOCAL_SOURCE=0
SYNC_PAYLOADS=0
for arg in "$@"; do
    case $arg in
        --no-deploy) SKIP_DEPLOY=1 ;;
        --no-release) SKIP_RELEASE=1 ;;
        --deploy-only|--sync) DEPLOY_ONLY=1 ;;
        --dev) USE_DEV_BRANCH=1 ;;
        --local) USE_LOCAL_SOURCE=1 ;;
        --sync-payloads) SYNC_PAYLOADS=1 ;;
        --clean) rm -rf "$BUILD_DIR"; echo "Cleaned build dir"; exit 0 ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --no-deploy     Skip deploying to Pager"
            echo "  --no-release    Skip populating release directory"
            echo "  --deploy-only   Sync release files to Pager without building"
            echo "  --dev           Build from 'dev' branch (experimental)"
            echo "  --local         Build from local ./doomgeneric/ source"
            echo "  --sync-payloads Sync all payload.sh files to Pager"
            echo "  --clean         Remove build directory and exit"
            exit 0
            ;;
    esac
done

# Override settings based on build type
if [ "$USE_LOCAL_SOURCE" = "1" ]; then
    RELEASE_DIR="$SCRIPT_DIR/payloads/user/games/doom-local"
    RELEASE_DIR_DM=""  # No deathmatch for local builds
    echo "*** LOCAL BUILD - using ./doomgeneric/ ***"
elif [ "$USE_DEV_BRANCH" = "1" ]; then
    DOOMGENERIC_BRANCH="dev"
    RELEASE_DIR="$SCRIPT_DIR/payloads/user/games/doom-dev"
    RELEASE_DIR_DM=""  # No deathmatch for dev builds
    echo "*** DEV BUILD - using 'dev' branch ***"
fi

# Sync payloads mode: just sync payload.sh files
if [ "$SYNC_PAYLOADS" = "1" ]; then
    echo "Syncing all payload.sh files to $PAGER..."
    PAYLOADS_DIR="$SCRIPT_DIR/payloads/user/games"
    for dir in "$PAYLOADS_DIR"/doom* "$PAYLOADS_DIR"/doom2*; do
        if [ -d "$dir" ] && [ -f "$dir/payload.sh" ]; then
            name=$(basename "$dir")
            echo "  $name"
            ssh "$PAGER" "mkdir -p $DEST/$name" 2>/dev/null
            scp -q "$dir/payload.sh" "$PAGER:$DEST/$name/"
        fi
    done
    ssh "$PAGER" "chmod +x $DEST/*/payload.sh; ALERT '✅ Payloads synced!'" 2>/dev/null || true
    echo "Done!"
    exit 0
fi

# Deploy-only mode: just sync existing release files
if [ "$DEPLOY_ONLY" = "1" ]; then
    if [ "$USE_LOCAL_SOURCE" = "1" ]; then
        echo "Deploying LOCAL release files to $PAGER..."
        if [ ! -d "$RELEASE_DIR" ]; then
            echo "ERROR: doom-local directory not found. Run './build.sh --local' first."
            exit 1
        fi
        ssh "$PAGER" "mkdir -p $DEST/doom-local" 2>/dev/null || { echo "Cannot connect to $PAGER"; exit 1; }
        scp "$RELEASE_DIR"/* "$PAGER:$DEST/doom-local/"
        ssh "$PAGER" "chmod +x $DEST/doom-local/doomgeneric $DEST/doom-local/*.sh; ALERT '🎮 DOOM LOCAL synced!'" 2>/dev/null || true
        echo "Done! LOCAL synced to $PAGER:$DEST/doom-local/"
    elif [ "$USE_DEV_BRANCH" = "1" ]; then
        echo "Deploying DEV release files to $PAGER..."
        if [ ! -d "$RELEASE_DIR" ]; then
            echo "ERROR: doom-dev directory not found. Run './build.sh --dev' first."
            exit 1
        fi
        ssh "$PAGER" "mkdir -p $DEST/doom-dev" 2>/dev/null || { echo "Cannot connect to $PAGER"; exit 1; }
        scp "$RELEASE_DIR"/* "$PAGER:$DEST/doom-dev/"
        ssh "$PAGER" "chmod +x $DEST/doom-dev/doomgeneric $DEST/doom-dev/*.sh; ALERT '🎮 DOOM DEV synced!'" 2>/dev/null || true
        echo "Done! DEV synced to $PAGER:$DEST/doom-dev/"
    else
        echo "Deploying release files to $PAGER..."
        if [ ! -d "$RELEASE_DIR" ] || [ ! -d "$RELEASE_DIR_DM" ]; then
            echo "ERROR: Release directories not found. Run build first."
            exit 1
        fi
        ssh "$PAGER" "mkdir -p $DEST/doom $DEST/doom-deathmatch" 2>/dev/null || { echo "Cannot connect to $PAGER"; exit 1; }
        scp "$RELEASE_DIR"/* "$PAGER:$DEST/doom/"
        ssh "$PAGER" "chmod +x $DEST/doom/doomgeneric $DEST/doom/*.sh"
        scp "$RELEASE_DIR_DM/payload.sh" "$RELEASE_DIR_DM/SHA256SUMS" "$PAGER:$DEST/doom-deathmatch/"
        ssh "$PAGER" "cd $DEST/doom-deathmatch && rm -f doomgeneric doom1.wad && ln -s ../doom/doomgeneric . && ln -s ../doom/doom1.wad . && chmod +x *.sh; ALERT '🎮 DOOM synced!'" 2>/dev/null || true
        echo "Done! Synced to $PAGER:$DEST/"
    fi
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

# 2. Clone/update doomgeneric fork (skip if using local source)
if [ "$USE_LOCAL_SOURCE" = "1" ]; then
    echo "[2/6] Using local ./doomgeneric/ source"
    DOOMGENERIC_DIR="$SCRIPT_DIR/doomgeneric"
    if [ ! -d "$DOOMGENERIC_DIR/doomgeneric" ]; then
        echo "ERROR: Local doomgeneric directory not found at $DOOMGENERIC_DIR"
        exit 1
    fi
else
    DOOMGENERIC_DIR="$BUILD_DIR/doomgeneric"
    if [ ! -d "$BUILD_DIR/doomgeneric/.git" ]; then
        echo "[2/6] Cloning doomgeneric-pager..."
        rm -rf "$BUILD_DIR/doomgeneric"
        git clone -b "$DOOMGENERIC_BRANCH" --depth 1 "$DOOMGENERIC_REPO" "$BUILD_DIR/doomgeneric"
    else
        echo "[2/6] Updating doomgeneric-pager..."
        git -C "$BUILD_DIR/doomgeneric" fetch origin
        git -C "$BUILD_DIR/doomgeneric" checkout "$DOOMGENERIC_BRANCH"
        git -C "$BUILD_DIR/doomgeneric" reset --hard "origin/$DOOMGENERIC_BRANCH"
        git -C "$BUILD_DIR/doomgeneric" clean -fd
    fi
fi

# 3. Download WAD
WAD_PATH="$DOOMGENERIC_DIR/doomgeneric/doom1.wad"
if [ ! -f "$WAD_PATH" ]; then
    echo "[3/6] Downloading doom1.wad..."
    curl -L "$WAD_URL" -o "$WAD_PATH"
else
    echo "[3/6] WAD ready"
fi

# 4. Build
echo "[4/6] Building..."

export OPENWRT_SDK="$BUILD_DIR/openwrt-sdk"
make -C "$DOOMGENERIC_DIR/doomgeneric" -f Makefile.mipsel clean
make -C "$DOOMGENERIC_DIR/doomgeneric" -f Makefile.mipsel -j$(nproc)

BINARY="$DOOMGENERIC_DIR/doomgeneric/doomgeneric"
WAD="$DOOMGENERIC_DIR/doomgeneric/doom1.wad"

echo ""
echo "Build complete:"
ls -lh "$BINARY" "$WAD"

# 5. Populate release directories
if [ "$SKIP_RELEASE" = "0" ]; then
    echo ""
    echo "[5/6] Populating release directories..."
    mkdir -p "$RELEASE_DIR"
    
    # Main payload
    cp "$BINARY" "$RELEASE_DIR/"
    cp "$WAD" "$RELEASE_DIR/"
    
    # Use appropriate payload script
    if [ "$USE_DEV_BRANCH" = "1" ]; then
        # Dev build: create simple payload
        cat > "$RELEASE_DIR/payload.sh" << 'DEVPAYLOAD'
#!/bin/bash
# Title: DOOM DEV
# Description: Experimental DOOM build
# Author: @lmacken
# Version: dev
# Category: Games

PAYLOAD_DIR="/root/payloads/user/games/doom-dev"
cd "$PAYLOAD_DIR" || exit 1
chmod +x ./doomgeneric

LOG "DOOM DEV (experimental build)"
LOG "Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1

/etc/init.d/pineapplepager stop 2>/dev/null
/etc/init.d/pineapd stop 2>/dev/null
sleep 1

./doomgeneric -iwad "$PAYLOAD_DIR/doom1.wad" >/tmp/doom.log 2>&1

/etc/init.d/pineapplepager start 2>/dev/null &
/etc/init.d/pineapd start 2>/dev/null &
DEVPAYLOAD
    else
        cp "$SCRIPT_DIR/payload.sh" "$RELEASE_DIR/"
    fi
    chmod +x "$RELEASE_DIR/doomgeneric" "$RELEASE_DIR/payload.sh"
    (cd "$RELEASE_DIR" && sha256sum doomgeneric doom1.wad payload.sh > SHA256SUMS)
    
    echo ""
    echo "Release: $RELEASE_DIR"
    ls -lh "$RELEASE_DIR"
    
    # Deathmatch: doom-deathmatch/ (symlinks to ../doom/ to save space)
    # Skip for dev builds
    if [ -n "$RELEASE_DIR_DM" ]; then
        mkdir -p "$RELEASE_DIR_DM"
        rm -f "$RELEASE_DIR_DM/doomgeneric" "$RELEASE_DIR_DM/doom1.wad"
        ln -s ../doom/doomgeneric "$RELEASE_DIR_DM/doomgeneric"
        ln -s ../doom/doom1.wad "$RELEASE_DIR_DM/doom1.wad"
        sed 's|/user/games/doom"|/user/games/doom-deathmatch"|g' \
            "$SCRIPT_DIR/payload-deathmatch.sh" > "$RELEASE_DIR_DM/payload.sh"
        chmod +x "$RELEASE_DIR_DM/payload.sh"
        (cd "$RELEASE_DIR_DM" && sha256sum payload.sh > SHA256SUMS)
        echo ""
        echo "Release: $RELEASE_DIR_DM"
        ls -lh "$RELEASE_DIR_DM"
    fi
else
    echo ""
    echo "[5/6] Skipping release (--no-release)"
fi

# 6. Deploy to Pager
if [ "$SKIP_DEPLOY" = "0" ]; then
    echo ""
    echo "[6/6] Deploying to $PAGER..."
    
    if [ "$USE_LOCAL_SOURCE" = "1" ]; then
        # Local build: deploy to doom-local/
        ssh "$PAGER" "mkdir -p $DEST/doom-local" 2>/dev/null || { echo "Cannot connect to $PAGER"; exit 1; }
        scp "$RELEASE_DIR"/* "$PAGER:$DEST/doom-local/"
        ssh "$PAGER" "chmod +x $DEST/doom-local/doomgeneric $DEST/doom-local/*.sh; ALERT '🎮 DOOM LOCAL deployed!'" 2>/dev/null || true
        echo ""
        echo "========================================"
        echo "  LOCAL build deployed to DOOM LOCAL"
        echo "  in Payloads > Games menu"
        echo "========================================"
    elif [ "$USE_DEV_BRANCH" = "1" ]; then
        # Dev build: deploy to doom-dev/
        ssh "$PAGER" "mkdir -p $DEST/doom-dev" 2>/dev/null || { echo "Cannot connect to $PAGER"; exit 1; }
        scp "$RELEASE_DIR"/* "$PAGER:$DEST/doom-dev/"
        ssh "$PAGER" "chmod +x $DEST/doom-dev/doomgeneric $DEST/doom-dev/*.sh; ALERT '🎮 DOOM DEV deployed!'" 2>/dev/null || true
        echo ""
        echo "========================================"
        echo "  DEV build deployed to DOOM DEV"
        echo "  in Payloads > Games menu"
        echo "========================================"
    else
        # Normal build: deploy doom/ and doom-deathmatch/
        ssh "$PAGER" "mkdir -p $DEST/doom $DEST/doom-deathmatch" 2>/dev/null || { echo "Cannot connect to $PAGER (use --no-deploy to skip)"; exit 1; }
        scp "$RELEASE_DIR"/* "$PAGER:$DEST/doom/"
        ssh "$PAGER" "chmod +x $DEST/doom/doomgeneric $DEST/doom/*.sh"
        scp "$RELEASE_DIR_DM/payload.sh" "$RELEASE_DIR_DM/SHA256SUMS" "$PAGER:$DEST/doom-deathmatch/"
        ssh "$PAGER" "cd $DEST/doom-deathmatch && rm -f doomgeneric doom1.wad && ln -s ../doom/doomgeneric . && ln -s ../doom/doom1.wad . && chmod +x *.sh; ALERT '🎮 DOOM deployed!'" 2>/dev/null || true
        echo ""
        echo "========================================"
        echo "  Done! Find DOOM & DOOM Deathmatch"
        echo "  in the Payloads > Games menu"
        echo "========================================"
    fi
else
    echo ""
    echo "[6/6] Skipping deploy (--no-deploy)"
    echo ""
    echo "To deploy manually:"
    echo "  scp $RELEASE_DIR/* $PAGER:$DEST/doom/"
    echo "  scp $RELEASE_DIR_DM/payload.sh $RELEASE_DIR_DM/SHA256SUMS $PAGER:$DEST/doom-deathmatch/"
    echo "  ssh $PAGER \"cd $DEST/doom-deathmatch && ln -sf ../doom/doomgeneric . && ln -sf ../doom/doom1.wad .\""
fi
