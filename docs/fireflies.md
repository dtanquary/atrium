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

A research agent measured the painting (2026-09-25; its notes are in the session scratchpad, `notes/science.md`). The painted look follows those numbers:

| What | Measured |
|---|---|
| **Colour, bottom to top** | Olive grass #3f3e26 → darkest ground #2d2c29 at 0.37 → violet-indigo #292935 at 0.62 → slate teal #526973 at the top. It varies left to right by only about ±4 levels. |
| **Dabs** | Flat cream #fef09c, a hard edge (1 px), no glow. Median diameter 1% of the height (p10 0.57%, p90 2.1%, max 3.4%). |
| **Where the dabs sit** | By tenth of the height from the bottom: 16, 56, 59, 42, 28, 18, 5, and none above 0.7. They're thickest just over the grass tops. |
| **Torn dabs** | About a third of the big ones are dry-brush bursts: a torn edge out to 1.4–1.6 radii, with cream spatter out to 2. Far ones are dim #9c936c. |
| **Stains** | Pale grey-teal washes about 2.6 times the dab's size (the ground mixed 25–35% toward #5a6a6a, so they're lighter than the ground), flat, off-centre, with ragged edges. Some have no dab in them. |
| **Grass** | The bottom 30% only. Near-vertical strokes 6–11% of the height long and 0.4% wide, pointed, leaning a few degrees (mostly right). Olive sage #56614e–#829480, with one in six a bluish #5c6f5f. They sit in clumps of 3–8, and the light comes from dry-brush skips, not the tips. |
| **Canvas** | Mostly a per-pixel speckle of about ±8 levels, a faint weave about 5 pt apart, and mottling over 10–40 pt. |

## How it works
1. **The view is a real camera.**
   - The eye is 1.2 m above the grass, the horizon sits at 46% of the height, and the focal length is 1.2 screen heights.
   - `project(x, y, d)` puts a point `d` metres away and `y` metres up at `horizon + focal·(y − eye)/d`. The grass along the bottom edge is then about 3 m away.
   - Fireflies and grass live in metres. Perspective alone makes distant ones smaller and slower, and makes near ones swoop further.
2. **Sky and field** (`skySource`): the painting's measured gradient in a `verticalGradient` texture.
   - It's sampled a little up or down by stretched noise, so it looks laid on in broad strokes across, with bristle streaks.
   - A soft treeline is dabbed along the horizon: crowns at 3–8% of the height above it, with a dry-brush edge.
3. **Grass** (`grass(from:to:)`): three bands of strokes, rooted 2.5–3.4, 3.4–4.6 and 4.6–6.2 m away, which keeps the tops below 30% of the height.
   - 22 clumps per square metre of meadow, each of 3–8 strokes sharing a colour and a lean (−0.12 to +0.2 of their height, so mostly right).
   - Each stroke is a flick of the brush: 0.18–0.4 m tall and 6–11 mm wide in the world, pointed at both ends and widest a third of the way up. Its root is buried a random 0–35% of its height, so the bases don't line up.
   - It's painted at half resolution, which softens the strokes. `bristleSource` then streaks them with less paint where the dry brush skipped.
   - Further clumps sink toward the soil colour.
   - Each band is its own sprite at z `100 − its middle distance`, so fireflies pass behind nearer grass.
4. **Canvas** (`canvasSource`), as measured: a speckle per point (±10%), a faint weave (±2.5%, threads about 5 pt apart) and mottling (±6%, over 10–40 pt). It's multiplied at 2x over everything, fireflies included, so 0.5 leaves a colour as it was.
5. **Fireflies** (`Fly`, `spawn`, `rest`, `dress`).
   - There's a pool of 1200 sprites. `fireflies.density` × 600 of them are active.
   - **Where they are:**
     - Each picks a spot on screen from the painting's counts by tenth of the height. It's then placed in the meadow at the distance that puts it there: 0.1 m up to just below eye height over the field, or up to 1.5 m above eye height against the sky.
     - They fly at 0.04–0.12 m/s, turning up to 0.8 rad between flashes.
     - Once one drifts out of view or past the treeline, it's put somewhere new.
   - **Flashing:**
     - Each has its own period of 4.5–6.5 s, with ±15% jitter each time.
     - A flash lasts 1.4 s: in over the first 8%, held, then out over the last 15%. The fades are quick, because paint caught half faded reads as a khaki blot.
     - During it the firefly dips a little, then climbs 0.1 m, like *Photinus*'s J-stroke.
     - Between flashes it's hidden, so about 150 are lit at once.
   - **The mark** (`dress`, `flySource`), from the painting's measurements:
     - A dab's radius is 0.5% of the height times a log-normal spread (σ about 0.45), and only a little bigger nearer (`(8/d)^0.3`, clamped to 0.75–1.3).
     - Of the bigger-than-median ones, 35% are torn into a dry-brush burst with spatter and 20% sit in a stain. Smaller ones rarely are.
     - Fireflies over 25 m away are small dim dabs (#9c936c).
     - 4% are stains alone (0.75–2.8% of the height across): fireflies out of focus.
     - `a_fly` carries the radius, the sprite's half-width, and the kind plus a seed. The node's alpha fades it through `v_color_mix.a`.

## Time and appearance
Time is accumulated from `frameTime` in `update(_:)`, so it pauses with the view. It's always blue hour, by Dave's choice, with no Light Mode look and no link to the real time. The layout is random on each load.

## Settings
- `fireflies.density` (Fireflies, 0.25–2×, standard 1): how many are active. It's live.

Planned: a Look switch between Painted and Photo (see Ideas), flash patterns (synchronous *Photinus carolinus*), and focus and depth of field for the photo look.

## Tuning constants
- Camera: eye 1.2 m, horizon 0.46, focal 1.2.
- Meadow: 2.5 m to the treeline at 60 m. Grass bands and density are as above.
- Flight: 0.04–0.12 m/s. Flash: 1.4 s long, a 4.5–6.5 s period and a 0.1 m climb.
- Dabs, stains and grass: as measured (above).

## Performance
CPU 0.7 ms and GPU 1.15 ms per frame (release build, 2x, 2026-09-25).
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
  - Then the agent's measurements showed the softening went the wrong way. The painting's dabs are hard-edged with no glow; its character comes from torn bursts, spatter, pale stains, clumped dry-brush grass and a strong canvas speckle. So the painted look was rebuilt to those numbers.

## Ideas / next steps
- **Photo look (in progress):** a real meadow photo relit to blue hour (as for Aurora and Weather), with photographic fireflies:
  - points in focus, bokeh discs up close, energy-conserving, with a saturating tone map so sharp cores clip to warm white
  - fireflies hidden behind nearer grass by the photo's depth map
  - then a Look setting to compare the two
- **Real flash patterns:** *Photinus pyralis* timing, synchronous *Photinus carolinus* waves, *Photuris* flickers (research in progress).
- Grass swaying gently. Bake the static shaders.

## Checking it
`SNAPSHOT_SCENE="Fireflies" SNAPSHOT_SECONDS=8 SNAPSHOT_DIR=/tmp/ff swift test`. Motion runs through `update(_:)`, so `SNAPSHOT_SECONDS` advances flights and flashes. Compare with the painting for colour and dab size.
