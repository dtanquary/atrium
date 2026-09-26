# Fireflies

A broad meadow at blue hour: a real photo of a field running to a leafy treeline, relit for dusk under a deep blue sky with a faint afterglow. Fog pools at the foot of the trees and thickens with distance, drifting in slow wisps. Hundreds of fireflies fly slow paths over the field, each glowing as a soft cream orb every few seconds, some in a pale halo.

- **Files:**
  - `Sources/Atrium/Fireflies.swift`
  - `Resources/fireflies-meadow.heic` and `Resources/fireflies-meadow-aux.png`, credited in `Resources/fireflies-credits.tsv`
  - The helpers shared by the nature scenes are below `// MARK: - Shared by the nature scenes`: `frameTime`, `rgb`, `mixRGB`, `verticalGradient`, `backdrop`, `radialGlow`, `softDot`, `treeline`, `pine`, `broadleaf` and `grassFringe`. Campfire, Murmuration, Live Sky, Pixel City and the Fish Tank use some of them, so keep their signatures.
- **Entry:** `@MainActor func fireflies(size:)`, which returns `final class Fireflies: SKScene`. Registry entry: icon `sparkle`, tint `.yellow`, `knobs: Fireflies.knobs`.
- **Kind:** SpriteKit. A sky shader, the photo drawn in five slices by distance with a relighting and fog shader, and a pool of firefly sprites sharing one shader.

## Reference
Dave picked three images for the mood (2026-09-25):
1. A gouache painting of cream fireflies over grass under a navy sky.
2. A photo of fireflies at a green forest edge, with big bokeh discs up close.
3. Mauney's Nat Geo long exposure of a meadow full of firefly streaks under an afterglow sky.

A research agent measured all three and read up on real fireflies. Its notes are in the session scratchpad, `notes/science.md`. The headlines:
- **Real fireflies:** *Photinus pyralis* flashes about 0.5 s every 5.5 s at 25 °C, a lemon yellow of about 563 nm, flying about half a metre up.
- **Photos:** real photos put fireflies thickest just below the treeline, 0.1–0.3 of the height beneath it.
- **Long exposures:** the meadow between the fireflies is near-black green.

## How it works
1. **The photo.** "Field at dusk" by Tristan Ferne (CC BY 2.0), a young wheat field running to a continuous leafy treeline, shot at real dusk.
   - A research agent cut and baked it (its scripts are in the scratchpad, `meadow/`). The sky is cut out, and the daylight and colour cast are taken out, leaving roughly albedo at half scale: 4096×1461 with alpha.
   - The aux map holds log distance in red (Depth Anything V2 through Core ML; 0 nearest, 1 at 32 times as far) and open field in green.
   - The crop fills a 1512×982 screen exactly, with the photo's top edge at 0.549 of the height. On a wider screen it's scaled up from that top edge, and `stretch` scales the view with it.
2. **The view is fitted to the photo.**
   - The lens (16 mm on a GF1) gives a focal length of 1.424 screen heights.
   - A ground plane fitted over the open field (`v = 0.3585 − 0.3387/D`, R² 0.987) gives the horizon, and with the eye 1.5 m up, 6.3 m per unit of the depth map's distance.
   - `project(x, y, d)` puts a point `d` metres away and `y` metres up at `horizon + focal·(y − eye)/d`. The bottom edge is about 6 m away, and the treeline's foot about 50 m.
3. **Sky** (`skySource`):
   - Deep blue overhead, paler toward the treeline, with a faint warm afterglow (a little stronger to the right).
   - A few stars, which fade out with the fog.
   - Fog lightens it low down.
4. **Ground** (`groundSource`), drawn five times, once per slice of distance (0–5, 5–9, 9–16, 16–28 and 28+ m, the last behind every firefly). Each slice sits at z `100 − its middle distance`, so fireflies pass behind nearer ground. In each slice:
   - The albedo is lit by a dim blue skylight, `(0.03, 0.036, 0.042)`, with a 15% Purkinje shift toward blue-grey.
   - **Fog** is clear close by and thickens with the square of the log distance: `1 − exp(−fog·(0.1 + 2.2·far²)·wisps·low)`.
     - `low` thins it up the trees (down 85% by 70% of their height), so mist pools at their foot while the crowns stay a dark silhouette.
     - `wisps` is warped noise drifting slowly across on `u_time`.
     - The fog colour is `(0.04, 0.05, 0.07)` in linear light.
   - **Wind:** the photo is sampled a little to the side, only on the open field (the aux map's green; never the trees), by `wind·(1 − far)²`: most up close, nothing in the distance.
     - Broad gusts (`noise`, drifting across at 0.06 photo widths a second, about 1.3 m/s at 20 m) set how far the grass leans.
     - Each patch also rustles at its own phase (`sin(1.6 t + noise)`).
     - At `fireflies.wind` 0.5, it leans about ±0.75 pt typically and 2.5 pt at most. The leaning stalks brighten by up to 6% where a gust passes.
   - Each pixel belongs to exactly one slice, so the other four skip all the work (an `if` on the slice); that halved the ground's cost.
5. **Fireflies** (`Fly`, `spawn`, `rest`, `dress`, `flySource`).
   - There's a pool of 800 sprites. `fireflies.density` × 400 of them are active.
   - **Where they are:**
     - Most are spread evenly over the meadow's area, 3–50 m out, so there are many more far off than near, crowding toward the treeline as in photos of real fields. A third are spread evenly by distance instead, to fill the middle of the field.
     - They fly 0.15–1.75 m up, weighted low; the few above eye height show against the trees.
     - They drift at 0.02–0.05 m/s, turning up to 0.8 rad between flashes. Once one drifts out of view or past the treeline, it's put somewhere new.
   - **Flashing:**
     - Each has a period of 6–10 s, with ±15% jitter each time.
     - A glow lasts 3 s: easing in over the first 35%, then out from 55%. That's a slow pulse, much slower than a real *Photinus* flash (about 0.5 s), by Dave's choice.
     - It rises 0.03 m over the glow. Between glows it's hidden.
     - `fireflies.speed` scales the scene's own clock, so drift, glows and gaps all speed up or slow down together.
   - **The orb:**
     - A cream disc (#fef09c) with a soft, slightly wobbly edge and a faint glow out to 2.6 radii.
     - Its radius is a glow about 4.5 cm across in the world (`focal·0.045/d`, with a log-normal spread of σ about 0.3, from 1 to 9 pt). So it shrinks with distance: 9 pt at 7 m, about 1.5 pt by the treeline.
     - Within 12 m, 20% sit in a pale grey-teal halo about 2.6 times their size, a little off centre, with a ragged edge, and 25% are a halo alone, a firefly out of focus.
     - `a_fly` carries the radius, the half-width, the kind plus a seed, and how much light gets through the fog (`clearness(d)`, the same curve as the ground's). The node's alpha fades it through `v_color_mix.a`.

## Time and appearance
Time is accumulated from `frameTime` in `update(_:)`, so it pauses with the view. It's always blue hour, by Dave's choice, with no Light Mode look and no link to the real time. The layout of the fireflies is random on each load.

## Settings
- `fireflies.density` (Fireflies, 0.25–2×, standard 1): how many are active. It's live.
- `fireflies.fog` (Fog, 0–1, standard 0.5): live for the ground and sky, and for each firefly from its next flash.
- `fireflies.speed` (Speed, 0.25–2×, standard 1): how fast they drift, glow and fade. It scales the scene's clock and is live.
- `fireflies.wind` (Wind, 0–1, standard 0.5): how much the grass sways. Live. 0 holds it still.

## Tuning constants
- **Photo placement and view:** in `MeadowPhoto`.
- **Light and fog:** skylight `(0.03, 0.036, 0.042)`, fog colour `(0.04, 0.05, 0.07)`, and a fog curve of `0.1 + 2.2·far²` with 85% thinning up the trees.
- **Fireflies:** drift 0.02–0.05 m/s; a glow 3 s long, a 6–10 s period and a 0.03 m rise; a 4.5 cm glow; a third spread by distance, the rest by area.

## Performance
CPU 0.54 ms and GPU 0.52 ms per frame (release build, 2x, 2026-09-26).
- **CPU:** a loop over 800 flies that only touches the ones glowing, about 150. A few a frame get new attributes as they finish a glow.
- **GPU:**
  - the five ground slices, each covering the photo's rect; a pixel outside a slice costs one texture read, and inside, five noise calls and two reads
  - the sky
  - the orbs

  ponytail: crop each slice's sprite to the rows its distances occupy if the GPU cost matters.
- **Memory:** the photo is 4096×1461 RGBA, about 24 MB decoded.

## Gotchas and shortcuts
- **Fading:** orbs fade with node alpha, which a SpriteKit custom shader gets as `v_color_mix.a`.
- **Metal naming:** `half` is a reserved word in Metal, so don't name a shader variable that.
- **Depth slices:** a firefly is in front of or behind a whole slice, so it can pass in front of grass up to half a slice nearer than it. The slices are narrow near the camera, where it shows.
- **Flat ground plane:** the plane underestimates the far end of the field, which rises to the right.
- **Wheat, not grass:** the photo's field is young wheat. At blue hour it reads as a meadow.

## Dave's feedback and decisions
- **The first version** was a flat vector forest (violet fog, cut-out pines, about 15 fireflies lit at a time), built in the "build out all of those ideas" batch.
- **2026-09-25:** Dave asked for a high-fidelity pass after his three references. He chose to compare a photoreal look with a painterly one, a meadow and treeline, live flashes, and always blue hour.
- **The painted look came first** (0.15.0), with its colours, sizes and layout measured from the painting.
  - "It looks too cartoony and the fireflies are moving too fast": the flight slowed, and the paint was softened.
  - Rebuilt to the measured painting (torn dry-brush bursts, spatter, stains, clumped grass, canvas speckle): "made them look worse, like paint splatters." The splatter went and the soft glowing orbs came back (0.16.2).
- **2026-09-26:** "I don't want it to look like an art painting, I want it to look like a realistic foggy meadow with a treeline", then "forget the painting look", and "the firefly orbs you have now look very nice, use them in a more broad meadow, more real scene."
  - So the painted sky, grass and canvas went, and so did the planned Photo/Painted comparison. The orbs stayed exactly as they were, now in the relit photo meadow with fog (0.17.0).
  - A photographic firefly model (points in focus, energy-conserving bokeh discs up close, a saturating tone map) was built and rendered, but not shipped, since Dave liked the orbs.
- **2026-09-26, first look at the meadow:** "it looks great except 2 things: most of the fireflies are right up next to the camera, they don't look spread out; they are all still moving and fading in and out too fast." Then: "add the firefly speed to a settings slider."
  - The painting-sized orbs were all about the same size, so they read as near. They now scale with distance, and most are spread over the meadow's area.
  - The flash went from 1.4 s with snappy fades to a 3 s pulse, the period from 4.5–6.5 s to 6–10 s, and the drift slowed by a factor of three.
  - Speed is a knob that scales the scene's clock (0.17.1).
- **2026-09-26:** "Fireflies is near perfect now, we just need to find a way to have a super subtle sway animation for the grass as if there is a very slight wind." The field sways in slow gusts, with a Wind setting (0.18.2).
  - The standard is 0.5: at 0.3 the typical lean was half a point, which read as still.
  - The sway can't be checked in the render test, because `u_time` doesn't advance between its runs. It was measured by pinning the time at two values in a scratch copy: the near field changes, and the trees and far field don't.
- **Photo choice:** a research agent shortlisted ten licensed meadow photos and baked four: Field at dusk, Herbst (Thomas Heins, CC BY 4.0), Indian Hollow and Pewley Downs. Field at dusk won for its real dusk light, continuous treeline and grass texture up close. Herbst, a flatter and broader meadow with mist already at the trees' foot, is the runner-up. Its bake is in the scratchpad, `meadow/ship/`.
  - Also tried: a real fog photo, "Desenka meadow 2016 G3" by George Chernilevsky (public domain), baked with its mist kept in. In the scene, at blue-hour brightness, the mist all but vanished. Its trees are near and tall at 50 mm, which leaves the meadow a thin dark strip, the opposite of broad. Shader fog over the wider field reads better.

## Ideas / next steps
- **Synchronous flashing,** like *Photinus carolinus*: bursts of 4–8 flashes 0.5 s apart, 6–9 s dark, relayed across the field at about 0.5 m/s.
- **Follow the real evening:** fireflies come out at sunset, peak about 30 minutes later and thin out by 90–120 minutes.
- **Faint light on the grass** around near flashes.
- Crop the ground slices to their rows.

## Checking it
`SNAPSHOT_SCENE="Fireflies" SNAPSHOT_SECONDS=8 SNAPSHOT_DIR=/tmp/ff swift test`. Motion runs through `update(_:)`, so `SNAPSHOT_SECONDS` advances flights and flashes. `u_time` follows the wall clock, so fog wisps don't move forward with it. `SNAPSHOT_DEFAULTS="fireflies.fog=1"` shows thick fog.
