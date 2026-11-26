# Data Model: Move Workspaces Between Monitors

No stored data. The feature works on Hyprland's live monitor list each time a key is pressed.

## Monitor (input, as Hyprland reports it)

From `hl.get_monitors()`: `name`, `x`, `y`, `width`, `height`, `scale`, `transform`, `enabled`,
`focused`, `active_workspace` (has `id`).

Validation: a monitor with `enabled == false`, or missing `name` / `x` / `y` / `width` /
`height`, is ignored. `scale <= 0` is treated as 1.

## Rect (derived, logical layout space)

| Field | Rule |
| --- | --- |
| `name` | the monitor's name |
| `left`, `top` | `x`, `y` |
| `w`, `h` | `width`, `height`, swapped when `transform` is odd (1, 3, 5, 7), then divided by `scale` |
| `cx`, `cy` | `left + w/2`, `top + h/2` |

Example (owner's desk): `HDMI-A-2` (2560 × 1080, transform 3, at 0,0) → 1080 × 2560 at 0,0,
centre (540, 1280). `DP-1` (2560 × 1080, transform 0, at 1080,740) → 2560 × 1080, centre
(2360, 1280).

## Direction

`"l" | "r" | "u" | "d"` (Left, Right, Up, Down). Axis: `l`/`r` horizontal, `u`/`d` vertical.

## Picking the target (`pick(rects, current, dir) -> name | nil`)

1. **Beyond**: another monitor is in direction `dir` from the current one when its centre lies
   past the current monitor's edge on that side: Left `other.cx < cur.left`, Right
   `other.cx > cur.left + cur.w`, Up `other.cy < cur.top`, Down `other.cy > cur.top + cur.h`.
   (Side-by-side monitors at different heights are left/right of each other; a monitor is
   above/below only when its centre clears the current one's top/bottom edge.)
2. **Nearest**: among those, the smallest distance between centres along the axis; ties go to
   the smallest centre offset on the other axis, then to the name in alphabetical order (the
   same answer every time).
3. **Wrap**: if none is beyond in `dir`, take the monitors beyond in the opposite direction and
   pick the **farthest** along the axis (same tie rules).
4. **Nothing**: if neither side has one (one monitor, or Up/Down on a single row), return `nil`
   and the key does nothing.

The current monitor is never its own target.

## Outcomes for the spec's scenarios

| Layout | Current | Key | Target |
| --- | --- | --- | --- |
| A, B side by side | A (left) | Right | B |
| A, B side by side | A (left) | Left | B (wrap) |
| A, B, C in a row | A | Left | C (wrap, farthest) |
| A, B, C in a row | C | Right | A (wrap, farthest) |
| A, B, C in a row | B | Left | A (nearest) |
| E above L (stacked) | L | Up | E |
| E above L (stacked) | E | Up | L (wrap) |
| A, B in a row | A | Up / Down | nil |
| owner's desk (portrait HDMI-A-2 left, DP-1 right, offset 740 down) | DP-1 | Left | HDMI-A-2 |
| owner's desk | DP-1 | Up | nil (HDMI-A-2's centre is level, not above) |
| one monitor | it | any | nil |
