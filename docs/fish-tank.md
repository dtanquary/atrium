# Fish Tank

A bright reef tank seen through the glass, the way reefkeepers build them. Two islands of live rock and coral stand on white aragonite sand with open water between them, and a soft cluster sits further back. Real fish, cut out of photos, school at three depths:
- a big school of blue-green chromis
- yellow and blue tangs
- a clownfish pair at home in their anemone
- a royal gramma, firefish and a flame angelfish hovering low by the rock

Soft corals sway in the current, caustics ripple over the sand, and the mirror of the surface runs along the top. It's daylight in Light Mode and a reef tank's actinic evening blue in Dark Mode.

- **Files:**
  - `Sources/Atrium/FishTank.swift` holds the scene: the light, water and sand shaders, the reef layout, the grading shader, schooling, marine snow and the vignette.
  - `Sources/Atrium/FishTankArt.swift` holds:
    - the `Species` enum: each fish's photos, size, speed, tail beat, spacing and haunt
    - `TankArt.photo`, which loads a cut-out at its on-screen size with an optional depth-of-field blur
    - the warp builders `swimWarps` and `swayWarps`
  - `Sources/Atrium/Resources/reef-*.heic`: 42 photo cut-outs, HEIC with alpha, 2.5 MB in all.
  - `Sources/Atrium/Resources/reef-credits.tsv`: each cut-out's subject, author, licence and source. Settings → About lists them, as CC BY requires.
- **Entry:** `final class FishTank: SKScene`, registered as `{ FishTank(size: $0) }` in Scenes.swift (icon `fish.fill`, tint `.teal`).
- **Kind:** photo cut-outs on SpriteKit sprites, graded by one shared shader, over two full-screen shaders for the water and the sand.
- **Shared helpers:** `frameTime` and `softDot` come from Fireflies.swift, and `shaderCommon`, `paint` and `resource` from Shaders.swift and Scenes.swift.

## How it works
Layers, back to front, from the `Z` enum:
1. **Water** (`addWater`), a full-screen SKShader, lit like a reef tank. Its colours were sampled from real reef tank photos: the CAS Steinhart coral tank and a public-aquarium reef tank on Wikimedia Commons. `Lighting.day` is used in Light Mode (daylight white-blue LEDs) and `Lighting.actinic` in Dark Mode. The layers:
   - a saturated royal-blue back panel, brighter high up (`high` and `low`)
   - the lamp's pool of light, brightest mid-tank (`0.75 + 0.35·lamp`)
   - faint LED shimmer (caustics) and rays from the lamp array, fading downward
   - the underside of the surface along the top, a mirror: it reflects the lit water, so it's the same blue as `high` but about 1.2× brighter, crossed by thin, crisp ripple highlights (the caustic network squashed flat, `pts / (90, 9)`), with a soft line where it meets the water, a bright waterline, and the dark lid above. It starts at 94% of the height. A grey, blurry, noise-streaked band there read as muddy; Dave called it out.
   - dither
2. **Sand** (`addSand`), all in its shader: white aragonite, warm white up front (`sandNear`) and going blue with distance (`sandFar`), with fine grain from `hash42`. Two caustic layers multiply the sand they land on rather than adding white, the way real light brightens it. They're bigger at the front and squashed by perspective (`pts.y * 2.6`), and the back edge melts into the back panel.
3. **The reef** (`addReef`). Which cut-outs go where, their flips, and which island has the anemone all change with each load. It has four parts:
   - **back cluster:** about 55% scale, near the back edge of the sand, faded 35% toward the back panel and blurred 1.4 pt, like a camera's depth of field
   - **two islands** (`cluster`), at 14–24% and 76–86% across, leaving open sand between. Each one has:
     - a base rock: the live rock (`rock-1`) or the wide, low pile (`rock-4`); the back cluster uses the pile or the pale Porites boulder (`rock-6`)
     - a different piece stacked on it toward the middle (often the tall, porous `rock-3`), so no island repeats a piece. It settles into the rock below as far as it needs to (never below 30% of the base's height), so the island tops out at 0.36 × screen height above its base.
     - a branching Acropora crowning the stacked rock's highest point
     - a toadstool leather coral on one shoulder
     - the anemone, or else a torch, hammer or candy cane coral, on the other shoulder
     - zoanthids on its face
     - a brain coral or a Porites head at its foot
   - **sitting on the rock:** corals and the stacked rock are set on the rocks' real top edge. `TankArt.skyline` reads each rock's silhouette from its alpha: the highest solid pixel in each of 48 columns. `perch(x)` puts a coral on the highest rock surface at x, sunk 12 pt into it, or moves toward the island's middle until there is rock under it. Placing by fractions of the rock's bounding box let corals float over the irregular rocks; Dave spotted one.
   - **swaying:** the soft corals (toadstool, anemone, torch) sway with `swayWarps` at 0.03–0.05 strength and a 5–8 s period
   - **front corner:** one brain or zoanthid colony up against the glass in a front corner, sharp and big
4. **Fish** (`addSchools`): nine schools, 38 fish in all:

   | Species | Count | Depth | Haunt |
   |---|---|---|---|
   | chromis (far) | 14 | 0.62 | open |
   | yellow tang | 3 | 0.8 | open |
   | chromis | 12 | 0.9 | open |
   | blue tang | 2 | 0.95 | open |
   | clownfish | 2 | 0.95 | their anemone |
   | royal gramma | 1 | 0.92 | low by a rock |
   | firefish | 2 | 0.9 | low by a rock |
   | flame angelfish | 1 | 0.97 | low by a rock |
   | yellow tang (near) | 1 | 1.1 | open |

   Each fish is drawn from one of its species' photos, picked at random, so a school isn't a row of clones. Depth sets scale, speed and z-layer (far < 0.7, mid < 1, near). The far school gets a slight blur, `(0.9 - depth)·4` pt, and fades toward the back panel, `(0.9 - depth)·0.5`. Real tank water barely tints anything over half a metre, so both stay light.
5. **Marine snow:** slow, faint specks across the whole tank (`softDot`).
6. **Vignette:** a radial darkening sprite on top.

**Lighting the cut-outs** (`photoShader`, shared by every fish and coral). Each sprite passes `a_frame`: the scene position of its texture's (0, 0) corner, then its signed width and height. From that, the shader knows where each pixel sits in the tank. Corals set it once; fish update it every frame in `pose`. The shader then:
- tints the white-light photos to the tank's light with `grade`: a slight blue-white by day, actinic blue at night
- gives things lower in the tank a little less light (`0.82 + 0.28·height`)
- plays the lamp's ripples over upper surfaces. Two crossing, wandering sine waves (`pow(|sin·sin|, 3)`) stand in for caustics: the Voronoi caustics on every overlapping coral layer took the tank from 1.35 to about 2.2 ms, and the waves read the same on small, moving shapes.
- **fluorescence:** adds `colour × saturation × a_glow × fluoro`. Under actinic blue (`fluoro` 1.5), coral pigments glow in their own colours while grey rock just goes blue, as in real reef photos at night. Daylight gets a touch (0.15). `a_glow` is 1 for corals, 0.1 for rock and 0.08 for fish; at 0.25 the yellow tangs glowed.
- fades things further back toward the back panel by `a_fog`: `mix(…, haze·alpha, a_fog)`, since the textures are premultiplied

**Schooling (`swim`)** uses boids within each species, with O(n²) per school:
- separation inside `gap` (body length × `Species.spacing`: 1.3 for chromis, 1.9 for the rest)
- alignment and cohesion within `sight` = 6 body lengths
- a random-walk wander angle
- a pull toward `home` for species with a haunt: clownfish above the anemone, and the shy species low by a rock (`rockSpots`, one per island)
- soft walls just past the screen edges (so turns mostly happen off-screen), and a floor and ceiling from `bounds(depth)`

- **burst and coast** for species with a `burst` (chromis 1.3 s at 45% beating; firefish 2.4 s at 25%, hovering then darting): a few quick tail beats, then a glide. Each fish runs its own cycle, so a school doesn't pulse in unison. It gets thrust of 1.8 × cruise per second while beating and drag of 0.9 while gliding, within the usual speed clamp, and its tail runs at 15% speed during a glide.

Everything is pre-simulated for 150 steps in `sceneDidLoad`, so schools have already formed on the first frame.

**Pose (`pose`):**
- facing eases through zero at 2.5 per second, so the fish visibly turns instead of flipping
- tilt follows pitch, clamped to ±0.3
- the tail beat steps through 20 precomputed warp frames (`swimWarps`: an 8×1 grid with a wave from head to tail, `0.075·(1-u)²`). The beat rate scales with speed. The warps work on the photos unchanged.

## Time, live data and appearance
Motion comes from `update(_:)` (boids and frame stepping), the coral sway actions, and `u_time` (the water and sand shaders). There's no network or location use. Light Mode is a daylight reef tank and Dark Mode its actinic evening look, read from `systemIsDark` when the scene is built.

## Settings
None yet.

## Tuning constants
- **`Species` (FishTankArt.swift):**

  | Species | length (pt) | cruise (pt/s) | beat (s) | photos |
  |---|---|---|---|---|
  | chromis (burst 1.3 s, 45%) | 46 | 40–54 | 0.3 | 3 |
  | yellow tang | 88 | 30–40 | 0.55 | 4 |
  | blue tang | 100 | 36–48 | 0.6 | 3 |
  | clownfish | 54 | 20–28 | 0.4 | 3 |
  | royal gramma | 44 | 12–18 | 0.45 | 1 |
  | firefish (burst 2.4 s, 25%) | 50 | 10–16 | 0.35 | 3 |
  | flame angelfish | 58 | 18–26 | 0.45 | 3 |

- **Scene scaling:** `unit` is height/982, clamped to 0.8–1.8, so a bigger screen gets a bigger tank rather than smaller fish. `fishUnit` is `unit × 1.2`. `sandHeight` is 0.22 × height.
- **Reef sizes** at `unit` 1: rock 440–520 pt wide, Acropora 320, toadstool 220, anemone 240, torch and hammer 210, zoanthids 110, brain 170. The front-corner colony is 230.
- **`Lighting`** (FishTank.swift), for `day` and `actinic`:
  - back panel `high` and `low` (the surface mirror is `high` brightened), `shimmer`
  - sand `sandNear` and `sandFar`
  - photo `grade`: day (0.94, 0.98, 1.06), actinic (0.45, 0.52, 1.05)
  - `fluoro`: day 0.15, actinic 1.5
  - `haze`
- **Snow:** birth rate 5, lifetime 40 s.

## Performance
CPU 0.7 ms and GPU 1.45–1.5 ms per frame (release, 2x), in both looks. The GPU cost is mostly the two full-screen shaders (the water's caustics and noise, and the sand's two caustic layers), plus about 60 lit sprites, many overlapping in the reef. CPU is the boids, 38 fish at O(n²) per school. The cut-outs are decoded and resized once at launch.

## Gotchas and shortcuts
- **Assets:** the cut-outs come from public domain, CC0 and CC BY photos (iNaturalist, Wikimedia Commons, NOAA). They were cut out with Vision's foreground mask, cleaned to their largest connected piece, resized (fish 480 px, corals 760, rock 900 at most) and saved as HEIC with alpha (about 8× smaller than PNG).
  - `acropora-3`, a single staghorn branch lying diagonally, was dropped: its base sat at a corner of the image, not the bottom middle, so it floated wherever it landed.
  - `reef-rock-1`'s right edge had been cut straight by the photo frame. It was redrawn as a rounded edge that mirrors the rock's natural left profile, darkened toward the edge.
  - `rock-2` (a coralline nodule that read as a pink ball) was dropped.
  - `gramma-3` was left out: its Smithsonian "no known copyright restrictions" isn't formally public domain.
  - The originals and the tools (`cut.swift`, `process.py`) were in the research agent's scratch folder and aren't in the repo.
- **Warp speed bug:** changing a node's `speed` every frame while `SKAction.animate(withWarps:)` runs on it makes SpriteKit steadily slower (1 ms up to 10 ms a frame within a minute). That's why fish step through warp frames by hand in `pose`. The coral sway uses warp actions only because its speed never changes. This is also noted in CLAUDE.md.
- `ponytail:` O(n²) boids within a school, fine up to a few dozen fish per school. Use a spatial grid, like Murmuration, if schools grow.
- **Rock:** no permissively licensed photo of coralline-covered live rock exists besides `rock-1`, so `rock-3`, `rock-4` and `rock-6` are bare dry reef rock and a bleached Porites head. `coralline.py` (in the research scratch folder, not the repo) removed each photo's colour cast and painted muted pink, purple and green coralline patches onto them, in colours sampled from `rock-1`. The credits note the change, as CC BY asks. A first pass at full strength read as camouflage paint; the patches are now 70% toward the grey stone and cover about a third of it. `rock-3` and `rock-4` are toned to 0.78 and 0.88 of the live rock's mid-grey, since at full brightness they looked bleached beside it. There's still no tall pillar or arch.
- The shaders use `u_time`, which doesn't advance in the render test, so caustics look frozen in snapshots. Fish and corals do move.

## Dave's feedback and decisions
- The first version (flat `SKShapeNode` fish, stroked seaweed) was the proof of concept. Dave called it "the primitive fish tank" and asked how to raise the fidelity.
- He then chose a drawn-in-code route over image sprites or RealityKit 3D, which became a planted tank of fish, plants and props painted with Core Graphics.
- 2026-09-25: "everything looks way too cartoony." A research agent compared renders with real tank photos and found three causes:
  - the scene mixed reef fish with freshwater plants under ocean lighting
  - it was drawn like vector art
  - it used ocean depth cues where a real tank has none

  It prototyped fixes, and photo cut-out fish were by far the biggest jump in realism. Dave said not to treat his earlier "drawn in code" call as written in stone, and chose:
  - a realistic **reef** tank
  - **photo cut-out** fish and corals ("or whatever is best quality")
  - **bright and lush** lighting

  This rebuild is the result, with daylight in Light Mode and actinic blue in Dark Mode.
- On the rebuild: "looking much better", but a reef stick floated attached to nothing in the top left, and the top of the tank looked muddy. The stick was the staghorn fragment; the fix was setting corals on the rocks' real silhouettes. The top became a bright mirror of the water with crisp ripple lines.

## Ideas / next steps
- Rare visitors: a cleaner shrimp on the rock, a snail on the glass.
- Settings: fish count, which species appear, the lighting look.

## Checking it
```sh
SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_SECONDS=8 swift test                        # Light Mode
SNAPSHOT_APPEARANCE=dark SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_SECONDS=8 swift test # actinic
```
Each load rolls a different reef. Caustics are driven by `u_time`, which ignores `SNAPSHOT_SECONDS`.
