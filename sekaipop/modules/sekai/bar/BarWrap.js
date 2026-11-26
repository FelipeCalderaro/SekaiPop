.pragma library

// The arithmetic of a wrapping flat bar (Status_Bar.qml `rows`): how many rows its three
// zones need on a bar of a given width, which row each zone takes, and where a row's middle
// is. Pure functions, so tests/bar-wrap-test runs them in node.

// The least room kept between two zones that share a row, design pixels.
var ZONE_GAP = 24

// How many rows (1-3) zones needing `L`, `C`, `R` px need on a bar `W` wide. The centre
// zone sits dead centre, so on one row the WIDER side decides: 2 x max(L, R) + C.
//   1  everything on one row
//   2  left + right on the first row, the centre zone under them; with no centre zone,
//      the left zone and then the right zone under it
//   3  one zone per row
function rowsFor(L, C, R, W) {
    if (C > 0) {
        if (2 * Math.max(L, R) + C + 2 * ZONE_GAP <= W)
            return 1
        if (L + R + ZONE_GAP <= W)
            return 2
        return 3
    }
    return L + R + ZONE_GAP <= W ? 1 : 2
}

// The row `zone` ("left" | "center" | "right") sits on, 0 first.
function rowOf(zone, rows, hasCenter) {
    if (rows <= 1)
        return 0
    if (rows === 2)
        return hasCenter ? (zone === "center" ? 1 : 0) : (zone === "right" ? 1 : 0)
    return zone === "left" ? 0 : (zone === "center" ? 1 : 2)
}

// Does `zone` have its row to itself? Such a zone is centred on its row, so a bar of stacked
// rows reads as one column instead of a staircase (left zone at the left edge, the next row in
// the middle, the last at the right edge). Zones sharing a row keep their own edges.
function alone(zone, rows, hasCenter) {
    if (rows <= 1)
        return false
    if (rows === 2)
        return hasCenter ? zone === "center" : true
    return true
}

// The middle of `row`, from the top of a content box `height` tall holding `rows` rows
// `step` apart (the rows are centred in the box as a block).
function rowCenter(height, rows, step, row) {
    return (height - (rows - 1) * step) / 2 + row * step
}

// The next row count. `grow` is what the bar needs at its real width, `shrinkTo` what it
// would need with some slack taken off that width. A row is added as soon as it is needed,
// and only taken away once the bar fits with the slack to spare, so a width right on the
// edge never flips the bar back and forth.
function settle(rows, grow, shrinkTo) {
    if (grow > rows)
        return grow
    if (shrinkTo < rows)
        return shrinkTo
    return rows
}
