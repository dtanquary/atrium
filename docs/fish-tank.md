# Fish Tank

A bright reef tank seen through the glass, the way reefkeepers build them. Two islands of live rock and coral stand on white aragonite sand with open water between them, and a soft cluster sits further back. Real fish, cut out of photos, school at three depths:
- a big school of blue-green chromis
- yellow and blue tangs
- a clownfish pair at home in their anemone
- a royal gramma, firefish and a flame angelfish hovering low by the rock

Soft corals sway in the current, caustics ripple over the sand, and the mirror of the surface runs along the top. Fish cast soft shadows on the sand and on the fish below them, and each fish is lit from where it swims and how it turns. It's daylight in Light Mode and a reef tank's actinic evening blue in Dark Mode.

- **Files:**
  - `Sources/Atrium/FishTank.swift` holds the scene: the light, water and sand shaders, the reef layout, the grading shader, schooling, fish lighting and shadows, marine snow and the vignette.
  - `Sources/Atrium/FishTankArt.swift` holds:
    - the `Species` enum: each fish's photos, size, speed, tail beat, spacing and haunt
    - `TankArt.photo`, which loads a cut-out at its on-screen size with an optional depth-of-field blur
    - the warp builders `swimWarps` and `swayWarps`
  - `Sources/Atrium/Resources/reef-*.heic`: 42 photo cut-outs, HEIC with alpha, 2.5 MB in all, and sharper copies of two of them for big displays (`reef-rock-1-big.heic`, `reef-acropora-2-big.heic`, 650 KB).
  - `Sources/Atrium/Resources/reef-credits.tsv`: each cut-out's subject, author, licence and source. Settings → About lists them, as CC BY requires.
- **Entry:** `final class FishTank: SKScene`, registered as `{ FishTank(size: $0) }` in Scenes.swift (icon `fish.fill`, tint `.teal`).
- **Kind:** photo cut-outs on SpriteKit sprites, graded by one shared shader, over two full-screen shaders for the water and the sand.
- **Shared helpers:** `frameTime` and `softDot` come from Fireflies.swift, and `shaderCommon`, `paint` and `resource` from Shaders.swift and Scenes.swift.

## How it works
Layers, back to front, from the `Z` enum:
1. **Water** (`addWater`), a full-screen SKShader, lit like a reef tank. Its colours were sampled from real reef tank photos: the CAS Steinhart coral tank and a public-aquarium reef tank on Wikimedia Commons. `Lighting.day` is used in Light Mode (daylight white-blue LEDs) and `Lighting.actinic` in Dark Mode. The layers:
   - a saturated royal-blue back panel, brighter high up (`high` and `low`)
   - the lamp's pool of light, brightest mid-tank (`0.75 + 0.35·lamp`)
   - faint LED shimmer (the baked caustics, below) and rays from the lamp array, fading downward
   - the underside of the surface along the top, a mirror: it reflects the lit water, so it's the same blue as `high` but about 1.2× brighter, crossed by thin, crisp ripple highlights (the caustics squashed flat, `pts / (90, 9)`, at 0.5 since the baked ones are finer than the Voronoi lines it had), with a soft line where it meets the water, a bright waterline, and the dark lid above. It starts at 94% of the height. A grey, blurry, noise-streaked band there read as muddy; Dave called it out.
   - dither
2. **Sand** (`addSand`), all in its shader: white aragonite, warm white up front (`sandNear`) and going blue with distance (`sandFar`), with fine grain from `hash42`. Two layers of the baked caustics (below), the second finer and turned, multiply the sand they land on rather than adding white, the way real light brightens it: `0.88 + 1.6·light`, so the sand between the filaments is a little darker than it was. They're bigger at the front and squashed by perspective (`pts.y * 2.6`). The brightest channel then rolls off above 0.8 toward 0.96, with the others scaled alike so the hue holds: the cores stop short of white (at 240 of 255 where 1% of the front sand had sat at 250 or more), and the sand's median fell from about 185 to 172. Under actinic blue, whose sand is mostly blue, the lines are calmer than they were. Then the back edge melts into the back panel: the sand goes half way toward `low`, then over its last few points fades into the water's own colour there, along an edge that wanders by 4 pt of low noise. It had ended on a ruled line across the whole screen (review of 2026-11-14). The fade is worked out in the sand's shader, not by alpha: a sand sprite that wasn't opaque cost 0.1 ms of GPU, as the water under all of it was shaded too (Apple's GPUs skip what an opaque sprite hides).
   - **shadows** (`Z.shadows`, just above the sand): soft, dark-blue ellipses (`shadowOnSand`). One per fish, moved in `illuminate` (see *Fish lighting and shadows* below), and a still one under each thing standing on the sand (`ground`): each island's base rock and the coral at its foot, the back cluster's (faint, as the fish's fade toward the back), and the front-corner colony. Each is the piece's width × 1.1 by a fifth of it, at alpha 0.65, a thirtieth of its width below its base, so a little shows in front of it. Before 2026-11-15 only fish cast them, and the rocks and corals beside them ended on bare, bright sand in a clean cut.
3. **The reef** (`addReef`). Which cut-outs go where, their flips, and which island has the anemone all change with each load. It has four parts:
   - **back cluster:** about 55% scale, near the back edge of the sand, faded 35% toward the back panel and blurred 1.4 pt, like a camera's depth of field. A blurred cut-out is drawn with a clear margin of three sigma all round (`TankArt.margin`), included in its sprite's size and kept out of the layout (`drawn` in `cluster`): blurred inside its own box, its blur was cut off there, and the cluster's base and sides stayed razor-straight while its top went soft. The far chromis get the margin too.
   - **two islands** (`cluster`), at 14–24% and 76–86% across, leaving open sand between. Each one has:
     - a base rock: the live rock (`rock-1`) or the wide, low pile (`rock-4`); the back cluster uses the pile or the pale Porites boulder (`rock-6`)
     - a different piece stacked on it toward the middle (often the tall, porous `rock-3`), so no island repeats a piece. It settles into the rock below as far as it needs to (never below 30% of the base's height), so the island tops out at 0.36 × screen height above its base.
     - a branching Acropora crowning the stacked rock's highest point
     - a toadstool leather coral on one shoulder
     - the anemone, or else a torch, hammer or candy cane coral, on the other shoulder
     - zoanthids on its face
     - a brain coral or a Porites head at its foot
   - **sitting on the rock:** corals and the stacked rock are set on the rocks' real top edge. `TankArt.skyline` reads each rock's silhouette from its alpha: the highest solid pixel in each of 48 columns. `perch(x)` puts a coral on the highest rock surface at x, sunk 12 pt into it, or moves toward the island's middle until there is rock under it. Placing by fractions of the rock's bounding box let corals float over the irregular rocks; Dave spotted one.
   - **swaying:** the soft corals (toadstool, anemone, torch) sway with `swayWarps` at 0.03–0.05 strength and a 5–8 s period. That warp leans the whole picture from its foot on a 1 × 8 grid, so the tentacles never moved against each other, and the anemone, the clownfish's home and where the eye rests, read as a still photo (review of 2026-11-14). Since 2026-11-15 `photoShader` also reads each soft coral's picture a few points aside before lighting it: waves up the tentacles about 70 pt long that drift across about 210 pt, travelling at 0.9 a second, none at the foot (`smoothstep(0.1, 0.7, v)`). How far is `a_fish.y`, which corals otherwise leave at 0 (`a_fish.x` tells fish from coral): 70 × the sway strength, so 3.5 pt for the anemone, 2.8 for the torch, hammer and candy cane, 2.1 for the toadstool. The warp's lean stays under it. It runs behind a branch on that amount, so only soft corals pay its two sines. Judged on film (frames at 15 fps): it reads as tentacles stirring, not as heat haze; stronger risks the haze.
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

   Each fish is drawn from one of its species' photos, picked at random, so a school isn't a row of clones. Depth sets scale, speed and z-layer (far < 0.85, behind the islands; mid < 1, in front of them; near, in front of everything). By `sandLine` the islands stand at about depth 0.86–0.9, their bases at 0.55–0.6 of the sand's height. Until 2026-11-15 far was < 0.7, so the three yellow tangs at 0.8 swam in front of the islands while their shadows fell behind them, and only the far chromis ever passed behind the reef; now the tangs do too. The far school gets a slight blur, `(0.9 - depth)·4` pt, and fades toward the back panel, `(0.9 - depth)·0.5`. Real tank water barely tints anything over half a metre, so both stay light.
5. **Marine snow:** slow, faint specks across the whole tank (`softDot`).
6. **Vignette:** a radial darkening sprite on top.

**Caustics** (`TankArt.caustics`, read through `causticAt` in the shaders). Real caustics are filaments that fork, bunch into bright knots and fade out; the Voronoi pattern the tank had until 2026-11-15 drew light where two cells met, so the sand got closed polygons in lines of even width with white cores, a net that looked drawn rather than lit (review of 2026-11-14). Now they are baked once at load, by tracing light: `causticLight` sends four rays to a texel straight down through a surface of 24 summed sines (whole waves across the tile, 5–20 to a tile, steeper ones smaller), bends each by the surface's slope (`reach`, just past the first focus) and counts where they land, sharing each between the four texels round it. The light, relative to its mean, over 8, goes into a 512-texel tile that repeats, with a wrapped row and column so it's smoothed across its seam (`sharedTexture`, 1 MB, let go with the last tank). It takes 23 ms in a release build, about 1 s in a debug one. `causticAt(q, t)` reads it with q in cells, 8 to a tile, bent at two scales by four sines that move with time (the light writhes as the surface moves) and drifting slowly across. The review's way of moving it, two reads at different scales and drifts keeping the lesser, was tried: it left short dashes and soft blobs where two filaments crossed, not a network, and was dropped.

**Lighting the cut-outs** (`photoShader`, shared by every fish and coral). Each sprite passes `a_frame`: the scene position of its texture's (0, 0) corner, then its signed width and height. From that, the shader knows where each pixel sits in the tank. Corals set it once; fish update it every frame in `pose`. The shader then:
- tints the white-light photos to the tank's light with `grade`: a slight blue-white by day, actinic blue at night
- gives things lower in the tank a little less light (`0.82 + 0.28·height`)
- plays the lamp's caustics over upper surfaces: the same baked caustics as on the sand, at `pts / 100`, so one light crosses sand, rock and coral. The Voronoi caustics on every overlapping coral layer had taken the tank from 1.35 to about 2.2 ms, so until 2026-11-15 the cut-outs got two crossing sine waves instead (`pow(|sin·sin|, 3)`); a texture read costs about what the sines did.
- **fluorescence:** adds `colour × saturation × weight × a_glow × fluoro`. Under actinic blue (`fluoro` 1.5), coral pigments glow in their own colours while grey rock just goes blue, as in real reef photos at night. Daylight gets a touch (0.15). `a_glow` is 1 for corals, 0.1 for rock and 0.08 for fish; at 0.25 the yellow tangs glowed. `weight` is `mix(0.3, 1, smoothstep(0.3, 0.7, saturation))`, so vivid pigment glows fully and tan tissue, which doesn't fluoresce, mostly goes blue and dim like the rock. Without it (until 2026-11-15) a tan brain coral got half its own warm colour added and stayed warm in the corner while everything else went blue: red over blue 0.88 against 0.54 on the sand beside it; now 0.74. The review's full `smoothstep` (0.66) also took most of the glow off the pale Acroporas, the focal point under actinic, which went a flat deep blue; the 0.3 floor keeps them lit. The truer brain corals are dimmer under actinic.
- **one light, no clipping:** last, the brightest channel rolls off above 0.8 toward 0.97, and the others are scaled by the same factor so the hue holds (taken on the colour before premultiplying). The pale Acroporas are graded 1.05 in blue and then get the caustics and their glow on top: under actinic 45% of one's lit pixels had a channel at 250 or more, in daylight 21%; now none. Daylight looks the same otherwise.
- darkens the foot of every rock and coral (not fish: `a_fish.x` is 0), to 0.6 at the bottom of its picture and back to full over its lowest 15%: corals where `perch` sinks them into rock, rocks where they meet the sand
- fades things further back toward the back panel by `a_fog`: `mix(…, haze·alpha, a_fog)`, since the textures are premultiplied

**Fish lighting and shadows.** The lamp is overhead, so each fish gets, from `illuminate` (every frame, in `pose`) and `castShadows` (every frame, after `swim`):
- **light from where it swims** (`a_fish.y`): `(0.85 + 0.2·lamp) × (0.8 + 0.3·height)`, with `lamp` the same pool of light as the water's (brightest mid-tank) and `height` how far up it is between its floor and ceiling. This is on top of the shared `0.82 + 0.28·height` every cut-out gets.
- **top light across the body:** the back is brighter than the belly, `0.8 + 0.4·up` in texture space, so the cut-outs read as lit from above.
- **sand bounce** (`a_fish.w`): white sand close below lights the belly, `0.3·exp(-height above sand / 60 pt)`.
- **banking in a turn:** each turn picks at random whether the fish rolls its flank up toward the lamp or away from it (`bank`). Toward, the flank flashes (`a_fish.z`, up to 0.3 of the light's colour added, peaking half-way through the turn); away, it dims by up to 25%. This is the flash of a school catching the light.
- **its shadow on the sand:** where the sand meets the fish's plane (`sandLine`), an ellipse its length wide that grows (`1 + 1.5·height/screen`) and fades (`0.55 / spread²`) the higher it swims, and fades out toward the back of the sand. As the fish turns, it narrows and deepens, since from above a turning fish points into the tank. Each fish's depth is its school's ±0.05, only for shadows: with one shared plane, a school's shadows all fell on one line and read as a dark streak.
- **shadows from fish above** (`a_shadow`): of the fish above it within 0.06 depth and horizontally close, the strongest one darkens a vertical band of it, `0.35 × closeness in depth × exp(-drop / 3 lengths)`, with the band's edge softer the further above it is. It also stops the lamp's ripples in the band. One shadow per fish is plenty to read.

**Schooling (`swim`)** uses boids within each species, with O(n²) per school:
- separation inside `gap` (body length × `Species.spacing`: 1.3 for chromis, 1.9 for the rest)
- alignment and cohesion within `sight` = 6 body lengths
- a random-walk wander angle
- a pull toward `home` for species with a haunt: clownfish above the anemone, and the shy species low by a rock (`rockSpots`, one per island)
- soft walls just past the screen edges (so turns mostly happen off-screen), and a floor and ceiling from `bounds(depth)`

- **burst and coast** for species with a `burst` (chromis 1.3 s at 45% beating; firefish 2.4 s at 25%, hovering then darting): a few quick tail beats, then a glide. Each fish runs its own cycle, so a school doesn't pulse in unison. It gets thrust of 1.8 × cruise per second while beating and drag of 0.9 while gliding, within the usual speed clamp, and its tail runs at 15% speed during a glide.

Everything is pre-simulated for 150 steps in `sceneDidLoad`, so schools have already formed on the first frame.

**Pose (`pose`):**
- facing eases through zero (`turn`), so the fish visibly turns instead of flipping: 2.5 a second, rising to 6 as it passes edge-on (linearly from |facing| 0.5). At a steady 2.5 a turning fish was under a third of its width for a quarter of a second, a squeezed sliver; now about a seventh, at 15 to 120 fps alike (`fishTurnQuicklyThroughEdgeOn`). Turns are meant to happen off screen, but fish that wander or keep a home turn in view.
- tilt follows pitch, clamped to ±0.3
- the tail beat steps through 20 precomputed warp frames (`swimWarps`: an 8×1 grid with a wave from head to tail, `0.075·(1-u)²`). The beat rate scales with speed. The warps work on the photos unchanged.

## Time, live data and appearance
Motion comes from `update(_:)` (boids and frame stepping), the coral sway actions, and `u_now` (the water, sand and photo shaders). There's no network or location use. Light Mode is a daylight reef tank and Dark Mode its actinic evening look, read from `systemIsDark` when the scene is built, unless Settings → Lighting holds one.

## Settings
- **Lighting** (`tank.look`, a menu): Match macOS (daylight in Light Mode, actinic blue in Dark Mode), Daylight, or Actinic blue.
- **Lights out at night** (`tank.lightsOut`, with **Lights off at** `tank.lightsOff`, 22:00, and **Lights on at** `tank.lightsOn`, 8:00): between those hours the tank is under actinic blue whatever the Lighting menu says, like a real tank's lamp timer; the span may cross midnight, and the same hour twice means never (`lightsOut(at:off:on:)`). The scene checks the clock every 30 s and, as an hour comes round, dissolves into the other look over 4 s.
- **Fish** (`tank.fish`, 0.25× to 1×): thins every school alike, from a calm few to the full 38.
- **Marine snow** (`tank.snow`): the drifting specks, which some people read as dust on the screen.

Every setting is read when the scene is built (`dark`, `settings`); a change dissolves into a new scene built to it, in the preview and on the desktop, both still running (`settingsChanged` → `handOver`, the Pixel City pattern), once it has settled for 0.3 s by the clock: a dragged slider used to build a tank at every step, half a second each on the main thread (found in the 1.0 review, 2026-10-08). The scene fading out is `retired` and hands over no more.

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
CPU 0.8–0.9 ms and GPU 1.3–1.5 ms per frame (release, 2x), in both looks, until the caustics were baked (2026-11-15): GPU median 1.27 → 0.98 ms in daylight and 1.31 → 0.92 under actinic blue (debug, seed 4, six to eight 3 s renders each, back to back on a loaded machine; the GPU reads the same in debug). The Voronoi pattern was about 40 sines and 9 square roots a pixel, once across the whole back wall and twice on the sand; each is now four sines and a texture read. The GPU cost is mostly the two full-screen shaders (the water's noise and the sand's two caustic reads), plus about 60 lit sprites, many overlapping in the reef, and 38 small shadow sprites. CPU is the boids, 38 fish at O(n²) per school, and the fish-on-fish shadows, O(n²) over all 38. Shadows and fish lighting added about 0.1 ms to each. Each fish's three attributes (`a_frame`, `a_fish`, `a_shadow`) are changed in place on the node's own `SKAttributeValue`, and only when they differ (`attribute(_:of:to:)`): until 2026-10-14 every fish got three new ones every frame, and the render's CPU drops from about 0.24 to 0.21 ms a frame, pixel for pixel the same. Each tank draws its cut-outs at their size, about 10 ms each (the HEIC decodes lazily, inside that draw), 0.47 s for a whole tank. `TankArt` keeps them drawn in a weak table, at widths rounded to a sixteenth of an octave (SpriteKit scales the last 2%), so a tank rebuilt for a new setting reuses most of the one it replaces': 0.1–0.25 s. They go with the last tank. The rocks' silhouettes are kept for good (a few hundred bytes each).
- **Battery** (review of 2026-11-14, tried 2026-11-15, both dropped). No `batteryRate`, rightly: chromis reach about 65 pt a second, over 4 px a frame at 30 fps.
  - *Starting the water above the sand*, so its shader wouldn't run under the opaque sand (22% of its pixels): it saved nothing measurable (GPU median 1.22 and 1.25 ms without it, 1.13 and 1.21 with, ten 3 s renders each, interleaved), and changed every water pixel by up to 1 of 255 (the dither). Apple's GPUs already skip what an opaque sprite hides; the sand going translucent at its edge showed the same thing from the other side, costing 0.1 ms (see Sand).
  - *A trim* (`batteryScale` 0.75, the water and sand in a `TrimNode` at the water's z, since a child's z adds to its node's): at 100% the sand's grain, one speck a pixel, and the caustics' filaments went visibly softer, which the rule for trims doesn't allow, and the GPU's work fell to 98% in one bench and 83% in another (`trimShots`, `TRIM_BENCH=8`, loaded machine), for 25 MB. Once the caustics were baked the two shaders were cheap enough that a trim wasn't worth it.
- **Grounding** (2026-11-15: the still shadows under the reef, the darkened feet, the blur margin and the sand's soft back edge) cost nothing measurable: GPU median 1.35 ms before and 1.26 after, CPU 0.95 both (debug, seed 4, eight 3 s renders each, back to back on a loaded machine).

## Gotchas and shortcuts
- **Assets:** the cut-outs come from public domain, CC0 and CC BY photos (iNaturalist, Wikimedia Commons, NOAA). They were cut out with Vision's foreground mask, cleaned to their largest connected piece, resized (fish 480 px, corals 760, rock 900 at most) and saved as HEIC with alpha (about 8× smaller than PNG).
  - **Sharper copies for big displays** (2026-11-15). `unit` grows with the display, to 1.47 on a 27-inch 5K at its standard scaling and 1.72 on a 6K, so a base rock is drawn 1,300–1,800 px across from a 900 px picture (review of 2026-11-14). Of the originals only two have the detail to give: the live rock's (`rock-1`, about 2,200 px of rock) and the tenuis Acropora's (`acropora-2`, about 3,200). `rock-3`'s and `rock-4`'s photos hold about 960 and 1,000 px of rock, about what the cut-outs already have; `rock-6` is only ever drawn blurred at 55% scale in the back cluster, at most about 1,030 px; the kenti Acropora's original has 1.28 times its cut-out's detail, a gain hard to see at 5K; and the anemones are drawn at about their size even at 5K. So `reef-rock-1-big.heic` (1,800 px) and `reef-acropora-2-big.heic` (1,200 px) were made by transferring detail rather than cutting again: each cut-out drawn bigger, its colour, alpha, coralline and the redrawn edge kept, multiplied by the original's fine luminance detail (the original registered to the cut-out by cross-correlating high-passed luminance over a range of scales, 0.85 and 0.93; the detail is the original over itself taken down to the cut-out's size and back up). Scaled back down, each matches its cut-out to 1.3–1.4 of 255 on average. At 5K and 100% the rock's pores and the Acropora's polyps are crisper where they were smeared. `TankArt.file` takes a copy only where a cut-out is drawn over 1.2 times the width of the ordinary one, because the copies take about four times as long to decode: put in place of the ordinary ones, every tank built on a laptop took about 0.13 s longer (0.68 → 0.81 s, release), for nothing it could show. With the threshold, laptops draw exactly what they did (renders identical to the byte) in the same time.
  - `acropora-3`, a single staghorn branch lying diagonally, was dropped: its base sat at a corner of the image, not the bottom middle, so it floated wherever it landed.
  - `reef-rock-1`'s right edge had been cut straight by the photo frame. It was redrawn as a rounded edge that mirrors the rock's natural left profile, darkened toward the edge.
  - `reef-rock-4`'s left side was cut straight by its photo's frame too, for 39% of its height, and showed as a vertical edge and a square corner on the sand whichever way it was flipped. On 2026-11-15 its lower left was redrawn as a curve (bulging out mid-way, tucked under at the foot, with a few pixels of wander) and darkened to half toward the new edge, as rock-1's was. Same size, 900 × 488, 60 KB.
  - `rock-2` (a coralline nodule that read as a pink ball) was dropped.
  - `gramma-3` was left out: its Smithsonian "no known copyright restrictions" isn't formally public domain.
  - The originals and the tools (`cut.swift`, `process.py`) were in the research agent's scratch folder and aren't in the repo.
- **Warp speed bug:** changing a node's `speed` every frame while `SKAction.animate(withWarps:)` runs on it makes SpriteKit steadily slower (1 ms up to 10 ms a frame within a minute). That's why fish step through warp frames by hand in `pose`. The coral sway uses warp actions only because its speed never changes. This is also noted in CLAUDE.md.
- `ponytail:` O(n²) boids within a school, fine up to a few dozen fish per school. Use a spatial grid, like Murmuration, if schools grow. `castShadows` is O(n²) over every fish, likewise.
- **Shadows only fall on sand and fish.** A fish over the rock casts its shadow on the sand behind it, hidden by the rock, not on the rock or corals. Rocks and corals cast only the still shadow at their foot. Shading a coral's top where a fish passes over would need its surface, which only `TankArt.skyline` knows.
- **Rock:** no permissively licensed photo of coralline-covered live rock exists besides `rock-1`, so `rock-3`, `rock-4` and `rock-6` are bare dry reef rock and a bleached Porites head. `coralline.py` (in the research scratch folder, not the repo) removed each photo's colour cast and painted muted pink, purple and green coralline patches onto them, in colours sampled from `rock-1`. The credits note the change, as CC BY asks. A first pass at full strength read as camouflage paint; the patches are now 70% toward the grey stone and cover about a third of it. `rock-3` and `rock-4` are toned to 0.78 and 0.88 of the live rock's mid-grey, since at full brightness they looked bleached beside it. There's still no tall pillar or arch.
- The shaders run on `u_now`, which moves with `SNAPSHOT_SECONDS`, so caustics move in snapshots, as fish and corals do.

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
- 2026-09-26: "shouldn't the fish be casting shadows on to the ground and on to each other? can we also adjust the lighting on each fish based on their movement and position from the top?" Added shadows on the sand and from fish above, light from where each fish swims, top light across the body, sand bounce, and a flash or dimming as a fish banks in a turn.

- 2026-10-07: a failed attempt at two more tanks, cut the same day. Research agents and mock-ups led to an Ocean Voyager tank modelled on the Georgia Aquarium (whale sharks, mantas, a cownose ray squadron, trevally) and a Shallow Reef, an open-sea snorkeller's view with blacktips and a resting nurse shark, with a Tank menu and a move-automatically toggle (commits bcd3ea4, 5a2dcba, c3289f2: the sources, species tables and motion research are in their docs and messages). The giants never moved convincingly as photo cut-outs: head-on views slid sideways, two whale sharks drew through each other, cut-outs that faced left swam tail first, and even after a heading-and-speed steering model, stride-based tail beats and shark and ray warps from game and biology research, Dave's verdict was "the large whales just look so fake" and then "its just no good, I dont want users to see this". He kept only the reef tank and asked for the toggle to go with the others. Lesson: a big animal is its body's motion, and a flat photo warped into a tail beat can't carry it; the small reef fish get away with it because they're small and many.
- 2026-10-07: "the only setting I can think of adding to fish tank is a select box to force a light/dark mode or pick auto". Added as the Lighting menu. Then, offered alongside it and taken up ("lets go ahead and add the other ideas too"): a Fish slider "from a calm few to the full school", a Marine snow switch, since "some people read [it] as dust on the screen", and Lights out at night, "dim the tank after a set hour, the way a real tank's timer does, instead of following Dark Mode".

## Ideas / next steps
- Not another tank of large animals as photo cut-outs (see 2026-10-07 above). A Kelp Forest was next in line and was dropped with the rest.
- Rare visitors: a cleaner shrimp on the rock, a snail on the glass.
- A glint on each tail beat, for shiny fish like chromis. Left out for now: 38 fish flickering at 3 beats a second may read as busy.
- Settings: which species appear.
- Lights out could go dimmer than the actinic look, to a moonlit tank, if the actinic blue reads as too bright for the small hours.

## Checking it
```sh
SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_SECONDS=8 swift test --filter everySceneRenders                        # Light Mode
SNAPSHOT_APPEARANCE=dark SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_SECONDS=8 swift test --filter everySceneRenders # actinic
SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_DEFAULTS="tank.seed=4,tank.snow=0,tank.look=1" swift test --filter everySceneRenders # the same tank every time
```
Each load rolls a different reef. `tank.seed` (test-only, nothing else sets it) rolls the same reef and the same fish every time, so two renders differ only by the code; marine snow is SpriteKit's own emitter, which no seed reaches, so turn it off to compare. Seed 4 has both islands on the wide pile (`rock-4`) and the anemone on the left; seed 1 has a brain coral in the front corner. Caustics are driven by `u_now`, which follows `SNAPSHOT_SECONDS`.
