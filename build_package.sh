#!/bin/bash
# Build Doom package for WiFi Pineapple Pager
# Creates a tarball that can be extracted to /root/games/doom on the device

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOOM_DIR="${SCRIPT_DIR}/doomgeneric/doomgeneric"
PACKAGE_NAME="doom-pager"
VERSION="1.0"
OUTPUT_DIR="${SCRIPT_DIR}/package"
PACKAGE_DIR="${OUTPUT_DIR}/${PACKAGE_NAME}"
TARBALL="${OUTPUT_DIR}/${PACKAGE_NAME}.tar.gz"

echo "=== Building Doom Package for WiFi Pineapple Pager ==="
echo ""

# Check if we're in the right directory
if [ ! -d "${DOOM_DIR}" ]; then
    echo "ERROR: Doom source directory not found: ${DOOM_DIR}"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Check for OpenWrt SDK
if [ ! -d "${SCRIPT_DIR}/openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64" ]; then
    echo "ERROR: OpenWrt SDK not found!"
    echo "Please download and extract the OpenWrt SDK to:"
    echo "  ${SCRIPT_DIR}/openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64"
    exit 1
fi

# Check for QEMU (if on non-x86_64 host)
if ! uname -m | grep -q "x86_64"; then
    if ! command -v qemu-x86_64 &> /dev/null; then
        echo "WARNING: qemu-x86_64 not found. You may need to install qemu-user-static"
        echo "  sudo apt-get install qemu-user-static"
    fi
fi

# Build Doom
echo "Step 1: Building Doom binary..."
cd "${DOOM_DIR}"

# Clean previous build
echo "  Cleaning previous build..."
make -f Makefile.mipsel clean || true

# Build
echo "  Compiling..."
make -f Makefile.mipsel

if [ ! -f "${DOOM_DIR}/doomgeneric" ]; then
    echo "ERROR: Build failed! Binary not found."
    exit 1
fi

echo "  Build successful!"
ls -lh "${DOOM_DIR}/doomgeneric"
echo ""

# WAD files are NOT included in the package for legal reasons
# Users must provide their own WAD files (doom1.wad, doom.wad, doom2.wad, etc.)
# or use free alternatives like Freedoom
echo "Note: WAD files are not included in the package."
echo "Users must provide their own WAD files. See INSTALL.md for details."
WAD_FILE=""

# Create package directory
echo "Step 2: Creating package structure..."
rm -rf "${OUTPUT_DIR}"
mkdir -p "${PACKAGE_DIR}"

# Copy files
echo "  Copying binary..."
cp "${DOOM_DIR}/doomgeneric" "${PACKAGE_DIR}/"

# Copy payload.sh if it exists
if [ -f "${SCRIPT_DIR}/payload.sh" ]; then
    echo "  Copying payload.sh..."
    cp "${SCRIPT_DIR}/payload.sh" "${PACKAGE_DIR}/"
    chmod +x "${PACKAGE_DIR}/payload.sh"
else
    echo "  WARNING: payload.sh not found - creating default..."
    # Create a basic payload.sh
    cat > "${PACKAGE_DIR}/payload.sh" << 'PAYLOAD_EOF'
#!/bin/bash
# Title: Doom
# Description: Play the classic Doom game on your WiFi Pineapple Pager!
# Author: Doom Port for WiFi Pineapple Pager
# Version: 1.0
# Category: Games

PAYLOAD_EOF
    # Append the rest of the payload script
    cat >> "${PACKAGE_DIR}/payload.sh" << 'PAYLOAD_EOF'
PAYLOAD_DIR="$(dirname "$0")"
cd "$PAYLOAD_DIR"

if [ ! -f "./doomgeneric" ]; then
    LOG red "ERROR: doomgeneric binary not found!"
    exit 1
fi

chmod +x ./doomgeneric 2>/dev/null

WAD_FILE=""
for wad in freedoom1.wad freedoom2.wad doom1.wad doom.wad doom2.wad; do
    [ -f "$wad" ] && { WAD_FILE="$wad"; break; }
done

[ -z "$WAD_FILE" ] && {
    LOG red "ERROR: No WAD file found! Place a WAD file in this directory."
    WAIT_FOR_INPUT >/dev/null 2>&1
    exit 1
}

LOG green "Starting Doom with $WAD_FILE..."
WAIT_FOR_INPUT >/dev/null 2>&1
clear
./doomgeneric -iwad "$WAD_FILE" 2>&1
LOG "Doom exited. Press any button..."
WAIT_FOR_INPUT >/dev/null 2>&1
PAYLOAD_EOF
    chmod +x "${PACKAGE_DIR}/payload.sh"
fi

# WAD files are not included - users must provide their own

# Create README for the package
echo "  Creating README..."
cat > "${PACKAGE_DIR}/README.md" << 'EOF'
# Doom on WiFi Pineapple Pager

## Quick Start

1. Extract this package to `/root/payloads/user/games/doom-pager`:
   ```bash
   mkdir -p /root/payloads/user/games
   cd /root/payloads/user/games
   tar -xzf doom-pager.tar.gz
   # If needed, rename the directory to 'doom-pager'
   ```

2. **Provide a WAD file** (this package does not include WAD files):
   - Place your WAD file (doom1.wad, doom.wad, doom2.wad, etc.) in `/root/games/doom/`
   - Or use Freedoom (free alternative): https://freedoom.github.io/
   - See INSTALL.md for more information

3. Run Doom from the Payloads menu:
   - Navigate to: Payloads > User > Games > Doom
   - Or run from command line: `cd /root/payloads/user/games/doom-pager && ./doomgeneric -iwad <wad-file>`

## Controls

- **Green Button**: Select/Confirm (ENTER) - Use in menus
- **Red Button**: Fire weapon (CTRL) - Shoot in-game
- **Arrow Keys**: Move and turn (if USB keyboard connected)

**Note**: USB keyboard will break the USB ethernet bridge, so use GPIO buttons for input.

## WAD Files

**This package does NOT include WAD files.** You must provide your own WAD file.

**Recommended**: Use Freedoom (free, open-source):
- Download from: https://freedoom.github.io/
- Place freedoom1.wad or freedoom2.wad in this directory

**Alternative**: Use your own Doom WAD file if you own the game.

See INSTALL.md for more information.

## Troubleshooting

- If you get "Illegal instruction", make sure you're using the correct binary
- If buttons don't work, check `/dev/input/event0` exists
- If screen is blank, check `/dev/fb0` exists and has proper permissions
- If you get "WAD file not found", make sure you've placed a WAD file in this directory

For more information, see INSTALL.md in the package.
EOF

# Copy INSTALL.md
if [ -f "${SCRIPT_DIR}/INSTALL.md" ]; then
    cp "${SCRIPT_DIR}/INSTALL.md" "${PACKAGE_DIR}/"
fi

# Create a simple launcher script (optional)
cat > "${PACKAGE_DIR}/run.sh" << 'EOF'
#!/bin/sh
# Simple launcher script for Doom
# Automatically finds WAD files in the current directory

cd "$(dirname "$0")"

# Try to find a WAD file
WAD_FILE=""
for wad in freedoom1.wad freedoom2.wad doom1.wad doom.wad doom2.wad; do
    if [ -f "$wad" ]; then
        WAD_FILE="$wad"
        break
    fi
done

if [ -z "$WAD_FILE" ]; then
    echo "ERROR: No WAD file found!"
    echo ""
    echo "Please place a WAD file in this directory. Options:"
    echo "  - freedoom1.wad or freedoom2.wad (free, from https://freedoom.github.io/)"
    echo "  - doom1.wad, doom.wad, or doom2.wad (if you own Doom)"
    echo ""
    echo "Or specify a WAD file manually:"
    echo "  ./doomgeneric -iwad <path-to-wad-file>"
    exit 1
fi

echo "Using WAD file: $WAD_FILE"
./doomgeneric -iwad "$WAD_FILE" "$@"
EOF
chmod +x "${PACKAGE_DIR}/run.sh"

# Create tarball
echo "Step 3: Creating tarball..."
cd "${OUTPUT_DIR}"
tar -czf "${TARBALL}" "${PACKAGE_NAME}"

# Calculate checksum
if command -v sha256sum &> /dev/null; then
    SHA256=$(sha256sum "${TARBALL}" | cut -d' ' -f1)
    echo "${SHA256}  $(basename "${TARBALL}")" > "${TARBALL}.sha256"
    echo "  SHA256: ${SHA256}"
elif command -v shasum &> /dev/null; then
    SHA256=$(shasum -a 256 "${TARBALL}" | cut -d' ' -f1)
    echo "${SHA256}  $(basename "${TARBALL}")" > "${TARBALL}.sha256"
    echo "  SHA256: ${SHA256}"
fi

# Show package info
echo ""
echo "=== Package Created Successfully! ==="
echo ""
echo "Package location: ${TARBALL}"
echo "Package size: $(du -h "${TARBALL}" | cut -f1)"
echo ""
echo "Package contents:"
tar -tzf "${TARBALL}" | sed 's/^/  /'
echo ""
echo "To install on your Pager:"
echo "  1. scp ${TARBALL} root@172.16.52.1:/tmp/"
echo "  2. ssh root@172.16.52.1"
echo "  3. mkdir -p /root/payloads/user/games && cd /root/payloads/user/games"
echo "  4. tar -xzf /tmp/$(basename "${TARBALL}")"
echo "  5. Rename the extracted directory to 'doom-pager' (if needed)"
echo "  6. Provide a WAD file in the doom-pager directory (see INSTALL.md for options)"
echo "  7. Doom will appear in the Payloads menu under Games > Doom"
echo ""
echo "IMPORTANT: This package does NOT include WAD files."
echo "Users must provide their own WAD files (Freedoom recommended)."
echo ""

