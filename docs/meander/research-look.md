# Meander: the look research

A research agent's report as it was sent on 2026-10-10, unedited, kept so its detail and sources aren't lost. The plan beside it is the summary and has Dave's decisions; where the two differ, the plan is later. `scratch/` was the session's temporary folder: the scripts and pictures worth keeping were copied into this folder, the rest (downloaded references, video clips) is gone and its source URLs are below.

Measured targets from the real references, for your Meander renders (from meander-look; full report goes to team-lead).
I scored your proto/t1-relief.png and t1-fisk.png against real pictures with scratchpad/meander/scripts/busy.py (run: python3 -I scripts/busy.py <img>). Side by side: scratchpad/meander/work/proto-vs-ref.jpg.

Real references live in scratchpad/meander/refs/. The most useful one for you: refs/usgs3dep-mississippi-helena-rem-2400.jpg and ...-pointbar-rem-2400.jpg, which I rendered from public-domain USGS 3DEP elevation (the float TIFFs are beside them, 23.6 m/px and 5 m/px).

What differs most, relief look:
- Channel width: yours is about 3.5-4% of the frame width. The references (7 lidar pictures, Fisk's sheet 6) sit at 1.8-2.5%, i.e. 40-55 channel widths across the frame.
- The real channel has no outline and its width varies 2-3x along its length (wide at bend apexes with bars and islands, narrow at crossings). A constant-width pale tube with a dark edge reads as a pipe.
- Scroll bars: on a real Mississippi point bar I measured crest spacing 130-155 m (0.12-0.17 channel widths; Strick et al. 2018 give a 167 m mean) and crest-to-trough relief 0.5-1 m median, up to 2-3 m, on a bar surface spanning 6-8 m. So they are fine, irregular, fanning and LOW contrast (a few percent of brightness), not even onion rings. Older sets are smoother and truncated by younger ones.
- The real floodplain is textured edge to edge: older belts, oxbow lakes as bright crescents at river level, levees as darker rims. Yours is a belt on flat empty ground.
- Brightness: your relief is luma 0.19 mean, edges 3.3%: good, calmer than the lidar references (0.30-0.47) and right for Atrium.

Fisk look:
- Your palette spans the wheel (my one-family score 0.44; chroma 0.20). Fisk used four muted inks on cream, measured on his legend: sage (188,199,139), salmon (215,114,97), grey-teal (154,180,159), straw (221,208,123), paper (235,224,196), line ink (89,75,59), not black.
- He shows age by ink coverage within one hue: solid, then hatch at about 65%, 50%, 40%, then dots at 23%. Older = paler. Flat tints at those blends do the same job without hatching (which shimmers when it moves).
- The present river is bare paper, the lightest thing, with no fill colour. Heavy lines (0.5-0.65 mm) only on final banklines; everything else 0.15-0.3 mm.
- Each spot gets ONE stage: the last time the river was there (a planar map, nothing translucent).

Motion check from NASA's Mamoré pair (1985 vs 2014, 29 years, refs/eo-mamore-*.jpg, overlay in work/mamore-change.png): only 24% of the 1985 channel is still channel; moved parts sit a median 0.9 channel widths away, 90th percentile 3.4. So about 0.03 widths a year typical, 0.12 on fast bends.

Palettes with RGB for Dark and Light: scripts/palettes.py prints them, swatches in work/palette-swatches.png.

---

Meander look 1/9: make lidar relief the default look, and put three choices to Dave as mock-ups.
Everything is in scratch/meander/ (refs/, scripts/, work/). "Measured" below means I measured it on the downloaded files.

**Why relief should be the default**
- I scored each reference at 1920 px wide (scripts/busy.py). Fisk's sheets have 56-59% of pixels on a brightness edge (hatching, line work, type) and a mean brightness of 0.71-0.75. The lidar relief pictures have 2-8% edges. Fisk's maps are beautiful but they are the busiest thing I measured; relief is calm by nature.
- Every relief reference is one colour family already: white river, through one hue, to near-black high ground. That is Dave's "colours in one family" with no adapting.
- There is a real Light Mode precedent: the Washington Geological Survey's Yakima picture is pale ground with the river as the darkest thing.
- One caution: the relief references are brighter than Atrium's bar (mean brightness 0.30-0.47, river pure white). Hold the river near 0.7-0.75 and the mean near 0.15-0.20.

**The best single reference, and it is public domain**
I built a relative elevation model of the Mississippi near Helena, Arkansas from USGS 3DEP elevation (one request, no key): refs/usgs3dep-mississippi-helena-rem-2400.jpg and a close-up of one point bar, refs/usgs3dep-mississippi-helena-pointbar-rem-2400.jpg. It is the same ground as Fisk's sheet 6, so the two looks can be compared on one real place.

**Mock-ups worth putting to Dave**
1. **Relief** (default): height above the river in one hue, Dark and Light. Palette Survey Blue or Rainforest.
2. **Fisk bands, one ink**: flat bands by age in a single ink on cream paper, older = paler, the river left as bare paper, thin warm-black banklines on the present channel only. No hatching, labels or grid.
3. **Bands over relief**: mock-up 2 with faint scroll-bar shading under it. I expect this to be the prettiest, and it is one renderer with two layers.
Also worth one frame so Dave can rule it in or out: Fisk's own four inks ("Fisk 1944"), which breaks the one-family rule but is the look he named. I'd skip a true-colour satellite look (message 5).

**First renders against the references** (sister agent's proto/t1-*.png, sheet in work/proto-vs-ref.jpg; I sent meander-sim the numbers)
- Relief: brightness 0.19 and 3.3% edges, which is right. But the channel is about 3.5-4% of the frame width against 1.8-2.5% in the references, it has a dark outline and constant width (reads as a pipe), the scroll bars are even, high-contrast rings, and the ground beyond the belt is empty.
- Fisk: colours span the wheel (one-family score 0.44, where the relief pictures score 1.0) and every lobe has the same dark outline. Real Fisk is four muted inks, mostly as tints.

---

Meander look 2/9: Fisk's maps are public domain, all 15 sheets are on Wikimedia Commons at about 10,000 x 14,000 px, and I measured the palette from the legend.

**Status and scans**
- Commons has Plate 22 sheets 1-15, each tagged Public domain, credited "US Army Corps of Engineers – Mississippi River Commission, Harold N. Fisk", scanned by LSU Law Center (https://biotech.law.lsu.edu/climate/mississippi/fisk/fisk.htm). Example: https://commons.wikimedia.org/wiki/File:Ancient_Courses_Mississippi_River_Meander_Belt,_Plate_22_Sheet_06.jpg
- One nuance: the title block (read on the scan) says "to accompany report of Harold N. Fisk, Ph.D., consultant, Louisiana State University", published by the Mississippi River Commission, 1944. A consultant's work is not automatically a federal work; I saw no copyright notice on the title blocks or legend I examined, and did not check renewal records. NASA/JPL and the Public Domain Review also treat it as public domain (https://pdimagearchive.org/images/03c7ce69-c0c7-4131-b0f7-85924627a30a).
- The Corps' own site (lmvmapping.erdc.usace.army.mil) failed with a certificate error, so I could not check it. Commons also holds the whole report as a PDF from the Corps' digital library (item USACE-p266001coll1-10015).

**Palette, measured on the legend of sheet 1** (scripts/legend.py; a second scan of sheet 7 by JPL differs by about ±15 per channel, brighter and more saturated)
- Paper (235,224,196). Line ink (89,75,59): warm brown-black, never pure black.
- Stage 20 (1944): bare paper, black outline. 19 (1880): solid sage (188,199,139). 18 (1820): solid salmon (215,114,97). 17 (1765): solid grey-teal (154,180,159); his "blue" reads as teal on aged cream. 16: solid straw (221,208,123).
- Then each ink fades with age through four patterns: 15-12 teal, 11-8 salmon, 7-4 sage, as wide hatch, medium hatch, fine hatch, dots. Measured ink coverage 65%, 50%, 40%, 23%. The eye-blended colours, salmon for example: (227,156,134), (227,175,149), (228,186,159), (231,206,175).
- Older still: 3-1 olive with vertical stripes, blend about (195,202,135) to (216,211,136); J-H orange stripes on straw, (222,167,114) to (226,196,125); G-D dark crimson, about (179,120,103) to (214,122,104). A-C, "older than the meander belt": black horizontal ruling.
So: four inks, about 26 stages, and age told by coverage. The mapped courses are 55-64 years apart (1765, 1820, 1880, 1944, read off the legend).

**Layering** (seen on full-resolution crops): no transparency. Each spot belongs to one stage, the last time the river was there; younger courses cut across older ones with a crisp line.

**Line weights and hatching** (measured on the full-resolution sheet 6: scale bar gives 354 px a mile, so 4.55 m a pixel, about 350 dpi)
- Final banklines 7-10 px: 0.5-0.65 mm on paper, 30-45 m on the ground. Contours and section lines 2-4 px: 0.15-0.3 mm. Stage lines long-dashed, uncertain ones dotted.
- Wide hatch about 2.2 mm apart at roughly 40 degrees, about 140 m on the ground.
- The 1944 river is 0.9-1.2 km wide, 2-2.6% of the sheet's 45.7 km width.

**Also on the sheet**: title block and "Plate 22 Sheet n", scale bar in miles, latitude and longitude ticks on the border, bold stage numerals in each band, cutoff symbols (a circled stage number with arrows), the river's name letter-spaced along it, and a base map of contours, section-line grid, county names, towns and levees, with the bluffs in grey hachures.

---

Meander look 3/9: what makes Fisk's maps beautiful, which conventions survive on a calm desktop, and a Dark Mode version of his palette.

**What makes them beautiful** (my reading, after measuring)
- The history is the picture. The present river is a thin pale ribbon; the eye lives in the overlapping older courses.
- Economy: four soft inks do the work of 26 stages, so the sheet stays in harmony however tangled it gets. Tints outnumber solids, so most of the colour is pale.
- Hierarchy: a few heavy banklines, everything else hairline.
- The river is the absence of ink. The calmest, lightest thing on the sheet is the subject.
- Warmth: cream paper and brown-black ink, nothing pure white or black.

**Conventions that survive on a calm, dim desktop**
- One stage per spot, banded by age, with crisp boundaries. This is the look.
- Age as paleness within one ink. It is the one-family rule already, per ink.
- The river as bare ground colour, not a blue fill.
- Warm off-black lines, heavy only on the present banks.
- Cream paper for Light Mode: (235,224,196) is far gentler than white.

**Conventions that will not survive**
- Hatching and stipple. On a moving picture a 5-point hatch shimmers and aliases, and it is what makes the sheets 56-59% edges. Use the blended tint instead: I measured those blends, so the colours stay his.
- Stage numerals, place names, contours, the section grid. Text and fine line work are busy, and labels that move with the river would be worse.
- All four inks at full strength together. Salmon at brightness 0.57 on paper at 0.88 is the loudest thing on the sheet.
- A possible keepsake, off by default: a small still cartouche in one corner (river name, scale bar), like the title block. Worth one mock-up at most.

**A Dark Mode version** (computed in scripts/palettes.py, swatches in work/palette-swatches.png)
Rule: the paper becomes his line ink darkened, the inks keep their hue and saturation at about 0.40 brightness, age still fades toward the ground by the measured coverage steps, and the river becomes the dimmed cream paper, the lightest thing on screen.
- Ground (27,24,20). River (166,158,138). Lines (80,76,67).
- Sage, oldest to youngest: (44,43,32) (56,57,42) (64,65,47) (74,77,55) (100,106,74).
- Salmon: (58,38,32) (81,49,42) (95,56,47) (115,65,55) (163,87,74).
- Teal: (42,43,37) (53,57,50) (59,65,57) (69,77,68) (91,106,94).
- All four inks ("Fisk 1944 · Dark"): straw (110,104,61), teal (82,96,84), salmon (123,65,55), sage (100,106,74).
The Light versions are his own measured values: paper (235,224,196), river a touch lighter (244,237,216), and for example salmon (230,199,173) (227,180,156) (225,169,146) (222,152,132) (215,114,97).

**A design consequence for the renderer**
Fisk's partition is "when was the river last here", cut into stages. Relief is the same history read as height. So one stored field, the age of last occupation per pixel, can drive both looks, and mock-up 3 (bands over relief) costs nothing extra.

---

Meander look 4/9: lidar relief. Seven openly licensed references by Daniel Coe plus two public-domain ones I rendered from USGS data, with their colour ramps, lighting and scale measured.

**Licences (verified per file on Commons)**
- Coe's personal pictures are not open: Colossal says "All images © Dan Coe", and his Flickr uses CC BY-NC-ND (https://www.thisiscolossal.com/2023/10/dan-coe-lidar-rivers/). Reference only.
- His work for the Washington Geological Survey is on Commons as CC BY-SA 2.0, from the Washington DNR Flickr account, at 7200 x 4050. I downloaded seven at 3840 px (list in message 9). Fine as references; share-alike makes them unsuitable to ship.
- USGS 3DEP elevation is public domain (https://www.usgs.gov/3d-elevation-program). My two renders from it carry no restriction.

**Colour ramps, measured** (scripts/ramp.py: median colour at each brightness, dark to light)
- Sauk, blue: (0,24,34) (4,46,63) (14,76,97) (30,104,127) (52,130,151) (81,155,173) (115,178,193) (153,200,211) (192,222,229) white.
- Quinault, green: (2,23,17) (0,47,37) (14,80,65) (31,109,90) (52,132,113) (81,159,140) (114,181,166) (151,202,192) (190,224,217) white.
- Chehalis, garnet to cream: (33,10,14) (81,25,38) (100,54,59) (120,81,79) (143,108,101) (168,135,126) (189,160,149) (210,187,173) (230,213,199).
- Okanogan, plum to peach: (28,15,31) (58,33,63) (92,51,79) (131,74,107) (165,100,111) (185,128,123) (201,157,138) (217,184,172).
- Yakima, the Light example: ground (241,245,247), then (206,219,232) (177,194,218) (160,163,201) (153,134,184), river (107,74,122).
- Skagit and Sol Duc run through two hues (purple, coral, cream), like a "magma" ramp: louder, and less in one family.
In all of them the river is the lowest and lightest thing, and brightness falls with height above the water. In the Dark pictures 23-62% of the frame is darker than 0.25 and 7-20% brighter than 0.75.

**Lighting**: these are colour-by-height first. Hillshade only shows on the hills, lit from the upper left (seen by eye, not stated by the Survey). On the floodplain the relief is too small to cast shade, so the detail is the ramp alone, with most of its range spent on the first few metres above the water. My render used height^0.6 over 12 m plus a faint north-west hillshade at 8x exaggeration (scripts/rem.py).

**How features read** (from my 3DEP render, real data)
- Scroll bars: fine concentric arcs that fan and converge. On a Mississippi point bar I measured crest spacing 130-155 m and crest-to-trough relief 0.5-1.0 m median, up to 2-3 m, on a bar spanning 6-8 m of height (scripts/scrolls.py, four transects at 5 m a pixel). Strick et al. 2018 give a 167 m mean for the Mississippi (https://research.brighton.ac.uk/en/publications/morphology-and-spacing-of-river-meander-scrolls/). In brightness that is a ripple of a few percent.
- Oxbow lakes: crescents at the river's own brightness, since their water sits at river level. Part-filled ones are a mid tone with a bright thread.
- Levees: darker (higher) rims beside channels, fading over a few channel widths.
- Older belts: darker and smoother with age, cut across by younger ones. High ground: near black.
- The whole floodplain is textured edge to edge, yet edges are only 1-2% in my renders.

**Scale** (brightness profiles across the channel): the channel is 1.8-2.5% of the frame width in Coe's pictures, matching Fisk's 2-2.6%. So frame the river at 40-55 channel widths across: about 28-38 points wide on a 1512-point screen.

---

Meander look 5/9: a true-colour satellite look is not worth offering as a third look, but it makes a good palette; and real meander motion suggests a pace of about one simulated year every 9 seconds.

**Satellite, true colour** (public domain: NASA Earth Observatory's Mamoré pair, https://science.nasa.gov/earth/earth-observatory/meandering-in-the-amazon-84833, and a still from NASA SVS's Ucayali time-lapse, https://svs.gsfc.nasa.gov/15021)
- Measured: the Ucayali over unbroken forest is calm (brightness 0.27, 2.5% edges, very low colour). The Mamoré over savanna is not (0.42, 17% edges, white salt lakes and pale pasture).
- Why not a look of its own: it is two families (forest green, sediment tan); it only convinces with photographic canopy texture, and a real photo cannot migrate, so the ground would have to be synthesised to Atrium's photoreal bar; and scroll bars show as stripes of vegetation age, which is a second simulation.
- What to take from it: a "Landsat" palette on the relief renderer. Measured colours: forest (48,63,52) and (59,85,61), young growth (79,104,75) and (112,130,93), fresh bars (168,172,125) to (220,208,171), river tan (209,170,103), black-water oxbow (30,29,46).

**What moves, from the Mamoré in 1985 and 2014** (29 years; scripts/mamore.py, overlay work/mamore-change.png)
- Only 24% of the 1985 channel is still channel in 2014.
- The parts that moved sit a median 0.9 channel widths from the new channel, 90th percentile 3.4 widths. That is about 0.03 widths a year typically and 0.12 on the fastest bends.
- Seen in the pair: bends grow outward and shift down the valley; whole loops are abandoned as oxbows; new pale bars fill the inside of bends; abandoned loops turn from pale (muddy) to dark or green.
- NASA on the mechanism (Sylvester and others, seven Amazon rivers, about 30 years of Landsat): "the sharper the bend, the tighter the bend, the faster it moves", with the fastest movement downstream of the sharpest curvature (https://science.nasa.gov/missions/landsat/sharp-bends-make-rivers-meander-as-landsat-attests).
- I did not download the time-lapse video itself (images only), so its pacing is from its description: 1985-2023 in a short clip. At that rate a river writhes like a snake, which is striking and not calm.

**What the eye follows**: the channel, as the highest-contrast line; a neck narrowing before a cutoff (the one moment of suspense); the cutoff, the only sudden change; then the slow fade of the lake.

**A pace that feels alive but calm** (my proposal, from the numbers above)
- With the channel 30 points wide, 1 simulated year every 9 seconds moves the fastest bends 0.4 points a second and typical banks 0.1. Galaxy drifts at 3-4 points a second (docs/galaxy.md), but as a soft texture; a crisp bank needs to be much slower. You see it has changed when you look back, not that it is crawling.
- The Ucayali had 13 cutoffs in 31 years over 1,300-1,500 km (https://science.nasa.gov/missions/landsat/the-secret-lives-of-migrating-rivers/). For about 100 km of channel in frame that is one roughly every 30 years, so one every 4-5 minutes at this pace; a Mamoré-like river more often.
- A Fisk stage (55-64 years) is laid down every 8-10 minutes. An oxbow lasting a century lingers 15 minutes. The belt is reworked over hours, so it never repeats.
- Soften the cutoff: open the breach over 5-10 seconds and fade the loop from river tone to lake tone, or it will be the one flashy moment.
- Give it a Speed setting (0.25-4x), and check frame strips, not stills.

---

Meander look 6/9: real rivers' numbers. Thinner than I wanted: three publishers refused the fetch, so some figures come from search summaries or my own measurements, each marked.

**Rules of thumb for any meandering river**
| Quantity | Value | Source |
|---|---|---|
| Wavelength | 11.0 × width^1.01 (Leopold and Wolman 1960); 7.5 × width^1.12 (Williams 1986): about 10-14 widths | read: https://www.ars.usda.gov/ARSUserFiles/6112/meanderShapeAndTheDesign.pdf |
| Bend radius | most often 2-3 widths; a third of 79 bends under 2 | Williams 1986 abstract: https://pubs.usgs.gov/publication/70015687 |
| Belt width | 15-18 channel widths | https://en.wikipedia.org/wiki/Meander |
| Scroll-bar spacing | about half the channel width on average, across rivers 55-2,042 m wide | Strick et al. 2018: https://research.brighton.ac.uk/en/publications/morphology-and-spacing-of-river-meander-scrolls/ |
| Oxbow lifetime | a few months to several centuries; chute cutoffs fill 10 times faster than neck cutoffs; plugs at the ends within months to a few years | https://core.ac.uk/works/134738703 and the search summary of Hooke 2008 |
| Sinuosity | joined semicircles are 1.57 | https://en.wikipedia.org/wiki/Sinuosity |

**Lower Mississippi**
- Width 0.9-1.2 km (measured on Fisk's sheet 6 with its scale bar).
- Migration 45.2 m a year in the northern reach and 59.1 in the delta, from surveys of 1877-1924 (Hudson and Kesel 2000, via a search summary of https://www.nature.com/articles/35014721, which I could not open). About 0.04-0.055 widths a year.
- Settled bend radius 3-4 widths (Hudson's dissertation: https://repository.lsu.edu/gradschool_disstheses/6741).
- Scroll spacing 167 m mean (Strick, above); I measured 130-155 m, so 0.12-0.17 widths here, well under the half-width average. Relief 0.5-1 m, up to 2-3 m (measured).
- Sinuosity today 1.31 near Helena (measured: 53.0 km of USGS NHD flowline over 40.6 km). Sixteen artificial cutoffs shortened Memphis to Baton Rouge by 170 of 680 miles (https://ascelibrary.com/doi/10.1061/TACEAT.0006144), so roughly 1.7 before them (my inference).
- Coloured belt on sheet 6 spans the sheet, about 40 widths (measured), wider than the rule of thumb because it stacks many belts.
- Oxbows last: False River was cut off about 1722 and is still a lake (https://en.wikipedia.org/wiki/False_River_(Louisiana)).

**Mamoré, Bolivia**
- Width about 480 m, if NASA's image is at Landsat's 30 m a pixel (measured, with that assumption).
- Migration 0.03 widths a year typical, 0.12 on fast bends (measured, 1985-2014): about 15 and 55 m a year.
- Below the Rio Grande confluence it migrates 1.7 times faster with twice the cutoffs; Andean-fed rivers migrate about four times faster than lowland ones (Constantine et al. 2014, via NASA: https://science.nasa.gov/earth/earth-observatory/meandering-in-the-amazon-84833).

**Ucayali, Peru**: width 400-1,200 m (https://en.wikipedia.org/wiki/Ucayali_River); 13 cutoffs in 31 years over 1,300-1,500 km (NASA, message 5). I could not get its migration rate: the paper (doi 10.1002/2016EA000196) returned 403.

**Koyukuk, Alaska**: average migration 0.52 m a year (a search summary, source page not opened); near Huslia 0-40 feet a year over 2016-2022 (https://arcticrivers.caltech.edu/documents/34248/Huslia_erosion_forecasts.pdf); permafrost cuts erosion by 47% (Geyman et al. 2024, doi 10.1038/s41586-024-07978-w). Width not found. It moves perhaps a tenth as fast as the Mamoré in widths a year, so as a preset it is a different look (many lasting lakes, crisp scrolls), not a different speed.

**The gap, and how to close it**: Greenberg and Ganti's dataset has width-normalised migration rates for 139 rivers under CC0 (doi 10.5061/dryad.jq2bvq8g3, 35 MB). I did not download it (images only). One table from it would fill this in consistently.

---

Meander look 7/9: real data. Seeding the simulation from a real river's present course is practical and tiny; replaying a recorded history is not a wallpaper on its own, but it is the right test for the simulation.

**Practical now**
- **USGS NHD centrelines** (public domain). I tested one query for the Mississippi near Helena: https://hydro.nationalmap.gov/arcgis/rest/services/nhd/MapServer/6/query with the river's name and a bounding box returned 11.6 KB of GeoJSON, 53 km in 158 vertices (one every 335 m, about a third of a channel width). A seed per river is a few KB. United States only, Alaska included, so the Mississippi and the Koyukuk but not the Amazon rivers.
- **GRWL**, Global River Widths from Landsat: centrelines with widths at 30 m worldwide, CC BY 4.0 (checked on the record: doi 10.5281/zenodo.1297434, 3.1 GB of vectors). The Mamoré, Ucayali and Juruá would be cut from it offline, with a credit line in About. SWORD is the same idea, also CC BY 4.0, 27 GB.
- **USGS 3DEP elevation** (public domain). One request to https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/exportImage returned a 2400 x 1500 float TIFF of any window. It gives a real floodplain as relief, at 1-3 MB once packed.

**Recorded histories that are open** (licences read from each record; I downloaded none of them, images only)
- Greenberg and Ganti 2024: yearly water masks and centrelines for 55 rivers, plus a table of 139. CC0. doi 10.5061/dryad.jq2bvq8g3, 35 MB.
- Dente and others: Amazon centrelines 1984-2020 and migration rates for 23,000 reaches. CC BY 4.0. doi 10.5281/zenodo.11066336, 43 MB. The centrelines are raster tiles coloured by year.
- Bonanomi and others: channel axes of permafrost and other meandering rivers from Landsat. CC BY 4.0. doi 10.5281/zenodo.11457850.
- The Ucayali's 31 yearly masks ship as a demo with the RivMAP MATLAB toolbox (https://www.mathworks.com/matlabcentral/fileexchange/58264-rivmap-river-morphodynamics-from-analysis-of-planforms); I could not confirm its licence.

**Why a replay alone does not work**
The Landsat record is about 40 years. I measured the Mamoré moving a median 0.9 channel widths in 29 years. At a calm pace (a year every 9 seconds) the whole record plays in 6 minutes and shows about one width of movement, then has to loop.

**What the histories are good for**
1. A test for the simulation: after 29 simulated years, 24% of the old channel should still be channel, with moved parts a median 0.9 widths away and 3.4 at the 90th percentile (the Mamoré, scripts/mamore.py). That is "judged against the real thing" for motion.
2. A real first chapter: start from the real present course with the real recent courses already painted as the youngest bands, then let the simulation carry on.

**Fisk's own courses**
I found no vector version. Automatic tracing fails on the hatching. The four dated courses (1765, 1820, 1880, 1944) are solid colours and could be segmented on one sheet, but each is hidden wherever a later course crosses it, so the gaps need tracing by hand: about a day a sheet. It would give 180 real years of the Mississippi (27 minutes at the pace above) before the simulation takes over. A charming later idea, not for the first version.

**Not practical**: anything live. Rivers do not change during a session.

**A setting "after a real one"**
I'd make it a kind, like Galaxy's: Mississippi, Mamoré, Koyukuk, each a real centreline as the seed (a few KB) plus a parameter set (width in frame, sinuosity, how long lakes last, scroll spacing, palette), with Random as the default. One further idea for later: start on the real 3DEP relief and let the simulated river overwrite it. The risk is a visible seam between rich real ground and cleaner simulated ground.

---

Meander look 8/9: six proposed palettes with RGB for Dark and Light, and what the existing art does.
Each palette: ground; five ages, oldest to youngest; river. scripts/palettes.py prints them all with line colours and brightness; swatches are in work/palette-swatches.png. Dark grounds sit at 0.05-0.10 brightness, the youngest deposits at 0.40-0.45 and the river at 0.62-0.75, never white.

1. **Survey Blue**, from the Survey's Sauk River picture.
   Dark: (0,22,31) | (4,46,63) (10,64,83) (14,76,97) (24,93,115) (52,130,151) | (153,200,211).
   Light: (240,244,242) | (192,222,229) (169,209,218) (153,200,211) (130,187,200) (115,178,193) | (30,104,127).
2. **Rainforest**, from the Quinault picture.
   Dark: (2,21,15) | (0,47,37) (8,67,54) (14,80,65) (24,97,80) (52,132,113) | (151,202,192).
   Light: (240,244,240) | (190,224,217) (167,211,202) (151,202,192) (129,189,176) (114,181,166) | (31,109,90).
3. **Garnet**, from the Chehalis picture.
   Dark: (30,9,13) | (81,25,38) (92,42,51) (100,54,59) (112,70,71) (143,108,101) | (210,187,173).
   Light: (245,241,232) | (230,213,199) (218,197,183) (210,187,173) (197,171,159) (189,160,149) | (120,81,79).
4. **Amethyst**, from the Okanogan picture.
   Dark: (25,14,28) | (58,33,63) (78,44,73) (92,51,79) (115,65,96) (165,100,111) | (217,184,172).
   Light: (248,244,242) | (237,212,209) (225,195,187) (217,184,172) (207,168,152) (201,157,138) | (131,74,107).
5. **Fisk Sage, Salmon or Teal**: one of his inks on his paper, values in message 3. The most faithful one-family reading of his maps.
6. **Fisk 1944**: his four inks together, values in messages 2 and 3. The one palette outside one family; offer it because it is the look Dave named, not as the default.
Plus **Landsat** (message 5) if a true-colour feel is wanted.
The Light relief palettes follow the Survey's Yakima picture: pale ground, the river the darkest thing. Their grounds are at 0.95, the same as Wind's paper; if that reads too bright here, Fisk's cream at 0.88 is the fallback.
A new palette on each load would suit "a new river on each load", as Nebula does.

**The art that exists** (copyright, reference only; I read the descriptions and downloaded none of it)
- Robert Hodgin, Meander, 2020: "a procedural system for generating historical maps of rivers that never existed", built in Houdini. The river is a flat curve nudged along a blend of each point's tangent and outward normal; near-collisions split off oxbow lakes, which "get smaller over time until they are deleted". Around the river he adds generated terrain, land plots (Voronoi cells cut into fields), roads grown until they meet, marsh and peaks, and place names remixed from USGS place-name data, then weathers it like a 1940s Corps map. https://roberthodgin.com/project/meander and https://flowingdata.com/2020/06/12/meandering-procedural-river-maps/
- Hodgin, Ancient Courses of Fictional Rivers, 2022: the same idea running in a browser. https://www.creativeapplications.net/nft/ancient-courses-of-fictional-rivers-robert-hodgin
- onformative, Meandering River: an audiovisual installation with painterly, slowly changing surfaces that simulate erosion, "oxbow lakes and meander scars". https://onformative.com/work/meandering-river
- Daniel Coe's lidar pictures (message 4).

**What makes them work, and what they add beyond the river**
- The accumulated history is the subject; the present channel is a small part of the frame.
- Hodgin's extras (plots, roads, names, weathering) make it a map of a place. That is right for a print read up close. On a desktop behind windows it is the fine detail and text that Dave finds busy, and it would have to stay still while the river moves under it.
- onformative shows the calm version: no map furniture, slow change, texture and colour only.
- Worth borrowing as ideas, not as copies: lakes that shrink and vanish; the river framed on a diagonal with ground to spare on both sides.

---

Meander look 9/9: pitfalls, a scorecard for judging renders, and what was blocked. The reference list follows as an appendix.

**What would make it look fake**
- A channel of constant width with an outline. Real ones vary 2-3 times in width, with bars and islands, and soft unlined banks.
- Even, concentric, high-contrast scroll rings. Real scrolls are fine (0.12-0.5 widths apart), irregular, fan out, are cut off by younger sets, and ripple brightness by only a few percent.
- Bends all the same size and symmetric. Real belts mix small and compound loops.
- Empty ground beyond the belt. Real floodplains are textured to the edge with older, dimmer courses.
- Oxbow lakes at the wrong tone. In relief they match the river; they then shrink from the ends.
- Cutoffs that pop.

**Garish**
- More than one saturated hue. Fisk's four inks at full strength, or the purple-coral-cream ramps of the Skagit and Sol Duc pictures.
- A pure white river on near black. The references do it; Atrium should stop at about 0.7.

**Busy**
- Hatching and stipple (they also shimmer in motion), stage numbers, labels, grids, contours, an outline on every band.
- Too many bands at once. Five or six ages read; twenty-six is noise at desktop size.
- Light Mode at full contrast. Bright and sharp is what got Zen Garden cut: keep bands within about 0.2 of the paper's brightness, as Fisk's tints are.

**Dull**
- Only the channel visible on flat dark ground (the Ucayali still: colour 0.08, contrast 0.09).
- Motion too slow to notice, or no events. Aim for a cutoff every few minutes.
- A history that saturates: after hours every pixel has been reworked and the picture evens out. Old deposits must keep fading so new always stands out from old.
- Every load alike. Vary the kind of river, its width in frame, its direction across the screen and the palette.

**Technical**
- Banding in dark ramps: dither, as Galaxy does.
- Bands and relief must come from one history, or they will drift apart.

**A scorecard for renders** (python3 -I scripts/busy.py <image>, at 1920 px wide)
| Picture | brightness | edges | one-family score |
|---|---|---|---|
| Fisk sheets 6 and 7 | 0.71-0.75 | 56-59% | - |
| Coe's Dark relief pictures | 0.30-0.47 | 3.5-7.7% | 1.0, or 0.61-0.76 for the two-hue ones |
| Coe's Light picture (Yakima) | 0.74 | 27% | 0.61 |
| My 3DEP relief renders | 0.20-0.31 | 1-2% | 1.0 |
| Proto t1-relief | 0.19 | 3.3% | 1.0 |
| Proto t1-fisk | 0.64 | 10.3% | 0.44 |
Suggested targets: Dark relief at brightness 0.15-0.20, edges 2-5%, one-family 1.0. Fisk bands in Light at brightness 0.80-0.88, edges under 10%, one-family above 0.9.

**Blocked, skipped or not verified**
- lmvmapping.erdc.usace.army.mil (the Corps' own Fisk plates): certificate error. I did not look at the Library of Congress or the Internet Archive, since Commons has every sheet at full size.
- HTTP 403 from Wiley (Schwenk 2017), Cardiff and Southampton (Constantine 2014); nature.com wanted a login. Their figures are from search summaries. The Caltech PDF of Geyman 2024 was over the fetch size limit.
- Not downloaded, under the images-only rule: NASA's Ucayali time-lapse video and the open datasets in message 7. Two exceptions to flag: one 11.6 KB GeoJSON reply from USGS NHD (work/nhd-test.json) to test the query, and a USDA PDF that the fetch tool saved on its own.
- Hodgin's and onformative's images: read about, not viewed.
- From memory and unchecked, so left out of the table: that long simulated rivers settle at a sinuosity near 3.14 (Stølum 1996), and that later work found Fisk's dates too young.
- Nothing in the repo was touched; no agents spawned.

---

Meander look, appendix: the reference files with title, credit, licence and source.
All under scratch/meander/refs/

**Fisk, Plate 22, "Ancient Courses, Mississippi River Meander Belt"**. Harold N. Fisk for the Mississippi River Commission, US Army Corps of Engineers, 1944. Public domain (Commons tag). Scans by LSU Law Center. Source pages: https://commons.wikimedia.org/wiki/File:Ancient_Courses_Mississippi_River_Meander_Belt,_Plate_22_Sheet_NN.jpg with NN = 01, 04, 06, 07, 09, 12.
- fisk-plate22-sheet01-3840.jpg (has the legend), sheet04, sheet06, sheet07, sheet09, sheet12, each 3840 px wide.
- fisk-plate22-sheet06-full.jpg: the original, 10,043 x 14,919.
- fisk-plate22-sheet07-jpl-scan.jpg: a second scan of sheet 7, catalogued by NASA/JPL (photo ID mississippimap). Public domain. Misnamed on Commons: https://commons.wikimedia.org/wiki/File:Mississippi_River_(ASTER).jpg

**Lidar pictures by Daniel E. Coe, Washington Geological Survey (Washington State DNR)**. CC BY-SA 2.0. Reference only, not to ship. Each is on Commons as "File:<title> 16-9 ratio, 7200x4050 pixels.jpg", from https://www.flickr.com/photos/35433815@N08/<id>/
- wgs-okanogan-scroll-bars-3840.jpg: "25 Floodplain—Okanogan River", id 51149800845.
- wgs-chehalis-black-rem-3840.jpg: "03 Stream Confluence—Chehalis River and Black River", id 51148700971.
- wgs-sauk-rem-3840.jpg: "01 Stream Channels—Sauk River", id 51149803860.
- wgs-quinault-rem-3840.jpg: "19 Stream Channels—Quinault River", id 51148017622.
- wgs-skagit-oxbows-3840.jpg: "23 Stream Channels—Skagit River", id 51149477549.
- wgs-yakima-point-bars-3840.jpg: "65 Point Bars and Meander Scars—Yakima River", id 52200696573. The Light Mode example.
- wgs-solduc-rem-3840.jpg: "76 Floodplain—Sol Duc River", id 52582416315.

**USGS 3DEP elevation, Mississippi near Helena, Arkansas**. Public domain. From https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/exportImage
- ms-helena-3dep.tif: longitude -90.95 to -90.33, latitude 34.42 to 34.74, 2400 x 1500 float metres, 23.6 m a pixel.
- ms-helena-zoom-3dep.tif: longitude -90.582 to -90.450, latitude 34.620 to 34.688, 5 m a pixel.
- usgs3dep-mississippi-helena-rem-2400.jpg and usgs3dep-mississippi-helena-pointbar-rem-2400.jpg: my relative elevation renders of those two (scripts/rem.py). No restriction.

**NASA**. Public domain.
- eo-mamore-1985-landsat5.jpg and eo-mamore-2014-landsat8.jpg: "Meandering in the Amazon". NASA Earth Observatory images by Jesse Allen, using Landsat data from the US Geological Survey. https://science.nasa.gov/earth/earth-observatory/meandering-in-the-amazon-84833
- svs-ucayali-still.jpg: a still from "The Meandering Ucayali River", NASA Scientific Visualization Studio, visualiser Ross K. Walter. https://svs.gsfc.nasa.gov/15021

**Scripts** (in ../scripts/, run with python3 -I)
- legend.py, hues.py, inks.py, sample.py: Fisk's colours. ramp.py: lidar colour ramps. busy.py: the scorecard.
- rem.py: relief from a 3DEP TIFF. scrolls.py: scroll-bar spacing and relief. mamore.py: the 1985-2014 comparison.
- palettes.py: the proposed palettes and swatches. sheet.py: contact sheets. fetch.sh: the polite downloader. width.py: an early width estimate that reads low; ignore it.

**Derived pictures** (in ../work/)
- proto-vs-ref.jpg: first renders beside the real references.
- palette-swatches.png: every proposed palette.
- f01-legend.png: Fisk's legend, cropped. f06-busy.jpg and f06-river.jpg: sheet 6 at full resolution.
- lidar-sheet.jpg: the seven Coe pictures on one sheet.
- mamore-change.png: 1985 in red, 2014 in cyan.
- ms-helena-rem-dark.npy: relative heights in metres for the Helena window.
