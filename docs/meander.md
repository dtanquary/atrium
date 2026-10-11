# Meander (planned, not built)

A river slowly migrating across its floodplain: bends grow and shift down the valley, a neck narrows until the river cuts through and leaves an oxbow lake, and every former course stays written on the ground behind it. Drawn as lidar relief (height above the river, in one colour family) or as a map of old courses coloured by age, after Harold Fisk's 1944 maps of the Mississippi. A new river on each load.

Dave picked the idea on 2026-10-10 ([ideas.md](ideas.md)). That day two agents researched it (one built and ran the simulation, one measured the real references) and one sheet went to Dave. **Nothing is built in the app.** This page is the plan, the measurements to build against and their sources.

- **In `docs/meander/`:** `sheet1.jpg` (what Dave chose from), `reference-mississippi-relief.jpg` (the real river, our render of USGS elevation), the prototype's pictures, `proto/` (the simulation: `python3 meander.py` is its self-check; `render.py` draws both looks) and `measure/` (the scorecard `busy.py`, the palettes, the relief and scroll-bar measurements). Research scripts, not reviewed line by line.

## Dave's decisions (2026-10-10)
From sheet 1: the two real references (Fisk's sheet 6, and the same stretch of river as relief from USGS elevation) above the simulation's renders of that hour.
- **Look:** both, from one simulation. Relief is the default; bands by age are a Settings choice.
- **Band colours:** palettes. Fisk's own four muted inks on cream, and single-ink palettes where older is simply paler.
- **River size:** a slider, true to life by default (the channel about 2% of the screen's width), zooming in toward a bold river.

Not asked yet: the pace (it needs a film), Light and Dark Mode (the plan follows the system, as Wind does), and rivers "after a real one".

## What the real things look like
Measured on the downloaded references; these are the numbers to judge renders against.

### Fisk's maps
"Ancient Courses, Mississippi River Meander Belt", Plate 22 of his 1944 report for the Mississippi River Commission, fifteen sheets. All fifteen are on Wikimedia Commons at about 10,000 × 14,000 px, tagged public domain. (One nuance: the title block credits Fisk as a consultant to the Commission, and a consultant's work is not automatically a federal work. No copyright notice was seen on the sheets, and renewal records weren't checked. NASA/JPL and the Public Domain Review treat it as public domain. Colours measured from it are facts either way; shipping a scan would want this settled.)
- **Four inks on cream,** measured on sheet 1's legend: paper (235,224,196); line ink (89,75,59), a warm brown-black, never black; sage (188,199,139); salmon (215,114,97); grey-teal (154,180,159), his "blue"; straw (221,208,123).
- **Age is ink coverage within one hue:** solid, then hatching at about 65%, 50% and 40%, then dots at 23%. Older is paler. The eye-blended tints, for salmon: (227,156,134), (227,175,149), (228,186,159), (231,206,175).
- **The present river is bare paper,** the lightest thing on the sheet, with no fill.
- **Each spot gets one stage:** the last time the river was there. Nothing is translucent; younger courses cut across older ones with a crisp line.
- **Line weights:** final banklines 0.5–0.65 mm, everything else 0.15–0.3 mm.
- **Scale:** the 1944 river is 0.9–1.2 km wide, 2–2.6% of the sheet's width.
- **It is busy:** 56–59% of pixels sit on a brightness edge (hatching, lettering, the base map), at a mean brightness of 0.71–0.75.

What survives on a calm desktop: one stage per spot with crisp boundaries; age as paleness within an ink; the river as bare ground colour; warm off-black lines, heavy only on the present banks; cream, not white. What doesn't: hatching and stipple (they shimmer when the picture moves: use the blended tints, which are still his colours), stage numbers, place names, contours and the grid, and all four inks at full strength together.

### Lidar relief
The pictures of rivers as height above the water, made famous by Daniel Coe. His own are not open (CC BY-NC-ND); seven he made for the Washington Geological Survey are CC BY-SA 2.0 on Commons, used here as references only. The best reference is one we made: a relative elevation model of the Mississippi near Helena, Arkansas, from USGS 3DEP elevation (public domain), the same ground as Fisk's sheet 6.
- **One colour family already:** a pale river, through one hue, to near-black high ground. Brightness falls with height above the water, with most of the range spent on the first few metres.
- **Lighting:** colour by height first; hillshade only shows on hills. On the floodplain the detail is the ramp alone.
- **Scale:** the channel is 1.8–2.5% of the frame's width: 40 to 55 channel widths across.
- **The channel** has no outline and its width varies two to three times along its length: wide at the apex of a bend, with bars and islands, narrow at the crossings. A constant-width pale tube with a dark edge reads as a pipe.
- **Scroll bars:** fine arcs that fan and converge. On a Mississippi point bar the crests are 130–155 m apart (0.12–0.17 channel widths; Strick et al. give a 167 m mean) and 0.5–1 m high, on a bar spanning 6–8 m. In brightness that is a ripple of a few percent. Older sets are smoother and cut off by younger ones.
- **Oxbow lakes** are crescents at the river's own brightness; part-filled ones a mid tone with a bright thread. **Levees** are darker rims fading over a few channel widths.
- **The floodplain is textured edge to edge** with older, dimmer courses, yet only 1–2% of pixels are edges.
- **Brightness:** the references sit at 0.30–0.47 with a pure white river, brighter than this app's bar. Hold the river near 0.7 and the mean near 0.15–0.20.

### A scorecard
`python3 -I measure/busy.py <image>` at 1920 px wide: brightness, the share of pixels on an edge, and a one-family colour score.

| Picture | brightness | edges | one family |
|---|---|---|---|
| Fisk's sheets 6 and 7 | 0.71–0.75 | 56–59% | – |
| Coe's Dark relief pictures | 0.30–0.47 | 3.5–7.7% | 1.0 (0.61–0.76 for the two-hue ones) |
| Our relief of the Mississippi from 3DEP | 0.20–0.31 | 1–2% | 1.0 |
| The simulation's first relief | 0.19 | 3.3% | 1.0 |
| The simulation's first bands | 0.64 | 10.3% | 0.44 |

Targets: Dark relief at 0.15–0.20, edges 2–5%, one family 1.0. Bands in Light at 0.80–0.88, edges under 10%, one family above 0.9 (Fisk's four inks apart).

## Real rivers' numbers
| Quantity | Value |
|---|---|
| Meander wavelength | 10–14 channel widths (Leopold & Wolman 1960; Williams 1986) |
| Bend radius | most often 2–3 widths |
| Belt width | 15–18 widths |
| Scroll-bar spacing | about half a width on average, across rivers 55–2,042 m wide; 0.12–0.17 on the Mississippi |
| Oxbow lifetime | months to several centuries; chute cutoffs fill ten times faster than neck cutoffs |
| Lower Mississippi | 0.9–1.2 km wide; migrates 45–59 m a year (0.04–0.055 widths); sinuosity 1.31 near Helena today, roughly 1.7 before its sixteen artificial cutoffs |
| Mamoré, Bolivia | about 480 m wide; 0.03 widths a year typically, 0.12 on fast bends |
| Ucayali, Peru | 400–1,200 m wide; 13 cutoffs in 31 years over 1,300–1,500 km |
| Koyukuk, Alaska | perhaps a tenth of the Mamoré's rate: many lasting lakes, crisp scrolls |

**A motion test from the real thing:** NASA's pair of the Mamoré in 1985 and 2014. After those 29 years only 24% of the 1985 channel was still channel; the parts that moved sat a median 0.9 channel widths from the new channel, 3.4 at the 90th percentile. A simulated 29 years should come out the same.

## Pace
Proposed, not yet seen moving: one simulated year every 9 seconds. With the channel 30 points wide the fastest bends then move 0.4 points a second and typical banks 0.1: you see that it has changed when you look back, not that it is crawling. That gives a cutoff every four or five minutes for about 100 km of channel in frame, a Fisk stage laid down every 8–10 minutes, and the belt reworked over hours. A cutoff is the one sudden thing: open the breach over 5–10 seconds and fade the loop from river tone to lake tone. A Speed setting, 0.25–4×. Check frame strips, not stills.

## Palettes proposed
Each: ground; five ages, oldest to youngest; river. Dark grounds sit at 0.05–0.10 brightness, the youngest deposits at 0.40–0.45, the river at 0.62–0.75, never white. A new palette on each load would suit a new river on each load.
- **Survey Blue** (from the Survey's Sauk River picture). Dark: (0,22,31) | (4,46,63) (10,64,83) (14,76,97) (24,93,115) (52,130,151) | (153,200,211). Light: (240,244,242) | (192,222,229) (169,209,218) (153,200,211) (130,187,200) (115,178,193) | (30,104,127).
- **Rainforest** (the Quinault). Dark: (2,21,15) | (0,47,37) (8,67,54) (14,80,65) (24,97,80) (52,132,113) | (151,202,192). Light: (240,244,240) | (190,224,217) (167,211,202) (151,202,192) (129,189,176) (114,181,166) | (31,109,90).
- **Garnet** (the Chehalis). Dark: (30,9,13) | (81,25,38) (92,42,51) (100,54,59) (112,70,71) (143,108,101) | (210,187,173). Light: (245,241,232) | (230,213,199) (218,197,183) (210,187,173) (197,171,159) (189,160,149) | (120,81,79).
- **Amethyst** (the Okanogan). Dark: (25,14,28) | (58,33,63) (78,44,73) (92,51,79) (115,65,96) (165,100,111) | (217,184,172). Light: (248,244,242) | (237,212,209) (225,195,187) (217,184,172) (207,168,152) (201,157,138) | (131,74,107).
- **Fisk Sage, Salmon, Teal:** one of his inks on his paper. Light: paper (235,224,196), river (244,237,216), and for salmon (230,199,173) (227,180,156) (225,169,146) (222,152,132) (215,114,97). Dark: ground (27,24,20), river (166,158,138), lines (80,76,67); sage (44,43,32) (56,57,42) (64,65,47) (74,77,55) (100,106,74); salmon (58,38,32) (81,49,42) (95,56,47) (115,65,55) (163,87,74); teal (42,43,37) (53,57,50) (59,65,57) (69,77,68) (91,106,94).
- **Fisk 1944:** his four inks together, the one palette outside one family. Dark: straw (110,104,61), teal (82,96,84), salmon (123,65,55), sage (100,106,74).
- **Landsat,** if a true-colour feel is wanted, from NASA's Mamoré and Ucayali pictures: forest (48,63,52) and (59,85,61), young growth (79,104,75) and (112,130,93), fresh bars (168,172,125) to (220,208,171), river tan (209,170,103), black-water oxbow (30,29,46). A true-colour satellite look of its own was judged not worth it: it only convinces with photographic canopy texture, which a simulation can't migrate.

## Real data
- **A real river as the seed** is practical and tiny: USGS NHD centrelines are public domain, and one query for the Mississippi near Helena returned 11.6 KB (53 km in 158 points). United States only. Worldwide centrelines with widths: GRWL, CC BY 4.0. That would make a setting "after a real one" (Mississippi, Mamoré, Koyukuk), like Galaxy's.
- **Replaying a recorded history** is not a wallpaper: the Landsat record is 40 years, which at the pace above plays in six minutes and shows about one width of movement. It is the right test for the simulation instead (above).
- **Fisk's own courses** exist nowhere as vectors; the four dated ones (1765, 1820, 1880, 1944) could be traced by hand, about a day a sheet. A charming later idea.

## Pitfalls
- **Fake:** a channel of constant width with an outline; even, high-contrast scroll rings; bends all one size; empty ground beyond the belt; oxbow lakes at the wrong tone; cutoffs that pop.
- **Garish:** more than one saturated hue; a pure white river on near black.
- **Busy:** hatching, labels, grids, an outline on every band; more than five or six ages at once; Light Mode at full contrast (bright and sharp is what got Zen Garden cut: keep bands within about 0.2 of the paper's brightness).
- **Dull:** only the channel on flat dark ground; motion too slow to notice; a history that saturates, so old deposits must keep fading; every load alike.
- **Technical:** banding in dark ramps (dither, as Galaxy does); bands and relief must come from one history or they drift apart.

## The art that exists
For reference only; nothing copied. Robert Hodgin's "Meander" (2020) generates maps of rivers that never existed, with fields, roads and place names, weathered like a 1940s Corps map: right for a print read up close, too busy for a desktop, and it would have to stay still while the river moves under it. onformative's "Meandering River" shows the calm version: no map furniture, slow change, texture and colour only. Worth borrowing as ideas: lakes that shrink and vanish; the river on a diagonal with ground to spare on both sides.

## The model
A Python prototype (`docs/meander/proto/`) ran three days of wallpaper time, 90,000 steps and 2,500 cutoffs, without the river crossing itself, leaving the valley, straightening or dying. It draws both looks from the same three per-texel fields, at the texture size the app would use.

The law is Howard & Knutson's (1984), a kinematic model: flow never enters, only curvature. Its form and constants were read from Zoltán Sylvester's `meanderpy` (Apache-2.0); no code was copied.

Units: the channel's width `W = 1`. Time `T` is "nominal widths", `kl·t/W`, `kl` being the migration constant.

The centreline is a polyline of nodes, **periodic along the valley**: node `i+n` is node `i` moved one valley length along x. Each step, per node, with `a = P_i − P_{i−1}` and `b = P_{i+1} − P_i`:
- **Curvature** `k_i = 2(a × b) / (|a| |b| |a+b|)`: the circle through three nodes (the nodes aren't evenly spaced, so not finite differences).
- **Upstream average** `U_i = Σ k_j w_j e^{−αs} / Σ w_j e^{−αs}` over the nodes upstream, `s` the distance along the river, `w_j` the node's share of length. Two running sums, one pass: `c = k_i w_i + e^{−α|a|} c`.
- **Rate** `R_i = Ω k_i + Γ U_i`, with `Ω = −1`, `Γ = 2.5`.
- **Move** along the right-hand normal by `clamp(R_i · E · ε, ±1.25 ε)`, `ε = kl·dt/W`.

Parameters:
- `αW = 0.73`. It sets the bend size: the fastest-growing wavelength is `8.24/α` along the channel, 11.3 widths here. At 0.6 and below the bends outgrow a 35-width valley and slide along its walls.
- `ε = 0.04` for a coarse step (the launch history); live steps are far smaller. The `−k` term is a heat equation, so `ε` must stay under spacing²/2.
- A rate cap of 1.25 W per T, which bounds the motion after a cutoff's kink.
- Node spacing 0.5 W, kept between 0.3 and 0.7 by splitting long segments at the Catmull-Rom midpoint `(−P0 + 9P1 + 9P2 − P3)/16` and dropping the far node of short ones. **Respace only the segments that need it:** respacing every node after a cutoff shifts every bank on screen in that frame.
- Erodibility `E = exp(0.5 × smooth noise)`, cells 8 W, fixed for the run, so the bends don't all look alike; times a valley-wall factor.
- **Neck cutoff:** the closest two nodes nearer than 1.04 W and at least 12 nodes apart along the river; drop the nodes between. 1.04 means the banks are touching, which is what makes the cutoff nearly invisible.
- Left out: chute cutoffs, the river's slope and depth, levees, meanderpy's sinuosity factor.

Over 90,000 steps: sinuosity 1.6 to 4.4, median 2.8; 239 to 656 nodes; about four big bends across a 54-width screen.

### Running forever
- **The river is periodic,** with a period of the screen's width plus 10 W either side, so what leaves on the right is what enters on the left, out of sight. Pinned at both ends (as meanderpy runs it) the river straightens from the inlet downstream and is two-thirds straight on screen by step 6,000.
- **Valley walls** 3 W inside the top and bottom edges: a bank cutting toward a wall erodes more slowly over the last 6 W and stops at it. The belt as a whole wanders between the walls, which is where the long-run variety comes from.
- **Nothing tangles:** the instability regrows any straight reach, and cutoffs remove loops before they can cross. Zero self-crossings at every check of two 90,000-step runs.
- **A new river on each load:** a straight line with small random wiggles and a random erodibility field, then a history run at launch in coarse steps. T 30 gives a full belt whose bends are young and alike; T 60 looks like a mature map.
- **Each display its own river,** like every other simulated wallpaper.
- **Days of running:** time as a `Double`; the stamps rebased every few hours (below).

### The floodplain's memory
One RGBA8 texture, about 756 × 491 on any 16:10 display (the river fixed at 14 texels wide), three fields:
1. **Stamp** (16 bits, red and green, as Turing Patterns packs its field): the time the channel last covered the texel. It carries nearly everything.
2. **Lake** (8 bits): distance to the centreline of the cut-off loop the texel belongs to, creeping up as the lake silts in.
3. **Live** (8 bits): distance to the live centreline, in a band two texels past each bank.

Updated each step only in the band under and beside the river (about 36,000 of 371,000 texels), from the exact distance of each texel's centre to the nearest segment. A texel a bank is part-way across takes that share of the new time, so old scarps come out smooth and not stair-stepped. At a cutoff the loop's texels copy their live distance into the lake field: the same numbers, so the water doesn't change that frame. Stamps are absolute times, so untouched texels are never rewritten; the shader gets "now" as a uniform. At 0.01 T a level, 16 bits last 655 T, so every few hours a constant is subtracted from every stamp (a whole number of scroll periods and stage cycles, so nothing shifts).

The shader, so far only emulated in numpy (`render.py`): one cubic B-spline read of the texture in four taps, as Turing Patterns', plus one more read of the stamp inside any lake. Then:
- `age = now − stamp`.
- Scroll bars `= cos(2π · stamp / 1.1 T)`: contours of the stamp, so they are the river's own old bank lines, fanning round each bend.
- Water where the live or lake distance is under half a width.
- **Bands:** `palette[floor(stamp / 5 T) mod 8]`, a ribbon per stage, fixed to the land once laid; all fading into the ground as age nears 160 T.
- **Relief:** `height = 1 − exp(−age / 28 T)`, land building up since the river left, plus the scrolls, minus a hollow in a silting lake; colour by height above the river.

### Pace and cutoffs, as measured
For a river 28 pt wide, at 75 s of wallpaper per T: the fastest bank moves 0.47 pt a second and the average 0.11; a cutoff on screen about every 2.5 minutes; an oxbow lasts about 20 minutes; old courses stay visible 3.3 hours. At 25 s per T, three times all of that. Frame-to-frame change at 75 s per T is 0.026 grey levels a pixel (relief) and 0.035 (bands), about the same as the Turing Patterns look Dave called done moving (0.03), so the agent would default nearer 25–30 s per T with a Speed setting. The look research's "a year every 9 seconds" is in real years; the two haven't been reconciled.

A cutoff, as it happens: the two limbs' banks touch; the loop's nodes are dropped; the river crosses the neck, which is the only thing that changes in one frame, a patch about a river's width across (0.05% of nearby pixels change by more than 20 levels in relief, 0.2% in bands; one cutoff measured). The kink relaxes over 10–20 s, the loop's ends silt up over a minute or two, its water darkens, and it narrows and dries from both ends, staying as a scar.

Stepping: 10 steps a second counted from elapsed time, as Turing Patterns counts its steps, so 15, 30 and 60 fps show the same river (by design; not run).

### Cost
Measured with a standalone Swift sketch (`proto/bench.swift`, `swiftc -O`, M3 Max): the river step 0.03–0.05 ms; the field update 0.51–0.57 ms; so about 0.6 ms a step, ten times a second, or 0.1–0.4 ms a frame averaged. The launch history: about 200 ms for T 60, 72 ms for T 30, on the main thread at every load (Schlieren's is about 100 ms). Not measured: the texture upload, anything on the GPU.

### What is wrong with the prototype's pictures
See `docs/meander/proto-relief.jpg` and `proto-bands-jade.jpg` beside `reference-mississippi-relief.jpg`.
- The relief reads as blue ribbon candy, not yet as lidar: the channel is about twice too wide with an outline, and the scroll bars are even, like corduroy (they are spaced by time, so they bunch where the river moved slowly).
- Where the river re-crosses an oxbow, ragged scraps of water remain, and a drying lake's front is stair-stepped at Retina.
- Old scarps wobble by about a pixel and, in bands, carry a thin fringe of other stages' colours.
- The strips 3 W inside the top and bottom edges stay empty; history covers 62–77% of the screen.
- Never-visited land is flat.

## The plan
One file, `Sources/Atrium/Meander.swift`: a `River` type with no SpriteKit in it (nodes, step, cutoff, fields, pixel bytes), the scene, its shader, knobs and palettes. Everything built in `sceneDidLoad`; steps owed at 10 a second in `update(_:)`; the texture uploaded only when a step ran.
1. **The look first, in the prototype:** bring `render.py`'s relief to the references' scorecard at the true-to-life river size Dave picked (thin channel of varying width, no outline, faint irregular scrolls, texture to the edges), and the bands in Fisk's measured inks. Then a film at two paces for Dave. No Swift before this: it is the Crystals risk.
2. **`River`** ported from `meander.py`, with its check: 6,000 coarse steps must cut off loops, never cross and stay in the valley; stepping by 1/15, 1/30 and 1/60 s for the same elapsed time must give identical nodes.
3. **The texture and shader,** matched to `render.py`'s stills. Finds out the unknowns: the alpha byte carrying data, a second dependent read, the uniform count, the upload's cost.
4. **Motion,** in frame strips through a cutoff: no frame with more than about 0.3% of pixels changing over 20 levels.
5. **Settings:** Look (Relief, Old map), Colors (palettes, Random by default), Speed (0.25–4×), River size (the slider Dave picked: a rebuild), how long old courses stay, scroll-bar strength, how long lakes last, the shared grade knobs.
6. Left overnight: no drift in pace, no banding from rebasing. Then the doc, screenshots, README, site.

Still Dave's to decide: the pace (from a film); whether 0.1–0.2 s to load is acceptable or the past should fill in over the first seconds; the empty margins (valley walls drawn as land, or left as ground); Light Mode (paper map by day, or leave it to the Look setting).

## Risks, worst first
1. Pretty, not just correct. The bands are already striking; the relief, the default, is not there yet.
2. Pace: calm enough to be ambient is as still as a look Dave has called finished.
3. The launch history on the main thread at every load, shuffle and Settings page.
4. Shader unknowns (above).
5. Lake leftovers and scarps at Retina.
6. Odd displays: portrait or ultrawide change how many widths the valley is.

## Sources
Fisk
- All fifteen sheets, scanned by LSU Law Center: https://commons.wikimedia.org/wiki/File:Ancient_Courses_Mississippi_River_Meander_Belt,_Plate_22_Sheet_06.jpg (and Sheet_01 … Sheet_15); https://biotech.law.lsu.edu/climate/mississippi/fisk/fisk.htm
- Treated as public domain: https://pdimagearchive.org/images/03c7ce69-c0c7-4131-b0f7-85924627a30a

Relief
- USGS 3DEP elevation, public domain: https://www.usgs.gov/3d-elevation-program; the request used: https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/exportImage (longitude −90.95 to −90.33, latitude 34.42 to 34.74)
- Daniel Coe's own pictures are not open: https://www.thisiscolossal.com/2023/10/dan-coe-lidar-rivers/. His Washington Geological Survey ones, CC BY-SA 2.0, on Commons from https://www.flickr.com/photos/35433815@N08/ (Sauk, Quinault, Chehalis, Okanogan, Skagit, Yakima, Sol Duc)
- Scroll-bar spacing, Strick et al. 2018: https://research.brighton.ac.uk/en/publications/morphology-and-spacing-of-river-meander-scrolls/

Rivers
- Wavelength rules: https://www.ars.usda.gov/ARSUserFiles/6112/meanderShapeAndTheDesign.pdf; bend radius, Williams 1986: https://pubs.usgs.gov/publication/70015687; belt width and sinuosity: https://en.wikipedia.org/wiki/Meander, https://en.wikipedia.org/wiki/Sinuosity
- Mississippi migration, Hudson & Kesel 2000 (from a search summary; the page wouldn't open): https://www.nature.com/articles/35014721; its artificial cutoffs: https://ascelibrary.com/doi/10.1061/TACEAT.0006144; False River, an oxbow since about 1722: https://en.wikipedia.org/wiki/False_River_(Louisiana)
- The Mamoré, 1985 and 2014 (NASA Earth Observatory, public domain): https://science.nasa.gov/earth/earth-observatory/meandering-in-the-amazon-84833
- The Ucayali (NASA SVS): https://svs.gsfc.nasa.gov/15021; its cutoffs: https://science.nasa.gov/missions/landsat/the-secret-lives-of-migrating-rivers/; sharper bends move faster: https://science.nasa.gov/missions/landsat/sharp-bends-make-rivers-meander-as-landsat-attests
- The Koyukuk near Huslia: https://arcticrivers.caltech.edu/documents/34248/Huslia_erosion_forecasts.pdf

Data
- USGS NHD flowlines, public domain: https://hydro.nationalmap.gov/arcgis/rest/services/nhd/MapServer/6/query
- GRWL, CC BY 4.0: doi 10.5281/zenodo.1297434
- Open histories, not downloaded: Greenberg & Ganti 2024, CC0, doi 10.5061/dryad.jq2bvq8g3 (its table of 139 rivers would fill the gaps above); Dente et al., CC BY 4.0, doi 10.5281/zenodo.11066336

The model
- meanderpy, Zoltán Sylvester, Apache-2.0 (law and constants read, no code copied): https://github.com/zsylvester/meanderpy
- Howard & Knutson 1984 (not read; known through meanderpy): https://agupubs.onlinelibrary.wiley.com/doi/abs/10.1029/WR020i011p01659
- Sylvester, Durkin & Covault 2019, meanderpy's paper (not read): https://doi.org/10.1130/G45608.1
- The four-tap cubic read and the busyness figures: [turing-patterns.md](turing-patterns.md), [game-of-life.md](game-of-life.md)

Art
- Robert Hodgin, Meander: https://roberthodgin.com/project/meander; onformative, Meandering River: https://onformative.com/work/meandering-river

Not verified: the Ucayali's migration rate and the Koyukuk's width (three publishers refused the fetch); figures marked as from search summaries; that long simulated rivers settle at a sinuosity near 3.14 (Stølum 1996, from memory).
