# Feature Specification: Move Workspaces Between Monitors

**Feature Branch**: `001-workspace-monitor-keybinds`

**Created**: 2026-11-26

**Status**: Draft

**Input**: User description: "Add to the default hyprland config new keybinds for moving
workspaces between monitors. SUPER + ALT + ARROW_KEYS: Move from monitor to monitor (The
direction selected is the direction of the monitor configured, if it's already in the left
monitor and pressing left then it cycles to the rightmost monitor.)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send the current workspace to the monitor beside it (Priority: P1)

On a desk with two or more monitors side by side, the user is working in a workspace on one
monitor and wants that whole workspace, with all its windows, on the monitor to its left or
right. They press SUPER + ALT + Left (or Right). The workspace leaves the current monitor and
appears on the neighbouring monitor in that direction, as that monitor's active workspace, and
the user's focus goes with it.

**Why this priority**: This is the whole feature for the common case (monitors in a row, like
the owner's portrait monitor beside a landscape one). Without it nothing else matters.

**Independent Test**: With two monitors side by side, open a few windows on a workspace on the
left monitor, press SUPER + ALT + Right, and check that the workspace and its windows are now on
the right monitor, shown, and focused.

**Acceptance Scenarios**:

1. **Given** two monitors side by side and a workspace with windows active on the left one,
   **When** the user presses SUPER + ALT + Right, **Then** that workspace, with every window in
   it, is shown on the right monitor and keyboard focus is on it.
2. **Given** the same workspace now on the right monitor, **When** the user presses
   SUPER + ALT + Left, **Then** it returns to the left monitor, shown and focused.
3. **Given** a workspace moved away from a monitor, **When** the move completes, **Then** the
   monitor it left still shows a workspace (another existing one, or an empty one), never
   nothing.
4. **Given** a workspace moved to another monitor, **When** the user looks at the shell's bar on
   each monitor, **Then** each bar's workspace pills show the workspaces now on its own monitor.

---

### User Story 2 - Wrap around at the edge of the monitor layout (Priority: P2)

The user is on the leftmost monitor and presses SUPER + ALT + Left. Instead of nothing
happening, the workspace goes round to the rightmost monitor. Likewise Right on the rightmost
monitor goes to the leftmost one. With only two monitors, Left and Right both simply send the
workspace to the other monitor.

**Why this priority**: The owner asked for this cycling explicitly; it makes the key always do
something useful. It builds on Story 1 and can be shipped after it.

**Independent Test**: With three monitors in a row, from the leftmost press SUPER + ALT + Left
and check the workspace lands on the rightmost; from the rightmost press SUPER + ALT + Right and
check it lands on the leftmost.

**Acceptance Scenarios**:

1. **Given** three monitors left to right A, B, C and the active workspace on A, **When** the
   user presses SUPER + ALT + Left, **Then** the workspace moves to C.
2. **Given** the active workspace on C, **When** the user presses SUPER + ALT + Right, **Then**
   it moves to A.
3. **Given** three monitors A, B, C and the active workspace on B, **When** the user presses
   SUPER + ALT + Left, **Then** it moves to A (the nearest one in that direction, no wrap needed).

---

### User Story 3 - Up and down for monitors stacked vertically (Priority: P3)

Some layouts stack a monitor above another (a laptop under an external screen). SUPER + ALT + Up
sends the workspace to the monitor above, SUPER + ALT + Down to the one below, wrapping round at
the top and bottom the same way Left and Right wrap at the sides.

**Why this priority**: The owner asked for the arrow keys as a set; stacked layouts are less
common than side-by-side ones, so this comes last.

**Independent Test**: With one monitor placed above another in the monitor configuration, press
SUPER + ALT + Up from the lower one and check the workspace moves to the upper one; press it
again from the upper one and check it wraps to the lower one.

**Acceptance Scenarios**:

1. **Given** a monitor placed above another, **When** the user presses SUPER + ALT + Up on the
   lower one, **Then** the workspace moves to the upper one.
2. **Given** the workspace on the topmost monitor, **When** the user presses SUPER + ALT + Up,
   **Then** it wraps to the bottommost monitor.
3. **Given** all monitors side by side in one row (none above another), **When** the user
   presses SUPER + ALT + Up or Down, **Then** nothing changes.

---

### Edge Cases

- **One monitor only**: every SUPER + ALT + arrow does nothing, and nothing visible breaks.
- **Monitors at different heights in one row** (the owner's tall portrait monitor beside a
  shorter landscape one, offset vertically): they count as side by side for Left/Right; they do
  not count as above or below each other unless one lies entirely above the other.
- **Two monitors equally near in the pressed direction**: the one closest to the current
  monitor's centre on the other axis is chosen, the same one every time.
- **A monitor that is disabled or disconnected**: it is never a target; directions are worked out
  from the monitors that are on right now.
- **The workspace is empty** (no windows): it still moves, the same as one with windows.
- **A special (scratchpad) workspace is focused**: the regular workspace showing on that monitor
  is the one that moves; the scratchpad is not moved.
- **Edit Desktop, Game Mode or a fullscreen window**: the binding behaves the same as any other
  window-management key in those states (it is not blocked by the shell).
- **The user already bound SUPER + ALT + an arrow in their own configuration**: their binding
  wins and keeps working after installs and updates.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The default Hyprland configuration MUST bind SUPER + ALT + Left, Right, Up and Down
  to "move the current workspace to the monitor in that direction".
- **FR-002**: The direction MUST follow the monitors' arrangement as configured (their positions
  in the monitor layout), not their names, numbers or the order they were connected.
- **FR-003**: Moving MUST take the whole workspace, including every window in it, and the moved
  workspace MUST become the visible workspace on the target monitor.
- **FR-004**: After a move, keyboard focus MUST be on the moved workspace on its new monitor.
- **FR-005**: When there is no monitor in the pressed direction, the workspace MUST wrap to the
  monitor farthest in the opposite direction along the same axis (Left on the leftmost goes to
  the rightmost; Up on the topmost goes to the bottommost).
- **FR-006**: When no other monitor lies along the pressed axis at all (one monitor, or Up/Down
  on a single row), the binding MUST do nothing.
- **FR-007**: The monitor a workspace leaves MUST keep showing a workspace.
- **FR-008**: The four bindings MUST appear in the shell's keybind cheat sheet, grouped as one
  entry the way the other arrow-key sets are, with a description that says what they do, and
  MUST be rebindable the way the other window and workspace binds are (in the user's own
  keybindings file). *(Amended during planning: Settings > Hyprland > Keybinds only manages the
  shell's own actions, not window or workspace binds; see plan.md, "Deviation recorded".)*
- **FR-009**: The bindings MUST NOT replace or conflict with any existing default binding
  (SUPER + arrows focuses windows, SUPER + SHIFT + arrows moves windows; SUPER + ALT + arrows is
  currently unused).
- **FR-010**: Reinstalling or updating MUST add the bindings without overwriting the user's own
  keybinding changes; a user binding of the same keys MUST take precedence.
- **FR-011**: The direction and wrap-around rules MUST be covered by unit tests in the
  repository's test suite, including one, two and three monitors, a row, a stack, and monitors
  offset at different heights.

### Key Entities

- **Monitor**: a connected, enabled display with a position and size in the monitor layout; the
  only input to working out "the monitor in that direction".
- **Workspace**: a set of windows shown on exactly one monitor at a time; the thing that moves.
- **Direction**: Left, Right, Up or Down, chosen by the arrow key; together with the current
  monitor it names the target monitor, wrapping at the edges.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a two-monitor setup, the user can send a workspace to the other monitor and back
  with two key presses and no mouse use.
- **SC-002**: In every tested layout (one, two and three monitors; a row; a stack; offset
  heights), 100% of presses land on the monitor the direction and wrap-around rules name.
- **SC-003**: A moved workspace is visible and focused on its new monitor in under half a second
  from the key press.
- **SC-004**: After a reinstall over a configuration where the user changed other keybindings,
  0 of the user's changes are lost.
- **SC-005**: The new bindings are discoverable: they are listed in the cheat sheet as soon as
  the configuration is installed.

## Assumptions

- "Moving workspaces between monitors" means the current workspace itself travels to the other
  monitor and focus follows it. Moving only the focus to another monitor (without moving the
  workspace) is a different action and out of scope.
- Arrangement comes from the monitor layout the user configured (Settings > Hyprland > Displays /
  the monitor configuration), so a portrait monitor to the left counts as left whatever its
  rotation.
- Monitors count as "in a direction" by their position relative to the current monitor's centre
  on that axis; side-by-side monitors are not above or below each other unless one lies entirely
  above the other.
- The bindings ship in the default (shipped) keybindings, so they reach every install; users who
  installed in "merge" or "skip" Hyprland mode get them only by adding them themselves.
- Only Hyprland is in scope. Other compositors the shell can run on (Niri) are not covered.
- Existing behaviour of every other keybinding stays exactly as it is (constitution, Principle II).
