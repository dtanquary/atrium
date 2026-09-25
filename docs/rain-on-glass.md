# Rain on Glass

Looking through a fogged, rain-spattered window at a city, at night in Dark Mode and on an overcast day in Light Mode: out-of-focus lights and a crawling band of traffic behind the glass. Small beads form and evaporate, and larger drops slide down in lurches, wiping clear trails. Each drop acts as a small lens showing a sharper, flipped view of the lights.

- **Files:** `Sources/Atrium/Shaders.swift`. `rainOnGlass(size:)` holds the whole shader. It uses the `shaderCommon` helpers from the same file: `hash11`, `hash21`, `noise` and `fbm`.
- **Entry:** `@MainActor func rainOnGlass(size:)`, which returns `shaderScene(size:source:)` from Scenes.swift. Registry entry: icon `cloud.rain.fill`, tint `.gray`.
- **Kind:** a single full-screen SKShader, animated by `u_time` alone. The only Swift-side state is the palette, picked when the scene is built (`rainPalettes` in Shaders.swift).

## How it works
It works in `p = v_tex_coord * vec2(aspect, 1)`, so 1 unit is the screen height.
1. **City (`city(p, blur, t)`).** A warm, light-polluted haze low down, fading to near-black upward. On top of that, five `bokeh()` layers, each a grid with about 55% of cells lit by a disc:
   - three static layers, with cells of 0.19, 0.13 and 0.09, the last one rotated so the grids don't line up
   - two traffic layers (cells 0.08 and 0.07) sliding sideways at ±0.012 and 0.009 units/s, in gaussian bands at y = 0.27 and 0.2
   - five tints from the palette, used by 45%, 20%, 15%, 13% and 7% of lights. They come into `bokeh()` as two `mat3`s of columns, because SKShader uniforms are only visible in `main()`
   - `bokeh()` returns `(tint × strength, strength)`, so the day look can use the same lights as ink
   - `blur` sets disc size and edge softness: 1 is fogged glass, 0.2 is seen through a drop
2. **Beads (`beads`).** One per 0.03 cell, present in 70% of cells. Each lives about 50 s (`fract(t * 0.02 + h)`), swelling in and shrinking out.
3. **Sliders (`slider`).** One big drop per column, in two offset layers with columns 0.1 and 0.065 wide; 70% of columns have one.
   - Motion is `fract(ph + 0.12 * sin(ph * 2π))`, a lurch, pause, lurch rhythm, taking about 10–25 s per fall.
   - Radius is 14–22% of the column width. The drop is teardrop-shaped, stretched 1.5× upward.
4. **Trails (`trail`, `drops`).** A slider wipes the fog in a strip up to 0.3 units above it and leaves shrinking beads spaced 1.6 radii apart in that strip.
5. **Compositing (`main`).**
   - The fogged view is `city(p, 1.0)`. Wiped trails blend in a clearer view, `city(p, 0.45)`.
   - Inside a drop the view is `city(p - drop.xy * 0.07, 0.2) * 1.3`: sharper, offset and flipped. It's darkened toward the rim, with a highlight at the upper left.
   - Dither ±1/256.

The branches on `wiped > 0` and `drop.z > 0` skip the extra `city()` lookups (each costs five bokeh layers) on dry glass, which covers most of the screen.

## Time and appearance
Everything is driven by `u_time`, so a speed setting would need the integrated-phase pattern from `FlowingGradient`/`LavaLamp` (`u_phase += dt * speed` in `update(_:)`). It follows the system appearance, set when the scene is built (the app rebuilds on a switch), via `u_day`:
- **Dark Mode (night):** the sky runs from `u_low` at the bottom to `u_top`. Lights add on, and the fog adds a `u_low × 0.55` haze low down.
- **Light Mode (overcast day):** the same lights read as coloured blurs. The sky is multiplied by `exp(-1.3 × (strength − 0.8 × tint))`, then fogged glass lifts it toward white by `0.15 × blur`, so wiped trails look clearer and darker. Drops brighten the view behind them ×1.05 rather than ×1.3.

It doesn't follow the real time or weather.

## Settings
**Colors:** `rain.palette`, which defaults to City (a `PaletteChoice` with `standard: "City"`); Random rolls one on each load. Each entry in `rainPalettes` holds a night sky (top and low), a day sky (top and low), and five light tints:

| Palette | Lights |
|---|---|
| City | sodium orange, warm white, red tail lights, cool LED blue, rare green (the original look) |
| Neon | magenta, cyan, violet, electric blue, rare amber |
| Blue Hour | LED white, steel blue, warm windows, teal, rare red |
| Sunset | gold, rose, amber, lilac, rare cream |
| Harbor | aqua, warm white, green and red channel markers, sodium |
| Holiday | warm fairy lights, red, green, gold, rare blue |
| Graphite | whites and silvers only |

Each swatch shows the night glow and the two most common lights (Dark Mode), or the day sky and those lights (Light Mode).

Suggested knobs, not built yet:

| Key | Label | Range | Default | Drives |
|---|---|---|---|---|
| `rain.speed` | Speed | 0.2–3 | 1 | integrated `u_phase` in place of `u_time` |
| `rain.drops` | Rain | 0–1 | 0.7 | share of columns with a slider (today `step(0.3, …)`) |
| `rain.fog` | Condensation | 0–1 | 1 | haze amount and bead share |
| `rain.blur` | Blur | 0.3–1 | 1 | background `blur` passed to `city()` |


## Tuning constants
- Traffic band heights: 0.27 and 0.2. Traffic speeds: 0.012 and 0.009.
- Bead cell: 0.03. Bead life: 1/0.02 = 50 s.
- Slider column widths: 0.1 and 0.065.
- Lens offset: 0.07. Trail height: 0.3.
- Through-drop brightness: ×1.3.

## Performance
Measured at CPU 0.45 ms and GPU 1.30–1.40 ms (either look) per frame (release build, 2x). The cost is dominated by `city()`, which runs five bokeh evaluations and up to three times per pixel under drops and trails. That leaves about 0.6 ms of GPU headroom. Adding drops or trails multiplies the city lookups.

## Gotchas and shortcuts
- `ponytail:` the lens is a fixed-width offset (`drop.xy * 0.07`), not real refraction. It's enough to read as water. Upgrade by offsetting along the drop's surface normal, scaled by its thickness.
- Uses `pow((p.y - 0.27) / 0.06, 2.0)` with a possibly negative base. GLSL leaves `pow` undefined for x < 0, so squaring by multiplying would be safer (the same pattern appears in LavaLamp).
- `u_time` doesn't advance in the render harness, so a snapshot is always the same moment.

## Dave's feedback and decisions
- Built in the first "build out all of those ideas" batch by the shaders agent; it hasn't had a fidelity pass.
- When the first batch landed it was judged the weakest shader scene: the drops don't stand out much.
- 2026-09-24, Dave: "raindrops is great". He asked for colour palettes in Settings, with a default that follows the system's Light or Dark Mode, "then allow a bunch of other color pallets". Hence City as the default, and every palette with both a night and a day look.

## Ideas / next steps
- **Bigger, bolder drops:** real refraction, merging when drops touch, and a thicker bright rim so they read at a glance.
- **Time and weather:**
  - follow the real Sun instead of the system appearance: lights come on after dusk
  - optionally only rain when it's raining where Dave is (reuse `WeatherScene.conditions`)
- **Occasional details:** passing headlight streaks, and a rare distant lightning flash.
- **Variety:** roll the layout on each load, like Nebula (Random already rolls the palette).

## Checking it
`SNAPSHOT_SCENE="Rain on Glass" SNAPSHOT_DEFAULTS="rain.palette=Neon" SNAPSHOT_APPEARANCE=light SNAPSHOT_DIR=/tmp/rain swift test`, then read the PNG. Motion can't be seen through `SNAPSHOT_SECONDS`. To preview other moments, temporarily add an offset to `t` in your copy (e.g. read from an env var and interpolated into the source), and remove it before committing.
