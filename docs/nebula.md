# Nebula

A deep-space gas cloud, cut by dark dust lanes, over a twinkling star field, drifting and folding very slowly. Every load rolls a unique nebula in colours modelled on real objects, and left running it dissolves into a freshly rolled one every 8 minutes. **Dave's favourite wallpaper.**

- **Files:** `Sources/Atrium/Shaders.swift`: the `nebulaPalettes` (file scope) and `nebula(size:)`, which includes its shader source. `hash21`, `noise`, `fbm`, `starField` and `brightStar` come from `shaderCommon` in the same file (`brightStar` moved there to be shared with Galaxy).
- **Entry:** `@MainActor func nebula(size:) -> SKScene`. It builds a plain scene through `shaderScene(size:source:uniforms:)` (Scenes.swift). Its registry entry has icon `sparkles`, tint `.purple`, and palettes `PaletteChoice(key: "nebula.palette", ...)`, whose swatches are colours 1–3 of each palette. The standard is "", meaning Random.
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
   - `starField` puts one candidate star per 7 pt cell and keeps 30% of them, each twinkling ±20% at its own rate, dimmed behind dense gas
   - `brightStar` adds a few foreground stars with four-point diffraction spikes (18% of 180 pt cells). About half of them (h < 0.09) shimmer very gently: ±7% over 6–10 s. They drift sideways at 0.2 pt/s.
   - both star layers are offset by `u_seed·97`, so each nebula has its own star field
7. **Dither:** `/128` against banding.

**Each load rolls a random:**
- `u_seed` (0–100 in x and y), a new region of the endless noise field
- `u_zoom` (1.2–1.9)
- `u_band`: height 0.38–0.62, slope −0.6 to 0.6, width 0.26–0.4
- palette, unless one is pinned

## Time, live data and appearance
- **Drift:** `t = u_time × 0.005`, one screen-height every ~5 minutes. It started at 0.004; Dave asked for "a very small amount" faster. The gas also drifts at 0.5t relative to the warp, which keeps it churning. It never repeats in practice.
- **Cycling:** after 8 × 60 s the scene presents `nebula(size:)` again with `SKTransition.crossFade(withDuration: 90)`, and both `pausesIncomingScene` and `pausesOutgoingScene` false, so both nebulas keep drifting through the dissolve. Each new scene schedules its own successor. The wait is an SKAction, so it pauses while the wallpaper is covered.
- **Re-picking:** choosing Nebula in the menu, or a palette swatch in Settings, crossfades to a fresh roll immediately.
- No location or network use. No Light Mode look; it's inherently dark.

## Settings
Only the palette pin, `nebula.palette` (default Random). Palettes (`nebulaPalettes`: background, main gas, secondary gas, hot core), each after a real kind of nebula and what glows in it:

| Name | Modelled on | Colours |
|---|---|---|
| Emission | Lagoon | hydrogen-alpha crimson, blue-grey oxygen core |
| Reflection | Pleiades | blue starlight scattered off dust |
| Planetary | Helix | red hydrogen/nitrogen rim, oxygen teal (dense = red, accent = teal, so teal dominates) |
| Dusty | Rho Ophiuchi | amber dust with blue reflection |
| Hubble | Pillars of Creation | SII gold and OIII teal (the Hubble false-colour palette) |

## Tuning constants
- Drift `0.005` (`float t = u_time * 0.005`).
- Cycle every `8 * 60` s, dissolve 90 s.
- Star cells: 7 pt at 30% density for the field, 180 pt at 18% for bright stars.
- Shimmer: amplitude 0.07, rate `0.6 + 5h`.

## Performance
CPU 0.45 ms and GPU 1.52 ms per frame (release, 2x). The GPU cost is mostly the three fbm calls (5 octaves each) plus two noise octaves for dust. During the 90 s dissolve both scenes render, so it roughly doubles (`ponytail:` noted in code). That's acceptable once every 8 minutes.

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

## Ideas / next steps
- Settings: drift speed (it would need an integrated phase like Flowing Gradient, instead of `u_time`), the cycle interval, and shimmer strength.
- Let the band slowly rotate or move so the composition evolves within one nebula.
- Occasional events: a brightening star, or a faint comet streak.

## Checking it
```sh
SNAPSHOT_SCENE=Nebula swift test                                        # a random roll
SNAPSHOT_DEFAULTS="nebula.palette=Planetary" SNAPSHOT_SCENE=Nebula swift test
```
`SNAPSHOT_SECONDS` won't move the gas (the shader uses `u_time`). To preview drift, temporarily change `float t = u_time * 0.005;` to add an offset from an environment variable, and remove it after. To test cycling fast, temporarily shorten the `8 * 60` wait and the 90 s dissolve, then run the app binary directly and check that it survives several handovers.
