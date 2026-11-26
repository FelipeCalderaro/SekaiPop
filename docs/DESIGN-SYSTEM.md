# SekaiPop Design System

The rules every surface of SekaiPop is drawn by: the bar and its popups, the Quick Panel phone,
Settings, the dock, Edit Desktop, desktop widgets, and plugins. It describes what the code already
does (every number below is read from the source, with the file it lives in) so that something new
looks like it was always there.

> **Source of truth.** Colours, sizes and fonts live in `sekaipop/modules/common/ThemeSet.qml`.
> If this document and that file ever disagree, the file wins; fix the document.

**Contents**

1. [The feel](#1-the-feel)
2. [How theming is wired](#2-how-theming-is-wired)
3. [Colour](#3-colour)
4. [Typography](#4-typography)
5. [Iconography](#5-iconography)
6. [Shape, size and spacing](#6-shape-size-and-spacing)
7. [Construction: the block](#7-construction-the-block)
8. [Buttons and states](#8-buttons-and-states)
9. [Motion](#9-motion)
10. [Transitions](#10-transitions)
11. [Components](#11-components)
12. [The bar](#12-the-bar)
13. [Layout, scale and responsiveness](#13-layout-scale-and-responsiveness)
14. [Legibility and accessibility](#14-legibility-and-accessibility)
15. [Recipes](#15-recipes)
16. [Do and don't](#16-do-and-dont)
17. [Token reference](#17-token-reference)
18. [File map](#18-file-map)

---

## 1. The feel

SekaiPop borrows the language of Project SEKAI's menus and a handheld toy. Five ideas run
through everything:

| Idea | What it means on screen |
| --- | --- |
| **One block, everywhere** | Every pill, key, card and popup is built the same way: a thick outline, a thin pale ring, a fill, and a **hard shadow straight down**. Nothing has a soft drop shadow, glow or blur. |
| **Physical** | Blocks are keycaps. Pressing one drops it onto its shadow; letting go springs it back past rest before it settles. Switches slide their thumb and overshoot. |
| **Things pop, then get swallowed** | Something appearing grows out of the thing that summoned it, with a little overshoot. Leaving, it shrinks *back into* that thing. Fading in place is the exception, not the rule. |
| **Printed and slanted** | Header plates carry a halftone that fades out of one corner and slanted bands of stage light. Section labels sit on slanted tabs with a diamond. Big numbers are stickers with an outline and a hard shadow. |
| **The shell is a device** | The Quick Panel is a 2.5D phone; Settings is that phone turned landscape; the equalizer is a handheld console with a D-pad and cartridges. Controls are drawn as hardware, not as web forms. |

The tone is playful but tidy: chunky outlines, bold type, pastel accents on a navy (or the theme's
dark tone) structure. Decoration is printed *on* blocks, never floating loose over content.

---

## 2. How theming is wired

```
ThemeService.palette ──► ThemeSet (derives every colour + holds every size)
   (group / matugen /         │
    custom / mono)            ├─► Theme            (singleton: the shell's own ThemeSet)
                              └─► Theme.of(window) (one per monitor with its own theme)
                                         │
                                         ▼
                 readonly property var mt: Theme.of(QsWindow.window)   // in an Item
                 readonly property var mt: Theme.of(screen)            // in a PanelWindow
```

- **Palette** (`ThemeService.qml`): a handful of raw colours per theme: `border`, `A`, `B`, `deep`,
  `divider`, `hoverTint`, the phone's plastics, and so on (table in [3.1](#31-palettes)).
- **ThemeSet** (`ThemeSet.qml`): turns a palette plus the mode into every colour the UI uses, and
  holds all sizes and fonts. It is written once and instanced per monitor.
- **`mt`** ("monitor theme"): every visual file reads colours through `mt`, never through the
  `Theme` singleton directly, so a monitor with its own theme (Settings → `theme.perMonitor`)
  gets its own colours. A QML property cannot start with a capital, hence the name.
- **Modes**: **Light**, **Dark** and **Darker** (`ThemeService.mode`; `dark` is true for both dark
  modes). Every derived colour has a formula per mode ([3.2](#32-derived-colours)).
- **Scopes that change the look locally**, found by walking up the item tree:
  - `classicPanel: true` (Quick Panel face, To-Do card): in plain Dark mode these keep the
    original white "classic" panel (`mt.classicFor(item)`, the `p…` colour family).
  - `capsuleBar: true` (`Status_Bar` in the Capsule style): `Pill`, `MaterialIcon` and the workspace
    badges redraw themselves as flat chips / small icons / dots (`mt.capsuleFor(item)`).
- **Plugins** get the same `ThemeSet` as `host.theme`, but may only rely on the names promised in
  `docs/PLUGINS.md` (between the `theme-names` markers).

---

## 3. Colour

### 3.1 Palettes

Each theme is a palette. The two accents `A` / `B` keep the names `accentCyan` / `accentMint` in
code whatever colour they are: they are the two stops of the accent gradient.

| Theme | `border` (outline, dark text) | `A` (accentCyan) | `B` (accentMint) | `deep` (dark tone) | `divider` |
| --- | --- | --- | --- | --- | --- |
| Virtual Singer (default) | `#555473` | `#04feee` | `#00ffcb` | `#232235` | `#e4e4ec` |
| Leo/need | `#2d3775` | `#8ea3ff` | `#9fd8ff` | `#181e3f` | `#dee1f2` |
| MORE MORE JUMP! | `#39662d` | `#a4ee55` | `#7fe9a8` | `#223c1b` | `#e3f1df` |
| Vivid BAD SQUAD | `#561938` | `#ff5c9a` | `#ff96c0` | `#43142c` | `#f5dbe8` |
| Wonderlands×Showtime | `#6a3c11` | `#ffa51f` | `#ffd54a` | `#4b2a0c` | `#f9e7d7` |
| Nightcord at 25:00 | `#43285f` | `#c08cf2` | `#e2b5ff` | `#2b1a3d` | `#e8dff1` |
| Monochrome (`mono: true`) | `#444444` | `#f4f4f4` | `#bdbdbd` | `#1a1a1a` | `#ececec` |
| Wallpaper (matugen) | `primary_container` | `primary` | `tertiary` | darker `on_primary` | — |
| Custom palette | user's | user's | user's | user's | user's |

Other palette keys: `rimHi`, `bezel`, `wallLight`, `wallMid`, `wallDark`, `hardware`, `lens`,
`glint` (the phone's plastics), `hoverTint` (pale hover wash), `boardBg` / `boardDot` (boards),
and for the lockscreen `lockMint` / `lockPink`.

### 3.2 Derived colours

What UI code actually uses. `B` = `palette.border`, `deep` = `palette.deep`, `tint(c, x)` means
`Qt.tint(c, B at alpha x)`.

| Token | Light | Dark | Darker | Used for |
| --- | --- | --- | --- | --- |
| `surface` | `#ffffff` | `lighter(deep, 1.18)` | `darker(deep, 1.4)` | Fill of cards, pills, popups |
| `surfaceHover` | `#f2f2f2` | `lighter(surface, 1.35)` | same | Hovered surface |
| `surfaceDivider` | `palette.divider` | `lighter(surface, 1.75)` | same | Tracks, separators, idle key fill |
| `ink` | `B` | `palette.divider` | same | Text and icons on a surface |
| `inkSub` | `ink` at 0.667 | same | same | Secondary text |
| `line` | `tint(#fff, 0.42)` | `B` | `darker(B, 1.35)` | The outer outline of every block |
| `lineShadow` | `tint(#fff, 0.30)` | `darker(B, 1.3)` | `darker(B, 1.8)` | The hard shadow |
| `ringWhite` | `#ffffff` | `#fff` tinted by B at 0.08 | `lighter(surface, 2.0)` | The ring inside a block |
| `surfaceRing` | `#d9d9d9` | `#fff` tinted by B at 0.18 | `lighter(surface, 1.6)` | The bar's / dock's wide pale ring |
| `chipFill` | `tint(#fff, 0.14)` | `B` | `darker(B, 1.35)` | Filled chips: clock, date, weather, tray, tabs |
| `chipInk` | `B` | `#ffffff` | `#ffffff` | Text on a chip |
| `surfaceTint` | `palette.hoverTint` | surface + A at 0.2 | same | Hover wash on white buttons |
| `scrim` | `tint(#fff, 0.10)` | `deep` | `deep` | Behind dialogs and the power menu |
| `paper` / `paperHover` / `paperEdge` | `#f5f1e6` / `#ece6d4` / `#e4dcc6` | lighter surface ×1.28 / 1.6 / 1.9 | same | Launcher / overview paper |
| `warnFill` | `#ffb74d` | `#ffb74d` | `#ffb74d` | "Wants a look, not an error" (always with `colBorder` ink) |
| `colBorder` | `B` | `B` | `B` | Raw outline colour: stickers, badges, dark text on pastel |
| `accentCyan` / `accentMint` | `A` / `B`(palette) | same | same | Accent gradient stops, "on" state |

The light-mode alphas are tunable in one place: `lightLineAlpha` 0.42, `lightShadowAlpha` 0.30,
`lightChipAlpha` 0.14; dark: `darkRingTint` 0.08, `darkShadowFactor` 1.3; darker:
`darkerFactor` 1.4, `darkerLineFactor` 1.35, `darkerShadowFactor` 1.8, `darkerRingLift` 2.0.

**The classic family (`p…`).** `pSurface`, `pSurfaceHover`, `pSurfaceDivider`, `pSurfaceRing`,
`pRingWhite`, `pLine`, `pLineShadow`, `pInk`, `pInkSub`. In plain Dark mode (`classic`) they are the
white panel's colours (`#ffffff` surface, `colBorder` lines and ink); otherwise they equal the
normal tokens. Desktop cards and the Settings phone use this family; the bar and its popups use the
plain one.

### 3.3 Fixed colours

| Name | Value | Meaning |
| --- | --- | --- |
| `attributeColors` | `#8EE3EF` Cool, `#FF9ECB` Cute, `#FFE066` Happy, `#B39DDB` Mysterious, `#A5E6A5` Pure | A friendly rotating palette: one stable colour per person / item (lock dots, Discord rows: `toneFor(id)` hashes the id). Monochrome: five alternating greys. |
| Discord blurple | `#5865f2` | The Discord plate only |
| Danger | `#ed4245` | A key that is "on" in a harmful sense (muted, deafened) |
| `warnFill` | `#ffb74d` | Updates nudging, a plugin's "key ends soon", AniList's "episodes out" |
| `textWhite` | `#ffffff` | Text on a dark or saturated plate |
| Transition motif | white `#ffffff`, pink `#ff8fd6`, cyan `#22e6d3`, green `#00ffcb` | Classic wallpaper transitions; with "Theme" colours on, derived from A / B (`transitionColors()`) |
| Scrapbook (`ScrapbookTheme.qml`) | page `#f5eeda`, ink `#4a4536`, tape teal `#7fb8bd` / coral `#e8886f` / mint `#b7d99a`, tag `#eec25e`, current `#3fa7c4`, cork `#c99a63` | Paper surfaces only: film-strip overview, cork-board cheat sheet, wallpaper board. Never mixed into the main theme. |

### 3.4 Capsule colours

The Capsule bar style takes its colours from the theme's surface so every group theme gets its own
tint: `capBody` (dark: `surface`, light: white), `capRim` (dark: `lighter(surface, 1.87)`, light:
`line`), `capShade` (dark: `lighter(surface, 1.42)`, light: `lineShadow`), `capChip` = `capRim`,
`capInk` (dark: white, light: `colBorder`), `capLit` = `accentCyan`, `capLitSoft` = `palette.glint`,
and five workspace dot colours `capWsColors`. A popup under a Capsule bar wears these via
`Pill.capRim`.

### 3.5 Colour rules

1. **Text sits on its own pair**: `ink` / `inkSub` on `surface`; `chipInk` on `chipFill`;
   `colBorder` on `warnFill` and on pastel accents; `#ffffff` on saturated plates.
2. **On a colour you don't control** (a profile colour, a cover colour), choose ink by luminance:
   relative luminance > 0.45 → `colBorder`, else white. (`AniList.js isLight()` is a reference
   implementation; the Discord plate is always white-on-blurple.)
3. **Accent means "on"**. The cyan → mint gradient marks the active state (Quick Panel ON,
   Settings tile lit, segment thumb). Don't use it for decoration of idle things.
4. **Amber means "look", red means "harm"**. Neither means "error message"; errors are written in
   words in `inkSub` / `ink`.
5. **Shadows are never black.** They are `lineShadow`, derived from the theme's border.
6. **No translucent surfaces** except the deliberate ones: the scrim, the washi tape, and white
   overlays on plates (bands at 0.10–0.22 alpha, eyebrow text at 0.78).

---

## 4. Typography

**Family**: Google Sans Flex (`mt.fontFamily`), a variable font, OFL. Fallback is whatever
fontconfig picks; nothing breaks without it.

**Bold** is always written as both a weight and a style name, because Qt doesn't reliably pick the
instance of a variable font from the weight alone:

```qml
font.weight: Font.ExtraBold
font.styleName: mt.fontStyleBold   // "ExtraBold"; Black clogs at 7–10 px
```

| Role | Size (px, design) | Weight | Where |
| --- | --- | --- | --- |
| Pill, first of two lines | 10 (`fontSizeTitle`) | ExtraBold | Media / Active Window pill |
| Pill, second line | 7 (`fontSizeSub`) | Medium | Media artist, window title |
| Pill, single line | 12 (`fontSizeIdle`, `fontSizeInfo`) | ExtraBold | Clock, date, weather, plugin entries |
| Capsule clock | 14 (`capClockSize`) | ExtraBold | Capsule bar |
| Hover tag | 11 | DemiBold | `BarTip` |
| Menu row | 14 (`fontSizeMenu`), row 32 tall | — | Tray menu |
| Eyebrow (small caps) | 10–11, UPPERCASE, `letterSpacing` 0.4–0.7 | Bold / ExtraBold | "VOICE CONNECTED", "3 IN CALL", section tabs |
| Card title | 18–19 | ExtraBold | Plate headings ("# General", a username) |
| Card body | 11–14 | DemiBold | Lists, notes, footers |
| Sticker numerals | 40–60 | (drawn) | `StickerText`: weather temperature, clock |
| Default | 16 (`fontSize`) | — | Anything that doesn't say |

Rules:

- **Two-line pills use fixed line boxes** (`lineHeightMode: Text.FixedHeight`, `lineHeight:
  round(size × 1.25)`), so a title containing emoji / CJK (a taller fallback font) can't push the
  block up. Always `elide: Text.ElideRight`, `maximumLineCount: 1`, `textFormat: Text.PlainText`,
  whitespace collapsed (`text.replace(/\s+/g, " ")`).
- **Labels are short words**, not sentences: "ON", "OFF", "Muted", "3 IN CALL", "Ep 8 · 2d 4h".
  A middle dot ` · ` separates facts.
- **Uppercase is for eyebrows and tags only.** Titles and body text are sentence case.
- **Numbers that change hop**: a `StickerText` springs from slightly smaller when its value changes
  (not on the first value).

---

## 5. Iconography

- **Set**: [Solar](https://www.figma.com/community/file/1166831539721848736) SVGs in
  `sekaipop/assets/icons/{outline,broken,line-duotone,bold-duotone,bold}`, drawn by
  `MaterialIcon.qml`.
- **Names**: code keeps using **Material Symbols names** (`wifi_off`, `notifications`).
  `functions/IconMap.js` maps each to a Solar file; a name that already is a Solar file name (with
  `_` for `-`) needs no entry.
- **Style**: Settings → `appearance.iconStyle` restyles every icon at once (outline, broken,
  line-duotone, bold-duotone). `fill: 1` on a single icon picks the Bold set (the "filled" state).
- **Fallback**: a name without a Solar file is drawn as text in **Material Symbols Rounded**
  (`mt.iconFont`, weight `iconWeight` 400; Settings uses 600 so outlines hold up against its thick
  borders). Plugins can't import `MaterialIcon`, so they always use this font.
- **Size**: 24 by default, 16–20 in pills, 18 in small chips. Inside the Capsule bar every icon is
  clamped to 16 (`drawSize`). The SVG face is drawn at 88 % of the box, centred on whole pixels.
- **Colour**: `ink` by default (`pInk` inside a classic panel); states are colours, never a second
  asset.

---

## 6. Shape, size and spacing

All sizes are **design pixels**: the whole bar, every popup and the panels are drawn inside a
`ScaleHost` that multiplies by the monitor's shell scale (`ShellScale`, `scale.json`).

### 6.1 Core metrics (`ThemeSet.qml`)

| Token | Value | What |
| --- | --- | --- |
| `borderWidth` | 3 | Outline of every block |
| `whiteLine` | 2 | The thin white line inside an outline (a block's `ringWidth` = `borderWidth + whiteLine`) |
| `shadowOffset` | 4 | Hard shadow drop (straight down) |
| `outerRingWidth` | 4 | The bar's / dock's wide pale ring |
| `cardRing` | 3 in dark modes, 0 in light | Inner ring drawn over a flat card's fill edge |
| `radiusOuter` | 13 | Cards, popups, the Float bar |
| `radiusBadge` | 15 | Pills in the bar |
| `pillHeight` | 36 (+4 shadow = 40) | Every pill in a flat bar |
| `barVBody` / `barVPillWidth` | 72 / 52 | Standing bar body / its pills |
| `barFloatInset` | 16 | Float bar's inset from the screen edges, and the room outside the workspaces |
| `phoneCornerRadius` | 100 | The phone |
| `phoneRimWidth` / `phoneBezelWidth` | 10 / 9 | Phone glass inset 19 |
| `menuRowHeight` | 32 | Tray menu rows |
| `wheelStep` | 110 | Pixels one mouse-wheel notch scrolls, everywhere |

### 6.2 Radii by object

| Object | Radius |
| --- | --- |
| Bar pill | 15 (`radiusBadge`) |
| Popup card | 13 (`radiusOuter`) |
| Header plate (`SekaiPlate`) | 16 |
| List row in a popup | 12 |
| Keycap (wide) | 10; small 8 |
| Section tab, hover tag | 8 |
| Slanted tag ("3 IN CALL") | 7 |
| Settings card (`SectionCard`) | 30 (inner 15) |
| Quick Panel square key | 30 |
| Capsule anything | fully round (`min(w, h) / 2`) |
| Avatar | circle; server icon: rounded square 9 |

### 6.3 Spacing

| Where | Value |
| --- | --- |
| Gap between pills on a flat bar | `10 − neighborShift(3)` = 7 |
| Gap between pills on a standing bar | 8 (reads as ~12 between faces because of the shadow) |
| Capsule gap / side padding | 6 / 7 |
| Popup content padding | 16 sides, 14 top |
| Popup section spacing | 10 |
| List row gap | 6–8 |
| Popup window gap from the bar | 4 (6 px of air on the facing side; Capsule 0) |
| Popup bleed (room for overshoot / stickers) | 14 on every side except the bar's |
| Hover tag gap from its module | 10 |

### 6.4 The Capsule style's own metrics

Bar 36 tall (3 rim + 30 body + 3 rim), hard shadow 3 below, strip reserved 8 + 39 + 8 = 55;
chips 21 tall, flat (no outline / ring / shadow); workspace dots 12 + 3 ring = 18, active 34 wide;
standing: chips 40 wide, body 50, face 56, strip 72.

---

## 7. Construction: the block

Every pill, key, card and popup is one structure (`modules/common/widgets/Pill.qml`):

```
   ┌──────────────────────────┐  ← outline: borderWidth (3) in `line`
   │ ┌──────────────────────┐ │  ← ring: ringWidth wide, `ringWhite` (a vertical gradient
   │ │                      │ │     ringColorTop → ringColorBottom when a ring carries colour)
   │ │        fill          │ │  ← fill: `fillColor` or `fillGradient`; content goes here
   │ │                      │ │
   │ └──────────────────────┘ │
   └──────────────────────────┘
     ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  ← hard shadow: same shape, `lineShadow`, shadowDy (4) below
```

- The **shadow never moves**. The **cap** (outline + ring + fill + content) moves as one piece.
- **Resting**: cap at y 0, shadow peeking out by `shadowOffset`: the block reads as raised.
- **Pressed**: cap at y `shadowOffset`, exactly covering its shadow: pushed flush.
- **Ring widths**: bar pills 6; two-line pills 5 (two lines don't fit in an 8-ring); cards
  `borderWidth` (so the ring doesn't show, and Dark mode adds `innerRing: cardRing` over the fill
  edge instead); desktop blocks `borderWidth + whiteLine`.

### 7.1 Variants

| Variant | Set | Looks like |
| --- | --- | --- |
| Pill (default) | — | Outline, ring, fill, shadow down |
| Gradient pill | `fillGradient` | Accent pills (Active Window: mint → cyan) |
| Card | `ringWidth: borderWidth`, `innerRing: cardRing`, `cornerRadius: radiusOuter` | Popups (`SekaiPopup`) |
| Capsule chip | inside `capsuleBar` | Flat, fully round chip, 21 tall, centred in its box; press dips 1 px |
| Keeps its colour in Capsule | `capKeepsFill` | Discord / privacy / updates chips whose colour means something |
| Capsule-coloured card | `capRim` | A popup under a Capsule bar: rim outline, rim shadow, body fill |
| Flat | `flat` | No shadow (press dips 1 px); the dock's Capsule keys |
| Bare | `bare` | No background at all, same size; the dock's Transparent style |
| Quick Panel key | `shadowDx` / `shadowDy` | Shadow down **and right** (OFF 3/1, ON 5/2); flat 2D phone mode: straight down |

### 7.2 Housings

The bar itself and the dock are housings: the same outline, but with the wide pale
`surfaceRing` (`outerRingWidth` 4) before the `surface` fill, and the shadow straight down. The
Straight bar style pushes the side outlines past the screen edge (`bgBleed`) so only top and bottom
show.

### 7.3 Decorations (printed on blocks)

| Piece | File | What |
| --- | --- | --- |
| Halftone | `DotField.qml` | Rows of dots shrinking from one corner (`corner: tl/tr/bl/br`, spacing 14–20, max radius ~3.4) |
| Stage light | inside `SekaiPlate.qml` | Two slanted translucent bands across a plate |
| Slant | `Slant.qml` | A leaning rounded rectangle (`skew` 0.2 of height); put text *next to* it, not inside |
| Section tab | `SectionTab.qml` | Slanted `chipFill` tab, radius 8, with a diamond (`accentMint` in dark, `colBorder` in light) |
| Sticker text | `StickerText.qml` | Text with an outline (≥ 2.5 or 8.5 % of size), a white ring (`whiteLine`), fill, and the outline repeated down-right as a hard shadow |
| Washi tape | `WashiTape.qml` | Torn-end tape strip, faint stripes, slight transparency, drawn 4× and scaled down for smooth rotated edges |
| Diamond dot | `DiamondDot.qml` | Small rotated square used as a bullet / gem |

---

## 8. Buttons and states

### 8.1 Kinds

| Kind | Example | Size |
| --- | --- | --- |
| Bar pill | weather, clock, plugin entries | 36 + 4 tall, content + 28 wide (Capsule + 20); standing: 52 wide |
| Bar key | workspace badges | 36 idle, 42 active (zooms; neighbours shift 3 px away) |
| Keycap (wide) | `DiscordKey`, AniList `Key` | 30 + 4 tall, icon + word |
| Quick Panel key | `QuickToggle` | wide 200 × 73, round 74 × 73, square 73 × 73 (radius 30) |
| Settings tile | `SekaiTile` (`SettingToggle`, `SettingAction`, `SettingStepper`) | leaning plate, diamond icon badge, name + second line; 3 across a card |
| Segmented switch | `SegmentSwitch` | pill track `surfaceHover`, mint thumb that slides with overshoot |
| Choice chips | `SettingChoice` | row of chips with optional preview glyphs (`edge`, `variant`) or icons |
| Text link | "Sign out" | `inkSub` → `ink` + underline on hover |

### 8.2 States

| State | How it looks | Numbers |
| --- | --- | --- |
| Rest | Raised: shadow visible under the cap | `shadowOffset` 4 |
| Hover | Fill → `surfaceHover` (on a white button: `surfaceTint`); pointer cursor; hover tag after a moment | colour 120–150 ms |
| Pressed | Cap drops onto its shadow | 80 ms `OutQuad` |
| Released | Springs back past rest and settles | 260 ms `OutBack`, overshoot 2.2 |
| On / active | Accent gradient fill (Quick Panel: inside a 9 px white ring, 5 px outline, bigger shadow); a popup's pill is held **pressed** while its popup is open | slide 170 ms |
| Danger-on | `#ed4245` fill, white ink | — |
| Wants a look | `warnFill` amber, `colBorder` ink | — |
| Attention | A coral dot breathes on the item (tray: an app needing attention) | scale 1.0 ↔ 1.35, 600 ms `InOutSine`, looping |
| Busy | Icon becomes a spinning `progress_activity` (or the module's icon spins) | 800–900 ms per turn |
| Live | Dot breathes | opacity 1 ↔ 0.45, 700 ms `InOutSine` |
| Disabled | 45 % opacity, no pointer, no press | — |
| Changed elsewhere | A Settings tile pulses by itself when its value changes without a click | — |

### 8.3 Click conventions in the bar

- **Left** opens / closes the module's popup (or does its one action: the clock does nothing, the
  notification bell opens the Quick Panel). For plugins the left button is always the shell's.
- **Right** is the module's secondary action (deafen, recheck updates, refresh AniList).
- **Middle** is a quick toggle or "open the app" (mute; open AniList).
- **Wheel** works where a scroll-hint marker (`ScrollHint`, `unfold_more`) is shown: workspaces,
  media volume, tray icons. One notch = `wheelStep`; touchpads follow the fingers.
- Any press hides the hover tag until the pointer leaves and comes back.
- **Escape** closes a popup; other keys go to the card's `keyed(event)`.

---

## 9. Motion

### 9.1 Principles

1. **Overshoot coming in, accelerate going out.** Entrances use `Easing.OutBack`; exits use
   `Easing.InCubic` and are about half as long.
2. **Grow from the source, shrink back into it.** The transform origin is the thing that caused
   the change (the pill, the button), even when that point lies outside the moving item.
3. **Don't fade out in place.** Fade in a touch at the start of a pop; leave by shrinking.
4. **Two fixed animations, not a Behavior with a flipping easing.** When direction matters, start
   `popIn` or `swallow` from the change of the flag; both begin from the current value, so reversing
   halfway just turns around (`SekaiPopup`, `PresetMotion`, the clock's reveal).
5. **Don't animate at start-up.** Windows built while hidden simply appear in place (`animReady`
   becomes true ~600 ms after the window is visible).
6. **One popup at a time.** Opening another first puts any still-shrinking card away at once
   (`PopupHandoff.qml`).
7. **Cheap while idle.** Decoration is drawn once (Canvas) and only redrawn when its size or colour
   changes; continuous animations run only while visible (`running: open || reveal > 0`).

### 9.2 Duration and easing tokens

| Token (in use) | Duration | Easing | Where |
| --- | --- | --- | --- |
| press | 80 ms | OutQuad | Every block's cap |
| release | 260 ms | OutBack 2.2 | Every block's cap |
| pop in | 340 ms | OutBack 1.3 | Popup cards, list stagger driver |
| swallow | 170 ms | InCubic | Popup cards back into the pill |
| settle | 80 ms | — | Empty frames kept after a card is gone |
| style glide | 180 ms | OutQuad | Bar radius / inset / background when the style changes |
| colour | 150 ms | linear | Fills, ring gradient stops |
| hover colour | 120 ms | linear | Row and pill hovers, tag fade |
| reveal (pill appears) | 260 ms | OutCubic | Discord / privacy / updates pills opening their slot |
| workspace zoom | 260 ms | OutBack 1.2 | Active badge grows, neighbours shift |
| dot press | 70 / 200 ms | OutBack 2 | Capsule workspace dots |
| tray icon pop | 170 ms (+70 delay) | OutBack 1.5–2.0 | Pinning an app; leaving: 110–120 ms InCubic |
| segment thumb | 280 ms (label colour 140) | OutBack 1.8 | `SegmentSwitch` |
| sticker hop | 340 ms | OutBack 2.4 | `StickerText` on a new value |
| progress fill | 420 ms | OutBack 1.4 | Progress bars moving |
| auto-hide | 220 ms | OutCubic in / InCubic out | Bar sliding off its edge; 450 ms grace before hiding |
| preset slide | out 190 ms InCubic, in 380 ms OutBack 1.1 | — | Bar and dock leave and return while a preset is worn |
| breathing | 700 ms ×2 | InOutSine | Live dots |
| attention | 600 ms ×2 | InOutSine | Coral dot on a tray item needing attention |
| phone route | 200 ms | — | Quick Panel page changes |
| phone flip | 200 ms (ring 380) | InOutBack | Quick Panel → Settings rotation (winds up the wrong way, turns, overshoots) |
| phone launch | in 340 / tilt 460 / out 300 ms | — | Opening an app from the phone |
| phone buzz | 2 × 340 ms, gap 130 | — | A notification arriving |

### 9.3 Choreography

- **Stagger**: drive children from one 0 → 1 value (`enter`, run with the pop-in curve) and give
  each a local progress `clamp(enter × 1.6 − index × 0.12…0.14)`. Rows fade in and slide 16–18 px
  from the left. Leave `enter` at 1 on the way out so rows stay put while the card shrinks.
- **Slot reveal**: a pill that comes and goes (privacy, Discord, updates, the tray) animates its
  layout width with `reveal` and gives back the layout gap with a negative margin at the same pace,
  so its neighbours glide instead of jumping.
- **Hand-off**: a reveal that overshoots past 1 is allowed (`reveal` is public on `SekaiPopup` so a
  card can key springs and cascades to it).

---

## 10. Transitions

| Transition | Behaviour |
| --- | --- |
| **Popup open / close** | The card scales from 0 at the centre of its pill (even though that point is outside the card) to 1 with overshoot, fading in over the first eighth. Closing, it scales all the way back into the pill. The window stays mapped a few frames empty so the compositor never freezes a half-card. |
| **Bar style change** | Radius, inset and background opacity glide (180 ms); Transparent fades the background out; Capsule cross-fades its own layer. |
| **Bar edge change** | The window is rebuilt on the new edge (never re-anchored live). During a preset it slides off (190 ms) and the new one slides in (380 ms, overshoot). |
| **Auto-hide** | Slides off its edge past its own shadow, back while the pointer touches the 3 px edge strip, a popup is open, in Edit Desktop, or for 2 s on `ipc call bar peek`. |
| **Wrapping** | A flat bar too narrow for its modules grows a row (after 250 ms of stable need) and loses it only with 32 px to spare, so it never flickers. |
| **Quick Panel** | The phone bounces up from the bottom edge; a new notification makes it rise only far enough to show it; Settings rotates the same phone into landscape. |
| **Wallpaper** | Shader transitions in theme colours: Ring, Iris, Star (it spins), Blocks, Flash, Fade, Random. The bands cover the desktop, then reveal the new picture. The same transition plays into and out of the lockscreen. |
| **Edit Desktop** | The whole desktop shrinks into a card (`EditStage`) inside a full-screen editor built from the same blocks. |
| **Things turning on / off** | Widgets pop up when switched on and are swallowed when switched off. |

---

## 11. Components

Grouped by where they live. "File" is under `sekaipop/modules/` unless noted.

### 11.1 Shared widgets (`common/widgets/`)

| Component | Purpose | Key properties |
| --- | --- | --- |
| `Pill` | The block (section 7) | `fillColor`, `fillGradient`, `cornerRadius`, `ringWidth`, `innerRing`, `pressed`, `shadowDx/Dy`, `capRim`, `capKeepsFill`, `flat`, `bare`, `barVWidth` |
| `MaterialIcon` | One icon (section 5) | `name`, `size`, `fill`, `color` |
| `SekaiPlate` | Popup header plate: gradient slab on the block with halftone + light bands; children unclipped | `colorTop/Bottom`, `cornerRadius` 16, `ringWidth`, `dotColor`, `bandColor`, `dotCorner`, `pressed` |
| `StickerText` | Text as a sticker, hops on change | `text`, `pixelSize`, `fillColor`, `outline`, `ring`, `shadowDx/Dy`, `popOnChange` |
| `Slant` | Leaning rounded rect | `skew` 0.2, `radius`, `color`, `borderColor`, `borderWidth`, `gradient` |
| `SegmentSwitch` | Sliding choice | `options`, `current`, `picked(id)` |
| `DotField` | Halftone | `dotColor`, `spacing`, `maxRadius`, `corner`, `reach` |
| `WashiTape`, `FilmStrip`, `CorkBoard`, `FramedImage` | Scrapbook pieces | — |
| `SekaiScrollBar` | Thin scroll thumb for a Flickable | `margin` 8, `inset` 2 |
| `WheelScroll` | Uniform wheel / touchpad scrolling over a Flickable | `scroller` |
| `SearchPill` | The launcher's search field on the block | — |
| `ScaleHost` | Draws design pixels at the monitor's scale | `factor` |
| `ShellBadge`, `DiamondDot`, `Burst`, `InnerRing`, `RoundClip` | Small marks and helpers | — |

### 11.2 Bar (`sekai/bar/`)

| Component | What it shows |
| --- | --- |
| `Status_Bar` | The bar's picture: background per style, three zones, every module (pure UI) |
| `Bar` | The bar's window: data sources, popups, edge, auto-hide, scale, input mask |
| `WorkspaceBadges` | Numbered keys (Capsule: dots); active zooms 36 → 42 |
| Active Window | Gradient pill, app over title (standing bar: `ActiveWindowKey`, an icon key) |
| `MediaPill` | Cover, title / artist, optional visualizer (`PillBars` / `PillWave`); grows between min and max width |
| `StatusPill` | Wi-Fi / Bluetooth / speaker icons |
| `WeatherIndicator`, `DateIndicator`, clock | Chip pills |
| `TrayCollection` | Pinned tray icons + the dropdown arrow, one pill |
| `PrivacyIndicator`, `DiscordPill`, `UpdatesBadge` | Pills that reveal only when they have something to say |
| `UtilButtons` / `UtilKeys` | A pill of small keys (screenshot, colour picker...); standing bar: one tools key + flyout |
| `ResourceIndicator`, `BatteryIndicator`, `KeyboardLayoutIndicator`, `NotificationBadge` | Small pills |
| `PluginBarItem` | A plugin's entry: the shell's pill around the plugin's `Bar.qml` |
| `BarTip` | Hover tag: its own click-through popup window; `colBorder` label, radius 8, white 11 px DemiBold, 16 × 10 padding, 10 px from the module, opens toward the screen's inside |
| `SekaiPopup` | The popup frame: placement on any edge, focus grab, pop / swallow, Escape |
| `SectionTab` | Slanted section heading |

Popups built on `SekaiPopup`: Calendar, Weather, Battery, Media (turntable), Equalizer (centred,
bare console), Discord, Resources, Util flyout, plugin popups.

### 11.3 Quick Panel, Settings, others

| Component | File | Notes |
| --- | --- | --- |
| `QuickToggle` | `sekai/quickPanel/` | Wide / round / square keys; OFF white 3 px outline, shadow 3 right 1 down; ON accent gradient in a 9 px white ring, 5 px outline, shadow 5 right 2 down; changes slide (170 ms) |
| `SekaiTile` | `sekai/quickPanel/` | Leaning Settings tile with a diamond badge; lights with a wipe of the accent gradient |
| `SettingToggle` / `SettingChoice` / `SettingSlider` / `SettingStepper` / `SettingAction` / `SettingText` | `sekai/settings/` | The Settings vocabulary; a page lays tiles three across |
| `SectionCard` | `sekai/settings/` | Card holding a `Flow` of tiles; radius 30, 3 px outline, shadow in `pLineShadow` |
| Dock | `sekai/dock/` | Housing + keys; styles mirror the bar's (Capsule keys are `flat`, Transparent are `bare`) |
| Edit Desktop | `sekai/editMode/` | Full-screen editor of blocks: shelf tabs Widgets, Bar, Dock, Views, Theme, Presets |

---

## 12. The bar

### 12.1 Styles (`BarStyleService`, Settings → Bar → Style)

| Style | Look | Strip reserved |
| --- | --- | --- |
| Float (0) | Rounded housing (13), inset 16 from the screen edges | 63 flat / 74 standing |
| Straight (1) | Flush, side outlines pushed off screen | same |
| Transparent (2) | No housing: pills straight on the wallpaper; windows sit closer (gaps_out + 5 trimmed) | same, minus trim |
| Capsule (3) | Slim fully rounded bar, dots and flat chips | 55 flat / 72 standing |

### 12.2 Zones

`left` (start of the bar / top of a standing one), `center` (dead centre, never drifts), `right`
(end / bottom). Where each module sits is `BarLayoutService` (shared, or per monitor with
`bar.perMonitor`); edited in Edit Desktop's BAR tab or `ipc call barlayout move <id> <zone> <i>`.

### 12.3 Per monitor (Settings → Bar → This monitor)

Each monitor can, on its own (`bar.screens`, `BarPositionService.screenPrefs`):

| Choice | Effect | IPC |
| --- | --- | --- |
| **Bar on this monitor** | Off: no bar window there (other monitors keep theirs) | `barposition hidescreen <output> true` |
| **Edge here** | Its own edge, or "Same" to follow the shell-wide Position | `barposition setscreen <output> left` (`default` to follow) |
| **When it doesn't fit** | **Wrap** (default): a flat bar too narrow for its modules grows rows; **Overlap**: one row, as before | `barposition wrapscreen <output> auto\|off` |

Wrapping, on a flat bar:

```
1 row    [ left ............. center ............. right ]     everything fits
2 rows   [ left ................................... right ]     the centre zone moves under
         [               center                          ]
3 rows   [               left                            ]     one zone per row, each centred
         [               center                          ]     (a zone alone on its row is
         [               right                           ]      centred: a column, not a staircase)
```

Rows are 48 apart (Capsule 30). Whether a row fits is measured with widths that don't depend on
the rows (media pill at its 220 minimum, the active window at its cap), so a long song title never
reshapes the bar. The window, its reserved space, popups, the OSD, notifications and the dock all
follow the taller bar (`BarPositionService.thicknessOn(output)`). A standing bar never wraps; on a
short screen it folds its utility keys into a tools key and drops CPU/RAM and weather first.

---

## 13. Layout, scale and responsiveness

- **Design pixels everywhere.** Lay out in design pixels; `ScaleHost` applies the monitor's scale.
  Only pixel-exact images need the scale (`host.scale` for plugins).
- **Popups follow the bar to any edge** (`Bar.popupX / popupY / popupGravity`); the card's flat side
  faces the bar, and the bleed room is on the other three sides.
- **Long text elides, it doesn't grow without bound.** Active Window caps at 260 (or 14 % of the
  bar); the media pill at 300 and never more than the room its row leaves.
- **Standing bars stack**: icon over a short text (`host.bar.vertical` for plugins).
- **Narrow flat bars wrap** (12.3). Before wrapping existed, the three anchored zones simply slid
  over each other on a portrait screen.
- **Narrow screens stack, they don't squeeze.** Edit Desktop's shelf folds its side columns
  (title + how-to, tabs, Lock all / Done) into rows above a full-width content area under 1400
  design px, and gives the tabs a row of their own under ~1040 (`EditMode.compactShelf` /
  `compactTight`). Keys keep their size and construction; the cost is height, which a portrait
  monitor has to spare. Help keeps its order and place in every layout.
- **Lists scroll inside their card** after five rows (`Flickable` + `WheelScroll` +
  `SekaiScrollBar`); a popup is at most 70 % of the screen tall.

---

## 14. Legibility and accessibility

- Keep body text ≥ 11 px and labels ≥ 10 px (7 px exists only as the second line of a two-line pill).
- Ink pairs in [3.5](#35-colour-rules) keep contrast in all three modes; check new colours in Light
  **and** Darker, the two extremes.
- Monochrome must still read: anything distinguished only by hue needs a second cue (shape, label,
  position). `attributeColors` alternate light and dark greys there for this reason.
- Every clickable thing has `cursorShape: Qt.PointingHandCursor` and a hover change.
- Information shown as an icon gets words in a hover tag (`BarTip`), e.g. "Microphone in use by: …".
- Popups close on Escape and on a click anywhere else.
- Don't rely on hover alone for an action: hover only reveals; clicks act.

---

## 15. Recipes

### 15.1 A block button in shell code

```qml
Item {
    id: key
    readonly property var mt: Theme.of(QsWindow.window)
    signal clicked()
    implicitWidth: 120
    implicitHeight: 30 + mt.shadowOffset

    Pill {
        anchors.fill: parent
        cornerRadius: 10
        ringWidth: mt.borderWidth + mt.whiteLine
        fillColor: area.containsMouse ? mt.surfaceHover : mt.surface
        pressed: area.pressed

        MaterialIcon { anchors.centerIn: parent; name: "refresh"; size: 16 }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: key.clicked()
    }
}
```

### 15.2 A popup card

```qml
SekaiPopup {
    id: root
    contentWidth: 336
    contentHeight: col.height + 28

    property real enter: 0
    onOpenChanged: if (open) enterAnim.restart()
    NumberAnimation { id: enterAnim; target: root; property: "enter"; from: 0; to: 1
                      duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.3 }

    Column {
        id: col
        x: 16; y: 14; width: 304; spacing: 10
        SekaiPlate { width: col.width; height: 82 + mt.shadowOffset /* ... */ }
        SectionTab { text: "Forecast" }
        // rows: opacity: local; x: (1 - local) * 16
    }
}
```

### 15.3 From a plugin (no `qs.*` imports)

Plugins rebuild the block from `host.theme` (see `plugins/anilist/Key.qml` and `Plate.qml` for
complete examples): a `lineShadow` rectangle at `y: shadowOffset`, then a cap with a `ringWhite`
rectangle bordered `borderWidth` in `line`, then the fill inset by `borderWidth + 2`; the cap's `y`
animates 80 ms OutQuad down / 260 ms OutBack 2.2 up. Use `host.bar.ink` inside a bar entry.

---

## 16. Do and don't

| Do | Don't |
| --- | --- |
| Hard shadow straight down in `lineShadow` | Soft / blurred / black shadows, glows |
| Outline every block in `line` at `borderWidth` | Borderless floating panels |
| Read colours through `mt` | Hard-code hex values (except the fixed set in 3.3) |
| Grow from the source, shrink back into it | Fade a card out in place |
| OutBack in, InCubic out | Linear or symmetric eases for entrances |
| Short labels, `·` between facts | Sentences in pills |
| `font.weight` **and** `font.styleName` for bold | Weight alone on the variable font |
| Elide with fixed line boxes | Let a title grow a pill without bound |
| Amber for "look", red for "harm", words for errors | Red error banners |
| Decoration printed on blocks, drawn once | Animated decoration running while hidden |
| One popup at a time | Stacked popups |
| Design pixels inside `ScaleHost` | Multiplying sizes by the scale by hand |

---

## 17. Token reference

Every name in `ThemeSet.qml`, grouped. ★ = promised to plugins (`docs/PLUGINS.md`).

- **Palette passthrough**: `pal`, `mono`, `colBorder`★, `colBg`, `accentCyan`★, `accentMint`★,
  `textWhite`, `colDeep`, `colHoverTint`, `colOuterRing`, `colHover`, `colDivider`, `colSubText`.
- **Mode**: `mode`, `dark`★, `darker`, `classic`, `quickFlat`.
- **Surfaces**: `surface`★, `surfaceHover`★, `surfaceDivider`★, `surfaceTint`, `surfaceRing`★,
  `ringWhite`★, `paper`, `paperHover`, `paperEdge`, `scrim`.
- **Ink and lines**: `ink`★, `inkSub`★, `line`★, `lineShadow`★.
- **Chips and status**: `chipFill`★, `chipInk`★, `warnFill`★.
- **Classic family**: `pSurface`★, `pSurfaceHover`★, `pSurfaceDivider`★, `pSurfaceRing`★,
  `pRingWhite`★, `pLine`★, `pLineShadow`★, `pInk`★, `pInkSub`★.
- **Capsule**: `capBarHeight`, `capBarFace`, `capRimWidth`, `capShadowDy`, `capEdgeGap`, `capStrip`,
  `capPadX`, `capGap`, `capDotFill`, `capDotRing`, `capDot`, `capDotActive`, `capChipHeight`,
  `capClockSize`, `capVChip`, `capVPadX`, `capVPadY`, `capVBarFace`, `capStripV`, `capBody`,
  `capRim`, `capShade`, `capChip`, `capInk`, `capLit`, `capLitSoft`, `capWsColors`.
- **Shape**: `pillHeight`, `radiusOuter`★, `radiusBadge`, `borderWidth`★, `whiteLine`,
  `shadowOffset`★, `cardRing`, `outerRingWidth`, `barVBody`, `barVPillWidth`, `barFloatInset`.
- **Type**: `fontFamily`★, `fontSize`, `fontStyleBold`★, `fontSizeTitle`, `fontSizeSub`,
  `fontSizeIdle`, `fontSizeInfo`, `fontSizeMenu`, `menuRowHeight`.
- **Icons**: `iconFont`★, `iconFill`, `iconStyle`, `iconWeight`, `settingsIconWeight`.
- **Phone**: `phoneRimHighlight`, `phoneBezel`, `phoneRimWidth`, `phoneBezelWidth`,
  `phoneScreenInset`, `phoneCornerRadius`, `phoneWallLight/Mid/Dark`, `phoneHardware`, `phoneLens`,
  `phoneLensGlint`.
- **Misc**: `attributeColors`, `wheelStep`, `wheelPx()`, `settingsLean`, `irisColor*`,
  `transitionColors()`, `classicFor()`, `capsuleFor()`, `capsuleVerticalFor()`, the light / dark
  tuning factors (3.2).

---

## 18. File map

| File | Holds |
| --- | --- |
| `modules/common/ThemeSet.qml` | Every colour formula, size, font |
| `modules/common/Theme.qml` | The shell's theme and `Theme.of()` per monitor |
| `services/ThemeService.qml` | Palettes, modes, matugen, custom palette |
| `modules/common/ScrapbookTheme.qml` | Paper / cork / tape colours |
| `modules/common/PresetMotion.qml` | Preset slide timings and flags |
| `services/PopupHandoff.qml` | One popup at a time |
| `modules/common/widgets/Pill.qml` | The block |
| `modules/common/widgets/MaterialIcon.qml`, `functions/IconMap.js` | Icons |
| `modules/sekai/bar/SekaiPopup.qml` | Popup frame and its motion |
| `modules/common/widgets/SekaiPlate.qml`, `StickerText.qml`, `Slant.qml`, `DotField.qml` | Printed decoration |
| `modules/sekai/bar/Status_Bar.qml`, `Bar.qml`, `BarWrap.js` | The bar, its zones, wrapping |
| `services/BarPositionService.qml`, `BarStyleService.qml`, `BarLayoutService.qml` | Edge (and per monitor), style, layout |
| `modules/sekai/quickPanel/QuickToggle.qml`, `SekaiTile.qml` | Phone keys and Settings tiles |
| `docs/PLUGINS.md` | The plugin interface and the promised theme names |
| `plugins/anilist/` | A complete bar plugin built on this system |
