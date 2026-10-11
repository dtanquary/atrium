# Meander (being built, hidden)

A river slowly migrating across its floodplain: bends grow and shift down the valley, a neck narrows until the river cuts through and leaves an oxbow lake, and every former course stays written on the ground behind it. Drawn as lidar relief (height above the river, in one colour family) or as a map of old courses coloured by age, after Harold Fisk's 1944 maps of the Mississippi. A new river on each load.

Dave picked the idea on 2026-10-10 ([ideas.md](ideas.md)). That day two agents researched it (one built and ran the simulation, one measured the real references) and two sheets went to Dave. **The build has begun, step by step and hidden:** [The build so far](#the-build-so-far) says what is in the app. The rest of this page is the plan, the measurements to build against and their sources.

- **The two research reports in full:** [the simulation](meander/research-simulation.md) and [the look](meander/research-look.md).
- **In `docs/meander/`:** `sheet1.jpg` (what Dave chose from) and `sheet2.jpg` (the same references above the prototype's second round, in the looks he chose), `reference-mississippi-relief.jpg` (the real river, our render of USGS elevation), the prototype's pictures (round 2's `proto-relief.jpg`, `proto-map-fisk.jpg`, `proto-cutoff.jpg`, `proto-first-frame.jpg`; round 3's and round 4's are named in their sections), `proto/` (the simulation: `python3 meander.py` is its self-check; `render.py` draws both looks; the latest round has the plain names, earlier ones `-v2` and `-v3`) and `measure/` (the scorecard `busy.py`, the palettes, the relief and scroll-bar measurements). Research scripts, not reviewed line by line.

## Dave's decisions (2026-10-10)
From sheet 1: the two real references (Fisk's sheet 6, and the same stretch of river as relief from USGS elevation) above the simulation's renders of that hour.
- **Look:** both, from one simulation. Relief is the default; bands by age are a Settings choice.
- **Band colours:** palettes. Fisk's own four muted inks on cream, and single-ink palettes where older is simply paler.
- **River size:** a slider, true to life by default (the channel about 2% of the screen's width), zooming in toward a bold river. The prototype's river was already that size (28 pt on a 1512 pt screen, 1.85%, 54 widths across), so the default is the small end and the slider zooms in from there, to about 56 pt. When he chose, I had told him the prototype's river was twice too wide; that was wrong (see [What is still wrong](#what-is-still-wrong-with-the-prototypes-pictures)).

From sheet 2 (2026-10-11), the same references above the second round:
- **The next pass on relief:** "Keep refining toward M but all are amazing do them all." Keep refining relief toward the real lidar picture (M): the lake scraps and faceted banks first, then levees, bars and islands, crisper scroll bars. My reading of "do them all": keep every look on the sheet, the map in Fisk's four inks, the single inks and the dark versions, as well as relief. That is already the plan.
- **The first frame:** try the cheap distant past, so a new river opens on a full floodplain: the older history drawn roughly in big coarse steps, then the recent past exactly. Untried; if it can't be done in about 0.3 s, fall back to the young belt.
- **Light and Dark Mode:** the look is the user's choice and stays; its shade follows the system (the palette's paper version in Light Mode, its dark version in Dark Mode), as Wind does.

Not asked yet: the pace (it needs a film), and rivers "after a real one".

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
| Its second relief (Survey Blue) | 0.25 | 1.1% | 1.0 |
| Its second map (Fisk's four inks) | 0.73 | 6.8% | 1.0 |

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

- **The channel's width varies** (added in the second round): each node carries a half-width that eases toward `0.5 (0.7 + 0.8 clamp(bend/0.4, 0, 1))`, `bend` the mean curvature over seven nodes, so it runs from 0.7 W on straight reaches to 1.5 W round the tightest bends, slowly enough that a cutoff can't jump it. The cutoff test becomes `|P_i − P_j| < 1.04 (hw_i + hw_j)`.

Over 90,000 steps with a constant width: sinuosity 1.6 to 4.4, median 2.8; 239 to 656 nodes; about four big bends across a 54-width screen. With the varying width, over 20,000 steps: 630 cutoffs, no self-crossing, sinuosity 1.9 to 3.2.

**The complete maths as the final prototype runs it,** step by step with every constant and which are from meanderpy and which are the agent's own, is in [research-simulation.md](meander/research-simulation.md), round 2, messages 2 to 4. What follows is the summary.

### Running forever
- **The river is periodic,** with a period of the screen's width plus 10 W either side, so what leaves on the right is what enters on the left, out of sight. Pinned at both ends (as meanderpy runs it) the river straightens from the inlet downstream and is two-thirds straight on screen by step 6,000.
- **Valley walls** 1.5 W inside the top and bottom edges (3 W in the first round, which left empty margins): a bank cutting toward a wall erodes more slowly over the last 5 W and stops at it. The belt as a whole wanders between the walls, which is where the long-run variety comes from.
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
- **Old map:** a ribbon per stage of 5 T, fixed to the land once laid, in one of Fisk's four inks by stage; the ink's cover falls with age through his measured steps (solid, 65%, 50%, 40%, 23%) as flat tints that slide, so nothing steps; the river and lakes are bare paper between heavy bank lines; all fading into the paper by 120 stages.
- **Relief:** `height = 0.25 (1 − exp(−age/1.6)) + 0.75 (1 − exp(−age/90))`: new ground leaves river level within about half a width, which is what stopped the river reading as a pipe; plus faint scrolls at two spacings that beat, minus a hollow where a lake dried; colour by height above the river; light from the upper left, faded to nothing near water so no bank has a rim. Memory is 600 T.

### Pace and cutoffs, as measured
For a river 28 pt wide, at 75 s of wallpaper per T: the fastest bank moves 0.47 pt a second and the average 0.11; a cutoff on screen about every 2.5 minutes; an oxbow lasts about 20 minutes; old courses stay visible 3.3 hours. At 25 s per T, three times all of that. Frame-to-frame change at 75 s per T was 0.026 grey levels a pixel (relief) and 0.035 (bands) in the first round, about the same as the Turing Patterns look Dave called done moving (0.03). In the second round's looks at 25 s per T it is 0.04 (relief, which is now so low in contrast that it stays near that Still level even three times faster) and 0.10 (the old map, near Turing's Regrow). So relief may want a faster pace than the map, or the map is the lively one. The look research's "a year every 9 seconds" is in real years; the two haven't been reconciled.

A cutoff, as it happens: the two limbs' banks touch; the loop's nodes are dropped; the river crosses the neck, which is the only thing that changes in one frame, a patch about a river's width across (in the second round's looks, 0.07% of nearby pixels change by more than 20 levels in relief and 0.38% in the old map, whose two heavy bank lines vanish in the neck; one cutoff measured). The kink relaxes over 10–20 s, the loop's ends silt up over a minute or two, its water darkens, and it narrows and dries from both ends, staying as a scar.

Stepping: 10 steps a second counted from elapsed time, as Turing Patterns counts its steps, so 15, 30 and 60 fps show the same river (by design; not run).

### Cost
Measured with a standalone Swift sketch (`proto/bench.swift`, `swiftc -O`, M3 Max): the river step 0.03–0.05 ms; the field update 0.51–0.57 ms; so about 0.6 ms a step, ten times a second, or 0.1–0.4 ms a frame averaged. The launch history: about 200 ms for T 60, 72 ms for T 30, on the main thread at every load (Schlieren's is about 100 ms). Not measured: the texture upload, anything on the GPU.

### What is still wrong with the prototype's pictures
See `sheet2.jpg`: the two real references above the second round.

Fixed in the second round: the river reading as a pipe (no outline in relief, new ground darkening within half a width of the bank, a width that varies); even, strong scroll rings (now a few percent of brightness and uneven; at one pixel a point they nearly vanish and show at Retina); colours round the whole wheel (relief in Survey Blue; the map in Fisk's four inks on cream); empty ground beyond the belt, for a river that has run a while (history covers 66–90% of the screen).

**A correction.** After the first round the look research measured the channel at 3.5–4% of the frame, twice the references', and that went to Dave and into the first version of this page. It was wrong: that script thresholds brightness, so it counted the pale new ground beside the water. Measured on the water's own colour, the channel was 1.84%, inside the references' range. The fault was real but it was the look (ground staying pale for eight widths behind a moving bank), not the scale.

Still wrong:
- **Lakes.** A drying lake's ends are blocky, and where the river re-crosses a fresh oxbow it leaves ragged scraps of water. Now the most visible flaw. Taper each lake's ends along its length, and dry a part-eaten lake quickly.
- A hairline of land shows where a lake meets the river.
- Banks are faceted on tight bends at Retina (straight chords up to 0.7 W long): draw the fields from the centreline subdivided along its curve.
- **The first frame** after the launch history is a young belt on empty ground (`proto-first-frame.jpg`), not the edge-to-edge floodplain of a river that has run two hours.
- Relief is soft beside real lidar: no levees, no bars or islands in the channel, width varying two times and not two to three, scroll bars invisible below Retina.
- In the old map lakes are bare paper like the river, so a fresh oxbow reads as a second river until its line thins.

And what the look research saw in the second round beside the references (both looks now score inside its targets and read as calm):
- **Relief:** banks are soft on both sides, where real ones are lopsided, a crisp step on the outer bank and a gradual ramp on the inner. Each bend leaves one broad smooth petal, where real ground is many smaller arcs cutting across each other. The belt's straight dark margins make it read as a corridor.
- **Old map:** the bands are thin stripes parallel to today's river. Fisk's are separate old courses that cross each other, because the Mississippi moved two to four channel widths between his stages (45–59 m a year over 55–64 years on a channel about a kilometre wide): longer stages would give his look. Hues alternate band by band, where his order keeps neighbours in one ink (four solids, then runs of four fading tints per ink). The river is even in width with a double line, which reads slightly as a road. The solid salmon areas are the loudest thing in it, which is the case for the single-ink palettes.

### A third round, and what it showed
The simulation's agent took the look research's review into a third set of renders (`proto-round3-relief.jpg`, `proto-round3-map-fisk.jpg`; code `proto/meander-v3.py` and `render-v3.py`, with round 2's kept as `meander-v2.py` and `render-v2.py`). Dave has not seen these: they are an experiment, and round 2 is still what he chose from.

Better than round 2:
- Relief's banks are lopsided, as real ones are: a clean step on the cut side, a gradual rise on the bar side (the land beside a bank is read two texels further from the water).
- The belt's edge is scalloped: each valley wall wanders in and out by up to 5 W, so the dark margins are no longer straight.
- Relief has arcs that show at a glance: a broader set of scrolls every 2.9 T, cut across by later ones.
- The old map follows Fisk's own order: stages of 11 T (the river moves two to four widths in one, as between his), the four newest solid in sage, salmon, grey-teal and straw, then runs of four stages in one ink at 65, 50, 40 and 23%.
- The cutoff frame: 0.03% of nearby pixels over 20 levels in relief, 0.24% in the map (one cutoff measured).

Worse, or newly visible:
- **Lakes are the weak point.** A cut-off loop breaks into jagged scraps when a second cutoff or the river crosses it, and in the map the scraps are bare paper on solid salmon: the first thing the eye lands on.
- The channel's width was widened to 0.6–1.7 W and tight bends swell into blobs. Go back to 0.7–1.5.
- The map is blotchier and louder: big solid salmon areas (one-family score 0.92, where round 2's was 1.0). It is truer to Fisk; round 2's thin stripes are calmer. Stage length is one constant, so it could be a setting: a choice for Dave once the lakes are clean enough to judge it by.
- Colouring by how many stages old the land is means every band must change colour each stage. The round slides the whole sheet over the last third of each stage (about 90 s in every 4.6 minutes at 25 s per T): a slow change of every colour at once, which Dave hasn't seen. Round 2's rule, colour fixed to the land once laid, has none.

**The lake redesign (built in round 4, below).** Keep each lake as a short polyline with a half-width per node, like the river, drawn with the same distance routine. Its widths shrink with age and taper to nothing at the ends, so every edge is as smooth as the river's. Where the live channel covers a lake's nodes, delete them, and the lake splits into two that taper: no per-texel erasing, so no scraps. River and lakes then share one water field (the river is the lake of age zero), which frees the texture's fourth byte for the hollow. About 15 lakes of 40 nodes is one more band the size of the river's, redrawn about once a second.

Not done from the review: islands and bars in the channel, levees.

### A fourth round: the lakes redone, and the launch timed
2026-10-11, by the simulation's agent, in the prototype only (`proto/meander.py` and `render.py` are now this round; the scripts are `stills4.py`, `strip4.py`, `recross4.py`, `film4.py`, `launch4.py`; the Swift timing sketch is `bench4.swift`, its output `bench4-run.txt`). Its five messages, with every formula that changed, close [the simulation research](meander/research-simulation.md). Pictures: `proto-round4-relief.jpg`, `proto-round4-map-fixed.jpg` and `proto-round4-map-order.jpg` (the two colour rules below), `proto-round4-map-sage.jpg` and `proto-round4-map-dark.jpg`, `proto-round4-first-frame.jpg`, `proto-round4-cutoff.jpg`. Two 20 s films at 25 and 75 s a T were made for Dave and aren't kept here (`film4.py` makes them again).

**The lakes work.** The jagged scraps are gone:
- A cut-off loop is kept as its own nodes and half-widths and drawn by the river's own distance routine into one water field, so its edges are as smooth as the river's. On the cutoff frame it has the widths the channel had: the same water.
- It silts up from each end behind a front that moves in (about 1.2 W in the first T, then 0.25 W a T), tapers to a point over the 2 W ahead of the front, and narrows to nothing over the second half of a 16 T life.
- Where the live channel covers a lake's nodes they are dropped; a lake the river cuts through becomes two, and a new end starts silting from that moment.
- River and lake differ in the shader only by the water's age. The old channel's footprint is kept apart as a hollow field in the texture's fourth byte.
- Measured at 25 s a T, 15 frames a second, in a 14 W window, share of pixels changing by more than 20 levels: the cutoff frame 0.05% in relief and 0.22% in the old map (round 3: 0.03% and 0.24%); a frame where the river takes a node off a lake 0.02–0.09% and 0.07–0.15% (three frames, one lake). All under the 0.3% bar.
- The run behind it: T 400, 351 cutoffs, no self-crossing, sinuosity 2.3 to 3.7, 9 to 26 lakes alive (median 17).

Also better: banks are smooth at Retina (every channel is drawn with one point added half-way along each segment, on a cubic through its neighbours), and the channel's width is back to 0.7–1.5 W.

**The cheap distant past works as a picture.** T 300 of old history is run coarse (nodes 1 W apart, steps three times the live one, the ribbon between the banks stamped every 4th step as whole texels), then T 60 exactly as the live river runs. The first frame's floodplain is then full of pale older courses, edge to edge of the belt: 0.72 of the screen has been visited, against a median 0.70 for the exact river over T 400. It is not the same history: the coarse river cuts off three times as often (649 in T 300 against about 220), its old scarps are stair-stepped, and in relief it barely shows, since land that old is already dark. It matters in the old map.

**The launch is too slow, as timed** (`bench4.swift`, `swiftc -O`, an M3 Max, a 28 pt river with varying width, lakes, hollows and subdivided banks):
- Distant past 135–142 ms, then the exact T 60 250–261 ms: 404 ms in all on the main thread. Without the distant past 283 ms; with fields every 16th step 304 ms; a 20 pt river 540 ms.
- A live step is 0.8–1.2 ms with fields and lakes (round 1's 0.6 ms was a constant-width river with no lakes). At ten steps a second that is 0.15–0.2 ms a frame on average, but about 1 ms on the frame a step lands on.
- Not tried: the sketch allocates five arrays a step and a bucket grid per cutoff search (tidying that is the first move, a guessed halving); fields every 16th step; or running the history off the main thread and fading in, as Rain on Glass's frost does.

**Found on the way.** The respacing rule can loop for ever (dropping a node and splitting what is left can undo each other): it needs the cap of four passes the Python always had; the Swift sketch hung without it. With widths that vary, the fast distance routine no longer matches the exhaustive one everywhere: up to 0.05–0.09 W out at a fresh junction, where two widths meet.

**The old map's two colour rules, both kept for Dave to choose** (`proto-round4-map-fixed.jpg` against `proto-round4-map-order.jpg`):
- *Fixed:* a stage is 5 T and its ink is fixed to the land once laid, so the bands are thin stripes and nothing ever changes colour.
- *Fisk's order:* a stage is 11 T, the four newest solid in Fisk's own order, so there are big solid areas (salmon most of all), and the whole sheet slides one colour on over the last third of each stage. The slide hasn't been seen in a film.

**Still wrong, worst first:** the launch time; the 1 ms step frame; the distant past being a busier river than the live one; relief still soft beside real lidar (levees, islands and bars were left out); a fresh oxbow in the old map reads as a second river until its line thins (a tint would fix it); in my own look at the stills, a lake's stub can show as a small notched blob; a small step in the bank at a fresh junction for about 1.5 T; long straight chords after a big cutoff, which is the model. Still unverified: the shader as a shader, GPU cost, the texture upload, sameness at 15, 30 and 60 fps, the alpha byte as data.

## The build so far
On a branch of its own (`meander`), by the agent that wrote the prototype, a step at a time: each is reviewed before the next.

### Step 1: the river (2026-10-11)
`Sources/MeanderRiver/River.swift` (in `Sources/Atrium/Meander.swift` until step 2 moved it) holds `River`, with no SpriteKit in it: the centreline, the cutoffs, the lakes, the ground's three fields and the four bytes a texel that a shader will read. There is no scene yet and no entry in `Scenes.swift`. Its checks are in `Tests/AtriumTests/MeanderTests.swift`.

It is `proto/meander.py` with round 4's rules. Where it differs, and why:
- **Banks.** The prototype added a point half-way along each segment, on the cubic through its neighbours, and drew straight pieces. `River` keeps the segments and bows each one to pass through that same middle point, so the distance routine runs once over half as many, longer segments, with its inner loop across the channel, where the bank distance changes by the same amount from texel to texel. Not yet compared with the prototype's banks pixel for pixel: that is step 2.
- **The launch history is kept a cheaper way** (`sweep`). Between two sweeps each bank moves from one line to another; where it moved in toward the river, the ground between the lines is ground the river has left, and its texels take a stamp that runs from the last sweep's time at the old line to now at the new one. So a texel is written once, as the river leaves it, the sweeps can be far apart (every 8th step of the distant past, every 12th of the recent), and the stage bands still come out smooth. It works in whole texels, so the furthest line a bank reached is stair-stepped in ground made at launch; the live river's is recorded to a fraction of a texel as before. A loop's own strips are swept just before it is cut off, and at the end the river's ribbon and a texel beyond it take the present time, or hairlines of old ground are left (found by looking: 1.6% of texels before those two fixes).
- **Two hours in all:** T 240 of distant past (it was 300) and T 60 of recent, 300 T, which at speed 1 is 2 h 5 min.
- **Lakes in the history** are trimmed once, at the end: where the ground's stamp is later than a lake's birth the river has been there since, and that end of the lake has been silting up since then.
- **Necks are looked for** every other coarse step while the history is made (every step live), and the pair cut is the one whose banks overlap most.
- **Erodibility** is the same random field, but its exponential is taken at the grid's corners and read between them, where the prototype read between the corners and then took the exponential.
- **A hollow's band** runs 0.3 W beyond the old banks, not 0.5: as far as the shader shows it, and its two texels.
- **The stamps' base moves up** before 16 bits run out (after 650 T, down to 605), which the prototype never needed.

Measured, `swift test -c release -Xswiftc -enable-testing --filter river`, an M3 Max, a 28 pt river (54 × 35.07 widths, 756 × 491 texels):
- **6,000 coarse steps** (T 240, no distant past): loops are cut off, the river never crosses itself at any of 12 checks, and no bank leaves the valley.
- **Stepped by 1/15, 1/30 and 1/60 s** for 12 s (8 at speed 1, 4 at speed 4, where it steps twenty times a second): the nodes and every byte of the texture are identical. A smaller valley, to keep a debug build quick.
- **The launch: 81 to 94 ms** over five seeds, where the sketch took 404 ms. Timed in parts (which adds a little): the distant past about 45 ms (moving the river 7, looking for necks 9–10, respacing 3, sweeps 16–18, cut-off loops 8–10), the recent past about 41 ms (moving 9, necks 12, respacing 3.5, sweeps 8–10, cut-off loops 6–9), the last exact update and writing every byte 3 ms. Keeping the recent past's ground exactly instead (the live routine every 12th step, 74 ms where the sweeps take 9) makes it 153 to 158 ms.
- **A live step** with the ground and every lake redrawn: a median 1.0 ms with 9 lakes and 1.5 ms with 26; the slowest of 600 was 1.3 to 2.5 ms. That is the frame a step lands on, ten times a second, before the texture's upload.
- **The first frame's ground:** 72–73% of the screen has a past, as the prototype's had.
- In a debug build the launch took 3.4 s (until step 2 gave the river its own module), and the whole suite (71 tests then) passed in 159 s.

Still wrong or not known after this step:
- **A step frame costs 1.0–1.5 ms** of CPU before SpriteKit's own and the upload, more than the plan's 0.6. Every lake is redrawn on every step; that is where to look first. (Step 2 did: about 0.8 ms now.)
- **Nothing has been drawn through a shader yet.** The texture has only been looked at as grey pictures of its bytes. Whether the sweep's stair-stepped scarps show, and whether the bowed banks match the prototype's, is for step 2. `age(exactEvery:)` keeps the exact way to compare with; one of the two goes after that.
- About 0.4% of stamped texels are older than everything round them by more than 3 T: mostly slivers at the cusps where lobes meet, some of them real.
- "Allocates nothing per step" is by reading the code (fixed buffers, lists with room for every texel), not measured. A cutoff and a trimmed lake do allocate.
- **Debug builds:** 3.4 s to make a river's past, at every scene build in a debug `swift test`. Fixed in step 2.
- The distant past is still a busier river than the live one.

### Step 2: the texture and the shader (2026-10-11)
**The river has a module of its own,** `MeanderRiver` (`Sources/MeanderRiver/River.swift`), built with `-O` even in a debug build, as `TreeGrowth` is and for the same reason: a river's past is made on the main thread whenever its scene is built, and unoptimised that was 3.4 s at every scene build in a debug `swift test`. It is Foundation and simd only, with its own seeded generator and `smoothstep`, so the type and what the scene and the tests read of it are `public`. In a debug build the launch now takes **85 to 95 ms** over five seeds, the same as in release (84 to 95 ms in the same run), and the four river tests take 1.8 s where they took most of a minute. The root `CLAUDE.md`'s Layout section lists `TreeGrowth` and not yet this one.

**Banks, checked against the prototype's.** Step 1 left open whether a segment bowed through the middle of its cubic gives the same bank as the prototype's two straight pieces. `River.bankDistance(at:)` works a point's bank distance out the prototype's way, every segment against it, and `riverGetsAPastQuickly` compares it with the ground at every fifth texel within two texels of a bank (3,271 of them, a 28 pt river): half are within 0.013 of a texel, 99 in 100 within 0.115, and the worst is 0.50, which is 2 px on a 2x screen at one joint. So the bowed banks stay. Three things changed in the routine that draws a channel (`band`) on the way:
- **A segment's banks are the lines that touch its two nodes' circles,** where they were the width read at the foot of the perpendicular. It is the common tangent of two circles; the form used is Inigo Quilez's uneven capsule (https://iquilezles.org/articles/distfunctions2d/, read 2026-10-11: his own derivation, and the page carries no licence statement, so the Swift is written from the geometry, not copied). For the river, whose width changes little from node to node, the two should differ by under a hundredth of a texel: worked out, not measured. For a lake's silting end, where the width falls from full to nothing over a few nodes, the old way left a step where one segment's reach ended and its neighbour's began: about half a texel in the one case taken apart, moving as the end silted up. It may be the "small notched blob" round 4 saw; that hasn't been checked in a picture.
- **A lake's last node has a round end** like its first. It was cut square, by an accident of the loop, and the square end came and went as the lake's width there changed.
- **A disc is drawn round a joint only where it turns by over 26 degrees,** which is as far as the segments' own reach past their ends covers; it was 16. Discs took 36,000 of the 117,000 texel visits in a step.

**The lakes are drawn a couple at a step.** Step 1 drew every lake again on every step, which was 0.6 ms of a 1.6 ms step with 26 lakes. Now each lake keeps the texels it was last drawn on and its bank distance at each (so one lake can be lifted out of the ground without disturbing another it overlaps), and `drawLakes` draws a new lake, or a piece of one just trimmed, at once, and of the rest only the two whose silting fronts have moved furthest since they were drawn, if that is over 0.15 of a texel. A fresh lake, whose front moves fast, is drawn every step; an old one every second or two. Two other things were found on the way: a lake with an end under the river was thrown away and made again on every step (an allocation a step for each), and is now left alone unless more of it is covered; and over half the river's own texels are deep water, all alike, and now take a short path.

Measured, a 28 pt river with 26 lakes, 600 steps at speed 1, an M3 Max that other builds were sharing:
- **A live step: a median 0.73 to 0.81 ms, 99 in 100 under 0.93 to 1.2, the slowest of 600 between 1.0 and 1.7** over six runs in debug and release (one run with the machine busier had a 4 ms step). It was a median 1.6 and a slowest 2.3 to 2.5. None of the slowest eight in a run was a cutoff or a trim: none happened in those 600 steps, so what a cutoff's step costs is not measured.
- **Where it goes,** timed in parts before the last two changes: drawing the river's band 0.47 ms and stamping it and writing its bytes 0.38 (50,000 texels), two lakes 0.08, and moving the river, looking for necks, respacing and trimming 0.03 between them.
- **How far behind a lake gets:** at most 0.43 of a texel at its bank after those 600 steps, against every lake drawn afresh (`River.lakesAdrift`). `riverKeepsItsLakesUpToDate` holds it under half a texel over 24 T at speed 4 on a small river, through 5 cutoffs and every lake of the start drying up: 0.22 there.

So River's part of a step frame is about 0.8 ms as a rule and 1.2 at worst on a quiet machine: near the 1 ms asked for, not inside it. What would take it further, neither built: (a) on most steps draw and stamp only a strip a few texels wide along each bank, and the deep water between every 16th step and on a cutoff (about half the band and the stamping, so perhaps 0.4 ms off; the risk is water left behind where a loop is cut off, and it needs the lists that say which texels left the band rethought); (b) step on a background queue and hand the bytes over, which takes the river off the frame altogether but needs the render test to wait for it.

**Ground made at launch, seen through the shader.** Step 1 asked whether the sweep's stair-stepped scarps would show. They do, plainly, at full size: [build-step2-scarps.jpg](meander/build-step2-scarps.jpg) is one piece of the same river three ways, 900 px across of a 2x screen. On the left step 1's sweep: old channels' edges in texel-sized stairs, and tatters of old ground where a bank had swung round against the valley wall. In the middle what step 1 offered in its place, the recent past kept the live river's way every 12th step: its scarps are smooth, but ground the river left between two visits all takes the one stamp, so the bars come out in terraces, one to a visit, where the sweep's are smooth (and it took 156 to 160 ms). On the right the sweep as it is now. So the sweep stays and `age(exactEvery:)` is deleted, with `updateGround`'s `drawing` switch that only it used. What changed in the sweep:
- **Soft scarps.** A strip's first edge is where a bank was, and a cut-off loop's ribbon has a bank on each side: scarps from then on. Texels up to one beyond such an edge now take a share of the stamp, less the further out, as the live river's part-covered texels do. The scarp stands half a texel further out than it should, which can't be seen. The river's own ribbon at the end of the past keeps hard edges: the live river's banks take over there.
- **A dropped node's strips are swept before it goes.** Respacing drops a node where a bank line bunches up, and the next strip then ran from the chord past it: the corner of the old bank line inside the chord was never stamped. Where a bank swings round a point these made fans of one-texel cracks.
- **The neck's two nodes are marked after a cutoff.** Their banks swing round to the new course, and the next sweep took that swing for ground the river had left. The segments either side of the neck are swept before the cut.
- **Cracks are closed.** What is still missed is a texel or two wide, so at the end each stamp becomes the latest of the nine round it and then the earliest of the nine round that, which fills anything under three texels wide and moves no scarp (`closeCracks`).
- **The stamps count from a memory back** (`base` starts at minus 605 T), so a texel the river never reached, whose stamp is none, reads as older than anything remembered. It read as 300 T old, and the ground beyond the belt came out as the oldest floodplain, flat, where it should be the rough ground of nowhere.

Measured before the exact way went, on a 300 T past at the live river's spacing made both ways from one seed (so the same river, 493 nodes and 287 cutoffs in both), counting land texels whose stamps differ by over 3 T: the sweep with soft scarps only left 1.43% older than the exact way did (missed); with the dropped nodes and the necks, 0.93%; with the cracks closed, 0.61%. It leaves 0.9% newer, most of it the line one texel wide that the river's last ribbon lays along its own banks (gone as soon as a bank moves) and the half texel the soft scarps stand out by. 96.4% of land is within 0.5 T. What is left of the misses is in the bays between bends against the valley walls: a few patches three texels or more across, which closing squares off (one shows in the picture's top right). Drawing every strip, not only those of a bank that moved in, halved the misses again but took 40 ms more, so it isn't done. `riverGetsAPastQuickly` now counts cracks (land over 3 T older than the land on both sides of it): none of 188,410.

**The launch is 97 to 114 ms** over five seeds, debug and release, on a shared machine, where step 1's was 81 to 94: the soft edges cost about 10 ms and the rest 5. Timed in parts: the distant past's necks and loops 24 ms and sweeps 23, the recent past's 21 and 12, moving the river 17, respacing 10, closing the cracks 1.

**The scene and its two shaders** are in `Sources/Atrium/Meander.swift`, and Meander is in `Scenes.swift`, flagged `unfinished`. `Meander` builds a `River` for the screen (a channel 28 pt wide, 14 texels to it, so a texel is 2 pt: 756 by 491 on a 14" screen), gives it its past, and draws one sprite the size of the screen whose texture is the river's bytes. `update(_:)` moves the river on by the frame's time and sends the bytes again only on a frame the river stepped on. There is a shader for each look, put together from a shared start (`reads`) and the look's own end:
- **The start** reads the ground through a cubic B-spline in four linear taps, as Turing Patterns does (Sigg & Hadwiger, GPU Gems 2, ch. 20: https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-20-fast-third-order-texture-filtering), and takes the stamp's slope and the direction away from the water from the same four taps. Then it reads the stamp twice more, two texels into the water (the water's own age: none for the river, a lake's for a lake) and two texels out (the land beside a bank, so a cut bank is a clean step up to old ground): these stand in for the prototype's newest and oldest stamp within two texels.
- **Relief** is `render.py`'s `relief`, term for term: height from age, hollows, the two scroll-bar spacings and the sets of them, rough ground where the river hasn't been in memory, light from the upper left with none beside water, and the land's colour from a 256-entry texture of the palette's heights.
- **The old map** is its `fisk`, with either colour rule (a `rule` picks the few lines that differ): the four inks as uniforms, Fisk's order as arithmetic, the stage lines, swale lines and bank lines.
- **What differs from the prototype.** Lengths the prototype gave in its pixels (half a texel) are in points here, so a line is as wide on any screen; the water's edge is softened over a pixel of the screen it is on, which on a 2x screen is half the prototype's. The noise is value noise from the shared `hash42` at three quarters of the prototype's strength, which gives the unreached ground the same spread (below). The slopes are differences of the four taps, not exact slopes of the surface; the light on the relief uses the GPU's own slopes a pixel (`dfdx`, `dfdy`: one value to a block of four pixels).
- **A cycle in the time needs to know the base.** A stamp counts from `River.base`, which moves up now and then; the scroll bars and the map's stages are cycles in the time itself. So with each upload the scene tells the shader how far through each cycle the base falls (`u_turns`), or every bar and stage would jump when the base moved. Watched across a move of the base in step 3, which changed how: the shader now works in ages, and is told where the present falls in each cycle.
- **Not Settings yet.** The look, its colours, the old map's rule and the river's seed are read from defaults keys (`meander.look`, `meander.palette`, `meander.rule`, `meander.seed`) that only the tests and `SNAPSHOT_DEFAULTS` set; Speed is a knob already but not on a page. The old map follows the system: Fisk 1944 in Light Mode, its dark sheet in Dark Mode. Relief has only its dark self, and what it should be in Light Mode is not designed. Palettes in: Survey Blue, Rainforest, Garnet; Fisk 1944 and its dark. The single inks and Amethyst wait for step 4.

Side by side with the prototype's stills, the app's 3024 by 1964 snapshot at half size on the left (`SNAPSHOT_SCENE=Meander SNAPSHOT_DEFAULTS="meander.seed=13,meander.look=1,meander.rule=1" SNAPSHOT_APPEARANCE=light swift test --filter everySceneRenders`, and so on): [relief](meander/build-step2-relief.jpg), the old map with its inks [fixed to the land](meander/build-step2-map-fixed.jpg), [in Fisk's order](meander/build-step2-map-order.jpg), and [dark](meander/build-step2-map-dark.jpg). They are different rivers, so it is the look that can be compared, and it was by eye and by these numbers: over the whole picture the mean colour is within 3 levels of the prototype's in every channel for all four, and the spread (standard deviation) within 3; the ground the river hasn't reached has the prototype's mean and spread to within 1 (green 19.9 and 4.5 against 19.3 and 4.5). What does differ is the river: the app's first frame is of a busier floodplain, many small old loops where the prototype's still, taken after a long run at the live river's pace, has long bars in stripes. That is the launch's distant past, a known shortcut.

What the unknowns turned out to be (`meanderGroundReachesTheShader`, `meanderDrawsEveryLook`, `meanderFrameCosts`):
- **The fourth byte carries data.** Every byte of every texel reaches a shader as written, the alpha too, through `SKMutableTexture`: none of 30,240 texels differed (a small river's). The river's first row is the bottom of the screen.
- **A read that depends on another works,** and costs little: six reads of the ground a pixel, and one of the heights for relief.
- **Uniforms:** relief has 7 and one texture besides the ground; the old map 11 and no other texture. Far under the limit of about 30.
- **`modifyPixelData` takes the bytes before it returns,** so the scene hands it the river's own buffer and copies nothing itself; the copy inside takes 0.02 ms.
- **Cost, a 14" screen at 2x (3024 by 1964) and 60 frames a second,** in a release build and a debug one, which agree (the river is optimised in both), on a machine other builds were sharing; the medians of 300 ordinary frames and of the 60 the river stepped on:

  | | ordinary frame, CPU | GPU | step frame: `update` | drawing | CPU in all | GPU |
  |---|---|---|---|---|---|---|
  | Relief | 0.41 to 0.47 ms | 0.80 | 0.61 to 0.73 | 0.75 to 0.78 | 1.4 to 1.5 ms | 0.80 to 0.88 |
  | Old map | 0.47 to 0.48 | 0.53 | 0.58 to 0.67 | 0.71 to 0.76 | 1.3 to 1.4 | 0.61 |
  | Old map, Fisk's order | 0.47 to 0.48 | 0.56 | 0.58 to 0.62 | 0.72 to 0.73 | 1.3 to 1.35 | 0.64 |

  An ordinary frame's CPU is all SpriteKit's. On a step frame, one in six, `update` is the river's step and the copy, and drawing is 0.3 ms more than on an ordinary frame: SpriteKit sending the 1.5 MB to the GPU. The river's slowest steps are 0.3 to 0.5 ms over its median (above), so the worst step frame is about 2 ms of CPU. The render test's average over a second, at 30 frames a second, is 0.85 ms of CPU and 0.6 to 0.9 of GPU.

Still wrong or not known after this step:
- **The first frame's floodplain is busier than the prototype's,** as above. Nothing moves in these pictures: no frame strip, no cutoff, no lake silting has been looked at through the shader. Step 3.
- **A few patches of launch-made ground are still blocky** (the bays at the valley walls, above), and the light on the relief shows a dotted edge there at full size, from the GPU's block-of-four slopes. Exact slopes would need eight more reads; not tried.
- **A lake nearly silted up can read as a glossy bead** in the relief: a teardrop of low ground with a sliver of water along one side.
- **The sameness at 15, 30 and 60 fps** is proven for the river and its bytes (step 1), not yet for the picture, which only adds the uniforms set from them.
- Relief in Light Mode, the single-ink sheets, the River size slider and every other setting.

### Step 3: motion (2026-10-11)
The real scene, through its shaders, watched moving. Four tests do the watching: `meanderDoesNotPop`, `meanderLooksTheSameAtAnyFrameRate`, `meanderShowsNothingWhenItsStampsMoveUp`, and `meanderFilm`, which only runs when asked (`MEANDER_FILM=<folder> swift test --filter meanderFilm`; `MEANDER_STRIPS=<folder>` makes `meanderDoesNotPop` save its frames and try a second river, 30 fps and Fisk's order as well).

**Nothing pops, by the prototype's measure:** the greatest share of a window 14 widths square that changes by over 20 levels from one frame to the next, from a second before to two seconds after. The bar is 0.3%. At 15 and at 30 frames a second the figures are the same, as they should be: the river is the same river.

| | relief | old map | old map, Fisk's order |
|---|---|---|---|
| A cutoff, river 7 (27 s in) | 0.037% | 0.095% | 0.097% |
| A cutoff, river 13 (55 s in) | 0.063% | 0.118% | 0.119% |
| The river parts a lake, river 7 (16 s in) | 0.035% | 0.050% | 0.068% |
| The river parts a lake, river 13 (6 min in) | 0.004% | 0.002% | 0.002% |

A cutoff's own frame is its worst; the lake's figures for river 7 are a second and a half after, something else nearby. The events are the prototype's kind: a loop over 8 widths long cut off at a neck 6 widths inside the screen, and a lake over 2 T old parted where it still had over half its water.

**What looking at the frames found, which the figures alone would have passed** ([build-step3-cutoff.jpg](meander/build-step3-cutoff.jpg), [build-step3-recrossing.jpg](meander/build-step3-recrossing.jpg): the frame before, the frame itself and a third of a second on, at full size):
- **A lake's dry end came back as water.** Where the river ran over a stretch of lake that had already silted up, the lake was cut there and its new end began silting from nothing, so the dry stretch behind it was water again on that frame: 0.14 to 0.19% of the window, under the bar and plain to see. A new end is now never less silted than the lake already was there (`trimLakes`, `Lake.age(ofFront:)`): 0.007 to 0.02% on the same frame.
- **A lake the river parted lost a bite of water.** The nodes under the river were dropped, and with them whatever of the lake's width stood out beyond the river's bank: a notch of land 15 to 20 px deep, at once. The live river now drops nothing. A parted lake's pieces each keep the covered stretch as far as its middle node, so everything is still drawn, and the new ends silt up as any lake's do: 0.09% became 0.004%. (A past still drops them: there the river has been and gone.) A lake that has dried from end to end is forgotten, so it stops taking a turn at being redrawn.
- **Lake water against river water had a ragged edge,** blocky and speckled: the water's age was read without smoothing. Deep water now takes the smooth read, and a lake shades into the river it lies against.
- **At a cutoff, what is left to see** is the neck opening in one frame, which is the event; a jog of 2 or 3 px in the bank beside it for a T or so, where two widths meet (known since round 4); and a spur of about 5 px on the bank across from the neck, where the lake's last segment and the river's first no longer bow as one bend. Not fixed: each is part of the 0.04 to 0.12%.

**The stamps' base moves and the picture doesn't.** Step 2 moved the base by whatever was due and worked every byte out again, and a sixth of relief's pixels changed by a level or more on that frame (234,549 of 1,484,784; 7,404 of them by over 5 levels). Three causes, each fixed:
- **The two bytes carried differently in neighbouring texels,** so the GPU's smoothing between them gave slightly other stamps. The base now moves by whole turns of the high byte (2.56 T each, 16 at once: 41 T, once in 17 minutes at 1x, as far as 16 bits allow beyond the memory), taken off the high bytes and nothing else.
- **Ground never reached, and ground older than the memory, had no fixed age:** its stamp stayed at nothing while the base moved under it, so wherever it met ground with a past the blend between them jumped. `River.forget` now keeps all such ground at one stamp, the memory and 5 T back, bringing a fiftieth of the rows up to it each step; and the shaders take anything 605 T old or more as the same, and as flat.
- **The shaders worked in stamps,** and a cycle's phase came from a stamp and the base's phase added: the same number after a move, but for its last bits, and relief's light, which took the GPU's slopes of the height, turned those last bits into a level here and there (8,385 pixels). The shaders now work in ages, are told where the present falls in each cycle (so nothing they are told changes when the base does, but the time since it), and relief's slope is worked out beside each part of the height, not taken from the GPU's slopes of it. That also cleared the dotted edges on scarps that step 2 listed.

What is left: of 1,484,784 pixels, 407 change by one level in relief, 263 in the old map (4 by more than one, the most 10) and 118 in Fisk's order (2 by more, the most 15), where an ordinary step of the river changes 20,000 to 49,000. **It is not none, and can't be:** an age is a subtraction of two numbers near 600, and after a move the same subtraction comes out a few hundred-thousandths of a T different in its last bits, enough to round a pixel in a few thousand the other way. The test holds it to one pixel in 2,000 and 20 levels. (On its own smaller screen it sees 4 to 14 pixels change.)

**The picture is the same at 15, 30 and 60 frames a second:** after the same six seconds every pixel of both looks is identical (`meanderLooksTheSameAtAnyFrameRate`).

**Timed.** A step frame that carries a cutoff: 0.91 to 1.15 ms in `update`, where a plain step's is 0.58 (the same runs, a 14" screen). One that parts a lake: 0.76 to 0.92. So the worst step frame is about 2 ms of CPU with SpriteKit's share, as step 2 guessed. The reworked shaders: relief 0.90 ms of GPU on an ordinary frame and 0.99 on a step frame (it was 0.80 and 0.88); the old map 0.53 and Fisk's order 0.58 to 0.65, as before. A live step is as it was (median 0.8 ms).

**A lake silted down to a sliver** read as a highlight on a bead in relief. Lake water now dulls to the colour of a new bar within two texels of its banks, and all of it over the second half of its life, so a sliver is dull right through. A thin lake no longer shines; the fattest remnants (a lens 4 texels across) keep a small light middle. Better, not gone.

**Half an hour from a fresh launch at 1x** ([relief](meander/build-step3-film-relief.jpg) and [the old map](meander/build-step3-film-map.jpg) at the start, 5 minutes and 10; river 13):
- **The busy launch-made floodplain does give way.** The live river had worked over 7% of the land with a past after 1 minute, 28% after 5, 47% after 10 and 82% after 30; what it leaves is broad bars in long arcs, as the prototype's stills have. The small old loops last longest at the belt's edges.
- **The pace, in numbers.** In 10 seconds the river's line moves a median 2.2 pt, and 9 nodes in 10 move under 7.7 pt; the model's limit is 14 pt. So in a glance of a few seconds nothing is seen to move; over ten seconds the liveliest bends creep by a quarter to a half of the channel's width.
- **A loop is cut off on screen about once a minute** (28 in the 30 minutes, some in twos and threes seconds apart, the longest wait four and a half minutes), and there are 6 to 22 lakes at once.
- At Speed 4x that would be four times as far, 9 pt and 31 pt in ten seconds, and a cutoff every 15 seconds: worked out, not measured. Dave found the Black Hole's first pace far too slow on his own screen; this one may want its 1x faster too, which only his screen can say.

Still wrong or not known after this step:
- The pace, above: whether 1x is lively enough.
- A move of the base is a few hundred pixels by a level, not none.
- At a cutoff, the jog and the spur beside the neck.
- A stretch of lake the live river lies along for longer than its end takes to silt up would show again if the river moved off it sideways (a `ponytail:` note in `trimLakes` says what to do then). Not seen.
- The fat remnant of a short lake still has a light middle.
- A few blocky patches of launch-made ground in the bays at the valley walls, as after step 2.
- Nothing has been left running overnight.

## The plan
One file, `Sources/Atrium/Meander.swift`: a `River` type with no SpriteKit in it (nodes, step, cutoff, fields, pixel bytes), the scene, its shader, knobs and palettes. Everything built in `sceneDidLoad`; steps owed at 10 a second in `update(_:)`; the texture uploaded only when a step ran.
1. **The look first, in the prototype.** Four rounds are done (above): the lakes, the banks and the cheap distant past are in, and two films at two paces are made. Left for Dave: the pace, the old map's colour rule, and whether the distant past is worth its time at launch. Left in the prototype: relief toward the reference (levees, bars and islands). No Swift before he has seen it move: it is the Crystals risk.
2. **`River`** (done: [step 1](#step-1-the-river-2026-10-11)) ported from `meander.py`, written to allocate nothing per step and with the respacing capped at four passes, and its launch timed first (the sketch took 0.3–0.4 s: too slow for the main thread at every load), with its check: 6,000 coarse steps must cut off loops, never cross and stay in the valley; stepping by 1/15, 1/30 and 1/60 s for the same elapsed time must give identical nodes.
3. **The texture and shader** (done: [step 2](#step-2-the-texture-and-the-shader-2026-10-11)), matched to `render.py`'s stills. Finds out the unknowns: the alpha byte carrying data, a second dependent read, the uniform count, the upload's cost.
4. **Motion** (done: [step 3](#step-3-motion-2026-10-11)), in frame strips through a cutoff: no frame with more than about 0.3% of pixels changing over 20 levels.
5. **Settings:** Look (Relief, Old map); Colors, a list per look (relief: Survey Blue, Rainforest, Garnet, Amethyst; old map: Fisk 1944, Sage, Salmon, Teal, each with a dark version), Random by default; Speed (0.25–4×); River size (the slider Dave picked, from 28 pt to about 56 pt: a rebuild, keeping 14 texels a width so the cost stays the same); how long old courses stay; scroll-bar strength; how long lakes last; the shared grade knobs.
6. Left overnight: no drift in pace, no banding from rebasing. Then the doc, screenshots, README, site.

Still Dave's to decide: the pace (from the two films), the old map's colour rule, and the distant past.

## Risks, worst first
1. Pretty, not just correct. The old map is already striking; the relief, the default, is calm and in one family but soft beside the real thing.
2. Pace: calm enough to be ambient is as still as a look Dave has called finished.
3. The launch history on the main thread at every load, shuffle and Settings page: 0.3–0.4 s as first timed (round 4).
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
- The four-tap cubic read and the busyness figures: [turing-patterns.md](turing-patterns.md), [game-of-life.md](game-of-life.md); the read itself is Sigg & Hadwiger, "Fast Third-Order Texture Filtering", GPU Gems 2, ch. 20: https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-20-fast-third-order-texture-filtering
- A tapering segment's banks (the uneven capsule), Inigo Quilez, no licence stated on the page, so written from the geometry: https://iquilezles.org/articles/distfunctions2d/
- The shader's noise is from the shared `hash42` (Dave Hoskins, "Hash without Sine", MIT: https://www.shadertoy.com/view/4djSRW)

Art
- Robert Hodgin, Meander: https://roberthodgin.com/project/meander; onformative, Meandering River: https://onformative.com/work/meandering-river

Not verified: the Ucayali's migration rate and the Koyukuk's width (three publishers refused the fetch); figures marked as from search summaries; that long simulated rivers settle at a sinuosity near 3.14 (Stølum 1996, from memory).
