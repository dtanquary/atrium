# Fish Tank

A planted tank seen through the glass. Five species of shaded fish school at different depths among swaying plants, rocks, driftwood and an anemone. Caustics ripple over the sand, sun shafts sway down from a shimmering surface, and an airstone sends up bubbles.

- **Files:**
  - `Sources/Atrium/FishTank.swift` holds the scene: layers, schooling, the water, sand and caustics shaders, bubbles, marine snow and the vignette.
  - `Sources/Atrium/FishTankArt.swift` holds the `Species` enum (per-species numbers) and `TankArt`, which paints the fish, plants, rocks, driftwood, sand, far rocks and bubbles with Core Graphics. It also holds the warp-frame builders `swimWarps` and `swayWarps`.
- **Entry:** `final class FishTank: SKScene`, registered as `{ FishTank(size: $0) }` in Scenes.swift (icon `fish.fill`, tint `.teal`).
- **Kind:** hybrid. SpriteKit sprites painted in code, plus two SKShaders: the full-screen water and the sand.
- **Shared helpers:** `frameTime`, `rgb`, `mixRGB` and `softDot` live in Fireflies.swift as module-level functions. Moving or renaming them breaks this scene.

## How it works
Layers, back to front, from the `Z` enum:
1. **Water** (`addWater`), a full-screen SKShader, lit like a reef tank. Its colours were sampled from real reef tank photos: the CAS Steinhart coral tank and a public-aquarium reef tank on Wikimedia Commons. `Lighting.day` is used in Light Mode (daylight white-blue LEDs) and `Lighting.actinic` in Dark Mode (a reef tank's evening blue). The layers:
   - a saturated royal-blue back panel, brighter high up (`high` and `low`)
   - the lamp's pool of light, brightest mid-tank (`0.75 + 0.35·lamp`)
   - faint LED shimmer (caustics) and rays from the lamp array, fading downward
   - the underside of the surface along the top: a mirror band reflecting the tank, streaked by drifting noise (a regular wave read as a zigzag), a bright waterline, and the dark lid above
   - dither
2. **Sand** (`addSand`), all in its shader: white aragonite, warm white up front (`sandNear`) and going blue with distance (`sandFar`), with fine grain from `hash42`. Two caustic layers multiply the sand they land on rather than adding white, the way real light brightens it. They're bigger at the front and squashed by perspective (`pts.y * 2.6`), and the back edge melts into the back panel.
3. **Far rocks:** a fogged silhouette strip at the back edge of the sand.
4. **Plants in three rows**, from a pool of a few painted variants per row reused with flips and scales to keep texture memory down:
   - back row: fog 0.5
   - middle row: fog 0.12, leaving room around the anemone
   - front row: tall plants against the glass at both edges that fish swim behind

   Plants sway with a 1×8 warp grid (`TankArt.swayWarps`): the bend grows from base to tip and the tip lags. Each clump has its own period (4.5–7.5 s) and start delay.
5. **Hardscape:** four stone clusters (a big stone plus one or two smaller), a driftwood branch at x≈0.56, and the anemone at (0.3 w, 0.48 × sand height).
6. **Fish:** seven schools (`addSchools` plan), 53 fish in total:

   | Species | Count | Depth |
   |---|---|---|
   | neon tetra (far) | 14 | 0.55 |
   | blue tang | 2 | 0.6 |
   | yellow tang | 4 | 0.75 |
   | neon tetra (showpiece) | 26 | 0.85 |
   | angelfish | 2 | 0.88 |
   | clownfish | 2 | 0.95 |
   | blue tang (near) | 3 | 1.1 |

   Depth sets scale, speed, z-layer (far < 0.7, mid < 1, near) and fog (`(1 - depth) * 0.7`, painted into the texture).
7. **Bubbles:** an `SKEmitterNode` over an airstone at x = 0.8 w. It has buoyancy (`yAcceleration` 25), a lifetime solved so the bubbles reach the surface band, a `particleAction` wobble, and they swell slightly as they rise.
8. **Marine snow:** slow, faint specks across the whole tank (`softDot`).
9. **Vignette:** a radial darkening sprite on top.

**Fish art (`TankArt.fish`)** is painted once per school, facing right: a bezier body shaded from a dark back to a pale belly, species markings clipped to the body, translucent fins with rays, a gill line, a pectoral fin, and an eye with a catchlight. The markings:
- clownfish: three white bands edged in black
- blue tang: black "palette" marking and a yellow tail
- yellow tang: white scalpel spine
- neon tetra: blue stripe with a glow, red rear
- angelfish: black vertical bars and long trailing fins

**Schooling (`swim`)** uses boids within each species, with O(n²) per school:
- separation inside `gap` (body length × `Species.spacing`: 1.4 for tetras, 1.9 for the rest)
- alignment and cohesion within `sight` = 6 body lengths
- a random-walk wander angle
- clownfish pulled toward `home` above the anemone
- soft walls just past the screen edges (so turns mostly happen off-screen), and a floor and ceiling from `bounds(depth)`. Far schools can't go as low because the sand is nearer the eye there.
- vertical speed damped (`1 - 1.4·dt`) and total speed clamped to 0.45–1.35 × cruise

Everything is pre-simulated for 150 steps in `sceneDidLoad`, so schools have already formed on the first frame.

**Pose (`pose`):**
- facing eases through zero at 2.5 per second, so the fish visibly turns instead of flipping
- tilt follows pitch, clamped to ±0.3
- the tail beat steps through 20 precomputed warp frames (`swimWarps`: an 8×1 grid with a wave from head to tail, `0.075·(1-u)²`). The beat rate scales with speed.

## Time, live data and appearance
Motion is driven by `update(_:)` (boids and frame stepping) and `u_time` (the water and sand shaders). No network or location. Light Mode is a daylight reef tank and Dark Mode its actinic evening look, read from `systemIsDark` when the scene is built.

## Settings
None yet.

## Tuning constants
- **`Species` (FishTankArt.swift):**

  | Species | length (pt) | bodyHeight | cruise (pt/s) | beat (s) |
  |---|---|---|---|---|
  | clownfish | 62 | 0.40 | 24–32 | 0.42 |
  | blue tang | 84 | 0.50 | 42–54 | 0.62 |
  | yellow tang | 64 | 0.72 | 34–44 | 0.55 |
  | neon tetra | 27 | 0.28 | 44–58 | 0.30 |
  | angelfish | 70 | 0.74 | 18–26 | 0.95 |

  `finReach` is 0.62 for angelfish and 0.2 for yellow tang.
- **Scene scaling:** `unit` is height/982, clamped to 0.8–1.8, so a bigger screen gets a bigger tank rather than smaller fish. `fishUnit` is `unit × 1.2`, drawing fish a little larger than life so they read from across the room. `sandHeight` is 0.22 × height.
- **Fog colour:** `TankArt.fogColour` = rgb(0.035, 0.27, 0.39).
- **Reef light:** `Lighting.day` and `Lighting.actinic` in FishTank.swift (back panel high/low, mirror, shimmer, sand near/far).
- **Bubbles:** birth rate 8, speed 110 ± 40. **Snow:** birth rate 5, lifetime 40 s.

## Performance
CPU 0.51 ms and GPU 1.55 ms per frame (release, 2x). The GPU cost is mostly the full-screen water shader (a 3×3 Voronoi loop for the caustics, plus noise) and the sand shader (two caustic calls), with about 70 warped sprites on top. CPU is the boids, 53 fish at O(n²) per school. There's headroom for maybe twice the fish before CPU matters.

## Gotchas and shortcuts
- **Warp speed bug:** changing a node's `speed` every frame while `SKAction.animate(withWarps:)` runs on it makes SpriteKit steadily slower (1 ms up to 10 ms a frame within a minute). That's why fish step through warp frames by hand in `pose`. Plants use warp actions only because their speed never changes. This is also noted in CLAUDE.md.
- `ponytail:` O(n²) boids within a school, fine up to a few dozen fish per school. Use a spatial grid, like Murmuration, if schools grow.
- The shaders use `u_time`, which doesn't advance in the render test, so caustics and shafts look frozen in snapshots. Fish and plants do move (driven by `update` and SKActions).
- Plants and rocks are placed randomly on each load, so every tank is a little different.

## Dave's feedback and decisions
- 2026-09-25: "everything looks way too cartoony." After a research pass comparing it with real tank photos, he chose a realistic **reef** tank, **photo cut-out** fish and corals (or whatever is best quality), and **bright and lush** lighting. He also asked to be challenged on past calls: the earlier "drawn in code over image sprites" decision was reversed because photo cut-outs were clearly more realistic. The rebuild is in progress; the water, light and sand came first.
- The first version (flat `SKShapeNode` fish, stroked seaweed) was the proof of concept. Dave called it "the primitive fish tank" and asked how to raise the fidelity.
- He chose the drawn-in-code route over image sprites or RealityKit 3D, and picked items 1–5 of the fidelity list: fish that look alive, schooling, light, depth and plants/props. Rare events and a time-of-day tint were explicitly deferred.
- He asked for the catalogue of other wallpapers to be built before the fidelity pass. This rebuild came after that.
- No complaints about the rebuild so far ("everything looks good").

## Ideas / next steps
- Rare visitors: a crab crossing the sand, a jellyfish drifting up, a big fish passing far in the back.
- Caustics on fish and rocks, not just the sand and back wall.
- A time-of-day tint that follows the real Sun (as Flowing Gradient does).
- Settings to add: fish count, which species appear, bubbles on or off.
- The back rocks are plain silhouettes. Broadleaf-style plants could add variety.
- Schools never interact with each other.

## Checking it
```sh
SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_SECONDS=20 swift test          # schools form within seconds; 60 s to check motion stays natural
swift test -c release -Xswiftc -enable-testing                      # release CPU numbers (debug is pessimistic)
```
Caustics and shafts are driven by `u_time`, which ignores `SNAPSHOT_SECONDS`. To see them at another moment, temporarily add an offset to `u_time` in the two shaders.
