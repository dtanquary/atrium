# Zen Garden

A karesansui (Japanese dry garden) seen from above: pale raked sand with grooves lit by a low sun, concentric rings around five mossy stones, and a wooden rake that slowly works across the garden stroke by stroke, leaving a new pattern behind it.

- **Files:** `Sources/Wallpaper/ZenGarden.swift`.
  - `ZenGarden`: the scene, the rake motion, and the painted stones and rake.
  - `sandShader`: the sand shader, as its own GLSL with its own `hash` and `noise`, not `shaderCommon`.
  - `frameTime` comes from Fireflies.swift.
- **Entry:** `@MainActor func zenGarden(size:)`, which returns `final class ZenGarden: SKScene`. Registry entry: icon `leaf.fill`, tint `.mint`.
- **Kind:** hybrid. A full-screen sand shader plus stone and rake sprites, with the rake state pushed into the shader each frame.

## How it works
1. **Stones.** Five at fixed fractions of the screen, with radii 0.028–0.09 × `min(w, h)`.
   - Each is painted as an irregular 12-point rounded blob, lit from the upper left with speckle, and given a random rotation.
   - Their centres and radii go to the shader as `u_s0`…`u_s4` (vec3).
2. **Height field (`height`).**
   - Within `RINGS × SPACING` (5 × 13 pt) of the nearest stone edge (`nearest()`, the minimum distance over the five circles), grooves follow that distance, forming rings.
   - Elsewhere, grooves follow `lines(p, kind)`: kind 0 is straight rows, kind 1 is ripples (9 pt amplitude, period 55·2π), kind 2 is long swells (34 pt, 210·2π).
   - Groove profile: `pow(0.5 + 0.5 cos 2πu, 0.7)`.
3. **The rake reveals the next pattern.**
   - `u_rake` is (current band, head x, direction, unused) and `u_kinds` is (pattern before, pattern after).
   - Bands above the current one, and the part of the current band behind the head, show the after pattern; the rest shows the before pattern.
4. **Lighting.**
   - The surface normal comes from two extra height samples (+1 pt in x and y), lit from the upper left.
   - Sand colour (0.86, 0.81, 0.71) plus per-pixel grain.
   - Stones cast a soft shadow offset by (10, −10) pt.
   - Moss rings have a noisy edge (`18 × noise(p/22) − 3`).
   - Light vignette.
5. **Rake motion (`rakeTo(t)`).**
   - Strokes are 104 pt bands (`band`: 8 tines at 13 pt). They alternate left-to-right and right-to-left from the top band down, at 30 pt/s (`rakeSpeed`), running 140 pt past each edge (`margin`).
   - A full pass takes `ceil(h / 104) × (w + 280) / 30`, about 10 minutes at 1512×982. Each pass moves to the next of the three patterns (`cycle % 3`).
   - It starts 40% into a pass and 45% into a stroke, so both patterns and the rake show at launch.
   - The rake sprite (320 pt, anchored at its head) flips with direction. It fades out (alpha) when close to a stone's rings, because the rings are drawn independently of the rake.

## Time and appearance
- Scene time accumulates through `frameTime`, and the rake position is a pure function of that time.
- It's always daylight sand. In Dark Mode it's by far the brightest wallpaper, so it's the obvious candidate for an appearance-aware look: moonlit sand and cool shadows in Dark Mode.

## Settings
None yet. Suggested:

| Key | Label | Range | Default | Notes |
|---|---|---|---|---|
| `zen.rakeSpeed` | Rake speed | 10–90 pt/s | 30 | `rakeTo` is computed from total time, so integrate progress first or the rake jumps when this changes |
| `zen.rake` | Show rake | switch | 1 | hide the rake; patterns still change |

A `zen.sand` palette could offer Sand (today's), White Gravel, Dark Slate, and Moonlit (the Dark Mode look). Pattern switches (straight, ripple or swells on or off) could feed `u_kinds`.

## Tuning constants
- In the shader: `SPACING` 13, `RINGS` 5, the pattern amplitudes (9 and 34) and periods (55 and 210), the light direction (−0.5, 0.65, 0.55), and the slope gain 2.4.
- In Swift: `band` 104, `rakeSpeed` 30, `margin` 140.

## Performance
Measured at CPU 0.43 ms and GPU 0.57 ms per frame (release build, 2x). GPU cost is three `HEIGHT` evaluations per pixel (each with a `nearest` over five stones) plus two more `NEAREST` calls for shadow and moss. There's plenty of headroom.

## Gotchas and shortcuts
- **Uniforms in helpers:** SpriteKit only exposes uniforms inside `main()`, so the shader uses `#define NEAREST(q)` and `#define HEIGHT(q)` macros to pass uniforms into helpers.
- **No global `const`:** the shader uses `#define SPACING` and `RINGS` instead.
- **Duplicated constant:** Swift repeats `RINGS × SPACING` as `5 * 13` in the rake-fade clearance. Change both together.
- **Fixed sizes:** the rake (320 pt) and band (104 pt) are fixed, so on big screens a pass takes longer and the rake looks small.
- **Rings never change:** only the open sand gets new patterns.
- **Moss and stones are simple** (flagged by the nature agent).

## Dave's feedback and decisions
- Built by the nature agent in the first batch.
- No specific feedback, and no fidelity pass.
- The full redraw was reported to Dave as "about 9 minutes"; the code comment says "about ten", which matches 1512 pt.

## Ideas / next steps
- **Layout:** a random stone layout on each load, and occasional re-raking of the rings.
- **Seasons:** fallen maple leaves drifting in, which the rake sweeps away.
- **Light:** follow the real Sun, with shadows swinging through the day and a moonlit night look.
- **Stones:** real stone textures and lichen.

## Checking it
`SNAPSHOT_SCENE="Zen Garden" SNAPSHOT_SECONDS=60 SNAPSHOT_DIR=/tmp/zen swift test`. `SNAPSHOT_SECONDS` advances the rake, since it runs on `update(_:)` time. Rendering at different lengths shows it moving along a stroke. Seeing a whole pass needs about 600 s, which is slow in the harness.
