# Black Hole (planned, not built)

A black hole with a thin disc of glowing gas turning round it, in front of the real Milky Way, all of it bent by the hole's gravity: the far side of the disc lifts into a hump over the shadow, its underside shows as a ring below, the side turning toward us is brighter, and the stars behind slide and double round the edge. One shader, beside Nebula and Galaxy.

Dave picked the idea on 2026-10-10 from a brainstorm ([ideas.md](ideas.md)). That day it was researched by two agents and mocked up in three rounds, and he made the choices below. **Nothing is built: there is no Swift, and no shader has been compiled.** This page is the plan, the measurements to build against and their sources.

- **Mock-ups and prototypes:** `docs/black-hole/` (see [Mock-ups](#mock-ups) and [Prototype](#the-prototype)).
- **The two research reports in full:** [the method](black-hole/research-method.md) and [the look](black-hole/research-look.md), which has the reference list, eight real black holes' numbers and the palettes.
- **Next step:** build order step (a) below, which also settles the two things nobody could test without building.

## Dave's decisions (2026-10-10)
From mock-up sheets, each choice with a recommendation beside it.
- **View:** nearly edge on (84° from the disc's axis), the one view. He did not pick the tilted view, the view from above or a slow drift between them.
- **Disc colour:** three, as a setting: orange (the default, gas at about 3,300 K), white-gold (about 6,200 K) and blue-white (about 15,000 K). He did not pick jewel palettes.
- **Size:** a slider, starting at medium (the disc about half the screen's width; a 56° field in the mock-up).
- **Position:** centred.
- **Speed:** the disc's inner edge goes round every 3 minutes, "but speed should be adjustable in a setting".
- **Sky:** ESO's Milky Way photograph as the glow, with real catalogue stars as sharp points (sheet 3, tile K). He first picked NASA's star map, on my word that it was public domain. It isn't clear of restrictions: see [The sky](#the-sky).

Still his to decide, once there is something running: how lopsided the disc's brightness should be (see Beaming), and whether the streaks' look is right once they match NASA's.

## How it will work
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
- **Turning without winding up:** cut the disc into narrow rings, even in `ln r` (9 per e-fold in the prototype). Each ring turns rigidly at its own Kepler rate, `√(1/(2r³))`; a point takes the patterns of the two rings it lies between, mixed by where it sits. Neighbours slide past each other and nothing stretches. Tileable noise sampled in (turns, ln r) with whole repeats round the disc: 4 fetches of `CloudNoise.texture`. **Not yet looked at moving.**
- **Speed:** 1× is the inner edge round in 3 minutes (Dave). For scale, the inner orbit of Sagittarius A* takes 33 minutes (92.3 GM/c³ for 4.3 million Suns), so real time for it is 0.09×: a marked stop on the slider, not the default.
- **Streaks:** the mock-ups' texture is a placeholder, and it is the "vinyl record" the look research warns about: even concentric bands. NASA's are sheared arcs of uneven width that fork and fade.

### The sky
- **Stars as points, not a picture.** For stars to stay sharp a sky map would need to be about 18,000 pixels wide. The plan: bake the catalogue into a 1024 × 512 grid of cells, one star a cell (its place in the cell, brightness, colour), and per pixel look at the 2 × 2 cells round the ray's sky direction and draw each star with the lens's stretch in closed form, brightened by the real magnification (capped, so a star passing dead behind the hole doesn't flash). Checked against 68 star images solved directly: within 0.09 px (first image) and 0.13 px (the second image, on the far side of the ring).
- **Which stars.** The app's Yale catalogue (2,888 stars to V 5.5) puts only about 100 on screen. Dave's pick, tile K, used HYG v4.4: 119,614 real stars, **CC BY-SA 4.0**, which NOTICE's list of licences allows (it needs its credit in About, and the baked grid stays under the same licence).
- **The Milky Way.** ESO/S. Brunier's panorama, **CC BY 4.0**, already credited for Deep Space Tour. It needs a fresh copy (the one in `Resources`, `deep-milky-way.heic`, was cropped and feathered for the tour and can't wrap). It is not an exact galactic map: its stars can't be lined up with the catalogue's (the best single shift left only 30% of bright stars within 0.12°). So it is blurred to a glow, about 1024 × 512 and a few hundred KB, and the catalogue supplies the stars.
- **Why not NASA's.** NASA SVS's Deep Star Maps 2020 is the exact map, and the first two mock-up sheets used it. It is built from Gaia DR2, and ESA's licence page says "Gaia data are distributed under the CC BY-NC 3.0 IGO license". Non-commercial isn't among the licences this app accepts. I had told Dave it was public domain before checking; corrected the same day.

### Glow and stretch
One `SKShader` pass can't blur. Start with Galaxy's stretch (`asinh(20·lum)/asinh(240)` on brightness, colour kept) and dither. NASA's picture has no bloom at all: the shadow, and the gap between the photon ring and the disc, are exactly black. A baked halo (the shader drawn small offscreen, blurred on the CPU, handed back as a texture, as `MoonBaker` does) is only for later, if the stretch alone looks hard.

### Cost (estimated, not measured)
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
- **Motion:** Speed, 0 to 4×; 1× is the inner edge in 3 minutes.
- **Look:** Brightness (exposure before the stretch, Galaxy's way), then the shared grade knobs; Beaming 0–1; Streaks 0–1.
- **Sky:** star brightness, Milky Way brightness.
- Not planned: a view choice, a drift, spin (below), jewel palettes, a stars-only switch. Each was offered and not picked, or advised against.

## Deliberately left out
- **Spin (Kerr).** Rays round a spinning hole don't stay in a plane, so the small tables don't exist; it needs a screen-sized map baked per view and gives up the free size slider. NASA's and Luminet's pictures are of non-spinning holes.
- **Real black holes as a setting.** Mass changes only speed and temperature, so the famous ones give four pictures, not ten, and the two that have been photographed (M87*, Sgr A*) have hot thick flows that need a different renderer. A later idea. Notes on eight candidates are in the look research (see Sources).
- **Live data.** Cygnus X-1's X-ray state can be read daily (Swift/BAT, MAXI), but it is a change visible light wouldn't show.
- **Light-travel delay across the disc.** Ignored; for a noise pattern it is only a fixed warp.

## Risks, worst first
1. **The look.** The geometry is settled; whether it is pretty at "soft and dim" is not. Crystals was cut with its physics right. This picture's beauty is fine bright streaks on black. Compare a softened render with NASA's side by side before going far.
2. **Thin rings shimmering.** The second photon ring is about 2 px wide at Retina and the third 0.1 px. Use `fwidth` to soften where it is thinner than a pixel, and check frame strips at 15 fps as well as 60. With the view held still (Dave's pick) only the disc and sky move, which helps.
3. **SpriteKit unknowns**, which nobody could test without building: packed 8-bit tables under the real GPU's filter (if it rounds the filtered value to 8 bits, the packing fails; fall back to fetching texel centres and mixing by hand); seven textures in one shader; about 23 uniforms.
4. **GPU time** is an estimate.
5. **The ring-by-ring turning** hasn't been seen moving: seams between rings may read as bands. A two-phase flow map is the fallback.
6. **Float precision at the shadow's edge** (table B's coordinate takes `ln(1 − e²/μ)`).
7. **The star grid's pole** pinches: put it where the camera never looks.

## Build order
Each a commit; follow "Adding a scene" in `Sources/CLAUDE.md`. One file, `Sources/Atrium/BlackHole.swift`, on Galaxy's pattern; everything built in `init`; motion in `update(_:)` by elapsed time.
1. **(a) Tables**, with a debug uniform that draws the prototype's test pattern, matched pixel for pixel to `proto/out/compare-reference.png` (camera 100 M out, 40° across, 78°, disc to 24 M). This is where risk 3 is found out.
2. **(b) Disc physics.** Measure the GPU here, with the disc filling the screen.
3. **(c) Stars and the glow map.** Adds two resource files and their credits (`blackhole-credits.tsv`, About).
4. **(d) Motion**, checked in frame strips.
5. **(e) The look**, against NASA's frames and the mock-up tiles Dave picked (sheet 1 tiles A, D, E; sheet 2 tile H; sheet 3 tile K).
6. **(f) A baked halo**, only if (e) says the stretch isn't enough.
Also owed: Bruneton's BSD-3 notice in NOTICE (his two table mappings), a unit test of the tables against RK4 (`proto/checks.py` is the pattern), an icon, the README and site.

## Mock-ups
In `docs/black-hole/`. They were rendered by `bh.py`, a brute-force tracer written for the purpose: every ray is integrated (`d²x/dλ² = −1.5 h² x / r⁵`, which gives a light ray's exact path), so the bending in them is real, not painted. Its disc texture, bloom and tone curve are stand-ins.
- `sheet1.jpg`: six looks (view A–C, colour D–E, framing F), over NASA's star map.
- `sheet2-sizes.jpg`: the size slider's range (G close, H medium, I small). A 14 s film of three speeds went with it (`python3 sheet2.py film`).
- `sheet3-sky.jpg`: NASA's map (J) against ESO's glow with HYG's stars (K). In K the stars near the hole smear into dashes: that is the picture-of-the-sky shortcut, which the build doesn't take.
- To render them again: `sky_eso.py` builds K's sky from the ESO panorama and HYG; `sheet.py sheet1` and `sheet2.py stills` make the sheets. They read their data from `$BH_DATA` (the star maps, as raw float files; `exr2raw.swift` decodes NASA's).

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
- Wyman, Sloan & Shirley 2013, analytic CIE curves (check the constants against the paper before they go in Swift): https://jcgt.org/published/0002/02/01/
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
