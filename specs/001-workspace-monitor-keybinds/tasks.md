---

description: "Task list for Move Workspaces Between Monitors"
---

# Tasks: Move Workspaces Between Monitors

**Input**: Design documents from `/specs/001-workspace-monitor-keybinds/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/keybindings.md, quickstart.md

**Tests**: Requested. FR-011 asks for unit tests of the direction and wrap-around rules, and
Constitution IV asks for tests with every integration. Within each story the test cases are
written first and must fail before the module code is written.

**Organization**: Tasks are grouped by user story so each story can be built and checked on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story the task belongs to (US1, US2, US3)

## Path Conventions

- Shipped Hyprland defaults: `hypr/hyprland/` (helpers in `lib/`, binds in `keybinds.lua`)
- Tests: `sekaipop/tests/monitor-direction-test/`, run from the `sekaipop/` folder with
  `node tests/monitor-direction-test/monitor_direction_test.js`
- Module name for `require`: `hyprland.lib.monitor_direction` (the same root `hypr/hyprland.lua`
  uses for `load("hyprland.lib")`)

**Shared-file note**: every story edits the same two files
(`hypr/hyprland/lib/monitor_direction.lua` and `sekaipop/tests/monitor-direction-test/monitor_direction_test.lua`),
so the stories run one after another (P1 → P2 → P3), not side by side.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the files and the test runner.

- [X] T001 Create the folder `sekaipop/tests/monitor-direction-test/` and an empty pure module `hypr/hyprland/lib/monitor_direction.lua` that returns a table `M` with stub functions `rects`, `pick` and `target` (signatures per contracts/keybindings.md §2); the file MUST NOT call any `hl.*` function or do I/O, so it loads in plain `lua`
- [X] T002 [P] Create the Lua test file `sekaipop/tests/monitor-direction-test/monitor_direction_test.lua`: set `package.path` so `require("hyprland.lib.monitor_direction")` resolves to `hypr/hyprland/lib/monitor_direction.lua` from the repository root (derive the root from `arg[0]`), add a small `check(name, got, want)` helper that counts failures and prints each failing case, plus a helper `mon(name, x, y, w, h, opts)` that builds a `hl.get_monitors()`-shaped table (`scale = 1`, `transform = 0`, `enabled = true` unless `opts` overrides); exit with `os.exit(failures == 0 and 0 or 1)`
- [X] T003 [P] Create the node runner `sekaipop/tests/monitor-direction-test/monitor_direction_test.js` following the suite's `spawnSync` style (see `sekaipop/tests/idle-test/idle_test.js`): run `lua` on `monitor_direction_test.lua`, print its output, and fail with its exit code; if `lua` is not installed, fail with a message that names the missing program (do not pass silently)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Turn Hyprland's monitor list into logical layout rectangles. Every story's picking works on these.

**⚠️ CRITICAL**: No story's picking can be written until `rects()` is correct.

- [X] T004 Add unit tests for `rects()` in `sekaipop/tests/monitor-direction-test/monitor_direction_test.lua`: a monitor with `enabled == false` is left out; monitors missing `name`, `x`, `y`, `width` or `height` are left out; `scale <= 0` is treated as 1; transforms 1, 3, 5, 7 swap width and height, 0, 2, 4, 6 do not; a scale of 2 halves `w`/`h`; `cx`/`cy` are the centres; the owner's desk example gives `HDMI-A-2` 1080 × 2560 at 0,0 centre (540, 1280) and `DP-1` 2560 × 1080 at 1080,740 centre (2360, 1280) (data-model.md, Monitor validation and Rect fields). Run T003's runner and confirm these fail
- [X] T005 Implement `M.rects(monitors)` in `hypr/hyprland/lib/monitor_direction.lua` per data-model.md: drop entries failing data-model.md `Monitor.enabled` and the required `Monitor.name` / `Monitor.x` / `Monitor.y` / `Monitor.width` / `Monitor.height`; apply data-model.md `Monitor.scale` (`<= 0` → 1) and `Monitor.transform`; produce data-model.md `Rect.name`, `Rect.left`, `Rect.top`, `Rect.w`, `Rect.h`, `Rect.cx`, `Rect.cy`. Make T004 pass
- [X] T006 Implement `M.target(monitors, current, dir)` as `M.pick(M.rects(monitors), current, dir)` and make `M.pick` return `nil` for any `dir` other than data-model.md `Direction` values (`"l"`, `"r"`, `"u"`, `"d"`) and when `current` is not among the rects, in `hypr/hyprland/lib/monitor_direction.lua`; add tests for an unknown direction, an unknown current monitor, and one monitor (every direction → `nil`) in `sekaipop/tests/monitor-direction-test/monitor_direction_test.lua`

**Checkpoint**: `node tests/monitor-direction-test/monitor_direction_test.js` passes; `rects()` is trusted.

---

## Phase 3: User Story 1 - Send the current workspace to the monitor beside it (Priority: P1) 🎯 MVP

**Goal**: SUPER + ALT + Left / Right sends the focused workspace, with its windows, to the nearest monitor in that direction, shown and focused there.

**Independent Test**: Two monitors side by side: open windows on a workspace on the left one, press SUPER + ALT + Right, and the workspace is on the right monitor, shown and focused; SUPER + ALT + Left brings it back (quickstart.md §3 steps 1–2, 4, 6).

### Tests for User Story 1 ⚠️

> Write these first and confirm they fail.

- [X] T007 [US1] Add Left/Right "beyond + nearest" cases to `sekaipop/tests/monitor-direction-test/monitor_direction_test.lua` from data-model.md "Outcomes": A,B side by side, A + Right → B; A,B,C in a row, B + Left → A and B + Right → C; the owner's desk, DP-1 + Left → HDMI-A-2 (offset heights still count as side by side); two monitors equally near on the axis → the one with the smaller centre offset on the other axis, then the name first in alphabetical order; a disabled monitor in between is never the target; `pick` never returns `current`
- [X] T008 [P] [US1] Add a source check to `sekaipop/tests/monitor-direction-test/monitor_direction_test.js` that reads `hypr/hyprland/keybinds.lua` and asserts: the module is loaded with `pcall(require, "hyprland.lib.monitor_direction")`; the four binds `SUPER + ALT + Left/Right/Up/Down` are made only inside the branch where the require succeeded; each uses the exact description `Workspaces: Move workspace to monitor in direction` (contracts/keybindings.md §1); the bind calls `hl.dsp.workspace.move` with both `workspace` and `monitor`, then `hl.dsp.focus({ monitor = ... })`; no other line binds `SUPER + ALT + Left|Right|Up|Down` (FR-009)

### Implementation for User Story 1

- [X] T009 [US1] Implement the "Beyond" and "Nearest" rules of data-model.md "Picking the target" for `"l"` and `"r"` in `M.pick` in `hypr/hyprland/lib/monitor_direction.lua` (beyond: `other.cx < cur.left` / `other.cx > cur.left + cur.w`; nearest by centre distance on the axis; ties by other-axis centre offset, then name). Return `nil` when nothing is beyond (wrap comes in US2). Make T007 pass
- [X] T010 [US1] Add the binds in `hypr/hyprland/keybinds.lua` in the `--##! Workspace` section after the "Focus workspace left/right" loops and before `--## Special`: a `--#/# bind = SUPER + ALT, ←/↑/→/↓,, -- Move workspace to monitor` comment, `local okMd, monitorDirection = pcall(require, "hyprland.lib.monitor_direction")`, and, only `if okMd`, a `for i = 1, 4` loop over `{ "Left", "Right", "Up", "Down" }` / `{ "l", "r", "u", "d" }` (the same shape as the SUPER + SHIFT arrow loop) binding `"SUPER + ALT + " .. key` to a Lua function that follows contracts/keybindings.md §3: read `hl.get_active_monitor()`, take its regular active workspace id (not a special workspace), `target = monitorDirection.target(hl.get_monitors(), focused.name, dir)`, return if `nil`, else `hl.dispatch(hl.dsp.workspace.move({ workspace = id, monitor = target }))` then `hl.dispatch(hl.dsp.focus({ monitor = target }))`; description `"Workspaces: Move workspace to monitor in direction"` on all four. Do not change any other bind. Make T008 pass
- [ ] T011 [US1] Validate on the real desk per quickstart.md §2 (`hyprctl reload`, `hyprctl configerrors` empty, no new lines in `~/.cache/sekaipop/hypr-errors.log`, `hyprctl binds -j | grep -c "Move workspace to monitor in direction"` → 4) and §3 steps 1, 2, 4 and 6: the moved workspace keeps its windows, is shown and focused on the target, the monitor it left still shows a workspace, and each bar's pills match. If focus or the left-behind monitor misbehave, fix it in the bind function in `hypr/hyprland/keybinds.lua` and record what was seen

**Checkpoint**: On two side-by-side monitors, Left/Right move the workspace back and forth (SC-001). MVP.

---

## Phase 4: User Story 2 - Wrap around at the edge of the monitor layout (Priority: P2)

**Goal**: Left on the leftmost monitor goes to the rightmost; Right on the rightmost goes to the leftmost. With two monitors both directions swap.

**Independent Test**: Three monitors in a row: Left from the leftmost lands on the rightmost, Right from the rightmost lands on the leftmost (unit test); on two monitors, quickstart.md §3 step 3.

### Tests for User Story 2 ⚠️

- [X] T012 [US2] Add wrap cases to `sekaipop/tests/monitor-direction-test/monitor_direction_test.lua` from data-model.md "Outcomes": A,B side by side, A + Left → B; A,B,C in a row, A + Left → C (farthest, not B) and C + Right → A; the owner's desk, HDMI-A-2 + Left → DP-1; a wrap tie between two equally far monitors resolves by other-axis centre offset, then name. Confirm they fail

### Implementation for User Story 2

- [X] T013 [US2] Implement the "Wrap" rule of data-model.md "Picking the target" in `M.pick` in `hypr/hyprland/lib/monitor_direction.lua`: when nothing is beyond in `dir`, take the monitors beyond in the opposite direction and choose the **farthest** along the axis with the same tie rules; still `nil` when neither side has one. Keep the US1 cases passing. Make T012 pass
- [ ] T014 [US2] Check quickstart.md §3 step 3 on the real desk: SUPER + ALT + Left twice from DP-1 sends the workspace to HDMI-A-2 and back (no change to `hypr/hyprland/keybinds.lua` expected)

**Checkpoint**: Left/Right always do something on a multi-monitor row (FR-005).

---

## Phase 5: User Story 3 - Up and down for monitors stacked vertically (Priority: P3)

**Goal**: SUPER + ALT + Up / Down send the workspace to the monitor above / below, wrapping at top and bottom; on a single row they do nothing.

**Independent Test**: One monitor placed above another: Up from the lower one moves the workspace to the upper one, Up again wraps to the lower one (unit test); on a side-by-side desk, quickstart.md §3 step 5 does nothing.

### Tests for User Story 3 ⚠️

- [X] T015 [US3] Add vertical cases to `sekaipop/tests/monitor-direction-test/monitor_direction_test.lua` from data-model.md "Outcomes": E above L, L + Up → E, E + Down → L, E + Up → L (wrap), L + Down → E (wrap); three stacked, top + Up → bottom (farthest); A,B in a row, A + Up and A + Down → `nil`; the owner's desk, DP-1 + Up and DP-1 + Down → `nil` (HDMI-A-2's centre is level, not above or below); a laptop below and offset sideways from an external screen still counts as below. Confirm they fail

### Implementation for User Story 3

- [X] T016 [US3] Extend the Beyond / Nearest / Wrap rules in `M.pick` in `hypr/hyprland/lib/monitor_direction.lua` to `"u"` and `"d"` (beyond: `other.cy < cur.top` / `other.cy > cur.top + cur.h`; distance on the y axis; tie by x-centre offset, then name). Prefer one axis-generic code path over copied branches. Make T015 pass with every earlier case still passing
- [ ] T017 [US3] Check quickstart.md §3 step 5 on the real desk: SUPER + ALT + Up and Down do nothing on the side-by-side layout (no change to `hypr/hyprland/keybinds.lua` expected)

**Checkpoint**: All four arrows follow the layout and wrap rules (FR-001, FR-002, FR-005, FR-006; SC-002).

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Docs, discoverability, user-binding precedence and the full suite.

- [X] T018 [P] Add an "Unreleased" entry to `sekaipop/CHANGELOG.md` in the file's plain-words style: SUPER + ALT + arrows move the current workspace to the monitor in that direction by the monitor layout, wrapping at the edges; nothing on one monitor or Up/Down on a single row; listed in the cheat sheet; rebind or remove in `~/.config/hypr/custom/keybinds.lua` (`hl.unbind("SUPER + ALT + Left")`); on an existing install run install.sh again (its merge keeps your own edits to `keybinds.lua`). Do not touch the other entries already there
- [ ] T019 [P] Check the cheat sheet (SUPER + /) shows one row in the Workspaces note, "Move workspace to monitor in direction", with ←/↑/→/↓ (quickstart.md §3 step 7; SC-005). If it does not fold, compare the description with `joinArrows` in the cheat sheet's `CheatBinds.js` and fix the description in `hypr/hyprland/keybinds.lua`, not the cheat sheet
- [ ] T020 Check user precedence per quickstart.md §4: `hl.unbind("SUPER + ALT + Left")` in `~/.config/hypr/custom/keybinds.lua` and `hyprctl reload` leaves Left unbound and the other three working; remove the line afterwards (FR-010)
- [ ] T021 Check the load guard (research R8): temporarily rename `hypr/hyprland/lib/monitor_direction.lua` in a test copy of the config, `hyprctl reload`, and confirm only the four new keys are missing (SUPER + arrows, SUPER + SHIFT + arrows and the rest still work); restore the file
- [ ] T022 Run the whole suite from `sekaipop/` (the new test plus the existing ones such as `tests/keybinds-test/keybinds_layout_unit.js` and `tests/cheatsheet-test/cheat_groups_unit.js`) and confirm no new failures against the base commit (constitution quality gate 3)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none. T002 and T003 can run together after T001.
- **Foundational (Phase 2)**: after Setup. T004 → T005 → T006. Blocks every story.
- **US1 (Phase 3)**: after Foundational.
- **US2 (Phase 4)**: after US1 (adds to the same `pick` and test file; its wrap rule assumes US1's beyond/nearest).
- **US3 (Phase 5)**: after US2 (extends the same rules, including wrap, to the vertical axis).
- **Polish (Phase 6)**: after the stories you ship. T018 can be written any time after T010.

### User Story Dependencies

- **US1 (P1)**: only Foundational. Binds all four keys; Up/Down return `nil` (do nothing) until US3, which is safe.
- **US2 (P2)**: US1's picking. Independently testable with its own unit cases.
- **US3 (P3)**: US1 + US2's picking. Independently testable with its own unit cases.

### Within Each User Story

- Unit cases first, failing → module code → real-desk check.
- `keybinds.lua` changes only in US1 (T010); later stories change only the module.

### Parallel Opportunities

- T002 ∥ T003 (different files).
- T007 ∥ T008 (Lua test file vs node runner).
- T018 ∥ T019 (changelog vs a manual check).
- Stories themselves are sequential (shared files).

---

## Parallel Example: User Story 1

```bash
# Write both tests of User Story 1 together:
Task: "Add Left/Right beyond + nearest cases in sekaipop/tests/monitor-direction-test/monitor_direction_test.lua"
Task: "Add the keybinds.lua source check in sekaipop/tests/monitor-direction-test/monitor_direction_test.js"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup
2. Phase 2: Foundational (`rects()` trusted)
3. Phase 3: US1 (Left/Right to the nearest neighbour, binds wired, checked on the desk)
4. **Stop and validate**: on the owner's two monitors, Left/Right swap the workspace (SC-001)

### Incremental Delivery

1. Setup + Foundational → the module loads and turns monitors into rects
2. + US1 → side-by-side moves work (MVP)
3. + US2 → wrap at the edges
4. + US3 → stacked layouts
5. Polish → changelog, cheat sheet, precedence, guard, full suite

---

## Notes

- [P] tasks = different files, no dependencies
- Constraints on fields live in data-model.md; tasks cite them rather than restate them
- No installer change (research R9) and no Settings > Keybinds change (research R6, spec FR-008 amendment)
- Commit only when the owner asks
