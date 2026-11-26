# Quickstart: validating "Move Workspaces Between Monitors"

## 1. Unit tests (no Hyprland needed)

From the `sekaipop` folder:

```sh
node tests/monitor-direction-test/monitor_direction_test.js
```

Expect it to pass. It runs the Lua unit test with the system `lua` (a dependency of the
`hyprland` package) over the layouts in [data-model.md](data-model.md) (one, two and three
monitors, a row, a stack, the owner's portrait + landscape desk offset vertically, a rotated and
a scaled monitor, a disabled monitor), and checks `keybinds.lua` binds the four keys with the
shared description, guarded by `pcall(require, ...)`.

## 2. Config loads cleanly

After installing (`./install.sh`, or copying `hypr/` over a test copy):

```sh
hyprctl reload
hyprctl configerrors                         # expect nothing new
tail -n 5 ~/.cache/sekaipop/hypr-errors.log  # expect no new lines about keybinds or monitor_direction
hyprctl binds -j | grep -c "Move workspace to monitor in direction"   # expect 4
```

## 3. On a real desk

Two monitors side by side (the owner's: portrait HDMI-A-2 on the left, DP-1 on the right):

| Step | Do | Expect |
| --- | --- | --- |
| 1 | Open two windows on a workspace on DP-1 | — |
| 2 | SUPER + ALT + Left | The workspace and both windows are on HDMI-A-2, shown and focused; DP-1 shows another workspace |
| 3 | SUPER + ALT + Left again | Wraps: back on DP-1 (two monitors: either direction swaps) |
| 4 | SUPER + ALT + Right | Back on HDMI-A-2 |
| 5 | SUPER + ALT + Up, then Down | Nothing happens (the two monitors are side by side) |
| 6 | Look at each monitor's bar | Its workspace pills list the workspaces now on that monitor |
| 7 | SUPER + / (cheat sheet) | One row in Workspaces: "Move workspace to monitor in direction", ←/↑/→/↓ |

## 4. Your own binding wins

In `~/.config/hypr/custom/keybinds.lua` add:

```lua
hl.unbind("SUPER + ALT + Left")
```

`hyprctl reload`; SUPER + ALT + Left now does nothing, the other three still work. Remove the line
to get it back.
