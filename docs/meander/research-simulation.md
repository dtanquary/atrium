# Meander: the simulation research

A research agent's report as it was sent on 2026-10-10, unedited, kept so its detail and sources aren't lost. The plan beside it is the summary and has Dave's decisions; where the two differ, the plan is later. `scratch/` was the session's temporary folder: the scripts and pictures worth keeping were copied into this folder, the rest (downloaded references, video clips) is gone and its source URLs are below.

The first seven messages are round 1. The note and five messages after them are round 2, which fixes the looks and has the complete maths as that prototype runs it (`proto/meander-v2.py`, `render-v2.py`). The last four are round 3 (`proto/meander.py`, `render.py`): what the look research's review led to, the formulas that changed, and why the lakes need a different design. Two of the messages were sent to the look research's agent.

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

---

Meander interim (new stills and a cutoff strip follow in a few minutes): the river in t5/t6 was not twice too wide, and three of the four faults are now fixed in the renders.

Scale: I measured the water itself in my renders (distance transform on the water's colour). t5, t6 and every still I sent are 28 px of 1512 = 1.84% of the frame, 54 widths across: inside meander-look's 40 to 55. t1 was 16 px, 1.06%, 94 across. meander-look's 3.5 to 4% comes from thresholding brightness (scripts/width.py), which also counts the pale new ground beside the water. In my first relief that ground stayed pale for about 8 widths behind the moving bank, so the river read as a fat pipe. So the slider's true-to-life default is the geometry you already saw (28 to 32 pt); zooming in goes from there. What had to change was the look, not the scale.

Fixed in the renders now (render.py, earlier version kept as render-v1.py):
1. Pipe: no outline in relief. New ground now rises out of river level within about half a width of the bank, so the bright ribbon is the water plus a narrow apron. The channel's width now varies along its length, 0.7 W on straight reaches to 1.5 W round the tightest bends, easing over time so a cutoff can't jump it (meander.py; the earlier one is meander-v1-constant-width.py).
2. Scroll rings: two spacings beating, uneven in strength, a few percent of brightness, about 0.2 W apart at the average bank's pace. At one pixel a point they nearly vanish; they show at Retina.
3. Band colours: Fisk's four inks on cream with his line ink, as meander-look measured them; older is paler by his ink-coverage steps (solid, 65, 50, 40, 23%) as flat tints that slide smoothly; the live river is bare paper between heavy bank lines. Single-ink and dark versions too.

Partly fixed:
4. Empty ground: with the valley walls 1.5 W from the edges and memory raised to T 600, a river that has run a while covers the screen edge to edge, and dried lakes stay as lighter hollows. But the first frame after a T 60 launch history is still a young belt on empty ground. Filling it at launch means a much longer history (I have a cheap way to try: coarse nodes and steps for the distant past) or drawing the untouched ground as textured upland, which is what the left third of the Helena reference is. I'll show the first frame as it is.

One correction to 6/7: my "slab band checked against the exhaustive version" held for the one state I tested. A later state showed it missing 4 of 44,883 texels at the joint across the period's seam. Fixed and rechecked (worst difference 4e-6 W). Field update timings are 0.5 to 0.9 ms depending on how much river is on screen.

---

Meander round 2, 1/5: the stills at true-to-life scale and the cutoff strip, to Dave's picks. Four more follow: the river's maths, the fields, the two looks' formulas, and what is still wrong.

All under scratch/meander/proto/out2/ :
- still-relief-survey-blue.png: relief, the default look, in meander-look's Sauk colours (also -rainforest, -garnet)
- still-fisk-fisk-1944.png: the old map in Fisk's four inks on cream (also still-fisk-fisk-1944-dark.png, still-fisk-sage.png, -salmon, -sage-dark: single inks, older is paler)
- cutoff/cutoff-fisk.png and cutoff/cutoff-relief.png: ten frames through one cutoff at 25 s a T, from 3 s before to 10 min after
- cutoff/frame-before-after-diff-fisk.png (and -relief): the frame before, the cutoff frame, and what changed
- first-frame-relief.png, first-frame-fisk.png: what a T 60 launch history leaves
- retina-relief.png, retina-fisk.png: a 500 x 350 pt piece at 2x Retina
- strip-minutes-relief.png, strip-minutes-fisk.png: six frames a minute apart at 25 s a T
All stills are 1512 x 982 at one pixel a point, the river 54 widths across (28 pt, 1.85% of the frame), at T 400 of a fresh run.

Against the four faults:
1. Pipe: fixed. No outline in relief; the water is the lightest thing and new ground darkens within about half a width. The water's width now varies: 22 to 42 px (10th to 90th percentile), median 28.
2. Even, strong scroll rings: fixed. They are now a few percent of brightness, two spacings beating, uneven. At one pixel a point they nearly vanish; see retina-relief.png.
3. Empty ground: fixed for a river that has run a while (history covers 66 to 90% of the screen, median 83%, with the valley walls 1.5 W from the edges and memory at T 600; dried lakes stay as lighter hollows). Not fixed for the first frame.
4. Colour wheel: fixed. meander-look's busy.py gives hues 1.00 for every new still. Relief: luma 0.25, edges 1.1%. Fisk 1944: luma 0.73, chroma 0.19.

Measured on the final code:
- River: the same model with a varying width, T 800 (20,000 steps): 630 cutoffs, no self-crossing at any of 20 checks, sinuosity 1.9 to 3.2, about 0.53 cutoffs per T on screen.
- The cutoff frame, share of a 14 W window changing more than 20 levels: relief 0.07%, Fisk 0.38% (its two heavy bank lines in the neck vanish). The frames either side: 0.000% and 0.004%. My first try at the new looks made it 1.4% and 2.6%, because a new lake changed its line weight and gained a hollow at once; both now ease in with the lake's age.
- Ordinary frame-to-frame change at 25 s a T, 1/15 s apart: relief 0.04 levels, Fisk 0.10. In 5/7 I guessed 25 s a T would land near Turing Patterns' Regrow (0.07 to 0.11) for both; that holds for Fisk only. The new relief is so low in contrast that it measures near Turing's Still (0.03) even at this pace.

The Swift sketch still times the constant-width river; the varying width adds a multiply per texel and a slightly wider band, which I have not re-timed.

---

Meander round 2, 2/5: the river's maths, complete, as the final prototype runs it (proto/meander.py). Law and constants Omega, Gamma, alpha from meanderpy, Apache-2.0, https://github.com/zsylvester/meanderpy (its migrate_one_step and README), after Howard & Knutson 1984, https://agupubs.onlinelibrary.wiley.com/doi/abs/10.1029/WR020i011p01659 (paper not read). Everything marked "mine" is my choice, tested only by the runs.

Units: channel width W = 1; time T = kl t / W. Screen sx by sy widths (54 by 35.07 for a 28 pt river on 1512 x 982 pt).

State: nodes P_i = (x_i, y_i) with half-width hw_i, i = 0..n-1. Periodic: node i+n is node i moved by (L, 0), L = sx + 20 (mine).

Start (mine): n = round(L / 0.5), x_i = -10 + L i / n, y_i = sy/2 + sum over k = 1..39 of a_k / sqrt(k) sin(2 pi k i / n + phase_k), a_k normal with deviation 0.25, phases uniform. hw_i = 0.5.

One step of size eps:
1. a = P_i - P_(i-1), b = P_(i+1) - P_i, c = a + b (neighbours wrap, adding or taking L in x).
2. Curvature k_i = 2 (a_x b_y - a_y b_x) / (|a| |b| |c|). Normal n_i = (c_y, -c_x) / |c|. (Mine: exact for uneven spacing.)
3. Upstream average, in order downstream, started 16 / (alpha 0.5) nodes before node 0: C = k_i w_i + q_i C, G = w_i + q_i G, with w_i = (|a| + |b|) / 2 and q_i = exp(-alpha |a|). U_i = C / G.
4. R_i = -k_i + 2.5 U_i (Omega = -1, Gamma = 2.5). alpha = 0.73 (meanderpy's 2 Cf / D x W with Cf 0.011, D 6 m, W 200 m).
5. The bank being eaten: B = P_i + 0.5 sign(R_i) n_i.
6. Erodibility (mine): E = exp(0.5 g(B)), g a grid of standard normal numbers, cells about 8 W, read bilinearly, wrapping in x.
7. Valley wall (mine): if sign(R_i) n_y (B_y - sy/2) > 0, E is multiplied by smoothstep((sy/2 - 1.5 - |B_y - sy/2|) / 5).
8. P_i moves by clamp(R_i E eps, -1.25 eps, 1.25 eps) along n_i.
9. Width (mine): bend = mean of |k| over the 7 nodes centred on i; want = 0.5 (0.7 + 0.8 clamp(bend / 0.4, 0, 1)); hw_i moves toward want by the share 1 - exp(-eps / 1.5).
10. T increases by eps.

Cutoff (every step live; mine except the idea): among pairs i, j (j may be in the next period) at least 12 nodes apart both ways round, with |P_i - P_j| < 1.04 (hw_i + hw_j), take the one with the least |P_i - P_j| - hw_i - hw_j. The loop is nodes i to j. The river becomes nodes j onward round to i, keeping both; the period's closing segment joins i to j. Repeat until none.

Respacing (mine), up to 4 passes: split every segment longer than 0.7 at (-P0 + 9 P1 + 9 P2 - P3) / 16, the new half-width the mean of its neighbours'; otherwise drop the far node of every segment shorter than 0.3, never two neighbours in one pass. Then shift all x by a multiple of L so their mean stays near L/2 - 10.

Step sizes: 0.04 for the launch history. Stable only while eps < spacing squared / 2 = 0.045 (my derivation; the -k term is a heat equation). Live: eps = 1 / (seconds per T x steps per second), 0.004 at 25 s a T and 10 steps a second.

Derived by me: the fastest-growing wavelength is 2 pi / (alpha sqrt(sqrt(2.5) - 1)) = 8.24 / alpha = 11.3 W along the channel.

Not from any source: every constant in steps 6 to 9, the cutoff's 1.04 and 12, the 1.25 cap, the respacing limits.

---

Meander round 2, 3/5: the fields and how they are kept, complete. All of this is mine; none of it comes from a source.

Grid: 14 texels per river width (2 pt for a 28 pt river), 756 x 491. A texel's centre is ((ix + 0.5) / 14, (iy + 0.5) / 14) in widths.

Three numbers per texel:
- stamp: the time the live channel last covered it. Starts as "never".
- lake: bank distance of the cut-off loop it belongs to. Starts at 1 (no lake).
- live: bank distance of the live channel, kept only near it.

Bank distance of a channel, for a texel centre p: the least, over the channel's segments, of [distance from p to the segment] - [half-width there, interpolated along the segment] + 0.5. So 0.5 is the bank, less is water. Each segment is drawn in the period that puts it on screen.

Every field update (each live step; every 8th coarse step during the launch history, as timed):
1. live = bank distance of the live channel, for texels out to 2 texels beyond its banks; elsewhere "far".
2. cover = clamp(0.5 + (0.5 - live) x 14, 0, 1): the share of the texel under water.
3. If cover = 1: stamp = now.
   Else if cover is more than at the last update: stamp moves toward now by the share (cover - before) / (1 - before), starting from max(stamp, now - 400).
   Else: unchanged. This is what records a bank's furthest reach to a fraction of a texel.
4. lake = max(lake, 0.5 + 3 (0.5 - live)): the river erases any lake it crosses.
5. Remember cover for next time (0 outside the band).

At a cutoff, before the loop's nodes are dropped: for texels out to 0.5 W beyond the loop's banks, lake = min(lake, the loop's bank distance). These are the numbers the live field held, so the water does not change. Keep for the lake: its texels; for each, `end`, the distance along the loop to its nearer end; rate = 1 + 80 exp(-end / 1.2); the time it was born; half the loop's length.

Every field update, per lake, with age = now - born and dT the time since the last update:
- front = (half + 2) smoothstep(age; 4.8, 16) - 1.5
- late = 40 smoothstep(front - end; -1.5, 0.5)
- every texel with lake < 0.56: lake = min(lake + (rate + late) x 0.006 x dT, 0.56)
So the ends plug in about 1 T, the body narrows slowly, then a front from each end closes it by about 16 T, and it stays at 0.56: dry, but remembered as a hollow. Forget the lake's list after 24 T.

The texture (as the Swift sketch packs it): stamp in 16 bits across red and green at 0.01 T a level; lake and live in 8 bits each. For live, 0.5 + (value - 0.5) x 14 / 4, clamped, puts the bank at mid-range. The lake needs its range up to 0.66 for the hollow, so pack it over 0.25 to 1 instead.

Rebasing: 16 bits at 0.01 T last 655 T, and memory is 600, so before the stamps run out subtract a constant from all of them and from the clock; a multiple of 15.86 T keeps the scroll phases and stage colours still (4 stages of 5 T; scroll periods 0.7 and 0.7 x 1.618). Not built. Keep the clock as a Double.

The shader reads each field through a cubic B-spline (four taps for all three), and reads the stamp once more about two texels inside any lake, down the lake field's slope, for the lake's own age: at a lake's bank the plain read is already half the old land's stamp. The prototype stands in for that second read with "the newest stamp within two texels". It is only right within two texels of the lake's bank, which is all it is used for.

---

Meander round 2, 4/5: both looks, per pixel, complete (proto/render.py). S, LK, DA are the smoothed reads of stamp, lake and live; SI is the stamp read inside a lake. All colours are meander-look's measurements (scripts/palettes.py in the meander scratchpad; their report has the source pictures and licences). The formulas and constants are mine, tuned by eye against their references; px is one pixel in widths.

Shared:
- age = now - S, capped at 600 T. lage = now - SI.
- river = smoothstep(0.5 - DA) over 0.6 px either side; lake = the same of LK, times (1 - river).

Relief (the default):
- height h = 0.25 (1 - exp(-age / 1.6)) + 0.75 (1 - exp(-age / 90)). The first term is what ended the pipe: new ground leaves river level in about half a width.
- hollow = smoothstep(0.66 - LK; 0, 0.12) x smoothstep(lage; 2, 12) x exp(-lage / 140); h falls by 0.14 x hollow x smoothstep(h; 0.1, 0.4). Old channels stay a shade lighter, and never appear at once.
- scroll = [0.6 cos(2 pi S / 0.7) + 0.4 cos(2 pi S / 1.133 + 1.3)] x fade x patch x (0.35 + 0.65 exp(-age / 150)). fade = 1 - smoothstep(2 pi |grad S| / 0.7; 0.7, 1.5) per pixel, which removes them where too fine to draw and across scarps. patch = 0.55 + 0.45 x soft noise in cells about 70 pt.
- colour = ramp of h + 0.02 scroll through, at h = 0, 0.10, 0.32, 0.52, 0.72, 0.90, 1: (120,178,192) (52,130,151) (24,93,115) (14,76,97) (10,64,83) (4,46,63) (1,30,42).
- ground untouched in memory (age past about 480 to 590): fades to (0,22,31), lifted toward (4,46,63) by three octaves of soft noise.
- light: shading height 0.35 h + 0.03 scroll; normal = (-5 d/dx, -5 d/dy, 1) with the slope per texel; light from the upper left (-0.55, -0.62, 0.56); colour x clamp(1 + 0.9 (n.l - 0.56) x away, 0.72, 1.3). away fades the light to nothing within 4 px of any water, so no bank has a rim.
- water: river (153,200,211); a lake drifts 35% toward (52,130,151) over lage 0.3 to 4.
- vignette 0.22; everything x 0.86.

Old map (Fisk):
- stage k = floor(S / 5 T). ink = one of sage (188,199,139), salmon (215,114,97), grey-teal (154,180,159), straw (221,208,123), by k mod 4. Paper (235,224,196). Line ink (89,75,59).
- cover, by age in stages (age / 5), straight lines between: 0 to 1.5: 1.0; 3: 0.65; 6: 0.5; 12: 0.4; 30: 0.23; 90: 0.12; 120: 0. These are Fisk's solid, hatch and dot coverages as flat tints, sliding with age so nothing steps.
- colour = paper x (1 - cover) + ink x cover, both with 3% paper grain.
- thin lines where stages meet (within about half a pixel of a whole number of S / 5) and along scarps (S / 5 changing by more than about 0.35 to 0.8 a pixel), at 45% ink, less on pale land; hachures every 1.4 T at 14%.
- river and lakes: bare paper (244,237,216). Heavy line where |DA - 0.5| is under 0.9 to 2.2 px. A lake's line is the same heavy one when new, thinning to 0.3 to 1.3 px at 70% over lage 0.5 to 6.
- single ink: two near shades of one ink alternating by stage. Dark: paper (27,24,20), river (166,158,138), line (80,76,67), inks (100,106,74) (123,65,55) (82,96,84) (110,104,61).

What makes neither look pop: a stage's colour is fixed to the land once laid; cover, height, hollows and line weights depend only on ages, which move smoothly; the water's edge comes from fields that hand over the same numbers at a cutoff.

---

Meander round 2, 5/5: what is still wrong, what changes in the plan, and what is open.

Still wrong in the new renders:
- Lakes. A lake's drying ends are blocky, and where the river re-crosses a fresh oxbow near the neck it leaves ragged scraps (cutoff/cutoff-fisk.png: the 10 s, 30 s and 1 min frames). This is now the most visible flaw. I'd give each lake's end a taper worked out along its length rather than per texel, and dry a part-eaten lake quickly.
- A hairline of land shows where a lake meets the river (retina-relief.png). Letting the lake run a texel under the river's edge would close it.
- Banks are faceted on tight bends at Retina: straight chords up to 0.7 W long. Draw the fields from the centreline subdivided along its Catmull-Rom curve.
- The first frame is a young belt on empty ground (first-frame-relief.png). It is dark, textured ground, and the left third of the Helena reference looks like that, but it is not the edge-to-edge floodplain of a river that has run two hours.
- Relief is soft next to real lidar: no levees, no islands or bars in the channel, width varying 2x rather than 2 to 3x, scroll bars invisible below Retina.
- In the old map, lakes are bare paper like the river, so a fresh oxbow reads as a second river until its line thins.

Changes to the plan in 6/7:
- River size slider: 28 pt (54 widths across) is already true to life, so the default sits at the small end and the slider zooms in from there, to about 56 pt. Changing it rebuilds the river. Keep 14 texels a width and let the texel grow from 2 pt to 4 pt as it zooms, so the cost stays the same.
- Look: Relief by default, Old map as the other choice; same texture, a different shader branch or source.
- Colors: two lists, one per look. Old map: Fisk 1944, Sage, Salmon, grey-teal, each with a dark version. Relief: Survey Blue, Rainforest, Garnet, Amethyst from meander-look's list.
- Valley walls 1.5 W from the edges, memory T 600.
- The shader needs the lake field over a wider range than I first packed it (3/5).
- Each node now carries a half-width; the Swift sketch does not have that yet.

Launch history, three choices for the empty first frame:
1. Leave it: T 60, about 0.2 s as timed, young belt on dark ground.
2. A longer history. The river alone costs about 0.045 ms a coarse step, so T 400 is about 0.45 s before any fields. Too slow as it stands.
3. The distant past cheaply: coarser nodes and bigger steps for the river, plain filled quads for its stamps, then T 60 exactly. Stamps are a maximum, so order doesn't matter. Not tried; my guess is under 0.1 s extra.

Open, for Dave:
- Pace. Relief at 25 s a T measures as still as the Turing look he found finished. Faster, or is the old map's liveliness the answer for those who want motion?
- The first frame: which of the three above.
- Is the bold zoomed river still wanted now that the default no longer reads as a pipe?

Verified this round by running: the varying-width river to T 800, both new looks, the cutoff frame. Not verified, as before: the shader as a shader, GPU cost, the upload, 15/30/60 fps. No real river's migration rate comes from me; meander-look's Mamore figure (about 0.03 widths a year) should set years per minute.

---

Your targets are in my new Meander renders, and one of your measurements needs a caveat: the channel's water was never twice too wide.

Width: scripts/width.py thresholds brightness, so on my first relief it counted the pale new ground beside the water as channel. Measuring the water's own colour with a distance transform, t1 is 16 px of 1512 (1.06%, 94 widths across) and t5, t6 and every later still are 28 px (1.84%, 54 across), inside your 40 to 55. The fault was real, though: the ground stayed pale for about 8 widths behind the moving bank, so it read as a fat pipe. I've told team-lead the scale was already right and the look was wrong.

What changed, from your message:
- no outline in relief; new ground now leaves river level within about half a width
- the water's width varies along the river, 22 to 42 px (10th to 90th percentile)
- scroll bars a few percent of brightness, uneven, about 0.2 W apart (finer than that is below my texture at one pixel a point)
- dried oxbows stay as lighter hollows; the floodplain is covered edge to edge once the river has run a while
- relief in your Survey Blue (Sauk) colours; the map in your four Fisk inks on cream with your line ink, older paler by your coverage steps as flat tints, the river bare paper with heavy bank lines; single-ink and dark versions

Your busy.py on the new stills: relief luma 0.25, edges 1.1%, hues 1.00; Fisk 1944 luma 0.73, chroma 0.19, hues 1.00.

Stills, if you want to put them beside the references: scratch/meander/proto/out2/still-relief-survey-blue.png, still-fisk-fisk-1944.png, retina-relief.png, retina-fisk.png.

Still short of your references: no levees, no bars or islands in the channel, width varying 2x not 2 to 3x, and the relief is much softer than real lidar.

---

Meander round 3: I closed meander-look's first gaps on each look in a third set of renders, and it shows that lakes are now the weak point and need a different design. Nothing here changes Dave's picks.

New pictures, under scratch/meander/proto/out3/ (same names as out2):
- still-relief-survey-blue.png, still-fisk-fisk-1944.png, retina-relief.png, retina-fisk.png, first-frame-*.png, strip-minutes-*.png
- cutoff/cutoff-relief.png, cutoff/cutoff-fisk.png
Round 2's code is kept as meander-v2.py and render-v2.py; out2 is unchanged, so the two rounds can be compared.

Better than out2:
- Relief banks are lopsided now, as real ones are: a clean step up on the cut side, a gradual rise on the bar side. The land beside a bank is read two texels further from the water, so it no longer blends with the channel.
- The belt's edge is scalloped: each valley wall wanders in and out by up to 5 W along the valley, so the dark margins are no longer straight.
- Relief has arcs that show at a glance: a broader set of scrolls every 2.9 T, cut across by later ones.
- The old map follows Fisk's own order: stages of 11 T (the river moves 2 to 4 widths in one, as between his), the four newest solid in sage, salmon, grey-teal and straw, then runs of four stages in one ink at 65, 50, 40 and 23%.
- Cutoff frame, one cutoff measured: relief 0.03% of the window over 20 levels, old map 0.24%.

Worse, or newly visible:
- Lakes. In cutoff/cutoff-relief.png the frames at 1 and 2 minutes show a cut-off loop breaking into jagged scraps after a second cutoff beside it, and in still-fisk-fisk-1944.png the scraps are bare paper on solid salmon. This is the first thing the eye lands on.
- I widened the channel's range to 0.6 to 1.7 W; tight bends now swell into blobs (same strip). I'd go back to 0.7 to 1.5.
- The old map is blotchier and louder than out2's: big solid salmon areas (busy.py hues 0.92, was 1.00). It is truer to Fisk; out2's thin stripes are calmer. Stage length is one constant, so it could be a setting.
- Fisk colours land by how many stages old it is, so every band must change colour each stage. I slide the whole sheet over the last third of each stage (about 90 s in every 4.6 min at 25 s a T). That is a slow global colour change Dave hasn't seen; out2's rule (colour fixed to the land) has none.

The lake redesign I'd build instead (not tested):
- Keep each lake as a short polyline with per-node half-widths, like the river, and draw it with the same distance routine. Its widths shrink with age and taper to nothing at the ends, so every edge is as smooth as the river's.
- Where the live channel covers a lake's nodes, delete them; the lake splits into two that taper. No per-texel erasing, so no scraps.
- River and lakes then share one water field (the river is just the lake of age zero), which frees the fourth texture byte for the hollow.
- Cost: about 15 lakes of 40 nodes is one more band the size of the river's, and it only needs redrawing about once a second.

Run behind these: T 400, 318 cutoffs, no self-crossing at 10 checks.

The formulas that changed, so they survive without the scripts, are in the next message.

---

Meander round 3, the formulas that changed from round 2's messages 2/5 to 4/5. All mine, tuned by eye against meander-look's references; Fisk's order of inks and his coverage steps are meander-look's reading of his legend.

River (replaces steps 7 and 9 of 2/5):
- Valley wall. Each wall stands in from its outermost line by in(x) = 2.5 (1 + tanh(wave(x))), wave(x) = sum over k = 2..7 of a_k / sqrt(k) sin(2 pi k (x + 10) / L + phase_k), a_k standard normal, a separate set for the top and bottom walls. A bank moving outward has its erodibility multiplied by smoothstep((sy/2 - 1.5 - in(B_x) - |B_y - sy/2|) / 5).
- Width: want = 0.5 (0.6 + 1.1 clamp(bend / 0.4, 0, 1)). Too wide at tight bends; I recommend round 2's 0.5 (0.7 + 0.8 clamp(...)).

Shader reads (adds to 3/5): a third read of the stamp, two texels further from the nearest water, the river's or a lake's. Use it in place of the plain read fully within one texel of a bank, not at all by three texels, sliding between. The prototype stands in with "the oldest stamp within two texels". A lake's bank has to count as well as the river's, or the land beside a loop changes on the frame the loop is cut off (it did: 0.20% of the window, against 0.03% once fixed).

Relief (changes to 4/5):
- age for the height comes from that outward read; the scroll phases still use the plain read.
- h = 0.25 (1 - exp(-age / 2.5)) + 0.75 (1 - exp(-age / 90)).
- add to scroll: 0.9 cos(2 pi S / 2.9 + 0.7) x [1 - smoothstep(2 pi |grad S| / 2.9; 0.7, 1.5)] x (0.5 + 0.5 exp(-age / 200)).

Old map (replaces the colour rule in 4/5):
- stage length 11 T. k = floor(S / 11); the present stage K = floor(now / 11); stages old j = K - k.
- land j stages old: j = 0, 1, 2, 3: sage, salmon, grey-teal, straw, solid. j = 4..7: grey-teal at 0.65, 0.5, 0.4, 0.23 of the ink over paper. j = 8..11: salmon, the same four. j = 12..15: sage. j = 16..19: straw. Older: straw at 0.23 falling to nothing over 34 more stages.
- colour = the j colour sliding to the j + 1 colour by smoothstep(fraction of now / 11; 0.67, 1). Every band slides together, so nothing steps when a stage ends.
- single ink: coverage by j through 0: 1, 3: 1, 4: 0.65, 8: 0.5, 12: 0.4, 16: 0.23, 30: 0.12, 54: 0, two near shades alternating by stage.
- scarp lines where S / 11 changes by more than about 0.16 to 0.36 a pixel; bank lines where |DA - 0.5| is under 0.5 to 1.5 px (lighter than round 2's).

Unchanged: everything else in 2/5 to 4/5, including the lake rules, which are the part I would now replace.

What I have not done from meander-look's list: islands and bars in the channel, levees, and making old courses cross each other more (that is the river's own behaviour, not a drawing choice).

---

Your bank asymmetry and stage length are in a third set of renders, and they exposed the lakes as the weak point.

Pictures: scratch/meander/proto/out3/ (still-relief-survey-blue.png, still-fisk-fisk-1944.png, retina-*.png, cutoff/cutoff-*.png). out2 is unchanged for comparison.

Done from your list:
- Relief 1: the cut bank is a clean step and only the bar side ramps (the land beside a bank is read two texels further from the water).
- Relief 3: the valley walls wander in and out by up to 5 W, so the belt's edge is scalloped.
- Relief 2, in part: a broader set of scrolls every 2.9 T gives arcs that cut across each other at a glance.
- Fisk 1: stages are 11 T, so the river moves 2 to 4 widths in one.
- Fisk 2: your order: four solids, then runs of four in one ink at 65, 50, 40, 23%. Because that colours land by how many stages old it is, the whole sheet slides to the next colours over the last third of each stage; team-lead knows that is a choice for Dave.
- Fisk 3, in part: one lighter bank line each side; width 0.6 to 1.7 W (too much: tight bends swell, I'd go back to 0.7 to 1.5).

Not done: islands and bars, levees, more crossing of old courses.

What got worse: cut-off loops break into jagged scraps when a second cutoff or the river crosses them (cutoff/cutoff-relief.png at 1 and 2 min), and in the map they are bare paper on solid salmon. I've proposed to team-lead drawing lakes as shrinking, tapering polylines with the river's own routine instead of per-texel erasing. Your busy.py on out3: relief luma 0.23, edges 1.1%, hues 1.00; Fisk 1944 luma 0.72, edges 5.2%, hues 0.92.

---

The changed-formulas message is already in your inbox, and I have stopped: it went out straight after the round 3 message, titled "Meander round 3: the formulas that changed" (wall scallop, width, the outward stamp read, relief height and broad scrolls, the old map's stage length and order of inks).

Nothing is running. out2, out3, meander-v2.py, render-v2.py and the rest of the meander scratchpad folder are untouched and will stay so. No round 4, no lake redesign, and no further messages to meander-look until you say.

For when Dave decides: the cheap distant past for the first frame is still untried (coarse nodes and steps for the river, plain filled quads for its stamps, then T 60 exactly), so its cost and look are guesses until someone runs it.
