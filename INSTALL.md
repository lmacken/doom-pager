# Installing Doom on WiFi Pineapple Pager

## Quick Install

1. **Transfer the package**:
   ```bash
   scp doom-pager.tar.gz root@172.16.52.1:/tmp/
   ```

2. **Install on Pager**:
   ```bash
   ssh root@172.16.52.1
   mkdir -p /root/payloads/user/games
   cd /root/payloads/user/games
   tar -xzf /tmp/doom-pager.tar.gz
   ```

3. **Play**: Navigate to Payloads → User → Games → Doom

## What's Included

- `doomgeneric` - Doom binary (statically linked for MIPS)
- `doom1.wad` - Shareware episode (freely distributable)
- `payload.sh` - Launcher script

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

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Illegal instruction" | Wrong binary - must be MIPS musl build |
| Blank screen | Check `/dev/fb0` exists |
| No button response | Check `/dev/input/event0` exists |

## Full Game

The included `doom1.wad` is Episode 1. For the full game:
- Place `doom.wad` or `doom2.wad` in the doom-pager directory
- Or use [Freedoom](https://freedoom.github.io/) (free, open-source)
