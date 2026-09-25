# Aurora

Curtains of northern lights shading through real aurora colours from the lower edge to the crown, with fine vertical rays, folding slowly over a jagged mountain range and snowy foreground drifts under twinkling stars.

- **Files:** `Sources/Atrium/Shaders.swift`. `aurora(size:)` holds the whole shader. It uses the `shaderCommon` helpers `noise`, `hash21` and `starField(pts, cell, density, t)`.
- **Entry:** `@MainActor func aurora(size:)`, which returns `shaderScene(size:source:uniforms:knobs:)`. Registry entry: icon `wind`, tint `.green`.
- **Kind:** a single full-screen SKShader driven by `u_time`. The only Swift-side state is the palette (`auroraPalettes` in Shaders.swift), pinned or rolled when the scene is built.

## How it works
It works in `uv = v_tex_coord` (0–1) and `p = uv * vec2(aspect, 1)`.
1. **Sky.** A gradient from dark teal near the horizon to near-black at the top, plus `starField(uv * u_size, 11, 0.3, t)`: one candidate star per 11 pt cell, 30% of them kept, each twinkling.
2. **Three curtains** (a loop, `i = 0..2`, each further back and dimmer by `1 - 0.25 i`).
   - **Lower edge:** `edge = 0.4 + 0.1i + 0.06·fold + 0.14·(noise − 0.5)`. The fold is two slow sines (0.04 and 0.03 rad/s) and the noise drifts at 0.01, so the curtains fold and ripple without looping.
   - **Light:**
     - a bright rim at the edge, `exp(-|h| * 70)`
     - a body fading upward, `exp(-h * 9)`
     - a violet tail higher up, `exp(-h * 4)` × 0.4
     - a faint glow below the edge
   - **Rays:** noise at 45× horizontal frequency, sheared along the folds (`+ fold * 3`) and drifting at 0.15, shaped by `0.25 + 1.4·rays²`.
   - **Patches:** a slow noise mask (`smoothstep(0.25, 0.7, …)`) so brightness comes and goes along each curtain.
   - **Colour:** a gradient by height above the edge, `ch = h + (0.5 − patch noise) × 0.09`, running from `u_fringe` to `u_body` (−0.01…0.012), then `u_upper` (0.03…0.14), then `u_crown` (0.12…0.3). The patch-noise term reuses the patch noise already computed (so it costs nothing extra) and moves the colour bands up and down along the curtain, so no curtain is a single colour. The fringe transition is kept thin: at 0.03 wide, Storm's pink edge read as a thick stripe.
   - The intensity profile is `((body + rim·0.7 + tail) · rays + below)`, the same shape as before, all tinted by that gradient.
3. **Soft clip.** `1 − exp(−aurora × 0.9)`, so overlapping curtains don't blow out. It fades above `uv.y` 0.6–1.05.
4. **Far range.** Ridged 4-octave noise (`peaks`) makes sharp summits at 0.08–0.40 of the height. Snow near the summits catches a green-tinted light, mottled by noise gullies. It's a hard silhouette with a 0.0015 anti-aliased edge.
5. **Foreground snow.** Rolling drifts at 0.04–0.125 of the height, lit by `u_body` (as are the summits), with a sparkle from a second `starField` (cell 7, density 0.08, 3× faster twinkle). Then dither.

## Time and appearance
All motion comes from `u_time`, so a speed knob needs an integrated `u_phase` (the `LavaLamp` pattern). There is no Light Mode look. The palette is Random by default, so each load rolls a new one, but the layout is the same every time.

## Settings
**Colors:** `aurora.palette`, Random by default. Each palette in `auroraPalettes` has four colours from bottom to top: fringe, body, upper and crown. They're all real emissions or mixes of them, the colours Dave listed after looking it up: green, red, pink, purple, blue, yellow and white.

| Palette | Fringe → body → upper → crown | Real basis |
|---|---|---|
| Green | green → green → green → violet | 557.7 nm oxygen; the original look |
| Storm | pink → green → yellow-green → red | strong display: nitrogen pink edge, 630 nm oxygen red crown |
| Red | green → red → red → deep red | seen from mid-latitudes, where only the high red part rises above the horizon |
| Pink | pink → pink → lilac → violet | nitrogen-rich lower border |
| Purple | magenta → purple → blue-violet → red-violet | nitrogen blue mixing with oxygen red |
| Blue | teal → blue → blue → violet | sunlit nitrogen at the top of a twilight display |
| Yellow | green → yellow-green → gold → red | green and red overlapping |
| White | pale greens and blues | a faint display, too dim for colour vision |

The swatches run crown to fringe, top-left to bottom-right, as the sky does.

- **Look**, the shared grade sliders (`gradeKnobs("aurora")` in Shaders.swift, applied by `grade()` from `shaderCommon` just before the dither). They're live and don't rebuild the scene:

| Key | Label | Range | Default |
|---|---|---|---|
| `aurora.brightness` | Brightness | 0.4–1.5 | 1 |
| `aurora.contrast` | Contrast | 0.5–1.5 | 1 |
| `aurora.saturation` | Saturation | 0–2 | 1 |
| `aurora.hue` | Hue shift | −180–180° | 0 |

The contrast pivot is 0.3, as in Nebula, so the night sky stays black. See `docs/nebula.md` for how the grade works.

Suggested knobs, not built yet:

| Key | Label | Range | Default | Drives |
|---|---|---|---|---|
| `aurora.speed` | Speed | 0–3 | 1 | integrated phase |
| `aurora.stars` | Stars | 0–1 | 1 | star-field strength |


## Tuning constants
- Fold speeds: 0.04 and 0.03. Edge noise drift: 0.01. Ray drift: 0.15. Patch drift: 0.008.
- Ray frequency: 45. Rim sharpness: 70. Body falloff: 9. Tail falloff: 4. Clip: 0.9.
- Peaks: `0.08 + 0.32 × peaks(p.x × 2.2)`.

## Performance
Measured at CPU 0.42 ms and GPU 1.85–1.91 ms per frame (the colour gradient added nothing measurable) (release build, 2x). It's the most expensive GPU scene, at the top of the budget. The cost comes from about 25 noise evaluations per pixel: three curtains of 4–5 noise calls each, two star fields, four-octave peaks and the snow noise. If anything is added, cut first: the second ray-noise octave, the snow sparkle field, or run the curtains at half resolution.

## Gotchas and shortcuts
- The mountains are a flat silhouette with mottled snow, with no per-face lighting (the shaders agent flagged this).
- `u_time` doesn't advance in the render harness.
- Adding a fourth curtain costs roughly 0.4 ms of GPU.

## Dave's feedback and decisions
- It was one of the four scenes Dave picked for the picker's first round (with Flowing Gradient, Rain on Glass and Night Sky, later renamed Live Sky), then built by the shaders agent.
- 2026-09-24, Dave asked for other aurora colours, but "keep it in the realm of what real colors they can be … green, red, pink, purple, blue, yellow, and white". He also asked for "some gradients to it … so you get more than one color in an aurora". Hence four-colour height gradients built from real emissions, and Random as the default.
- The parent agent judged it to read well at launch.

## Ideas / next steps
- **Cycling:** a slow crossfade to a freshly rolled palette and layout every few minutes, like Nebula's self-replacing scene. Roll the fold phases and edge heights per load too.
- **Substorms:** brightness surges and faster ray motion every few minutes, then calm.
- **Terrain:** lit mountain faces, or a still lake mirroring the curtains.
- **Night only:** follow the real Sun (dimmer or absent by day), as Flowing Gradient's mood does.

## Checking it
`SNAPSHOT_SCENE="Aurora" SNAPSHOT_DEFAULTS="aurora.palette=Storm" SNAPSHOT_DIR=/tmp/aurora swift test`. `SNAPSHOT_SECONDS` doesn't move shader time. For other moments, temporarily offset `t` in a scratch copy, as the shaders agent did for its +60 s and +300 s checks.
