# Doom on WiFi Pineapple Pager

This project cross-compiles Doom for the WiFi Pineapple Pager (MIPS architecture) using doomgeneric.

## Quick Start

**Want to install Doom on your Pager?** See [INSTALL.md](INSTALL.md) for installation instructions.

**Want to build Doom yourself?** Continue reading below.

## The Problem

The WiFi Pineapple Pager uses:
- **Architecture**: mipsel_24kc (MIPS 24KEc CPU)
- **libc**: musl with soft-float (musl-sf)
- **OS**: OpenWrt 24.10.1

Standard `mipsel-linux-gnu-gcc` cross-compilers produce glibc-based binaries that are incompatible with the device's musl environment, resulting in "Illegal instruction" errors.

## Solution: Use OpenWrt SDK

The correct approach is to use the OpenWrt SDK with musl toolchain. However, there's an architecture mismatch:
- **Host system**: aarch64 (ARM64)
- **OpenWrt SDK**: x86-64

## Options

### Option 1: Install QEMU (Recommended)

Install QEMU user-mode emulation to run the x86-64 OpenWrt SDK:

```bash
sudo apt-get install qemu-user-static
```

Then the build should work with the OpenWrt SDK toolchain.

### Option 2: Use x86-64 Build Machine

Build on an x86-64 machine where the OpenWrt SDK will work natively.

### Option 3: Download ARM64-Compatible SDK

Find or build an OpenWrt SDK for ARM64 host systems.

## Current Status

- ✅ Doom source cloned (doomgeneric)
- ✅ WAD file downloaded (doom1.wad)
- ✅ Makefile created for MIPS cross-compilation
- ✅ OpenWrt SDK with musl toolchain configured
- ✅ QEMU wrapper for x86-64 SDK on ARM64 host
- ✅ GPIO button support implemented
- ✅ Successfully cross-compiled and running on device

## Files

- `doomgeneric/doomgeneric/` - Doom source code
- `doomgeneric/doomgeneric/Makefile.mipsel` - MIPS cross-compilation Makefile
- `build_package.sh` - Build script to create installable package (does NOT include WAD files)
- `transfer_doom.sh` - Quick transfer script for development
- `INSTALL.md` - Installation guide for end users
- `openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64/` - OpenWrt SDK

**Note**: WAD files are NOT distributed with this package. Users must provide their own WAD files (see INSTALL.md for legal options including Freedoom).

## GPIO Button Support

The code now supports GPIO buttons on embedded devices. Button mappings:

- **Green Button (BTN_1)**: Select/Confirm (ENTER) - Use in menus
- **Red Button (BTN_0)**: Fire weapon (CTRL) - Shoot in-game
- **Volume Up/Down**: Move forward/backward
- **Power/Back**: Escape/Menu
- **Home/Select/OK**: Use/Open doors
- **Menu**: Map/Status (TAB)
- **Search**: Fire weapon
- **Arrow keys**: Turn left/right, move forward/backward

The input system will automatically detect and accept any device with key events, including GPIO buttons.

## Building and Deploying

### Building a Package for Distribution

To create an installable package:

```bash
./build_package.sh
```

This will create `package/doom-pager.tar.gz` that can be extracted to `/root/games/doom` on the device.

### Building for Development

1. **Build Doom**:
   ```bash
   cd doomgeneric/doomgeneric
   make -f Makefile.mipsel clean
   make -f Makefile.mipsel
   ```

2. **Transfer to device** (when USB keyboard is NOT connected):
   ```bash
   ./transfer_doom.sh
   ```

3. **Run on device**:
   ```bash
   ssh root@172.16.52.1
   cd /tmp/doom
   ./doomgeneric -iwad doom1.wad
   ```

**Note**: USB keyboard breaks the USB ethernet bridge, so use GPIO buttons for input instead.
