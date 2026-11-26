# Contract: Workspace-to-monitor keybindings

Two interfaces: what the user (and the shell's cheat sheet) sees, and the Lua module the
keybinds call, which the tests exercise.

## 1. User-facing bindings (default Hyprland config)

| Keys | Action |
| --- | --- |
| SUPER + ALT + Left | Move the current workspace to the monitor on the left (wraps to the rightmost) |
| SUPER + ALT + Right | Move it to the monitor on the right (wraps to the leftmost) |
| SUPER + ALT + Up | Move it to the monitor above (wraps to the bottommost) |
| SUPER + ALT + Down | Move it to the monitor below (wraps to the topmost) |

- Description on all four (exact text; the cheat sheet groups by it and folds the arrows into
  one row): `Workspaces: Move workspace to monitor in direction`
- After a move, the moved workspace is the visible one on the target monitor and has focus.
- No target (one monitor; Up/Down on a single row): nothing happens.
- Rebinding: in `~/.config/hypr/custom/keybinds.lua`, which loads after the defaults, e.g.
  `hl.unbind("SUPER + ALT + Left")` then bind your own keys. Not in Settings > Keybinds (see
  research R6).
- These keys are unused by every other default binding (SUPER + arrows focus windows,
  SUPER + SHIFT + arrows move windows).

## 2. Lua module `hyprland.lib.monitor_direction`

File: `hypr/hyprland/lib/monitor_direction.lua`. Pure: uses no `hl.*`, no I/O, so it runs in
plain `lua`. Returns a table:

### `rects(monitors) -> Rect[]`

- `monitors`: a list of tables shaped like `hl.get_monitors()` entries (`name`, `x`, `y`,
  `width`, `height`, `scale`, `transform`, `enabled`).
- Returns logical rectangles (`name`, `left`, `top`, `w`, `h`, `cx`, `cy`) per
  [data-model.md](../data-model.md); disabled or incomplete monitors are left out.

### `pick(rects, current, dir) -> string | nil`

- `rects`: the result of `rects()`.
- `current`: the focused monitor's name.
- `dir`: `"l"`, `"r"`, `"u"` or `"d"`; anything else returns `nil`.
- Returns the target monitor's name, or `nil` for "do nothing". Never returns `current`.
  Rules: [data-model.md](../data-model.md), "Picking the target".

### `target(monitors, current, dir) -> string | nil`

- `pick(rects(monitors), current, dir)`, the one call `keybinds.lua` makes.

## 3. Keybind behaviour (in `keybinds.lua`)

On a press of SUPER + ALT + arrow `dir`:

1. Read the focused monitor (`hl.get_active_monitor()`) and its regular active workspace.
2. `target = monitor_direction.target(hl.get_monitors(), focused.name, dir)`.
3. If `target` is `nil`: return.
4. `hl.dispatch(hl.dsp.workspace.move({ workspace = <active id>, monitor = target }))`, then
   `hl.dispatch(hl.dsp.focus({ monitor = target }))`.

If the module fails to load, the four keys are not bound and every other bind still works.
