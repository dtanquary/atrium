# Aurora

Curtains of northern lights shading through real aurora colours from the lower edge to the crown, with fine vertical rays, folding slowly under twinkling stars over a real snowy range: a photo of the Tetons in winter, relit as a long exposure by the aurora's own light.

- **Files:** `Sources/Atrium/Aurora.swift` (the palettes, the sky shader and the ground), plus `Resources/aurora-ground.heic` and `Resources/aurora-ground-aux.png`. The shaders use the `shaderCommon` helpers `noise`, `hash21`, `starField(pts, cell, density, t)` and `grade`.
- **Entry:** `@MainActor func aurora(size:)`, which builds `shaderScene(size:source:uniforms:knobs:)` for the sky and adds the ground sprite from `auroraGround`. Registry entry: icon `wind`, tint `.green`.
- **Kind:** a full-screen SKShader for the sky, driven by `u_time`, under a photo sprite with its own shader for the ground. The only Swift-side state is the palette (`auroraPalettes`), pinned or rolled when the scene is built.

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
4. **Ground.** A photo of the Tetons from Teton Point in winter (NPS photo by A. Falgoust, public domain, 6000×4000, a soft day under thin high cloud): snow flats, a dark band of spruce, then the jagged range. It's drawn as its own sprite over the sky, full width, with its highest summit at 0.42 of the screen height (the skyline runs 0.30–0.42) and its bottom cropped by the screen.
   - **Baked offline** (the research agent's `bake.py`, in the scratchpad): sky cut out with a soft, decontaminated edge; the photo's own haze removed by its depth; its daylight flattened (divided by blurred brightness^0.2); white-balanced so the median snow is 0.85 and desaturated to 30%. What's left is roughly albedo, stored sRGB at half scale (snow ≈ 0.42) so nothing clips, as `aurora-ground.heic` (4096×1390 with alpha, 1.3 MB). `aurora-ground-aux.png` (1024×348) holds log distance in red (Depth Anything V2 via Core ML, as for Weather) and open snow in green.
   - **Relit in the shader:** `2·tex^2.2` is the albedo, times `u_light`: 60% starlight blue and 40% the palette's own light (0.2 fringe, 0.6 body, 0.2 upper, squared to roughly linear), each at unit brightness so only the hue mixes, times 0.035. That puts lit snow at about 0.15 of the curtains' peak, as measured in real long exposures (0.02–0.47, typically 0.1–0.2). A 30% Purkinje mix toward grey-blue `(0.78, 0.92, 1.2)`, then haze toward the horizon glow (`u_glow`, the sky's low colour plus a little body colour) by `1 − exp(−0.06·km)`, with km = `(32^R − 1)/3.1`.
   - **Glistening:** `starField(pts, 3, 0.15, t·3)`, masked to open snow within the nearest part of the depth (`G · smoothstep(0.6, 0.1, R)`), in pale blue-white at 0.3. They never fall on trees, rock or the far slopes.
   - Then the same grade and dither as the sky, premultiplied by the photo's alpha.

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
With the photo ground: CPU 0.6 ms and GPU 1.6 ms per frame (release build, 2x, 2026-09-25), down from 2.0–2.2 ms with the procedural peaks and drifts. The sky's cost is about 15 noise evaluations per pixel (three curtains of 4–5 noise calls, and the star field); the ground is two texture reads and a star field over the bottom 40%. Memory: the ground texture is 4096×1390 RGBA, about 23 MB decoded, loaded once and kept (like Weather's). If anything is added, cut first: the second ray-noise octave, or run the curtains at half resolution.

## Gotchas and shortcuts
- The ground's light is one flat colour per palette. It doesn't follow where the curtains are or how bright they are right now.
- The Tetons are Wyoming, not Norway: they won on looks (see below).
- `u_time` doesn't advance in the render harness.
- Adding a fourth curtain costs roughly 0.4 ms of GPU.

## Dave's feedback and decisions
- It was one of the four scenes Dave picked for the picker's first round (with Flowing Gradient, Rain on Glass and Night Sky, later renamed Live Sky), then built by the shaders agent.
- 2026-09-24, Dave asked for other aurora colours, but "keep it in the realm of what real colors they can be … green, red, pink, purple, blue, yellow, and white". He also asked for "some gradients to it … so you get more than one color in an aurora". Hence four-colour height gradients built from real emissions, and Random as the default.
- The parent agent judged it to read well at launch.
- 2026-09-25, Dave asked for a photoreal ground, "glistening snow hills and norwegian mountain background", with the same approach as Weather. Three research agents: landscape photos, measurements of 63 real aurora-over-mountain photos, and aurora rendering techniques (for the next pass). Of ten licensed candidates, three were cut and relit (night composites in the scratchpad): the Tetons (NPS, PD), south of Tromsø on Kvaløya (Lars Tiede, CC BY 2.0: the most on-brief, snow hills with birches, but hazy and murky once relit) and Raftsund in Lofoten (Clemensfranz, CC BY 2.5: striking peaks but no snow in front). A real night photo lost: dark, noisy, and its lake has the aurora's reflection baked in. Dave picked the Tetons.

## Ideas / next steps
- **Cycling:** a slow crossfade to a freshly rolled palette and layout every few minutes, like Nebula's self-replacing scene. Roll the fold phases and edge heights per load too.
- **Substorms:** brightness surges and faster ray motion every few minutes, then calm.
- **Next pass, the aurora itself** (research notes in the scratchpad, `aurora/notes/`): curtains as sheets at their real height in perspective (arcs dipping to the horizon, rays converging on the magnetic zenith, folds brightening edge-on), about 1.2 ms in a prototype; a brighter grey-teal night sky (real photos' sky is about 10× ours); paler yellow-green aurora; wider, softer, sparser rays; a pale pink hem for Storm; clumpier, coloured stars.
- **Settings:** Activity (Quiet to Storm, or Live from NOAA's hemispheric power feed, as seen from northern Norway), Substorms, Speed.
- **Ground:** light that follows the curtains; a still lake mirroring the live sky; a Norwegian alternative (Raftsund) if the Tetons ever grate.
- **Night only:** follow the real Sun (dimmer or absent by day), as Flowing Gradient's mood does.

## Checking it
`SNAPSHOT_SCENE="Aurora" SNAPSHOT_DEFAULTS="aurora.palette=Storm" SNAPSHOT_DIR=/tmp/aurora swift test`. `SNAPSHOT_SECONDS` doesn't move shader time. For other moments, temporarily offset `t` in a scratch copy, as the shaders agent did for its +60 s and +300 s checks.
