# Ant Colony

A thin tank seen from the side, with the display as its glass: blue gel lit from its base, sand, or earth. At six in the morning the tank is whole and a few ants are on top of it. They sink a shaft, branch it, open rooms, and carry what they dig up to lie round the mouths. The colony grows with its nest, and by the next morning the nest is finished and another begins.

It imitates the Ant Farm, the toy sold since 1956, and the blue gel tanks that came after it. That name is a registered mark and is used nowhere in the app: see [Rights](#rights).

Dave asked for it on 2026-10-12, slowly evolving and "based on realistic ant movements", and then: "think that sideways clear view into the ant colony as it slowly forms and gets bigger". It was researched and mocked up that day, he chose from the sheets ([Dave's decisions](#daves-decisions-2026-10-12)), and it was built the same day in three steps, then gone over again after the lead's review and Dave's second look at the mock-ups. It was built behind the `unfinished` switch, and has been shown to everyone since 0.111.0 (2026-10-13, when Dave said "unhide all 3 of the new ones").

- **Source:** `Sources/Atrium/AntColony.swift` (the scene, its clock, the five looks' shaders and the ants' sprites), `Sources/AntNest/` (`Nest.swift`, the nest and its bake; `Colony.swift`, the ants; its own module, built with `-O`).
- **Data:** none. Everything is made from the date.
- **Scripts:** `docs/ant-colony/probe.swift` measures what the ants do with nothing drawn, and `wide.swift` runs a thousand nests looking for a crash ([Checking it](#checking-it)); `avinery_curve.py` and `measure_photos.py` are the two measurements taken off other people's films and photographs.
- **Pictures of it:** `docs/images/ant-colony.jpg`, the same moment moving (`ant-colony.webp`, the website's 12 s loop) and one for each other look (`ant-colony-bright-gel.jpg`, `ant-colony-sand.jpg`, `ant-colony-white-sand.jpg`, `ant-colony-earth.jpg`) and one of Large ants early in the day (`ant-colony-large.jpg`); and in `docs/ant-colony/`, one farm at four moments of its day (`day.jpg`), the smallest ants beside the largest (`sizes.jpg`), one ant followed for five seconds (`one-ant.jpg`) and a face at the top of Speed (`face-at-speed-8.jpg`).

## Dave's decisions (2026-10-12)

| Question | His pick |
|---|---|
| Name | Ant Colony |
| What it shows | "that sideways clear view into the ant colony as it slowly forms and gets bigger" |
| Look | "Gel and sand both", as a setting. Then, having seen both rounds of mock-ups: "i love all of the ... mockups, all of what has been shown should be an option to select somehow". So every medium he was shown is a pick: the gel, sand dim and white, and earth |
| The standard look | "Gel" |
| The sand | "Both, as a setting; dim by default" |
| Size of ant | "Middle, with a Size setting" |
| Time | "A farm a day", by the wall's clock, with a Speed slider |
| The toy on screen | no frame and no skyline: the display is the glass, edge to edge |
| How to build | "Build now, refine as it goes" |
| On his desktop, the same evening | "ant colony is great" |
| Which gel to keep (2026-10-13) | "keep both gels for now" |

The lead's calls, which he has not ruled on: the mock-ups' deep dim gel is "Gel", with the brighter gel of the realism pass kept beside it as Bright Gel for him to compare; Speed keeps the nest on the tank; the day begins at six and follows the clock in [The day](#the-day), which is not how ants dig; the colony grows with its nest, and is ants only (no queen, no brood); a young colony sinks one or two shafts at a time; someone is always walking; the slider for how many ants is "Colony size". The builder's, which neither has ruled on: Speed stops at 8; three ants to a face; ninety ants at the most.

## What real ants and nests do

What was read for it, and how. "Full text" was read by the builder; "abstract" and "through a fetch tool" were not, and say less.

### How ants move

| Fact | Number | Source | Read |
|---|---|---|---|
| Gait | An alternating tripod at every speed: the front and hind leg of one side with the middle leg of the other | Wahl, Pfeffer & Wittlinger 2015, *J Comp Physiol A*, https://doi.org/10.1007/s00359-015-0999-2 (a desert ant) | full text |
| Stride | Its length rises in a straight line with speed: 5.93 mm + 0.023 s × speed, for ants about 7 mm long. A foot is down 0.6 to 0.7 of a stride at a walk | same | full text |
| The body rides level | Carried about 0.13 of its length up, bobbing by under 0.02, nose 12 to 15 degrees up | Merienne et al. 2021, *PeerJ*, https://doi.org/10.7717/peerj.10664 | full text |
| Pace inside a nest being dug | 0.27 body lengths a second on average; two that meet turn back 0.34 of the time | Avinery et al. 2023, *J R Soc Interface*, https://pmc.ncbi.nlm.nih.gov/articles/PMC10189599/ | the page's text |
| Pace in tunnels | 2.0 ± 0.8 lengths a second up and 2.3 ± 0.7 down in glass tunnels; legs spread to about a body length where the tunnel is wider | Gravish et al. 2013, *PNAS*, https://pmc.ncbi.nlm.nih.gov/articles/PMC3683784/ | the page's text |
| Stop and go | Movement comes in bouts with stops between, each bout's speed set at its start | Hunt et al. 2016, *R Soc Open Sci*, https://doi.org/10.1098/rsos.150534 | parts |
| How many are idle | Workers inactive 61% of the time; in a dig, "approximately half of the ants seemed to be excavating" in the first hours | Charbonneau, Sasaki & Dornhaus 2017, *PLoS ONE*, https://doi.org/10.1371/journal.pone.0184074; Avinery 2023 | parts |
| Idleness helps a dig | Digging in narrow tunnels goes best when many stay idle and others turn back | Aguilar et al. 2018, *Science*, https://doi.org/10.1126/science.aan3891 | abstract |

Measured by the builder: a real stride off Woehrl, Reinhardt & Blickhan's film of a desert ant (Wikimedia Commons, CC BY-SA 3.0, https://commons.wikimedia.org/wiki/File:Alternating_Tripod_Gait.webm), eight frames 12 ms apart; and the ant's proportions off AntWeb specimen CASENT0102894, a harvester ant worker (CC BY 4.0, https://commons.wikimedia.org/wiki/File:Pogonomyrmex_barbatus_casent0102894_profile_1.jpg): head 0.22 of the body's length, mesosoma 0.30, waist 0.16, gaster 0.31; legs from hip to claw 0.64, 0.70 and 0.87. By eye off a sheet, so within about a tenth. They are `Build` in `Colony.swift`.

Not found: a measured rate of antennation between nestmates in a tunnel, or a measured gait for an ant on a tunnel's wall. Those numbers are the builder's.

### How a nest grows

| Fact | Number | Source | Read |
|---|---|---|---|
| Tunnel width | About one body length: 1.06 ± 0.23 in fire ants, who fit the tunnel to themselves | Gravish et al. 2013 (above) | the page's text |
| Steepness | "In the bulk, ants dig at or below the angle of repose"; "almost vertical descents occur at the top"; "the ants tend to dig in linear segments" | Buarque de Macedo et al. 2021, *PNAS*, https://pmc.ncbi.nlm.nih.gov/articles/PMC8433525/ | through a fetch tool |
| How a network is made | Tunnels "extend in a straight line with active fronts at their end. New tunnels are dug either from the border ... or from the sides of an existing tunnel" | Gautrais et al. 2014, *PLoS ONE*, https://doi.org/10.1371/journal.pone.0109436 | full text, not its parameter values |
| A real nest's parts | Shafts under 1 cm across, steeper with depth; chambers about 1 cm high whatever their area, flat-floored, begun as a niche on a shaft's side; most of them near the top | Tschinkel 2004, *J Insect Sci*, https://pmc.ncbi.nlm.nih.gov/articles/PMC528881/ | full text |
| How fast | Fast, then a stop: exponential growth and then "a saturation phase in which activity was almost totally stopped" | Buhl et al. 2004, *Naturwissenschaften*, https://doi.org/10.1007/s00114-004-0577-x | abstract |
| A vertical slab, start to finish | 40 to 70 fire ants between sheets 2.5 mm apart: "rapid excavation ... at the first few hours, followed by fast decrease" | Avinery et al. 2023 (above) | the page's text |

Measured by the builder, off that paper's own time-lapse (CC BY 4.0, https://figshare.com/articles/journal_contribution/Labeled_Tracking_Videos_and_Scripts/22649689; `docs/ant-colony/avinery_curve.py`): of what was dug in 17 hours, **49% was dug in the first hour, 74% by three hours and 90% by eight.**

### Reference photographs

Looked at, measured for colour (`docs/ant-colony/measure_photos.py`) and compared with the app's renders. None is in the repository or the app; several may not be copied at all. Licences are as each page gave them: the first and the sixth were read at their pages on 2026-10-12 through a fetch tool, the rest are as a helper recorded them that day.

1. A toy sand tank, mid-dig, the sharpest: AntMan3001, https://www.flickr.com/photos/antdude3001/27383673142/ (CC BY-SA 2.0). Sand (211,201,183); tunnels (148,135,118); a tunnel 0.9 to 1.2 ant lengths wide; about a fifth of the sand dug. The sand look was matched to this one.
2. A toy sand tank, late: Jeffrey Zeldman, https://www.flickr.com/photos/zeldman/8142637940/ (CC BY-NC-ND 2.0). The sand left as rounded blocks.
3. An arch-shaped tank, half dug: Fosterx2, https://www.flickr.com/photos/justbcuz/4276215049/ (CC BY-NC-ND 2.0).
4. Two ants in a gallery, close: same, https://www.flickr.com/photos/justbcuz/4276215361/. One is on the sand in side view and one on the glass, seen from below with its legs spread.
5. One harvester ant in side view: same, https://www.flickr.com/photos/justbcuz/4276960030/. Its colour: (148,73,23) in its dark parts, (171,108,49) in its mid tones.
6. A gel tank lit by its own lamps in the dark: Steve Jurvetson, https://www.flickr.com/photos/jurvetson/2635075929/ (CC BY 2.0). Gel (9,54,206) up to (75,142,254); tunnel rims (176,241,251); ants and room black. The gel look was matched to this one.
7. Gel, backlit, close: same, https://www.flickr.com/photos/jurvetson/5268677/ (CC BY 2.0). Five ants in single file, in silhouette, in a tunnel 0.74 ant lengths wide.
8. A home-made nest in fine yellow-brown soil against glass (*Lasius niger* by its title): Tim Keppens, https://www.flickr.com/photos/mckillaboy/3382430428/ (CC BY-NC-ND 2.0). Soil (185,143,95); voids (105,83,52) and darker, fringed with grains stuck to the glass. The earth look's colours are this one's.

## How it works

### The nest is baked, not dug

`Nest` grows a whole nest from a seed before anything is shown (60 ms for a 14-inch display at the middle size, off the main thread). Faces go on in wandering lines pulled toward their own pitch, branch off sideways and stop; three times in four a face that meets another tunnel runs on into it, so galleries join and the medium is left in blocks; new faces open toward the largest undug stretch; rooms two to four ant lengths across swell from a niche in a tunnel's side or end. A tunnel's width wanders and its walls widen slowly behind the face. The finished map is read through a smooth push about a quarter of an ant's length deep, so no wall is a brush stroke, and anything left thinner than 0.4 of a length between two tunnels is taken away with the later one.

What is kept is **one number for each cell: the share of all the digging done when that cell goes.** The nest at any moment is the cells whose number is at most the share dug, so the dug area grows as that share does, and how the share runs against the clock is decided afterwards. A young colony works one face and a grown one eight (`Nest.faces`), and its mouths open one after another, so the first hours are one shaft.

The spoil is its height above the ground at each column, at each of 257 shares (`heap`): a thin layer with a small mound either side of each mouth and a funnel at sand's angle of repose (36 degrees) kept open round it, whose foot is the mouth's own edge. It shows about a twentieth of what is dug: the rest is taken to be carried off, since a slab's own spoil would fill the air above it.

The tunnels' centre lines and the ways between them (a side branch leaving its parent, a face that broke through, two tunnels that cross) are kept for the ants. A way is open once both its ends and the line between them are dug.

It is a believable sketch of a young nest in section, matched to the kinds of feature the papers describe and their sizes. It is not fitted to the statistics of real networks.

### The day

A day runs from six to six, and a nest takes 24 hours divided by Speed. The share dug is 1 − (1 − h/24)² at h hours into a farm: at Speed 1, 8% by seven, 23% by nine, 44% at noon, 75% at six in the evening, 94% at midnight, and the last of it through the small hours. Real ants dig faster still at first (above), which would leave most of a day with a finished nest.

Which farm is on the tank, and how long it has been going, is one `Cycle` shared by every copy of the scene and kept in the defaults (`antcolony.farm`, the day it began and its turn in that day, which together are its seed; `antcolony.began`, when it would have begun at this pace; `antcolony.paced`). So a relaunch finds its place at any Speed from those three numbers, and Shuffle or a rebuild goes on from where it was. Every copy is at the same moment of the same farm; the nest itself is baked for a copy's own size, a tank as wide as its display, so two displays of one size show one nest, and two of different sizes (or Settings' preview) two nests of the one seed, each as far dug as the other.

- **At Speed 1 a farm begins at six and only at six.** From a fresh install it is exactly the day's wall-clock farm. A nest finished early (Speed has been higher) stays finished, its ants about, until six; and an unfinished one carried over from a higher Speed is replaced at six, however far it has got.
- **Above 1 the next farm begins as each ends,** through the fade.
- **Moving Speed never moves the dig,** up or down: as much is dug as was, and it goes on from there at the new pace. (The first build's clock was a plain function of the wall's time and the slider, so a change of Speed could land in another nest.)
- The ants walk no faster at any Speed.

A test's scene, and the copy Settings gives a head start, keep a cycle of their own by the frame's clock, and save nothing.

### The ants

The ants do not dig the nest. At each moment `Colony` sends them to the faces the map says are being worked. The faces that will move within the next minute of the clock come first (the nest's history has others waiting their turn, which do not move for a while), and a moving tunnel face that nobody is at comes before any other task. One ant digs at a time, with up to two more waiting behind or on their way; it digs until the next is waiting behind it, or for a minute or more, then carries a grain up to the spoil by the nearest mouth, drops it (it lies there 45 seconds) and chooses again. The rest go and stand in a room for 20 to 90 seconds, or wander. They walk in bouts with stops; two that meet stop and touch antennae, and a third of the time one turns back; otherwise one crosses to the other wall to pass. There are four ants on a whole tank and the number Colony size asks for when the nest is done, the new ones walking in from the tank's side. When nobody is walking, the one due to move soonest goes at once.

Everything is stepped in sixtieths of a second counted from when the farm landed, each with the share dug at its own moment, so the picture is the same at 15, 30 and 60 frames a second.

**Where an ant is.** Its place in the nest is a point of a tunnel's centre line. Its body's middle is on the line across the tunnel through that point, as far toward the wall it walks on as leaves it riding just clear (`berth`). That stretch is open by construction, so **a body's middle is never over undug medium**, and it is moved off further where its head or gaster would be. How far out it rides changes only as it walks, by four fifths of the distance walked, with a look a body length ahead so that it is on its way up a step in the floor before it reaches it. It faces the way its middle has come over the last half length, so it turns through a corner. (An earlier version put the body on two points of the wall like a cart; near junctions the two points disagreed and bodies jumped a length in a sixtieth of a second.)

**Feet.** Each foot is planted on the wall itself and stays where it is while the body moves over it, then swings to its next hold; the stride is driven by how far the body really moved, in the tripod order and timing of the papers. A foot out of reach steps to a new hold at a walking foot's speed and is never moved while planted. Where there is no wall straight under it, it takes the wall a little ahead or behind if a leg can reach one; and where there is none (over the mouth of a side tunnel), it rests where a floor would be, as an ant on the glass does.

**Turning.** An about turn is a half turn on the spot in 0.7 s, seen end on half-way. Crossing to the other wall, the ant rolls over as it goes (0.35 s): half-way it is seen from above, legs out to both sides.

### The picture

One full-screen sprite with one of five shaders, a look each, and sprites for the ants. Each look is its own source, the two gels and the two sands as well: a variant behind a uniform can move pixels where it never runs.

- **What is dug.** A texture a shader reads is smoothed whatever its filtering is set to, and a rank smoothed between a dug cell and one never dug is a rank nothing has. So the map is read at the middles of the four cells round the pixel, each compared with the share dug on its own, and only then mixed. A cell is open by the time an ant may stand in it and opens over the digging of the twenty cells before, so a face creeps and never jumps a cell. The spoil's top is its height read from a second small texture, the same heights the ants stand on.
- **What a read or two cannot tell** (how near a wall is, at three widths, and which way the wall faces the light) is three blurs of the dug mask in a third texture, worked out again off the main thread for each 4000th of the digging (13 ms).
- **Gel**, the standard, is the mock-up Dave chose from: a deep blue slab that glows toward four lamps in its base; a tunnel is a frosted, paler tube with light gathered into a bright line at its edge, a halo in the gel beside it, a sheen and beads along its wet wall; small bubbles hang in the gel; what is dug lies on top as pale crumbs; the air above is dark but for the glow that leaks up, against which an ant on the heap is a shape. Ants are flat and dark.
- **Bright Gel** is the same tank nearer photograph 6, and far brighter: a bloom of faint rays over each lamp, more bubbles, and tunnels that are the gel's own blue a little paler with bubbles frothing at their walls.
- **Sand.** Grains a tenth of an ant across, scattered one to a square with no lattice to them (on a square lattice they showed as a weave wherever the picture was drawn at half size: a non-Retina display, Settings' preview, a README picture). The scatter is baked once into a tile that repeats every 64 squares (`Nest.scatter`), each of its texels saying which grain it is in, so a pixel finds its grain with one read. The map is read at the middle of the grain a pixel is in, so a grain is there whole or not at all: an edge crumbles by the grain. A grain is as big as its nearest neighbour lets it be. A tunnel is a trough, its wall curving back to the pane behind, dark under its upper lip, with loose grains lying on the pane, most of them along the floors. Ants are red harvesters lit from above, their far legs darker, with a shadow on the pane. **Sand** is the mock-ups' warm sand (211,201,183, warmed) at two thirds of its brightness, with warm dark tunnels; **White Sand** is the toy's, matched to photograph 1, with the grey pane behind.
- **Earth.** Photograph 8's fine yellow-brown soil, too fine to show a grain, in clumps, lit from the upper left, its edge pushed about half a grain deep; tunnels dark, the soil behind in the shadow of the upper lip, with crumbs left on the pane beside the walls and a little light on the floors; a dark room above. Its ants are the sand's, and are not dimmed with the soil: in the first mock-up they were, and could hardly be seen in the tunnels.
- **An ant** is a painted body and a sprite for each length of leg and antenna (16, or 22 for the largest ants, the only ones whose feet are big enough to show a bend), with soft sides so that a leg thinner than a pixel is a faint line and not a row of dots. An ant standing still has only its antennae placed.

## Rights

From the search of 2026-10-12, by a helper who read the USPTO's records; the builder re-read the first record and looked at the frame's drawing. Neither is a lawyer. This is a record search and an opinion, to be checked by a trademark lawyer before the wallpaper is on the Mac App Store.

- The toy's name is a live word mark for "ant vivaria" (US reg. 863461, filed 1967, first use 1956, renewed 2018; owner TBDUM, LLC; https://tsdr.uspto.gov/statusview/sn72268158). The farm skyline is registered as a picture (reg. 2144076), and so is the frame's shape with the skyline in it (reg. 2327915: ribbed side posts with knobs, a top bar, splayed feet). No colour is claimed, so green is not registered.
- Software has been tested once. In 2008 the USPTO refused the name for downloadable games over the toy's registration, asking "Do the games relate to ants, representations of ants and/or the movement of ants?" (https://tsdr.uspto.gov/documentviewer?caseId=sn77445346&docId=OOA20080723112947). A wallpaper of ants moving is that.
- By one cartoonist's own account they enforce it (https://www.infoworld.com/article/2325387/dilbert-creator-charms-at-eclipsecon.html); the letters were not seen.
- The gel toy was sold as AntWorks; its marks are dead (regs. 1943244, 3045965). The blue gel look was not checked for design patents.
- So: the name is in neither the app's name, its interface nor its keywords, and there is no skyline, no ribbed frame and no green plastic. A plain pane, the screen's own edge, sand or gel, tunnels and ants are free. "Ant Colony" had one live hit in the helper's screen of word marks in classes 9, 28, 41 and 42, a board game (reg. 7537568); that is a hit list, not a clearance. Not searched: state, common-law or foreign marks.

## Settings

| Setting | Key | What it does | Default |
|---|---|---|---|
| Look | `antcolony.look` | Gel, Bright Gel, Sand, White Sand or Earth, stored as 0 to 4. The shader and the ants change there and then; the nest stays | Gel |
| Speed | `antcolony.speed` | 1× to 8×: a nest takes 24 hours divided by it. Moving it never moves the dig; the nest goes on from where it is at the new pace. At 1 a farm begins only at six; above 1, as the last ends | 1× |
| Ant size | `antcolony.size` | Small, Medium, Large: an ant 13, 22 or 36 points long. The tank is the display at any size, so smaller ants get a bigger nest, baked afresh | Medium |
| Colony size | `antcolony.ants` | 0.5× to 2× an ant to every 130 square ant lengths of tank when the nest is done (24 on a 14-inch display at Medium, 69 at Small), ninety at the most | 1× |

`antcolony.day` (a number like 20261012) and `antcolony.hour` (a farm's own hours, of 24) are for the tests and for stills: the farm of another day, and how long it has been going at the scene's first frame, from where it runs on at Speed's pace. `antcolony.farm`, `antcolony.began` and `antcolony.paced` are the shared cycle's, kept by the app.

**Why Speed stops at 8.** The ants walk no faster, so the faster the dig, the more of it happens with no ant at the face. The top is where a tunnel face that moves still has an ant digging at it two times in three at every hour of the day. Measured by `probe.swift` over ten minutes at each of four hours, the mean of the nests of 2026-10-12, 13 and 15:

| Speed | 06:30 | 09:00 | 15:00 | 22:00 | all |
|---|---|---|---|---|---|
| 1× | 84% | 74% | 76% | 82% | 79% |
| 2× | 82% | 76% | 75% | 79% | 78% |
| 4× | 76% | 75% | 67% | 78% | 74% |
| 8× | 68% | 68% | 68% | 78% | 70% |
| 12× | 59% | 60% | 70% | 76% | 66% |
| 16× | 48% | 54% | 70% | 77% | 62% |
| 24× | 43% | 54% | 65% | 77% | 60% |

The worst single nest and hour was 66% at 1× and 53% at 8×. At 8 the day's first shaft goes down an ant's length in thirteen seconds. `face-at-speed-8.jpg` is that, in white sand, 0.47 s a tile: one ant digs at the face with another waiting behind it; the digger takes a grain, turns about and leaves, and the other steps up.

Settings' own copy, behind its page, is given three in the afternoon of the day's first farm when the real one is under three tenths dug or over nine (`HeadStart`), so its settings can be judged at any hour. That is a clock of its own: it looks at a copy of the shared cycle and saves nothing, so opening the page moves nothing on the desktop.

## Cost

Measured 2026-10-12 on an M3 Max with other work running, a debug build (the AntNest module optimised), the mean of 30 frames of this scene alone with its colony whole. "CPU" is the render test's figure, which is everything in a frame that is not the GPU's own time; of it, the scene's own update and SpriteKit's drawing were timed apart.

| Display, at 2x | Look, ants | CPU ms (update + drawing) | GPU ms |
|---|---|---|---|
| 14-inch, 1512 × 982 points | Gel, Medium, 24 | 0.9 (0.26 + 0.08) | 0.5 to 0.7 |
| | Bright Gel | the same | 0.85 |
| | Sand or White Sand | the same | 0.45 |
| | Earth | the same | 0.35 |
| | Gel, Small at Colony size 2×, 90 | 1.9 (0.93 + 0.26) | 0.5 |
| 6K, 3008 × 1692 points | Gel, Medium, 82 | 1.6 to 1.75 (0.9 + 0.26) | 1.75 |
| | Gel, Small, 90 | 1.8 (0.92 + 0.26) | 1.7 |
| | Bright Gel, Medium | 1.8 to 2.1 | 2.8 |
| | Sand or White Sand, Medium | 1.6 to 1.85 | 1.5 to 1.7 |
| | Sand, Small, 90 | 1.7 | 1.5 |
| | Earth, Medium, 82 | 1.6 to 1.7 | 1.15 |

- **The colony stops at ninety ants** so that the CPU figure stays under 2 ms on the largest display. An ant is eighteen sprites (two lengths to a leg; three for the largest ants), each placed, turned and stretched every frame it walks; an ant standing still has only its antennae placed. Stepping the ants is the small part: 36 millionths of a second a step for 22 of them (`probe.swift`), two steps to a frame at 30 fps.
- **Sand was 3.7 ms of GPU on a 6K display** while a pixel looked for its grain through the nine squares round it (1.1 ms on a laptop's). With the scatter baked into a tile it is 1.5 to 1.7 ms there.
- **Bright Gel is over the GPU budget on a 6K display** (2.8 ms). It was left until Dave had chosen between the gels; on 2026-10-13 he kept both "for now", so it wants trimming there.
- **Before a farm fades up** its nest is baked and its ants run three minutes on, off the main thread: 0.06 s and 0.03 s on a 14-inch display at Medium, 0.18 and 0.11 at Small; 0.22 and 0.12 on a 6K display at Medium; and at Small on 6K, the largest tank there is (2,545 by 1,432 cells), 0.87 and 0.12, so about a second of black ([Still open](#still-open)). The surroundings follow the nest (13 ms on a 14-inch display, 190 ms for the largest tank) and again each 4000th of the digging.
- **What the update sets was cut** (2026-10-14): an ant's body scales, and its shadow's, are set only when they change (only while it turns about or rolls; each set is a KVO notice), a leg's length is its sprite's width rather than a scale, and `day(at:)` keeps the last day it worked out, so the calendar (1.5 µs a call, every frame) is asked again only after the next six. With 24 Medium ants on the gel the update went from 116.6 to 109.3 µs a frame in a release build (four interleaved runs). Renders match the old code byte for byte at 4, 30 and 120 s and as frames at Speed 8 on sand and with Small ants; the kept day was checked against the calendar's every 37 minutes for two years in five time zones.
- Not measured: a release build, a slower Mac. The research's own timing sketch of a simpler shader ran 0.35, 0.7 and 1.0 ms of GPU at 14-inch, 5K and 6K on the same machine.

**On battery it runs at 20 fps at most** (`batteryRate` in Scenes.swift; 2026-10-13). Walking ants are the fastest thing: up to 1.75 body lengths a second (pace 1.4 × tempo 1.25), so a Medium ant, 44 device pixels (2x on a 14-inch MacBook Pro, 3024 × 1964) long, moves 44–77 px a second, 2.2–3.9 px a frame at 20 fps, with its legs at about 3 Hz. Large ants (72 px) step up to 6 px. Speed doesn't make ants walk faster. Its sprites are placed every frame, so the cap saves CPU as well as GPU.

## Checking it

```sh
swift test --filter 'antColony'
SNAPSHOT_SCENE="Ant Colony" SNAPSHOT_DEFAULTS="antcolony.day=20261013,antcolony.hour=11" swift test --filter everySceneRenders
SNAPSHOT_SCENE="Ant Colony" SNAPSHOT_MOVIE=8 SNAPSHOT_DEFAULTS="antcolony.day=20261013,antcolony.hour=6,antcolony.speed=8,antcolony.look=3" swift test --filter everySceneRenders
swiftc -O Sources/AntNest/Nest.swift Sources/AntNest/Colony.swift docs/ant-colony/probe.swift -o /tmp/probe && /tmp/probe 2026101300
swiftc -O Sources/AntNest/Nest.swift Sources/AntNest/Colony.swift docs/ant-colony/wide.swift -o /tmp/wide && /tmp/wide
```

- **The other tests:** the same seed bakes the same nest and another seed another; the dug area is the share the clock says; the clock's hours; one shaft only in a farm's first twentieth. Three nests at four ages, watched every sixtieth of a second with the digging forty times too fast: no ant's middle is ever over undug medium (0 of 303,038 ant-moments; its head or gaster 111), no planted foot moves, no body goes further in a sixtieth of a second than a quarter of its length (0.069 at most), and someone is always walking. The picture is the same at 15, 30 and 60 fps, in gel and in white sand with small ants at Speed 8; the five looks differ as they should; there is more tunnel at six in the evening than at nine in the morning; Settings' copy opens on a nest part-dug, and its head start saves nothing of the shared cycle; and the frame after Speed goes from 1 to 8, or back, shows exactly as much tunnel as the frame before. The cycle on its own: a fresh one at Speed 1 is the day's wall-clock farm; a change of Speed keeps the hours dug; the next farm begins as one ends above 1 and only at six at 1; a relaunch from the saved numbers is where it was; a clock set back leaves the farm whole.
- **A nest is baked from the date every morning,** so a trap on one date is a crash at every launch that day. The test that stays bakes 36 nests (six dates on six grids: a 14-inch display's at each size of ant, a portrait display's, a 13-inch's, a 5K's), runs each at four ages and once with the clock set back under its ants, and asserts that every ant is somewhere in the tank and none has its middle in the medium (2 s). **`wide.swift`** is the same on twelve grids, up to Small ants on a 6K display (2,545 by 1,432 cells), and as many dates as asked. Its last run of 2026-10-12: 1,080 nests, 91.7 million ant-moments, no trap, 0 middles in the medium, 0 places off the tank or not a number; 966 ants moved to their place at once, 880 of them on the frame the clock went back; fewest mouths 1; every nest had a room. Its first run trapped, on an ant digging in a tunnel the set-back clock had not yet dug; that and two ways of standing in the medium for a moment after a set-back are fixed.
- **`probe.swift`** runs ten minutes at four ages of a day, at each of four Speeds or those asked for, and prints how often a tunnel face that moved had an ant at it, where the ants' time went, how many planted feet were on the medium (and how many were not though some was in reach), and what a step costs. The figures under [Settings](#settings) and [Still open](#still-open) are its, for the nests of 2026-10-12, 13 and 15.
- **Judge motion from strips**, not stills: `SNAPSHOT_MOVIE` saves frames at 15 fps. `one-ant.jpg` (in Bright Gel, 0.2 s a tile) is an ant at a face, turning about and leaving with its grain.
- **The pictures:** each still is the render test at 2x on a 14-inch display, after the 4 seconds it runs unless told otherwise, with one of the sets of defaults below, and then `sips -s format jpeg -s formatOptions 85 -Z 1600` of the test's PNG:
  `SNAPSHOT_SCENE="Ant Colony" SNAPSHOT_DIR=<a folder> SNAPSHOT_DEFAULTS="<below>" swift test -c release -Xswiftc -enable-testing --filter everySceneRenders`
  - `docs/images/ant-colony.jpg`, the README's and the website's look: `antcolony.day=20261013,antcolony.hour=11`. Everything else is as it comes (Gel, Medium ants, Colony size 1×, Speed 1×). Eleven hours into the nest, five in the afternoon by its own clock, 71% dug. The day was picked from four.
  - `ant-colony-bright-gel.jpg`: the same with `antcolony.look=1`.
  - `ant-colony-sand.jpg`: `antcolony.day=20261015,antcolony.hour=11,antcolony.look=2`.
  - `ant-colony-white-sand.jpg`: `antcolony.day=20261014,antcolony.hour=9,antcolony.look=3`.
  - `ant-colony-earth.jpg`: `antcolony.day=20261012,antcolony.hour=10,antcolony.look=4`.
  - `ant-colony-large.jpg`: `antcolony.day=20261013,antcolony.hour=3,antcolony.size=2`. Gel with Large ants, three hours into the nest, nine in the morning, 23% dug: the first shaft and its first branches.
  - `Resources/preview-ant-colony.jpg` is the first: `sips -Z 1200 -s formatOptions 70 docs/images/ant-colony.jpg --out Sources/Atrium/Resources/preview-ant-colony.jpg`.

  A recipe gives the same file byte for byte (the two sands did, on 2026-10-13). The gel, the bright gel, the earth and the preview were retaken that day for the README: theirs were from before ants were sent first to the faces about to move, so the nests were these but the ants were not where the recipes now put them.
- **The loop** on the website's card, and the README's moving picture made from it: `site/media.sh preview-ant-colony card-ant-colony`. Its `PREVIEWS` line is the first still's recipe, 4 seconds in, at Speed 1×: the 12 seconds begin 2 seconds after the still. The ants are what moves. The digging does not show in 12 seconds at that hour at any Speed: with `antcolony.speed=8` two or three faces crept a few pixels (of 3024 across) between the first frame and the twelfth second, and at 1× none did, so the loop is at the Speed the wallpaper comes with. Its last 2 seconds dissolve into its first 2, so for those 2 seconds every ant fades out where it is while it fades in where it began. `docs/images/ant-colony.webp` is `ffmpeg -i site/public/media/preview-ant-colony.hevc.mp4 -vf fps=15,scale=640:-2:flags=lanczos f/%03d.png && img2webp -loop 0 -lossy -q 70 -m 4 -d 67 f/*.png -o docs/images/ant-colony.webp`: 180 frames, 487 KB. It needed no keyframe on every frame: 9 seconds in it shows no blocks, and is within 0.6 dB of its first frame against the frames it was made from.

## Shortcuts

- **An ant is eighteen sprites,** each placed and turned every frame it walks, so the colony stops at ninety ants. One shader drawing a whole ant would lift that.
- **A finished farm gives way to the next through black,** in under half a second. A crossfade needs both farms' textures at once.
- **Every ant is seen from the side.** In a real thin tank some walk on the glass and are seen from above (photograph 4). That is drawn only for the third of a second an ant rolls over.
- **Ants pass through each other.** Two that meet stop and one takes the other wall, but two overlapping shapes are not two bodies squeezing past.
- **The nest is one flat layer.** A real gel tank is 3 cm deep, so its tunnels overlap and catch light on facets.
- **The spoil is a twentieth of what is dug,** by a rule, and grows by a table; a dropped grain is a sprite that fades into it.
- **Each copy of the scene bakes its own nest** (the desktop's, each display's, Settings'), though one would serve them all.
- **There is no Light Mode look.** White Sand is the bright one, by choice.

## Still open

Worst first, as the builder saw it on stills and strips; Dave has not seen it run.

1. **A face still moves alone a fifth to a third of the time:** an ant is digging at a moving tunnel face 79% of the time at Speed 1 and 70% at 8 (the table under [Settings](#settings)). Before ants were sent first to the faces about to move, and before a digger stayed until relieved, it was 59 to 63% in a farm's first half hour and 14 to 53% later.
2. **Bright Gel's tubes are not glass.** Beside photograph 6 they are a paler blue with froth at the walls; the photograph's are clear, with heavy white bubbling and light caught on facets. And it is bright, where Dave's taste is soft and dim: it is there to be compared with Gel.
3. **Feet on nothing.** 84 to 98% of planted feet are on the medium, 91% on average (it was 85% before a foot with nothing straight under it could take the wall a little ahead or behind). Of the rest, a quarter still have some medium within half an ant's length; the others are over the mouth of a side tunnel or a dip in a room's floor, and rest where a floor would be. A walking ant has no wall within a length and a half under it 1 to 12% of the time.
4. **Rooms do not read as rooms.** About twenty are baked in each nest; they look like bulges.
5. **It is busier than real ants:** two fifths to three fifths of the colony are walking at once, where real workers are idle 60% of the time. Dave's rule is lively over realistic, but this has not been judged running.
6. **Crossing to the other wall** happens at many junctions and may read as a twitch.
7. **Now and then an ant is moved to its place at once** (none or one in ten minutes of 22 ants; 86 times in the wide run's 1,080 nests, besides the frame the clock was set back), where neither the straight way nor the way by the middle of the tunnel was open.
8. **Tunnel edges are scalloped at the size of a cell** in the gels and in earth: 4 pixels at Medium, which takes a close look, and 6.5 at Large, where every wall has small regular bumps under its bright rim. In sand the grains hide it.
9. **Tunnels are 1.3 to 1.5 ant lengths wide** once their walls have widened, against the measured one, so ants look small in them.
10. **Digging is a nod of the head,** and a grain appears in the jaws.
11. **The lit ant is drawn, not photographed,** and is lit from its own back, so its highlight turns with it. In earth it is small and bright against a dark tunnel, and has been judged on stills only.
12. **A second of black at Small on a 6K display** before a farm fades up (it was 1.7 to 1.85 s with ten minutes of ants and the surroundings waited for; the bake is one thread and is left so). 0.34 s at Medium there, 0.09 s on a 14-inch display.
13. Not checked: the Settings page itself (its test opens a window on the screen), so the five looks have not been seen in its menu nor the head start behind its page; the picture on a 5K or 6K display (only its cost, off screen); a 1x display, a second display, a slower Mac, a release build, the lock screen's still.
14. **Some people do not want insects on their screen,** and small dark things moving at the edge of vision can read as a real one on the glass. Whether it should be left out of Shuffle's list until picked is Dave's to say.

## Next ideas

- One shader for a whole ant, for a tank of several hundred small ones.
- Ants on the glass, seen from above, where the wall has a gap.
- A crossfade between farms, and a minute of the finished nest held before it.
- Rooms with flat floors and a use: ants resting in rows, a store of seeds.
- An Activity slider, from the measured idleness to what is there now.
- Fewer ants walking at night.
