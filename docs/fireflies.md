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
5. **Fireflies** (`Fly`, `spawn`, `rest`, `dress`, `flySource`).
   - There's a pool of 1200 sprites. `fireflies.density` × 600 of them are active.
   - **Where they are:**
     - Each picks a spot on screen by tenth of the height from the bottom, weighted 10, 30, 60, 45, 12, 3: thickest just below the treeline, some against the trees, few above them.
     - It's then placed in the meadow at the distance that puts it there: 0.1 m up to just below eye height over the field, or up to 1.5 m above eye height against the trees and sky.
     - They fly at 0.04–0.12 m/s, turning up to 0.8 rad between flashes. Once one drifts out of view or past the treeline, it's put somewhere new.
   - **Flashing:**
     - Each has a period of 4.5–6.5 s, with ±15% jitter each time.
     - A flash lasts 1.4 s: in over the first 8%, held, then out over the last 15%. The fades are quick, because an orb caught half faded reads as a khaki blot.
     - It dips a little, then climbs 0.1 m, like *Photinus*'s J-stroke. Between flashes it's hidden.
   - **The orb:**
     - A cream disc (#fef09c) with a soft, slightly wobbly edge and a faint glow out to 2.6 radii.
     - Its radius is 0.5% of the height times a log-normal spread (σ about 0.45), only a little bigger nearer (`(8/d)^0.3`, clamped to 0.75–1.3). Those sizes are measured from the painting.
     - 20% of the bigger ones sit in a pale grey-teal halo about 2.6 times their size, a little off centre, with a ragged edge.
     - Fireflies over 25 m away are small and dim (#9c936c). 4% are a halo alone, a firefly out of focus.
     - `a_fly` carries the radius, the half-width, the kind plus a seed, and how much light gets through the fog (`clearness(d)`, the same curve as the ground's). The node's alpha fades it through `v_color_mix.a`.

## Time and appearance
Time is accumulated from `frameTime` in `update(_:)`, so it pauses with the view. It's always blue hour, by Dave's choice, with no Light Mode look and no link to the real time. The layout of the fireflies is random on each load.

## Settings
- `fireflies.density` (Fireflies, 0.25–2×, standard 1): how many are active. It's live.
- `fireflies.fog` (Fog, 0–1, standard 0.5): live for the ground and sky, and for each firefly from its next flash.

## Tuning constants
- **Photo placement and view:** in `MeadowPhoto`.
- **Light and fog:** skylight `(0.03, 0.036, 0.042)`, fog colour `(0.04, 0.05, 0.07)`, and a fog curve of `0.1 + 2.2·far²` with 85% thinning up the trees.
- **Fireflies:** flight 0.04–0.12 m/s; a flash 1.4 s long, a 4.5–6.5 s period and a 0.1 m climb; placement weights as above.

## Performance
CPU 0.57 ms and GPU 0.91 ms per frame (release build, 2x, 2026-09-26).
- **CPU:** a loop over 1200 flies that only touches the ones flashing, about 150. About seven a frame get new attributes as they finish a flash.
- **GPU:**
  - the five ground slices, each covering the photo's rect, with two texture reads and three noise calls a pixel before most are discarded
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
- **Photo choice:** a research agent shortlisted ten licensed meadow photos and baked four: Field at dusk, Herbst (Thomas Heins, CC BY 4.0), Indian Hollow and Pewley Downs. Field at dusk won for its real dusk light, continuous treeline and grass texture up close. Herbst, a flatter and broader meadow with mist already at the trees' foot, is the runner-up. Its bake is in the scratchpad, `meadow/ship/`.

## Ideas / next steps
- **Synchronous flashing,** like *Photinus carolinus*: bursts of 4–8 flashes 0.5 s apart, 6–9 s dark, relayed across the field at about 0.5 m/s.
- **Follow the real evening:** fireflies come out at sunset, peak about 30 minutes later and thin out by 90–120 minutes.
- **Faint light on the grass** around near flashes.
- Crop the ground slices to their rows.

## Checking it
`SNAPSHOT_SCENE="Fireflies" SNAPSHOT_SECONDS=8 SNAPSHOT_DIR=/tmp/ff swift test`. Motion runs through `update(_:)`, so `SNAPSHOT_SECONDS` advances flights and flashes. `u_time` follows the wall clock, so fog wisps don't move forward with it. `SNAPSHOT_DEFAULTS="fireflies.fog=1"` shows thick fog.
