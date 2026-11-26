# Research: Move Workspaces Between Monitors

All findings were verified on the owner's machine (Hyprland 0.57.2, Lua config) on 2026-11-26.
Probes were read-only: dispatchers were built but never passed to `hl.dispatch`.

## R1. How to move the current workspace to a monitor (Lua config)

- **Decision**: `hl.dispatch(hl.dsp.workspace.move({ workspace = <id>, monitor = <name> }))`.
- **Rationale**: The wiki's dispatcher table lists `workspace.move({ workspace?, monitor })`
  ("Move a workspace to a monitor"). A live probe confirmed it builds an `HL.Dispatcher` and
  that `monitor` is required (`hl.workspace.move: 'monitor' is required`). Passing `workspace`
  explicitly (the focused monitor's regular active workspace) means a focused special
  (scratchpad) workspace is never what moves (spec edge case).
- **Alternatives considered**: hyprlang `movecurrentworkspacetomonitor` through
  `hyprctl dispatch` from a script (works in both config formats, but spawns processes and puts
  window management in a script, unlike every sibling bind); `workspace.swap_monitors` (swaps
  the two monitors' workspaces, which is not what the spec asks).

## R2. Does focus follow the moved workspace?

- **Decision**: Dispatch `hl.dsp.focus({ monitor = <target> })` right after the move.
- **Rationale**: The documentation does not say whether focus follows. Focusing the target
  monitor afterwards guarantees FR-004 either way and is a no-op if focus already followed.
  The probe confirmed `hl.dsp.focus({ monitor = ... })` exists in 0.57.
- **Alternatives considered**: relying on default behaviour (undocumented, could change);
  `window.move` with `follow` (moves one window, not the workspace).

## R3. Can Hyprland's own monitor directions do the wrap-around?

- **Decision**: No; pick the target monitor ourselves and pass its name.
- **Rationale**: Hyprland's directional monitor lookup is documented without wrap-around, and
  relative selectors (`+1` / `-1`) cycle by monitor ID, not by position (connection order, not
  layout). The spec needs position-based direction (FR-002) and wrap-around (FR-005).
- **Alternatives considered**: `monitor = "l"` (no wrap; at the left edge nothing happens);
  `monitor = "+1"` (wraps, but in ID order, which is wrong on the owner's desk where the left
  monitor is not ID 0).

## R4. Which monitor geometry to use

- **Decision**: Read `hl.get_monitors()` and turn each into a logical rectangle: swap
  width/height when `transform` is odd (90°/270°, flipped or not), then divide by `scale`;
  `x`/`y` are already layout positions.
- **Rationale**: The probe showed `width`/`height` are the physical mode: the owner's portrait
  monitor reports `w=2560 h=1080 transform=3` while it occupies 1080 × 2560 in the layout
  (`x=0 y=0`, the landscape monitor starts at `x=1080`). Without the swap, the portrait monitor
  would wrongly overlap its neighbour.
- **Alternatives considered**: `hyprctl monitors -j` from a script (same numbers, needs a
  process and a JSON parser); `hl.get_monitor_at(x, y)` stepping across the layout (cannot do
  wrap-around or nearest-of-several cleanly).

## R5. Where the direction logic lives, and how it is tested

- **Decision**: A pure Lua module `hypr/hyprland/lib/monitor_direction.lua` (no `hl.*` calls:
  plain tables in, a monitor name out), required by `keybinds.lua`. It is unit-tested with the
  system `lua` interpreter, driven from a node test in the repository suite.
- **Rationale**: Constitution IV requires tests for every integration and logic in pure,
  testable units. `lua` (5.5) is a hard dependency of the `hyprland` package itself
  (`pacman -Qi lua`: "Required By: hyprland"), so the test needs nothing new. The suite's
  runner is node, and existing tests already spawn other programs (`spawnSync`), so a node test
  that runs the Lua test keeps one way to run everything.
- **Alternatives considered**: logic inline in `keybinds.lua` (not testable without Hyprland);
  a shell script with `jq` (testable, but splits window management into a script and adds a
  process per press).

## R6. The keybinds panel (spec FR-008)

- **Decision**: The bindings appear in the cheat sheet (and are rebindable in
  `custom/keybinds.lua`), like every other window and workspace bind. They are **not** added to
  Settings > Hyprland > Keybinds.
- **Rationale**: That panel (`modules/common/functions/KeyBinds.js`, `ACTIONS`) manages only
  SekaiPop's shell actions (groups Shell, Utilities, Media, Session) and re-creates a rebound
  action from a shell command. Window and workspace binds (SUPER + arrows, SUPER + SHIFT +
  arrows, Send to workspace #) are not in it, and a Lua function bind has no command to
  re-create. Adding it would mean extending the panel to a new kind of action, against
  Constitution II (follow the existing pattern). The spec's FR-008 and SC-005 are amended to
  match (see the spec's FR-008 note).
- **Alternatives considered**: turning the bind into a shell command so the panel can rebind it
  (rejected with R1 and R5); extending the panel with a Workspaces group (scope creep).

## R7. Cheat sheet grouping

- **Decision**: One description for all four keys: `"Workspaces: Move workspace to monitor in
  direction"`, bound in a loop like the existing arrow sets.
- **Rationale**: The cheat sheet reads binds back from Hyprland and, since Lua binds report as
  `__lua`, knows them only by their "Group: sentence" description; binds with the same group,
  modifiers and sentence fold into one row with ←/↑/→/↓ (`CheatBinds.js`, `joinArrows`).
- **Alternatives considered**: four descriptions (four rows instead of one).

## R8. Safety of the default config

- **Decision**: `keybinds.lua` requires the module with `pcall(require, ...)` and binds the four
  keys only if it loaded.
- **Rationale**: `keybinds.lua` is loaded as one unit (`hyprland.lua` `load()`); an error in it
  would drop every keybind after that point. A missing or broken module must cost only these
  four binds.

## R9. Install and update

- **Decision**: No installer change. The new module is a new shipped file; `keybinds.lua` is a
  changed shipped file. The installer's edit-preserving merge (install.sh `keep_your_edits`)
  installs the new file and merges `keybinds.lua` with any user edits.
- **Rationale**: Covers FR-010 with the existing mechanism. User bindings in
  `custom/keybinds.lua` load after the defaults, so a user binding of the same keys wins.
- **Not a big migration** (Constitution III): no user file is moved, renamed or converted.
