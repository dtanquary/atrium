# Kelp Forest: the method research

A research agent's report, 2026-11-08, on how to draw an underwater kelp forest within the app's budget: the real thing in numbers, how it moves, how to draw it, what it costs (measured), and what to mock up. Nothing here is built.

**How to read the marks.** A key in brackets, like [JJN85], means the figure was checked against that source (list at the end). "[key, abstract]" or "[key, snippet]" means checked against an abstract or a search summary, not the full text. **Unchecked** means no source was found to state it. **Derived** means my arithmetic on checked figures; **estimate** means reasoning without a source. **Measured** means the probe below, on this Mac.

## Recommendation in ten lines
1. **Subject:** giant kelp, as it really is: clumps of 10–50 rope-thin stipes metres apart, blades every 4–13 cm, a float at each, sparse low down and a dense ruff high up, in green-teal coastal water of 8–12 m visibility (§1). Bull kelp as a second look.
2. **First view:** level through the forest, tipped up 10–20°, stipes rising into brighter haze with shafts between them. Second: looking up into the canopy and Snell's window (§4).
3. **Drawing, measured:** a hybrid. One water shader (fog by colour, rays, one soft caustic layer on the floor), 4–6 far slabs baked at each load and swayed by a displacement lookup, and 8–16 near fronds as real sprites: stipes bent by warp grids, blades as photo cards posed every frame. About 1.2 ms of GPU with marine snow, and 0.55–0.75 ms of CPU, the top of that for real blade spacing (§3).
4. **Not:** every blade worked out per pixel (4–9 ms for a whole forest), or a sprite per swaying frond (2.7–4.8 ms with the water). The mock-up's method is for pictures only (about 360 ms a frame).
5. **Motion:** a CPU chain per near frond (the literature's tethered buoy in segments) in water from a few swell components, a slow surf beat and a wandering current, at fixed substeps; far slabs sway by the same chain's response, worked out once at load (§2).
6. **Its character:** slack and dragged, never springy; nearly together across the view but rippling; small swell sway low, big slow lean high; blades streaming and fluttering by centimetres.
7. **Live:** the Sun's height for the light, and optionally the real swell at a named forest from Open-Meteo's marine feed.
8. **Fish:** a mid-distance school of blacksmith as small fogged cut-outs; garibaldi at most one and optional; no big animals.
9. **Battery:** no `batteryRate` (near motion is over 2 px a frame); a `batteryScale` on the water and slabs only.
10. **Biggest risks:** motion that reads fake, a forest that reads as bars, and amber-on-teal as two colour families (§6).

## 1. The real thing in numbers
### One giant kelp (*Macrocystis pyrifera*)
| | Value | Mark |
|---|---|---|
| Where | rock at 5–20 m usually [FS85, abstract]; to 30 m in California [GVB07 Table 1] | checked |
| Frond length | from 1–2 cm to over 40 m; the longest ≈ 1.4 × depth − 0.79 m [JJN85 Table 4] | checked |
| So, in 12 m of water | the longest frond is about 16 m, its last quarter (23–26%) lying on the surface | derived |
| Stipe | a rope about 0.5 cm thick [JJN85]; 3–8 mm, branching 3–6 times just above the holdfast [SAF] | checked |
| Fronds per plant | 2 to 100 [JJN85]; 25 on average in farmed adults [FS85]; up to 400 [GVB07] | checked |
| Stipes at 1 m off the floor, Channel Islands 2013 | site means 1.5–19.7 (median 9.5), single plants 1–55 [KFM13] | checked |
| Blades | over 100 a frond [JJN85]; 30–150 cm long, 5–15 cm wide, toothed 2–6 mm along the edge [SAF]; the largest, 300–400 cm², mid-frond, smaller toward the tip and the base [JJN85] | checked |
| Blade spacing | one per 16 cm on average; about 4 cm near the tip, 7 cm at the 20th blade, 13 cm from the 80th on (from [JJN85 Table 2]) | derived |
| Where the blades are | close-set in the canopy, sparse in the water column [SBCNPP]; most of the plant's mass is in its top 20–30% [FS85] | checked |
| Blade arrangement | split off one side of the frond ("unilaterally") [SAF]; a twisting frond carries them all round | first checked, second unchecked |
| Float (pneumatocyst) | one at each blade's base, elongate-ovoid to pear-shaped, 4–12 × 1–4 cm [SAF] | checked |
| Holdfast | a cone of root-like strands, 10–50 cm [SAF]; Channel Islands median 19 cm, largest 86 cm [KFM13] | checked |
| Growing tip | a broad sickle-shaped blade splitting off 8–20 young blades [SAF]; 15–30 cm long | first checked, length unchecked |
| Canopy mat | the top 1–2 m [GVB07]; harvests cut the top 1.2–1.3 m [MBA, SBCNPP] | checked |
| Growth, life | over 30 cm a day at peak [FS85], up to 60 [MBA]; a frond lives about 6 months [FS85], a plant 4–8 years [FS85, GVB07] | checked |
| Colour | medium to dark brown [SAF]; fucoxanthin, more protective pigment in surface blades [CP06, abstract] | checked |
| Colour as sRGB | lit from the front about `#6B5A24`–`#8A6D2C`; light coming through about `#C8962A`–`#E0B040`; stipe about `#4A3A1A` | unchecked: calibrate on the photos below |

What it means for drawing: blades are two to three times closer than the probe's 22 cm, so the near tier's sprite count doubles or triples (576 blades measured at 0.73 ms of CPU, so it holds). Low down a frond is mostly stipe with a few smaller, worn blades; high up it's a dense ruff.

### The forest
- **Density:** at most 0.3–0.61 plants a m² in Santa Barbara plots at 6–8 m [REED08]; adults thin to about 1 per 10 m² [GVB07]; about 10 fronds a m² at carrying capacity [GVB07].
- **Spacing:** 3–7 m between plants at 15 m (San Clemente Island), 10–50 cm at 3 m [GVB07 Fig. 2]. In deep forests "high stipe densities are aggregated around individual sporophytes that are widely spaced" [GVB07]. So a deep forest is clumps of 10–50 ropes metres apart, not an even field of poles (derived), which is the best defence against bars (§6).
- **Under it:** a subsurface canopy 1–2 m off the floor of *Pterygophora*, *Eisenia* and *Laminaria*, then foliose red algae and articulated and crustose coralline algae [CR; RF84, abstract]. The floor is rocky reef running out to sand, with red and purple urchins, bat stars, sunflower stars and spiny lobster [CR, FS85].

### Bull kelp and the others
- **Bull kelp** (*Nereocystis luetkeana*): one stipe about 8 mm thick and 10–36 m long [SPR10, RR, WPN] ending in a single round float up to 15 cm across, about 3 litres [SIMN, RR], carrying 30–64 blades (up to 100) up to 4 m long and 15 cm wide [SPR10, SIMN, PMCB]. Annual, at the surface by midsummer [SPR10]. Blades are wide and ruffled in calm water, flat straps where it's rough [SPR10]. North of Santa Cruz, and at exposed edges of giant kelp forests [CR].
- **Elk kelp** (*Pelagophycus porra*): one bulb and two blades up to 20 m long and a metre wide, in 18 m of water or more [FS85]. Dramatic, rarely seen.
- *Ecklonia radiata* is a 0.3–2 m kelp [SAFE]: an understory, not a forest to stand in.
- **Verdict:** giant kelp is the subject. Bull kelp is the second look: few bare whips, each a float with a tuft of streaming blades, a strong silhouette against Snell's window and cheaper to draw (opinion, unchecked).

### The water
- **Visibility:** Monterey typically 4.5–7.5 m, Carmel 6–14 m, 30 m on rare days [MSB]; the Channel Islands 18–30 m in summer and autumn by one dive guide [SDL] but 6–10 m on average [Ikelite, snippet]; a plankton bloom can take it to nothing [FS85]. Dive sites, not surveys. **Use 8–12 m, with 20–30 m as a clear-day setting** (unchecked synthesis).
- **Attenuation by colour**, Kd per metre, Jerlov's coastal types [JER, a transcription of his 1976 Table XXVII]:

  | Type | 450 nm | 500 | 550 | 600 | 650 |
  |---|---|---|---|---|---|
  | 1C (clearest) | 0.25 | 0.14 | 0.12 | 0.30 | 0.45 |
  | 3C | 0.39 | 0.22 | 0.19 | 0.33 | 0.46 |
  | 5C | 0.56 | 0.36 | 0.30 | 0.40 | 0.54 |

- **What's left of the light** (red/green/blue at 650/550/450 nm) in 3C water: at 2 m 40/68/46%, at 5 m 10/39/14%, at 10 m 1/15/2% (derived from [JER]). Red is gone by about 5 m; from there the light is green, not blue, in coastal water. In turbid coastal water green goes furthest, in clear water blue [FS85]. So California's kelp water is green-teal on most days, and blue only in the clearest (derived). Photos are white-balanced or strobed, so draw it as a camera shows it, not as the light is (unchecked; the mock does this).
- **The canopy's shade:** Macrocystis canopies can cut the light by over 90% [FS85]; at 15 m 0.2–2.5% of the surface's light under a canopy against 2–6% in the open [FS85, citing Reed & Foster 1984]; by season 39–92.5% at Mohawk Reef, where the forest's own Kd averaged 0.34–0.40 [MIL11]. Most is lost in the top metre [GER84, snippet]. So the floor under a full canopy is dim, and the open gaps are where the light comes down (derived).

### The light
- **Snell's window:** the whole sky squeezed into a cone 97° across [WPS] (the critical angle is 48.6°, derived), 2.27 × the depth across on the surface, about 23 m from 10 m (derived). Waves widen it to 97–122° [LYN15, snippet]. Outside it the surface is dark or mirrors the water below by total internal reflection, and the window's brightness falls to nothing at its edge [WPS].
- **Shafts of light** are caustic sheets made by the wavy surface: "more or less parallel", converging by perspective toward the refracted Sun and, looking away, toward the antisolar point [ATO]. Underwater the Sun is never more than 48.6° from overhead (derived). In kelp, the canopy's gaps make broad steady shafts and the waves shimmer thin sheets inside them (unchecked).
- **Caustics:** between 0.5 and 3 m deep the peaks pass 10× the mean; at 5 m the bright lines are 9 cm apart in a 3 m/s wind and 28–34 cm with swell or strong wind; by 20 m peaks are only 1.3–1.4× the mean, in open ocean [HM12]. In coastal water, about three times as murky, a clear net on sand to about 5 m, faint by 10 m, gone by about 15 m (unchecked, scaled from [HM12]). So on a floor 10–15 m down under a canopy they are faint and slow: one soft layer, not Fish Tank's crisp shallow net, which also saves 0.33 ms.

### Reference photos (public domain unless said; licences read on each Commons page)
NOAA's *Kelp forest, Channel Islands NMS.jpg* (looking up), Claire Fackler's NOAA Sanc0023, 0056, 0061, 0063 and 0091 (holdfast), *CINMS - Giant Kelp (29894800782).jpg*, Wheeler North's *Reuzekelp Californië.jpg*; *Bosque de macroalgas gigantes (Macrocystis pyrifera).jpg* (CC BY-SA 4.0, sunlight through the canopy); Chris Teague's *Nereocystis luetkeana1.jpg* (CC BY 4.0, bull kelp); Stef Maruch's *Kelp-forest-Monterey.jpg* (CC BY-SA 2.0, the aquarium). All on commons.wikimedia.org under those file names. Photo cards of single blades still have to be found (§6).

## 2. How kelp moves
The motion figures were gathered by a second helper agent; "meas" in its notes means field-measured, and I keep that apart from models below. Lag and blade-flutter frequency for giant kelp were *not* found measured anywhere open: they're marked as estimates.

### In wave surge
- **The sea:** Santa Cruz's forest had swell of 12–20 s with wind waves of 6–10 s, significant height 0.5–1.5 m, mean 0.77 m at 11.3 s [Rosman07]; Palos Verdes most often 0.6 m at 15 s, its energy peaking near 16 s [Elsmore24]. Orbital speeds of about 30 cm/s are routine [Gaylord07].
- **The water moves nearly as one column.** By linear wave theory (derived, per metre of wave height): at 10 m deep a 12 s swell swings the water ±0.86 m at the floor and ±0.99 m at the surface, peaking at 0.45 m/s on the floor; at 15 m deep ±0.66 and ±0.83 m; 8 s waves less, 16 s more. Its wavelength is 70–190 m and its crests run 7–12 m/s, so across a view 10–20 m wide the swing's timing shifts by 20–60° (derived). **The forest is never in lockstep**, but nearly.
- **The kelp barely damps it:** swell of 7–15 s isn't significantly damped inside a forest [Rosman07]; 7% of the energy over 180 m at Palos Verdes [Elsmore24]. The canopy does calm the wind ripples at the surface [Rosman07, by eye], so the canopy's patches look glassy.
- **A slower surge underneath.** Surf beat, long-period surge of 60–200 s, sends the water about 6 m each way where the swell sends it about 0.3 m (Otago, NZ, 3.4–5.9 m deep) [Mullarney17]; at Hopkins it peaked near 200 s under a 16 s swell [Denny97].
- **How the plant answers** (accelerometers on plants 2–4.7 m tall) [Mullarney17]: about 15° of tilt in the swell, about 50° in the slow surge; the swell tilts it most near the holdfast, the slow surge most near the top; the top sensor often tipped past 90°; upper blades longer than the swell's excursion stretch out only in the slow surge. The water's speed past a frond is rarely zero and often as large as the water's own [Stevens01, abstract]: a frond doesn't simply ride the water.
- **Slack, not springy.** Under linear waves plants are essentially never pulled taut; the waves' net drift (Stokes drift) does pull them taut (a 10 m bull kelp model) [Gaylord03]. A frond's buoyancy is about 2.49 N regardless of length [UD96, snippet], so a 15 m frond rights itself like an upside-down pendulum of about 27–58 s (estimate, unchecked), far slower than the swell: it is dragged by the water and settles back over a minute, it doesn't spring back each wave.
- **Bull kelp is livelier:** its estimated natural period, 13–26 s (unchecked), sits near the swell's; a strongly buoyant model float moved periodically like an inverted pendulum, a weakly buoyant one went slack and moved chaotically [Denny97]. Its stipe is unusually stretchy [KW77, abstract].
- **Lean of a stipe that goes with the water:** atan(excursion / depth) is about 4–11° on ordinary days, about 19° in storms (derived).

### In current, and between
- **Currents inside a forest are a third or less of outside** [Jackson & Winant 1983, via Gaylord07]: 0.5–1.5 cm/s in Mohawk Reef's interior [Gaylord07]; under 1–1.5 cm/s rms inside Palos Verdes against 3.2–6.1 outside, and 12% of outside once a surface canopy formed [Elsmore22]. Outside, 10–50 cm/s is common [Elsmore22, Gaylord03].
- **Stokes drift** adds 1.3–3.2 cm/s at the surface, 5–6 in big waves [Rosman07].
- **Lean:** up to 57° from vertical, over periods longer than 5 minutes; waves add to the mean lean [Daly26, abstract]. A model 12 m frond in 0.1 m/s stretches to about 16 m and leans 3.7 m off [StrongWright24].
- **Blades** stream out parallel with the flow, flutter like flags and clump together. Bull kelp's ruffled blades flap 2–16 cm, strap-like ones 1–2 cm at a higher frequency [Koehl08]. Frequency: about 0.3–2 Hz (estimate, unchecked, from a Strouhal number of 0.15–0.2 at 0.1–0.4 m/s).
- **So, three layers of motion** (synthesis): a small swell sway of 9–16 s, mostly low on the plant; a bigger, slower lean of 1–3 minutes, mostly high up; and a drifting mean lean with the current over many minutes. Blades stream with the water's speed *past* them and flutter by a few centimetres.

### How to model it
- **The water,** on the CPU: 4–6 swell components in a narrow band round the peak period (random phases each load, so the swell comes in sets and never repeats), 1–2 surf-beat components of 60–200 s, and a current that wanders over minutes. Real height and period from the marine feed if wanted (§3). Phases kept in Double. Cost: nothing.
- **Each near frond:** a chain of 12–16 nodes from the holdfast, each buoyant, dragged toward the water's velocity, links nearly inextensible, bending ignored. This is the multi-segment tethered buoy of the literature: Utter & Denny's single buoy [UD96] split into segments [Rosman13; StrongWright24, whose model ignores bending as 150 times smaller than tension]. Their fitted constants are a start: velocity exponent 1.6 and added mass 3 [UD96, as cited in Denny97]; drag coefficients 0.87 for blades and 1.0 for stipe [StrongWright24]. Fixed 60 Hz substeps, so 15–120 fps look the same; run a couple of minutes at load so it's settled, as the Fish Tank pre-runs its schools. Cost: about 16 × 16 nodes, a few microseconds (derived).
- **Each near blade:** its angle from the water's speed past its node (streaming when fast, floating up and out on its float when slack), eased with a lag of under a second (unchecked), plus a flutter of a few centimetres at 0.3–2 Hz scaled by that speed.
- **The far slabs:** run the same chain once at load under each component to get how much it sways and how late, by height (a transfer function), and let the shader sum the components for each slab, shifted across the screen by the wave's travel. Plants in one slab then sway alike, so add a slow variation of amplitude across it. Pixar's *Luca* did much the same for its sea grass: one shared noise field read at each blade's root, its tip reading it later by a "stiffness" [Pixar21].
- **Rejected:** a sine per stipe (lockstep, no lag, no sets); a spring that bounces back (wrong: dragged, 27–58 s to right); full 3D cloth for blades (cost, for nothing visible).

### What reads as fake
- The forest swaying in lockstep, or every plant at its own random phase: both wrong. Real: nearly together, rippling across the view.
- A bounce or spring-back each wave; plants pulled taut by ordinary swell.
- One rhythm. Real: swell, a slower surge under it, and a drifting lean.
- A stipe pivoting like a rod; the same tilt top to bottom.
- Blades as stiff cards, all alike, flapping by more than a few centimetres.
- Too fast. Monterey Bay Aquarium's surge machine plunges every 6 s ([WMBA], citing a book I didn't read), faster than wild swell's 9–16 s, so tank footage runs fast.

### Footage to judge it by
No wild giant- or bull-kelp video was found on Wikimedia Commons. Freely licensed: *Kelpforest_vert.webm* (63 s, Monterey Bay Aquarium's exhibit, CC BY-SA 4.0, Eric Polk), *Exhibits_at_Monterey_Bay_Aquarium_2_2017-11-21.webm* (10.8 s, the top of the exhibit and its surge machine, CC BY-SA 4.0), *Kelp1000.webm* (17 s, aquarium kelp with holdfast, CC BY-SA 4.0), NOAA Fisheries' b-roll "Kelp Forest, Sea Urchin Barren…" (4:26, public domain, though its slate lists third-party clips). NPS's Channel Islands live dives (about 20 min each) say not to presume public domain; a 46 s 4K clip of wild Macrocystis in swell and current (YouTube `xuNitr0vdXM`) is under a standard licence: watch and measure, don't reuse. Links in Sources.

## 3. How to draw it within budget

### Measured
A throwaway probe, `$TMPDIR/kelp/probe/main.swift` (not app code), drives SpriteKit's `SKRenderer` as the Jellyfish probe did: 3024×1964, GPU time from the command buffer's `gpuStartTime` and `gpuEndTime`, the median of 60 frames after 40 to warm up, run twice. CPU is each frame's wall time less its GPU time, so it includes SpriteKit's own update and encoding: the empty scene's 0.36–0.40 ms is that floor. This Mac is an M3 Max. **Calibration:** Nebula's own shader, copied from Shaders.swift, reads 1.49 ms here (the README's 1.6, the Jellyfish probe's 1.50). The water is drawn under every kelp variant but D, with the caustic layers each row says, so read the kelp's share as the difference; marine snow is under none of them, so add its 0.21 ms.

| Variant | GPU ms | CPU ms |
|---|---|---|
| Empty scene | 0.01 | 0.38–0.40 |
| Nebula (calibration) | 1.49 | 0.42 |
| **Water:** fog brighter upward, rays, the floor | 0.21 | 0.40 |
| the same with one layer of Fish Tank's Voronoi `caustic` on the floor | 0.56 | 0.43 |
| the same with two layers (Fish Tank's sand) | 0.89 | 0.42 |
| Marine snow, three hash-cell layers (the Jellyfish probe's) | 0.21 | 0.38 |
| **A. The whole forest procedural in one pass:** 4 depth layers (2 with blades), 3 fronds a plant, over two caustic layers | 4.11 | 0.48 |
| A, 6 layers | 5.27 | 0.51 |
| A, 8 layers (3 with blades), 4 fronds a plant | 7.61 | 0.55 |
| A, 8 layers, plants 1.2 m apart instead of 2.2 | 8.83 | 0.58 |
| A, one near layer with blades only (4 fronds × 3 cells × 3 blades a pixel), over one caustic layer | 1.75 | 0.44 |
| A, that layer cut down (2 cells, 3 fronds, 2 blades a pixel) | 1.23 | 0.43 |
| **B. Baked slabs:** 6 at half resolution, each swayed by a displacement lookup, over one caustic layer | 0.84 | 0.44 |
| B, the same over water with no caustics | 0.49 | 0.42 |
| B, 8 slabs (the 2 nearest at full resolution), over two caustic layers | 1.26 | 0.44 |
| **C. One sprite per frond, swayed in its shader**, 60 fronds (each 2.6× its strip's width, room to sway into), over two caustic layers | 2.67 | 0.54 |
| C, 150 fronds | 4.82 | 0.71 |
| **D. 150 frond sprites bent by `warpGeometry` set on the CPU every frame** (no water) | 0.89 | 0.61 |
| **E. Far layers procedural at half resolution** (an effect node, as `TrimNode`), 2 near layers at full | 3.52 | 0.48 |
| **G. The hybrid:** B's 6 slabs and one caustic layer, plus 16 near fronds as warped stipes and about 230 blade sprites posed on the CPU every frame | 0.89 | 0.49 |
| G, the blades sharing one lighting shader, one attribute per blade changed in place every frame | **0.99** | **0.55** |
| G, 32 near fronds (about 576 blades) | 1.10 | 0.73 |
| **H. Looking up:** Snell's window with refracted ripples, a canopy texture on the surface, rays (one full-screen shader) | 0.31 | 0.39 |

**The bake**, measured with CoreGraphics at half resolution (1768×982 with room to sway into): one far slab of plants × 8 fronds, each blade a rotated card, took 49 ms (864 blades at 5 m) to 71 ms (18,368 blades at 24 m). Five slabs are about 0.3 s on one core, or about 70 ms spread over five. A half-resolution slab is about 7 MB of RGBA8, six about 40 MB; a full-resolution one is 23.7 MB (derived).

What the numbers show:
- **Blades worked out per pixel are the cost.** Every pixel of a layer tests each frond within reach and two or three blades on each: 0.7–1.2 ms for one layer covering the screen. A whole forest done that way is two to four times the budget, and a half-resolution far forest doesn't save it (E).
- **Baked slabs are nearly free to draw**, about 0.05 ms each. Their cost is memory and the bake.
- **A sprite per frond costs by its area** (C), and a frond that sways needs a sprite wide enough to sway into: a near one is wider than the screen. The Jellyfish lesson ("area decides the cost") holds.
- **A sprite per blade is cheap at these counts.** Blades sharing one texture and one shader batch together, and 230 of them posed every frame (position, rotation, one attribute) added about 0.15 ms of CPU, 576 about 0.35 ms. Sources/CLAUDE.md's warning (cost is by the sprite and the property set) is real, but this is well inside it. The probe is an optimised build: debug CPU will read higher, as Jellyfish's 1.77 ms did.
- **The water is the dearest single part:** each Voronoi caustic layer is 0.33–0.35 ms.
- **A full ray march** wasn't measured: it would add marching to A's per-pixel blade tests, and A already fails.
- **The mock-up's method.** The parallel mock-up (`docs/kelp-forest/mock.swift`) hangs procedural blades along a spine inside one sprite per frond, Jellyfish's pattern. A copy taken at 18:55, while it was still being written, drew its standard frame in about **360 ms** of GPU (490 tipped up 60°), median of 40 frames: about 240 times the budget. That's fine for mock-ups and its look is promising, but the build should port its look, not its per-pixel blades, which cost as A and C do: by the area the near fronds cover.

### The options compared
1. **The hybrid (G). Recommended.** A full-screen water shader at the back, the far forest as 4–6 baked slabs swayed by a displacement lookup, and the near forest as real sprites: each stipe a sprite bent by a short warp grid, each blade a sprite of a photo card. About 1.2 ms of GPU with marine snow, and 0.55–0.75 ms of CPU, measured. Each tier moves the way it needs to: the far forest leans together, near blades stream and flip.
2. **Everything procedural in one shader (A).** The most freedom, measured at 4–9 ms. Out.
3. **A sprite per frond with blades in its shader (C, the mock's).** Right for judging looks in mock-ups; in the build, slabs do its job beyond 5 m for far less, and near fronds are too big for it.
4. **Frond sprites bent on the CPU (D).** True bending for a stipe, cheap on the GPU, but blades baked into the strip can't stream or flip, and a near frond's strip is a giant card. Use it for stipes only, as G does.
5. **Tree-style slabs of a 3D-baked plant (TreeGrowth).** The Tree's bake is the model for the far slabs: real scans as cards, lit once, sorted into depth slabs. Its sway (a cantilever bend in the shader) is what the slabs' displacement lookup is. Its sampler budget is the warning: 16 samplers, of which the Tree uses 15.
6. **A ray march through a 3D kelp field.** Not measured; dearer than A. Out.

### What is baked, what runs live
- **Baked at each load, a new forest each time:** where the plants stand and how many fronds each has, their heights, which blade card each blade uses, and the far slabs, drawn on the CPU off the main thread (as Rain on Glass's frost is), about 70 ms over five cores. Show the water first and fade the forest in, or bake before the first frame as Fish Tank's 0.47 s build does.
- **Live, on the CPU:** the sea's wave components (their phases kept in Double and passed as uniforms, so the shader never sees a large time), each near frond's chain, each near blade's angle.
- **Live, in the shaders, by `u_now` wrapped hourly where a jump can't be seen:** rays shimmering, caustics, marine snow.
- **Live data:** the Sun's height for the light and the rays' angle (already in the app); the real swell, height and period, from Open-Meteo's marine feed at a named kelp forest. The cut Sea Sparkle's research checked that feed: Scripps Pier, beside Point Loma's kelp forest, read 1.04 m at 12.0 s on 2026-11-08 (docs/sea-sparkle/research-method.md §6 in git at 1028d91, citing its [OMM]). One call an hour; CC BY 4.0 with "Weather data by Open-Meteo.com" (same source).

### Layered back to front (the level view)
1. **The water** (one full-screen shader; the soft part a `TrimNode` can draw at 0.5–0.75 on battery). Its colour along each ray from the light's attenuation by colour (§1), brighter toward the surface; the floor where the ray meets it, with one caustic layer whose contrast falls with depth and distance; the understory and floor's rock baked into a floor texture if wanted.
2. **The far forest:** 4–6 slabs from about 5 to 24 m, each fogged by its distance and swayed by the same wave model as the near fronds (§2). **Rays** belong between them, not on top: light scattered toward the eye in each gap between slabs, added before the next nearer slab is laid over, so nearer stipes cut the shafts as real ones do. That costs nothing extra in the one shader.
3. **Fish, optional** (below).
4. **The near forest:** 8–16 fronds, 2.5–7 m off. Each stipe a sprite bent by a 1×8 warp grid from its chain; each blade a sprite of one of 4–8 photo cards, sharing one shader: translucent amber when the light comes through it, olive-brown when lit from the viewer's side, its own veins and texture from the photo, a caustic flicker from two crossing waves (Fish Tank's `photoShader` trick, which it measured as reading the same as Voronoi on small moving shapes), fogged by distance. A blade bends along its length in its shader (the lookup shifted by a quadratic up the card), inside a sprite a little wider than the card.
5. **Marine snow** over everything, the near flakes larger and lit from above.

**Snell's window** isn't in a level view, by geometry: at 60° across, a level view's top edge is 20.6° up (30–40° tipped up 10–20°), and with 8–12 m of visibility the surface, about 9 m above the camera, is at or past the limit of sight unless looking up more than about 50° (derived; §1 has the window). A level view shows stipes rising into a brighter haze, which is what level photos of kelp forests show. The window, the canopy and the Sun belong to the looking-up views (H, 0.31 ms).

### Fish
Small and many, as the Fish Tank's lesson says. The kelp forest's own:
- **Blacksmith** (*Chromis punctipinnis*), a damselfish of 4–8 inches, up to a foot, blue-grey, schooling in open water above the floor to feed on plankton [RB, snippet]. A cousin of the Fish Tank's chromis. A school in the mid-distance is the Channel Islands' signature sight, and its colour sits inside the water's.
- **Señorita** (*Oxyjulis californica*), a cigar-shaped wrasse to 25 cm, yellow to orange-brown with a black spot at the tail [RS, snippet]: small, loose groups, low and near the kelp.
- **Garibaldi** (*Hypsypops rubicundus*) is bright orange (unchecked) and sits alone by the rock: one at most, low and fogged, behind a switch, or the forest stops being one colour family.
- **How:** Fish Tank's boids of photo cut-outs, fogged by distance, if there are freely licensed photos of blacksmith (iNaturalist and Commons, licences unchecked). Beyond about 8 m a school is dark slivers in the haze and could be shader-drawn instead.
- **Left out:** sea otters, sea lions and seals, sharks, giant sea bass, bat rays. Big animals are their bodies' motion, and the Fish Tank's whale sharks showed a flat photo can't carry it.

## 4. Views worth mocking up
Each with how hard it is and what it risks. The camera is 60° across unless said; at distance z the screen shows 1.155 z m across and 0.75 z m up (derived).

1. **Through the forest, level** ("the cathedral"). From about 3 m above a floor 10–15 m down, tipped up 10–20°: stipes rising out of the floor into a brighter blue-green haze, near fronds big and sharp, far ones soft silhouettes, shafts of light coming down between them, caustics on the floor in front. *Hardness:* the easiest, and exactly what the hybrid draws. *Risks:* a field of vertical lines reads as bars or a curtain, as Sea Sparkle's waves read as stripes; it needs the fronds' fan from the holdfast, their lean, blades breaking the verticals and real depth in the fog. Low down a frond carries few, small, worn blades [SBCNPP, JJN85], so the floor end is mostly bare rope; the understory's 1–2 m subcanopy fills it (§1).
2. **Looking up from the floor into the canopy.** Tipped up 50–80°: stipes converging toward the surface, the canopy's mat dark against the bright window of sky, the Sun in it, golden where light comes through blades, rays fanning down from it. The most famous kelp photograph. *Hardness:* medium. The surface is one cheap shader (H); the stipes can't be slabs, since each runs from near to far along its length, so they're projected 3D curves drawn as warped sprites with blade sprites, as the near fronds of view 1. *Risks:* the brightest view, against "soft and dim": the Sun in the window glitters as the surface refocuses it, and caustics on the canopy flicker. It needs a dim exposure, the Sun's glitter slowed and spread, or the Sun kept just outside the frame. Its look turns with the real Sun's height.
3. **An aquarium's kelp tank through acrylic**, after Monterey Bay Aquarium's Kelp Forest exhibit: 28 ft (8.5 m) tall, pumped at up to 2,000 gallons a minute, with a surge machine [MBAX]; about 320,000–343,000 gallons, sources differ [WMBA]; its kelp grows 3–5 inches a day against 10–12 in the bay [MBAX]. *Hardness:* medium: view 1 in a box, with a back wall, the tank's artificial surge from its wave machine, sardines circling, and the panel's frame or none. *Risks:* it overlaps the Fish Tank, and a tank's wall a few metres back caps the depth that makes the forest. Its strength is a bright Light Mode look, as Jellyfish's lit tank is to its glow.
4. **Just under the canopy.** Near the surface, looking along it: floating blades and floats close and golden, rocking as each swell passes, the surface a silver mirror above (beyond Snell's window it reflects the water below, §1), stipes dropping away into blue. *Hardness:* the hardest. Everything near is big, so the blades' fidelity is everything (photo cards are a must), and the surface from below (refraction, the mirror, the window's edge) is hard to make look real. *Risks:* a texture that slides, and brightness.
5. **Bull kelp instead of giant kelp** (as a look, not a view). One long stipe to a single float, its blades streaming from it like hair (§1): a stronger silhouette and more visible motion, the blades' streaming being most of it. *Hardness:* as view 1 or 2, fewer and simpler plants. *Risks:* a cooler, greener northern water; most of its motion is the blades, the near tier's job.

## 5. Cost, in short
- **The hybrid as recommended:** 0.99 ms of GPU and 0.55 ms of CPU with 16 near fronds and 230 blades (G), 1.10 and 0.73 with 576 blades, nearer real blade spacing (§1), plus 0.21 ms of marine snow: about **1.2 ms of GPU**, under Nebula's 1.5 and the Jellyfish build's 1.56. A second caustic layer adds 0.33, a school of fish perhaps 0.1–0.2 (unmeasured; Fish Tank's 38 fish and their shadows are part of its 1.3–1.5).
- **Looking up** is cheaper: 0.31 ms for the surface, window and canopy, plus the stipes converging toward it (sprites, as G).
- **No `batteryRate`.** Even a gentle sway, a near stipe 2.5 m off moving ±0.3 m on a 12 s swell (a calm day's water moves ±0.5–0.9 m, §2), moves about 0.16 m/s at its peak, about 330 device pixels a second at this camera, 16 a frame at 20 fps (derived), far over the 2 that can't be seen. A **`batteryScale`** on the water and slabs only (inside `TrimNode`, with the sprites outside it) is the saving that fits.
- **Memory:** about 40 MB of slabs at half resolution, plus the cards (4–8 blades at 512 px tall, about 1 MB).
- **Unmeasured:** smaller Apple GPUs, and a 6K display's 3.4 times the pixels, where the full-screen water scales and the sprites don't.

## 6. Risks, worst first
1. **The motion reads fake.** This is how the Fish Tank's big animals died. The traps, from §2: the whole forest swinging as one stiff sine; stipes pivoting like rods instead of bending; blades as stiff cards; everything too fast; the near and the far moving by different rules. Judge it first, from a film of one near frond beside freely licensed footage (§2), before any picture is polished.
2. **Bars, not a forest.** Many tall vertical stems on a screen read as a fence or stripes. Depth (fog by distance, size by perspective), each plant's fan of fronds, leaning stipes and blades across them have to break it up. It's the first thing to judge in the level view's mock-ups.
3. **Two colours, not one family.** Golden-brown kelp in blue-green water is amber against teal. In green coastal water both sit in one olive-to-teal family; in clear blue water they're complements. Mock both waters; keep the kelp dim and desaturated with distance, so gold appears only where light comes through a near blade.
4. **Near blades look drawn, not real.** The Fish Tank's first version was "way too cartoony" until photos replaced drawing. The near tier needs photo cards of real blades (pneumatocyst, wrinkled surface, ruffled edge) under a free licence; drawn ellipses won't do (the probe's crude ones show it).
5. **Bright isn't calm.** The Sun in Snell's window, caustics, glitter on the canopy and shimmering rays are all flicker. Keep the caustics slow and low in contrast, the window dim, and rays that drift rather than shimmer.
6. **Cost where it wasn't measured.** A smaller GPU, a 6K display (3.4× the pixels), a denser near forest, or a second caustic layer. The full-screen parts scale with pixels; keep `batteryScale` for them.
7. **Load time and memory.** About 0.3 s of CPU for the slabs and about 40 MB to hold them. Bake off the main thread and share the bake between displays of the same size, as the Tree does.
8. **Shader gotchas,** found or confirmed by the probe: `half` is a type in Metal, so a variable named `half` won't compile (the probe's first shader drew nothing, at 0.05 ms, until it was renamed); 16 samplers (six slabs, the floor and cards fit); about 30 uniforms (wave components as a few vec4s); no early return; `u_now` wrapped where a jump is harmless, and the wave phases passed from the CPU in Double.
9. **No battery rate** (§5), so it runs at the battery's full rate all day. Moving the nearest plant out to 5 m halves its speed on screen but still leaves it far over 2 px a frame, so it's a cost to accept, with `batteryScale` on the soft parts.

## Recommendation
Build the **level view through the forest** first, as the hybrid measured here: the water shader, half-resolution slabs baked at each load, and near fronds as warped stipes and blade sprites from real photo cards, moved by a chain simulation in a water model of swell, surf beat and current. Judge the motion before the look: a film of one near frond and a slab behind it, beside the freely licensed footage, at the real pace, before any picture is polished. Then mock the green and the clear-blue water side by side for the colour, and the looking-up view as the second look.

Before building, find 4–8 freely licensed photos of single giant kelp blades with their floats to cut out as cards (none were looked for yet), and decide with Dave whether the swell follows a real forest's live sea or a Surge slider. Knobs that fall out of the model: Surge (wave height), Current, Visibility, Water (green or clear), Fish, and the view.

## Sources
Morphology, forest and optics (gathered by a helper agent for this report; its marks are kept):
- [ATO] Atmospheric Optics, "Anticrepuscular whales?" (shafts as caustic sheets). https://atoptics.co.uk/blog/opod-anticrepuscular-whales/
- [CP06] Colombo-Pallotta et al. 2006, *J Phycol* (abstract). https://doi.org/10.1111/j.1529-8817.2006.00287.x
- [CR] Carr & Reed, "Shallow rocky reefs and kelp forests", *Ecosystems of California* ch. 17. https://www.tomwbell.net/uploads/5/6/9/7/56976837/carr_and_reed_ch17_ecosystems_of_california_compressed.pdf
- [FS85] Foster & Schiel 1985, *The Ecology of Giant Kelp Forests in California*, USFWS Biol. Rep. 85(7.2), public domain. https://archive.org/download/doi-report_i-4989-285-72/doi-report_i-4989-285-72_djvu.txt
- [GER84] Gerard 1984, *Mar Biol* 84:189 (abstract snippet). https://link.springer.com/article/10.1007/BF00393004
- [GVB07] Graham, Vásquez & Buschmann 2007, "Global ecology of the giant kelp *Macrocystis*", *OMBAR* 45:39. https://www.tomwbell.net/uploads/5/6/9/7/56976837/global_ecology_of_the_giant_kelp_macrocy.pdf
- [HM12] Hieronymi & Macke 2012, *Ocean Sci* 8:455, underwater light flicker (CC BY 3.0). https://os.copernicus.org/articles/8/455/2012/os-8-455-2012.pdf
- [Ikelite] Channel Islands visibility (search snippet only), ikelite.com.
- [JER] Jerlov 1976, *Marine Optics*, Table XXVII, as transcribed in the `jerlov` 1.1.1 Python package (`data/jerlov1976_kd.csv`). https://files.pythonhosted.org/packages/a8/9d/6079b0a3212b782bea9c66110d3a60a964e77ce94d4abcf0dcdcf4b0fcf4/jerlov-1.1.1.tar.gz
- [JJN85] Jackson, James & North 1985, *MEPS* 26:261, frond morphology. https://www.int-res.com/articles/meps/26/m026p261.pdf
- [KFM13] Channel Islands National Park, Kelp Forest Monitoring 2013 appendices (xlsx). https://irma.nps.gov/DataStore/DownloadFile/620107?Reference=2259603
- [LYN15] Lynch 2015, "Snell's window in wavy water", *Appl Opt* 54:B8 (snippet). https://doi.org/10.1364/AO.54.0000B8
- [MBA] Monterey Bay Aquarium, giant kelp. https://www.montereybayaquarium.org/animals/animals-a-to-z/giant-kelp
- [MIL11] Miller, Reed & Brzezinski 2011, *L&O* 56:119. https://sbclter.msi.ucsb.edu/external/eemb595p_wtr2011/2011-01-19/Miller_et_al_2011_LimnolOceano.pdf
- [MSB] Monterey Scuba Board, About Monterey diving. https://montereyscubaboard.com/about-monterey-diving/
- [PMCB] Juvenile bull kelp scaling (CC BY 4.0). https://pmc.ncbi.nlm.nih.gov/articles/PMC8363980/
- [RB] REEF, blacksmith (search snippet). https://www.reef.org/species/blacksmith
- [REED08] Reed et al. 2008, *Ecology* 89:2493. https://sbclter.msi.ucsb.edu/external/eemb595p_wtr2011/2011-01-19/Reed_et_al_2008_Ecology.pdf
- [RF84] Reed & Foster 1984, *Ecology* 65:937 (abstract). https://api.crossref.org/works/10.2307/1938066
- [RR] Race Rocks, *Nereocystis luetkeana*. https://racerocks.ca/nereocystis-luetkeana-bull-kelp/
- [RS] REEF, señorita (search snippet). https://www.reef.org/species/senorita
- [SAF] Flora of South Australia, *Macrocystis pyrifera* (Womersley). https://flora.sa.gov.au/taxon/60530-macrocystis-pyrifera
- [SAFE] Flora of South Australia, *Ecklonia radiata*. https://flora.sa.gov.au/taxon/60534-ecklonia-radiata
- [SBCNPP] SBC LTER, kelp net primary production protocol. https://sbclter.msi.ucsb.edu/external/Reef/Protocols/Kelp_NPP/KelpNPP_20180522.pdf
- [SDL] Scuba Diver Life, Southern Channel Islands kelp forests. https://scubadiverlife.com/diving-southern-channel-islands-kelp-forests/
- [SIMN] SIMoN, bull kelp. https://sanctuarysimon.org/dbtools/species-database/species-info-ajax.php?sID=75
- [SPR10] Springer et al. 2010, bull kelp management review, *OMBAR* 48. https://farallones.org/wp-content/uploads/2018/09/Ecosystem-Based-Management-of-Bull-Kelp.pdf
- [WPN] Wikipedia, *Nereocystis* (last resort). https://en.wikipedia.org/wiki/Nereocystis
- [WPS] Wikipedia, Snell's window (last resort). https://en.wikipedia.org/wiki/Snell%27s_window

Motion and footage (gathered by a second helper agent; its marks are kept):
- [Daly26] In situ giant kelp motion, *JGR Oceans* (abstract). https://doi.org/10.1029/2025JC023650
- [Denny97] Denny, Gaylord & Cowen 1997, Flow and flexibility II (bull kelp), *J Exp Biol*. https://www.gaylordlab.com/s/Denny_et_al_1997_JEB.pdf
- [Elsmore22] Elsmore et al. 2022, current reduction by giant kelp, *MEPS*. https://www.gaylordlab.com/s/Elsmore_et_al_2022_MEPS.pdf
- [Elsmore24] Elsmore et al. 2024, wave damping by giant kelp, *Annals of Botany*. https://www.gaylordlab.com/s/Elsmore_et_al_2024_Annals_Bot.pdf
- [Gaylord03] Gaylord et al. 2003, wave forces on kelp canopies, *L&O*. https://www.gaylordlab.com/s/gaylord_et_al_2003_LO.pdf
- [Gaylord07] Gaylord et al. 2007, flow in and around a giant kelp forest, *L&O*. https://www.gaylordlab.com/s/gaylord_et_al_2007_LO.pdf
- [Koehl08] Koehl et al. 2008, kelp blade shapes in flow. https://softmath.seas.harvard.edu/wp-content/uploads/2019/10/2008-10.pdf
- [KW77] Koehl & Wainwright 1977, *L&O* (abstract). https://doi.org/10.4319/lo.1977.22.6.1067
- [MBAX] Monterey Bay Aquarium, Kelp Forest exhibit (and its media kit). https://www.montereybayaquarium.org/visit/exhibits/kelp-forest
- [Mullarney17] Mullarney and co-authors 2017, giant kelp's response to swell and infragravity waves, Otago, NZ. https://researchcommons.waikato.ac.nz/bitstreams/d434ea17-74e2-4246-b309-73f64944d92f/download
- [Pixar21] Fecho et al., "Underwater procedural vegetation on Pixar's *Luca*", SIGGRAPH 2021 talk. https://history.siggraph.org/wp-content/uploads/2022/06/2021-Talks-Fecho_Underwater-Procedural-Vegetation-on-Pixars-Luca.pdf
- [Rosman07] Rosman et al. 2007, kelp forest hydrodynamics, *JGR*. https://cdr.lib.unc.edu/downloads/1544c0342
- [Rosman13] Rosman et al. 2013, *L&O* 58:790 (abstract; multi-segment model as described by StrongWright24). https://doi.org/10.4319/lo.2013.58.3.0790
- [Stevens01] Stevens et al. 2001, water motion relative to kelp fronds (abstract). https://figshare.com/articles/journal_contribution/Water_motion_relative_to_subtidal_kelp_fronds/22912577
- [StrongWright24] Strong-Wright and co-authors 2024, a multi-segment giant kelp model, *Flow* E21 (CC BY; its code, GiantKelpDynamics.jl on Zenodo, licence unchecked). https://doi.org/10.1017/flo.2024.13
- [UD96] Utter & Denny 1996, *J Exp Biol* (abstract; full text unreachable). https://pubmed.ncbi.nlm.nih.gov/9320580/
- [WMBA] Wikipedia, Monterey Bay Aquarium (last resort). https://en.wikipedia.org/wiki/Monterey_Bay_Aquarium
- Footage: https://commons.wikimedia.org/wiki/File:Kelpforest_vert.webm · https://commons.wikimedia.org/wiki/File:Exhibits_at_Monterey_Bay_Aquarium_2_2017-11-21.webm · https://commons.wikimedia.org/wiki/File:Kelp1000.webm · https://videos.fisheries.noaa.gov/detail/video/3863054329001/ · https://www.nps.gov/chis/planyourvisit/archived-programs.htm · https://www.youtube.com/watch?v=xuNitr0vdXM

The app's own: the Jellyfish method research and its probe ([jellyfish/research-method.md](../jellyfish/research-method.md)), Fish Tank's doc ([fish-tank.md](../fish-tank.md)), and the cut Sea Sparkle's research on the Open-Meteo marine feed (`git show 1028d91:docs/sea-sparkle/research-method.md`, §6).
