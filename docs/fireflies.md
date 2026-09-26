# Fireflies

A meadow at blue hour, painted in gouache on canvas: a slate-teal sky deepening to indigo at a soft treeline, an olive field, and blades of grass in the foreground. Hundreds of fireflies fly slow paths over the grass, each flashing every few seconds as it goes, as cream dabs of paint. Some wear a watery wash or a pale dry-brush burst.

- **Files:** `Sources/Atrium/Fireflies.swift`.
  - The `Fireflies` scene.
  - **The helpers shared by the nature scenes**, below `// MARK: - Shared by the nature scenes`:
    - `frameTime(_:_:)`: the clamped frame delta
    - `rgb` and `mixRGB`
    - `verticalGradient(_:)`
    - `backdrop(_:_:)`: a dithered sky sprite
    - `radialGlow(diameter:stops:)` and `softDot()`
    - `treeline(width:base:hills:trees:spacing:color:pineChance:clearing:resolution:)`
    - `pine`, `broadleaf` and `grassFringe`

  Campfire, Murmuration, Live Sky, Pixel City and the Fish Tank use some of these, so changing them affects those scenes too.
- **Entry:** `@MainActor func fireflies(size:)`, which returns `final class Fireflies: SKScene`. Registry entry: icon `sparkle`, tint `.yellow`, `knobs: Fireflies.knobs`.
- **Kind:** SpriteKit. There are two full-screen shaders (the sky, and the canvas multiplied over everything), grass painted once with Core Graphics, and a pool of firefly sprites sharing one shader.

## Reference
Dave picked three images for the mood (2026-09-25):
1. A gouache painting of cream fireflies over grass under a navy sky. The painted look is sampled from it.
2. A photo of fireflies at a green forest edge, with big bokeh discs up close.
3. Mauney's Nat Geo long exposure of a meadow full of firefly streaks under an afterglow sky.

Sampled from the painting (sRGB, 0–255):

| Where | Colour |
|---|---|
| Top | 80, 103, 112 (slate teal) |
| 0.8 up | 51, 67, 71 |
| 0.6 up | 38, 39, 51 (indigo) |
| 0.4 up | 42, 44, 38 (dark olive) |
| Bottom | 58, 56, 32 (olive) |
| The dots | 254, 240, 158 (cream) |

## How it works
1. **The view is a real camera.**
   - The eye is 1.2 m above the grass, the horizon sits at 46% of the height, and the focal length is 1.2 screen heights.
   - `project(x, y, d)` puts a point `d` metres away and `y` metres up at `horizon + focal·(y − eye)/d`. The grass along the bottom edge is then about 3 m away.
   - Fireflies and grass live in metres. Perspective alone makes distant ones smaller and slower, and makes near ones swoop further.
2. **Sky and field** (`skySource`): the painting's gradient in a `verticalGradient` texture.
   - It's sampled a little up or down by stretched noise, so it looks laid on in broad strokes across, with bristle streaks.
   - A soft treeline is dabbed along the horizon: crowns at 3–8% of the height above it, with a dry-brush edge.
3. **Grass** (`grass(from:to:)`): four bands of blades, rooted 2.5–3.4, 3.4–4.8, 4.8–7 and 7–12 m away.
   - Each blade is 0.12–0.4 m tall and 6–13 mm wide in the world, drawn as a tapered stroke in one of five sage or teal greens. A paler stroke runs up it toward the tip.
   - It's painted at half resolution, which softens the strokes. `bristleSource` then streaks each stroke with less paint where the dry brush skipped.
   - Further blades sink toward the field colour.
   - There are 25 blades per square metre of meadow, with at least 250 a band so the front stays thick.
   - Each band is its own sprite at z `100 − its middle distance`, so fireflies pass behind nearer grass.
4. **Canvas** (`canvasSource`): linen threads both ways (about 2.6 pt apart and uneven), fine grain, and gouache drying patchy. It's multiplied at 2x over everything, fireflies included, so 0.5 leaves a colour as it was.
5. **Fireflies** (`Fly`, `spawn`, `rest`, `dress`).
   - There's a pool of 1200 sprites. `fireflies.density` × 600 of them are active.
   - **Where they are:**
     - Half are spread evenly down the screen, as in the painting. The other half are spread evenly over the meadow's area, which crowds them toward the treeline.
     - They fly 0.1–2.1 m up (weighted low) at 0.04–0.12 m/s, turning up to 0.8 rad between flashes.
     - Once one drifts out of view or past the treeline, it's put somewhere new.
   - **Flashing:**
     - Each has its own period of 4.5–6.5 s, with ±15% jitter each time.
     - A flash lasts 1.4 s: in over the first 12%, held, then out over the last 30%.
     - During it the firefly dips a little, then climbs 0.1 m, like *Photinus*'s J-stroke.
     - Between flashes it's hidden, so about 150 are lit at once.
   - **The dab** (`flySource`): a cream disc with a soft, slightly wobbly edge and a paler middle, `min(max(24/d, 2.2), 8)` pt in radius. A faint glow of cream paint surrounds every dab, out to 2.6 radii.
     - 10–50% of them (more often the nearer they are) wear a halo: either a translucent grey-teal wash about 3.4 radii wide, with pigment pooled at its ragged rim, or a pale dry-brush burst.
     - `a_fly` carries the radius, the sprite's half-width and the kind plus a seed. The node's alpha fades it through `v_color_mix.a`.

## Time and appearance
Time is accumulated from `frameTime` in `update(_:)`, so it pauses with the view. It's always blue hour, by Dave's choice, with no Light Mode look and no link to the real time. The layout is random on each load.

## Settings
- `fireflies.density` (Fireflies, 0.25–2×, standard 1): how many are active. It's live.

Planned: a Look switch between Painted and Photo (see Ideas), flash patterns (synchronous *Photinus carolinus*), and focus and depth of field for the photo look.

## Tuning constants
- Camera: eye 1.2 m, horizon 0.46, focal 1.2.
- Meadow: 2.5 m to the treeline at 60 m. Grass bands and density are as above.
- Flight: 0.04–0.12 m/s. Flash: 1.4 s long, a 4.5–6.5 s period and a 0.1 m climb.
- Dab radius: 24/d, from 2.2 to 8 pt.

## Performance
CPU 0.5 ms and GPU 1.45 ms per frame (release build, 2x, 2026-09-25).
- **CPU:** a loop over 1200 flies that only touches the ones flashing, about 150. About seven a frame get new attributes as they finish a flash.
- **GPU:** mostly the sky and canvas shaders, which are static but recomputed every frame. ponytail: render them to textures once with `SKView.texture(from:)` in `didMove(to:)` if the GPU cost matters. The render test never calls `didMove`, so it would still show the unbaked cost.
- **Memory:** the four grass textures are full-width at 2x, the lower 40% of the screen or less.

## Gotchas and shortcuts
- Painted fireflies fade with node alpha. In SpriteKit custom shaders, that arrives as `v_color_mix.a`.
- `half` is a reserved word in Metal, so don't name a shader variable that.
- The grass is static: no sway.

## Dave's feedback and decisions
- The first version was a flat vector forest (violet fog, cut-out pines, about 15 fireflies lit at a time), built in the "build out all of those ideas" batch. It never had a fidelity pass.
- 2026-09-25: Dave asked for a high-fidelity pass after his three references (above). He chose:
  - both a photoreal look and a painterly one, to compare and then cut the loser
  - a meadow and treeline over a forest understory
  - live flashes with bokeh over long-exposure trails
  - always blue hour over following the real evening
- The painted look came first, since it needs no photo. The old forest was replaced outright rather than kept to compare, since Dave had no attachment to it.
- 2026-09-25, first look at the painted version: "it looks too cartoony and the fireflies are moving too fast."
  - Flight slowed from 0.15–0.4 m/s to 0.04–0.12, and the J-stroke climb from 0.3 m to 0.1. A near firefly was sweeping about 200 pt a second.
  - Softened: grass at half resolution with dry-brush streaks, and dabs with soft edges and a painted glow.
  - A painting will always read as illustration. The photo look is the realistic answer.

## Ideas / next steps
- **Photo look (in progress):** a real meadow photo relit to blue hour (as for Aurora and Weather), with photographic fireflies:
  - points in focus, bokeh discs up close, energy-conserving, with a saturating tone map so sharp cores clip to warm white
  - fireflies hidden behind nearer grass by the photo's depth map
  - then a Look setting to compare the two
- **Real flash patterns:** *Photinus pyralis* timing, synchronous *Photinus carolinus* waves, *Photuris* flickers (research in progress).
- Grass swaying gently. Bake the static shaders.

## Checking it
`SNAPSHOT_SCENE="Fireflies" SNAPSHOT_SECONDS=8 SNAPSHOT_DIR=/tmp/ff swift test`. Motion runs through `update(_:)`, so `SNAPSHOT_SECONDS` advances flights and flashes. Compare with the painting for colour and dab size.
