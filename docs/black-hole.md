# Black Hole (being built)

A black hole with a thin disc of glowing gas turning round it, in front of the real Milky Way, all of it bent by the hole's gravity: the far side of the disc lifts into a hump over the shadow, its underside shows as a ring below, the side turning toward us is brighter, and the stars behind slide and double round the edge. One shader, beside Nebula and Galaxy.

Dave picked the idea on 2026-10-10 from a brainstorm ([ideas.md](ideas.md)). That day it was researched by two agents and mocked up in three rounds, and he made the choices below. The build began on 2026-10-11: [The build so far](#the-build-so-far) says what exists. It is in the app as a hidden wallpaper (`unfinished: true`): the bending, the disc and the sky, with a first pass at the disc's look. The rest of this page is the plan, the measurements to build against and their sources.

- **Mock-ups and prototypes:** `docs/black-hole/` (see [Mock-ups](#mock-ups) and [Prototype](#the-prototype)).
- **The two research reports in full:** [the method](black-hole/research-method.md) and [the look](black-hole/research-look.md), which has the reference list, eight real black holes' numbers and the palettes.
- **Where it stands:** steps (a) to (e) of the build order are done, the motion check (d) twice, the second time on the finished look. It is still hidden (`unfinished: true`). Next is Dave's eye on it, and what is listed under [Still open](#still-open).

## Dave's decisions (2026-10-10)
From mock-up sheets, each choice with a recommendation beside it.
- **View:** nearly edge on (84° from the disc's axis), the one view. He did not pick the tilted view, the view from above or a slow drift between them.
- **Disc colour:** three, as a setting: orange (the default, gas at about 3,300 K), white-gold (about 6,200 K) and blue-white (about 15,000 K). He did not pick jewel palettes.
- **Size:** a slider, starting at medium (the disc about half the screen's width; a 56° field in the mock-up).
- **Position:** centred.
- **Speed:** the disc's inner edge goes round every 3 minutes, "but speed should be adjustable in a setting". Changed on 2026-10-11 once he saw it on his desktop: 1× is now a lap in 45 seconds (see [Dave's feedback](#daves-feedback)).
- **Sky:** ESO's Milky Way photograph as the glow, with real catalogue stars as sharp points (sheet 3, tile K). He first picked NASA's star map, on my word that it was public domain. It isn't clear of restrictions: see [The sky](#the-sky).

Still his to decide, once there is something running: how lopsided the disc's brightness should be (see Beaming), and whether the streaks' look is right once they match NASA's.

## How it will work
This section is the plan as it stood before the build. Where the build went another way it says so in a line beginning **As built**, and [The build so far](#the-build-so-far) has the detail and the measurements.

The method is Eric Bruneton's (2020), cut down for a camera that stays far from the hole. A prototype in numpy matched a brute-force ray tracer; the numbers are under [The prototype](#the-prototype).

Units: the Schwarzschild radius `r_s = 2GM/c² = 1`, so `M = ½`. The horizon is at `r = 1`, the photon sphere at 1.5, the innermost stable orbit (the disc's inner edge) at 3, and the critical impact parameter is `√27/2 = 2.598`. `u = 1/r`, `e = 1/b` (b the impact parameter), `μ = 4/27`.

### Bending, from two small tables
A ray round a non-spinning hole stays in one plane, and its shape depends on one number, `e`: `(du/dφ)² = e² − u²(1 − u)`. So two tables that depend on nothing but the metric do all the bending, for every view:
- **Table A, 256 × 128:** `u(e, φ)`, the inverse radius along a ray from infinity. `x = 1/(1 + 6e²)`, `y = φ/φ_ub` with `φ_ub = (1 + e²)/(⅓ + 2e³)` (Bruneton's two mappings). Stores `min(u, ½) × 2`. Each column is one RK4 run from `u = 0`, `u′ = e`.
- **Table B, 1024 × 1:** `φ_A(e)`, the angle from infinity to the ray's closest approach. `x = 1 − 2√(−ln(1 − e²/μ)/50)`. Stores `(φ_A − π/2)/8`. `φ_A = ∫₀^{u_A} du/√(e² − u² + u³)`, `u_A = ⅓ + ⅔ sin(asin(2e²/μ − 1)/3)`.
- Both are baked once at launch (10–30 ms expected, a guess) into 8-bit RGBA, since `SKTexture(data:)` is RGBA8: a value is split over two bytes (three for table B) so hardware bilinear filtering still interpolates it. `hi = round(255v)`, `lo = round(255(255v − hi + ½))`; in the shader `v = hi + (lo − ½)/255`.

Per pixel, with `c` the unit vector from hole to camera, `d` the pixel's ray, `n` the disc's normal and `u_c` one over the camera's distance:
1. `cosδ = −d·c`; `perp = d + cosδ c`; `sinδ = |perp|`; `y = perp/sinδ`.
2. `e = u_c √(1 − u_c)/sinδ`. The ray is swallowed if `e² > μ`: that is the shadow's edge.
3. The turn already made from infinity to the camera, in closed form: `φ_C = asin(u_c/e) − ½((2e² − u_c²)/√(e² − u_c²) − 2e)` (good to 1e-5 rad with the camera 30 r_s or more out).
4. `φ_A` from table B. `α = mod(atan2(−c·n, y·n), π)`: where the disc's plane cuts the ray's plane.
5. First crossing of the disc, on the way in: `ψ₀ = φ_C + α`, good if `ψ₀ < φ_A` or the ray is swallowed; `u₀` from table A at `(e, ψ₀)`.
6. Second crossing, on the way out: `s = 2φ_A − φ_C − α`, `ψ₁ = mod(s, π)`, `k = floor(s/π)`; good if `e² < μ`, `s > 0`, `ψ₁ < φ_A`. This one lookup holds the underside image and every order of photon ring.
   - **The two lookups are "before closest approach" and "after closest approach", not "first image" and "second image".** The disc's far side, the hump over the hole, is the direct image, but it comes from this second lookup with `k = 0`. Only `k = 1` and up are the underside and the rings. Both lookups are needed for the plain disc.
7. A hit if `1/r_out ≤ u ≤ ⅓`. The point is `(cos t · c + sin t · y)/u`, `t = α` for the first and `α + kπ` for the second.
8. The sky direction for a ray that escapes: `φ_∞ = 2φ_A − φ_C`, `cos φ_∞ · c + sin φ_∞ · y`.

Size, tilt, distance, where the hole sits and how the sky is turned are all uniforms: nothing is rebaked. That is what makes the size slider free.

### The disc
- **Redshift:** `g = √(1 − 1.5u) / (1 − √(u³/2) · cos_n / e)`, with `cos_n = (y × c)·n`. Doppler and gravity together, right for every image order. At the inner edge, edge on, coming toward us, it is √2.
- **Temperature:** `T(r) = T_peak · F(r)^¼`, F the Novikov–Thorne flux: with `x = √(2r)`, `F ∝ (x − √6 + (√3/2) ln((x + √3)(√6 − √3)/((x − √3)(√6 + √3)))) / (x⁵(x² − 3))`. Zero at the inner edge, so the edge fades by itself; it peaks at `r = 4.8` (9.55 M).
- **Colour:** a black body shifted by `g` is a black body at `gT`, so colour only ever slides along the black-body line. The three colours Dave picked are three values of `T_peak`.
- **Beaming:** in visible light, true Doppler brightening is brutal for a cool disc: at 78° the approaching side of the hottest ring is 191 times the receding side at 4,500 K, 39 times at 6,500 K, 8.6 times at 12,000 K. The mock-ups Dave chose from used the gentler all-wavelengths law (brightness ∝ `(g·T)⁴`) under a soft tone curve. NASA's own picture comes to 1.6 times in display values, about 3.3 in linear light: between the first power of `g` (2.2 times at 85°) and the second (4.7), where the full fourth power is 22. So: a Beaming knob, with its default set by eye to match the mock-ups and NASA's 1.6.
- **Turning without winding up:** cut the disc into narrow rings, even in `ln r` (9 per e-fold in the prototype). Each ring turns rigidly at its own Kepler rate, `√(1/(2r³))`; a point takes the patterns of the two rings it lies between, mixed by where it sits. Neighbours slide past each other and nothing stretches. Tileable noise sampled in (turns, ln r) with whole repeats round the disc: 4 fetches of `CloudNoise.texture`. **As built:** not rings but three overlapping generations of the scene's own noise, each sheared by its age and reborn in turn (step b), with knots born six times as long as deep and their colour following their brightness (step e). Looked at moving twice (steps d and e).
- **Speed:** 1× is the inner edge round in 3 minutes (Dave). **As built:** 45 seconds, after his feedback. For scale, the inner orbit of Sagittarius A* takes 33 minutes (92.3 GM/c³ for 4.3 million Suns), so real time for it is 0.09× (0.02× as built): a marked stop on the slider, not the default.
- **Streaks:** the mock-ups' texture is a placeholder, and it is the "vinyl record" the look research warns about: even concentric bands. NASA's are sheared arcs of uneven width that fork and fade.

### The sky
- **Stars as points, not a picture.** For stars to stay sharp a sky map would need to be about 18,000 pixels wide. The plan: bake the catalogue into a 1024 × 512 grid of cells, one star a cell (its place in the cell, brightness, colour), and per pixel look at the 2 × 2 cells round the ray's sky direction and draw each star with the lens's stretch in closed form, brightened by the real magnification (capped, so a star passing dead behind the hole doesn't flash). **As built:** a 2048 × 1024 grid, in the scene's own frame with its poles straight up and down from the view, where the camera never looks. Checked in the prototype against 68 star images solved directly: within 0.09 px (first image) and 0.13 px (the second image, on the far side of the ring).
- **Which stars.** The app's Yale catalogue (2,888 stars to V 5.5) puts only about 100 on screen. Dave's pick, tile K, used HYG v4.4: 119,614 real stars, **CC BY-SA 4.0**, which NOTICE's list of licences allows (it needs its credit in About, and the baked grid stays under the same licence).
- **The Milky Way.** ESO/S. Brunier's panorama, **CC BY 4.0**, already credited for Deep Space Tour. It needs a fresh copy (the one in `Resources`, `deep-milky-way.heic`, was cropped and feathered for the tour and can't wrap). It is not an exact galactic map: its stars can't be lined up with the catalogue's (the best single shift left only 30% of bright stars within 0.12°). So it is blurred to a glow, about 1024 × 512 and a few hundred KB, and the catalogue supplies the stars. **As built:** 2048 × 1024 and 118 KB, with the photo's own stars taken out and their light spread back as a haze (step c).
- **Why not NASA's.** NASA SVS's Deep Star Maps 2020 is the exact map, and the first two mock-up sheets were drawn over it. It is built from Gaia DR2, and ESA's licence page says "Gaia data are distributed under the CC BY-NC 3.0 IGO license". Non-commercial isn't among the licences this app accepts. I had told Dave it was public domain before checking; corrected the same day.

### Glow and stretch
One `SKShader` pass can't blur. Start with Galaxy's stretch (`asinh(20·lum)/asinh(240)` on brightness, colour kept) and dither. NASA's picture has no bloom at all: the shadow, and the gap between the photon ring and the disc, are exactly black. A baked halo (the shader drawn small offscreen, blurred on the CPU, handed back as a texture, as `MoonBaker` does) is only for later, if the stretch alone looks hard. **As built:** `asinh(20·most)/asinh(165)` on the strongest channel (step e), and the baked halo after all, because Dave picked the glow (step f).

### Cost (the estimate; measured with everything in, the glow and the twinkle too: GPU 0.87–0.94 ms, CPU 0.5–0.7 ms, seven textures and 17 other uniforms; with the sky drifting 0.92–0.98 ms and 19; at Size 3, 0.92–0.99 ms, and 0.98–1.02 drifting)
8 to 14 fetches from small textures a pixel, about 250–350 arithmetic operations. Expect 0.6–1.2 ms of GPU against the 2 ms budget; about 0.5 ms of CPU, as every shader scene. About 23 uniforms of roughly 30, 7 of them textures. Memory: 136 KB of tables, 2 MB star grid, 2 MB glow map.

## Acceptance numbers
Measured on NASA's 2019 visualization, whose frames are 3840 px with one brightness value per pixel. Unit: the shadow's radius `R = √27 M` (the photon ring's radius). The disc there runs from 6 M to 30 M.

At about 85°, distances from the centre along the vertical:
- The hump (far side of the disc): 1.27 to 2.55 R above.
- The near side: 0.11 to 0.48 R below, and it stays opaque to 0.66 R, cutting the under-arc off flat. That dark strip is a signature of the real thing.
- The under-arc: 1.24 to 2.16 R below.
- The dark gap between the photon ring (1.00) and the disc's inner edge (1.27): 0.27 R wide, exactly black.
- Half-width 5.97 R on the bright side (5.72 measured on the dim side, where a fixed brightness threshold pulls the faint edge in; the geometry gives 5.96 on both, for a disc to 30 M).
- The photon ring's hairline sits at 0.998 R and is at most 0.004 R wide. The next ring out thins to 1.010–1.022 R over the top.
- Approaching side to receding: 1.59–1.63 in display values. The brightest pixel is always on the approaching side, 1.8–2.2 R out.
- No glow: every pixel beyond 6.8 R, and inside 0.98 R, is 0.

Face on, brightness by radius (R: value of 255): 1.4: 69, 2.0: 157, 2.5: 174 (the peak), 3.0: 167, 4.0: 136, 5.0: 72, 6.0: 9. The outer edge is a soft taper from 4 to 6.2 R, faded by hand (a thin disc's own flux would still be 15% of peak there). Streaks span the 5th to 95th percentile 100–200 at 2 R. The mean lit pixel is 104 of 255: mostly deep red, orange only in the streaks.

Note: Dave's mock-ups drew the disc to 22 M (11 r_s), not NASA's 30 M. Match the mock-ups; the numbers above are for checking the geometry.

## Settings (the plan)
- **Disc** (`blackhole.heat`): Orange, White-gold, Blue-white. Swatches from the black-body table.
- **Size:** a slider, close to small in a wide sky; medium by default.
- **Motion:** Speed, 0 to 4×; 1× is the inner edge in 3 minutes (45 seconds as built).
- **Look:** Brightness (exposure before the stretch, Galaxy's way), then the shared grade knobs; Beaming 0–1; Streaks 0–1.
- **Sky:** star brightness, Milky Way brightness. (And a twinkle, which Dave asked for once he had it on his desktop: step (g).)
- Not planned: a view choice, a drift, spin (below), jewel palettes, a stars-only switch. Each was offered and not picked, or advised against. (That drift was one from view to view. The sky's drift of step (h) is another thing: the view stays where it is.)

As built (all on the `Wallpaper` entry, from `BlackHole.knobs` and `BlackHole.palette`):

| key | label | range | default | drives |
|---|---|---|---|---|
| `blackhole.heat` | Disc | Orange, White-gold, Blue-white (or Random) | Orange | the hottest ring's temperature: 3,300, 6,200 or 15,000 K; a new pick rebuilds the scene |
| `blackhole.size` | Size | 0.65–3× | 1 | the field of view: 78° at 0.65×, 56° at 1×, 39° at 1.5×, 30° at 2×, 20° at 3× |
| `blackhole.brightness` | Brightness | 0.4–1.8 | 1 | the disc's exposure before the stretch |
| `blackhole.glow` | Glow | 0–2 | 1 | the disc's light spread round it; 1 is tile M's strength, 0 none (and no glow is made) |
| `blackhole.beaming` | Beaming | 0–1 | 1 | how much of the Doppler shift shows; 1 is the full `(g T)⁴` |
| `blackhole.streaks` | Streaks | 0–1 | 0.7 | the streaks' contrast; 0 is a smooth disc |
| `blackhole.speed` | Speed | 0–4× | 1 | the disc's clock; 1× is the inner edge round in 45 seconds, 0 holds it |
| `blackhole.stars` | Stars | 0–2 | 1 | the stars' brightness |
| `blackhole.twinkle` | Twinkle | 0–1 | 0.6 | how far each star swells and fades on its own slow rhythm: up to 0.87 of a magnitude either way at 1, none at 0 |
| `blackhole.milkyway` | Milky Way | 0–2 | 1 | the glow's brightness |
| `blackhole.drift` | Drift | 0–4× | 0 | how fast the camera goes round the hole, which turns the whole sky; 1× is once round in 36.5 minutes, 4× in 9.1; 0 is a sky that stands still |

The shared grade knobs (contrast, saturation, hue) were planned and not built: nothing asked for them, and each is another uniform.

## Deliberately left out
- **Spin (Kerr).** Rays round a spinning hole don't stay in a plane, so the small tables don't exist; it needs a screen-sized map baked per view and gives up the free size slider. NASA's and Luminet's pictures are of non-spinning holes.
- **Real black holes as a setting.** Mass changes only speed and temperature, so the famous ones give four pictures, not ten, and the two that have been photographed (M87*, Sgr A*) have hot thick flows that need a different renderer. A later idea. Notes on eight candidates are in the look research (see Sources).
- **Live data.** Cygnus X-1's X-ray state can be read daily (Swift/BAT, MAXI), but it is a change visible light wouldn't show.
- **Light-travel delay across the disc.** Ignored; for a noise pattern it is only a fixed warp.

## Risks, worst first
1. **The look.** The geometry is settled; whether it is pretty at "soft and dim" is not. Crystals was cut with its physics right. This picture's beauty is fine bright streaks on black. Compare a softened render with NASA's side by side before going far.
2. **Thin rings shimmering.** The second photon ring is about 2 px wide at Retina and the third 0.1 px. Use `fwidth` to soften where it is thinner than a pixel, and check frame strips at 15 fps as well as 60. With the view held still (Dave's pick) only the disc and sky move, which helps.
3. **SpriteKit unknowns**, which nobody could test without building: packed 8-bit tables under the real GPU's filter (if it rounds the filtered value to 8 bits, the packing fails; fall back to fetching texel centres and mixing by hand); seven textures in one shader; about 23 uniforms. **The first is settled** by step (a): the filter keeps the packed bytes.
4. **GPU time** is an estimate.
5. **The ring-by-ring turning** hasn't been seen moving: seams between rings may read as bands. A two-phase flow map is the fallback. **Changed in the build:** the flow map goes first, see [The build so far](#the-build-so-far).
6. **Float precision at the shadow's edge** (table B's coordinate takes `ln(1 − e²/μ)`).
7. **The star grid's pole** pinches: put it where the camera never looks.

## Build order
Each a commit; follow "Adding a scene" in `Sources/CLAUDE.md`. One file, `Sources/Atrium/BlackHole.swift`, on Galaxy's pattern; everything built in `init`; motion in `update(_:)` by elapsed time.
1. **(a) Tables**, with a debug uniform that draws the prototype's test pattern, matched pixel for pixel to `proto/out/compare-reference.png` (camera 100 M out, 40° across, 78°, disc to 24 M). This is where risk 3 is found out.
2. **(b) Disc physics.** Measure the GPU here, with the disc filling the screen.
3. **(c) Stars and the glow map.** Adds two resource files and their credits (`blackhole-credits.tsv`, About).
4. **(d) Motion**, checked in frame strips.
5. **(e) The look**, against NASA's frames and the mock-up tiles Dave picked (sheet 1 tiles A, D, E; sheet 2 tile H; sheet 3 tile K).
6. **(f) A baked halo**, only if (e) says the stretch isn't enough. (It didn't; Dave picked the glow from a sheet, so it was built.)
Also owed: an icon, the README's own entry and the site. Done: Bruneton's BSD-3 notice in NOTICE (three expressions of his: table A's column, its row bound and table B's stretch), and the tables' test against Runge-Kutta.

## The build so far
`Sources/Atrium/BlackHole.swift` and `Tests/AtriumTests/BlackHoleTests.swift`, written by the agent that made the prototype and reviewed by the session that planned it.

**Step (a), the tables (2026-10-11).** `Bending` bakes both tables in Swift at launch (0.3 s for both, with their checks, in a debug build; a release build isn't timed yet). The shader bends light with them and can draw the prototype's test pattern in place of the picture. Three tests:
- `blackHoleBendsAsThePrototype`: the pattern on the real GPU at 960 × 600 against `proto/out/compare-reference.png`. 352 of 576,000 pixels differ, all on the edges of checks: edges sit within about 0.015 px on the disc and 0.002 px on the sky.
- `bendingTablesFollowTheRays`: the baked bytes, read as the shader reads them, against rays stepped by Runge-Kutta. Table A within 5e-5 in 1/r for rays aimed within 16 radii; table B within 1e-4 rad down to a part in 100,000 of the shadow's edge, checked against a march to the turning point, not the integral that baked it.
- `gpuKeepsTheTablesPrecision`: each table read back through the GPU's filter.

What the GPU's filter does, which nobody could know before building:
- **It keeps the packed bytes.** A filtered reading isn't rounded to a byte (errors are 20 to 80 times smaller than that), so the two- and three-byte packing works.
- **It places a reading only to about a 35th of an entry**, not the 256th the prototype assumed. Measured against exact smoothing: table A within 2.1e-4 (mean 5e-5), table B within 1.1e-4 (mean 1.2e-5). With both tables left to the filter, 987 pixels differed and the sky sat 0.03 px out.
- So **table B is read at the two entries either side and mixed in the shader**, which took the sky to 0.002 px. Those two reads also give the slope the stars' stretch needs.
- **Table A is left to the filter** (0.015 px here, about a 20th of a pixel at Retina width). Mixing it by hand gave 131 differing pixels, better than numpy's 152, but costs six more reads wherever the disc is. That is the known fix if the disc's texture ever looks stepped.
- Table A's last two columns (rays aimed more than 16 radii out) are coarse, off by up to 0.004 in 1/r. No disc is out there, and the error can't make a false hit.

**A change from the plan for step (b).** The disc's streaks will be three overlapping generations of noise, each sheared by its own age and reborn in turn (a flow map), not rings turning rigidly. Rigid rings can only draw concentric bands, the even "vinyl record" look of the mock-ups' stand-in texture, which the build isn't to copy; NASA's arcs are knots sheared by age. The conditions it has to meet: no breathing as generations cross (mean and contrast of a patch flat within about 2% over a cycle), streaks from the moment a generation is born, the inner edge still round once in 3 minutes, and a clock that Speed can stop or change without a jump.

**Step (b), the disc (2026-10-11).** The scene is in `allScenes` as Black Hole, hidden. What it draws:
- **The disc's physics as planned:** Novikov-Thorne heat, the redshift `g` for every image, colour from a black-body table baked in Swift (`BlackBody`: Planck's spectrum through the CIE 1931 curves, in [Wyman, Sloan & Shirley's analytic fit](https://jcgt.org/published/0002/02/01/), to sRGB), brightness as `(g T)⁴`, the mock-up's opacity and outer fade, and both crossings of the disc composited front to back.
- **Streaks as a flow map:** three generations of noise a third of a life apart, each read at its own Kepler turning since birth. Their weights are `(1 − cos)/3`, whose squares sum to a constant, so contrast can't pulse as generations cross. A generation lives 60 of the hole's time units (234 s at 1×), in which the inner edge laps 1.3 times and the rim 0.19. The noise is a texture of four octaves, one a channel (512 × 128 at this step, 512 × 512 since step (e)); each octave fades out as its cells shrink toward a pixel, so streaks seen edge on or wound tight melt into the glow.
- **A hairline at the shadow's edge.** Drawn one by one, the images of the disc thinner than a pixel came out as stray dots. Where a pixel spans more than about a radian of extra turn they give way to their average: 0.14 of the disc's light at 5 radii.
- **Tone:** Galaxy's asinh on brightness with other constants, fitted to the mock-up's own curve. Galaxy's grey mix for highlights is left out, so red clips first, then green.
- **Settings so far:** Disc (the three temperatures, Orange the standard), Size 0.7× to 1.5× (the field of view: 1× is 56°, the ends about 74° and 39°), Brightness, Beaming, Streaks, Speed 0 to 4×. Size and Speed never rebuild anything.

Measured:
- **Cost:** GPU 0.38–0.47 ms a frame at 3024 × 1964 (0.41 in my own run), CPU 0.42 ms in a release build. The estimate of 0.6–1.2 ms for the whole picture was high; stars and glow are still to come. 15 uniforms so far, 4 of them textures.
- **Tests:** the three from step (a) still pass (355 pixels differ now: the hit point is worked out another way).
- **Motion, checked on 90 frames at Speed 4×:** no pixel changes by more than 0.008 between frames, no dots, no shimmer on the thin rings, and a patch's mean and contrast stay flat. But see below: it is calm because it is soft.
- **Beaming:** at 1 (the full law) the approaching side is 1.6–1.7 times the receding in luma after the stretch, which is NASA's displayed ratio, so 1 is the default.

**What is wrong with the look at step (b)**, against mock-up tile H (the same boxes on both):
- Its range is squeezed: luma at the 10th, 50th, 90th and 99th percentile of the disc is 0.36, 0.50, 0.72, 0.82 against the mock-up's 0.31, 0.40, 0.83, 0.99.
- The hot side never goes yellow-white: no pixel is near white, against 6.3% of the mock-up's disc.
- Fine contrast (luma less its 9 px blur) is 0.041 against 0.088. It reads as airbrushed, with a wide feathered rim.
- Frames 2 s apart at 4× are hard to tell apart, so at 1× it would read as a still. The streaks have to carry the motion: finer, crisper, with dark gaps.
- Empty sky isn't quite black: the dither leaves 1/255 on a quarter of its pixels.
The look pass (e) is to fix these before the motion strips (d), since shimmer only shows at high contrast.

A gotcha found on the way, now in `Sources/CLAUDE.md`: SKShader has `fwidth` but not `dFdx` or `dFdy`.

**Step (c), the sky (2026-10-11).** The real stars and the Milky Way, both bent by the hole.
- **Two files, baked by `docs/black-hole/sky.py`** in half a minute from HYG's `hyg_v44.csv` and ESO's 6000 × 3000 JPEG, both already turned to the scene's own frame (the sky as in tile K), so the app does no astronomy:
  - `blackhole-stars.lzfse`, 566 KB: HYG's 115,562 stars from magnitude −1.5 to 11, six bytes each (place, magnitude, B−V).
  - `blackhole-glow.heic`, 151 KB (118 KB since step (e)): ESO's panorama as a 2048 × 1024 glow.
- **Credits:** `blackhole-credits.tsv` (author, licence, source), a line in Settings → About, the README's Credits, and NOTICE for Bruneton's expressions. The star file is an adaptation of HYG and stays under CC BY-SA 4.0.
- **HYG's own sources, checked at its README on 2026-10-11:** v4.4 combines the Hipparcos, Yale Bright Star and Gliese catalogues, CC BY-SA 4.0 since v4.0. It has no Gaia data: that is its sister set, AT-HYG, which this doesn't use.
- **The glow is not the mock-up's plain blur.** Blurred, the photo's own stars stay as soft blobs degrees from the catalogue's sharp ones. So the bake takes them out (a 9-pixel opening: stars go, dust lanes stay) and spreads their light back over a degree. Display levels beside tile K (mock-up / build): the Milky Way's band 48 / 38, under the hole 43 / 30, empty sky 13 / 4. The build is darker partly because the mock-up's bloom isn't copied.
- **Stars are points** 1.5 to 4 px across at Retina. 110,973 of the 115,562 have a grid cell of their own; 4% share one with a brighter star and are dropped.
- **Settings added, under Sky:** Stars and Milky Way, each 0 to 2.

Measured:
- **Stars land where the lens puts them.** A separate script solved each bright star's image directly (bisection on the escape angle) and looked for it in the app's picture: all 667 stars brighter than magnitude 7.5 in clear sky were found, their centres 0.07 px off at the median and 0.35 px at the 90th percentile; the 8 within four shadow radii, where the lens moves them most, 0.15 px.
- **Tests, five now:** `blackHoleSkyHoldsItsStars` (Sirius, turned to the scene's frame from scratch, is the brightest thing in its cell) and `blackBodyKeepsToTheLocus` (the colour table against six published points of the Planckian locus, to 0.004) join the three.
- **Cost with everything in:** GPU 0.70–0.71 ms a frame at 3024 × 1964 at every size, CPU 0.54 ms. Six textures and 13 other uniforms, so risk 3 is settled. Building the scene takes about 30 ms (tables 7, star grid 7, the glow's decode 14), 140 ms more the first time the app decodes any HEIC; a second copy takes 1.3 ms.

Open after step (c):
- The glow shows faint concentric arcs round the hole. They may be the haze's lumps stretched by the lens, as tile K's are, or an artefact. The test is a flat grey sky, which lensing must leave flat.
- Stars read thinner than tile K's at a glance: about 10,600 peaks over 0.25 luma outside the disc at full size, 340 over 0.5. The default may want to be brighter.
- The disc's look, as listed above. The dither is still on the shadow.

**Step (d), a first motion check (2026-10-11), done on the soft disc before its look pass; it was done again after it, see step (e).** A test steps one scene frame by frame and saves strips: `BLACKHOLE_STRIPS=<dir> swift test --filter blackHoleMoves` (it does nothing without the variable).
- At full Retina size, default size and speed, eight frames in a row at 15 and at 30 fps, at three places (the thin ring over the shadow, the disc's near side seen edge on, the bright left end): no pixel changes by more than 1 of 255 between frames. The hairline and the ring hold still; nothing sparkles.
- Over a whole life of the streaks (15 frames, 5 s apart at Speed 4×): the lit disc's mean stays between 131 and 138 of 255 and its spread between 36 and 39, so generations hand over without a pulse, and the pattern never winds up.
- By construction: the inner edge turns 2° a second at 1× (about 3.7 pt/s on screen at the default size), Speed 0 holds it still, and the clock is a Double moved on by elapsed time, capped at 0.1 s a frame.
- One or two stars close to the Einstein ring are drawn as short dashes: the correction that keeps stars round is exact only for small offsets, and right at the ring a star really is pulled into an arc. They are still.
- **The catch:** a pixel changes by 0.02 of 255 a frame on average. The motion is calm to the point of being hard to see, because the streaks are soft. That is the look pass's job.

**Step (e), the look (2026-10-11).** `black-hole/sheet4-app.jpg` puts the app's snapshots beside the mock-up tiles Dave chose from (A, D, E for the three colours; G, H, I for the sizes; K for the sky); `black-hole/compare.py` makes it from a folder of snapshots and prints the numbers below. What changed to get there:
- **Streaks are fine sheared arcs with dark gaps, not soft blobs.** A knot is born six times as long round the disc as it is deep (10 cells round and 12 up in the coarsest octave of a 512 × 512 texture), so it is a streak from its first frame, at the slow outer edge too; and it shines up to 12 times as bright as a lane between knots (it was 3). Arcs fork where generations of different ages cross, and fade: NASA's look.
- **A streak's colour follows its brightness.** Brightness goes as the fourth power of temperature, so a knot 12 times brighter than a lane is 1.9 times hotter: knots are a quarter hotter than the disc round them and whiter, lanes a third cooler and deep red. Colour still only slides along the black-body line. Without this the lanes were brown, a dim orange, where NASA's are red.
- **The rim is broken into wisps.** The disc thins out over the last 42% of its radius, lanes sooner than knots, so streaks run out past the gaps between them. It was a smooth feather.
- **Tone:** still asinh on brightness with the colour kept, but brightness is now the strongest channel, not Galaxy's weighted sum, so the three disc colours expose alike (the white and blue discs came out dull under the sum). The curve is `asinh(20·most)/asinh(165)`, which reaches full short of the brightest gas: red clips first, then green, and past that the gas burns out to white (mixed in from 0.88 to 1.2 of full), which gives the mock-ups' white-hot side. Per-colour exposures: Orange 1, White-gold 2, Blue-white 1.6.
- **The shadow is exactly black.** The dither is left off wherever nothing shines; measured, no pixel inside the shadow is above 0.
- **Stars** are a little brighter and wider than at step (c) (a magnitude 9 star peaks at 0.22 before the stretch; the narrowest are 0.85 px in radius). Counted at full size outside the disc, as peaks standing above the sky round them: 3,700 by 0.05 of luma, 2,400 by 0.25, 700 by 0.5. Tile K, at its own 960 px, has 3,150, 390 and 36: as many stars, each a soft blob where the app's is a point.
- **The glow** is smoothed a little more in the bake (118 KB now), which took a faint mottling out of the empty sky.
- **Size** runs 0.65× to 1.5×, so its small end reaches tile I's 78° field.

Measured on the finished look, at full Retina size:
- **Against tile H, both at 800 × 500, as the step (b) review measured it** (pixels with luma over 0.3; mock-up / app): luma at its 10th, 50th, 90th and 99th percentile 0.31, 0.40, 0.85, 0.99 / 0.32, 0.39, 0.77, 1.00; near white (every channel over 0.75) 6.3% / 5.5%; fine contrast (luma less its 9 px blur) 0.089 / 0.101. All inside the targets (within about a fifth of the mock-up's; fine contrast at least 0.08). The approaching side over the receding, in luma along the disc: 2.6 / 2.2 (NASA's is 1.6). Sky far from the hole, median luma: 0.069 / 0.036; the mock-up's includes its bloom.
- **The faint arcs in the glow are the sky's own lumps stretched by the lens, not an artefact.** With the glow made a flat grey and the stars off, 99.94% of sky pixels came out within 1 of 255 of each other; the rest are where the disc's thin outer edge lies over the sky. With a smooth ramp for a sky, no pixel differs from its neighbour by more than 3 of 255 (the dither alone is 2) and the slope never changes by more than 0.44 a pixel: table B's entries don't show as steps.
- **Motion, again** (`blackHoleMoves`, on this look): at 15 fps no pixel changes by more than 3 of 255 between frames, at 30 fps by more than 1, at the thin ring, the near side and the bright end alike. At 1×, two frames 5 s apart differ by 8.4 of 255 on average over the disc, 41% of its pixels by 8 or more: the turning shows. Over two lives of the streaks (78 looks, 1.5 s apart at 4×) the disc's mean brightness runs 115 to 128 of 255 and its contrast 49 to 59: that is the streaks themselves coming and going over minutes. The part that keeps time with the generations handing over, which would be breathing, is ±0.7% of the mean and ±0.9% of the contrast.
- **Stars still land where the lens puts them:** 568 of 568 found, 0.04 px off at the median, 0.16 px at the 90th percentile.
- **Cost, release build, at sizes 1.5×, 1× and 0.65×:** GPU 0.70–0.74 ms a frame; CPU 0.4–0.8 ms on a machine busy with other builds (Galaxy, in one of the same runs, 0.58 and 1.91). Six textures, 13 other uniforms.
- **Tests, seven:** the six above pass, and `blackHoleMoves` does nothing without its variable.

**Step (f), the glow (2026-10-11).** The glow Dave picked, tile M, with a Glow slider under Look: 0 to 2, 1 the default and tile M's strength, 0 none. Built on a branch of its own (`black-hole`).
- **How it is made.** The disc is drawn alone and small, offscreen (756 px across, by the desktop's own shader with the sky off, so there is one account of the disc's light), read back, taken as light (its values to the power 2.2) and blurred on the CPU (`vImage`) at `glow.py`'s two widths: 60% at 14 px in radius on a 3,024 px picture, 40% at 60 px. That goes to the shader as a texture 378 across, which adds it as light at 0.45 × Glow after the stretch, where `glow.py` adds it.
- **When.** As the scene is built, in `init`, so the render test and the copy behind Settings have it. Again when Size, Brightness, Beaming or Streaks has moved: at most once in 0.15 s for a scene, and never two scenes in one frame. (A new disc colour rebuilds the scene anyway.) Until one is made for a new Size, the one there is stretched to fit, so it follows the disc at once. At Glow 0 none is made.
- **It doesn't follow the streaks.** That would mean making it every frame; and made from one frame, it would hold that frame's knots as bright patches while the disc turned under them. So it is made from the disc with its streaks shuffled: each pixel reads them at a random place of its own, in four pictures each half a pixel aside from the last, which gives what the streaks average to.
- **One shader, written out twice.** The offscreen picture differs in two lines: it keeps its fine streaks however small it is drawn, and it shuffles them. A uniform switched those at first, and then Glow 0 was no longer the old picture: 47 pixels were one step of 255 off, because the compiler laid out the arithmetic another way round the lines that never ran. So the two lines are written into a second copy of the source. Every scene shares one offscreen scene, so the second shader compiles once.
- **Glow 0 is the picture as it was, to the byte.** A still with the same streaks from this code at Glow 0 and from the commit before it are the same file (`cmp`), with the sky and with it off.

Measured at 3024 × 1964, default size, Orange, on stills from `blackHoleStill`:
- **Against tile M** (`glow.py` run on the Glow 0 still), along three cuts from the disc's edge at 20, 60 and 150 px, luma of 255, M / the app: straight up from the hump 35.5 / 38.4, 22.5 / 22.3, 5.0 / 6.0; straight down from the underside ring 40.7 / 43.6, 66.3 / 67.0, 32.1 / 33.1; out from the bright left end 27.7 / 36.4, 17.6 / 16.6, 6.2 / 7.2. Eight of the nine are within the 15% asked for. **The left end at 20 px is 31% over** (40% with the sky off).
- **Why the left end misses:** M is the glow of one frame, and in that frame the streaks at the left end happen to be dim. Over 18 stills at other moments of the streaks, the recipe's glow at that point has a spread of ±64% of its mean (in light, one standard deviation); up and down from the hump, ±22%. Against the recipe averaged over the 18 (worked in floating point, shown as the picture's values on black), the app is within 2% above the hump, 6% below the ring and 10% at the left end, out to 100 px.
- **The app's glow has light in it that M's left out.** `glow.py` finds the disc as red more than 40 over blue, which a white-hot pixel isn't: 10–19% of the disc's light, all on the bright side, never reached M's blur. The app spreads all of it. With the mask taken off the recipe, the app is within 6% of the 18's mean on all three cuts.
- **Beyond about 130 px M adds nothing, and the app next to nothing.** `glow.py` blurs whole bytes, so its glow stops dead there (132 px above the hump), with a last step of 9 of 255 in red on black. The app's fades out by the same place instead (half a byte of light is taken off, softly): 2 of 255 on black at 150 px, its last 1 at 170. The recipe in floating point would still add 6 of 255 at 150 px; that longer tail isn't what Dave saw.
- **At Glow 1 no part of the shadow is black,** in M or in the app: its middle is 21 of 255 in M, 23 in the app. At Glow 0 it is exactly black, as before.
- **The glow softens the disc, a little more than M did.** Fine contrast, as step (b) measured it, on the whole still at 800 px: 0.094 at Glow 0, 0.081 in M, 0.074 in the app. Two frames 5 s apart at 1×, on the disc's pixels: 26.5 of 255 at Glow 0, 22.8 with M painted on each, 19.5 in the app. Half of that gap is the white-hot light above; the rest is that M's glow, made from each frame, gave a knot a little more than the lane beside it.
- **By eye,** M beside the app at 0.65× and 1.5× and in White-gold and Blue-white: alike, but for M's hard outer edge. (`glow.py` can't find a blue disc and misses most of a white one, so for those two M was made from the still with its sky off, all of its light.)
- **Cost,** release build, in the same runs as the commit before: GPU 0.74–0.77 ms a frame before, 0.75–0.79 at Glow 0, 0.80–0.84 at Glow 1 and 2 and at every size; CPU 0.5–0.7 either way (Galaxy, in the same runs, 0.6 and 1.6–2.3). Seven textures and 15 other uniforms. Making a glow takes 9–14 ms on the main thread: four small pictures drawn, read back and summed 8, the blur 0.6, packing 1. The first of a run takes 90–210 ms, which is the second shader compiling. So a dragged slider costs one 10 ms frame in nine at 60 fps.
- **Motion** (`blackHoleMoves`): from frame to frame at 15 fps no pixel changes by more than 6 of 255 (7 on the commit before, in the same session), at 30 fps by more than 3 (4): the glow adds no flicker. When a fresh glow takes over from the last after 0.15 s of a slider dragged across its whole range in 2 s, with the disc held still: for Size no pixel changes by more than 5 of 255 and 99.9% by 3 or less; Brightness 4; Streaks 2. The handover between streak generations beats by 0.1–0.8% of the mean.
- **Tests, nine:** `blackHoleGlows` joins them (Glow 0 leaves the sky over the hump black; Glow 1 lights it, has died away by the corner and darkens nothing), with `blackHoleStill`, which saves a still that comes out the same every time (`BLACKHOLE_STILL=<file.png>`, with `BLACKHOLE_DEFAULTS` and `BLACKHOLE_START`). The whole suite passes.

**Step (g), the stars' twinkle (2026-10-11).** Dave asked for it while testing the build (his words are under [Dave's feedback](#daves-feedback)). Each catalogue star swells and fades a little on a slow rhythm of its own, and a Twinkle slider under Sky sets how far: 0 to 1, 0.6 the default, 0 none. The Milky Way's glow is left as it was.
- **What a star does.** Its brightness follows the sum of two sine rhythms, each 3 to 8 seconds long and starting where it likes, so no star is regular for long: it can sit almost still for some seconds, then swing. The swing is in magnitudes and the same for every star: up to 0.87 of a magnitude either way at Twinkle 1 (2.2 times brighter or dimmer), 0.52 at the default (1.6 times), and under half of that most of the time. The scene draws a brighter star wider, so a bright star grows and shrinks at its rim, while a faint one only brightens and dims.
- **The star's own, not the pixel's.** The two rhythms are picked by the star's cell in the catalogue grid (the shared `hash42`). So a star keeps its rhythm wherever the lens puts it, and both of its images keep time. That is by construction; no star was followed through both images to check.
- **A matter of the app's clock only** (`WallpaperTime`), so it is the same at any frame rate. The shader gets that clock as one number going 0 to 1 every two minutes, and every rhythm is a whole number of beats to it (15 to 39): the number stays small, and nothing jumps when it comes round. The sky's twinkling as a whole repeats every two minutes.
- **Not true to life, and meant not to be.** Stars twinkle through air; seen from space, as here, they don't. It is there so the sky isn't a still photograph behind a turning disc.
- **The default, 0.6,** is the builder's judgement of "noticed, but not sparkle": in a 6 s film a typical star's peak moves over 29 of 255 (a fifth to a half of its own level), three stars in four over 20 or more, none faster than 3 of 255 in a frame at 15 fps. The app's other twinkles are shallower (Galaxy's stars ±14% over 2 to 10 s, the shared star field's ±25% over 2 to 6 s; this one is ±27% as a rule and up to 1.6 times). Dave only noticed this disc turning at four times the planned speed, so it leans to the strong side; the slider's top is 1.7 times it.
- **Twinkle 0 is the picture as it was, to the byte,** and a plain uniform gave that: no second shader source this time. (The twinkle is added to the star's brightness code, and nought added changes nothing; but that was checked, not assumed, after the glow's lesson.)

What was tried, on 8 s films of a patch of sky at 15 fps with the disc held still:
- **One rhythm a star, or two.** One is a steady breathing. Two give each star quiet spells and the odd deeper swing, with no more code. Kept two.
- **The swing as a share of the star's light, or in magnitudes.** As a share (±35% to ±50%), anything deeper takes a star to nothing at the bottom of its swing, where the picture steps (81 of 255 in a frame in the trial at ±100%). In magnitudes it is even both ways and can't reach nothing. Kept magnitudes.
- **Bright stars more than faint.** With the swing growing with brightness, the brightest winked out and back (one pixel stepped 174 of 255 in a frame), and the fainter ones moved less than they had. Dropped: with the same swing for all, the bright ones show it most anyway, because they change size.
- **A trace of colour,** the star's colour drifting toward white and back on its second rhythm. Where it measured at all, a star wandered over as much colour as separates one star from the next (0.074 against 0.084, red against blue), which is a star changing what it is; and on points 1.5 px across it couldn't be seen at three times life size. Dropped.
- **How quick.** Rhythms of 4 to 10 s, 3 to 8 s and 2 to 5 s. The slowest is the calmest and the least likely to be noticed. The quickest steps 13 of 255 in a frame at the slider's top. Kept 3 to 8 s.

Measured on the one kept, at 3024 × 1964:
- **Twinkle 0 against main:** the still from `blackHoleStill` is the same file as main's (`cmp`): four runs with the stars, one with Stars at 0. At the default the still differs, as it should, and comes out the same on every run (the still is of the clock's first moment).
- **How far a pixel steps in a frame from the twinkle alone,** at 15 fps over 64 frames with the disc held still (`blackHoleMoves`): at the default 0.41% of the picture changes in a frame, 99.9% of that by 4 of 255 or less, the most 5; at the slider's top 0.54%, 6 and 7. The bar was the disc's own, about 8. At 30 and 60 fps a step is a half and a quarter of that, since only the clock moves it; those weren't run.
- **What the stars do in a 6 s film of the wallpaper running** (209 stars in a 640 × 400 patch): at the default a star's peak moves over 29 of 255 at the median, a tenth of them over 37, the most 42; at the top 48, 61 and 68.
- **Looked at in motion:** the strips from `blackHoleMoves` (a patch every half second, with its change beside it) and frames a second apart from both films, at three times life size. Stars come and go singly and slowly; nothing flashes. Two films at 15 fps were made for whoever reviews it, at the default and at the top; they aren't in the repo.
- **Cost,** release build, three rounds turn about with main's commit: GPU 0.82–0.86 ms a frame on main at the default size and 0.84–0.90 at the other two; 0.87–0.94 with the twinkle, at any Twinkle and every size (the work is done whether or not the slider is up); CPU 0.5–0.7 either way. So about 0.06 ms. Seven textures and 17 other uniforms. If that is ever wanted back, the rhythms could come from the star's own bytes in the grid in place of the hash.
- **Tests:** `blackHoleTwinkles` joins them: with the disc held still, two pictures two seconds of the clock apart differ in their stars at the default and in no pixel at 0. That makes nine in the file (the counts above run one high). `blackHoleMoves` now runs the app's clock as it steps, and holds the stars still where it measures the glow being made again. They and `everySceneRenders` pass; the rest of the suite wasn't run, since nothing outside this wallpaper's two files changed.

**Step (h), the sky's drift (2026-10-12).** Dave, with the twinkle on his desktop, asked for the Milky Way's glow to move too, "as an option i can test" (his words are under [Dave's feedback](#daves-feedback)). A Drift slider under Sky does it: 0 to 4×, and 0 by default, since he doesn't yet know how it will look.
- **What moves, and why that.** The stars and the glow are one sky, so they go together. The honest way for a sky to move behind a black hole is for the camera to go slowly round the hole about the disc's axis, as anything out there would be doing: the disc looks the same from all the way round, and the whole sky pans across behind it, with stars passing behind the hole and being swept round its ring. In the shader that is one rotation of the direction the sky is looked up by, for the catalogue and the glow alike.
- **How fast.** At 1× the camera goes round as a body in orbit at its distance (40 radii) would while the disc turns at its own 1×: by Kepler, the inner edge's 45 seconds times (40/3)^1.5, which is 36.5 minutes. The top, 4×, is 9.1 minutes. It goes the way the gas does, so the sky passes from left to right: 9 px a second in the open sky at 1× on a 3,024 px screen, 36 at 4×.
- **What a turn brings.** The sky Dave picked (tile K's, the Milky Way to the upper right) is where it starts. Half a turn on, the Milky Way is behind the hole and is drawn out into a whole ring round it; a quarter turn either side of that there is only dark sky and stars.
- **Its own slider only.** Speed at 0 holds the disc but not the sky, as with Twinkle; Dave hasn't said whether it should hold both. Drift back at 0 holds the sky where it has got to. A scene built afresh (another wallpaper and back, a new disc colour, the 12-hour refresh) starts from tile K's sky again.
- **The clock.** The turn is summed frame by frame from the time each frame took, as the disc's is, so the same time gives the same turn at any frame rate and moving the slider never makes the sky jump. It is kept as a part of one turn, 0 to 1, and reaches the shader as a rotation, so nothing the shader sees grows.
- **A star is drawn as the streak it left in the frame.** In the open sky a star moves 0.6 px a frame at 1× and 15 fps, but near the ring the lens speeds the images up without limit: at 1× they crossed 8 px a frame there, and drawn as points they hopped, a band of sparkle round the ring that no slower top would have cured. So in a drifting sky each star is a short line from where it was last frame to where it is now, its light thinned to suit. Frames then join up at any speed and frame rate: at 60 fps the streaks are a quarter as long as at 15. In the open sky they are too short to see at 1× (0.6 px) and little dashes at 4× and 15 fps (2.5 px); at the ring they are long thin arcs, which is what a camera would record.
- **The Milky Way's picture has a join, and it had to be mended.** The picture's two ends are the same line on the sky and don't quite match: a step of 4 of 255, grey on one side and mauve on the other. It never showed, because that line lay behind the camera; a drifting sky carries it across the screen once a turn, as an arc from top to bottom. In a drifting sky the shader takes half the difference between the two ends, at each height, off one side and adds it to the other, fading out over 11° from the join. Measured on stills with the join in view and the stars off: before, the picture stepped across the join (36 to 41 of 255 where it crossed dark sky); after, nothing along it stands more than 1.5 off its neighbours, which is what the dither's own pattern measures anywhere.
- **The poles don't come into the open sky.** The picture's poles are within 12° of straight up and straight down from the view all the way round a turn, far off the screen (its top is 19° up at 1×, 28° at 0.65×). They are on screen only where they always were: in the squeezed images at the shadow's edge, a few pixels wide.
- **Twinkle still belongs to the star:** its rhythm is picked by its cell in the catalogue, and the sky's turn comes before that.
- **Drift 0 is the picture as it was, to the byte, and a uniform couldn't give that.** With the turn given as a uniform that was no turn at all, three stills in four matched main's and the fourth (Size 0.65, Blue-white) had one pixel in six million a step off. So, as for the glow, there are two shader sources: a scene draws with the one main has, to the letter, until its sky first turns, and changes to the drifting one then. That change compiles a shader, once: 0.17 s the first time Drift leaves 0. No frame is lost over it.

Measured, at 3024 × 1964:
- **Drift 0 against main:** four stills from `blackHoleStill` are the same files as main's (`cmp`): Twinkle 0, the defaults, Size 1.5, and Size 0.65 in Blue-white; main's own first two were drawn twice.
- **From the drift alone, at the top of the slider and 15 fps** (disc and twinkle held; `blackHoleMoves`): in a 400 × 150 patch of open sky 12.6% of the pixels change in a frame, 185 of them by 80 of 255 or more, the most 223; over the hump, where the ring passes, 24.2%, 319 and 159. These are large because a star that moves gives up its pixels and takes new ones; they say where the motion is, not that anything flickers. What was looked for is in the strips: each streak begins where the last one ended, in the open sky and at the ring, and the trails of a 6 s film (the brightest each pixel got) are unbroken lines.
- **The same at any frame rate:** 4× at 60 fps steps as 1× at 15 fps does (0.63 px a frame in the open sky, and 4.8% of the patch changing in a frame, in both).
- **Looked at in motion:** the strips, the trails, six frames in a row at twice life size (the ring at 1× and 4×, the open sky at 4×), and frames 2 s apart of the whole screen at 4×, with the Milky Way coming round behind the hole. Films at 15 fps of the whole screen and of the ring, at 1× and at 4×, were made for whoever reviews it; they aren't in the repo.
- **Cost,** release build, three rounds turn about with main's commit: GPU 0.86–0.92 ms a frame on main at the three sizes; the same with Drift at 0 (it is the same shader); 0.92–0.98 while the sky drifts, at 1× and 4× alike. So about 0.06 ms, and only while it drifts. CPU 0.5–0.6 either way. The drifting shader has two more uniforms, 19 besides the seven textures, and reads the Milky Way's picture twice more a pixel for the join.
- **Tests:** `blackHoleDrifts` joins them, ten in the file: a turned sky is another picture, a whole turn further is the same one, and with the sky dark a turn changes no pixel by more than the last bit. They and `everySceneRenders` pass.

**Step (i), Size up to 3× (2026-10-12).** Dave found the range too short at 1.5× (his words are under [Dave's feedback](#daves-feedback)), so the slider runs 0.65× to 3× now: the field of view from 78° down to 20°. 1× is still the default, and a stored value carries over. Only the range was changed. At 3× the disc is wider than the screen, the shadow is 1,100 px across at Retina size, and all the sky in view lies inside the Einstein ring, a close-up nobody had looked at; this is what it looks like and measures, on stills at 2×, 2.5× and 3× at full Retina size and in all three colours at 3×.
- **The bending holds.** The shader's test pattern in this view at 3×, against a brute-force picture of the same from the prototype's tracer (960 × 600): 762 of 576,000 pixels differ, every one of them on the edge of a check, so edges are 0.010 px out on average (0.03 px at Retina width). At 1× it is 141 pixels and 0.004 px. The tables cover every ray whatever the field (a narrower field only leaves the far ones out), and `bendingTablesFollowTheRays` and `gpuKeepsTheTablesPrecision` pass as before; neither depends on Size.
- **No bands or steps in the disc or the bright ring.** At full size the streaks, the disc's edges and the bright ring round the shadow are smooth, and the fine grain (a pixel against its neighbours) is what it is at 1×, about 2 of 255.
- **The hairline at the shadow's very edge is stepped,** a one-pixel line with hard edges. It is so at every size, 1× included; but at 3× it stands 5 px clear of the bright ring where at 1× it is 1 px off it, and its steps are longer on the flatter curve, so it is easier to see. The fix is to soften the shadow's edge by how much of each pixel lies outside it. Not made here, since it changes the picture at 1× as well.
- **Stars stay points:** they are drawn in pixels, whatever the field. There are fewer in view and they are fainter, being images from inside the Einstein ring. The one or two that are pulled into dashes just over the bright ring are three times as long as at 1×, 30 to 80 px.
- **The Milky Way stays a smooth haze.** No pixels and no bands show, though one of its picture's pixels is 26 across on the screen at 3×: it was a glow without detail at 1× and is the same glow three times as large. In the sky Dave picked, little of it is in view this close.
- **Nothing in the disc was tied to 1×.** The streaks are set in the disc's own measure and fade by how many pixels they span, so they are as crisp at 3×; the glow's reach is in pixels, so against the larger disc it is a third as wide, as a lens's bloom would be; the dither is by the pixel.
- **It is a bright wallpaper at the top.** The whole picture's mean brightness is 0.14 at 1×, 0.18 at 1.5×, 0.23 at 2×, 0.29 at 2.5× and 0.34 at 3× in Orange; at 3× in White-gold it is 0.45 and in Blue-white 0.43, with a fifth of the screen near white.
- **Motion at 15 fps from the disc alone, at Speed 1,** over the whole picture for 4 s: the largest step of any pixel in a frame is 10 of 255 at 1×, 16 at 1.5× and 42 at 3×, and 99.9% of the pixels that change do so by 4, 5 and 7 or less. So at 3× the bar of 8 holds for all but 600 pixels a frame in six million (6 at 1.5×). At Speed 4 and Size 3 together it doesn't: the most is 85, and 99.9% is 23 or less; that corner of the two sliders is fast at 15 fps. `blackHoleMoves` at 3× (`BLACKHOLE_DEFAULTS="blackhole.size=3"`): 13 and 11 of 255 at most in its two crops that fall on the disc, 7 and 6 at 30 fps.
- **Twinkle at 0.6, at 3×:** the most 3 of 255 in a frame over the whole picture (5 at 1×). Stars are drawn in pixels, so only their number changes.
- **Drift at its top, at 3×:** the most 173 of 255 in a frame, 99.9% by 61 or less (245 and 128 at 1.5×). The sky crosses the screen three times as fast, so at 15 fps every star is a streak; and all of the sky in view is inside the Einstein ring, where images are swept round the hole more than across it.
- **A fresh glow on a dragged Size steps more,** now that a drag covers more: after 0.15 s of a 2 s drag across the whole range a pixel changes by 10 of 255 at most, 99.9% by 8 or less (5 and 3 over the old range).
- **Cost,** release build, three rounds: GPU 0.88 ms a frame at 1×, 0.89–0.92 at 1.5×, 0.90–0.93 at 2×, 0.91–0.95 at 2.5× and 0.92–0.99 at 3×; 0.98–1.02 at 3× with the sky drifting. CPU 0.45–0.6 throughout. Half the 2 ms bar.
- **The slider.** Its label reads 3.0× at the top and 0.7× at the bottom (one decimal, and 0.65 rounds up, as it did before). 1× now sits 15% of the way along and the old range is the first third, so the same change is a smaller movement of the hand than it was. The Settings preview is the desktop's own picture scaled to fill, so it shows what the desktop does. These are from the code and the stills: the Settings window wasn't opened.
- **Tests:** none named the range or 1.5. `blackHoleMoves` takes `BLACKHOLE_DEFAULTS` now, so it can be run at a size, and its dragged-Size step is the new range's. The ten and `everySceneRenders` pass.

## Dave's feedback
- **2026-10-11, the first build on his desktop:** "it looks cool but we should adjust speed slider, only when I had it at 4x did even really notice motion". He had picked a lap of the inner edge in 3 minutes from a mock-up's film, where it was plain to see; on the desktop, at the real size and with nothing else moving, it wasn't.
  - **Changed:** 1× is four times faster, a lap in 45 seconds, which is the speed he had it at. The slider still runs 0 to 4×, so it now reaches a lap in 11 seconds. A streak generation's life follows the disc's clock, so it is 58 seconds at 1× where it was 3 minutes 54.
  - **Checked at the new 1×** (`blackHoleMoves`): two frames 5 s apart differ by 28 of 255 on average over the disc (it was 9), 77% of its pixels by 8 or more; at 15 fps no pixel changes by more than 8 of 255 a frame, at 30 fps by more than 4; the handover between generations beats by 0.9% of the mean and 1.4% of the contrast.
  - **Checked at the new top, 4×,** in a 4 s film at 15 fps: a disc pixel changes by 1.8 of 255 a frame on average. 0.04% of pixels step by more than 15 in a frame, all at the inner edge left of the hole, where a bright knot's edge passes; each steps once and stays, so it is fast motion and not sparkle.
  - He had Size at its top (1.5×) and Milky Way at half while he tried it. Not asked for as defaults, so they stay.
- **2026-10-11, the glow:** "go with M for the glow". The mock-ups he chose from had a soft glow round the disc, a stand-in added to those pictures; the build had none, by the plan (NASA's has none, and one shader pass can't blur). A side agent pointed out that he may have liked it, so he was shown a sheet: mock-up tile H, the app as it was (L), and the app with a soft (M) and a strong (N) glow painted on. He picked M. `black-hole/glow.py` is that painting as numbers (the disc's own light blurred at 14 and 60 px on a 3024 px picture, 60% and 40%, added back at 0.45), for the build to be matched against. It is to have a Glow slider that goes down to none. **Built:** step (f) in [The build so far](#the-build-so-far).
- **2026-10-11, the sky, while testing the build with the glow in it:** "is it possible to add some 'twinkle' to the stars in black hole so the background image doesnt feel so static".
  - **Changed:** every star swells and fades on its own slow rhythm, with a Twinkle slider under Sky (0 to 1, 0.6 by default): step (g) in [The build so far](#the-build-so-far). The Milky Way's glow doesn't move.
- **2026-10-12, the sky again, with the twinkle in his build:** "yes make the milky way glow move too as an option i can test, i dont know how it will look".
  - **Changed:** a Drift slider under Sky, 0 by default, turns the whole sky, stars and Milky Way together, by taking the camera slowly round the hole: step (h) in [The build so far](#the-build-so-far). For him to try and judge.
- **2026-10-12, the size:** "can we allow up to 3x size on black hole, the 1.5x is not enough range".
  - **Changed:** Size runs to 3×, a 20° field, with the disc wider than the screen. What the close-up looks like and measures is step (i) in [The build so far](#the-build-so-far).
  - **Once he had it on his desktop:** "i think it looks great at 3x, dont have any issues". So the top stays at 3×, and the things step (i) lists as wrong there (the brightness, the hairline at the shadow's edge, 1× sitting 15% along the slider) are not his complaints.
- **2026-10-11:** "proceed on your own until you have working versions of all 3" (this, Meander and the train).

### Still open
- **The glow is built (step f) and nobody has seen it on a desktop.** It was matched to tile M in stills and numbers by the agent that built it. Where it differs from M: it is the streaks' average and doesn't follow them, so it is 31% brighter than M at the left end of the one still M was made from, and the turning shows about a seventh less than under a glow made from each frame; it spreads the white-hot light that M's mask left out; it fades out where M's stops dead. If the disc looks too soft, Glow below 1 is the slider; making the glow follow the streaks (scaled by a pixel's own light over the average there) is the fix that wasn't built.
- **At Glow 1 the shadow's middle is 23 of 255, not black,** as in tile M (21). Dave picked M with that in it; whether he wants the shadow kept darker is his call.
- **The first glow of a run holds the main thread for 0.1–0.2 s** while its shader compiles: at launch, or on first switching to this wallpaper. Not measured in the running app, nor with a slider really dragged in Settings, nor on two displays.
- **Dave has seen it once** ("it looks cool", and the speed: above). Everything else in step (e) was judged against the mock-up tiles, NASA's frames and the review's numbers by the agent that built it. To meet those numbers the disc is crisp and has a white-hot side; "calm, soft, dim" may want Streaks below its 0.7 and Brightness below 1. The sliders are there.
- **The twinkle's default is a guess until Dave has watched it.** 0.6 was chosen from films and numbers by the agent that built it, to be noticed without sparkling; whether it is enough to stop the sky feeling static is for him to say. The slider's top is 1.7 times it. The glow of the Milky Way still doesn't move at all, which may be the larger part of "static".
- **The sky's drift is an option Dave asked to test, and its fate is his.** Off by default. If he keeps it, the builder's suggestion for a default is 2× (once round in 18 minutes, 18 px a second): 1× is true to the orbit but may be too slow for him to notice, as the disc was. Still to settle with him: whether Speed at 0 should hold the sky too, whether Drift at 0 should take the sky back to tile K's or hold it where it is (it holds), and whether the bare stretches of a turn, with the Milky Way out of sight, are wanted.
- **At 15 fps and the top of the slider every star is a dash** (2.5 px in the open sky, long arcs at the ring). That is the price of joined-up motion at a low frame rate; at 60 fps they are a quarter of that. Nobody has watched it on a desktop.
- **Size 3× is sound in stills and numbers, and nobody has watched it on a desktop.** Nothing is blurred or banded up there, so the top was left at the 3× Dave asked for. What he may not like: it is a bright picture (a third of full on average, nearly a half in the white and blue discs); at 15 fps with Speed or Drift also at their tops it is fast and streaky; and the hairline at the shadow's edge is plainer (below).
- **The hairline at the shadow's edge is a stepped one-pixel line** at every size, plainest close up. Softening the shadow's edge would cure it and would change the 1× picture a little too; not done.
- **Stars read finer than tile K's.** They are points about 1.5 px across at Retina, the brightest a soft 8, where the mock-up's were blobs and dashes, so at a glance the sky looks emptier, though it holds the same 111,000 stars. The Stars slider goes to 2.
- **The disc's mean brightness wanders about ±5% over minutes** as knots come and go. It doesn't beat, but nobody has watched it for an hour.
- **Whether the turning is "plain to see" at 1×** is a number here (above), not yet somebody watching the desktop.
- **One or two stars at the Einstein ring are short dashes** in a still sky, as in the first motion check. In a drifting sky stars pass through there all the time and are streaks anyway.
- **Not done:** the Settings page's own screenshot and preview (`SETTINGS_SHOT` can't open a hidden wallpaper's page), an icon chosen on purpose (it has `circle.circle.fill`), the README's own entry and the site.

## Mock-ups
In `docs/black-hole/`. They were rendered by `bh.py`, a brute-force tracer written for the purpose: every ray is integrated (`d²x/dλ² = −1.5 h² x / r⁵`, which gives a light ray's exact path), so the bending in them is real, not painted. Its disc texture, bloom and tone curve are stand-ins.

**The sheets kept here are not quite the ones Dave chose from.** He saw sheets 1 and 2, and tile J of sheet 3, drawn over NASA's star map. That map can't be published in this repo (see [The sky](#the-sky)), so the copies here were rendered again over the sky he then picked, with nothing else changed. I had first committed the originals; a side agent caught it before anything was pushed, and those commits were rebuilt without them.
- `sheet1.jpg`: six looks (view A–C, colour D–E, framing F).
- `sheet2-sizes.jpg`: the size slider's range (G close, H medium, I small). A 14 s film of three speeds went with it (`python3 sheet2.py film`).
- `sheet3-sky.jpg`: tile K, ESO's glow with HYG's stars. Tile J, NASA's map beside it, isn't kept. The stars near the hole smear into dashes: that is the picture-of-the-sky shortcut, which the build doesn't take.
- **Credits for these pictures:** the Milky Way is ESO/S. Brunier's panorama (CC BY 4.0); the stars are drawn from the HYG catalogue v4.4 (CC BY-SA 4.0). As adaptations of HYG, the three sheets are under CC BY-SA 4.0, not the repo's MIT; so is `sheet4-app.jpg`, the app's own pictures beside them, which shows the same stars and Milky Way.
- To render them again: `sky_eso.py` builds the sky from the ESO panorama and HYG into `$BH_DATA` (raw float files); `sheet.py sheet1` and `sheet2.py stills` make the sheets into `$BH_OUT`. `exr2raw.swift` decodes an OpenEXR star map to the same raw form, which is how NASA's was tried.

## The prototype
`docs/black-hole/proto/`, by the method research agent: research scripts, not reviewed line by line. `bhlib.py` holds both tracers, the bake, the 8-bit packing, the disc's flux and redshift. What it showed, all in numpy:
- Tables against the brute-force tracer at 960 × 600: 152 of 576,000 pixels differ, all on edges of the test pattern. Tried at 15° to 88° and cameras 50 to 300 M out, with one pair of tables.
- Disc hit points within 0.013 r_s (0.4–0.9 px at 3024 wide); sky directions within 0.87 px (median 0.004).
- The tables were held to what SpriteKit offers: 8-bit RGBA, bilinear weights to 1/256, float32 set-up.
- Against a second, independent integrator (the look research's `schwarz.py`): every edge at 0°, 56°, 65° and 85° agrees to 0.003 shadow radii (`proto/nasa_check.py`). Against NASA's frames: inner edges and rings within 0.05; three faint outer edges miss by 0.05–0.08, which is the measurement's brightness threshold pulling a dim edge in, not the geometry.
- Beloborodov's closed form alone is not enough: within 0.1% for bends up to 105°, but 19–24% out at 165–180°, where the hump is, and it has no second image.
- Not verified: anything on a GPU.

## Sources
Method
- Eric Bruneton, "Real-time High-Quality Rendering of Non-Rotating Black Holes", 2020: https://arxiv.org/abs/2010.08735. Code, BSD-3-Clause: https://github.com/ebruneton/black_hole_shader. The table mappings: https://ebruneton.github.io/black_hole_shader/black_hole/functions.glsl.html
- Luminet 1979, "Image of a spherical black hole with thin accretion disk": https://ui.adsabs.harvard.edu/abs/1979A%26A....75..228L
- Page & Thorne 1974 (the disc's flux): https://ui.adsabs.harvard.edu/abs/1974ApJ...191..499P
- James, von Tunzelmann, Franklin & Thorne 2015, the Interstellar paper (a uniform 4,500 K disc, Doppler left out as "too lopsided"): https://arxiv.org/abs/1502.03808
- Beloborodov 2002: https://arxiv.org/abs/astro-ph/0201117
- Wyman, Sloan & Shirley 2013, analytic CIE curves: https://jcgt.org/published/0002/02/01/. The constants in `BlackBody` were typed from memory, not from the paper; `blackBodyKeepsToTheLocus` checks what they produce against six points of the Planckian locus (those six from memory of the standard table too), to 0.004.
- Ballesteros 2012, "New insights into black bodies" (a star's B−V to its temperature, for the stars' colours): https://arxiv.org/abs/1201.1809 (the formula came by way of `sky_eso.py`; the paper wasn't opened).
- Bardeen, Press & Teukolsky 1972 (inner orbit with spin): https://ui.adsabs.harvard.edu/abs/1972ApJ...178..347B
- Read only, nothing copied: rantonels/starless (GPL-3.0), https://github.com/rantonels/starless; oseiskar/black-hole (MIT), https://github.com/oseiskar/black-hole

Pictures and data
- NASA's black hole visualization, Jeremy Schnittman, 2019 (the acceptance numbers; public domain, credit NASA's Goddard Space Flight Center/Jeremy Schnittman): https://svs.gsfc.nasa.gov/13326. The 2024 version, over a Milky Way: https://svs.gsfc.nasa.gov/14576
- NASA SVS Deep Star Maps 2020 (mock-ups only): https://svs.gsfc.nasa.gov/4851. Gaia's licence: https://www.cosmos.esa.int/web/gaia-users/license
- ESO/S. Brunier, the Milky Way panorama, CC BY 4.0: https://www.eso.org/public/images/eso0932a/
- HYG v4.4, 119,614 stars, CC BY-SA 4.0: https://codeberg.org/astronexus/hyg
- Event Horizon Telescope images, CC BY 4.0 (the amber ramp): https://www.eso.org/public/images/eso1907a/, https://www.eso.org/public/images/eso2208-eht-mwa/
- Sagittarius A*'s flares circling in about an hour: https://www.aanda.org/10.1051/0004-6361/202347416
- Cygnus X-1 daily, if a live touch is ever wanted: https://swift.gsfc.nasa.gov/results/transients/CygX-1.lc.txt

Not checked: the black-body table in `bh.py` is from memory of Mitchell Charity's; several real holes' coordinates and values in the look research were from memory.
