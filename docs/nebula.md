# Nebula

A deep-space gas cloud, cut by dark dust lanes, over a twinkling star field, drifting and folding very slowly. Every load rolls a unique nebula in colours modelled on real objects, and left running it dissolves into a freshly rolled one every 8 minutes. **Dave's favourite wallpaper.**

- **Files:** `Sources/Atrium/Shaders.swift`: the `nebulaPalettes` (file scope) and `nebula(size:)`, which includes its shader source. `hash21`, `hash42`, `noise`, `fbm`, `starField` and `brightStar` come from `shaderCommon` in the same file (`brightStar` moved there to be shared with Galaxy).
- **Entry:** `@MainActor func nebula(size:) -> SKScene`. It builds a plain scene through `shaderScene(size:source:uniforms:knobs:)` (Scenes.swift), which turns each of its knobs, `nebulaKnobs`, into a live uniform. Its registry entry has icon `sparkles`, tint `.purple`, and palettes `PaletteChoice(key: "nebula.palette", ...)`, whose swatches are colours 1–3 of each palette. The standard is "", meaning Random.
- **Kind:** a full-screen SKShader, fully procedural, with no image files.

## How it works
Everything is maths per pixel, per frame:
1. **Gas:** `fbm` is value noise stacked 5 octaves deep. The coordinates are `q = p·u_zoom + u_seed + (t, 0.4t)`.
2. **Domain warp:** two more fbm fields, `w`, bend `q` before the gas is sampled (`gas = fbm(q + 1.8w + ...)`). This is what turns blobs into filaments, folds and curls.
3. **Dust lanes:** two warped noise octaves. Where `dust` > 0.5–0.72 they darken the gas by up to 85%.
4. **Band:** a gaussian band across the screen, `(y - u_band.x + u_band.y·(x - 0.5))/u_band.z`. It keeps the cloud crossing the screen instead of landing wherever the noise puts it. `ponytail:` it's a fixed band, so the composition only shifts through the drifting gas.
5. **Colour:**
   - `u_base` blends to `u_dense` with gas density
   - `u_accent` comes in where the warp `w.x` is high
   - `u_hot` lights up where density and warp overlap
   - a soft clip, `1 - exp(-c·density²·2.2)`, keeps bright cores from blowing out
   - plus a faint wash around the band
6. **Stars:**
   - `starField` puts one candidate star per 7 pt cell and keeps 30% of them, each twinkling ±20% at its own rate, dimmed behind dense gas. Its random numbers come from `hash42`: `hash21` repeated every 50 cells, tiling the stars every 350 pt (Dave spotted it in Galaxy's emptier sky).
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
- **Drift:** `t = u_time × 0.005`, one screen-height every ~5 minutes. It started at 0.004; Dave asked for "a very small amount" faster. The gas also drifts at 0.5t relative to the warp, which keeps it churning. It never repeats in practice.
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
- Drift `0.005` (`float t = u_time * 0.005`).
- Cycle every `8 * 60` s, dissolve 90 s.
- Star cells: 7 pt at 30% density for the field, 180 pt at 18% for bright stars.
- Shimmer: amplitude 0.07, rate `0.6 + 5h`.

## Performance
CPU 0.45 ms and GPU about 1.6 ms per frame (release, 2x; the dissolve's thickness adds about 0.07 ms over the old 1.52). The GPU cost is mostly the three fbm calls (5 octaves each) plus two noise octaves for dust. During the 90 s change both nebulas are drawn, about 3.1 ms, as the old two-scene crossfade was. That's acceptable once every 8 minutes. The Settings grade is a handful of arithmetic per pixel and doesn't show in the measurement.

## Gotchas and shortcuts
- `u_time` doesn't advance in the render test, and every roll is random. To compare palettes, pin one with `SNAPSHOT_DEFAULTS="nebula.palette=Hubble"`. To see another moment, temporarily add an offset to `u_time`.
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

## Ideas / next steps
- More Settings: drift speed (it would need an integrated phase like Flowing Gradient, instead of `u_time`) and shimmer strength.
- Let the band slowly rotate or move so the composition evolves within one nebula.
- Occasional events: a brightening star, or a faint comet streak.

## Checking it
```sh
SNAPSHOT_SCENE=Nebula swift test                                        # a random roll
SNAPSHOT_DEFAULTS="nebula.palette=Planetary" SNAPSHOT_SCENE=Nebula swift test
SNAPSHOT_DEFAULTS="nebula.palette=Hubble,nebula.contrast=1.5,nebula.hue=120" SNAPSHOT_SCENE=Nebula swift test
```
`SNAPSHOT_SECONDS` won't move the gas (the shader uses `u_time`). To preview drift, temporarily change `float t = u_time * 0.005;` to add an offset from an environment variable, and remove it after. To test cycling fast, temporarily shorten the `8 * 60` wait and the 90 s dissolve, then run the app binary directly and check that it survives several handovers.
