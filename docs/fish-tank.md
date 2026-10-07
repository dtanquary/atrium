# Fish Tank

Three tanks in one wallpaper, picked in Settings → Tank, with a shuffle that moves between them on its own: the **Reef Tank** (the original, described first), **Ocean Voyager** (the Georgia Aquarium's big window: whale sharks, mantas, a squadron of cownose rays) and the **Shallow Reef** (a snorkeller's view of a sunlit reef flat, with blacktip reef sharks). The other two are under *The other tanks* below; they share the reef tank's engine (the boids, the lit cut-outs, the shadows) with their own water, seabed, furniture and cast.

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
  - `Sources/Atrium/Resources/reef-*.heic`: 42 photo cut-outs, HEIC with alpha, 2.5 MB in all.
  - `Sources/Atrium/Resources/ocean-*.heic` (19, 1.1 MB) and `lagoon-*.heic` (25, 1.3 MB): the other tanks' cut-outs.
  - `Sources/Atrium/Resources/reef-credits.tsv`, `ocean-credits.tsv`, `lagoon-credits.tsv`: each cut-out's subject, author, licence and source. Settings → About lists them, as CC BY requires.
- **Entry:** `final class FishTank: SKScene`, registered as `{ FishTank(size: $0) }` with `knobs: FishTank.knobs` in Scenes.swift (icon `fish.fill`, tint `.teal`). `init(size:)` reads the tank from `tank.kind` (`FishTank.Tank`: `.reef`, `.ocean`, `.lagoon`) and `sceneDidLoad` builds that one.
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
   - **fish shadows** (`Z.shadows`, just above the sand): one soft, dark-blue ellipse per fish, moved in `illuminate`. See *Fish lighting and shadows* below.
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

**Fish lighting and shadows.** The lamp is overhead, so each fish gets, from `illuminate` (every frame, in `pose`) and `castShadows` (every frame, after `swim`):
- **light from where it swims** (`a_fish.y`): `(0.85 + 0.2·lamp) × (0.8 + 0.3·height)`, with `lamp` the same pool of light as the water's (brightest mid-tank) and `height` how far up it is between its floor and ceiling. This is on top of the shared `0.82 + 0.28·height` every cut-out gets.
- **top light across the body:** the back is brighter than the belly, `0.8 + 0.4·up` in texture space, so the cut-outs read as lit from above.
- **sand bounce** (`a_fish.w`): white sand close below lights the belly, `0.3·exp(-height above sand / 60 pt)`.
- **banking in a turn:** each turn picks at random whether the fish rolls its flank up toward the lamp or away from it (`bank`). Toward, the flank flashes (`a_fish.z`, up to 0.3 of the light's colour added, peaking half-way through the turn); away, it dims by up to 25%. This is the flash of a school catching the light.
- **its shadow on the sand:** where the sand meets the fish's plane (`sandLine`), an ellipse its length wide that grows (`1 + 1.5·height/screen`) and fades (`0.55 / spread²`) the higher it swims, and fades out toward the back of the sand. As the fish turns, it narrows and deepens, since from above a turning fish points into the tank. Each fish's depth is its school's ±0.05, only for shadows: with one shared plane, a school's shadows all fell on one line and read as a dark streak.
- **shadows from fish above** (`a_shadow`): of the fish above it within 0.06 depth and horizontally close, the strongest one darkens a vertical band of it, `0.35 × closeness in depth × exp(-drop / 3 lengths)`, with the band's edge softer the further above it is. It also stops the lamp's ripples in the band. One shadow per fish is plenty to read.

**Schooling (`swim`)** uses boids within each species, with O(n²) per school. Since 2026-10-07 the boids' free velocity is only the fish's **intent** (`Swimmer.intent`): where the steering has been pushing it. The fish itself always swims forward the way it faces, at the intent's pace (clamped to 0.45–1.35 × cruise), pitching toward the intent within its species' lean (`0.35·√agility` rad), and it turns round only when the intent points the other way strongly (`intent.x·facing < −0.3|intent|`), by easing its width through zero (`facing` from ±1 to ∓1 at `2.5·max(agility, 0.4)` per second), slowing and reversing as it does, the way a fish turns toward or away from the glass. The giants (`margin > 0`) only begin a turn once they're past the screen edge, so they're never seen turning. Moving along the free velocity itself let flocking push sharks along backwards (Dave: "i see sharks swimming backwards"); `fishSwimForward` steps the ocean for a minute and checks no fish not mid-turn ever moves against its facing. This is the heading-plus-speed model games use (Reynolds' steering with orientation locked to motion; Spine's squash-through-zero turn), per the motion research in Sources.
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

## The other tanks
Both reuse the reef tank's layers (`Z`), the photo shader, `addSchools`, `swim`, `pose`, `illuminate` and `castShadows`. What changes per tank is on `Tank` (`floor`, how much of the screen the seabed takes; `ceiling`, where the water ends), in `Lighting` (`ocean`/`oceanNight`, `lagoon`/`lagoonDusk`, with `mirror` for the lagoon's surface and `ripple` for how strongly the sun's ripples play over the cut-outs), and in the per-tank `plan` of schools in `addSchools`. The lamp's pool of light in `illuminate` is the reef tank's only; the others are lit evenly.

### Ocean Voyager
The Georgia Aquarium's 6.3-million-gallon Ocean Voyager exhibit seen through its 19 m × 7 m acrylic window. The desktop is the window: the screen shows about 11 m of it, so a 7 m whale shark near the glass spans most of the screen.
- **Water** (`addOceanWater`): azure, `high` #2f8fc9 at the top to `low` #0a63a6 at the bottom, going navy in the far corners (`pow(|x − 0.5|·2, 2.5)`), with shafts of light fanning down from top centre (two octaves of `noise1`, the x squeezed by `1 + 0.6·(1 − y)` so they spread with depth, gone by mid-depth), a faint shimmer high up, and the gallery's dark rim along the top. The water is very clear, so distance darkens and saturates toward the water colour rather than milking: cut-outs fog by `(0.9 − depth)·1.4` toward `haze`.
- **Seabed** (`addSeabed(cell: 220, net: 0.3, ripples: 0, melt: 0.25)`): a greyed slate-blue floor (#3e6a83 near, #28597c far, sampled from the 2022 window photos), with faint, large caustics, melting into the water from a quarter of the way back.
- **Rockwork** (`addOceanRocks`): the reef tank's two big rocks as ledges at the foot of the window's sides, fogged 0.7 and blurred 2 pt so they go blue and soft, each with a shadow under it (`ground`).
- **Cast** (`plan`, 107 animals): six schools of 14 golden trevally spread through the water as texture (depths 0.52–0.92), a squadron of 16 cownose rays at one height (depth 0.75, `spacing` 1.8, `height` 0.1–0.5), a whale shark near the glass (0.95, `height` 0.35–0.8) and a small hazy one far back (0.5), two mantas low in the water (0.7 and 1.0), a sandbar shark (0.72, low), and a zebra shark and a bowmouth guitarfish resting on the floor (`haunt: .sand`, `rests`). Not in: groupers, hammerheads, sawfish, turtles, batfish (their cut-outs exist in the research folder if wanted).
- **Dark Mode** (`Lighting.oceanNight`): the aquarium after hours, dimmed to deep blue.

### Shallow Reef
A sunlit reef flat in the open sea, 1–2 m deep, from a snorkeller's eye.
- **Water** (`addLagoonWater`): turquoise hazing toward the horizon (`low` #15759a to `high` #33a3c7), faint shafts of sun (real shallows show the caustic net rather than beams, so these are at 0.08), and above `ceiling` (0.76 of the height) **the surface seen from below**: outside Snell's window it mirrors the bottom, so it's a darker sand-turquoise (`mirror` #337f91) crossed by long wavy streaks of light and dark (two octaves of `noise`, squashed toward the horizon by `mix(10, 2, v)`) with sun glints on the ripples (`caustic`), paler toward the top, and a bright line where it meets the water. In the reference photos the surface takes the top quarter of a horizontal view.
- **Seabed** (`addSeabed(cell: 90, net: 1.0, ripples: 0.07, melt: 0.5)`): white sand (#ccc9bd near) going turquoise-grey (#3b93a6) by a few metres and melting into the water, under a crisp caustic net (cells about 0.1–0.2 of a shark, bright nodes clipping white as they do in photos, dark cells 0.9×) that softens with distance, over shore-parallel ripples in the sand.
- **Furniture** (`addBommies`): four coral heads from the lagoon cut-outs (Porites mounds, Pocillopora clumps, an Acropora table) on the sand at depths 0.58–0.9, smaller, softer and bluer the further back, each with a shadow under it (`ground`). The near ones are `rockSpots` for the fish that hover over a bommie.
- **Cast** (`plan`, 58 animals): four blacktip reef sharks at depths 0.6–1.0 patrolling low (`height` 0.05–0.7, `margin` 0.8 so they turn off-screen), a baitfish ball of 40 herring and silversides in the upper water, eight sergeant majors and two butterflyfish over the bommies, a parrotfish, and on the sand a nurse shark, an epaulette shark and a blue-spotted ribbontail ray (`haunt: .sand`, `rests`: still between short moves).
- **Dark Mode** (`Lighting.lagoonDusk`): dusk, dimmer and bluer.

### What the new animals needed in the engine
- `Species` is now a table (`Species.all` entries as static lets) rather than an enum of switches, so a species is one line.
- **`gait`** (`TankArt.swimWarps`, 24 frames on a 12 × 1 grid for the big species): `.tail` is the small fish's wave from head to tail. `.sweep` is a shark seen from the side, the motion research's recipe: a wave travelling tailward (`θ = phase − 5·s`, under one wavelength on the body) with an envelope `smoothstep(0.4, 1, s)²` that bends from mid-body and is steepest over the rear third, a wag of `0.03·L·env·sin θ` plus a nose counter-yaw of `0.008·L`, the blade foreshortening twice a beat as it swings out of the plane of view (`0.06·L·env·sin²θ`), the caudal blade (`s > 0.78`) swinging as one piece about the peduncle by ±6°, and in `pose` the whole body pivoting ±0.7° with the beat (ABZÛ's trick); the eel-like up-and-down wave looked wrong on a whale shark, Dave's first complaint. `.wings`: a ray's stroke runs from the wing base to the tip with the tip lagging 1.3 rad and curling, quick up and slow down (`θ' = θ + 0.3·sin θ`), `0.2·L·w²·sin θ'` on top of wings held `0.06·L·w²` above level, the body between them still (tip excursion about ±0.35 of the disc, Fish et al. 2016). The ribbontail ray and the nurse and zebra sharks use the tail wave: a wave running back along the body reads right for them.
- **`agility`** (1 for a small fish; whale shark 0.12, manta 0.25, sharks 0.4, cownose 0.5): scales how fast the wander angle changes, the wander and social steering, the rate of turning round, and how far and fast it pitches. The giants cruise level and straight, with heading changes over tens of seconds.
- **`trim`** (whale shark and sandbar +0.08 rad, blacktip +0.06): the pitch held at cruise; slow sharks swim a few degrees nose-up (Wilga & Lauder 2004).
- **`stride`** (sharks 0.45 L, whale shark 0.4, manta 0.55, cownose 0.5): the beat follows the distance swum, one beat per stride, instead of the clock. Beating by the clock had a whale shark sweep its tail every 4 s while advancing a fifth of a body length ("treadmilling", the research's first diagnosis; Webb & Keyes measured 0.5–0.74 L a beat). The whale shark's cruise rose to 50–60 pt/s and the manta's to 40–50 so beats land every 6–8 s.
- **`thrust`** (whale shark 0.1, manta 0.15): how much burst-and-coast changes the speed. The whale shark's tail rests between sweeps and the manta flaps then glides, but neither visibly speeds up and slows down any more.
- **Views:** every cut-out in motion is a side or three-quarter-from-the-side view, and every one faces right in its file (the agents' sets weren't consistent; five were mirrored on import, as their credits say: a cut-out facing left swims tail first however right the engine is). A head-on manta sliding sideways, and a banking belly view, were Dave's second complaint; the side views came from the research folder's finals and extras (`extra/manta-7, -8`, `final/manta-3`, `whaleshark-1, 3, 4`).
- **One near whale shark** (depth 0.95, `height` 0.35–0.8) and a far, hazy one (0.5); the mantas keep low (`height` 0.15–0.6) so the giants don't swim through each other.
- **`rests`** with **`haunt: .sand`**: the fish lies on the sand line (`sandLine(depth) + 0.1·L`) and its `burst` cycle becomes move-and-rest: during the resting share its speed decays to zero and its tail nearly stops; during the moving share it slides along the sand at cruise. Nurse sharks move 10% of a 60 s cycle, epaulettes 30% of 25 s, the ray 20% of 35 s, the zebra shark 20% of 40 s.
- **`margin`**, in body lengths: the soft walls move that far past the screen edges, so whale sharks (0.7), mantas (1), sharks (0.6–0.8) and the squadron (0.5) swim right off the screen before turning, never flipping in view.
- **`height`**: the part of the water column a species keeps to, 0 at the sand and 1 at the top, which `bounds(_:height:)` maps to a floor and ceiling. Whale sharks cruise high (0.45–0.95), the squadron low (0.1–0.5), blacktips low (0.05–0.7).
- Small fish (under 30 pt) are lit once rather than every frame, and neither cast nor catch fish-on-fish shadows: with 84 trevally it didn't show and cost a third of the frame.

## Time, live data and appearance
Motion comes from `update(_:)` (boids and frame stepping), the coral sway actions, and `u_now` (the water, sand and photo shaders). There's no network or location use. Light Mode is a daylight reef tank and Dark Mode its actinic evening look, read from `systemIsDark` when the scene is built; Ocean Voyager dims to its after-hours blue and the Shallow Reef goes to dusk.

## Settings
Section **Tank** (`FishTank.knobs`):
- **Tank**: Reef Tank, Ocean Voyager or Shallow Reef (`tank.kind`, stored as the index, 0 is the reef). A new pick dissolves into a new scene of that tank with both still running (`settingsChanged`: `SKTransition.crossFade`, 0.8 s by hand, 4 s when the shuffle moves it), the way Pixel City moves between cities.
- **Move to another tank automatically** (`tank.shuffle`, off) and **Move every** (`tank.shuffleMinutes`, 1–60, 10): `moveIfDue` checks every 5 s on the wall clock (`tank.moved`) and picks another tank at random, saving it as Settings would so every display's copy follows and the menu shows where we are. Picking a tank by hand, or changing the shuffle, starts the wait over. A scene built after the wait has passed (the app was quit, or the tank was off the desktop) comes back as another tank.

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

- **The other tanks' species** (points at depth 1; `burst` is move-and-rest for the species that rest):

  | Species | length | cruise | beat (s) | notes |
  |---|---|---|---|---|
  | whale shark | 760 | 50–60 | by stride 0.4 L | sweep; tail rests 7 s in 20; thrust 0.1; agility 0.12; trim +0.08; margin 0.8; height 0.35–0.8; 3 photos |
  | manta ray | 420 | 40–50 | by stride 0.55 L | wings; one flap then a glide (7 s, 50%); thrust 0.15; agility 0.25; margin 1; height 0.15–0.6; 3 photos |
  | cownose ray | 120 | 30–40 | by stride 0.5 L | wings; spacing 1.8; agility 0.5; height 0.1–0.5; 3 photos |
  | golden trevally | 40 | 25–35 | 0.4 | burst 1.5 s, 40%; spacing 2; 4 photos |
  | sandbar shark | 300 | 30–40 | by stride 0.45 L | sweep; agility 0.4; trim +0.08; margin 0.6; height 0.15–0.6; 1 photo |
  | zebra shark | 320 | 14–20 | 2 | rests, moves 20% of 40 s; 2 photos |
  | bowmouth guitarfish | 300 | 12–18 | by stride 0.45 L | sweep; rests, moves 15% of 50 s; agility 0.4; 1 photo |
  | blacktip reef shark | 300 | 28–36 | by stride 0.45 L | sweep; agility 0.4; trim +0.06; margin 0.8; height 0.05–0.7; 3 photos |
  | nurse shark | 380 | 8–12 | 2 | rests, moves 10% of 60 s; agility 0.3; 2 photos |
  | epaulette shark | 160 | 10–16 | 1 | rests, moves 30% of 25 s; 2 photos |
  | blue-spotted ray | 140 | 10–15 | 0.6 | rests, moves 20% of 35 s; tail wave; 2 photos |
  | baitfish (herring, silverside) | 36 | 35–45 | 0.3 | burst 1.3 s, 45%; spacing 1.2; height 0.4–1; 3 photos |
  | sergeant major | 60 | 20–28 | 0.45 | haunt rock (a bommie); 2 photos |
  | parrotfish | 150 | 16–22 | 0.6 | 2 photos |
  | butterflyfish | 60 | 18–24 | 0.4 | haunt rock; 2 photos |

- **Scene scaling:** `unit` is height/982, clamped to 0.8–1.8, so a bigger screen gets a bigger tank rather than smaller fish. `fishUnit` is `unit × 1.2`. `sandHeight` is 0.22 × height.
- **Reef sizes** at `unit` 1: rock 440–520 pt wide, Acropora 320, toadstool 220, anemone 240, torch and hammer 210, zoanthids 110, brain 170. The front-corner colony is 230.
- **`Tank`:** `floor` (the seabed's share of the height) 0.22 / 0.16 / 0.4 and `ceiling` 0.9 / 0.98 / 0.76 for the reef, ocean and lagoon.
- **`Lighting`** (FishTank.swift), for `day` and `actinic` (and `ocean`, `oceanNight`, `lagoon`, `lagoonDusk` likewise):
  - back panel `high` and `low` (the surface mirror is `high` brightened), `shimmer`
  - sand `sandNear` and `sandFar`
  - photo `grade`: day (0.94, 0.98, 1.06), actinic (0.45, 0.52, 1.05)
  - `fluoro`: day 0.15, actinic 1.5
  - `haze`
- **Snow:** birth rate 5, lifetime 40 s.

## Performance
Reef Tank: CPU 0.8–0.9 ms and GPU 1.3–1.5 ms per frame (release, 2x), in both looks. Ocean Voyager: CPU 0.99 ms, GPU 1.14 ms. Shallow Reef: CPU 0.84 ms, GPU 1.05 ms (release, 2x, Light Mode, 2026-10-07). The GPU cost is mostly the two full-screen shaders (the water's caustics and noise, and the sand's two caustic layers), plus about 60 lit sprites, many overlapping in the reef, and 38 small shadow sprites. CPU is the boids, 38 fish at O(n²) per school, and the fish-on-fish shadows, O(n²) over all 38. Shadows and fish lighting added about 0.1 ms to each. The cut-outs are decoded and resized once at launch.

## Gotchas and shortcuts
- **Assets:** the cut-outs come from public domain, CC0 and CC BY photos (iNaturalist, Wikimedia Commons, NOAA). They were cut out with Vision's foreground mask, cleaned to their largest connected piece, resized (fish 480 px, corals 760, rock 900 at most) and saved as HEIC with alpha (about 8× smaller than PNG).
  - `acropora-3`, a single staghorn branch lying diagonally, was dropped: its base sat at a corner of the image, not the bottom middle, so it floated wherever it landed.
  - `reef-rock-1`'s right edge had been cut straight by the photo frame. It was redrawn as a rounded edge that mirrors the rock's natural left profile, darkened toward the edge.
  - `rock-2` (a coralline nodule that read as a pink ball) was dropped.
  - `gramma-3` was left out: its Smithsonian "no known copyright restrictions" isn't formally public domain.
  - The originals and the tools (`cut.swift`, `process.py`) were in the research agent's scratch folder and aren't in the repo.
- **Re-entrant settings:** `settingsChanged` records the picked settings before it writes anything to UserDefaults, because the write's own `didChangeNotification` comes straight back into it. The other order recursed until the stack overflowed the first time Dave picked Ocean Voyager (2026-10-07). `fishTankTanksLoad` changes the tank on a live scene to keep it so.
- **Warp speed bug:** changing a node's `speed` every frame while `SKAction.animate(withWarps:)` runs on it makes SpriteKit steadily slower (1 ms up to 10 ms a frame within a minute). That's why fish step through warp frames by hand in `pose`. The coral sway uses warp actions only because its speed never changes. This is also noted in CLAUDE.md.
- `ponytail:` O(n²) boids within a school, fine up to a few dozen fish per school. Use a spatial grid, like Murmuration, if schools grow. `castShadows` is O(n²) over every fish, likewise.
- **Shadows only fall on sand and fish.** A fish over the rock casts its shadow on the sand behind it, hidden by the rock, not on the rock or corals. Shading a coral's top where a fish passes over would need its surface, which only `TankArt.skyline` knows.
- **Rock:** no permissively licensed photo of coralline-covered live rock exists besides `rock-1`, so `rock-3`, `rock-4` and `rock-6` are bare dry reef rock and a bleached Porites head. `coralline.py` (in the research scratch folder, not the repo) removed each photo's colour cast and painted muted pink, purple and green coralline patches onto them, in colours sampled from `rock-1`. The credits note the change, as CC BY asks. A first pass at full strength read as camouflage paint; the patches are now 70% toward the grey stone and cover about a third of it. `rock-3` and `rock-4` are toned to 0.78 and 0.88 of the live rock's mid-grey, since at full brightness they looked bleached beside it. There's still no tall pillar or arch.
- The shaders run on `u_now`, which moves with `SNAPSHOT_SECONDS`, so caustics move in snapshots, as fish and corals do.

## Sources
- **Photos:** every cut-out's author, licence and URL is in `reef-credits.tsv`, `ocean-credits.tsv` and `lagoon-credits.tsv` (iNaturalist CC BY and CC0, Wikimedia Commons, NOAA). The Ocean Voyager set leans on Wikimedia Commons' 339-photo CC0 set "Georgia Aquarium in Atlanta - HCP - September 17, 2022" (Vulturesong), about 90 of them inside Ocean Voyager; its photos are pure blue LED light with no red left, so they were kept as toned luminance and the scene re-tints them. The lagoon sharks had their cameras' pink or blue casts taken off by scaling each channel so the body's mean lands on a warm grey.
- **Ocean Voyager's look:** colours sampled from visitors' photos of the window on Wikimedia Commons: Zac Wolf's 2006 "Male whale shark at Georgia Aquarium" (the classic shot; metal-halide teal), istolethetv's 2009 "Manta ray", and the 2022 CC0 HCP set (LED-era azure, #2a7dbb top to #0168ab bottom, the floor a greyed slate blue). The window's size (23 ft × 61 ft × 2 ft) and the residents are from the Georgia Aquarium's own exhibit and animal pages. Okinawa Churaumi's Kuroshio Sea window was checked as the other great reference (purer deep blue); Dave asked for the Georgia Aquarium as the guide.
- **Shallow Reef's look:** reef-flat photos on iNaturalist (observations 407532622, 644469523 CC0, 718929416, 465127835, 148710399) and Kris Mikael Krister's CC BY 3.0 reef-flat shots and Furlan's Moorea split-level on Wikimedia Commons: sand near white under a metre of water, #3b93a6 at 2–5 m, far water #0c6c95–#1589b3; the surface band #287991 with brighter ripple lines; the caustic net's cell size, contrast and flicker.
- **Motion in games** (the 2026-10-07 motion research, after Dave's "do video game research how fish are setup in games"): the ABZÛ vertex-shader recipe as written up in Godot's "Animating thousands of fish" tutorial (whole-body sway and pivot, a travelling wave masked toward the tail, a twist; the head yaws, it doesn't hold still; Matt Nava, "Creating the Art of ABZÛ", GDC 2017); Webb & Keyes 1982 for the shark numbers (tail-tip excursion 0.16–0.21 L peak to peak, under one wavelength on the body, amplitude minimum 0.2 L behind the nose with nose yaw, beat frequency rising with speed); Berio, Morerod & Di Santo 2025 (J Fish Biol) for slow cruisers bending more of the body at a flat beat rate; Spine's shark rig breakdown (NotSlot) and forum answer for turning by squashing scale X through zero; Reynolds' steering behaviours (GDC 1999) and Lague's boids for heading-locked motion with a 2.5:1 speed band.
- **Footage** (the motion research, part 3): CC-licensed Commons clips cut to contact sheets: whale sharks side-on at Chimelong Ocean Kingdom, Georgia Aquarium's Ocean Voyager and Osaka Kaiyukan (the body rigid to the first dorsal, the caudal blade's width cycling to about half, a 4 s period, trevally riding ahead of the head); Meekan et al. 2015 (Front Mar Sci) for stroke rates and glides; Wilga & Lauder 2004 for slow sharks' nose-up trim; Fish et al. 2016 (Aerospace 3:20) for manta wing kinematics (tip ±0.35 disc lengths, 0.31 Hz, the stroke travelling base to tip).
- **Motion:** whale shark cruising speed from the Georgia Aquarium's species page (2.5 knots) and tail-beat scaling from Gough et al. 2019 (J Exp Biol) and Gleiss et al. 2011 (Funct Ecol, Nat Comms: glides between strokes); manta wingbeat 0.31 Hz and flap-and-glide from a 2022 drone kinematics study (Drones 6(5):111); cownose flap rate and tip amplitude from cownose ray kinematics (PMC2739381); hammerhead rolling from Payne et al. 2016 (Nat Comms 7:12289); blacktip reef shark speed and tail beat from Webb & Keyes 1982 (Fishery Bulletin 80:803) and its ledge-patrolling from Papastamatiou et al. 2009 (Ecology); the ribbontail ray's fin undulation from Rosenberger & Westneat 1999 (J Exp Biol 202:3523) and Rosenberger 2001 (J Exp Biol 204:379); epaulette walking from Porter et al. 2022 (Integr Org Biol) and Goto 1999; nurse shark and lagoon fish habits from the Florida Museum's species pages and FishBase. All real speeds are slowed three to five times for a calm desktop, as the reef tank's are.

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

- 2026-10-07, later: "i see sharks swimming backwards, the large whales just look so fake, how about you do video research, do video game research how fish are setup in games... if we cannot find a good solution then we need to cut the new fish tank locations, the reef is meh anyway, but the ocean voyager whole vibe and overall tank look is so cool would hate to waste it." A research agent brought back the game recipes and the shark kinematics (Sources); the engine moved to forward-only motion with turns that ease through zero (`Swimmer.intent`); five cut-outs that still faced left were mirrored, which was the last "backwards" shark; the giants got the sweep gait, agility and thrust; and a school's starting scatter was clamped into the water column.
- 2026-10-07, on the first build: "the motion of the larger animals just looks very unnatural", with two screenshots: a head-on manta sliding sideways and two whale sharks drawn through each other. Side views only, one near whale shark, and size-aware motion (`agility`, `thrust`, the `.sweep` gait) followed.
- 2026-10-07: "research some new options for the fish tank, lets obviously keep what we have as an option but lets maybe add like 2 new ones": a large aquarium view "like the Georgia Aquarium" ("remember to use The Georgia Aquarium as a guide, its one of the most popular aquariums in the world") and "a shallow tropical reef and we can try to add some small shallow sharks". Two research agents found the references and cut-outs; mock-ups (cut-outs composed over the engine's real water renders, by day and in Dark Mode) went to Dave before the build. His picks: the shallow reef is the **open sea**, not an aquarium exhibit; **one wallpaper with a Tank menu** rather than three wallpapers, plus "a tank shuffle option like we have for other wallpapers such as aurora"; add a **cownose ray squadron** to Ocean Voyager and a **resting nurse shark** to the reef flat (not groupers, turtles, hammerheads, bamboo sharks or more lagoon fish); keep both Dark Mode looks as shown; and a **Kelp Forest** (Monterey Bay's) as a third new tank after these two land. "Remember to cite all sources in our docs."

## Ideas / next steps
- **Kelp Forest**, Dave's pick for the next tank: Monterey Bay Aquarium's exhibit, giant kelp swaying in a surge under gold-green light, sardine balls, leopard sharks, garibaldi. The research (references, colours, cut-outs) is in the 2026-10-07 session's scratch folder `kelp/`.
- The lagoon's surface band still reads a little flat; bigger swell streaks and a wobble at the horizon line would help. Nurse sharks pile together in real life; a second one under the same bommie.
- Golden trevally pilot right in front of the whale shark's mouth, and mantas barrel-roll under the lights: both would need a per-fish target rather than a school home.
- Batfish, groupers, a turtle, hammerheads and a sawfish have cut-outs ready in the research folder if Ocean Voyager wants more variety.
- Rare visitors: a cleaner shrimp on the rock, a snail on the glass.
- A glint on each tail beat, for shiny fish like chromis. Left out for now: 38 fish flickering at 3 beats a second may read as busy.
- Settings: fish count, which species appear, the lighting look.

## Checking it
```sh
SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_SECONDS=8 swift test                        # Light Mode
SNAPSHOT_APPEARANCE=dark SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_SECONDS=8 swift test # actinic
SNAPSHOT_DEFAULTS="tank.kind=1" SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_SECONDS=12 swift test   # Ocean Voyager
SNAPSHOT_DEFAULTS="tank.kind=2" SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_SECONDS=12 swift test   # Shallow Reef
```
Each load rolls a different reef. Caustics are driven by `u_now`, which follows `SNAPSHOT_SECONDS`.
