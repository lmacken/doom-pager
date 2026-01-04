# DOOM for WiFi Pineapple Pager

Play the classic 1993 FPS on your WiFi Pineapple Pager!

![DOOM on Pager](docs/screenshot.png)

## Quick Install

Copy the pre-built files from `payloads/` to your Pager:

```bash
scp -r payloads/user/games/doom root@172.16.52.1:/root/payloads/user/games/
```

Then find DOOM in: **Payloads → User → Games → DOOM**

## Build from Source

```bash
./build.sh
```

This will:
1. Download the OpenWrt SDK (~400MB, cached in `build/`)
2. Clone doomgeneric
3. Apply our patches
4. Cross-compile for MIPS
5. Output to `release/` with SHA256 checksums

### Requirements

- Linux (tested on Ubuntu/Debian)
- `curl`, `git`, `make`
- `qemu-user-static` (on non-x86_64 hosts)

```bash
sudo apt install curl git make qemu-user-static
```

## Verify Build

Compare your build against the release checksums:

```bash
cd release/
cat SHA256SUMS
sha256sum -c SHA256SUMS
```

## Controls

| Input | Action |
|-------|--------|
| D-pad | Move/Turn |
| Red | Fire |
| Green | Select (menus) |
| Green + Up | Open doors |
| Green + Down | Automap |
| Green + Left/Right | Strafe |
| Red + Green | Quit |

## Technical Details

- **CPU**: MIPS 24KEc @ 580MHz (soft-float)
- **Display**: 222×480 RGB565, rotated 90° CCW
- **Input**: GPIO buttons via `/dev/input/event0`

## Files

```
├── build.sh           # Build script
├── patches/           # Patches for doomgeneric
├── payload.sh         # Launcher script
├── doom1.wad          # Shareware WAD (Episode 1)
└── payloads/          # Ready for Hak5 payloads repo PR
    └── user/games/doom/
```

## License

- DOOM source: GPL
- doom1.wad: Shareware (freely distributable)
