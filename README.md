# MonitorForgeX
Developed by X Project

MonitorForgeX is a small Bash utility for X11 setups using `xrandr` and i3wm (or any WM that reads Xresources).  
It automatically detects connected monitors, arranges them left-to-right in a predictable order, exports monitor names and resolutions into `~/.Xresources`, and provides a simple rotate command that also refreshes your exports.

This project contains:
- `monitorforgex.sh`

---

## What the script does

1. Detects all connected monitors via `xrandr`.
2. Sorts them in a stable order (internal panels first, then DP/DisplayPort, HDMI, DVI, VGA, TV).
3. Arranges monitors left-to-right using `--right-of`.
4. Sets a primary monitor.
   - Uses the current `xrandr` primary if present.
   - Otherwise uses `i3wm.primary_monitor` from `~/.Xresources` if present.
   - Otherwise falls back to the first monitor in sorted order.
5. Writes these keys into `~/.Xresources`:
   - `i3wm.primary_monitor: <NAME>`
   - `i3wm.primary_monitor_resx: <WIDTH>`
   - `i3wm.primary_monitor_resy: <HEIGHT>`
   - `i3wm.other_monitor_1: <NAME>`
   - `i3wm.other_monitor_1_resx: <WIDTH>`
   - `i3wm.other_monitor_1_resy: <HEIGHT>`
   - and so on for all other monitors
6. Loads the updated resources with `xrdb`.
7. Optionally refreshes wallpaper if `~/bin/xwallpaperauto.sh` exists.
8. Provides a rotate command:
   - Rotates a chosen monitor (left/right/normal/inverted).
   - If you rotate to the same direction twice, it toggles back to normal.
   - After rotation, it refreshes Xresources exports without re-arranging your layout.

---

## Requirements

Mandatory:
- `xrandr`
- `xrdb`
- `bash` 4+

Standard utilities:
- `awk`
- `sed`
- `grep`
- `sort`
- `realpath` (coreutils)

Optional:
- `~/bin/xwallpaperauto.sh`  
  If present and executable, this script is called after layout/rotation to refresh wallpapers.

---

## Installation

1. Save the script as `monitorforgex.sh`
2. Make it executable:
```bash
chmod +x monitorforgex.sh
```

3. Place it somewhere in your PATH (optional), for example:
```bash
mkdir -p ~/bin
cp monitorforgex.sh ~/bin/
```

---

## Usage

```bash
./monitorforgex.sh [flags] [command] [args]
```

### Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Print what would be executed, do not change anything |
| `--silent` | No normal output, only errors |

### Commands

| Command | Description |
|---------|-------------|
| `arrange` | Detect, order, and arrange monitors; export to Xresources (default) |
| `list` | Print connected monitor names |
| `rotate MON DIR` | Rotate monitor `MON` to `DIR` (left/right/normal/inverted). Toggles back to normal if already in that direction |
| `set-primary MON` | Make `MON` primary and refresh exports |
| `export-only` | Refresh Xresources exports without changing layout |

---

## Examples

Arrange monitors using defaults:
```bash
./monitorforgex.sh
# same as:
./monitorforgex.sh arrange
```

List connected monitors:
```bash
./monitorforgex.sh list
```

Rotate a monitor left:
```bash
./monitorforgex.sh rotate HDMI-1 left
```

Rotate and toggle back to normal:
```bash
./monitorforgex.sh rotate HDMI-1 left
./monitorforgex.sh rotate HDMI-1 left
```

Set primary monitor:
```bash
./monitorforgex.sh set-primary DP-1
```

Preview actions only:
```bash
./monitorforgex.sh --dry-run arrange
```

Export monitor variables without re-arranging:
```bash
./monitorforgex.sh export-only
```

---

## Notes

- This script is intended for X11 sessions (not Wayland).
- The ordering rules are simple and deterministic; you can adjust them inside the script if you want a different priority.
- The exports in `~/.Xresources` are designed to be used from i3 config or any other tooling you have.
- If a monitor has no active mode (rare), resolution keys may not be written for that monitor.

---

## Troubleshooting

1. No monitors detected
   - Run `xrandr --query` manually to confirm X is running and monitors are connected.

2. Xresources not updating
   - Ensure `xrdb` is installed and `~/.Xresources` is writable.
   - You can reload manually:
     ```bash
     xrdb ~/.Xresources
     ```

3. Wallpaper not refreshing
   - Only runs if `~/bin/xwallpaperauto.sh` exists and is executable.

---

## License and credits

MonitorForgeX is developed by X Project.  
You may use, modify, and distribute it freely in your own environment.

If you publish modifications, keeping this credit line is appreciated:
"Developed by X Project"
