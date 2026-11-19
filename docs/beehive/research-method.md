# Beehive: the method

Research for the wallpaper Dave picked as idea #5 on 2026-11-14: "An observation hive behind glass. Comb is drawn out cell by cell through the day, filled with honey and capped, with bees working across it," built on the wall clock as Ant Colony is, with the bees clustering tighter when it is cold where you are. This report covers how it works and what it costs: the real numbers, the pace, the data model, how to draw it, and the cold. The look (references, palettes, licences, the name) is in `research-look.md`.

## The recommendation, in short

- **Ant Colony's engine, nearly as it is.** A comb a day, six to six, on Ant Colony's `Cycle` and Speed. The comb is baked from the date as one small texture, a texel a cell, holding when that cell is drawn out, when it fills and when it is capped. One shader compares those times with a single number, the farm's clock. The comb is kept in a rasterised `SKEffectNode` and drawn again only when the clock moves a step.
- **One sprite per bee**, from a baked atlas of poses seen from above, turned by `zRotation`. Measured: 1,000 bees cost 0.17 to 0.27 ms of CPU and almost no GPU. Ant Colony's jointed ants cost 0.85 ms at 300 and crashed at 1,000. A shader drawing every bee costs more GPU, and drops bees where they crowd, which is exactly where the cold sends them.
- **Light the comb from the viewer's side.** A bee lit from straight in front looks right at any heading, so turning its sprite is correct. Ant Colony's ants, lit from their own backs, are not.
- **The calm comes from the real numbers.** Bees walk slowly in the hive, at about a third of a body length a second against Ant Colony's 1.4 to 1.75. Between a fifth and two fifths of them are still at any moment. The busy look comes from how many there are, so the lever is how many walk at once: about 60 on a 14-inch display.
- **Honey comb only:** no brood, no larvae, no queen. That is real (a honey super) and keeps the trypophobia triggers out.
- **Cold:** smooth the live air temperature over half an hour. From 18 °C down the bees gather, and from 14 to 10 °C they form a cluster, which tightens below that, more of them going head first into empty cells. Each bee moves on its own schedule, so the gathering never turns into a stampede.

## 1. The real thing in numbers

Two helper agents read these pages on 2026-11-18 through a fetch tool, and I didn't read them again myself. In the Read column, "full" means a helper read the whole text, "abstract" means only the abstract or record, and "summary" means a secondary page or a search summary, so treat those as **unchecked**. "Derived" is arithmetic on the rows above it. PMC, PNAS, Springer and apidologie.org refused automated fetches, so some papers were read through another copy, as noted.

### The comb

| Fact | Number | Source | Read |
|---|---|---|---|
| Worker cell, across the flats (*A. m. ligustica*, natural comb) | 5.50 mm | Yang et al. 2021, *J Insect Sci* (CC BY 4.0), https://academic.oup.com/jinsectscience/article/doi/10.1093/jisesa/ieab042/6313200 | full |
| Honey-storage cell / drone cell | 5.74 / 6.63 mm | same | full |
| Depth: worker / drone / honey cell | 12.1 / 13.8 / 16.9 mm | same | full |
| Upward tilt, base to mouth | mean 7.3° (0 to 19°) | same | full |
| Upward tilt, a beekeeper's figure | about 15° | https://bushfarms.com/beesobservationhives.htm | full (unchecked against a paper) |
| Worker / drone cells, 4,414 and 2,586 measured | 5.4 ± 0.2 / 6.6 ± 0.2 mm | Smith et al. 2021 *PNAS*, through an *American Bee Journal* write-up: https://bpb-us-e1.wpmucdn.com/blogs.cornell.edu/dist/8/5278/files/2021/10/10-McArt-article_October2021.pdf | full (write-up) |
| Irregular cells | 4.4% of cells not hexagonal; 87.8% of 5- and 7-sided cells come in pairs, at merges and worker/drone seams | same; Smith et al. 2023 *PLOS Biol* (CC BY), https://journals.plos.org/plosbiology/article?id=10.1371/journal.pbio.3002211 | full |
| Wall thickness | 0.07 to 0.09 mm fresh, thickening with use | Darwin 1860, https://darwin-online.org.uk/Variorum/1860/1860-231-dns.html (1/353 in); Zhang et al. 2010 (88 µm) | full / summary |
| Comb thickness / gap between combs | 22 mm / 7.5 ± 1.5 mm (European bees) | https://tjs.udsm.ac.tz/index.php/tjs/article/download/2053/990/3483 | full |
| Colour | new comb near-white; storage comb yellows with pollen; brood comb goes almost black | Berry & Delaplane, https://bees.caes.uga.edu/content/dam/caes-subsite/bee-program/images/research-archives/effects_comb_age.pdf | full |

Derived: a honey cell 16.9 mm deep, tilted 7.3°, puts its base 2.2 mm below its mouth, **0.38 of a cell's width**. Looking straight in, you see a band of the upper inner wall above a base pushed down by about a third of a cell. That is the cheapest strong cue that these are holes and not a printed pattern (§4).

### The observation hive

| Fact | Number | Source | Read |
|---|---|---|---|
| Langstroth frame, deep / medium | 19 × 9⅛ in / 19 × 6¼ in (483 × 232 / 483 × 159 mm) | https://www.dummies.com/article/home-auto-hobbies/hobby-farming/beekeeping/vital-stats-and-materials-list-for-langstroth-frames-170310/ | full |
| British National brood frame | top bar 432, bottom bar 356, sides 216 mm | https://dorchesterandweymouthbka.com/hive-sizes/ | full |
| Glass to glass | 1¾ in (44 mm) right; 1½ in too tight; 2¼ in invites burr comb | bushfarms (above) | full |
| Layout | one comb thick, frames one above another; three deep or four medium | same | full (the stacking is the helper's reading of the frame-rest heights) |
| Bee space | 6.4 to 9.5 mm, usually given as 7 ± 2 | https://en.wikipedia.org/wiki/Bee_space | full |
| A strong colony | "a mass of bees underneath the glass"; never in direct sun | https://entomology.mgcafe.uky.edu/files/ef016.pdf | full |

### How comb is built

| Fact | Number | Source | Read |
|---|---|---|---|
| Where it starts | at the ceiling, building downward, the bees first hanging as a cluster | https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0205353 | full |
| Tongues | "separate tongues of comb are constructed individually ... but must ultimately be united"; photos 4 h apart show pits becoming cells | Gallo et al. 2023 (CC BY), https://chittkalab.sbcs.qmul.ac.uk/2023/s00359-023-01632-y.pdf | full |
| The growing comb's shape | height about equal to width until the tip nears the frame's bottom, then it widens; growth slows before it reaches wood | Marting, Koger & Smith 2023, https://par.nsf.gov/servlets/purl/10479402 | full |
| Its leading edge | comes to a point, which later "flattens out and loses its point" | https://par.nsf.gov/servlets/purl/10479403 | full |
| The rim | a "rude circumferential rim" round a growing comb; first walls 10 to 20 times too thick, gnawed down | Darwin 1860 (above) | full |
| Festoons | bees link legs into "curtain-like structures" around the building site | Marting et al. 2023 | full |
| How fast | 1,107 ± 431 cm² a week for a new colony in empty frames (about 1.3 frames); 86% of the year's nest by day 45 | same | full |
| The same a day | about 158 cm² a day, about 600 worker cells a face | derived | derived |
| Wax scales | about 3 mm across, 0.1 mm thick, about 1,100 to a gram | https://en.wikipedia.org/wiki/Beeswax | full (citing a 1981 book) |
| At night | "Comb building occurs also during night" (citing Kaiser 1988) | https://honeybee.drawwing.org/book/comb-building | full (secondary; original unchecked) |

### Nectar to honey

| Fact | Number | Source | Read |
|---|---|---|---|
| How a cell is filled | nectar is spread on the cell's ceiling with sideways movements of the head and runs down the walls; part-filled cells have dense "tongues" toward the mouth | Eyer, Neumann & Dietemann 2016, *PLOS ONE* (CC BY), https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0161059 | full |
| Ripening | sugar 57.7% on day 1, 84.8% in capped cells | same | full |
| Fill and cap | 83% of cells full in 4 to 7 days, the rest in 11 to 12; first cap on day 12 | same | full |
| Water | nectar about 70%; honey under 18.6% | https://news.ncsu.edu/2013/06/how-do-bees-make-honey | full |
| Caps | dry caps (an air gap under the wax) white or very light tan; wet caps darker; honey capped in groups, so the surface is flatter | https://honeybeesuite.com/wet-cappings-vs-dry-cappings/ | full (a practitioner's page) |
| How full when capped | not found | | **unchecked** |
| Classic layout | brood low, pollen beside it, honey above (the "honey arch") | Johnson 2009, Europe PMC record of PMC2674341 | abstract |

### The bees

| Fact | Number | Source | Read |
|---|---|---|---|
| Length: worker / drone / queen | 10 to 15 / 15 to 17 / 18 to 20 mm | https://biokids.umich.edu/critters/Apis_mellifera | summary (**unchecked**) |
| Forewing: worker / drone | 9.1 / 11.1 mm | Tofilski et al. 2024, https://sciendo.com/pdf/10.2478/jas-2023-0013 | full |
| Walking speed on the comb | hourly means about 1 to 2.5 mm/s at night, 3 to 5 at midday; resting counted under 1 mm/s; 95% band up to about 10 | Mellert, Kłos et al. 2024 (preprint), https://www.biorxiv.org/content/10.1101/2024.07.29.605620.full.pdf | read off its figure 1 |
| Movement while tracked | 0.9 ± 0.9 mm a frame at 4 frames/s, about 3.6 mm/s | Blut et al. 2017, https://pmc.ncbi.nlm.nih.gov/articles/PMC5732155 | full |
| In body lengths | 0.1 to 0.4 a second | derived | derived |
| Still at any moment, by caste | cleaners 42%, nurses 22%, food storers 21%, foragers 25% (sleeping out of cells plus still in cells; a scan study 28 to 38%) | Klein et al. 2008, *J Exp Biol*, https://kops.uni-konstanz.de/bitstreams/bced220c-e236-4f35-ad67-d0c6d1c719fc/download | full |
| Lindauer's bee no. 107 | idle 69 h of 177 h watched (39%) | Klein & Busby 2020, *PeerJ*, https://peerj.com/articles/9583 | full (Lindauer at second hand) |
| Sleeping in a cell | 17% of in-cell sightings are sleep, with more than 10 s between pumps of the abdomen; the tip alone shows | same | full |
| Longest still bouts | out of cells, 89 to 333 s; in cells, over 900 s | Klein et al. 2008 | full |
| Foragers asleep outside cells | 56% of sightings by night, 13% by day | same | full |
| More bees in cells | between 21:00 and 06:00 | Bozek et al. 2021, https://pmc.ncbi.nlm.nih.gov/articles/PMC7979864/ | full |
| A cell visit | under 10 s is ten times as common as 10 to 300 s; a feeding visit is 80 to 133 s; depositing water 19 s | Siefert, Buling & Grünewald 2021, *PLOS ONE*, https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0247323 | full |
| Taking a wax scale | about 5 s from the pocket, 0.4 s to the mouth | same | full |
| Trophallaxis | contacts over 3 s always pass food | Farina & Wainselboim 2001 | abstract (search) |
| Waggle dance | a circuit takes 1.8 to 4.5 s; dances on a floor of about 500 cm² near the entrance, 94% within 24 cm of it | PeerJ 2021, https://pmc.ncbi.nlm.nih.gov/articles/PMC8029670; PLOS ONE 2026, https://pmc.ncbi.nlm.nih.gov/articles/PMC12915931/ | full |
| Density, a covered frame | 1,215 bees on a deep Langstroth side (880 cm²), 1.38 a cm²; 1.23 to 1.77 across frame types | Delaplane et al. 2013, https://bees.caes.uga.edu/content/dam/caes-subsite/bee-program/images/research-archives/JARStandardmethodscolonystrength.1.03.pdf | full |
| Density, an observation hive | 805 to 1,316 bees on a 47 × 47 cm face, 0.4 to 0.6 a cm² | Bozek et al. 2021 | full + derived |
| How long grooming, fanning or festooning acts last; what share of the time a bee walks | not found | | **unchecked** |

### Cold and night

| Fact | Number | Source | Read |
|---|---|---|---|
| A cluster forms | when the coolest bees are at about 14 °C (57 °F), which is the bees' own temperature, not the air's. Above it they spread over the combs, and are quiet between 14 and 21 °C. In one record the cluster tightened through an evening as the air cooled. | Phillips & Demuth 1914, https://www.archive.org/download/temperatureofhon93phil/temperatureofhon93phil.pdf | full |
| By the air | the cluster breaks up and re-forms at 10 to 14 °C | Southwick 1983, https://jim-boogaerts.squarespace.com/s/THE-HONEY-BEE-CLUSTER-AS-A-HOMEOTHERMIC-SUPERORGANISM-Southwick-1983.pdf | full |
| Below 10 °C | metabolism rises in a straight line as the air cools; a tight cluster of 20 cm cuts its surface by 88% | same | full |
| Volume | −55% (surface −40%) from 4 to −23 °C (Severson & Erickson 1990) | | **unchecked** (a snippet only) |
| Inside a winter cluster, air 1 to 6 °C | thorax at the surface 12 °C, outer layer 17, middle 23, core 30; 15 to 16% of the bees are heating, mostly still in the core | Stabentheiner et al. 2003, https://jim-boogaerts.squarespace.com/s/Endothermic-heat-production-in-honeybee-winter-clusters.pdf | full |
| Movement on a cluster at night | 6 to 80 bees an hour come out to its surface | same | full |
| Mantle and core density; clustering on cool summer nights | not found | | **unchecked** |

## 2. Calming the pace without looking wrong

The worry was that bees are busier than ants. Per bee, the measurements say otherwise: a worker on the comb walks at 0.1 to 0.4 body lengths a second and spends a fifth to two fifths of its time still. Ant Colony's ants walk at up to 1.75. What makes a hive look busy is numbers: hundreds of bees, each nodding into cells and turning, a few dancing at 13 Hz (**unchecked**), and bees landing and taking off at the entrance. So keep the real pace and the real stillness, and cap how many walk at once.

| | Real | Standard, by day | By night (21:00 to 06:00 local) |
|---|---|---|---|
| Walking speed | 3 to 5 mm/s by day, 1 to 2.5 at night (hourly means) | 2 to 5 mm/s, at most 6 (0.5 lengths a second) | 1 to 2.5 mm/s |
| Walking | not measured | 12 to 15% of bees; about 60 on a 14-inch display | 6 to 8% |
| Working in place: head in a cell, building at the edge, capping, grooming, feeding a neighbour | most of the rest | 40% | 30% |
| Still: resting, asleep on the comb or in a cell, hanging in a festoon | 21 to 42% (by caste) | 45% | 60% |
| A still bout | 5 s to over 15 min | 20 s to 5 min on the comb, 1 to 15 min in a cell | longer by half |
| Head into a cell | mostly under 10 s; feeding 80 to 133 s | 10 to 60 s | |
| Turning | | at most 45° a second | |

**Leave out:** the waggle dance's buzz (a 13 Hz shake reads as a vibration, and aliases at 30 fps or less), flight, takeoff, the entrance, bees running, and drones and the queen (none above a queen excluder). A dance could come later as a slow figure-of-eight traced by one bee with a few followers, and no waggle.

**Keep, because it's slow:** festoons (chains of bees hanging still under the growing edge, the most striking calm thing a hive has), bees asleep in cells with only the tip of the abdomen showing, a bee's head going into a cell, two bees face to face passing food, grooming, and fanning (wings drawn as a still blur, never flapping).

Total motion compared with Ant Colony: 24 ants, half walking at about 1.4 lengths a second of 44 px, move about 740 px a second between them. 500 bees at 12% walking, 0.3 lengths a second of 59 px, move about 1,060. So the standard hive moves somewhat more than Ant Colony, spread over many slower bees. Judge it from a moving mock-up before building (§7, risk 1).

## 3. The data model

### Scale

Pointy-topped hexagons: rows level, the side walls upright, as in natural comb. These are honey cells, 5.74 mm across.

| Bee size | Cell across | Points a mm | A worker (12 mm) | 14-inch screen shows | Bees at 0.2 a cm² |
|---|---|---|---|---|---|
| Small | 10 pt | 1.74 | 21 pt | 868 × 564 mm | 980 |
| **Medium** (standard) | 14 pt | 2.44 | 29 pt (59 px) | 620 × 403 mm | 500 |
| Large | 20 pt | 3.48 | 42 pt | 434 × 282 mm | 245 |

At Medium the screen is one large comb, about a top-bar hive's, with the top bar along the screen's top edge and no frame drawn. That follows Ant Colony's "the display is the glass, edge to edge". The real density on an observation hive's face is 0.4 to 0.6 bees a cm². The standard here is 0.2, a third of that, so the comb shows between the bees (a worker covers about 0.55 cm², so 11% of the comb is under a bee), with the Bees slider going from 0.5× to 2×. The colony doesn't grow through the day; it is one colony on a comb that does.

### What is baked from the date

`Comb` (its own module, like `AntNest`, built with `-O`) grows the day's comb from a seed:

- **The lattice:** one lattice per comb, as from a starter strip along the top bar, bent by a smooth warp of up to a third of a cell over about ten cells, so the rows curve as natural comb's do. A second lattice for drone cells, or tongues meeting with their own lattices, would need a Voronoi read in the shader (nine reads); leave that out at first.
- **When each cell is drawn out** (16 bits, a share of the day): a front grows from one to three seed points on the top bar as tongues about as high as they are wide, joining where they meet. It comes to a point and then flattens, slows as it nears the bottom, and has noise in its speed so the edge is ragged by a cell or two. As in Ant Colony, what is kept is the share of the day's building done when the cell starts. The cell's walls then rise over the next stretch of the farm's clock (about 20 minutes at Speed 1), so the edge is a band two or three cells wide of pits deepening into cells, as in Gallo's photos.
- **When it fills** (8 bits): from the top down and outward, the honey arch, a few hours of the farm after the cell is drawn. The lowest quarter or so stays empty by the day's end, which is where the bees cluster.
- **When it is capped** (8 bits): some hours after it fills, in patches seeded together (honey is capped in groups), starting from the top corners.
- **A variant byte** (a second texel or texture): the honey's tint, wet or dry cap, and the odd pollen cell if the look report wants one.

That is one RGBA8 texel a cell plus a variant: 108 × 81 cells at Medium on a 14-inch display, a 35 KB texture. A day's 8,700 cells baked by a front-growing pass should take a few milliseconds off the main thread. That's an estimate; the probe's map is a formula, not a bake.

**Time is compressed.** Real comb grows about 158 cm² a day, so this screen would take about two weeks, and honey takes 4 to 12 days to fill and cap. Here it is all one day, as Ant Colony's nest is.

### The clock

Ant Colony's `Cycle` (the farm's day and turn, when it began, the pace; Speed 1× to 8× without moving the work; a farm begins at six at 1×) should be lifted out of `AntColony.swift` with a key prefix and shared, not copied. The share of the comb drawn at h hours into the farm is s₀ + (1 − s₀)(1 − (1 − h/24)²), with **s₀ = 0.25**: a quarter of the comb is there at six in the morning, as if built overnight (bees do build at night), then 43% at nine, 58% at noon, 81% at six in the evening and 95% at midnight. Bake the curve into the map, so the shader reads one uniform, the farm's elapsed fraction.

### The day's end, never empty

At six the next comb dissolves in over the old one for two minutes, both maps in one shader with a mix uniform. The bees stay, as sprites over it, and are sent to the new comb's work. There is never a blank: the old comb is whole until the new one has a quarter of the screen. In the morning the bees crowd the small comb and hang in festoons under its edge, which fills the empty part of the screen with the most characteristic sight of the day. Ant Colony's own next idea, a crossfade between farms, is this.

### Where the bees are sent

As Ant Colony's `Colony` sends ants to the faces about to move, the bees go where the map says work happens in the next few minutes of the farm's clock:

| Task | Where, from the map | Bees | Pose |
|---|---|---|---|
| Building | cells whose walls are rising now, along the edge | 2 to 3 a cell along the front | head at the rim, a slow nod |
| Festooning | hanging from the edge into the open space below | 10 to 20% in the morning, fewer as the comb nears the bottom | hanging in chains, still |
| Storing | cells whose honey is rising now | 1 a cell, 10 to 60 s, then off | head in the cell, the rear half showing |
| Capping | cells being capped now | 1 to 2 a cell | over the cell, small movements |
| Resting | capped comb, empty cells | the rest | still; in a cell, the tip showing |
| Walking | between tasks | capped as in §2 | 4-frame walk |
| Pairs | anywhere | a few | two face to face, 2 to 10 s |

## 4. How to draw it within budget

### Measured

`docs/beehive/probe.swift` (a copy of `$TMPDIR/beehive-probe/main.swift`, kept) draws with `SKRenderer` at 3024 × 1964, as the render test draws a wallpaper. It was run on 2026-11-18 on an M3 Max on mains power, with other sessions working (load average 3.3 to 4.0), built with `swiftc -O`. Each figure is the median of 90 frames after 30, stepped at 60 fps, in two rounds run one after the other; where the rounds differ, both are given.

GPU is the command buffer's own time. "CPU" is the main thread's time from the bees' step to commit. "Render test's way" is the wall time to the GPU's finish less the GPU's time, as RenderTests.swift counts it, which includes a floor of 0.3 to 0.5 ms that an empty scene shows too. **Calibration:** Nebula's shader, read from Shaders.swift, reads 1.72 ms of GPU here, against the 1.6 in its doc and 1.72 in the Canopy probe, so this machine reads about 7% high.

The probe's comb is the shading described below, simplified: the hex grid, a lit rim, depth shading, three-faceted bases, one octave of wax noise, honey with a highlight, and a dry cap. Its bees are a painted placeholder, 36 × 20 pt, in four poses. 30% of them walk (a trivial random walk) and the rest are not touched.

| What | Bees | Walking | CPU, ms | Render test's way | GPU, ms |
|---|---|---|---|---|---|
| Empty scene | | | 0.03 | 0.34 to 0.53 | 0.01 to 0.03 |
| Nebula (calibration) | | | 0.04 to 0.06 | 0.37 to 0.43 | 1.72 |
| Comb, drawn every frame | | | 0.04 to 0.05 | 0.36 to 0.39 | 0.32 to 0.42 |
| Comb, kept in an `SKEffectNode` | | | 0.03 | 0.32 to 0.35 | 0.10 to 0.24 |
| **(b) a sprite a bee**, over the kept comb | 100 | 30% | 0.04 | 0.36 to 0.37 | 0.10 to 0.26 |
| | 300 | 30% | 0.07 | 0.41 | 0.11 to 0.30 |
| | 300 | all | 0.09 | 0.43 to 0.45 | 0.11 to 0.15 |
| | 1,000 | 30% | 0.17 to 0.19 | 0.52 | 0.13 to 0.37 |
| | 1,000 | all | 0.23 to 0.27 | 0.56 to 0.66 | 0.13 to 0.38 |
| (a) a body and 17 leg sprites, Ant Colony's way | 100 | 30% | 0.29 to 0.30 | 0.64 to 0.66 | 0.11 to 0.15 |
| | 300 | 30% | 0.84 to 0.87 | 1.22 to 1.27 | 0.14 to 0.15 |
| | 1,000 | 30% | crashed: a Metal assertion in SpriteKit's encoder ("endEncoding has already been called") at 18,000 nodes | | |
| (c) every bee drawn by one full-screen shader | 100 | 30% | 0.06 to 0.08 | 0.41 to 0.44 | 0.21 to 0.36 |
| | 300 | 30% | 0.08 | 0.40 to 0.47 | 0.27 to 0.28 |
| | 1,000 | 30% | 0.09 | 0.41 to 0.42 | 0.49 |
| (d) still bees kept in a second effect node, walkers as sprites | 1,000 | 30% | 0.09 | | 0.36 to 0.50 |

The GPU figures swing by up to 0.25 ms between rounds with the GPU's clock (Ant Colony and Turing Patterns saw the same), so only differences larger than that mean anything. The bees' trivial step cost 18 µs for 300 walkers and 58 µs for 1,000.

### The bees: (b), one sprite each

- **(b) wins.** At 1,000 bees it costs a fifth of a millisecond of CPU and barely any GPU, since SpriteKit draws sprites that share an atlas in one batch. Per frame, a walking bee sets `position` and `zRotation`, plus `texture` when its pose changes (4 Hz). A bee working in place sets something every second or so, and a still bee nothing, which is Ant Colony's rule: count the sprites and the properties set a frame.
- **(a)**, Ant Colony's jointed bodies, costs seven times (b)'s CPU at 100 bees, and at 300 four times what (b) costs at 1,000. It crashed at 1,000. From above, a bee's legs are mostly under its body anyway, so there is little for joints to show.
- **(c)** saves CPU and spends GPU, and it has a fatal flaw: each 64-point square holds eight bees, and a cluster packs eleven or more into a square, so bees vanish exactly where the cold gathers them. More slots cost reads at every pixel on the screen. It would also have to draw from the same atlas that (b) gets drawn for free.
- **(d)** saves 0.08 ms of CPU at 1,000 bees and costs another screen-sized texture. Not worth it.

**Light from the viewer's side.** In an observation hive the light falls through the glass from the room, so a bee seen from above is lit on its back whatever its heading. A sprite turned by `zRotation` is then correct, and Murmuration's sixteen-angle atlas isn't needed. Bake a soft, round contact shadow into each pose, which also looks the same at any heading. The atlas holds a worker seen from above, at about 59 px long at Medium (one size, scaled ±5% a bee), in these poses: four of walking, standing, nodding at a rim, head in a cell (the rear half, foreshortened), the abdomen's tip in a cell, grooming, hanging in a festoon, two bees face to face (two sprites), and fanning (a wing blur). That's about 12 frames of 72 × 72 px, a 300 KB atlas. Whether it is painted or cut from a photograph, and the licence, is the look report's question.

**Order:** give each bee a fixed `zPosition` by its number, and lift the walkers above the still ones, so overlaps never flicker.

### The comb: one shader, kept

Recommended: Ant Colony's arrangement, the comb in a rasterised `SKEffectNode`, its uniform set only when the drawn share moves a step. Drawn every frame, the probe's comb costs 0.32 to 0.42 ms of GPU on a 14-inch display. The finished shader will cost two or three times that, and a 6K display has 3.4 times the pixels. Kept, it costs 0.10 to 0.24 between draws. At Speed 1 a cell changes state every few seconds, so it's drawn again about once a second at most. The price is memory: Ant Colony measured about 50 MB on a 14-inch display and about 160 MB on a 6K, plus the same again behind Settings' page.

What the shader does at each pixel, in the probe's order: find the nearest cell (cube rounding on the warped lattice), read that cell's texel at its centre (no smoothing between cells), then shade.

- **The rim.** The real wall is 0.07 to 0.09 mm, a fifth of a pixel, too thin to see. What shows is the thickened coping at the mouth, so draw a lit rim 1.5 to 2 px wide, smoothed by `fwidth`. It's thicker and ragged at the comb's edge (Darwin's "rude rim").
- **Depth, by the tilt.** The base is drawn shifted down by 0.28 to 0.38 of a cell (the tilt, §1), scaled by how far the walls are drawn out. Above it shows a band of upper inner wall, darkening with depth, and the base itself is three rhombi, shaded apart. A cell just begun is a shallow pit: the facets, and no band.
- **Nectar and honey.** It coats the ceiling, pools low, and when full stands as a meniscus at the mouth. It is amber deepening with thickness (Beer–Lambert), with one highlight from the light behind the viewer, still, because the light is.
- **Caps.** Dry caps are white to very light tan and nearly flat, with the wax's grain. A cap closes from the rim inward over a few minutes of the farm's clock, which is calm and cheap: the cell is capped where the distance in from the rim is under the cap's progress.
- **Wax.** New comb is near-white to pale yellow, with one octave of noise for grain. Whether the comb is lit through from behind (translucent wax, glowing honey) is for the look report; the same shader takes either.
- **Edges and antialiasing.** A 14 pt lattice at half size (Settings' preview, a 1x display, the README's pictures) is a 7 px cell, and thin rims will shimmer unless they are filtered by their slope.

### The battery rate

The fastest thing is a walking bee, at no more than 6 mm/s: 29 px a second at Medium on a 2x display, 1.9 px a frame at 15 fps. **`batteryRate` 15.** At 12 fps it would be 2.4 px a frame, and the 4 Hz walk cycle wants at least 12 fps, so 15 is the safe pick.

## 5. The cold cluster

Read `LiveWeather.shared.latest?.temperature` and call `poll()` from a periodic action, as Weather does, starting `Location.shared` in `didMove(to:)`. **When `latest` is nil (offline, or no location yet), treat the air as warm.** Don't take the 15 °C that `Conditions()` holds by default, because 15 °C is inside the band where bees start to gather. Smooth the reading toward each new report with a time constant of 30 minutes.

| Air, smoothed | Real | On screen |
|---|---|---|
| 18 °C and up | spread over the combs; quiet from 14 to 21 °C (bees' own temperature) | spread over the comb; the standard day |
| 18 to 14 °C | | walkers fall to half; each bee's home drifts toward the cluster site, the area they keep to shrinking to 70% |
| 14 to 10 °C | the cluster breaks up and re-forms at 10 to 14 °C (air) | a cluster forms, a disc of bees packed to about 1.6 a cm², where its loosest edge was 0.6; building, capping and festoons stop, and their bees join it; the comb's clock does not stop |
| 10 °C and below | metabolism rises as it cools; volume about −55% from 4 to −23 °C (**unchecked**) | tight; a growing share go head first into empty cells, only their tips showing, so the disc seen shrinks to about 60% of its area at −20 °C |
| at any cold | 6 to 80 bees an hour come out to a cluster's surface at night | inside the disc nearly nothing moves: now and then one bee shifts |

- **Where:** a cluster sits under the capped honey, on the empty drawn cells of the lower comb, centred across it. In a winter hive that's the boundary of the stores, which the bake keeps empty for it.
- **How calmly:** each bee is given its own moment to move to its new place, spread over the 30 minutes, so at most a few walk at once and the gathering is never a stampede. Loosening on a warm afternoon is the same in reverse.
- **On screen at 500 bees:** fully packed, they cover about 280 cm², a disc about 19 cm across, or about 460 pt at Medium: a mat of bees in the lower middle of the comb.
- **The comb keeps the clock.** Real colonies stop building in the cold, but that would leave a cold day with nothing changing. Say so on the page; it's Dave's call.
- **A conceit to own:** an observation hive stands indoors, and its bees feel the room. Following the outdoor air stands for "the colony where you are", and is a setting (Follow the cold), on by default.
- **Heat, optional:** above about 30 °C, a few bees fanning near the bottom edge, with their wings as a still blur.

## 6. Baked and live, and what stepping costs

| | When | Cost |
|---|---|---|
| The comb's map (and the next day's) | at load and before six, off the main thread | a few ms (estimated) |
| The atlas | once, shared through `sharedTexture` | about 300 KB |
| The comb's picture | when the farm's clock moves a step (about once a second at most at Speed 1), and on every frame of the two-minute change at six | 0.3 to 1 ms of GPU each time (estimated for the finished shader); 0.1 to 0.24 ms between |
| The bees | every frame | see below |
| The temperature | every 10 minutes, smoothed every frame | nothing |

**Stepping.** As in Ant Colony, step in sixtieths of a second counted from when the comb landed, so the picture is the same at 15, 30, 60 and 120 fps. The bees don't need the day replayed from six: when a comb lands, deal the bees to the tasks the map has open at that moment (seeded by the comb and the minute it landed), then run 60 seconds of steps off the main thread so they aren't all starting at once. Ant Colony ran three minutes on.

A real step adds a check against neighbours through a grid of bee-sized squares, for walkers only, plus each task's timer. Estimated at two to four times the probe's trivial walk, under 0.1 ms a step for 500 bees, two steps a frame at 30 fps. So the whole frame is about 0.3 ms of the scene's own CPU, 0.6 to 0.9 ms the render test's way. That is well under 2 ms.

**Cap the bees at 1,200.** A 6K display at Medium and 0.2 a cm² would want 1,700. The probe measured 1,000 at 3024 × 1964; the cap needs measuring again on 6K. Above it, the density falls a little.

## 7. Risks, worst first

1. **A crawling carpet.** Hundreds of insects, many moving at once, can make skin crawl, and that isn't calm whatever each bee's speed. The levers are how many walk (about 60 on a 14-inch display), their slow real pace, a still majority, and festoons and cells to hold bees still. Make a moving mock-up and have Dave judge it before the build.
2. **Insects and holes.** Clusters of holes are the classic trypophobia trigger, and honeycomb is named among them (Cole & Wilkins 2013, *Psychological Science*, **unchecked**, not read). Larvae, eggs and capped brood are the worst of it, so there's no brood at all: a honey comb, where most cells are filled or capped by the afternoon. Dark empty holes should be few: lit, shallow bases, low contrast between rim and hole, soft warm light. The morning's freshly drawn cells are the most hole-like part of the day. Ant Colony's doc already notes that some people don't want insects on screen. Whether Beehive stays out of Shuffle's list until picked is Dave's call.
3. **The comb reads as a flat hex pattern.** The probe's own render does: an even grid of hexagons, honeycomb clip art. Crystals was correct physics that wasn't pretty. What fights it: the tilt (bases a third of a cell low), coping rims, the bent lattice, honey with depth and a highlight, caps with grain, a ragged edge with pits, and perhaps translucency. Judge it beside real photographs, as Galaxy was.
4. **The bees read as stickers.** Rotated sprites all the same, sliding without stepping, overlapping one another. What fights it: an atlas from a real bee, ±5% in size, the walk cycle tied to distance moved (as Ant Colony's feet are), avoidance for walkers, and the still ones never touched.
5. **The morning.** At six only a quarter of the comb is there. The bees, the festoons and the edge have to carry three quarters of an empty screen. The two-minute change at six has to be a dissolve and never a cut, and that has not been tried.
6. **The cold.** It is a conceit for an indoor hive. Offline, the default reading would cluster the bees for no reason (the 15 °C default). A gathering not spread over time becomes a stampede. And the comb keeps building in the cold, which no real colony does.
7. **Count on large displays.** Bees were measured only up to 1,000 at 3024 × 1964. Jointed bodies crashed SpriteKit at 18,000 nodes, so never draw a bee as many sprites.
8. **Memory.** The kept comb costs about 50 MB on a 14-inch display and 160 MB on a 6K (Ant Colony's figures), and the same again behind Settings' page.
9. **Time is compressed.** The comb grows 12 to 16 times as fast as a strong new colony builds (three quarters of 2,500 cm² in a day against 158), and honey that takes 4 to 12 days to ripen is capped within hours. That is the same bargain Ant Colony made, and it should be said on the Settings page or in the doc.

## 8. Settings worth offering

| Setting | Key | What it does | Standard |
|---|---|---|---|
| Speed | `beehive.speed` | 1× to 8×: a comb takes 24 hours divided by it, on Ant Colony's `Cycle`; moving it never moves the work | 1× |
| Bees | `beehive.bees` | 0.5× to 2× of 0.2 bees a cm² of screen (250 to 1,000 on a 14-inch display at Medium), 1,200 at most | 1× |
| Bee size | `beehive.size` | Small, Medium, Large: a cell 10, 14 or 20 pt across; a new comb is baked for it | Medium |
| Follow the cold | `beehive.cold` | the bees gather as the air where you are cools (§5); a status line shows the temperature they follow, as Weather's does | on |
| Look | `beehive.look` | as the look report proposes (comb lit from the front or through from behind, honey's colour) | |

For tests and stills: `beehive.day` (a number like 20261118, the comb of that day), `beehive.hour` (the farm's own hours, of 24, at the first frame), and `beehive.temp` (a fixed air temperature in °C, which also lets the cluster be seen on a warm day). These are Ant Colony's own pins, plus the temperature. The time of day for night behaviour is six plus the farm's hours at Speed 1, so `beehive.hour=17` is eleven at night. Settings' copy gets `HeadStart`, as Ant Colony's does: three in the afternoon of the day's comb.

## What was not done

- No bake of a real comb: the probe's map is a formula. Bake time is estimated.
- The comb shader is about half of what §4 describes (no warp, no tilt shift, no cap closing, no Voronoi). Its cost is a floor.
- Nothing above 1,000 bees, no 6K display, no release build of the app (the probe was built with `-O`), no slower Mac, nothing on battery.
- The bees' sprites are a placeholder painting. Nothing here judges the look.
