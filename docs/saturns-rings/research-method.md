# Saturn's Rings: how to draw it (method research, 2026-11-18)

The idea, from [ideas.md](../ideas.md) on 2026-11-14: drifting just above the ring plane, thousands of fine bands, the planet's shadow lying across them, and a moon's ripple passing through, from Cassini's real measurements. One shader, in Black Hole's family. This report is the method. The look (reference pictures, real colours, palettes, image licences) is the other agent's.

**In short:** one full-screen `SKShader`, about 0.3 ms of GPU at 3024 × 1964 in a probe that draws the real ring profile, the planet, its shadow on the rings and the rings' shadow on the planet. That is a sixth of the budget, against 1.74 ms for Nebula run the same way. The band data is real and public: Cassini UVIS, RSS and VIMS occultation profiles of the rings' optical depth on the PDS Ring-Moon Systems Node. The two hard parts are not the cost. The first is aliasing, which the probe found first-hand: a summed table loses its precision in SpriteKit, and a table of averages by width (a 1-D mip chain by radius) fixes it. The second is that optical depth alone makes the lit B ring a flat, featureless tan. The lit face needs a real brightness profile as well, and that data is thinner on the ground.

Every figure and licence below is marked **checked**, with the page that says it, or **unchecked**. "Derived" means I worked it out from checked figures.

## 1. The numbers

**Saturn** (NSSDC fact sheet, **checked**: https://nssdc.gsfc.nasa.gov/planetary/factsheet/saturnfact.html):

| Quantity | Value |
|---|---|
| Equatorial radius (1 bar) | 60,268 km |
| Polar radius | 54,364 km |
| Flattening (derived) | 0.098, so the radius ratio is 1.1086 |
| GM | 37.931 × 10⁶ km³/s² |
| Rotation (System III) | 10.656 h |

**The rings**, from the Ring-Moon Systems Node's tables (**checked**: https://pds-rings.seti.org/saturn/saturn_tables.html):

| Feature | Radius (km) | Normal optical depth τ |
|---|---|---|
| D | 66,900–74,491 | 10⁻⁵–10⁻³ |
| C | 74,491–91,975 | 0.05–0.35 |
| B | 91,975–117,570 | 0.4–5 (median 3.6 in the central B ring) |
| Cassini Division | 117,500–122,050 | 0–0.2 |
| A | 122,050–136,770 | 0.4–1 |
| Encke gap | 133,423–133,745 (322 km wide) | 0 |
| Keeler gap | 136,487–136,522 (35 km wide; 42 km in PIA11654) | 0 |
| F | 139,826–140,612 (core 140,224) | 0.01–0.2 |

- **Thickness** (NSSDC rings fact sheet, **checked**: https://nssdc.gsfc.nasa.gov/planetary/factsheet/satringfact.html): C 5 m, B 5–10 m, Cassini Division 20 m, A 10–30 m. At any view above about 0.01° the rings are a plane of zero thickness.
- **Moons in gaps** (RMS tables, **checked**):
  - Pan: orbit at 133,584 km, 28 km across.
  - Daphnis: orbit at 136,504 km, 7.6 km across, inclined 0.0036°.
  - Daphnis's edge waves stand "between one-half to 1.5 kilometers tall" (**checked**: https://photojournal.jpl.nasa.gov/catalog/PIA11654).

**Orbits.** Derived from GM by Kepler, P = 2π√(r³/GM):

| Where | Radius (km) | Period | Speed |
|---|---|---|---|
| C ring, inner edge | 74,491 | 5.76 h | 22.6 km/s |
| C/B boundary | 91,975 | 7.90 h | 20.3 km/s |
| B ring, outer edge | 117,570 | 11.42 h | 18.0 km/s |
| Encke gap (Pan) | 133,584 | 13.84 h | 16.9 km/s |
| A ring, outer edge | 136,770 | 14.33 h | 16.7 km/s |
| F ring | 140,224 | 14.88 h | 16.4 km/s |
| Camera A (below) | 150,000 | 16.46 h | 15.9 km/s |

Neighbouring ringlets shear past each other at (3/2)Ω per km of radius. At the A ring that is 0.18 km/s per 1,000 km.

**The Sun now.**
- Saturn's equinox, when the Sun crossed the ring plane from north to south, was 6 May 2025 (**checked**: BAA, https://britastro.org/section_information_/saturn-uranus-and-neptune-section-overview/saturn-apparition-notes/saturn-2025-apparition-notes).
- JPL Horizons gives the sub-solar latitude on 2026-11-18 as −10.24° planetodetic. The research agent converted that to about **8.4° below the ring plane** (derived, not stated on any page). So the **south face is lit** now, and the north face is the unlit one.
- The Sun will rise to about 27° south at the 2032 solstice, then come back through the plane at the next equinox, around 2039 (unchecked).

## 2. The view: three set-ups

Units below: Saturn's centre is the origin and the ring plane is z = 0. The figures are the probe's (`rings.swift`, `views`).

Inside the rings, Saturn is enormous. From 150,000 km out it spans 47°, and from 126,000 km 57°. So "drifting just above the ring plane" always means either a big globe above a sheet of bands, or the globe just off to one side. The planet's shadow on the rings reaches R/sin B′ beyond the planet (derived). Today that is 415,000 km, past every ring, so **the shadow crosses the whole ring system in every season except within about a year of a solstice**: it is always available.

**A. Looking in, the planet rising.** `view-A.jpg`, and the unlit face in `view-A-unlit.jpg`.
- Camera at r = 150,000 km, 12,000 km above the lit face. It looks straight in toward Saturn, pitched 24° down, with a 74° horizontal field.
- The Sun is 140° round from the camera (behind the planet on one side).
- On screen:
  - The globe is a crescent at the top.
  - The rings sweep across the whole lower two-thirds as concentric arcs: the A ring and Encke gap nearest, the Cassini Division as a dark arc about a third of the way down, the B ring as a broad band, and the C ring and the inner gap as fine arcs by the planet.
  - The planet's shadow is a sharp-edged black wedge across the far rings, coming out of the globe.
- About 60% ring, 25% planet and shadow, 15% sky.
- Pixel scale: about 10 km a pixel at mid-screen and 5 km at the bottom edge, so the 10 km bands are just resolved near the bottom and blend beyond it.
- **The strongest picture**, and the one that best answers the brief.

**B. Along the orbit, bands to the horizon.** `view-B.jpg` and `view-B-unlit.jpg`.
- Camera at r = 126,000 km (the inner A ring), 4,000 km up. It looks 55° off the inward direction, nearly along the orbit, pitched 9° down, with a 70° field.
- The bands sweep from the near left round to a horizon two-thirds of the way up. The Cassini Division and the B ring's edge make a great curving lane, and the sky is above.
- The shadow lies across the far right of the horizon.
- The planet is just off the left edge of the frame. Yaw about 45° brings its limb in.
- Near the camera a pixel is about 1–2 km, so this is the view where a 1 km profile and the moon's waves would show.
- Most "drifting above", least planet.

**C. High over the B ring, looking down and in.** Camera at r = 112,000 km, 40,000 km up, pitched 38°, with a 66° field.
- Much more of the rings' face, with a big globe.
- The probe framed it badly: with the Sun at 150° the frame is mostly the planet's night side (`view-C.jpg`).
- Turning the Sun to 60–90° gives the classic Cassini picture of the shadow across the rings behind a lit globe.
- It is the least "just above the plane" of the three.

A camera lower than about 2,000 km collapses the rings into a thin wedge, and this is the aliasing worst case. Probe view B at its first framing (a 4,000 km height with the rings in shadow) showed only a sliver.

## 3. Drawing it in one shader (what the probe does)

The probe is about 120 lines of GLSL; the source is in `rings.swift`. Per pixel:

1. **The ray.** `d = normalize(u_rot · (x·tanX, y·tanY, 1))`, from a camera matrix and position.
2. **The ring plane.** `t = −c.z / d.z`, then `p = c + t·d` and `r = |p.xy|`. This takes 3 multiplies and one square root. A ring hit counts only if t > 0 and it lies before the planet.
3. **The planet.** Stretch z by 1.1086 and the oblate spheroid becomes a sphere. One quadratic gives the hit, and the normal is `(x, y, z·k²)`. Shading:
   - Minnaert, I ∝ μ₀^0.9 μ^−0.1, which gives the planet's soft limb.
   - Bands are latitude-only in the probe (see §8).
4. **The planet's shadow on the rings.** From p toward the Sun, in the same stretched space: the ray's closest approach to the centre, compared with R.
   - A smoothstep softens the edge over the penumbra. The Sun is 0.056° across at 9.5 AU, so the penumbra is about 100 km wide 100,000 km behind the limb (derived).
   - Cost: about 10 ALU, no fetch.
5. **The rings' shadow on the planet.** From the planet hit h toward the Sun: `ts = −h.z / s.z`, which gives a radius `rq` on the ring plane, then the rings' transmission there, `exp(−τ(rq)/μ₀)`. That is one filtered table read (2 fetches).
6. **The rings' light.** This is classical single scattering from a thin layer (Chandrasekhar's slab, as in Cuzzi et al. 1984; unchecked for this report), with μ = |d.z| and μ₀ = |s.z|:
   - **Lit face** (camera and Sun on the same side): `I/F = (ϖ₀P/4) · μ₀/(μ+μ₀) · (1 − e^{−τ(1/μ+1/μ₀)})`
   - **Unlit face:** `I/F = (ϖ₀P/4) · μ₀/(μ₀−μ) · (e^{−τ/μ₀} − e^{−τ/μ})`, which goes to `τ/μ` for thin rings. This is the real reason the unlit side looks so different: the B ring goes dark because it is too thick to pass light, while the C ring, the Cassini Division and the A ring glow (`view-A-unlit.jpg`).
   - **What shows through** (planet or stars behind): `e^{−τ/μ}`.
   - All three need only the mean of `e^{−τk}` over the pixel's footprint, for k = 1/μ, 1/μ₀ or their sum. That is why the table holds **exp(−τk) for 12 values of k** rather than τ.
   - Colour by region is a smoothstep in the probe. A real colour profile is in §5.
7. **Tone.** Exposure, then `1 − e^{−x}`, then display gamma, then ±½ LSB of dither. Galaxy's and Black Hole's asinh stretch would do as well.

**Not in the probe.** These cost little more:
- **Ringshine on the planet's night side.** It is real and well seen in Cassini frames. Without it the night side is a black disc, the "black hole" risk below. Its cost is one term per pixel: the rings' mean brightness as a function of the normal's latitude, about 10 ALU.
- **Saturnshine on the rings' unlit face.** About 10 ALU.
- **Real stars.** The probe's stars are screen-space hash stars, which are exact only while the camera translates without turning.

**Count.**

| Item | Lit face | Unlit face |
|---|---|---|
| Fetches, ring over planet (planet's ring shadow included) | 6 | 8 |
| ALU (estimate; the measured cost is what counts) | about 150 | about 150 |

**Uniforms:** the probe uses 10, against the limit of about 30:
- the table, start radius, camera position, camera matrix, Sun, lens, size, filter, `u_now` and exposure.

A full build would add about 8, for 18:
- a colour/brightness profile, the star grid, the Milky Way glow, two moon or wake terms, Speed's clock, brightness, and the face.

**Textures:**

| Texture | Size |
|---|---|
| The pyramid table | 8192 × 156, RGBA8: 5.1 MB |
| Colour profile | about 32 KB |
| Black Hole's star grid (`blackhole-stars.lzfse` baked to cells), optional | 8 MB |
| Black Hole's glow (`blackhole-glow.heic`), optional | 2 MB |

The big ones go through `sharedTexture`.

**Measured** (probe, `./rings <profile> time`, 120 frames after 10 to warm up, on this Mac; median GPU time per frame from `MTLCommandBuffer.gpuStart/EndTime`):

| Shader | GPU median | 10th–90th percentile |
|---|---|---|
| Nebula's own shader, copied from Shaders.swift | 1.74 ms | 1.73–2.01 ms |
| Rings, view A | 0.320 ms | 0.319–0.329 ms |
| Rings, view B | 0.270 ms | |
| Rings, view C | 0.308 ms | |
| Rings, without the footprint filter | 0.318 ms | |

The filter is free. The app's render test usually reads Nebula at about 1.6 ms, so the probe's clock runs about 10% high, if anything. Expect **0.35–0.5 ms in the app** with stars, glow and ringshine added. CPU is a shader scene's usual, about 0.5 ms, with a handful of uniforms set each frame.

## 4. Aliasing: the worst risk, and what the probe found

The bands are a 1-D function of radius, so the right filter is exact and cheap: the mean of the quantity over the pixel's radial footprint, `[u − w, u + w]`.
- `w = ½ · |(dfdx(u), dfdy(u))|` in table texels.
- The full gradient length is better than `fwidth`, which runs about 4/π high (Black Hole's note).
- The derivative is smooth everywhere the plane is hit. The planet's limb doesn't break it, because r is worked out for the plane on every pixel. Only the horizon line is singular, and there the footprint is enormous and the mean goes to the ring's average, which is right.

**The obvious method fails in SpriteKit.** I built it first: a prefix-sum table with C(r) = ∫ e^{−τk} dr, and the mean = (C(r+w) − C(r−w)) / 2w. Two attempts:
- **24-bit sums packed into RGBA8**, as Black Hole packs its tables (`crop-B.png`). Speckled black-and-white dashes along certain radii. They fall exactly where the high byte steps, because the filtered high channel comes back with too little precision. The sum's range of 0 to 8,192 texels magnifies a tiny channel error into a visible one, and it only fails to cancel where the two reads straddle a carry.
- **A 32-bit float texture through `SKMutableTexture(…128RGBAFloat)`** (`crop-B-float.png`). Regular ridges everywhere. The values come back about as coarse as half floats: at 4,096–8,192 a half float steps by 4.
- Black Hole's tables get away with packing because their values are smooth and their range is small.

**The fix that works: a radial pyramid** (`crop-B-pyr.png`, `view-B.jpg`, clean). It is a 1-D mip chain by radius, with one row per level:
- Row (j, m) holds the mean of e^{−τ·2^j} over a box 2^m texels wide, centred on each texel. Every value is in 0…1, stored as two bytes.
- 12 values of k × 13 levels × 8,192 texels makes 156 rows (5.1 MB).
- The shader picks `m = log2(2w)`. Adjacent rows are adjacent levels, so the hardware blends levels for free, and the two rows of k round the pixel's own k are mixed by hand.
- That is **2 fetches per filtered quantity**, the same count as the prefix sums, and with no precision trap.
- Building it took well under a second in the probe (unoptimised Swift). In the app it would be baked at launch or shipped (§5).

**The frame strip.** `./rings <profile> strip A|B`: the camera drifts in at 300 km/s, much faster than the calm speed proposed in §7 (on purpose: a hard test), with 12 frames at each rate. The measure is the per-pixel temporal second difference, |f(t+1) − 2f(t) + f(t−1)|. Smooth motion keeps it small and crawling bands make it large. Green channel, 1 pixel in 16.

| View, rate | No footprint (w = ½ texel): 99th / 99.9th percentile | Footprint filter: 99th / 99.9th percentile |
|---|---|---|
| A, 15 fps | 57 / 150 | 30 / 107 |
| A, 30 fps | 27 / 97 | 20 / 53 |
| B, 15 fps | 81 / 163 | 73 / 143 |
| B, 30 fps | 39 / 111 | 31 / 85 |

- The filter halves the crawl in view A.
- Most of what remains is honest motion: sharp ring edges and the shadow's edge moving 2 px a frame at this speed, plus the probe's twinkling stars. View B's near field is resolved data moving several pixels a frame.
- **At the speed proposed for 1× (about 20 km/s) these motions are 15 times smaller.** That is under ⅓ px a frame at mid-screen and about 2 px/s at the bottom of view A, so a `batteryRate` of 15 should hold.
- Not yet done:
  - Watching it as a film.
  - Measuring against a supersampled reference.
  - Checking the dotting that `dfdx` can give across the 2 × 2 blocks at the planet's limb. Analytic derivatives of the ray–plane hit are the fallback: `dp/dx = t·(dd/dx − d·(dd_z/dx)/d_z)`, about 15 ALU.

**What could still shimmer:**
- The planet's limb and the shadow's edge: smoothstep them over a pixel.
- The horizon in low views, where the pyramid's top level is the ring's mean: fine.
- Anything non-radial: wakes and spokes (§6) need their own footprint, from the same derivatives.

## 5. The ring data

**The optical-depth profiles** (all on the PDS Ring-Moon Systems Node, all **checked** by the research agent from each volume's readme and index):

| Set | What | Profiles | Bin sizes | Size of one profile |
|---|---|---|---|---|
| **UVIS** stellar occultations, `COUVIS_8001` | Normal τ and photon counts, Oct 2004–Aug 2017 | 275 at 10 km (72 cover 74,000–140,000 km), 277 at 1 km | 1 and 10 km | 10 km: 0.2–3 MB text; 1 km: about 10 MB |
| **RSS** radio occultations, `CORSS_8001` | Normal τ, normalised power and phase, X/S/Ka band, Jun 2005–Sep 2010 | 204 at 10 km (86 cover 72,000–145,000 km) | `TAU_10KM` (sampled every 2.5 km), `TAU_01KM` (every 250 m), `DLP_500M` | 10 km: 5.2 MB; 1 km: about 50 MB |
| **VIMS** stellar occultations, `COVIMS_8001` | Normal τ at 2.9 µm, May 2005–Sep 2017 | 248 at 10 km (70 cover the main rings), 248 at 1 km | 1 and 10 km | 10 km: 0.25–1.1 MB; 1 km: about 4 MB |
| **Voyager** (fallback), `VG_2801` (PPS, δ Sco), `VG_2803` (RSS), `VG_2802` (UVS) | | | 0.1–50 km | 10 km PPS file: 72,000–142,500 km, 7,051 rows |

Readme and folder for each:
- UVIS: https://pds-rings.seti.org/holdings/volumes/COUVIS_8xxx/COUVIS_8001/
- RSS: https://pds-rings.seti.org/holdings/volumes/CORSS_8xxx/CORSS_8001/aareadme.txt
- VIMS: https://pds-rings.seti.org/holdings/volumes/COVIMS_8xxx/COVIMS_8001/
- Voyager PPS label: https://pds-rings.seti.org/holdings/volumes/VG_28xx/VG_2801/EASYDATA/KM010/PS1P01.LBL

No PDS4 replacements exist for these. The PDS4 bundle list has image bundles and one UVIS solar-occultation set (**checked**: https://pds-rings.seti.org/pds4/bundles/).

**The probe used** `UVIS_HSP_2008_231_BETCEN_I_TAU10KM.TAB` (954 KB, 7,884 rows, 72,833–151,675 km; the star was 66.7° above the ring plane). It is saved in `scratchpad/probe/data/agent/`, and τ is the 5th column. Its values:

| Radius | τ |
|---|---|
| 75,000 km | 0.05 |
| 105,000 km | 4.1 (saturated; the column beside it gives the most the star could show) |
| 119,000 km | 0.08 |
| 125,000 km | 0.71 |
| 133,580 km | 0 |

**Cleaning the profile:**
1. Clamp τ to the column of the most τ the occultation could detect.
2. Zero the noise outside the rings: the probe left τ ≈ ±0.005 between 137,000 and 142,000 km, and at grazing angles it drew faint lines (`view-A.jpg`, bottom edge).
3. Keep the F ring.
4. Fill a 1 km profile's gaps from a second occultation.
5. A shallow-angle star like this one saturates the B ring's core. A steep, bright one does better there: β Cen, α Vir and the RSS profiles, where RSS goes to τ ≈ 5–6.

**How many samples.** The main rings span 66,000 km.
- At 4 km a sample that is 16,384 texels, the widest a Metal 2-D texture can be: a good compromise. View B's near field draws 1–2 km a pixel, so 1 km detail would only show there.
- 8,192 at 8 km is enough for views A and C.
- The pyramid for 16,384 × 12 k × 14 levels is 11 MB of RGBA8. It can be compressed as a resource (lzfse, as the star grid is) or baked at launch from a 64 KB τ profile in about 0.1 s off the main thread. Measure it.

**Brightness and colour: the gap.** The probe's lit B ring is flat tan (`view-A.jpg`, `view-B.jpg`): τ > 2 is opaque at every angle, so τ alone gives it no texture. Real lit-face images show strong banding there from the particles' albedo and how they pack.
- **Real I/F profiles** exist in Voyager's imaging set `VG_2810`: 2, 4, 10 and 20 km samples (about 185 KB at 10 km). The lit face is Voyager 2's, at 74,000–138,700 km, phase 47°, incidence 82°, emission 67°. Voyager 1's is the unlit face, at 74,000–140,600 km (**checked**: https://pds-rings.seti.org/holdings/volumes/VG_28xx/VG_2810/DATA/).
- Cassini VIMS lit and unlit spectral profiles in 20 km bins are published (Hedman et al. 2013, https://ar5iv.arxiv.org/html/1210.4727; EPSC-DPS2019-1167). They were not found on the node, so they are **unchecked** as data anyone can download.
- **Proposal:** ϖ₀P(α) per radius = Voyager 2's lit-face I/F divided by the slab model's prediction from Cassini's τ at Voyager's geometry. That is the particles' own brightness, one real 1-D albedo texture. The colour as a slow function of radius comes from the look research's measured colours. A colour profile at 100 km is ample: 660 samples, 1 fetch with hardware mipmaps.

**Licence.**
- **Checked:** NASA's Science Mission Directorate policy SPD-41a says "SMD scientific data should be released with a Creative Commons Zero license", and footnote 29 says "Mission data are released into the public domain" (https://science.nasa.gov/wp-content/uploads/2023/08/smd-information-policy-spd-41a.pdf).
- **Checked:** the Planetary Science Division's policy says archives "shall make scientific information publicly available without fee or restriction of use" (https://science.nasa.gov/wp-content/uploads/2023/05/PSDInformationDataManagementPolicy.pdf).
- **Checked:** JPL's notice for PDS data it supplied: "may be used by any person for any purpose without prior permission" (https://pds-geosciences.wustl.edu/jplcopyright.html). This covers JPL's own products only.
- **Unchecked:** neither pds.nasa.gov nor the Rings Node states a licence on the data pages themselves.

So: the ring profiles are NASA mission data, which NASA's own policy puts in the public domain (CC0). That clears them for the app, with a credit line in About: "Ring profiles: NASA/JPL/Univ. of Colorado (UVIS), PDS Ring-Moon Systems Node". The Voyager I/F set falls under the same policy.

## 6. The moon's ripple

What is real, and how big it is from these cameras:

- **Pan's wakes on the Encke gap's edges.**
  - The wavelength is λ ≈ 3π·Δr, where Δr is the distance in radius from the moon (Showalter et al. 1986, **checked**: https://zenodo.org/records/1253894). Pan is 161 km from each edge, so λ ≈ 1,520 km along the edge (derived).
  - The waves stand still in Pan's frame. Ring material flows through them at (3/2)Ω·Δr ≈ 110 km/h, one wavelength per orbit (derived).
  - The edges' radial wiggle is a few km. **Unchecked:** no amplitude was found on a page.
  - The wakes go on into the A ring as density streaks whose wavelength grows with Δr.
  - In view A, 1,520 km is about 150 px along the edge, but the wiggle is under a pixel. They would show only as a texture on the gap's edges, not as a ripple.
- **Daphnis in the Keeler gap.**
  - The edges are 17–18 km from it, so λ ≈ 165 km (derived).
  - Edge waves rise 0.5–1.5 km out of the plane (**checked**, PIA11654). At equinox they cast shadows tens of km long. Now, at 8.4°, about 10 km (derived).
  - Visible only in a close view (view B's near field, 1–2 km a pixel).
- **Density and bending waves.**
  - Janus 2:1 at 96,233 km (**checked**: https://www.nasa.gov/image-article/staggering-structure/), Mimas 5:3 density wave at 132,301 km and bending wave at 131,902 km (**checked**: arXiv 1004.1400 and 2402.15456).
  - They are already in the 1 km profiles, as trains of fine bands tightening outward. They are "thousands of fine bands" for free, but they don't visibly move.
- **Propellers.**
  - The moonlets are 40–120 m across (Tiscareno et al. 2006, **checked**: https://www.astro.umd.edu/~dcr/reprints/tiscareno_nature440,648.pdf).
  - The giant ones (Blériot and others) are a few km to tens of km long. Unchecked.
  - Sub-pixel from every view here.
- **Spokes** (not in the brief, but worth the look agent's attention).
  - Dark or bright radial smudges on the B ring, thousands of km long. They form near the synchronous orbit (about 112,000 km, derived from the 10.66 h rotation), turn with the planet's magnetic field, and come and go in hours.
  - They are seasonal and strongest near equinox, which is now (unchecked).
  - Of everything real here they are the one thing that visibly moves across the bands at a calm pace.

**How a ripple would be drawn.** It is a perturbation of r before the table read:
- r′ = r + A(Δr)·e^{−φ/φ_d}·sin(2π·φ·r_m/λ(Δr)). Here φ is the angle downstream of the moon, a phase that grows with the shear, and the amplitude decays downstream.
- Cost: about 20 ALU and no fetch. Its own footprint must fade it out where the wavelength drops below 2 px, as Black Hole fades fine streaks.
- A vertical edge wave adds its own shadow: one more shifted table read, 2 fetches, only near the gap.

**How often it can pass.** In a camera that holds still relative to the Sun, which keeps the shadow fixed, Pan comes round once per orbit (13.8 h real) and Daphnis once per 14.3 h. At 10× that is every 80–85 minutes, crossing a view in about 4 minutes. A camera on its own Kepler orbit sees Pan only once every 150 h (from 126,000 km, derived).

So "passing through" every few minutes means a clock 50–100× real, or a scene that starts each load with a moon somewhere upstream of the view.

**Recommendation:** Pan and its Encke-gap wake as the moon, at its real λ, with the edge amplitude exaggerated only as far as the look agent's references allow (a knob, standard 1 = real). And not as the scene's only motion (§7). If "real over made up" forbids the exaggeration, the ripple will read only in a view as close as B.

## 7. Motion

What really moves, and what each would look like:

- **Axisymmetric bands.** They never move in a camera that co-orbits with them, and they barely move in any camera. Only a radial drift slides them.
  - Proposal: a slow radial drift, in then out over the A, Cassini and B region, as a sine or a reflected walk.
  - **Speed 1× = 20 km/s** of drift. That is Cassini-like (the Grand Finale's ring-plane crossings were over 30 km/s; unchecked). It moves the near bands about 2 px/s at the bottom of view A and ½ px/s at mid-screen.
  - From the A ring's outer edge to the B ring's is 19,000 km, about 16 minutes at 1×.
- **The Sun round the planet.** For a camera on its own orbit, the Sun's direction turns once per orbit: 16.5 h at 150,000 km. The planet's phase and the shadow's place then walk round in real time.
  - At 1× real time that is a change no one sees and a different picture every hour. That is Night Sky's kind of "real", and it suits "variety without repetition".
  - Faster than about 10× it stops being calm, since the globe goes from full to crescent in under an hour.
  - **Proposal:** the lighting follows the camera's real orbit at real time by default.
- **The shadow.** It is fixed to the Sun. In a camera held still relative to the Sun it doesn't move at all. In one on its orbit it sweeps as above.
- **The planet's rotation.** 10.66 h, so features at its cloud tops move about 9.8 km/s at the equator (derived). It shows only with real features in the bands (§8).
- **Wakes and spokes.** Covered in §6.
- **Stars.** These are fixed for a camera that only translates. The camera's own turn as it orbits turns the sky once per orbit, 0.36° a minute at 150,000 km. That would need Black Hole's direction-based HYG grid in place of screen-space stars (8 MB plus 2 fetches); Black Hole's code does exactly this.

**Speed.** One clock: 0–4×, where 1× is the radial drift at 20 km/s plus wake and spoke phases at 10× real. The light keeps real time unless a separate knob says otherwise.

**batteryRate.** 15, from the 2-pixels-a-frame rule. `BatteryPaced` isn't needed.

## 8. Live or baked

- **Baked and shipped:** the τ profile (64 KB lzfse) and the albedo and colour profile. The pyramid is baked from them at launch.
- **Live, by date:** the Sun's elevation over the ring plane.
  - SkyMath.swift already has Saturn's orbital elements (`SkyMath.swift:81`). With the pole (IAU: RA 40.589°, Dec 83.537°; **unchecked** here) that gives B′ in a few lines, to within a tenth of a degree. Check it against Horizons' −10.24° planetodetic for 2026-11-18, which is −8.4° geocentric on the ring plane.
  - **The catch:** today's low Sun dims the lit face. The lit face's brightness goes as μ₀/(μ+μ₀), so at 8° against Cassini-era light it falls by a third to a half.
  - The unlit face is the more striking picture now: dark B ring, glowing A and C (`view-A-unlit.jpg`). Near the 2025 equinox Cassini-like frames are mostly unlit-side frames.
  - **Proposal:** a "Season" menu: Today (the real B′, with the face chosen to suit it), Lit face (Cassini 2006, B′ ≈ −20°), Unlit face. The exposure is set per pick so each sits at the same dimness. Taking the season from the date adds no risk: it is one uniform.
- **The real moons' positions:** Pan's and Daphnis's mean longitudes from JPL's elements (in SkyMath's way, two numbers each). It is only worth it if the view is chosen to look where the moon really is; otherwise it is noise.

## 9. The planet

- **Procedural** (probe): latitude bands from two sines, Minnaert limb darkening, and the rings' shadow. It is cheap (about 20 ALU) and reads as Saturn at this size: in view A the globe is 1,000–1,500 px across, mostly in shadow or crescent.
  - It needs the real band pattern: pale equatorial zone, darker belts, the bluer north in winter.
  - The rings' shadow across the globe is the thing that sells it, and it is already real.
- **A real map:**
  - Cassini's global colour maps of Saturn exist: PIA20513, "maps of Saturn, 2016", and others. Their **licence is unchecked**: NASA/JPL-Caltech/SSI images are normally public domain under NASA's media guidelines (https://www.nasa.gov/nasa-brand-center/images-and-media/, **checked** for NASA images in general, not for this one).
  - A 4096 × 2048 map is about 2–4 MB HEIC and one fetch. The look agent should say whether the bands' real texture is worth it.
  - **My view:** start procedural, with the band colours sampled from a Cassini map, and add the map as a texture only if the globe is ever bigger than a crescent.

## 10. Different enough from Black Hole

**What the method guarantees:**
- **Reflected sunlight, not emission.** Brightness comes from τ, μ and μ₀, there is no glow, and the colour is neutral tan and grey, not black-body orange.
- **The bands are sharp, fine and concentric,** from real data with hundreds of distinct edges. Black Hole's disc is sheared noise knots.
- **There is a lit planet with a terminator, and two kinds of shadow,** straight-edged and soft-edged at once.
- **There is no lensing, no hump, no photon ring.**

**What could make it read as the same:**
- A dark night-side globe with a bright ring round it (view A at some angles).
- A warm palette.
- Any added glow.

To keep them apart:
- Keep ringshine on the night side.
- Keep the camera above the rings, where they read as a surface to the horizon. Never let the view slide to edge-on.
- Keep the colours to the measured neutral tans.

## 11. Risks, worst first

1. **The lit face is flat without a brightness profile.** τ alone saturates the B ring (`view-A.jpg`). Real I/F (Voyager `VG_2810`) has to work as an albedo profile, or the picture is one tan band with a few lines. This needs testing first.
2. **Aliasing.**
   - The prefix-sum method fails in SpriteKit (§4). The pyramid works in a still and halves crawl in a fast strip.
   - It is not yet seen as a film at the real speed, nor in the lowest views.
   - `dfdx`'s 2 × 2 dotting at the limb and the shadow's edge is untested.
3. **The moon's ripple won't read at real size** from any view that also shows the planet (§6). It needs a closer view, an exaggeration knob, or spokes standing in for it.
4. **Dimness at today's Sun angle** versus a lit Cassini-era look. That is a choice for Dave (§8), not a technical risk.
5. **The picture is mostly static.** Bands don't move unless the camera drifts, and the light turns in hours. Pair the drift with something non-axisymmetric (wakes, spokes) or it is a still.
6. **SpriteKit:** a 16,384-wide texture (Metal allows it; untested in SpriteKit) and an 11 MB pyramid's memory.
7. **The ring data's coverage:** saturation in the B ring's core, and gaps in 1 km profiles. Merge two occultations.

## 12. Build order and settings

1. **A still at the right dimness.**
   - View A on both faces, with the cleaned UVIS profile, the pyramid and Voyager's albedo.
   - Ringshine on the globe, and the stars and glow from Black Hole.
   - Hidden `unfinished`. Measure GPU and check against the look agent's reference frames.
2. **Motion.**
   - The radial drift, the real orbit's light, and Pan's wake.
   - Frame strips at 15 and 30 fps at the real speed, watched as films.
   - Fix the derivatives if dotting shows.
3. **Settings,** in the table below.
4. **Live data:** B′ from the date via SkyMath, and Pan's real longitude if the view looks for it.

Then the doc, the screenshots and the menu tile, as for any scene.

**Settings plan.** The prefix is **`saturn.`**:

| key | label | range | standard | drives |
|---|---|---|---|---|
| `saturn.view` | View | Looking in, Along the rings, From above | Looking in | the camera set-ups A, B, C |
| `saturn.season` | Season | Today, Lit face, Unlit face | Today | B′ and the face |
| `saturn.speed` | Speed | 0–4× | 1 | drift 20 km/s, wakes 10× real |
| `saturn.drift` | Drift | switch | on | radial drift in and out |
| `saturn.brightness` | Brightness | 0.4–1.6 | 1 | exposure |
| `saturn.ripple` | Ripple | 0–1 (real to ×10, if allowed) | real | Pan's wake amplitude |
| `saturn.stars` | Stars | 0–2 | 1 | the stars |
| `saturn.planet` | Planet | 0–1.5 | 1 | the globe's exposure, with ringshine |

**Settings left out:** a field-of-view slider (the views carry their own), and colour palettes (the colours are measured, so "Colours in one family" is the data's).

## The probe

All in `/private/tmp/claude-501/-Users-dave-Development-atrium/75eefa28-284c-41b6-be45-8a1ded042fde/scratchpad/probe/`. It is throwaway; `rings.swift` is the source.

Build and run: `swiftc -O rings.swift -o rings && ./rings data/agent/UVIS_HSP_2008_231_BETCEN_I_TAU10KM.TAB still|time|strip A,B,C`. The environment switches are:
- `FACE=unlit` for the unlit face.
- `PREFIX=1` for the failed prefix-sum table, with `FLOAT=1` for its float version.
- `FILTER=0` to turn the footprint off.
- `EXPOSURE=-1` for a debug picture of the table reads.
- `DRIFT=<Mm/s>` for the strip's speed.

The frames:
- `view-A.jpg`: looking in, lit face, the shadow across the far rings.
- `view-A-unlit.jpg`: the same from the unlit face, with the B ring dark.
- `view-B.jpg` and `view-B-unlit.jpg`: along the orbit to the horizon.
- `view-C.jpg`: from above, framed badly (mostly the night side).
- `crop-B.png`, `crop-B-float.png`, `crop-B-pyr.png`: the same patch with the packed prefix sums (dashes), float prefix sums (ridges) and the pyramid (clean).
- `strip-A-box-0.jpg`, `strip-A-point-0.jpg`, `strip-B-box-0.jpg`, `strip-B-point-0.jpg`: one frame each from the aliasing strips.
- `nebula.glsl`: Nebula's shader, copied from Shaders.swift for the timing.

The research agent's downloads and the pages it read are in `data/agent/`.
