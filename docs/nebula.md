# Nebula

A deep-space gas cloud, cut by dark dust lanes, over a twinkling star field, drifting and folding very slowly. Every load rolls a unique nebula in colours modelled on real objects, and left running it dissolves into a freshly rolled one every 8 minutes. **Dave's favourite wallpaper.**

- **Files:** `Sources/Atrium/Shaders.swift`: the `nebulaPalettes` (file scope) and `nebula(size:)`, which includes its shader source. `hash21`, `hash42`, `noise`, `fbm` and `brightStar` come from `shaderCommon` in the same file (`brightStar` moved there to be shared with Galaxy). Its field stars are a copy of Galaxy's `starLayer` (Galaxy.swift) in its own source: `ponytail:` move both into `shaderCommon` when a third scene wants it, which would mean changing Galaxy's file too.
- **Entry:** `@MainActor func nebula(size:) -> SKScene`. It builds a plain scene through `shaderScene(size:source:uniforms:knobs:)` (Scenes.swift), which turns each of its knobs, `nebulaKnobs`, into a live uniform. Its registry entry has icon `sparkles`, tint `.purple`, and palettes `PaletteChoice(key: "nebula.palette", ...)`, whose swatches are colours 1–3 of each palette. The standard is "", meaning Random.
- **Kind:** a full-screen SKShader, fully procedural, with no image files.

## How it works
Everything is maths per pixel, per frame:
1. **Gas:** `fbm` is value noise stacked 5 octaves deep. The coordinates are `q = p·u_zoom + u_seed + (t, 0.4t)`.
2. **Domain warp:** two more fbm fields, `w`, bend `q` before the gas is sampled (`gas = fbm(q + 1.8w + ...)`). This is what turns blobs into filaments, folds and curls.
3. **Dust lanes:** two warped noise octaves. Where `dust` > 0.5–0.72 they darken the gas by up to 85%. They're dust in front of the gas, so they hide the field stars behind them too: 90% where a lane crosses dense gas, fading with the gas (`smoothstep(0.1, 0.5, density)`), so open sky is never punched with starless holes. The gas alone dims them by up to 60%, as it always did. `nebulaAt` returns that hiding in its alpha. (2026-11-16, from the review of 14 November: a lane held 13.8 stars per 100 × 100 px, as many as the gas beside it, and read as a shadow on the gas rather than dust in front of it; now 4.5, only the brightest showing faintly. In Dark Cloud a lane over the dim gas now reads as a true dark nebula, a starless patch.)
   - **Crisp dust lanes** (`nebula.detail`, 0–1, standard 0): the lanes' edges are soft blurs 30–60 pt wide with no lit rim, which is the calm look and stays the standard. Raised, a lane's edge takes the gas's own five octaves (`dust + (gas − 0.5)·0.4·detail`) and its smoothstep narrows from 0.5–0.72 to 0.57–0.65, so it becomes a crisp silhouette with folded edges; and a thin rim just outside it (0.03 below the lane's threshold) is lit in the palette's hot colour, soft-clipped like the gas, only where the gas is dense (`smoothstep(0.5, 0.75, gas)`) and hot (`smoothstep(0.3, 0.6, g·w.y·1.1)`, a looser gate than the hot-core colour's own), so the rims glow on the side facing the hot gas and break up along the rest, like the lit edges of the Pillars. Because the gas lifts the threshold, at 1 a lane also reaches a little further into the brightest gas, which can grow a new pillar there. At 0 every term it adds is multiplied by 0, so it is the picture from before the slider: 44 of 5.9 million pixels moved by 1 of 255 (Metal lays the arithmetic out differently round it, as Sources/CLAUDE.md warns). (2026-11-16, from the review of 14 November: Dave's call was to put the crisp, rim-lit lanes behind a slider whose standard is today's look.)
4. **Band:** a gaussian band across the screen, `(y - u_band.x + u_band.y·(x - 0.5))/u_band.z`. It keeps the cloud crossing the screen instead of landing wherever the noise puts it. `ponytail:` it's a fixed band, so the composition only shifts through the drifting gas.
5. **Colour:**
   - `u_base` blends to `u_dense` with gas density
   - `u_accent` comes in where the warp `w.x` is high
   - `u_hot` lights up where density and warp overlap
   - a soft clip, `1 - exp(-c·density²·2.2·m)`, keeps bright cores from blowing out
   - `m` lets the light follow the gas on past where density stops rising (`g` 0.8): `1 + 8(g − 0.87)·smoothstep(0.8, 0.9, g)`, which dips to 0.92 at `g` 0.84 and climbs above 0.87. Without it the brightest body, where the band lifts `g` past 0.8 across a wide area, was one flat tone, a slab: in the Dusty and Oxygen seed-5 rolls, whose band sits on bright gas, 15–17% of the lit gas (stars removed) was in the top 10 brightness levels and 15–21% in a single 4 levels. Now 1.3–1.7% is in the top 10 and 11–12% in the most crowded 4, and at 100% the slab breaks into soft folds; the cloud's mean brightness is unchanged (71.4 and 75.1 of 255). The curve starts only where density has already stopped rising, so a roll with no gas above `g` 0.8 is left as it was (Hubble seed 6 and Dark Cloud seed 4: no pixel moves by more than 1 of 255), and Hubble seed 1's highlights hold (p95 210 before, 209 after). The first version, `1 + 4(g − 0.84)` phased in from `g` 0.7 to 0.8, spread the slab further (6% in its most crowded 4 levels) but dipped below 1 where density was still rising, so the tone curve went nearly flat across `g` 0.7–0.81: Hubble seed 6 got a new slab (p95 170 to 159, p99.5 180 to 161) and its gold went duller, and Dark Cloud seed 4 and Hubble seed 1 lost 12–16 levels off their highlights (p95). The review's own idea, `(0.55 + 0.9·gas)` everywhere, made the whole cloud 6% brighter and left 16% of it piled at the top; centred at 0.82 it was as bright as before with brighter peaks; at 0.85 from `g` 0.65 the gold went muddy in rolls that were already good. The constants are Dave's call. (2026-11-16, from the review of 14 November.)
   - plus a faint wash around the band
6. **Stars:**
   - the field stars are Galaxy's sky (`fieldStars`, from Galaxy's `starLayer`): two layers on grids turned apart so they never line up into a lattice, one candidate per 5 pt cell kept at 16% and one per 17 pt cell at 30%, both thinned and thickened by one broad noise (`crowd`, 0.25–1.75, cells about 160 pt) into loose clusters and thinner patches. Most are a faint dust of points; only the big layer holds bright ones, with a soft halo; colours run from orange dwarfs through white to blue giants; each twinkles ±12% at its own rate. They're dimmed behind dense gas and hidden behind dust lanes (above). Their random numbers come from `hash42`, not `hash21`, which repeats every 50 cells and tiled the stars every 350 pt (Dave spotted it in Galaxy's emptier sky). (2026-11-16, from the review of 14 November: until then every field star was the same blue-white at the same density everywhere, 16 per 100 × 100 px in open sky, from `starField`, one star per 7 pt cell kept at 30%. Galaxy got the coloured, bunched sky after Dave said its stars were too uniform. The overall brightness is unchanged, to a hundredth of a level; at the battery's 0.75 scale the field looks the same.)
   - `brightStar` adds a few foreground stars with four-point diffraction spikes (18% of 180 pt cells). About half of them (h < 0.09) shimmer very gently: ±7% over 6–10 s. They drift sideways at 0.2 pt/s.
   - both star layers are offset by `u_seed·97`, so each nebula has its own star field
7. **Grade** (the Settings sliders): `grade()` in `shaderCommon`, shared with Aurora and Rain on Glass, over the whole picture in this order:
   - hue: a rotation of the RGB vector around the grey axis (Rodrigues), by `u_hue` degrees
   - saturation: a mix from Rec. 709 luma to the colour, clamped at 0
   - contrast: `pivot·(col/pivot)^u_contrast`, a power curve through the scene's typical level (0.3 here), so black space stays black instead of lifting to grey the way a linear contrast would
   - brightness: a plain multiply
   At their defaults all four are exactly the identity.
8. **Dither:** `/128` against banding.

**Each load rolls a random:**
- `u_seed` (0–100 in x and y), a new region of the endless noise field
- `u_zoom` (1.2–1.9)
- `u_band`: height 0.38–0.62, slope −0.6 to 0.6, width 0.26–0.4
- palette, unless one is pinned

## Time, live data and appearance
- **Drift:** `t = u_now × 0.005`, one screen-height every ~5 minutes. It started at 0.004; Dave asked for "a very small amount" faster. The gas also drifts at 0.5t relative to the warp, which keeps it churning. It never repeats in practice.
- **Changing to a new nebula** (`NebulaCycle`): one scene draws both. Its uniforms come in two sets, the nebula showing (`u_seed`, `u_zoom`, `u_band` and the palette) and the next (the same names ending in 2). An SKAction checks every 5 s whether the Settings interval has passed (so a new interval applies at once, and it pauses while the wallpaper is covered). When it has, it rolls the next nebula and runs `u_mix` from 0 to 1 over 90 s, then copies the next set into the showing one. The shader's per-nebula maths is a function, `nebulaAt`, called once normally and twice only while `u_mix` > 0, stars included, so both keep drifting through the change and the rest of the time it costs one nebula.
  - **Dissolve and condense**: the old nebula dissolves from its thin outer gas and fine filaments into its densest knots over the first three quarters, while the new one condenses out of its densest knots and spreads along its filaments over the last three, so halfway the densest quarter or so of each is showing. Each clips a smooth "thickness" (mostly the broad warp field, measured over the visible gas of several rolls at 0.5–0.85 raw and stretched to 0–1), not the gas itself, which would break into specks; that's the lesson from Weather's forming clouds, where clipping raw alpha made Swiss cheese. The clip sweeps linearly from −0.2 (all kept) to 1.2 (all gone). The two are screened together (1 − (1−a)(1−b)); added, their overlap flared white. Stars crossfade.
  - Before 2026-09-25 each nebula was its own scene, and the next was presented with `SKTransition.crossFade(withDuration: 90)`: a double exposure for the 90 s. Dave compared the two live with a Settings switch and chose dissolve and condense ("looks good to me, i like it"), so the switch and the crossfade were removed; they're in commit 7dafffe.
- **Re-picking:** choosing Nebula in the menu, or a palette swatch in Settings, crossfades to a fresh roll immediately.
- No location or network use. No Light Mode look; it's inherently dark.

## Settings
- **Colors:** the palette pin, `nebula.palette` (default Random). Picking one rolls a fresh nebula.
- **Change** (`nebula.every`): "New nebula every" 0–30 minutes (default 8; 0 is Off, and one minute is handy for watching a change).
- **Look**, live without a new roll (`ShaderScene` observes `UserDefaults.didChangeNotification`):

| Key | Label | Range | Default |
|---|---|---|---|
| `nebula.brightness` | Brightness | 0.4–1.5 | 1 |
| `nebula.contrast` | Contrast | 0.5–1.5 | 1 |
| `nebula.saturation` | Saturation | 0–2 | 1 |
| `nebula.hue` | Hue shift | −180–180° | 0 |
| `nebula.detail` | Crisp dust lanes | 0–1 | 0 (the soft lanes; see How it works, 3) |

At 1.8, brightness and contrast blew the cores out to white, so both stop at 1.5.

Palettes (`nebulaPalettes`: background, main gas, secondary gas, hot core), each after a real kind of nebula and what glows in it:

| Name | Modelled on | Colours |
|---|---|---|
| Emission | Lagoon | hydrogen-alpha crimson, blue-grey oxygen core |
| Reflection | Pleiades | blue starlight scattered off dust |
| Planetary | Helix | red hydrogen/nitrogen rim, oxygen teal (dense = red, accent = teal, so teal dominates) |
| Dusty | Rho Ophiuchi | amber dust with blue reflection |
| Hubble | Pillars of Creation | SII gold and OIII teal (the Hubble false-colour palette) |
| Dark Cloud | Shark Nebula (LDN 1235) | a dark nebula: dim brown dust lit only by the Milky Way, slate-grey reflection. The quiet one. |
| Oxygen | NGC 3242 (Ghost of Jupiter) | OIII-rich planetary: oxygen's true green-cyan and hydrogen-beta blue, the colour bright nebulae look through a telescope |

## Tuning constants
- Drift `0.005` (`float t = u_now * 0.005`).
- Cycle every `8 * 60` s, dissolve 90 s.
- Star cells: 5 pt at 16% and 17 pt at 30% for the field (times `crowd`), 180 pt at 18% for bright stars.
- Shimmer: amplitude 0.07, rate `0.6 + 5h`.

## Performance
CPU 0.45 ms and GPU about 1.6 ms per frame (release, 2x; the dissolve's thickness adds about 0.07 ms over the old 1.52). The GPU cost is mostly the three fbm calls (5 octaves each) plus two noise octaves for dust. During the 90 s change both nebulas are drawn, about 3.1 ms, as the old two-scene crossfade was. That's acceptable once every 8 minutes. The Settings grade is a handful of arithmetic per pixel and doesn't show in the measurement.

After the review of 14 November (2026-11-16; the render test's GPU figure on a pinned Dusty roll, debug build, back to back three times each, while other builds ran): 1.50 ms before, 1.74 after; 2.91 ms mid-change before, 3.42 after. Measured commit by commit, back to back: the coloured field stars cost about 0.19 ms more than the old `starField` (their bunching noise, the small layer and the big layer about a third each), drawn twice through a change; the review had guessed 0.1. Crisp dust lanes costs about 0.05 ms whatever the slider is set to, because its arithmetic runs at 0 too (1.52 ms before it, 1.56–1.57 after, at the standard 0). It's still inside the 2 ms budget. The lanes hiding stars and the light following the gas cost nothing measurable. CPU is unchanged, about 0.4 ms.
- Tried to pay for the stars: the review's warp trim, the two warp fbm calls cut from 5 octaves to 4 with the fifth's average added back (as Galaxy's `fbm3`), saved about 0.1 ms but isn't the same picture: the fifth octave moves the dust lanes (warped by 2.5–3 times `w`) and the fine folds, so 7–8% of the pixels moved by more than 8 of 255 and lane edges visibly shifted side by side. Dropped, since a saving has to leave the picture as it was.

**On battery it runs at 15 fps at most** (`batteryRate` in Scenes.swift; 2026-10-13). The fastest thing in it is the cloud's drift, `u_now * 0.005` in Shaders.swift with its domain warp, about 8–15 device pixels (2x on a 14-inch MacBook Pro, 3024 × 1964) a second: 1 px a frame at 15 fps. The field stars twinkle at 0.41 Hz at most (`starLayer`), far under a third of 15, and the new cloud dissolves in over 90 s.

**On battery it draws at three quarters of the screen's resolution each way** (`batteryScale` in Scenes.swift, under the same condition as its battery rate, with Settings → Power's Lighter drawing on battery, on unless changed; 2026-10-14). That cuts the GPU's work a frame by 40% (1.49 to 0.90 ms, frames drawn back to back at 3024 × 1964), about 24 ms of GPU time a second at 15 fps. Side by side at 100% (`trimShots` in TrimShots.swift) the gas can't be told apart and the stars barely; at half resolution the faintest stars thinned and softened, so it stays at three quarters.

## Gotchas and shortcuts
- Every roll is random. To compare palettes, pin one with `SNAPSHOT_DEFAULTS="nebula.palette=Hubble"`. To render the same roll twice, pin its seed too, `nebula.seed=5` (a test-only key, any whole number above 0; nothing else sets it): with the palette pinned, one seed gives the same cloud in every palette. To see another moment, raise `SNAPSHOT_SECONDS`: the drift runs on `u_now`, which moves with it.
- Helper functions can't read uniforms, so `brightStar` takes `t` as a parameter.
- The Planetary palette's dense and accent slots are swapped on purpose. The accent covers most of the area (`w.x` is often high), so putting red in dense and teal in accent makes it read teal with a red rim, like the Helix. The first attempt came out salmon.
- Colours are mixed in RGB and then soft-clipped. Emission's red and blue together can drift slightly pink; that's real (hydrogen-alpha plus hydrogen-beta) but has been kept restrained.

## Dave's feedback and decisions
- It's his favourite. He wanted to know if it was procedural and how it animates. He loved the idea of "every time I load a new nebula I get a unique new one", which led to the seed, zoom, band and palette rolls.
- "Use other colours, sourced from real-life probable colours, but don't just use pink all the time." That led to the five real-object palettes. The original magenta-and-teal set and a violet/ice set were dropped as unrealistic.
- "Increase that speed by a very small amount": the drift went from 0.004 to 0.005.
- "If I leave it on forever, will it stay the same nebula? If not, let's add seamless cycling." That added the 8-minute self-replacing dissolve.
- "A very very very subtle twinkle on some of the larger background stars": the ±7% shimmer on about half of the spiked stars. The small field stars already twinkled.
- He asked for a palette picker in Settings.
- He asked for colour, contrast, brightness and saturation controls, and for "1 or 2 more colour presets if there are any more natural colour combinations we see in real life that are missing". The Look sliders came from that. So did Dark Cloud and Oxygen: the set had no dark nebula and no green. A Crab-style Supernova (orange filaments on blue synchrotron) was tried and dropped because it read too close to Dusty.
- 2026-09-25, after Weather's clouds learned to form and dissolve: "would the nebula wallpaper benefit from this new billowing forming dissolving tech we have?" Billowing no (the gas already churns), but the forming and dissolving yes, for the change between nebulas. He had it prototyped with a Settings switch against the crossfade, compared them, and chose it: "Dissolve and condense looks good to me, i like it."

- 2026-09-26, after every Settings page got a screenshot behind its top: "I am not sure I want this so maybe just try it on one item first" about live previews. Nebula's page was the trial: its own copy of the scene runs there (`LivePreview` in Settings.swift), so the Look sliders show on the page as they move. He liked it, "yeah the live preview is awesome, add it to all of them", so every page has one now.

## Ideas / next steps
- More Settings: drift speed (it would need an integrated phase like Flowing Gradient, instead of `u_now`) and shimmer strength.
- Let the band slowly rotate or move so the composition evolves within one nebula.
- Occasional events: a brightening star, or a faint comet streak.

## Checking it
```sh
SNAPSHOT_SCENE=Nebula swift test                                        # a random roll
SNAPSHOT_DEFAULTS="nebula.palette=Planetary" SNAPSHOT_SCENE=Nebula swift test
SNAPSHOT_DEFAULTS="nebula.seed=5,nebula.palette=Dusty" SNAPSHOT_SCENE=Nebula swift test --filter everySceneRenders  # the same roll every time
SNAPSHOT_DEFAULTS="nebula.seed=1,nebula.palette=Hubble,nebula.detail=1" SNAPSHOT_SCENE=Nebula swift test --filter everySceneRenders  # crisp, rim-lit lanes
swift test --filter nebulaFollowsItsSeedAndDustDetail   # the seed pins the roll, and Crisp dust lanes reaches the shader
SNAPSHOT_DEFAULTS="nebula.palette=Hubble,nebula.contrast=1.5,nebula.hue=120" SNAPSHOT_SCENE=Nebula swift test
```
`SNAPSHOT_SECONDS` moves the gas (the shader runs on `u_now`), so a larger value previews the drift. To test cycling fast, temporarily shorten the `8 * 60` wait and the 90 s dissolve, then run the app binary directly and check that it survives several handovers.
