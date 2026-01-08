# DOOM for WiFi Pineapple Pager

Play the classic 1993 FPS on your WiFi Pineapple Pager!

[![Darren Kitchen playing DOOM on the Pager](doomdarren.png)](https://www.youtube.com/live/Er7XwjwmfIU?si=CsJcLTFFy_HVQuCv&t=15302)
*Darren Kitchen demoing DOOM on the Pager — [watch the full video](https://www.youtube.com/live/Er7XwjwmfIU?si=CsJcLTFFy_HVQuCv&t=15302)*

## Quick Install

### Using Pull Payload PR

If you have the `general` → `Pull Payload PR` payload on your pager, type PR `130` to install.

### Manual Install

Copy the pre-built files to your Pager:

```bash
scp -r payloads/user/games/doom root@172.16.52.1:/root/payloads/user/games/
```

Then find DOOM in: **Payloads → User → Games → DOOM**

## Supported WADs

| | |
|:---:|:---:|
| ![Pager Menu](img/menu-1.png) | ![Games Menu](img/menu-2.png) |

**Bring your own WADs!** Only the shareware `doom1.wad` is included. Place your legally obtained WAD files in the `wads/` directory to play the full games.

### IWADs (Base Games)

| Game | WAD File | Status |
|------|----------|--------|
| DOOM Shareware | `doom1.wad` | ✅ Works |
| DOOM Registered | `doom.wad` | ✅ Works |
| DOOM II | `doom2.wad` | ✅ Works |
| Final DOOM: TNT | `tnt.wad` | ✅ Works |
| Final DOOM: Plutonia | `plutonia.wad` | ✅ Works |

| | |
|:---:|:---:|
| ![DOOM](img/doom.png) | ![DOOM II](img/doom2-1.png) |
| ![DOOM II](img/doom2-2.png) | ![Final DOOM: TNT](img/finaldoom-tnt-wad-1.png) |
| ![Final DOOM: Plutonia](img/finaldoom-wad-4.png) | |

### PWADs (Add-ons)

| Add-on | WAD File | Requires | Status |
|--------|----------|----------|--------|
| No Rest for the Living | `nerve.wad` | `doom2.wad` | ✅ Works |
| Master Levels | `masterlevels.wad` | `doom2.wad` | ✅ Works |
| SIGIL | `sigil.wad` | `doom.wad` | ✅ Works (Episode 3) |
| SIGIL II | `sigil2.wad` | `doom.wad` | ❌ Incompatible |

| | |
|:---:|:---:|
| ![SIGIL](img/sigil-wad-0.png) | ![SIGIL Gameplay](img/sigil-wad-6.png) |
| ![Master Levels](img/masterlevels-wad-1.png) | ![No Rest for the Living](img/doom2-wad-nrftl.png) |

### Installing Additional WADs

1. Place your WAD files in the `wads/` directory
2. Run the installer:

```bash
./install-wads.sh list      # Show available configurations
./install-wads.sh install   # Create payload directories
./install-wads.sh deploy    # Deploy to Pager via SSH
```

### WAD Compatibility Notes

- **SIGIL** uses the "compat" version which replaces Episode 3 (select Episode 3 in menu)
- **SIGIL II** is NOT compatible (requires UMAPINFO support)

## Controls

| Input | Action |
|-------|--------|
| D-pad | Move/Turn |
| Red | Fire |
| Green | Select (menus) |
| Green + Up | Open doors/Use |
| Green + Down | Automap |
| Green + Left/Right | Strafe |
| Red + Green | ESC (Menu/Quit) |

### USB Keyboard Support

External USB keyboards work alongside the Pager's built-in buttons. **Plug in your keyboard before launching the game** - input devices are detected at startup.

## Multiplayer Deathmatch

Connect to our public DOOM server for multiplayer deathmatch!

| | |
|:---:|:---:|
| ![Deathmatch Lobby](img/deathmatch.png) | ![Deathmatch Gameplay](img/deathmatch-1.png) |

Run the **DOOM Deathmatch** payload from: Payloads → User → Games

Desktop players can join with Chocolate Doom:
```bash
chocolate-doom -iwad doom1.wad -connect 64.227.99.100:2342
```

### Network Features
- Chocolate Doom 3.1.x protocol compatibility
- Works with vanilla Chocolate Doom server
- POSIX socket-based network layer (no SDL dependency)

## Build from Source

```bash
./build.sh
```

This will:
1. Download the OpenWrt SDK (~400MB, cached in `build/`)
2. Clone our [doomgeneric fork](https://github.com/lmacken/doomgeneric-pager) (`pager` branch)
3. Cross-compile for MIPS
4. Deploy to Pager (if connected)

For experimental builds, use `./build.sh --dev` which pulls from the `dev` branch and creates a separate `DOOM DEV` payload.

### Requirements

- Linux (tested on Ubuntu/Debian)
- `curl`, `git`, `make`
- `qemu-user-static` (on non-x86_64 hosts)

```bash
sudo apt install curl git make qemu-user-static
```

## Screenshots

Capture a screenshot from your Pager's framebuffer and save it locally:

```bash
./screenshot.sh                  # Landscape (default)
./screenshot.sh -n               # Portrait (raw framebuffer)
./screenshot.sh my_shot.png      # Custom filename
```

## Technical Details

- **CPU**: MIPS 24KEc @ 580MHz (soft-float)
- **Display**: 222×480 RGB565, rotated 90° CCW
- **Input**: GPIO buttons via `/dev/input/event0`

### Rendering Limits (Increased for SIGIL and Complex WADs)

The vanilla DOOM engine has hardcoded limits that can cause crashes on complex maps like SIGIL. These have been increased:

| Limit | Original | Modified |
|-------|----------|----------|
| MAXVISPLANES | 128 | 512 |
| MAXVISSPRITES | 128 | 256 |
| MAXDRAWSEGS | 256 | 512 |

### Engine Modifications

**Display**
- 16-bit RGB565 framebuffer support
- 90° CCW rotation for portrait display
- Full-screen stretched scaling with widened FOV (gameplay)
- Aspect-correct rendering with letterboxing (menus/title)
- Precomputed lookup tables for fast scaling

**Input**
- GPIO button mapping (red/green buttons)
- Button combo detection (ESC, Use, Strafe, Automap)

**Performance**
- MIPS 24KEc optimizations (`-march=24kec -mdsp -mbranch-likely`)
- 4-pixel loop unrolling in render loop
- Inline RGB888→RGB565 conversion macro
- Aggressive compiler flags (`-O3 -ffast-math -funroll-loops`)

## Files

```
├── build.sh              # Main build script
├── install-wads.sh       # WAD installer tool
├── screenshot.sh         # Pager screenshot utility
├── doomgeneric/          # Engine fork (github.com/lmacken/doomgeneric-pager)
├── wads/                 # Place your WAD files here
├── img/                  # Screenshots
├── ansible/              # Deathmatch server playbook
└── payloads/             # Pager payload directories
    └── user/games/
        ├── doom/              # Base DOOM (shareware)
        ├── doom-deathmatch/   # Multiplayer
        ├── doom2/             # DOOM II
        ├── doom-sigil/        # SIGIL
        └── ...
```

## Future Ideas

- Further rendering optimizations
- Vibrate when hit
- DOOM theme ringtone using the piezoelectric buzzer

## License

- DOOM source: GPL
- doom1.wad: Shareware (freely distributable)
