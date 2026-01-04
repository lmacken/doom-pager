# Doom on WiFi Pineapple Pager

Play the classic 1993 FPS on your WiFi Pineapple Pager!

## Installation

See [INSTALL.md](INSTALL.md)

## Controls

| Input | Action |
|-------|--------|
| D-pad | Move/Turn |
| Red Button | Fire |
| Green Button | Select (menus) |
| Green + Up | Open doors/switches |
| Green + Down | Automap |
| Green + Left/Right | Strafe |
| Red + Green | Quit menu |

## Building from Source

Requires the OpenWrt SDK with musl toolchain (x86_64). On ARM64 hosts, use QEMU:

```bash
sudo apt install qemu-user-static
```

Build:

```bash
cd doomgeneric/doomgeneric
make -f Makefile.mipsel
```

Create package:

```bash
./build_package.sh
```

## Technical Details

- **Target**: mipsel_24kc (MIPS 24KEc, soft-float, musl libc)
- **Display**: 222x480 RGB565 framebuffer, rotated 90° CCW
- **Input**: GPIO buttons via evdev (`/dev/input/event0`)

## License

Doom source code is GPL. The included `doom1.wad` is the freely distributable shareware version (Episode 1: Knee-Deep in the Dead).
