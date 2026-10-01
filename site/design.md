# Handoff: atrium.show website

## Overview
Design directions for the website of Atrium, a free, open-source menu bar app that plays living, animated wallpapers behind the macOS desktop. Domain: atrium.show. The site is a gallery first and a product page second: the wallpapers are the art, and the art is the page.

Nine directions were explored across three rounds, plus a revisions block. **No direction has been chosen yet.** Read the directions, pick one with the owner (or build the shared foundation first, see "Suggested build order"), then implement it.

Source repo for the app: https://github.com/dtanquary/atrium (Swift + SpriteKit/Metal, MIT). The website is a separate deliverable; it does not need to live in that repo.

## About the design files
The `.dc.html` files in this bundle are **design references drawn in HTML**: static frames showing look and layout, plus written notes on motion. They are not production code and should not be shipped. Recreate the chosen direction in whatever stack fits a small static site (plain HTML/CSS/JS, Astro, or similar). The frames are the spec for layout, type, colour and copy; the motion notes are the spec for behaviour.

The files open directly in a browser. Each one is a pannable canvas of frames: desktop frames at 1440×900 drawn at half size, phone frames at 390×844 at three-quarter size. Every frame's caption states the share of the viewport that is art.

## Fidelity
**High fidelity** for layout, type, colour, copy and spacing. Treat positions, sizes and hex values in the HTML as the intended values (read them off the inline styles; they are all in the frame markup). Motion is specified in writing only, with durations; easing and implementation are the developer's call within the rules below.

## Hard rules (from the owner's brief)
1. **The art fills the screen.** In every state, the wallpaper covers at least 80% of the viewport, edge to edge. When in doubt, make the art bigger and use fewer words. The only sanctioned exception is the opening frame of The Skylight (2c), which is dark by design.
2. **No decoration.** No gradient blobs, glows, glass/blur cards, noise, 3D, icons as ornament, stock photos or generated imagery. Only the uploaded renders, the Settings window render and the app icon.
3. **Ground is near black:** `#0A0A0B`. The single accent colour is sampled from whichever wallpaper is on screen (see Design tokens) and crossfades with the art.
4. **Type is quiet and small**, like museum wall labels. One typeface per direction, a variable font under the SIL Open Font License, self-hosted (download from Google Fonts; do not use the Google Fonts CDN in production).
5. **Calm motion.** Transitions are slow crossfades of 1 s or more. Never hard cuts, bounces, springs or parallax. Respect `prefers-reduced-motion`: show the same states without animation.
6. **Only the copy below.** Do not invent features, reviews, quotes or numbers. Two directions (3a Verso, 3b Provenance) quote the app's source code and its comments; that text comes from the repo, not the copy list, and the owner should approve each quoted passage before it ships.

## Copy (verbatim; do not rewrite)
- Atrium
- Living wallpapers for your Mac.
- Download · Free · macOS 26 or later, on Apple silicon · Source on GitHub (MIT)
- Wall labels (title: medium · line):
  - Nebula: Shader · a new nebula every time, in colours modelled on real ones
  - Flowing Gradient: Shader · pools of colour whose mood follows the real Sun
  - Live Sky: Live · the real sky above you, right now
  - Galaxy: Shader · after real galaxies: the Whirlpool, Andromeda, the Milky Way
  - Murmuration: Simulation · tens of thousands of starlings at sunset
  - Fish Tank: Real fish, cut out of photographs, in a sunlit reef tank  (no medium word; the whole line is the label)
- It's your desktop: it plays behind your icons and windows, and pauses when they cover it.
- Easy on your Mac: frozen in Low Power Mode, about 2 ms a frame.

Only the six works with wall labels appear on the site. The other renders in `uploads/` (aurora, earth, rain, pillars, dappled light) have no copy and were deliberately left out.

## Design tokens

### Colour
- Page ground: `#0A0A0B`
- Strip divider / wall edge hairline (revision R3): `#1C1C20`, 1 px, below very dark works only
- Primary text: `#EEEDE9` (sans directions) or `#F2F1EE` (2b, 3c)
- Secondary text (label lines): `#C9C8C4` or `#A8A7A3`
- Tertiary text (fine print, inactive index items): `#8B8A86`, `#9A9995`, `#77767A`
- Accents, one per work. Measured from each render's pixels: dominant hue, lifted to oklch L 0.82, C ≤ 0.11 so it reads above 11:1 on the ground.
  - Nebula `#95D0D9`
  - Flowing Gradient `#CAB9F3`
  - Live Sky `#B9C2EC`
  - Galaxy `#DDBE9A`
  - Murmuration `#ECB799`
  - Fish Tank `#9BC5FF` (lifts to `#C8DFFF` when text sits over the water or sand, to hold 4.5:1)
- During a crossfade the accent interpolates between the two works' accents in oklch (hue the short way round). Sample midpoints used in the frames: Galaxy→Murmuration `#E5BB98`; Nebula→Galaxy `#B9C7BA`; Fish Tank→Flowing Gradient `#B4BFFA`; Galaxy→Live Sky `#CCC0C4`; Murmuration→Live Sky `#D3BFC3`.
- Accent text on the art must stay ≥ 4.5:1 against the pixels behind it; adjust lightness per placement, not hue.

### Type (one per direction; all variable, OFL, on Google Fonts)
- 2a The Exhibition: Instrument Sans
- 2b One Endless Canvas: Figtree
- 2c The Skylight: Newsreader
- 2d The Still Room: Geist Mono
- 3a Verso: JetBrains Mono
- 3b Provenance: Source Serif 4
- 3c Credit Line: Hanken Grotesk
- 3d The Day: Literata
- 3e The Monitor Wall: Schibsted Grotesk

Scale at 1440 wide: wordmark 15–18 px (600 in sans, 400 in serif); work title 15–22 px; medium word 11–12 px, uppercase, letter-spacing 0.10–0.14 em, in the accent; label line 13–16 px (italic in the serif directions); fine print 12–13 px; tagline 20–26 px light (300) in 2b/3c, italic in serif directions. Code in 3a: 12 px, line-height 1.65. Phone sizes are the same or 1–2 px smaller. Nothing is bold above 600.

### Spacing
- Desktop margins: 56 px (floating-label directions), 40–48 px (strip directions); top bar at y = 36 px
- Phone margins: 24 px; top bar at y = 28 px
- Label strip heights: 80 px (2a), 63 px (2d), 48 px (3e), 104 px (3b), 100 px (R1 stacked label)
- Download section strip: 140–160 px
- Phone label band: 120–154 px
- Monitor wall gutters: 2 px of ground

### Radius and shadow
None, except the skylight opening in 2c (20–26 px at the start, flattening as it widens) and the Settings window render in 2d (14 px). No shadows anywhere.

## Images: art rendering rules
- Renders are 16:10 JPEGs. Display with `object-fit: cover` (or `background-size: cover`), never letterboxed, never scaled up past the viewport.
- Portrait crops for phones: the frames use a horizontal focal point per work, given as a background-position percentage. Nebula 54%; Flowing Gradient 34%; Live Sky 72%; Galaxy 48%; Murmuration 64–66%; Fish Tank 42%. Implement with `object-position` so the crop follows the viewport.
- The frames use the JPEGs as stand-ins. In production the works should be the real animated wallpapers rendered in the browser (WebGL/WebGPU ports of the shaders, or looped video captures). Which to use is an open decision; design-wise the page must never show a hard cut, including on first paint (fade the first work up from the ground over ≥ 1 s).
- Pause rendering when the tab is hidden; this mirrors the app's own behaviour.

## Shared behaviours (all directions)
- **Crossfade between works**: outgoing work fades to the ground over ~1.2 s while the incoming fades up over ~1.6 s, overlapping so the screen never goes fully black; the label fades a half-beat (~0.4 s) behind the art; the accent interpolates across the full duration.
- **Download** is a text link (no button chrome), in the accent, with a 1 px underline in the accent on the download section only. It links to the latest GitHub release. "Source on GitHub (MIT)" links to the repo.
- **Scroll** is native; no scroll-jacking. Directions that snap to rooms (2a, 3b, 3d) use CSS scroll-snap with `proximity`, not `mandatory`.
- **Keyboard**: arrow keys or Page Up/Down move between works where the direction has rooms; the index items in 2d/3e are real links/buttons.
- **Responsive**: the frames show 1440 and 390. Between them, keep margins and type fixed and let the art scale; below ~700 px wide, switch to the phone layout.

## Directions

### Round 1 (Atrium Website Directions.dc.html, ids 1a–1d)
Superseded by round 2. Kept for reference only; the accents here were guessed, not measured.

### Round 2 (Atrium Website Directions v2.dc.html, ids 2a–2d)

**2a The Exhibition** (Instrument Sans). Gallery walk. Each work is one viewport-height room: art fills the top 820 px, an 80 px strip at the bottom holds the wall label (title, medium, line in a row) with Download at the right. Scroll moves room to room; the work dims to the wall over 1.2 s and the next rises over 1.6 s. Download section is the last room: art 760 px, 140 px strip in three columns (wordmark + tagline / the two feature lines / Download + fine print, right-aligned). Phone: art 724 px over a 120 px label band.

**2b One Endless Canvas** (Figtree). One fixed, full-bleed canvas that never moves. Scroll position drives the crossfade: a full viewport of scrolling equals one dissolve from work to work. Only the words travel: each label (top-left of lower half, x = 56) drifts upward and fades as the user scrolls past. Wordmark top-left, Download top-right at y = 36. Download section: tagline and link at top-left, the two feature lines top-right, over the last work (Fish Tank). Phone: full-bleed, labels at y = 130.

**2c The Skylight** (Newsreader). Opens in darkness on a four-paned square opening (780 × 780 at 1440 wide, 20 px radius, 6 px mullions in the ground colour) showing the first work. The first scroll widens the opening until its edges leave the viewport and the mullions dissolve; the art behind never moves or scales. Between works the cross returns faintly (4 px, 35–60% opacity) while one work crossfades to the next over 1.6 s, then fades again. Labels bottom-left. Download section: the app icon (96 px), wordmark, tagline, Download, fine print and feature lines centred over Live Sky. Phone: 334 × 334 opening at y = 150.

**2d The Still Room** (Geist Mono). The page behaves like the desktop it sells: the first screen never scrolls away; works change on their own, each holding ~40 s before a 2 s crossfade. Art fills the top 836 px; a 1 px hairline (`#26262A`) with an accent-coloured fill that grows left to right toward the next change; a 63 px strip below with wordmark + tagline (replaced by the current work's label once the first change happens), an index of the six titles (current one in the accent), and Download. Choosing a title starts the same crossfade at once. One scroll reaches the download section: the current work keeps playing; the Settings window render (420 × 328, 14 px radius) sits over it at right, the copy at left. Phone: 700 px art, 143 px strip, index wraps or scrolls sideways.

### Round 3 (Atrium Website Directions v3.dc.html, ids 3a–3e, 3r)

**3a Verso** (JetBrains Mono). Each work hangs face-up with label bottom-left. Press-and-hold (or a sustained scroll past the midpoint) turns it over: the art dims to ~28% over 1.5 s while the source file that draws it fades in on top (12 px mono, 1.65 line height, comments in `#A3A29E`, code in `#E6E5E1`, file path + "MIT" in the accent). Release and it turns back over 1.5 s. The art never leaves the screen. Frames show Galaxy's `kinds` table (Sources/Atrium/Galaxy.swift) and Nebula's palettes (Sources/Atrium/Shaders.swift). Pull the quoted text from the repo at build time or pin it; do not paraphrase.

**3b Provenance** (Source Serif 4). The Exhibition with a third label line stating where the work came from, as a museum's provenance line does: the star catalogue, the telescope portraits, the file path. Rooms as 2a (art 796 px, 104 px strip). The provenance line arrives 0.4 s after the rest of the label. The lines in the frames were lifted from comments in the source; owner approval needed. Download section as 2a, over Flowing Gradient.

**3c Credit Line** (Hanken Grotesk). One Endless Canvas where every label ends with "Free · Source on GitHub (MIT)" in the accent. It is the one label line that is never grey, and it is the last part of a label to fade and the first of the next to return, so it holds through every crossfade. Download section bottom-left over Nebula, with the full fine-print line.

**3d The Day** (Literata). The opening work follows the visitor's clock: Flowing Gradient in the morning, Murmuration at dusk, Live Sky at night (the thresholds should follow the real Sun at the visitor's location via the Geolocation API with a time-of-day fallback). Label bottom-right with the local time beneath in tabular figures; tagline bottom-left. At the hour's turn, a 2 s crossfade; only the clock stays. Scrolling walks the other works as 2a.

**3e The Monitor Wall** (Schibsted Grotesk). All six works play at once as equal tiles, 3 × 2, edge to edge with 2 px gutters of ground, over a 48 px strip holding wordmark, tagline, the index and Download (grey, no accent, until a work is chosen). Choosing a tile or title grows it from its own position to fill the wall over 1.6 s while the other five dim to 35%; its label takes the strip and the accent arrives. A second choice or a scroll settles it back over 1.6 s. Download section: the wall at 40% behind centred copy. Phone: 2 × 3 tiles.

**3r Revisions** (apply to round 2 and 3 as noted):
- R1 (2a, 3b): stack the wall label (title / medium / line) rather than running it in a row, 100 px strip; remove Download from the rooms, keep it on the opening and the last room only.
- R2 (all openings): include "Source on GitHub (MIT)" on the first screen as part of the fine-print line.
- R3 (2a, 2d, 3b, 3e): a 1 px wall-edge hairline in `#1C1C20` where the art meets the strip, so Live Sky does not vanish into it.

## Suggested build order
1. Shared foundation: ground, one self-hosted variable font, the six works as a `<Work>` component with cover/crop rules and focal points, the accent system (per-work accent + oklch interpolation + per-placement lightness lift), the crossfade primitive (two stacked layers, opacity-driven, ≥ 1.2 s), reduced-motion handling, pause on hidden tab.
2. The chosen direction's layout and scroll model.
3. Download section and links (latest release, repo).
4. Phone layout.

## Assets (in `uploads/`)
Only these may appear on the site.
- Wallpaper renders, 16:10 JPEG: nebula-hubble.jpg, flowing-gradient.jpg, live-sky.jpg, galaxy-whirlpool.jpg, murmuration-blue-hour.jpg, fish-tank-day.jpg. Also present but unused (no copy): aurora-green.jpg, dappled-light-golden.jpg, deep-space-pillars.jpg, earth-from-orbit.jpg, rain-on-glass-night.jpg.
- settings-nebula.jpg: the app's Settings window (used in 2d's download section).
- app-icon.png: the app icon (used in 2c's download section).

## Files
- Atrium Website Directions.dc.html: round 1, directions 1a–1d (superseded).
- Atrium Website Directions v2.dc.html: round 2, directions 2a–2d (current basis).
- Atrium Website Directions v3.dc.html: round 3, directions 3a–3e and revisions 3r.
- support.js: runtime the design files need to render; open the HTML files from this folder.
- github.md: the app repository the designs drew on.
- uploads/: the renders, Settings window and icon.
