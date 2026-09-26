# Aurora

The northern lights as a long exposure records them: sheets of light 100 km up and a few hundred km away, drawn in true perspective so arcs dip toward the horizon, folds brighten where they're seen edge-on and rays lean together toward the magnetic zenith, over a grey-teal airglow and clumped, coloured stars. Below them, a real snowy range (a photo of the Tetons in winter) lit by their light: open snow brightens and greens under the brightest stretch of the arc.

- **Files:** `Sources/Atrium/Aurora.swift` (the palettes, the arc texture, the sky shader, `AuroraLight` and the ground), plus `Resources/aurora-ground.heic` and `Resources/aurora-ground-aux.png`. The shaders use the `shaderCommon` helpers `noise`, `hash21`, `starField(pts, cell, density, t)` and `grade`.
- **Entry:** `@MainActor func aurora(size:)`, which builds `shaderScene(size:source:uniforms:knobs:)` for the sky and adds the ground sprite from `auroraGround`. Registry entry: icon `wind`, tint `.green`.
- **Kind:** a full-screen SKShader for the sky under a photo sprite with its own shader for the ground. Swift side: the palette, a new arrangement of curtains and a baked arc texture on each load, a clock (`u_phase`, advanced by an SKAction in scene time), and `AuroraLight`, which re-measures the curtains' light on the land each second.

## How it works
The research behind it (three agents on 2026-09-25: landscape photos, 63 measured real aurora photos, rendering techniques) is in the scratchpad notes, `aurora/notes/`. The targets it set, in linear light: sky 0.007 at the zenith to 0.021 at the horizon, grey-teal; aurora peak 0.45–0.55 at hue 92–105 and saturation 0.35–0.45, its mean about 0.12; one main arc covering 35–55% of the sky; snow 3–5× the sky and 0.06–0.15× the aurora's peak, barely green.

1. **Camera.** A level pinhole camera facing north, its eye level at 0.26 of the screen height (where the photo's is, just under the range) and `u_lens` 0.8 (tan of half the view across, about a 22 mm lens). Each pixel is a direction; `tanEl` is its elevation.
2. **Curtains** (up to four, `u_dist`, `u_angle`, `u_lum`, `u_low`, `u_thick`): each is a vertical sheet over a line on the ground `dist` km away, its normal `angle` from north, leaning 11° toward us along the field. One main arc at 220–330 km, a second (45% of loads) and a third (20%) at 180–380 km, all near the main one's direction. Those distances keep every lower edge above the summits.
   - **Where the line of sight meets a sheet** is closed-form: `s = (dist + fold + 20·cos) / (cos(heading − normal) + 0.2·cos·tanEl)`, and the height seen there is `s·tanEl + s²/2R` (a round Earth). So an arc dips toward the horizon at the edges of the view, and a far one sits low.
   - **Folds** come from `u_arc`, one 4097×1 RGBA texture baked at load (`auroraArc`, about 5 ms): R a fold curve of 48 sines, G its slope, B a barcode of rays, A how high each ray reaches. Two octaves, read along the curtain at 3000 km and 500 km scales, drift opposite ways (0.6 and 0.35 km/s), so the shapes reshape rather than slide. Where the sheet is seen edge-on its light adds up along the line of sight: the path factor `√(1+m²)/√((cos − m·sin)² + 0.04)`, at most 3, makes the bright fold pillars.
   - **Emission by height:** green rising over a few km at `u_low` (98–110 km) and fading upward over 10–35 km (per ray), with no corner or step at the edge (either draws a hairline along it); a faint glow scattered around the edge; and the crown (`u_red`: 0.02, or 0.1 for Storm and 0.08 for Red) as a broad band at 240 ± 42 km in the crown colour, with no rays, since the 630 nm red takes 110 s to glow and smears them out.
   - **Rays** are the barcode read at each ray's foot (`s·sin − 0.2·(h − 100)·sin(angle)`), so they lean together up the field lines, at 20000 km per texture (7–30 km apart) and ±15% (`u_rays`). They fade to their mean where they'd be finer than a pixel (`fwidth`) and where we look up through a thick slab.
   - **Colour** by height above the edge: the fringe tints only the lowest few km (and averages away through a thick slab, so Storm's pink stays a hem), then the body, then the upper colour from 20 to 70 km up. Palette colours are display colours, made linear (`^2.2`) for the light.
   - **Patches:** a slow read of the fold curve (`l/2500`) brightens and dims stretches of each curtain (0.4–1).
3. **Air.** Kasten–Young air mass: low light is dimmed and reddened, and haze softens it.
4. **Sky and stars.** Airglow from `(0.016, 0.022, 0.025)` at the horizon to `(0.0052, 0.007, 0.0116)` higher up. Stars: `starField` at 11 pt (bright) and 6 pt (a faint tail), their density clumped by a slow noise (0.35–1.65×), each tinted orange to blue-white.
5. **Tone.** Everything adds in linear light, then `1 − exp(−x)` per channel (bright cores go pale, as on film), then `^(1/2.2)`, the Look grade and dither.
6. **The old curtains** (the Compare switch): the previous three stacked screen-space curtains with their original colours (`classicColours`), kept until Dave picks.
4. **Ground.** A photo of the Tetons from Teton Point in winter (NPS photo by A. Falgoust, public domain, 6000×4000, a soft day under thin high cloud): snow flats, a dark band of spruce, then the jagged range. It's drawn as its own sprite over the sky, full width, with its highest summit at 0.38 of the screen height (the skyline runs 0.26–0.38) and its bottom cropped by the screen.
   - **Baked offline** (the research agent's `bake.py`, in the scratchpad): sky cut out with a soft, decontaminated edge; the photo's own haze removed by its depth; its daylight flattened (divided by blurred brightness^0.2); white-balanced so the median snow is 0.85 and desaturated to 30%. What's left is roughly albedo, stored sRGB at half scale (snow ≈ 0.42) so nothing clips, as `aurora-ground.heic` (4096×1390 with alpha, 1.3 MB). `aurora-ground-aux.png` (1024×348) holds log distance in red (Depth Anything V2 via Core ML, as for Weather) and open snow in green.
   - **Lit by the aurora** (Dave: "is it possible to have the aurora cast a realistic light on the mountain range below"): `2·tex^2.2` is the albedo, times `u_star` (starlight and airglow, bluish, 0.02) plus `u_aurora` (the palette's body and upper colours at unit brightness, 0.016) × `pool` × `open`.
     - `pool` is how bright the arc is above that part of the screen: `AuroraLight.pool()` runs the shader's own geometry on the CPU (the same arc texture bytes, folds, path factor and patches, at the curtains' lower edges) for 8 strips across the screen, once a second, into `u_poolA`/`u_poolB`, which the shader interpolates. Snow under a bright stretch comes out about 40% brighter and a little greener than under a dim one.
     - `open` is 1 on the flats and 0.25 on the range (`smoothstep(0.92, 0.8, R)`): the aurora hangs in the north beyond the range, so open snow faces up into its light while the faces we see are turned away from it. (A slope map from the depth's gradient was tried and dropped: 8-bit depth bands on the flats and tree tops light up.)
     - Measured: snow about 0.045 linear, 3× the sky and 0.08–0.11× the aurora's peak, greenness 1.1–1.25.
   - A 30% Purkinje mix toward grey-blue `(0.78, 0.92, 1.2)`, then haze toward `u_glow` (the airglow at the horizon plus a little of the aurora's colour, by its mean pool) by `1 − exp(−0.06·km)`, with km = `(32^R − 1)/3.1`.
   - **Glistening:** `starField(pts, 3, 0.15, t·3)`, masked to open snow within the nearest part of the depth (`G · smoothstep(0.6, 0.1, R)`), in pale blue-white at 0.3. They never fall on trees, rock or the far slopes.
   - Then the same grade and dither as the sky, premultiplied by the photo's alpha.

## Time and appearance
The curtains move on `u_phase`, seconds of scene time advanced by a repeating `customAction`, so it pauses with the wallpaper and a Speed knob can scale it. Stars twinkle on `u_time`. There is no Light Mode look. Each load rolls a new arrangement of curtains and folds; the palette is Random unless pinned. `AURORA_SEED=n` in the environment repeats one arrangement (for snapshots).

## Settings
**Colors:** `aurora.palette`, Random by default. Each palette in `auroraPalettes` has four colours from bottom to top: fringe, body, upper and crown. They're all real emissions or mixes of them, the colours Dave listed after looking it up: green, red, pink, purple, blue, yellow and white.

| Palette | Fringe → body → upper → crown | Real basis |
|---|---|---|
| Green | yellow-green → yellow-green → green → violet | 557.7 nm oxygen, hue about 95 as photos record it; the original look |
| Storm | pink → green → yellow-green → red | strong display: nitrogen pink edge, 630 nm oxygen red crown |
| Red | green → red → red → deep red | seen from mid-latitudes, where only the high red part rises above the horizon |
| Pink | pink → pink → lilac → violet | nitrogen-rich lower border |
| Purple | magenta → purple → blue-violet → red-violet | nitrogen blue mixing with oxygen red |
| Blue | teal → blue → blue → violet | sunlit nitrogen at the top of a twilight display |
| Yellow | green → yellow-green → gold → red | green and red overlapping |
| White | pale greens and blues | a faint display, too dim for colour vision |

The swatches run crown to fringe, top-left to bottom-right, as the sky does. On 2026-09-25 the greens (Green, Storm, Red's fringe) moved from a teal `(0.2, 1, 0.5)` to the yellow-green real photos measure, `(0.58, 1, 0.5)`, paler so the peak's saturation lands near 0.45.

- **Motion:** `aurora.speed`, "Speed", 0–6×, default 1× (Dave: "default to a natural realistic speed"): scales `u_phase`, so 1× is a real display's pace (folds 0.35–0.6 km/s, rays 0.5 km/s), 0 freezes the curtains and 6× is a lively one. Stars keep twinkling. Shown as "1.0×" (`.times` now shows a decimal below 10).
- **Colors, fading:** `aurora.fade`, "Fade to a new color automatically" (off), and `aurora.fadeMinutes`, "Every", 1–60 min (10), shown under the swatches only while the palette is Random, as Lava Lamp's cycling is. Dave asked for it on 2026-09-25. Every so often the four colours, the crown strength and the ground's aurora light ease to another palette over 90 s (smoothstep, in linear light, per `AuroraColours.mixed`). The clock counts from the start of each fade, so at 1 minute the fades run back to back. These knobs, and Speed, aren't shader uniforms (they're read once a second from UserDefaults), which keeps the sky shader under Metal's limit of about 30 uniforms.
- **Compare:** `aurora.classic`, "Show the old curtains", off by default: the previous screen-space curtains and colours, live, to compare against. It goes once Dave picks.
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
| `aurora.activity` | Activity | Quiet / Moderate / Active / Storm / Live | Moderate | curtain count, brightness, folds, lower-edge height; Live from NOAA's hemispheric power |
| `aurora.substorms` | Substorms | on/off | on | a 20–30 min quiet → surge → recovery cycle |


## Tuning constants
- Camera: eye level 0.26, lens 0.8. Main arc 220–330 km, others 180–380 km, lower edges 98–110 km, slabs 3–12 km.
- Drift per second of phase: big folds 0.0002 of 3000 km, small folds −0.0007 of 500 km, rays 0.000025 of 20000 km (0.5 km/s), patches 0.00002.
- Emission: lower edge `exp(−dh²/(30 + 2·sh² + 400·airmass))`, upward `exp((4 − √(dh² + 16))/(10 + 25·a²))`, ray contrast `u_rays` 0.15, glow 0.015. Gain `u_gain` 0.7 before the tone curve.
- Ground: `u_star` 0.02, `u_aurora` 0.016, range faces 0.25 of the flats' aurora light.

## Performance
CPU 0.5–0.7 ms and GPU 1.0–1.45 ms per frame (release build, 2x, 2026-09-25), depending on how many curtains a load rolls; the old curtains cost 1.6–1.7 ms with the same ground, and 2.0–2.2 ms with the procedural range before that. Per curtain: three reads of the 16 KB arc texture and some arithmetic, skipped when its `u_lum` is 0. The ground is two texture reads and a star field over the bottom 40%. `AuroraLight.pool()` is 8 × up to 4 evaluations once a second. The arc texture takes about 5 ms to bake at load. Memory: the ground texture is 4096×1390 RGBA, about 23 MB decoded, loaded once and kept (like Weather's). If anything is added, cut first: the second ray-noise octave, or run the curtains at half resolution.

## Gotchas and shortcuts
- The Tetons are Wyoming, not Norway: they won on looks (see below).
- The photo's lens is about 29 mm (18 mm on APS-C); the sky's is wider (about 22 mm) for more of the arc. Nobody can tell from a skyline.
- No true spirals or folds that turn back on themselves: each heading meets a curtain once. The techniques agent's option for them is CPU-projected ribbons.
- The fold curve is 8-bit, which leaves faint kinks in a sharp edge; the lower edge is soft enough to hide them.
- `u_time` doesn't advance in the render harness, but SKActions do, so `SNAPSHOT_SECONDS` moves the curtains (`u_phase`).

## Dave's feedback and decisions
- It was one of the four scenes Dave picked for the picker's first round (with Flowing Gradient, Rain on Glass and Night Sky, later renamed Live Sky), then built by the shaders agent.
- 2026-09-24, Dave asked for other aurora colours, but "keep it in the realm of what real colors they can be … green, red, pink, purple, blue, yellow, and white". He also asked for "some gradients to it … so you get more than one color in an aurora". Hence four-colour height gradients built from real emissions, and Random as the default.
- The parent agent judged it to read well at launch.
- 2026-09-25, Dave asked for a photoreal ground, "glistening snow hills and norwegian mountain background", with the same approach as Weather. Three research agents: landscape photos, measurements of 63 real aurora-over-mountain photos, and aurora rendering techniques (for the next pass). Of ten licensed candidates, three were cut and relit (night composites in the scratchpad): the Tetons (NPS, PD), south of Tromsø on Kvaløya (Lars Tiede, CC BY 2.0: the most on-brief, snow hills with birches, but hazy and murky once relit) and Raftsund in Lofoten (Clemensfranz, CC BY 2.5: striking peaks but no snow in front). A real night photo lost: dark, noisy, and its lake has the aurora's reflection baked in. Dave picked the Tetons. Then: "the edges of the aurora get really close to the top of the mountains, it looks odd", so the curtains went up (lower edges from 0.4 to 0.5) and the range down (summit from 0.42 to 0.38). In the new sky, the curtains' distances keep their lower edges above the summits.
- 2026-09-25, the aurora itself: the techniques agent's perspective-sheet prototype, tuned against the reference agent's measurements, behind a Compare switch for Dave to choose. He also asked for the aurora to "cast a realistic light on the mountain range below" (the ground section above).

## Ideas / next steps
- **Slow change:** every few minutes one curtain fades out over a minute or so and returns somewhere new (distance, angle, height), so the sky rearranges over 10–20 minutes without a cut; distances drift slowly as real arcs do.
- **Settings:** Activity (Quiet to Storm, or Live from NOAA's hemispheric power feed, `services.swpc.noaa.gov/text/aurora-nowcast-hemi-power.txt`, as seen from northern Norway: from Dave's latitude the real sky would be dark most nights), Substorms, Speed. Details in the techniques notes.
- **Snow sparkle:** none of the 47 real snow photos shows any at this scale; Dave asked for glistening, so it stays subtle. Make it rarer and static if it reads as noise.
- **Ground:** a still lake mirroring the live sky; a Norwegian alternative (Raftsund) if the Tetons ever grate; a faint rim of light on the summits' snow from the aurora behind them.
- **Stars:** the real catalogue (Live Sky's) for true clustering and the Milky Way.
- **Night only:** follow the real Sun (dimmer or absent by day), as Flowing Gradient's mood does.

## Checking it
`AURORA_SEED=3 SNAPSHOT_SCENE="Aurora" SNAPSHOT_DEFAULTS="aurora.palette=Storm" SNAPSHOT_DIR=/tmp/aurora swift test -c release -Xswiftc -enable-testing`. `SNAPSHOT_SECONDS=60` shows the same arrangement a minute on. The reference agent's scripts (scratchpad `aurora/reference/`) re-measure a render against the 63 photos; `aurora/stats.py` gives the quick version (sky, peak, coverage, snow).
