# Flowing Gradient

Seven big, soft pools of colour drift and melt into each other with no visible edges. Two silk ribbons of light fold through them, under a fine film grain. The mood follows the real Sun. In Dark Mode the pools glow like coloured light; in Light Mode they're watercolour washes on pale paper. Dave's second-favourite wallpaper.

- **Files:** `Sources/Atrium/FlowingGradient.swift` holds everything: knobs, palettes, `pastel`, and the shader source. The noise helpers come from `shaderCommon` in Shaders.swift.
- **Entry:** `flowingGradient(size:)` returns `final class FlowingGradient: SKScene`. Its registry entry in Scenes.swift has icon `swirl.circle.righthalf.filled`, tint `.indigo`, `knobs: FlowingGradient.knobs`, and palettes `PaletteChoice(key: "gradient.palette", options: FlowingGradient.paletteOptions, standard: "Midnight")`.
- **Kind:** a full-screen SKShader on one sprite, with a subclass so it can hold live uniforms.

## How it works
In the shader (`FlowingGradient.source`):
1. **Warp:** the plane is bent by slow, broad noise (`q = p + 0.5·noise(p·0.9 ± t)`), so the pools smear and flow rather than sliding as circles.
2. **Seven pools:** gaussian weights `pool(q, drift(...), r)`. Each drifts on its own Lissajous path that roams a little past the screen edges. Radii run 0.85 to 0.42, scaled by `u_poolSize`. Slots 4 and 6 are the warm ones: at golden hour they swell ×(1 + 0.8·golden) and ×(1 + 2·golden).
3. **Dark Mode (`u_lightMode` < 0.5), blending as light:**
   - `light = u_base + Σ c_i·w_i`: the pools add like coloured light, so overlaps glow into new hues with no edge
   - tinted by mood: cooler at night, warmer at golden hour
   - silk added as `silk·(light·2.5 + blue-grey)`, so it's tinted by what's beneath it
   - exposure `col = 1 - exp(-light·exposure)`, a soft curve so overlaps never clip and the gaps stay dark
   - vignette 0.45
4. **Light Mode, blending as watercolour:**
   - `ink = Σ (1 - c_i)·w_i`, then `col = paper·exp(-ink·(0.3/u_brightness)·mood)`: each wash absorbs what its colour lacks, so overlaps deepen
   - silk is a white sheen, `mix(col, 1, silk·0.9)`
   - a lighter 0.12 vignette
   - the paper is white tinted 6% toward the palette's second pool
5. **Silk ribbons (`ribbon`):** two slow waves, each made of 5 fine strands. They spread apart and pinch together with `twist`, so bright folds travel along the ribbon, wrapped in a soft glow.
6. **Film grain:** `hash21` over `floor(pixel / u_grainSize)`. It's fixed rather than animated (a deliberate choice for a calm, printed feel) and stronger in the lights. It also dithers away 8-bit banding.

**How the palette is picked (init):** `gradient.palette` is read, defaulting to "Midnight". An empty value means Random. `systemIsDark` chooses between the raw pool colours (Dark) and `pastel(c)` for each colour (Light). `pastel` normalises the colour to its brightest channel, then mixes it 55% toward white. So each palette defines only its dark colours, and the light washes are derived from them.

## Time, live data and appearance
- **Flow:** `u_phase` is integrated in `update` as `dt × 0.04 × flowSpeed`, capped at 0.5 s per step. It isn't `u_time × speed`, so dragging the speed slider never makes the pools jump. This also means `SNAPSHOT_SECONDS` does move it forward in tests.
- **Mood:** `applySettings()` computes the Sun's altitude with `Sky` (SkyMath.swift) at `Location.shared.coordinate`, on every settings change and every 60 s:
  - `golden = exp(-((alt-2)/8)²)`
  - `night = 1 - smoothstep(-18, -4, alt)`
  - `noon = smoothstep(15, 55, alt)`

  All three are scaled in the shader by the `followDay` knob. `Location.shared.start()` runs in `didMove`.
- **Appearance:** Light/Dark is read when the scene is built. The app crossfades the scene into its other look when macOS switches (main.swift observes `effectiveAppearance`).
- **Palette picks:** a new pick rebuilds the scene through `switchScene()` if it's on the desktop.

## Settings
| key | label | range | default | drives |
|---|---|---|---|---|
| gradient.brightness | Brightness | 0.2–1.2 | 0.6 | Dark exposure; Light ink strength (inverse) |
| gradient.speed | Flow speed | 0–3 | 1 | phase rate (CPU side) |
| gradient.poolSize | Pool size | 0.5–1.8 | 1 | every pool radius |
| gradient.ribbonsOn | Show ribbons | toggle | on | `u_ribbonsOn` |
| gradient.ribbons | Strength | 0–1 | 0.5 | silk strength (shown when on) |
| gradient.ribbonWidth | Width | 0.3–2.5 | 1 | strand spread and glow width (shown when on) |
| gradient.grain | Amount | 0–1 | 0.35 | grain strength |
| gradient.grainSize | Size | 1–4 | 1.5 | grain cell size in pixels |
| gradient.followDay | Follow the day | 0–1 | 0.7 | how much golden, night and noon apply |
| gradient.previewTime | Preview a time of day | toggle | off | use today at the preview hour instead of now |
| gradient.previewHour | Time | 0–24 | 19:00 | preview hour (shown when previewing) |

Sections: Look, Silk Ribbons, Film Grain, Time of Day.

**Palettes** (`FlowingGradient.palettes`: a base plus seven pools; slots 4 and 6 are warm). The default is Midnight, and Random is offered.

| Palette | Colours |
|---|---|
| Midnight | the original: navy, indigo, teal, soft blue (#6eb1ff-ish, >1 for glow), magenta, violet, dusky coral |
| Aurora | deep teal, emerald, teal, mint, violet, blue, magenta |
| Sunset | plum, purple, rose, gold, magenta-red, indigo, orange |
| Ocean | navy, blue, teal, aqua, cornflower, seafoam, periwinkle |
| Blush | wine, mauve, rose, champagne, pink, plum, peach |
| Graphite | blue-greys with a warm grey |

The swatches in Settings (`paletteOptions`) use pools 1, 3, 4 and 6, and their pastels.

## Tuning constants
- Drift speeds and phases are the `drift(t, a, b, phase)` arguments per pool. The flow rate is `0.04` in `update`.
- Ribbons:
  - first: y0 0.62, amplitude 0.16, frequency 1.6
  - second: y0 0.36, amplitude 0.13, frequency 2.1, at ×0.8 strength
  - strand spacing `0.03·width·twist`, strand thickness `0.006·width + 0.003`
- Dark mode mood multipliers: night (0.85, 0.9, 1.15), golden (1.12, 0.97, 0.88). Exposure is `u_brightness·(1 - 0.35·night)·(1 + 0.25·noon)`.
- Light mode: ink scale `0.3/u_brightness`, pastel mix 0.55. These were tuned down from 0.6 and 0.45, which looked too saturated.

## Performance
CPU 0.47 ms and GPU 0.55 ms per frame (release, 2x), one of the cheapest scenes. The 7 gaussians and 10 strand exponentials per pixel are the bulk. Lots of headroom.

## Gotchas and shortcuts
- **Knobs are read by array index:** `Self.knobs[1]` (speed), `[9]` (previewTime), `[10]` (previewHour). Reordering the `knobs` array silently breaks them. Look the key up instead if you touch this.
- Every knob gets a `u_<name>` uniform, even the ones the shader doesn't use (`previewTime`, `previewHour`). That's harmless.
- `speed` can't be a property name on an SKScene (it clashes with `SKNode.speed`), hence `flowSpeed`.
- Uniforms are only visible inside `main()`, so `ribbon()` takes width as a parameter.

## Dave's feedback and decisions
- He loved it as a "quiet default" but asked for bigger orbs that blend into each other more, with edges harder to see, plus a couple more complementary colours, keeping the vibe.
  - Painter-style `mix()` layering showed orb edges.
  - A weighted-average blend was tried and rejected: everything went muddy indigo.
  - Additive light at exposure 1.1 was too bright and washed out.
  - Settled on additive light at exposure 0.6, with violet and dusky coral added.
- For "next level", he picked three ideas: silk ribbons, film grain, and follow the day. He wanted them "easily configurable so we can tweak until it looks good", which is where the Settings window came from.
- He asked for a switch to turn the ribbons off (`gradient.ribbonsOn`).
- He asked for palettes plus a Dark/Light Mode look. Light Mode first came out too saturated; he got the softened washes.

## Ideas / next steps
- Breathing: a slow brightness swell over about 60 s.
- Cursor parallax: layers shift slightly with the mouse (clicks still pass through). Optional, since Dave chose ambient-only early on.
- A Nebula-style unique roll: randomised drift paths per load, or a slow palette cycle.
- Once Dave settles on slider values, read them with `defaults read com.dtanquary.atrium` and bake them in as the new defaults.

## Checking it
```sh
SNAPSHOT_SCENE="Flowing Gradient" SNAPSHOT_SECONDS=20 swift test
SNAPSHOT_DEFAULTS="gradient.palette=Sunset" SNAPSHOT_APPEARANCE=light SNAPSHOT_SCENE="Flowing Gradient" swift test
SNAPSHOT_DEFAULTS="gradient.previewTime=1,gradient.previewHour=18.7" SNAPSHOT_SCENE="Flowing Gradient" swift test   # golden hour
SNAPSHOT_DEFAULTS="gradient.ribbons=1,gradient.grain=1" SNAPSHOT_SCENE="Flowing Gradient" swift test                 # exaggerate to inspect
```
The flow uses the integrated `u_phase`, so `SNAPSHOT_SECONDS` works. The test location is the time-zone fallback, so sunset in previews is around 18:45 local time.
