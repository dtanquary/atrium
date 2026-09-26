# Murmuration

A starling murmuration seen from the shore at sunset: tens of thousands of birds wheeling as one over Brighton's ruined West Pier or a flat marsh pond, folding into dark bands and opening into pale sheets, mirrored in the water when they swoop low, and scattering in dark ripples when a falcon dives through.

- **Files:**
  - `Sources/Atrium/Murmuration.swift`: the scene, the flock and the ground shader.
  - `Resources/murmuration-pier.heic` and `murmuration-marsh.heic`: the ground photos with their skies cut away (HEIC with alpha, 4096 wide).
  - `Resources/murmuration-pier-aux.png` and `murmuration-marsh-aux.png`: their water maps (half size): red is water, green is the water's reflectance ÷ 2.
  - It uses Weather's physical sky (`Atmosphere`, `SkyCamera`, `SkyLight` and `CloudNoise` in `WeatherSky.swift`), `SkyMath.swift` for the Sun, and `frameTime` and `rgb` from `Fireflies.swift`.
- **Entry:** `@MainActor func murmuration(size:)` returns `final class Murmuration: SKScene`. Registry entry: icon `bird.fill`, tint `.brown`, `knobs: murmurationKnobs`.
- **Kind:** a CPU flock simulation in metres drawn as SpriteKit sprites, over two shaders (the sky, and the ground with its water).

## How it works
Everything was tuned against two research passes, saved in the session scratchpad: twelve measured murmuration photos (sky profiles, flock size, edge sharpness, bird size and tone) and the literature (StarDisplay, the STARFLAG measurements of real flocks, Attanasi's turning waves, Procaccini's and Storms' falcon-escape studies, Pearce's flock opacity).

1. **The view.** A level camera on the shore, 64° across, as `GroundView` (for the flock) and `SkyCamera` (for the sky), sharing one horizon. The horizon comes from the ground photo: it spans the screen's width on its bottom edge, so its horizon lands about 0.26–0.28 up a 16:10 screen (photos of murmurations put 10–40% of the frame, median 23%, under it).
2. **The sky.** `SkyLight.bake` once at build: the Somerset Levels on 1 December 2025, at the moment the Sun reaches the Light setting's height (Golden hour +5°, Sunset +0.5°, Afterglow −2°, Blue hour −5°), facing 10° left of it so the Sun sits right of centre. Each light has its own white balance (`evenings`), as a photographer's would: with only three wavelengths the physical sky turns violet in deep twilight where photos show blue. The shader decodes it, adds the Sun's disc and glow, and tone-maps like Weather's.
3. **The ground** (`groundShader`), from the photo and its aux map:
   - **Land and pier** keep the photo's shading, recoloured by our sky's horizon (30% of the photo's own colour kept) and scaled from the photo's sky brightness to ours, then darkened to 35%: photos show silhouettes at 0.3–4% of the sky, and the pier photo is a long exposure.
   - **Water** is our sky, mirrored about the horizon, times the water's reflectance as measured in the photo: the photo's water divided by its own sky at the mirrored height, a per-row profile (reflectance falls away from the horizon) times the fine ripples only, so the photo's reflections of its own clouds and its vignetting don't show. Rough water reflects sky from higher up than the mirror image, and a spread of it: `rough` samples three heights above the mirror (0.12 of the screen for the long-exposure sea, almost none for the calm pond).
   - **Slow ripples** keep the water from looking like a still photo. Two layers of Weather's baked `CloudNoise` drift different ways on the water plane, found for each pixel from its angle below the horizon with the eye 2 m up, so they shrink toward the horizon and fade out beyond a few hundred metres. Their slope bends where the water samples the sky, the photo's own ripple texture and the flock's reflection (a few points at most, near the bottom of the screen), and swells its brightness a little. A third, finer layer of wavelets, stretched across the view as wind ripples are and drifting toward the shore at about 0.3 m/s, brightens and darkens the nearer water (within about 45 m, where a pixel is still smaller than a wavelet); moving fine texture is what the eye reads as water. `waves` per ground (bend, drift speed, brightness): 0.03, ×2.5, 0.22 on the long-exposure sea, where bending barely shows; 0.05, ×3.5, 0.12 on the pond.
   - **The flock's reflection** darkens the water. Mirroring in level water flips a point about the horizon on screen, so each frame the flock splats each parcel's ink at its flipped position into a 384×96 texture over the water (`Flock.reflection`), saturating as d / (1 + d); the shader reads it with a little vertical smear. Only rows the flock touched this frame or last are converted and uploaded, and nothing is uploaded while the flock is too high to reflect, which is most of the time.
   - Baked offline by the scratchpad's `mur/ground/bake.py`: the sky cut by keying the dark pier against a smooth sky model (the pier) or `cutsky.py`'s skyline (the marsh), the wind farm on the pier photo's far left removed, and water found only near the horizon (below that it's all water, even where the photo's sea is dark).
4. **The flock** (`Flock`), a cut-down StarDisplay (Hildenbrandt, Carere & Hemelrijk 2010), ported from the research agent's validated prototype:
   - **1,500 agents**, each a parcel standing for about 40 birds (lengths scale by 40^⅓ ≈ 3.4 over a bird's). The count doesn't depend on the screen, so a bigger display just shows the same flock bigger.
   - **Neighbours:** a spatial hash of 6 m cubes, rebuilt by counting sort each step; the seven nearest by insertion into a sorted list of seven, and a count of those within 6 m. Each agent re-plans every fifth step (1/6 s, a starling's 0.076 s reaction scaled to a parcel) and holds its steering between.
   - **Steering**, in StarDisplay's newtons over an 80 g bird: separation all round (a half-Gaussian out to 20 m); cohesion scaled by centrality (the length of the mean direction to the neighbours, about 0 inside the flock and 0.5–0.75 on its edge), so only edge birds pull in; alignment; noise; a steer toward the flock's middle for birds with fewer than 12 within 6 m (after Hoetzlein's Flock2), which keeps one flock with a crisp edge; and a weak spring to the roost's height, which keeps it a thin horizontal sheet.
   - **Flight:** cruising at 10 m/s. The sideways part of the steering only sets a bank angle (rolling in over 0.1 s, out over 0.4 s, at most 69°); lift ∝ speed² tilts with the bank, so a banked bird turns, sinks and speeds up, then climbs back as it levels, as in StarDisplay.
   - **Turns:** every 7 s the bird furthest ahead picks a new heading, back over the roost if the flock has wandered, otherwise 60–150° either way. Birds seeing a neighbour turning copy it 0.15 s later, then rest 4 s, so turns sweep across the flock at about 15 m/s as real ones do (Attanasi 2014: 9–21 m/s). This is also what keeps the flock on screen, over a roost 220 m out and ±55 m across.
   - **The roost's height** drifts from 26 to 62 m over about three minutes, so the flock sometimes swoops low over the water, where its reflection shows.
   - **The falcon** (when Falcon attacks is on): every 45–90 s it dives through the flock's middle at 22 m/s for 6 s, unseen. Birds within 25 m scatter from it (a flash expansion); those within 20 m roll hard away for 0.25 s and back, and their neighbours copy the roll at 0.9 of its size, which sends dark bands across the flock (Procaccini 2011; Hemelrijk 2015).
5. **Drawing.** Each agent is one sprite, 7 m across, from a mipmapped atlas of four scatterings of ten birds (Gaussian, σ 1.3 m), each bird a dash (wings level) or a small V (raised) with a spread of sizes (in photos the 90th-percentile bird is twice the median). Per frame:
   - **position and scale** from the camera: birds are 3–6 px at 2x;
   - **rotation** to the projected wing axis, so dashes tilt together as a region banks;
   - **alpha** 0.22 + 0.45 × how much wing faces us (|banked up · view|): level birds seen from below and to the side show little; a bird rolled toward us shows all of it. That one line makes the dark folds, the falcon's bands, and the lightening in sharp turns;
   - **colour:** the sky behind the flock at a tenth of its light, since a silhouette at 200 m is darkened sky (blue-grey under blue, brown under gold), not black.

## Settings
| Key | Label | Values | Default | Notes |
|---|---|---|---|---|
| `murmuration.evening` | Light | Random, Golden hour, Sunset, Afterglow, Blue hour | Random | rebuilds the scene |
| `murmuration.ground` | Ground | Brighton West Pier, Marsh pond | West Pier | rebuilds the scene |
| `murmuration.falcon` | Falcon attacks | switch | on | read by the flock as it flies |

The knobs are referred to by name (`lightKnob`, `groundKnob`, `falconKnob`), not by their index in `murmurationKnobs`: when Ground was added, the falcon check kept reading index 1 and for a while the falcon only came over the marsh pond.

For repeatable snapshots, `MURMURATION_SEED=3` seeds the flock.

## Tuning constants
- Camera: 64° across, flock roost (0, 220 m, 44 m ± 18 m), roost area ±55 × ±40 m.
- Flock: 1,500 agents, 6 m cells, separation reach 9.2 m (σ, to 20 m), edge steer below 12 within 6 m, height spring 0.1 /s², turns every 7 s, cruise 10 m/s, bank ≤ 1.2 rad.
- Ink: 10 birds per 7 m parcel, alpha 0.22–0.67. Measured flock coverage (1 − L/L_sky inside the flock): mean 0.35–0.55, p95 0.7–0.95, against 0.2–0.5 and 0.8–0.97 in the photos (a little dark, from the few dense cores).
- Ground: pier horizon 780/1533 of its photo, sky L 0.125, rough 0.12; marsh 15/706, sky L 0.264, rough 0.005.

## Performance
- Release build at 2x: CPU 1.25–1.8 ms (simulation 0.4–0.7, sprites 0.25, SpriteKit's own 1,500 nodes about 0.6), GPU 0.45–0.8 ms. It no longer scales with screen area.
- The reflection costs nothing while the flock is high; about 0.05 ms while it's over the water.
- Flipping wing poses every few frames for shimmer cost 0.15 ms and only flickered at 3–5 px, so each parcel keeps one pose.
- On battery (15 fps) it takes two simulation steps a frame, so the flight is the same.

## Gotchas and shortcuts
- `ponytail:` 1,500 agents stand for about 60,000 birds, each drawn as a sprite of ten. More agents would give finer folds but cost CPU linearly.
- The sky is baked once per build, so the light doesn't change while it runs.
- The ripples use `u_time`, which follows the wall clock, so snapshots can't show them moving. To measure the motion, temporarily feed the shader a clock from an environment variable and diff two renders (2 s apart: the pond changes by about 2.7 levels of 255 on average, the pier's sea by about 1.8). The first version, at 1.3 and 0.3, drifted too slowly to see: "i am not seeing any ripples in the water".
- The flock is always drawn behind the ground, which is right for the pier (the flock is further out) and the far shore.
- A splat at a negative screen x must use `floor`, not `Int()`, or its weights go negative and `UInt8` traps.
- The pier photo is CC BY 4.0: its credit is in the code, README and Settings → About.

## Dave's feedback and decisions
- Built in the first batch; it had no fidelity pass until 2026-09-26.
- 2026-09-26: "I love the bird swarming stuff, but what else can we do to make that one 'feel' better and look better." This pass: physical sky, real flight model, photo grounds.
- He was shown three grounds (West Pier, marsh pond, reed bed) and asked for both the pier and the pond, as a setting, and asked whether the birds could be reflected in the water. They are.
- After seeing it: "its near perfect, we just need some very very subtle animation to make the water look not static ... i like both locations keep both." Hence the slow ripples.
- The old painted-sunset version (four-dot clusters in screen points) was kept behind a Compare switch until Dave said to remove it on 2026-09-26; it's in git history before then.

## Ideas / next steps
- **An evening's arc:** feeder flocks streaming in and merging, the light deepening from golden hour to blue hour over the display's real length (about 26 minutes), then the flock pouring down in a funnel into the reeds or under the pier, and a new evening fading in. Or follow the real sunset where you are.
- **A visible falcon:** a lone silhouette about 2.5× a starling's size, lighter than the flock, a few flock-lengths off its edge (as in the reference photos).
- **Splits and merges:** a sub-flock of a sixth to a tenth of the flock breaking off and rejoining within 10–20 s, as in about a quarter of the photos; copied 180° escape turns from the falcon would give these.
- **Blackening and dilution:** the flock compacting and darkening around an attack and spreading out about 15 s later.
- **Clouds:** most murmuration photos have some; Weather's cloud layer could be borrowed.
- **Flock size** as a setting: more birds per parcel and wider spacing.

## Checking it
`SNAPSHOT_DEFAULTS="murmuration.evening=2,murmuration.ground=0" MURMURATION_SEED=3 SNAPSHOT_SCENE="Murmuration" SNAPSHOT_SECONDS=30 swift test -c release -Xswiftc -enable-testing`. The simulation runs in `update(_:)`, so `SNAPSHOT_SECONDS` advances it; with seed 3, 106 s is a low pass that shows the reflection, and the first falcon comes at about 40 s. The scratchpad's `mur/opacity.py` measures flock coverage against a render with no birds.
