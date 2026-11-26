// node tests/monitor-direction-test/monitor_direction_test.js   (run from the sekaipop folder)
// SUPER + ALT + arrows move the workspace to the monitor in that direction. Runs the Lua unit
// test of hypr/hyprland/lib/monitor_direction.lua with the system `lua` (a dependency of the
// hyprland package), then checks from source how keybinds.lua wires the four keys.
const fs = require("fs"), path = require("path")
const { spawnSync } = require("child_process")
const top = path.join(__dirname, "..", "..")
const repo = path.dirname(top)

let fails = 0, n = 0
function ok(cond, msg) { n++; if (!cond) { fails++; console.log("FAIL " + msg) } }

// 1. The Lua unit test
const run = spawnSync("lua", [path.join(__dirname, "monitor_direction_test.lua")], { encoding: "utf8" })
if (run.error) {
    ok(false, "could not run `lua` (" + run.error.code + "): install the lua package to run this test")
} else {
    process.stdout.write(run.stdout + run.stderr)
    ok(run.status === 0, "monitor_direction_test.lua passed")
}

// 2. keybinds.lua wiring
const binds = fs.readFileSync(path.join(repo, "hypr/hyprland/keybinds.lua"), "utf8")
const DESC = "Workspaces: Move workspace to monitor in direction"
const req = binds.indexOf('pcall(require, "hyprland.lib.monitor_direction")')
ok(req >= 0, "the helper is loaded with pcall(require, ...)")
const guard = binds.indexOf("if okMd then", req)
ok(guard > req, "the binds are made only when the helper loaded")
// the guarded block: from `if okMd then` to its closing `end` at the start of a line
const blockEnd = binds.indexOf("\nend", guard)
const block = binds.slice(guard, blockEnd)
ok(/"SUPER \+ ALT \+ " \.\. arrowkey\[i\]/.test(block), "the binds are SUPER + ALT + arrow")
ok(/\{ "Left", "Right", "Up", "Down" \}/.test(block) && /\{ "l", "r", "u", "d" \}/.test(block),
    "the four arrows map to l / r / u / d in order")
ok(block.includes('description = "' + DESC + '"'), "every key has the shared description")
ok(binds.split(DESC).length - 1 === 1, "the description is written once (one loop, one cheat-sheet row)")
ok(/monitorDirection\.target\(hl\.get_monitors\(\), focused\.name, dir\)/.test(block), "the target comes from the helper")
ok(/if not target then return end/.test(block), "no target: the key does nothing")
const move = block.indexOf("hl.dsp.workspace.move({ workspace = ws.id, monitor = target })")
const focus = block.indexOf("hl.dsp.focus({ monitor = target })")
ok(move > 0, "the workspace is moved with workspace and monitor")
ok(focus > move, "then the target monitor is focused")
ok(/focused\.active_workspace/.test(block), "the regular active workspace moves, not a scratchpad")
// no other default binds these keys (FR-009)
const others = binds.slice(0, guard) + binds.slice(blockEnd)
ok(!/SUPER \+ ALT \+ (Left|Right|Up|Down)\b/.test(others), "no other default bind uses SUPER + ALT + an arrow")
ok(!/"SUPER \+ ALT \+ " \.\. arrowkey/.test(others), "no other loop binds SUPER + ALT + arrows")
// the helper stays pure, so the unit test means what it says
const helper = fs.readFileSync(path.join(repo, "hypr/hyprland/lib/monitor_direction.lua"), "utf8")
ok(!/\bhl\./.test(helper.replace(/--.*$/gm, "")), "monitor_direction.lua calls no hl.* function")
ok(!/\b(io|os)\./.test(helper), "monitor_direction.lua does no I/O")

console.log(fails ? `${fails} of ${n} failed` : `all ${n} passed`)
process.exit(fails ? 1 : 0)
