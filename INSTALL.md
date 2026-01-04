# Installing Doom on WiFi Pineapple Pager

This guide will help you install and run Doom on your WiFi Pineapple Pager.

## Prerequisites

- WiFi Pineapple Pager with SSH access
- A pre-built Doom package (tarball) or build environment

## Quick Installation (Using Pre-built Package)

**Note**: This package is designed to be installed in `/root/payloads/user/games/doom-pager` so it appears in the Payloads menu.

1. **Download the Doom package**:
   ```bash
   # On your computer, download the doom-pager.tar.gz file
   ```

2. **Transfer to your Pager**:
   ```bash
   # Replace 172.16.52.1 with your Pager's IP address
   scp doom-pager.tar.gz root@172.16.52.1:/tmp/
   ```

3. **SSH into your Pager**:
   ```bash
   ssh root@172.16.52.1
   ```

4. **Extract and install**:
   ```bash
   # Create payloads games directory if it doesn't exist
   mkdir -p /root/payloads/user/games
   
   # Extract the package
   cd /root/payloads/user/games
   tar -xzf /tmp/doom-pager.tar.gz
   
   # If the directory name is different, rename it to 'doom-pager'
   # (The package extracts as 'doom-pager' by default)
   
   # Make sure payload.sh is executable
   chmod +x doom-pager/payload.sh
   chmod +x doom-pager/doomgeneric
   ```

5. **Provide a WAD file** (this package does not include WAD files):
   ```bash
   # You need to provide your own WAD file. Options:
   # 
   # Option 1: Use Freedoom (free, open-source alternative)
   #   Download from: https://freedoom.github.io/
   #   Place freedoom1.wad or freedoom2.wad in /root/games/doom/
   #
   # Option 2: Use your own Doom WAD file
   #   If you own Doom, copy your doom1.wad, doom.wad, or doom2.wad
   #   to /root/games/doom/
   #
   # Option 3: Download shareware version (for personal use)
   #   Search for "doom shareware" - you'll need to find a legal source
   ```

6. **Run Doom**:
   
   **Option A: Use the Payloads Menu (Recommended)**
   - Navigate to: Payloads > User > Games > Doom
   - The game will start automatically
   
   **Option B: Run from command line**
   ```bash
   cd /root/payloads/user/games/doom-pager
   ./doomgeneric -iwad doom1.wad
   # Or use your WAD file name:
   # ./doomgeneric -iwad doom.wad
   # ./doomgeneric -iwad doom2.wad
   # ./doomgeneric -iwad freedoom1.wad
   ```

## Button Controls

The WiFi Pineapple Pager buttons are mapped as follows:

- **Green Button (BTN_1)**: Select/Confirm (ENTER) - Use in menus
- **Red Button (BTN_0)**: Fire weapon (CTRL) - Shoot in-game
- **Arrow Keys** (if USB keyboard connected): Move and turn
- **Volume Up/Down**: Move forward/backward
- **Power/Back**: Escape/Menu
- **Home/Select/OK**: Use/Open doors
- **Menu**: Map/Status (TAB)
- **Search**: Fire weapon

**Note**: USB keyboard will break the USB ethernet bridge, so use GPIO buttons for input.

## Troubleshooting

### "Illegal instruction" error
- Make sure you're using the correct binary compiled for MIPS with musl libc
- The binary must be statically linked

### "cannot execute binary file: Exec format error"
- The binary is not for the correct architecture (must be mipsel_24kc)
- Make sure you downloaded the correct package

### Screen is blank or distorted
- Make sure the framebuffer device exists: `ls -l /dev/fb0`
- Check framebuffer permissions: `ls -l /dev/fb0` should show read/write access

### Buttons don't work
- Check input device: `ls -l /dev/input/event*`
- The code automatically detects GPIO buttons from `/dev/input/event0`

### Game runs but is slow
- This is normal - the MIPS CPU is not very powerful
- The game should be playable, but may have lower frame rates

## Building from Source

If you want to build Doom yourself, see the main [README.md](README.md) for build instructions.

## Files Included

- `doomgeneric` - The Doom executable (statically linked for MIPS)
- `README.md` - Quick start guide
- `INSTALL.md` - This file

**Note**: WAD files are NOT included. You must provide your own WAD file. See step 5 above for options.

## WAD Files and Legal Information

**This package does NOT include WAD files** due to copyright restrictions. WAD files are copyrighted by id Software.

### Legal Options for WAD Files:

1. **Freedoom** (Recommended - Free and Open Source):
   - Download from: https://freedoom.github.io/
   - Freedoom provides free, open-source replacements for Doom WAD files
   - Licensed under BSD 3-Clause - fully legal to use and distribute
   - Works with all Doom source ports

2. **Purchase Doom**:
   - Buy Doom from authorized retailers (Steam, GOG, etc.)
   - Extract the WAD files from your purchased copy
   - Use your legally obtained WAD files

3. **Shareware Version** (Personal Use Only):
   - The original Doom shareware was freely distributable
   - However, redistributing it today may have legal restrictions
   - Users must obtain it from a legal source themselves

### License

The doomgeneric port is free software, covered by the GNU General Public License.

WAD files are separate and subject to their own copyright and licensing terms.

## Support

For issues or questions:
- Check the main [README.md](README.md) for technical details
- Report issues on the project repository
- Make sure you're using the latest version of the package

