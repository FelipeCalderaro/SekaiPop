# Implementation Plan: Move Workspaces Between Monitors

**Branch**: `001-workspace-monitor-keybinds` | **Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-workspace-monitor-keybinds/spec.md`

## Summary

Add SUPER + ALT + Left/Right/Up/Down to the default Hyprland keybinds to send the current
workspace to the monitor in that direction, by the configured monitor layout, wrapping to the
far side at the edges. A pure Lua module picks the target monitor from Hyprland's live monitor
list (turning physical sizes into logical layout rectangles, so a rotated portrait monitor is
placed correctly); the bind then moves the workspace there with
`hl.dsp.workspace.move({ workspace, monitor })` and focuses that monitor. The module is
unit-tested with the system `lua`, run from the repository's node test suite.

## Technical Context

**Language/Version**: Lua 5.5 (Hyprland 0.57 Lua config); test harness in JavaScript (node),
as the rest of the suite

**Primary Dependencies**: Hyprland 0.55+ Lua API (`hl.bind`, `hl.get_monitors`,
`hl.get_active_monitor`, `hl.dispatch`, `hl.dsp.workspace.move`, `hl.dsp.focus`); `lua`
interpreter for tests (a hard dependency of the `hyprland` package)

**Storage**: N/A (reads the live monitor list on each key press)

**Testing**: `node tests/monitor-direction-test/monitor_direction_test.js` (spawns
`lua` on a Lua unit test, and checks `keybinds.lua` wiring from source)

**Target Platform**: Linux, Hyprland 0.55+ with SekaiPop's shipped Lua config

**Project Type**: Desktop configuration (window manager keybinds) within the SekaiPop rice

**Performance Goals**: The move is visible in under 0.5 s from the key press (SC-003); the
target is computed in-process over a handful of monitors, no external process

**Constraints**: Must not break other keybinds if the module fails to load; must not change any
existing binding; user bindings in `custom/` must win; works with rotated and scaled monitors

**Scale/Scope**: 1–6 monitors; 4 bindings; one new module, one edited file, one new test

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | How |
| --- | --- | --- |
| I. One design language | Pass (n/a) | No UI is drawn. The cheat sheet shows the binds with its existing look. |
| II. Preserve the existing configuration | Pass | New keys only (unused today); follows the existing pattern for arrow-key sets (a loop, one "Group: sentence" description) and for window/workspace binds (cheat sheet, rebind in `custom/`); no other bind changes; `custom/keybinds.lua` still wins; the installer's merge keeps user edits to `keybinds.lua`. |
| III. Rollback for big migrations | Pass (n/a) | Not a migration: no user file is moved, renamed or converted. Rolling back is removing the four binds (or `hl.unbind` in `custom/`). |
| IV. Tests with every integration | Pass | Pure Lua module with a unit test over every layout in data-model.md, run by the node suite; a source check guards the `keybinds.lua` wiring. |
| V. Reproducible on any machine | Pass | Ships in the default config the installer lays down; no machine-specific names: monitors are found from the live layout. |
| Plugins and integrations | Pass (n/a) | Core window-management default, not a personal integration; no plugin needed. |

**Deviation recorded**: spec FR-008 asked for the binds in Settings > Hyprland > Keybinds as
well. That panel only manages shell actions it can re-create as commands; window/workspace
binds are not in it (research R6). Per Principle II the binds follow their siblings (cheat sheet;
rebind in `custom/`). FR-008 and SC-005 in the spec are amended accordingly.

**Post-design re-check (after Phase 1)**: unchanged, all pass. The design adds no process, no
dependency and no state.

## Project Structure

### Documentation (this feature)

```text
specs/001-workspace-monitor-keybinds/
├── plan.md              # This file
├── research.md          # Phase 0: decisions R1–R9
├── data-model.md        # Phase 1: monitor → rect, the picking rules, expected outcomes
├── quickstart.md        # Phase 1: how to validate
├── contracts/
│   └── keybindings.md   # Phase 1: the bindings and the Lua module's interface
└── tasks.md             # Phase 2 (/speckit-tasks, not created here)
```

### Source Code (repository root)

```text
hypr/hyprland/
├── lib/
│   ├── init.lua                    # existing helpers (unchanged)
│   └── monitor_direction.lua       # NEW: pure target picking (rects, pick, target)
└── keybinds.lua                    # EDIT: SUPER + ALT + arrows, beside the other arrow sets

sekaipop/tests/monitor-direction-test/
├── monitor_direction_test.lua      # NEW: unit test of the module (plain lua)
└── monitor_direction_test.js       # NEW: runs the Lua test; checks keybinds.lua wiring

sekaipop/CHANGELOG.md               # EDIT: "Unreleased" entry
```

(The README has no keybind list, so it needs no change; the cheat sheet, SUPER + /, is where
binds are discovered.)

**Structure Decision**: Keep to the existing layout: shipped Hyprland defaults in
`hypr/hyprland/` (helpers in `lib/`, binds in `keybinds.lua`), tests in
`sekaipop/tests/<area>-test/` run by node. No installer change: the existing edit-preserving
install handles a new shipped file and a changed one (research R9).

## Complexity Tracking

No constitution violations to justify. The one recorded deviation (FR-008) reduces scope to the
existing pattern rather than adding complexity.
