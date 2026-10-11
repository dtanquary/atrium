# Meander: the simulation research

A research agent's report as it was sent on 2026-10-10, unedited, kept so its detail and sources aren't lost. The plan beside it is the summary and has Dave's decisions; where the two differ, the plan is later. `scratch/` was the session's temporary folder: the scripts and pictures worth keeping were copied into this folder, the rest (downloaded references, video clips) is gone and its source URLs are below.

Meander 1/7: it works, and one simulation feeds both looks. Verdict, paths, and what is and isn't proven.

A Python prototype ran three days of wallpaper time (90,000 steps, 2,500 cutoffs) without the river crossing itself, leaving the valley, straightening or dying. It draws a Fisk-style map and a shaded relief from the same three per-texel fields, at the texture size the app would use (756 x 491, one texel per 2 pt), read the way Turing Patterns' shader reads its texture.

Look at these first (all under scratch/meander/proto/):
- out/still-fisk-jade.png, out/still-fisk-survey.png, out/still-fisk-midnight.png, out/still-relief-glacier.png (also -moss, -ember): full-screen stills, 1512 x 982
- out/strip-hours-fisk.png, out/strip-hours-relief.png: nine frames 400 T apart across the three days: a different river each time, always full of history
- out/strip-minutes-relief.png, out/strip-minutes-fisk.png: six frames 2.4 T apart (one to three minutes each, by pace)
- pops-seed3/cutoff-fisk.png, pops-seed3/cutoff-relief.png: one cutoff, from 3 s before to 10 min after
- out/retina-relief.png, out/retina-fisk-jade.png: a 500 x 350 pt piece at 2x Retina
- launch-history.png: the first frame after four candidate launch histories

Scripts: meander.py (river and fields; `python3 meander.py` is its self-check), render.py (both looks), long.py, strips.py, pops.py, launch.py, variants.py, lines.py. A Swift timing sketch of the core is in ../swift-bench/bench.swift (standalone swiftc -O in the scratchpad, nothing in the repo touched).

Verified by running:
- the river model, cutoffs and long-run behaviour (Python)
- both looks, drawn only from the three fields through an emulated shader read (numpy)
- frame-to-frame change through a cutoff at the wallpaper's own pace
- CPU cost of the river step, the field update and the launch history (Swift, M3 Max)

Not verified:
- GPU cost, and the shader itself: it exists only as numpy
- the cost of uploading a 1.45 MB SKMutableTexture ten times a second
- whether SpriteKit lets the texture's alpha byte carry data (I assumed so; I did not check a scene that does it)
- sameness at 15, 30 and 60 fps: by design (fixed 10 steps a second from elapsed time, as Turing Patterns counts steps), not run
- Howard & Knutson's paper itself: I read the formula and constants in meanderpy's source and README, not in the paper

Three things the obvious approach gets wrong, each found by running it:
1. A river pinned at both ends (what meanderpy does) straightens from the inlet downstream and is two-thirds straight on screen by step 6,000 (lines-pinned-washout.png). The river has to be periodic along the valley.
2. Respacing all nodes evenly after a cutoff shifts every bank on screen in that frame. Respace only the segments that need it.
3. Stamping texels as wet or dry leaves stair-stepped scarps. A texel a bank is part-way across has to take that share of the new time.

Six more messages follow: the model, running forever, the fields and looks, time and cutoffs, costs and the scene outline, then flaws, risks, questions and URLs.

---

Meander 2/7: the model, its maths and parameters.

Source: meanderpy by Zoltan Sylvester, Apache-2.0 (https://github.com/zsylvester/meanderpy, licence https://github.com/zsylvester/meanderpy/blob/master/LICENSE.txt). I read its source for the law and constants and copied no code; Apache-2.0 would allow reuse with a notice. It implements Howard & Knutson 1984 (https://agupubs.onlinelibrary.wiley.com/doi/abs/10.1029/WR020i011p01659), a kinematic model: flow never enters, only curvature. I did not read Ikeda, Parker & Sawai 1981; a search says Howard & Knutson build on it.

Units: channel width W = 1. Time T is "nominal widths": kl x t / W, where kl is meanderpy's migration constant.

The centreline is a polyline of nodes P_i, periodic along the valley: node i+n is node i moved one valley length L along x.

Each step, per node, with a = P_i - P_(i-1) and b = P_(i+1) - P_i:
- curvature k_i = 2 (a x b) / (|a| |b| |a+b|): the circle through three nodes. Mine, not meanderpy's (it uses finite differences on evenly spaced nodes); needed because my nodes aren't evenly spaced.
- upstream average U_i = sum of k_j w_j exp(-alpha s) / sum of w_j exp(-alpha s), over nodes upstream, s the distance along the river and w_j the node's share of length. It is two running sums, so one pass: c = k_i w_i + exp(-alpha |a|) c, and the same for the weights.
- rate R_i = Omega k_i + Gamma U_i, with Omega = -1 and Gamma = 2.5 (meanderpy's defaults, in its migrate_one_step).
- move along the right-hand normal by clamp(R_i x E x eps, +-1.25 eps), eps = kl dt / W.

Parameters:
- alpha W = 0.73. meanderpy: alpha = 2 k Cf / D with k = 1, Cf = 0.011, D = 6 m, W = 200 m (its README). It sets the bend size. My own derivation: the fastest-growing wavelength is 8.24 / alpha along the channel, so 11.3 W here, inside the 10 to 14 widths you gave. Tested 0.25 to 0.73 (var-alpha.png, var-zoom.png): at 0.6 and below the bends outgrow a 35 W valley and slide along its walls.
- eps: 0.04 per coarse step (meanderpy's defaults give 0.03). The -k term is a heat equation, so eps must stay under spacing squared / 2 (0.045 at my smallest spacing; my derivation). Live steps are far smaller, see 5/7.
- rate cap 1.25 W per T: mine. It bounds the motion after a cutoff's kink. The fastest bank on screen sits at the cap most of the time (median peak 1.25, mean 0.29 W per T over the long run).
- node spacing 0.5 W, kept between 0.3 and 0.7 by splitting long segments at the Catmull-Rom midpoint (-P0 + 9 P1 + 9 P2 - P3) / 16 and dropping the far node of short ones.
- erodibility E = exp(0.5 x smooth noise), cells 8 W, fixed for the run: mine, to stop every bend looking alike. Times a valley-wall factor (3/7).
- neck cutoff: the closest two nodes nearer than 1.04 W and at least 12 nodes apart along the river; drop the nodes between. meanderpy uses 2 W and the first pair found; 1.04 means the banks are touching, which is what makes the cutoff nearly invisible (5/7).
- left out: meanderpy's sinuosity factor (rate x sinuosity^(-2/3)), so the pace on screen stays steady; chute cutoffs (they need floods); the river's slope and depth; levees. meanderpy builds topography from a distance map per saved centreline with Howard's 1992 overbank law (in its fluvial_levee); I use a simpler closed form (4/7).

Results over 90,000 steps: sinuosity 1.6 to 4.4, median 2.8; 239 to 656 nodes; about 4 big bends across a 54 W screen.

---

Meander 3/7: running forever on a screen.

Where it enters and leaves: nowhere. The river is periodic along the valley, with a period of the screen's width plus 10 W either side (74 W for a 54 W screen), so what leaves on the right is what enters on the left, 20 W out of sight. There are no ends to pin and nothing to feed in. I tried pinned ends first: the bends travel downstream and nothing replaces them (lines-pinned-washout.png, meander-pinned.py). The seam costs some index arithmetic: neighbours wrap, a cutoff may span the seam, and each segment is drawn in the period that puts it on screen.

What keeps it in frame: valley walls 3 W inside the top and bottom edges. A bank cutting toward a wall erodes more slowly over the last 6 W and stops at it; a bank leaving a wall is never held. Over the long run the centreline stayed between 3.6 and 31.4 W of a 35.07 W tall screen. The belt as a whole wanders up and down between the walls, which is where the long-term variety comes from (out/strip-hours-fisk.png).

What stops it straightening or tangling: the instability regrows any straight reach, and cutoffs remove loops before they can cross. Measured: zero self-crossings at all 90 checks (one per 1,000 steps) in each of two 90,000-step runs, and at 6 checks of an earlier 48,000-step run. Cutoffs: 2,500 in T 3,600, about 0.51 per T on screen.

A new river on each load: a straight line with small random wiggles and a random erodibility field, then a history run at launch in coarse steps (eps 0.04) before the first frame. launch-history.png compares four. T 30 from straight already gives a full belt but the bends are young and alike; T 60 looks like a mature map. Ready-made bends (a sine-generated start) looked worse, so I dropped that.

How long the history takes (Swift sketch, M3 Max, -O): T 60 is 1,500 river steps (about 70 ms) plus the fields brought up to date every 8th step (188 updates), 200 to 207 ms in all; 176 ms for a 40 pt river. T 30 is 72 ms. Schlieren's doc says it runs 90 steps at about 1.1 ms at build, so 100 ms has a precedent and 200 ms does not. The sketch is unoptimised (five arrays allocated per step, five separate field arrays), so I'd expect T 60 near 100 ms after tidying, but that is a guess. It did not make lakes during the history; that is a few more loops' worth of the same work.

A cheaper route I did not build: the stamp is the latest time a texel was wet, a maximum, so old snapshots can be stamped in any order. The recent past could be done at launch and the older past filled in over the first seconds.

Texture size: fix the river at 14 texels wide and the screen at about 35 widths tall, and the texture is about 756 x 491 on any 16:10 display, so cost doesn't grow with the display. Texels are 2 pt on a 1512 pt screen and coarser on bigger ones.

Displays: each display's scene (and the Settings preview) owns its own river with its own seed, like every other simulated wallpaper. Nothing is shared, so two copies just cost twice. One river flowing across two displays would need shared state and the displays' arrangement; I wouldn't.

Days of running: keep time as a Double. The sketch's Float loses step precision by T 3,600. The 16-bit stamp needs rebasing too (4/7).

---

Meander 4/7: the floodplain's memory, and how each look is drawn from it.

Three fields, one RGBA8 texture, one texel per 2 pt (14 per river width):
1. Stamp (16 bits, red and green, as Turing Patterns packs its field): the time the channel last covered the texel. This one field carries nearly everything.
2. Lake (8 bits): distance to the centreline of the cut-off loop the texel belongs to, creeping up as the lake silts in.
3. Live (8 bits): distance to the live centreline, in a band two texels past each bank.
Both distances are stored so the bank sits at mid-range and two texels either side fill the byte, so a bank is placed to about 1/64 of a texel and moves smoothly below a pixel.

Updated each step, only in the band under and beside the river (about 36,000 of 371,000 texels):
- exact distance from each texel centre to the nearest segment
- fully covered: stamp = now. Part-covered and more covered than last step: stamp moves that share of the way to now. So the furthest line a bank reached is recorded to a fraction of a texel, and old scarps come out smooth.
- lake = max(lake, 1 - distance): the river erases any lake it crosses, again to a fraction of a texel
- at a cutoff: the loop's texels copy their live distance into the lake field. Same numbers, so the water doesn't change that frame.
- lakes: each keeps a list of its texels; every step each texel's value rises a little, fastest by the loop's two ends (they plug in about a minute), then a front moves in from each end and closes it.

Stamps are absolute times, so untouched texels never need rewriting; the shader gets "now" as a uniform. At 0.01 T per level, 16 bits last 655 T (4.5 to 13.6 hours by pace), so every few hours subtract a constant from every stamp: a whole number of scroll periods and stage cycles, so nothing shifts. One pass over 371,000 texels.

The shader (emulated in numpy in render.py): one cubic B-spline read of the texture, four taps, the read Turing Patterns uses, plus one more read of the stamp two texels inside any lake for the lake's own age (at a lake's bank the plain read blends the lake's stamp with the old land beside it, which made lakes shrink on the cutoff frame until I fixed it). Then per pixel:
- age = now - stamp
- scroll bars = cos(2 pi stamp / 1.1 T): contours of the stamp, so they are the river's old bank lines, fanning out round each bend. Faded where the stamp changes too fast to draw, which also flattens them across scarps.
- water = live or lake distance under half a width

(a) Fisk map: colour = palette[floor(stamp / 5 T) mod 8], a ribbon per stage, fixed to the land once laid; ink where stages meet and along scarps; the scroll contours as hachures; water pale with a bank line; all fading into paper as age nears 160 T.
(b) Relief: height = 1 - exp(-age / 28 T), land building up since the river left, plus scrolls, minus a hollow in a silting lake. Colour by height above the river (new and low is light, old and high is deep); light from the upper left on the fine relief.

So yes: one simulation, one texture, the look is a setting. Fisk's map is strictly the channel's whole ribbon at survey dates; mine is the land abandoned in each stage. They read alike.

Not modelled: levees, height built by Howard's deposition law, lakes that shallow rather than narrow. Never-visited land is flat.

---

Meander 5/7: time, pace, and cutoffs without a pop.

The pace is one number: seconds of wallpaper per T. For a river 28 pt wide:

At 75 s per T (what I measured at):
- fastest bank 0.47 pt/s, average 0.11 pt/s
- a cutoff on screen about every 2.5 minutes
- an oxbow lake lasts about 20 minutes; a bend's whole life about half an hour
- old courses stay visible 3.3 hours

At 25 s per T: three times all of that. Fastest bank 1.4 pt/s, a cutoff about every 50 s, lakes 7 minutes, history 67 minutes.

In years: by meanderpy's default constant (60 m a year for a 200 m river, its README), 1 T is 3.3 years, so 75 s per T is 2.7 years a minute and 25 s per T is 8. That constant is a fast river. I did not look up real rivers' rates; meander-look's numbers should replace this conversion.

How calm (pops.py: frames 1/15 s apart, average grey-level change per pixel, in a 14 W window round a bend): 0.026 for relief and 0.035 for the Fisk map at 75 s per T. The docs give Turing Patterns' Still as 0.03, Regrow 0.07 to 0.11 and Game of Life's Calm 0.22. So at 75 s per T Meander moves about as much as the Turing look Dave called "done moving". Change should scale with pace, so 25 s per T would land near Regrow; I did not measure that. My recommendation: default near 25 to 30 s per T with a Speed setting from a quarter to four times, and let Dave pick. The measured window is busier than the whole screen.

Stepping: 10 steps a second counted from elapsed time, the way Turing Patterns counts its steps, so 15, 30 and 60 fps show the same river. At 25 s per T the fastest bank moves 0.28 px (Retina) per step. Speed scales the step, not the rate, until a step nears a pixel.

A cutoff, as it happens (pops-seed3/cutoff-fisk.png):
1. The two limbs' banks touch (centrelines 1.04 W apart).
2. The loop's nodes are dropped. The loop's water is now drawn from the lake field, which holds the same distances the live field did: no change.
3. The river now crosses the neck. That is the only thing that changes in one frame: a patch about one river width across, where the two facing bank lines vanish.
4. The kink relaxes at the rate cap, over 10 to 20 s.
5. The loop's ends silt up and pull back from the river over a minute or two, leaving a horseshoe with tapered ends; its water darkens to still water over about 4 T.
6. It narrows, then dries from both ends, and stays as a scar in the stamp field.

Measured on the cutoff frame, share of the window's pixels changing more than 20 levels: relief 0.05%, Fisk 0.2%; the frames either side are ordinary (0.00% and 0.003%). Before the fixes in 1/7 it was 1.2% and 0.8%, with every bank on screen shifting (pops-seed3-old/cutoff-frame-before-after-diff.png shows where). The Fisk look's remaining change is larger because of its ink bank lines. If Dave still sees it, the neck could be eased open over a second; I did not build that. One cutoff measured, not many.

Nothing else is sudden: stage colours are fixed to the land once laid, a new stage's colour only appears on new land at the inner bank, and old land fades continuously.

---

Meander 6/7: cost, the scene outline, settings and checks.

CPU, measured (Swift sketch, swiftc -O, M3 Max, river 28 pt wide, 756 x 491 texture, about 400 nodes):
- river step (rates, move, bucket-grid cutoff search, respace): 0.03 to 0.05 ms
- field update: 0.51 to 0.57 ms for about 36,000 band texels (0.26 to 0.31 of it the distance band). Each segment only visits the slab beside itself; checked against the exhaustive version to 2e-6 W.
- copying the texture's 1.45 MB: 0.02 ms
- so one step with fields is about 0.6 ms, ten times a second: 6 ms a second, or 0.1, 0.2 and 0.4 ms a frame averaged at 60, 30 and 15 fps, on top of SpriteKit's own floor (the docs' plain shader scenes measure 0.41 to 0.5 ms). The frame a step lands on costs about 0.6 ms more.
Estimated, not measured: the SKMutableTexture upload; GPU. The shader is Turing Patterns' shape (0.3 to 0.75 ms there) plus a second four-tap read, so I'd guess under 1.5 ms.

Outline, by the steps in Sources/CLAUDE.md:
1. One file, Sources/Atrium/Meander.swift: a `River` type with no SpriteKit in it (nodes, step, cutoff, fields, pixel bytes), the `Meander` scene, its shader, knobs and palettes; `@MainActor func meander(size:)`; an entry in allScenes. bench.swift is a starting point for River, not finished code.
2. Everything in sceneDidLoad: seed, launch history, texture, one full-screen sprite with the shader. The render test then has a river at frame 0.
3. No live services.
4. update(_:) with frameTime: owed steps at 10 a second, capped per frame; upload only when a step ran.
5. Read systemIsDark at build for paper against dark palettes.
6. Budget as above.
7, 8. Snapshots, docs/meander.md, the docs/README.md row, screenshots, the Settings preview.
Plus one check without SpriteKit: River stepped 6,000 coarse steps must have cut off loops, never cross itself and stay in the valley (the Python self-check, ported).

Settings I'd offer:
- Look: Relief, Old map. Live, same texture.
- Colors: a PaletteChoice, Random by default; needs a rebuild or a uniform swap.
- Speed: .times, 0.25 to 4.
- River: Fine, Medium, Wide (about 20, 28, 40 pt). Rebuilds.
- Memory: how long old courses stay (the 160 T). Live.
- Scroll bars: strength, 0 to 1. Live.
- Lakes: how long oxbows last. Live for new lakes.
- the shared grade knobs.
I'd leave bend size (alpha) out: below 0.6 it misbehaves in a short valley.

Acceptance checks:
- stills at 20 s and 10 min in both looks and both appearances, against meander-look's references
- frame strips (check motion, not stills): SNAPSHOT_MOVIE through a cutoff; no frame with more than about 0.3% of pixels over 20 levels
- River stepped by 1/15, 1/30 and 1/60 s for the same elapsed time gives identical nodes
- the long-run check above
- build time under about 150 ms; CPU and GPU as the render test prints them, including with two copies running
- left overnight: no drift in pace, no banding from stamp rebasing

The mock-ups-before-big-builds rule applies: the prototype's renders are those mock-ups, already written as geometry, so the build can be pixel-matched against render.py.

---

Meander 7/7: what looked wrong, risks ranked, questions for Dave, URLs.

What looked wrong, and what I'd tune:
- Lake leftovers. Where the river re-crosses an oxbow, ragged scraps of water remain, and a drying lake's front is stair-stepped at Retina zoom (out/retina-relief.png, top right; the white scraps in out/still-fisk-midnight.png). I'd dry a lake quickly once the river has eaten part of it.
- The relief look reads as blue ribbon candy, not yet as lidar. The scroll bars are too even, like corduroy. It needs meander-look's references and a pass on height, light and colour.
- Old scarps wobble by about a pixel, and in the Fisk look carry a thin fringe of other stages' colours (the stamp blends across one texel). Ink mostly hides it; one colour family hides it more.
- A fresh oxbow looks like river until its tint arrives.
- The strips 3 W inside the top and bottom edges stay empty; history covers 62 to 77% of the screen. Either draw the valley walls as land or accept the margin.
- Scroll bars are spaced by time, so they bunch where the river moved slowly and fade out there.
- The Survey palette is Fisk's many colours, not one family. Jade and Midnight are my one-family tries; palettes are meander-look's.

Risks, worst first:
1. Pretty, not just correct (the Crystals lesson). The Fisk look is already striking; relief is not there yet.
2. Pace. Calm enough to be ambient is as still as the Turing look Dave found finished.
3. Launch history at about 200 ms on the main thread, on every load, shuffle and Settings page.
4. Shader unknowns: the alpha byte as data, a second dependent read, 30 uniforms (palette stops add up), and `fwidth` (the docs only confirm dfdx and dfdy).
5. The leftovers and scarps above, at Retina.
6. Upload cost, unmeasured.
7. Days of running: stamp rebasing and Double time are designed, not run.
8. Odd displays: portrait or ultrawide change how many widths the valley is.

Only Dave can answer:
1. Pace: a cutoff every 2.5 minutes (banks barely creeping) or every 50 seconds?
2. Default look: old map or relief? May the old map keep Fisk's own many colours as one palette?
3. How wide a river: 28 pt gives about four big bends across; 20 pt a busier belt.
4. Is 0.1 to 0.2 s to load acceptable, or should the past fill in over the first seconds?
5. Empty margins: valley walls drawn, or left as paper and dark?
6. Light Mode: paper map by day and relief by night, or leave it to the Look setting?
7. A separate river per display?

URLs:
- meanderpy, Apache-2.0: https://github.com/zsylvester/meanderpy ; licence https://github.com/zsylvester/meanderpy/blob/master/LICENSE.txt ; the source I read https://raw.githubusercontent.com/zsylvester/meanderpy/master/meanderpy/meanderpy.py (my copy is in ../ref-meanderpy/, read, never run)
- Howard & Knutson 1984: https://agupubs.onlinelibrary.wiley.com/doi/abs/10.1029/WR020i011p01659 (not read)
- Sylvester, Durkin & Covault 2019, meanderpy's own paper: https://doi.org/10.1130/G45608.1 (not read)
- Crosato 2007 on smoothing and regridding in meander models, which bears on the respacing finding (found by search, not read): https://sitesreservoirproject.riptideweb.com/references/REF23/Volume%202/App07B_Hydrodynamic_Geomorph_Model/Crosato_2007_Effects%20of%20smoothing%20and%20regridding.pdf
- Cubic B-spline in four taps (GPU Gems 2, ch. 20) and the busyness figures: docs/turing-patterns.md and docs/game-of-life.md in the repo.

Unsourced: that a pinned inlet washes out because the instability travels downstream is my reading of what I saw. No real river's migration rate is cited anywhere above.

Nothing was blocked. I wrote only under the scratchpad's meander/ folder.
