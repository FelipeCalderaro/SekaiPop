-- Which monitor lies in a direction from the focused one, by the monitor layout, wrapping to the
-- far side at the edges. Used by SUPER + ALT + arrows (keybinds.lua) to move a workspace there.
-- Pure: plain tables in, a monitor name out (no hl.* calls), so it runs in plain `lua` for the
-- tests (sekaipop/tests/monitor-direction-test/).

local M = {}

-- Hyprland's monitors -> logical layout rectangles. width/height are the physical mode, so a
-- rotated monitor (odd transform: 90/270, flipped or not) swaps them; then divide by scale.
-- Disabled or incomplete monitors are left out.
function M.rects(monitors)
    local out = {}
    for _, m in ipairs(monitors or {}) do
        if m.enabled ~= false and m.name and m.x and m.y and m.width and m.height then
            local scale = (m.scale and m.scale > 0) and m.scale or 1
            local w, h = m.width, m.height
            if (m.transform or 0) % 2 == 1 then w, h = h, w end
            w, h = w / scale, h / scale
            out[#out + 1] = { name = m.name, left = m.x, top = m.y, w = w, h = h,
                cx = m.x + w / 2, cy = m.y + h / 2 }
        end
    end
    return out
end

-- Per direction: the axis centre, the other axis centre, and "is o beyond c on this side".
local AXES = {
    l = { main = "cx", other = "cy", opp = "r", beyond = function(c, o) return o.cx < c.left end },
    r = { main = "cx", other = "cy", opp = "l", beyond = function(c, o) return o.cx > c.left + c.w end },
    u = { main = "cy", other = "cx", opp = "d", beyond = function(c, o) return o.cy < c.top end },
    d = { main = "cy", other = "cx", opp = "u", beyond = function(c, o) return o.cy > c.top + c.h end },
}

-- The candidate beyond `cur` in `dir` nearest (or farthest) along the axis; ties go to the
-- smallest offset on the other axis, then to the name.
local function choose(rects, cur, dir, farthest)
    local a = AXES[dir]
    local best, bestKey
    for _, o in ipairs(rects) do
        if o.name ~= cur.name and a.beyond(cur, o) then
            local dist = math.abs(o[a.main] - cur[a.main])
            local key = { farthest and -dist or dist, math.abs(o[a.other] - cur[a.other]), o.name }
            if not bestKey or key[1] < bestKey[1]
                or (key[1] == bestKey[1] and (key[2] < bestKey[2]
                    or (key[2] == bestKey[2] and key[3] < bestKey[3]))) then
                best, bestKey = o, key
            end
        end
    end
    return best and best.name or nil
end

-- The target monitor's name, or nil for "do nothing". Never `current`.
function M.pick(rects, current, dir)
    local a = AXES[dir]
    if not a then return nil end
    local cur
    for _, r in ipairs(rects or {}) do
        if r.name == current then cur = r break end
    end
    if not cur then return nil end
    return choose(rects, cur, dir, false) or choose(rects, cur, a.opp, true)
end

function M.target(monitors, current, dir)
    return M.pick(M.rects(monitors), current, dir)
end

return M
