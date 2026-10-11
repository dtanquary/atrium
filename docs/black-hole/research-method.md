# Black Hole: the method research

A research agent's report as it was sent on 2026-10-10, unedited, kept so its detail and sources aren't lost. The plan beside it is the summary and has Dave's decisions; where the two differ, the plan is later. `scratch/` was the session's temporary folder: the scripts and pictures worth keeping were copied into this folder, the rest (downloaded references, video clips) is gone and its source URLs are below.

1/8 Black Hole rendering: use two small tables that depend only on the metric, plus closed forms. It matches brute force, and it is cheap.

METHOD. A Schwarzschild ray stays in one plane and its shape depends on one number, the impact parameter. So two tables do all the bending: U(e, phi), the inverse radius along a ray from infinity (256x128), and phiA(e), the angle to its closest approach (1024x1). Per pixel that is 3 fetches and no integration. The disc and the sky enter only through angles worked out per pixel. This is Eric Bruneton's 2020 method (https://arxiv.org/abs/2010.08735; code BSD-3-Clause, https://github.com/ebruneton/black_hole_shader), cut down for a camera that stays far out.

VERIFIED BY RUNNING CODE (numpy, 8 more messages give detail):
- Tables against a brute-force tracer that knows nothing of them (RK4 in 3D per pixel): at 960x600, 152 of 576,000 pixels differ, all on edges of the test pattern. Tried at inclinations 15, 45, 60, 65, 75, 78, 80, 85, 88 degrees and cameras 50 to 300 M out.
- Disc hit point: within 0.013 r_s, which is 0.4 to 0.9 px at 3024 wide. (A 128x64 table gave up to 1.4 px.)
- Sky direction: as a shift on screen, median 0.004 px, worst 0.87 px.
- The tables were held to what SpriteKit offers: 8-bit RGBA, bilinear filtering with weights to 1/256, ray set-up in float32.
- One pair of tables served every view. Inclination, distance and field of view are uniforms, never a rebake.
- Bake took 0.2 s in numpy at half size. In Swift at launch I expect 10 to 30 ms (a guess). No data file and no Python script to ship.

NOT VERIFIED: GPU time (I could not build), and how exactly SpriteKit filters a packed table on the real GPU. Both are in the risks message.

CLOSED FORMS ALONE FALL SHORT. I measured Beloborodov's formula (ApJ 566 L85, https://arxiv.org/abs/astro-ph/0201117) for the disc's direct image: radius within 0.1% while the ray has bent through 105 degrees or less, 1.5% at 135, 5% at 150, 19 to 24% at 165 to 180. The far side of the disc arching over the hole, seen at 75 to 85 degrees, sits at up to 170. It also gives no second image and no photon ring.

FILES, all in scratch/blackhole/proto/
- bhlib.py: both tracers, the bake, the 8-bit packing, disc flux and redshift
- compare.py, checks.py, beloborodov.py, stars_check.py, panorama_check.py: the measurements quoted in these messages
- render.py: stills written the way the shader would work
- out/compare-reference.png, compare-tables.png, compare-difference.png: same plain shading from each tracer
- out/beauty-inc78-t0.png, beauty-inc78-t40000.png, beauty-inc30-t0.png, sheet.png: full pipeline. The look is NOT tuned; they only show the parts work.

FOR YOUR MOCK-UPS: bhlib.trace_tables does a 1512x982 still in about 4 s; trace_reference took 35 s at 960x600. I also put four downloaded source files in proto/downloads (they first landed in refs/ by mistake and I moved them out).

---

2/8 Black Hole: the maths the shader and the bake need for the bending, with table specs.

UNITS: Schwarzschild radius r_s = 2GM/c^2 = 1, so M = 1/2. Horizon r = 1, photon sphere 1.5, ISCO 3, critical impact parameter sqrt(27)/2 = 2.598. u = 1/r, e = 1/b, mu = 4/27.
RAY: (du/dphi)^2 = e^2 - u^2 (1 - u), so u'' = 1.5 u^2 - u (Bruneton eq. 8).

PER PIXEL. c = unit vector from hole to camera, d = the pixel's ray direction, n = disc normal, u_c = 1 / camera distance.
1. cosd = -dot(d, c); perp = d + cosd * c; sind = length(perp); y = perp / sind.
2. e = u_c * sqrt(1 - u_c) / sind (a static observer). Swallowed if e^2 > mu: that is the shadow's edge.
3. Angle the ray has already turned from infinity to the camera, closed form: phiC = asin(u_c / e) - 0.5 * ((2 e^2 - u_c^2) / sqrt(e^2 - u_c^2) - 2 e). First order in r_s; I measured its error under 1e-5 rad for cameras 30 r_s (60 M) or more out, at 1 to 35 degrees off axis.
4. phiA = table B at e (only if e^2 < mu).
5. alpha = mod(atan2(-dot(c, n), dot(y, n)), pi): where the disc plane cuts the ray's plane.
6. First crossing, on the way in: psi0 = phiC + alpha. Good if psi0 < phiA, or the ray is swallowed. u0 = table A at (e, psi0).
7. Second crossing, on the way out, mirrored about closest approach: s = 2 phiA - phiC - alpha; psi1 = mod(s, pi); k = floor(s / pi). Good if e^2 < mu, s > 0, psi1 < phiA. u1 = table A at (e, psi1). This one lookup holds the second image and every order of photon ring: the critical ray is inside the ISCO after 0.98 rad (measured), so each leg can meet the disc once only.
8. A hit if 1/r_out <= u <= 1/3. The point: (cos(t) c + sin(t) y) / u, with t = alpha for the first and alpha + k pi for the second.
9. Sky: phiInf = 2 phiA - phiC, direction = cos(phiInf) c + sin(phiInf) y.

TABLE A, 256x128, 131 KB. x = 1 / (1 + 6 e^2); y = phi / phiUb, phiUb = (1 + e^2) / (1/3 + 2 e^3). Those two mappings are Bruneton's (functions.glsl, BSD-3-Clause: keep his notice if ported). Stores min(u, 0.5) * 2. Each column is one RK4 run from u = 0, u' = e. Column x = 0 is just y; column x = 1 is 0.

TABLE B, 1024x1, 4 KB. x = 1 - 2 sqrt(-ln(1 - e^2/mu) / 50), which spreads out the logarithmic blow-up at the shadow's edge (his stretch, halved). Stores (phiA - pi/2) / 8. phiA = integral from 0 to uA of du / sqrt(e^2 - u^2 + u^3), with uA = 1/3 + (2/3) sin(asin(2 e^2/mu - 1) / 3) (Bruneton eq. 9). Put u = uA (1 - s^2) and the integrand turns smooth: 2 sqrt(uA) / sqrt(Q), Q = -(u^2 + (uA - 1) u + uA (uA - 1)), s from 0 to 1. I checked it against RK4 to 6 figures and against Darwin's strong-field log formula (agrees to 4e-4 at b/b_c - 1 = 1e-4).

8-BIT PACKING, since SKTexture(data:) is RGBA8 (CloudNoise and The Moon's terrain already pass raw data this way): hi = round(255 v), lo = round(255 (255 v - hi + 0.5)); in the shader v = hi + (lo - 0.5) / 255 after filtering. It is linear, so hardware bilinear filtering still interpolates it. Table A needs two bytes. Table B needs three (the same trick once more): with two, sky directions were off by 0.2 arcmin median.

Sample every table at (x (n - 1) + 0.5) / n. Bake both once in a static let, as CloudNoise.texture is.

---

3/8 Black Hole: the disc. All closed form once the tables give r; and one finding that matters for the look.

Given r = 1/u, e, and cosn = dot(cross(y, c), n), the cosine between the photon's angular momentum and the disc's spin:

REDSHIFT g = observed / emitted frequency = sqrt(1 - 1.5 u) / (1 - sqrt(u^3 / 2) * cosn / e). Doppler and gravity together, for gas on circular orbits, and right for every image order because the photon's angular momentum is conserved (Bruneton eq. 14; Luminet 1979 has it as 1 + z, https://ui.adsabs.harvard.edu/abs/1979A%26A....75..228L). Hand check: ISCO, edge-on, coming at you gives sqrt(2), as v = c/2 should.

TEMPERATURE T(r) = T_peak * F(r)^(1/4), F the Novikov-Thorne flux (Page & Thorne 1974, https://ui.adsabs.harvard.edu/abs/1974ApJ...191..499P). With x = sqrt(2 r): F ~ (x - sqrt6 + (sqrt3 / 2) ln((x + sqrt3)(sqrt6 - sqrt3) / ((x - sqrt3)(sqrt6 + sqrt3)))) / (x^5 (x^2 - 3)). Zero at the ISCO, so the inner edge fades by itself; peak at 9.55 M. I checked it against Page & Thorne's integral numerically: agrees to 2e-7. The coefficient is sqrt3/2; with sqrt3/3, which I half remembered from elsewhere, the profile is 35% out.

COLOUR AND BRIGHTNESS: a black body shifted by g is exactly a black body at g T. So T_obs = g * T(r); colour from a 256x1 table (Planck times the CIE curves; I used the Wyman, Sloan & Shirley 2013 analytic fit, https://jcgt.org/published/0002/02/01/), brightness = 1 / (exp(25924 / T_obs) - 1), Planck at 555 nm. One fetch and one exp.

LIMB DARKENING: cosine of the angle the light left at = g * sqrt(1 - cosn^2) / (e r); brightness times (3/7)(1 + 2 cos), Chandrasekhar's scattering atmosphere. Thickness: keep it thin and opaque, fade the opacity at the outer edge so stars show through. The second image goes behind the first, the sky behind both.

FINDING: physically right Doppler in visible light is brutal at warm temperatures. On the hottest ring, the approaching side over the receding side (measured, table tracer): at 78 degrees, 191x for a 4,500 K disc, 39x at 6,500 K, 8.6x at 12,000 K, 3.4x at 30,000 K; all colours together (g^4) 22x. At 30 degrees: 16x, 7x, 3.1x, 1.9x. out/beauty-inc78-t0.png shows it: one side lit, the other gone. Interstellar used a uniform 4,500 K black body and left the Doppler shift and its brightness change out, because the true picture was too lopsided (James et al. 2015, section 4.3, https://arxiv.org/abs/1502.03808). So: a Beaming slider, T_obs = T * mix(1, g, beaming), and expect the default to sit well under 1 unless the disc is hot.

ROTATION THAT NEVER WINDS UP: cut the disc into narrow rings, even in ln r (I used 9 per e-fold). Each ring turns rigidly at its own Kepler rate, sqrt(1 / (2 r^3)); a point takes the patterns of the two rings it lies between, mixed by where it sits. Neighbours slide past each other, nothing stretches, and unlike a two-phase flow map nothing pulses in time. Sample tileable noise in (turns, ln r) with whole numbers of repeats round the disc: 4 fetches of CloudNoise.texture, which the app already has. Stills at t = 0 and 40,000 keep the same character (out/sheet.png). I have NOT looked at it moving.

SPEED: the ISCO's period is 92.3 GM/c^3: 33 minutes for Sgr A* (4.3 million Suns), 34 days for M87* (computed). Kepler speed on screen is nearly flat with radius. For Galaxy's 3 to 4 pt/s with the ISCO about 150 pt out, the ISCO turns once in about 4.5 minutes, which is a 0.6-million-Sun hole in real time, 7 times Sgr A*.

SCHNITTMAN: NASA's page says only custom software, bright knots that shear into lanes, non-rotating hole. No texture or colour method is published there (https://svs.gsfc.nasa.gov/13326).

---

4/8 Black Hole: stars through the lens, the Milky Way, and glow.

NO STAR TEXTURE. For point stars to stay sharp, an equirect map needs 3024 * 360 / (degrees across the screen) pixels: 18,000 wide for a 60 degree view, 22,000 for 50. An 8k map is 134 MB as RGBA and still leaves stars 2 to 3 times soft.

INSTEAD: the catalogue as a grid, drawn with the lens's stretch in closed form.
- Bake stars.txt into a 1024x512 grid of 0.35 degree cells in the scene's frame, one star a cell: position in the cell (2 bytes), brightness, B-V. 2 MB in memory, nothing shipped. 63 of the 2,888 stars lose a shared cell to a brighter one.
- Per pixel: sky direction, then the 2x2 cells round it (4 fetches). For a star there, D = star - pixel direction, and its image is this far away on screen: (dot(D, eR) / kR, dot(D, eT) / kT), with eR = -sin(phiInf) c + cos(phiInf) y, eT = cross(c, y), kT = sin(phiInf) / sind, kR = d phiInf / d delta (one more table B fetch for the difference). Brightness times min(1 / |kR kT|, a cap): the real magnification.
- Checked: I solved for 68 star images directly by root-finding. The method drew them within 0.09 px (median, first image) and 0.13 px (second image, the one on the far side of the ring), as round points, at magnifications 0.01 to 7.4. Doubled stars and brightening near the Einstein ring come free. A glow map sampled by the same direction stretches into arcs, as it should.

THE CATALOGUE IS THIN. 2,888 stars is 0.07 per square degree: about 100 on screen at 50 degrees across. out/stars-only.png is nearly empty. It needs a faint layer: hashed stars in sky cells (hash42, as Galaxy does), their density following the Milky Way. A later step up is HYG, 119,614 real stars, CC BY-SA 4.0 (https://codeberg.org/astronexus/hyg), which the same grid holds.

MILKY WAY, three choices:
1. NASA SVS Deep Star Maps 2020 (https://svs.gsfc.nasa.gov/4851): exact equirect in celestial and galactic coordinates, with a Milky-Way-only layer that leaves the bright stars out. EXR: 4k 34.7 MB, 8k 131 MB, 16k 414 MB, up to 64k 3.7 GB. The page names no licence; credit is NASA/Goddard Space Flight Center Scientific Visualization Studio, and it is built from Gaia DR2. ESA's page, read today: "Gaia data are distributed under the CC BY-NC 3.0 IGO license" (https://www.cosmos.esa.int/web/gaia-users/license). Non-commercial is not in NOTICE's list. Dave's call; I would not.
2. ESO/S. Brunier's panorama (https://www.eso.org/public/images/eso0932a/, 6000x3000, CC BY 4.0, already credited in deep-photos.tsv). Two things I checked: the copy in Resources, deep-milky-way.heic, was cropped and feathered by the tour's prep.py, so it has a black frame and cannot wrap; a fresh copy is needed. And the original is not an exact galactic equirect: the best single shift (3.1, -2.0 degrees) puts only 30% of the catalogue's V < 4 stars within 0.12 degrees, fewer away from the centre. So it works blurred to a glow (1024x512, a few hundred KB, one new file the updater fetches once) but its stars cannot be lined up with the catalogue's.
3. No file: Live Sky's computed Milky Way (disc, bulge, noise, dust lane in galactic coordinates).
I used 2 as a glow in render.py.

GLOW. One SKShader pass cannot blur. Galaxy's stretch, asinh(20 lum) / asinh(240) on brightness with colour kept and highlights paling, costs nothing and render.py uses it unchanged: start there. For a true halo: draw the same shader at one eighth size offscreen (MoonBaker in TheMoon.swift already renders through SKRenderer and reads the pixels back), blur it on the CPU, hand it back as a texture. One more fetch a pixel, rebaked only when the view has moved. render.py does exactly this in numpy with two Gaussians. Interstellar convolved with a measured lens spread function (James et al., same paper).

---

5/8 Black Hole: spin (Kerr), what the camera can do, and the cost per pixel.

KERR: ship Schwarzschild, and I would not plan Kerr at all unless Dave asks for it.
- What spin changes on screen: the shadow shifts sideways and flattens on one side into a D, plain only for fast spin seen near edge-on (from memory of Bardeen 1973: at full spin, edge-on, it runs from -2 M to +7 M across instead of +-5.2 M; I did not re-derive that). The disc's inner edge moves in: 6 M with no spin, 4.23 M at a = 0.5, 3.83 M at 0.6, 2.32 M at 0.9, 1.24 M at 0.998 (I ran Bardeen, Press & Teukolsky's 1972 formula, https://ui.adsabs.harvard.edu/abs/1972ApJ...178..347B). So the dark gap between disc and photon ring closes and the disc gets hotter and more one-sided. The star field is dragged round.
- What it costs: Kerr rays do not stay in a plane, so a ray's fate is no longer one number and these small tables do not exist. Bruneton says the same and leaves it as future work (paper, sections 5 and 6). The fallback is a screen-sized map baked per view (hit radius, azimuth, g, sky direction for each pixel), rebaked whenever tilt or distance changes: my guess is 0.5 to 1.5 s of all cores per view, with softer edges and a different way to keep stars sharp. That gives up the free camera below.
- The pictures people know are mostly non-rotating anyway: Luminet 1979 and NASA's 2019 visualization (https://svs.gsfc.nasa.gov/13326). Interstellar's was slowed to a = 0.6 so the audience could read it (James et al. 2015).

CAMERA: with the table method every part of the view is a uniform. Inclination, distance (checked 50 to 300 M with the same tables), field of view, where the hole sits on screen, and which way the sky is turned can all change every frame at no cost. So:
- a slow drift that never cuts, and a new view on each load, with no dissolve between scenes (Galaxy's doubles the GPU for 90 s);
- orbiting the disc's axis is the same as turning the sky about that axis, since the disc is symmetric: one 3x3 matrix a frame. That is what makes stars slide round the Einstein ring, the liveliest thing a lens does.
Limits: the camera stays 60 M or more out (the closed form in step 3) and outside the disc; rays more than about 35 degrees off the hole are untested.

COST PER PIXEL (an estimate, not measured: I could not build)
- sky pixel, about 80% of the screen: 2 fetches of table B, 4 star cells, 1 glow map, 1 or 2 hash42 for faint stars; an atan2, an asin, about 250 arithmetic operations.
- disc pixel: 1 fetch of B, 2 of A; then per crossing 1 colour fetch, 4 noise fetches, an exp, a log, 3 square roots, an atan2; about 350 operations.
That is 8 to 14 fetches from small textures. Yardsticks from docs/README.md: Deep Space Tour does 9 to 18 fetches a pixel full screen for 0.23 to 0.85 ms; Galaxy computes about 18 noise lookups for 1.5 to 2.1 ms. My expectation is 0.6 to 1.2 ms of GPU. Bruneton measured 0.7 to 1.9 ms for his disc and 2.6 to 4.1 ms for his stars at 1080p on a GTX 960 (paper, table 1), but his star filter reads up to 9x9 texels and his disc is heavier.
- CPU: a handful of uniforms a frame, so about the 0.5 ms every shader scene costs.
- Uniforms: about 23 of the 30 allowed, 7 of them textures (rays, apsis, colour, star grid, glow map, noise, halo). If the texture count pinches, table B and the colour table can share one 1024x2 texture.
- Memory: 131 KB + 4 KB + 1 KB of tables, 2 MB star grid, 2 MB glow map, 264 KB noise.

---

6/8 Black Hole: the scene, following "Adding a scene" in Sources/CLAUDE.md, and the settings I would give it.

OUTLINE
1. One file, Sources/Atrium/BlackHole.swift: `@MainActor func blackHole(size:) -> SKScene` returning `final class BlackHole: SKScene`, built on Galaxy's pattern (a dictionary of knob uniforms, applySettings on UserDefaults.didChangeNotification, only the knobs the shader reads passed in). An entry in allScenes, which sorts itself; check the menu and Settings order. Welcome.swift puts it in the last mood group by itself. The icon needs choosing: none of the existing ones fits, and smallcircle.filled.circle is taken by Solar System Tour.
2. Everything in init, since the render test never calls didMove: the tables as static lets beside the scene (as CloudNoise.texture), the star grid from LiveSky.catalogue (already parsed, nonisolated static), the glow map, then one full-screen sprite with the shader.
3. No live services, no location, no network.
4. Motion in update(_:), summed in Double with the step capped at 0.5 s as Galaxy does: the disc's clock, the sky's turn, the tilt's drift. Elapsed time only, so 15, 30 and 60 fps look the same. SNAPSHOT_SECONDS moves it.
5. One look; it is dark by nature, like Nebula and Galaxy.
6. Measure with the render test at the largest disc and steepest tilt.
7. Look at the snapshot, and at frame strips (the thin rings are where shimmer would show).
8. docs/black-hole.md with every URL in these messages, a screenshot, the Settings preview.
Also owed: Bruneton's BSD-3 notice in NOTICE if his two mappings are ported (formulas, about ten lines); ESO's credit line if the glow file is added (a blackhole-credits.tsv beside it); a unit test of the tables against RK4, for which checks.py is the pattern.

SHADER GOTCHAS THAT BITE HERE: texture2D only inside main(), so write helpers that return table coordinates and do the fetches in main; no early return, so the shadow, disc and sky are nested branches; uniforms reach helpers as parameters; animate by the scene's own clock uniforms, not u_time. fwidth is available (Aurora uses it): use it to soften the photon ring where it is thinner than a pixel, as Bruneton's FilteredPulse does.

BUILD ORDER, each a commit: (a) tables and a debug uniform drawing compare.py's checks, pixel-matched to out/compare-reference.png (camera 100 M out, 40 degrees across, tilt 78 degrees, disc to 24 M); (b) disc physics; (c) stars and glow map; (d) motion, checked in strips; (e) the look pass against bh-look's references; (f) the baked halo, only if (e) says the stretch alone is not enough.

SETTINGS
- Colors, a PaletteChoice `blackhole.heat`, empty meaning Random: the disc's peak temperature, swatches taken from the black-body table (outer, middle, inner). Ember 3,500 K, Amber 4,500 K (Interstellar's), Gold 6,500 K, White 10,000 K, Blue 25,000 K (nearest to what real discs are: they peak in ultraviolet or X-rays, so their visible light is blue-white).
- Look: Brightness as exposure before the stretch (Galaxy's way), then gradeKnobs' contrast, saturation and hue; Beaming 0 to 1; Disc texture 0 to 1; Glow.
- View: a choice, Drifting (default) / Edge-on / Tilted / From above; Distance.
- Motion: Disc speed 0 to 4 (1 is an ISCO turn in about 4.5 minutes; the doc can say 0.14 is Sgr A* in real time), Sky drift 0 to 4 (0 holds the stars still).
- Sky: Stars (brightness), Milky Way (switch).
Not suggested: a spin knob (message 5), or a cycle timer (the drift replaces it).

---

7/8 Black Hole: risks and open questions, worst first.

RISKS
1. The look, not the maths. The geometry is settled; whether it is pretty is not. Crystals was cut with its physics right. My stills (out/sheet.png) are correct and nowhere near Nebula's bar: a thin, flat-lit disc reads as CG, and true Doppler leaves one side dark (message 3). This wants your mock-ups and bh-look's references before any Swift, and a Beaming default chosen by eye.
2. The sky is sparse. About 100 real stars on screen (message 4). A hashed faint layer fixes the count but is made up; a real Milky Way needs a file whose licence or geometry has a catch. Decide which before building the star path.
3. Thin rings will shimmer while the view drifts. At 25 pt per M the second photon ring is about 2 px wide and the third 0.1 px; out/beauty-inc78-zoom.png shows the ring already breaking into dots without filtering. It needs the fwidth treatment, and checking as frame strips at 15 fps as well as 60, per your motion rule. If it cannot be made calm, hold the tilt and distance still and let only the sky and disc move.
4. SpriteKit unknowns I could not test:
   a. Packed 8-bit tables under the real GPU's filter. I assumed weights of 1/256 and an unrounded result. If the GPU rounds the filtered value to 8 bits the packing fails. Fallback: fetch texel centres and mix by hand, 4 fetches in place of 1 for table A and 2 for B. Step (a) of the build order exists to find this out on day one.
   b. Seven textures in one shader. I did not find a scene with more than about six; the limit is unknown to me.
   c. About 23 uniforms against roughly 30.
5. GPU time is an estimate (0.6 to 1.2 ms). Measure after step (b), with the disc filling the screen.
6. The ring-by-ring rotation is untested in motion. The seams between rings may read as bands sliding at different speeds; ring count and noise scale are the knobs, and a two-phase flow map is the fallback at about the same cost.
7. Float32 at the shadow's edge: table B's coordinate takes ln(1 - e^2/mu), which loses digits there. My float32 run was fine as far as the second ring. fwidth across the jump in mod(s, pi) between ring orders will give a one-pixel seam unless clamped.
8. The star grid's pole. Equirect cells pinch at the poles and the 2x2 lookup clips stars there. I put the pole on the disc's axis, which a view from above looks straight along. Put the pole somewhere the camera never looks, or use cube faces if it shows.
9. Light-travel delay across the disc is ignored (Bruneton stores it; for a noise pattern it is only a fixed warp). Say so in the doc with a ponytail note.

OPEN QUESTIONS
- For Dave: true Doppler, or tamed, as the default? Which Milky Way: NASA's (exact, but built on Gaia's non-commercial data), ESO's as a blurred glow (CC BY 4.0, one new file), or computed with no file? Should the hole sit in front of a part of the real sky he would know (Orion, the galactic centre), or a new part each load?
- For you: is a halo wanted at all, once the stretch is in? Does the drift of tilt and distance survive risk 3?
- For bh-look: a peak temperature and Beaming value that match their best references, and whether those references show the disc's far side brighter above the hole than physics gives (many artist versions do).

WHAT I DID NOT DO: no Swift, no shader compiled, nothing in the repo touched. No frame strips. The Semerak 2015 and Poutanen 2020 closed forms (next message) were read about, not measured. HYG was not downloaded.

Correction to message 1: there are 8 messages in all, not 9.

---

8/8 Black Hole: prior art and sources, each with its licence and how I know it.

CODE
- Eric Bruneton, black_hole_shader. Paper: https://arxiv.org/abs/2010.08735 (read in full as PDF). Code: https://github.com/ebruneton/black_hole_shader, BSD-3-Clause (LICENSE file read). The functions file with the table mappings: https://ebruneton.github.io/black_hole_shader/black_hole/functions.glsl.html (source read). Reusable with his notice. His star cube maps are built from Gaia DR2 and Tycho-2 (550 GB of processing, his paper): not for us.
- rantonels/starless: https://github.com/rantonels/starless, GPL-3.0 (repo page). Read only, copy nothing. Python, full integration per pixel, black-body disc, redshift, Airy-disc bloom. My reference tracer uses the same textbook equation (acceleration -1.5 h^2 x / r^5), written from scratch.
- oseiskar/black-hole: https://github.com/oseiskar/black-hole, MIT for its own code (COPYRIGHT.md read). Integrates per pixel on the GPU with few steps, which it says over-bends light slightly; 30 fps at 1080p on a GTX 750 Ti. Its Milky Way image is CC BY-NC 2.0: not usable.
- Shadertoy black holes: unless an author says otherwise the default is CC BY-NC-SA 3.0. I have that from second-hand pages (e.g. https://godotshaders.com/shader/creation-by-silexars/), not from Shadertoy's own terms. Study only.

PAPERS (formulas are not copyrightable; cite them in the doc)
- James, von Tunzelmann, Franklin & Thorne 2015, "Gravitational lensing by spinning black holes in astrophysics, and in the movie Interstellar", Class. Quantum Grav. 32 065001: https://arxiv.org/abs/1502.03808 (arXiv copy CC BY-NC-SA 3.0; read through ar5iv, first 100,000 characters only). Disc at a uniform 4,500 K, Doppler left out, spin slowed to 0.6, lens flare by convolving with a measured spread function, point stars brightened by magnification.
- Luminet 1979, "Image of a spherical black hole with thin accretion disk", A&A 75, 228: https://ui.adsabs.harvard.edu/abs/1979A%26A....75..228L (cited from memory and through Bruneton; not re-read today).
- Page & Thorne 1974, ApJ 191, 499: https://ui.adsabs.harvard.edu/abs/1974ApJ...191..499P (formula from memory, then verified numerically against its own integral).
- Beloborodov 2002, ApJ 566, L85: https://arxiv.org/abs/astro-ph/0201117 (abstract read; accuracy measured by me, message 1).
- Better closed forms I did not test: Semerak 2015, ApJ 800, 77, https://arxiv.org/abs/1412.5650; Poutanen 2020, https://www.aanda.org/10.1051/0004-6361/202037471; and https://arxiv.org/abs/2403.18543, aimed at accretion discs. None covers the second image, as far as their abstracts say.
- Muller & Weiskopf 2010 (stars by a 4096x4096 lookup) and Muller & Frauendiener 2012 (disc by Jacobi elliptic functions, which GPUs lack): known to me only through Bruneton's related-work section.
- Bardeen, Press & Teukolsky 1972 (ISCO with spin): https://ui.adsabs.harvard.edu/abs/1972ApJ...178..347B.
- Wyman, Sloan & Shirley 2013, analytic CIE curves: https://jcgt.org/published/0002/02/01/ (fit constants from memory; check them against the paper before they go in Swift).

PICTURES AND DATA
- NASA's black hole visualization, Jeremy Schnittman, 2019: https://svs.gsfc.nasa.gov/13326. Credit "NASA's Goddard Space Flight Center/Jeremy Schnittman". NASA says its media "generally are not subject to copyright in the United States", with credit and no implied endorsement (https://www.nasa.gov/nasa-brand-center/images-and-media/).
- NASA SVS Deep Star Maps 2020: https://svs.gsfc.nasa.gov/4851. Gaia's licence: https://www.cosmos.esa.int/web/gaia-users/license (CC BY-NC 3.0 IGO, page text read).
- ESO/S. Brunier Milky Way panorama: https://www.eso.org/public/images/eso0932a/, CC BY 4.0 as deep-photos.tsv already records it (the image page itself only links ESO's usage terms).
- Yale Bright Star Catalogue: already in Resources/stars.txt, public domain per its header.
- HYG, 119,614 stars: https://codeberg.org/astronexus/hyg, CC BY-SA 4.0 (page read).

That is all eight. I am done unless you want something measured further: the obvious next ones are frame strips of the ring rotation, and the photon ring with fwidth-style filtering emulated in numpy.
