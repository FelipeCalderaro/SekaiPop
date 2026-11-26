-- lua tests/monitor-direction-test/monitor_direction_test.lua   (run by monitor_direction_test.js)
-- hypr/hyprland/lib/monitor_direction.lua: monitors -> layout rects, and which monitor a
-- SUPER + ALT + arrow picks in every layout of specs/001-workspace-monitor-keybinds/data-model.md.

local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local repo = here .. "/../../.."
package.path = repo .. "/hypr/?.lua;" .. repo .. "/hypr/?/init.lua;" .. package.path
local md = require("hyprland.lib.monitor_direction")

local fails, n = 0, 0
local function show(v)
    if type(v) == "number" then return string.format("%.4f", v) end -- 1080 and 1080.0 alike
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. show(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function check(name, got, want)
    n = n + 1
    if show(got) ~= show(want) then
        fails = fails + 1
        print("FAIL " .. name .. "\n   got  " .. show(got) .. "\n   want " .. show(want))
    end
end

-- A hl.get_monitors()-shaped entry.
local function mon(name, x, y, w, h, opts)
    local m = { name = name, x = x, y = y, width = w, height = h, scale = 1, transform = 0, enabled = true }
    for k, v in pairs(opts or {}) do m[k] = v end
    return m
end
local function T(monitors, cur, dir) return md.target(monitors, cur, dir) end

-- rects --------------------------------------------------------------------------------------
check("plain rect", md.rects({ mon("A", 10, 20, 1920, 1080) }),
    { { name = "A", left = 10, top = 20, w = 1920, h = 1080, cx = 970, cy = 560 } })
check("disabled left out", #md.rects({ mon("A", 0, 0, 100, 100, { enabled = false }) }), 0)
for _, f in ipairs({ "name", "x", "y", "width", "height" }) do
    local m = mon("A", 0, 0, 100, 100)
    m[f] = nil
    check("missing " .. f .. " left out", #md.rects({ m }), 0)
end
check("scale 0 is 1", md.rects({ mon("A", 0, 0, 200, 100, { scale = 0 }) })[1].w, 200)
check("scale -1 is 1", md.rects({ mon("A", 0, 0, 200, 100, { scale = -1 }) })[1].w, 200)
check("scale 2 halves", { md.rects({ mon("A", 0, 0, 200, 100, { scale = 2 }) })[1].w,
    md.rects({ mon("A", 0, 0, 200, 100, { scale = 2 }) })[1].h }, { 100, 50 })
for t = 0, 7 do
    local r = md.rects({ mon("A", 0, 0, 200, 100, { transform = t }) })[1]
    check("transform " .. t, { r.w, r.h }, (t % 2 == 1) and { 100, 200 } or { 200, 100 })
end
check("rotated and scaled", (function()
    local r = md.rects({ mon("A", 0, 0, 3840, 2160, { transform = 1, scale = 2 }) })[1]
    return { r.w, r.h }
end)(), { 1080, 1920 })

-- The owner's desk: portrait HDMI-A-2 on the left, DP-1 on the right, 740 px lower.
local desk = {
    mon("HDMI-A-2", 0, 0, 2560, 1080, { transform = 3 }),
    mon("DP-1", 1080, 740, 2560, 1080),
}
check("desk rects", md.rects(desk), {
    { name = "HDMI-A-2", left = 0, top = 0, w = 1080, h = 2560, cx = 540, cy = 1280 },
    { name = "DP-1", left = 1080, top = 740, w = 2560, h = 1080, cx = 2360, cy = 1280 },
})

-- guards ---------------------------------------------------------------------------------------
local two = { mon("A", 0, 0, 1920, 1080), mon("B", 1920, 0, 1920, 1080) }
check("unknown dir", T(two, "A", "x"), nil)
check("nil dir", T(two, "A", nil), nil)
check("unknown current", T(two, "Z", "r"), nil)
check("empty list", T({}, "A", "r"), nil)
for _, d in ipairs({ "l", "r", "u", "d" }) do
    check("one monitor " .. d, T({ mon("A", 0, 0, 1920, 1080) }, "A", d), nil)
end

-- US1: beside, nearest ---------------------------------------------------------------------------
local row = { mon("A", 0, 0, 1920, 1080), mon("B", 1920, 0, 1920, 1080), mon("C", 3840, 0, 1920, 1080) }
check("A,B: A right -> B", T(two, "A", "r"), "B")
check("A,B: B left -> A", T(two, "B", "l"), "A")
check("A,B,C: B left -> A", T(row, "B", "l"), "A")
check("A,B,C: B right -> C", T(row, "B", "r"), "C")
check("A,B,C: A right -> B (nearest)", T(row, "A", "r"), "B")
check("desk: DP-1 left -> HDMI-A-2", T(desk, "DP-1", "l"), "HDMI-A-2")
check("order of the list does not matter", T({ row[3], row[1], row[2] }, "A", "r"), "B")
-- two equally near to the right: the one closer in height wins, then the name
local fork = { mon("A", 0, 500, 1000, 1000), mon("Hi", 1000, 0, 1000, 1000), mon("Lo", 1000, 1100, 1000, 1000) }
check("tie -> smaller other-axis offset", T(fork, "A", "r"), "Hi")
local even = { mon("A", 0, 500, 1000, 1000), mon("Y", 1000, 0, 1000, 1000), mon("X", 1000, 1000, 1000, 1000) }
check("full tie -> name", T(even, "A", "r"), "X")
local withOff = { mon("A", 0, 0, 1920, 1080), mon("B", 1920, 0, 1920, 1080, { enabled = false }),
    mon("C", 3840, 0, 1920, 1080) }
check("disabled monitor skipped", T(withOff, "A", "r"), "C")
for _, layout in ipairs({ two, row, desk, fork }) do
    for _, m in ipairs(layout) do
        for _, d in ipairs({ "l", "r", "u", "d" }) do
            local t = T(layout, m.name, d)
            if t == m.name then check("never current " .. m.name .. " " .. d, t, "another") end
        end
    end
end

-- US2: wrap ------------------------------------------------------------------------------------
check("A,B: A left -> B (wrap)", T(two, "A", "l"), "B")
check("A,B: B right -> A (wrap)", T(two, "B", "r"), "A")
check("A,B,C: A left -> C (farthest)", T(row, "A", "l"), "C")
check("A,B,C: C right -> A (farthest)", T(row, "C", "r"), "A")
check("desk: HDMI-A-2 left -> DP-1 (wrap)", T(desk, "HDMI-A-2", "l"), "DP-1")
check("desk: DP-1 right -> HDMI-A-2 (wrap)", T(desk, "DP-1", "r"), "HDMI-A-2")
local wrapTie = { mon("Hi", 0, 0, 1000, 1000), mon("Lo", 0, 1100, 1000, 1000), mon("A", 1000, 500, 1000, 1000) }
check("wrap tie -> smaller other-axis offset", T(wrapTie, "A", "r"), "Hi")

-- US3: up and down -------------------------------------------------------------------------------
local stack = { mon("E", 0, 0, 1920, 1080), mon("L", 0, 1080, 1920, 1080) }
check("E over L: L up -> E", T(stack, "L", "u"), "E")
check("E over L: E down -> L", T(stack, "E", "d"), "L")
check("E over L: E up -> L (wrap)", T(stack, "E", "u"), "L")
check("E over L: L down -> E (wrap)", T(stack, "L", "d"), "E")
check("E over L: left/right -> nil", { T(stack, "L", "l"), T(stack, "L", "r") }, {})
local tower = { mon("T", 0, 0, 1920, 1080), mon("M", 0, 1080, 1920, 1080), mon("B", 0, 2160, 1920, 1080) }
check("three stacked: T up -> B (farthest)", T(tower, "T", "u"), "B")
check("three stacked: B down -> T (farthest)", T(tower, "B", "d"), "T")
check("three stacked: M up -> T", T(tower, "M", "u"), "T")
check("row: up -> nil", T(two, "A", "u"), nil)
check("row: down -> nil", T(two, "A", "d"), nil)
check("desk: DP-1 up -> nil", T(desk, "DP-1", "u"), nil)
check("desk: DP-1 down -> nil", T(desk, "DP-1", "d"), nil)
check("desk: HDMI-A-2 up -> nil", T(desk, "HDMI-A-2", "u"), nil)
-- a laptop under an external screen, shifted sideways
local laptop = { mon("Ext", 0, 0, 2560, 1440), mon("eDP-1", 800, 1440, 1920, 1200, { scale = 1.5 }) }
check("offset laptop: up -> Ext", T(laptop, "eDP-1", "u"), "Ext")
check("offset laptop: Ext down -> eDP-1", T(laptop, "Ext", "d"), "eDP-1")

print(fails > 0 and (fails .. " of " .. n .. " failed") or ("all " .. n .. " passed"))
os.exit(fails == 0 and 0 or 1)
