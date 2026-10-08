# A Tree for the Year

> **Unfinished, hidden for 1.0 (2026-09-30).** Dave feels A Tree for the Year isn't hitting the mark yet, so it's flagged `unfinished: true` in Scenes.swift: left out of the menu, Settings, Shuffle, the welcome and the README, but still built and render-tested. **Revisit:** ask Dave what's missing (the look, the motion, or something specific), record it under his feedback here, and fix that before un-hiding it. To see it while working on it: `defaults write com.dtanquary.atrium unfinished -bool true`, then relaunch.

One young white oak on a chalk hilltop, living through the real seasons where you are, under Weather's physical sky and your live weather: khaki-gold bud break with catkins, lime then deep green, colour from the top and the sunny side down to wine and rust, leaf fall, tan dead leaves held through the winter, and snow on the branches. Wind sways it, rain darkens its bark, and it's this Mac's own tree: grown from a seed saved the first time it's shown, a year older each spring.

- **Files:** `Sources/Atrium/TreeForTheYear.swift` holds the scene (`TreeScene`, a `WeatherScene`), its shader, `Phenology` and the grass's year. `Sources/TreeGrowth/TreeGrowth.swift` grows and bakes the tree, in its own module (see Performance). `Resources/tree-*`: the hilltop, its aux map, six oak leaves (colour, normals, translucency) and oak bark, credited in `tree-credits.tsv`. Tests: `Tests/AtriumTests/TreeTests.swift`.
- **Entry:** `treeForTheYear(size:)` builds `final class TreeScene: WeatherScene`. Its entry in Scenes.swift is "A Tree for the Year", icon `tree.fill`, tint `.green`, with `TreeScene.treeKnobs` and Weather's status line under its Weather menu.
- **Kind:** Weather's scene on another ground, with a procedural tree baked once a year into three depth slabs of data textures and drawn by one shader.
- **Research:** three agents, 2026-09-26/27: technique (a Python prototype, then the Swift port), reference photos and phenology, and CC0 assets. Their notes, prototypes and renders are in the session scratchpad; the directions page Dave chose from is https://claude.ai/artifact/X8dckuvj76SiqRJpXjmqvh.

## How it works
- **Weather underneath:** `TreeScene` subclasses `WeatherScene` (see [weather.md](weather.md), "As a base for other wallpapers") with `WeatherGround.cissbury` and its own settings keys (`tree.lock`, …). So the sky, clouds and their shadows, rain, snow, fog, lightning, the real Sun and Moon, day and night are Weather's. The tree is added in `addForeground()`, between the land and the rain, and lit through `relight(direct:from:sky:)`.
- **The hilltop:** Cissbury Ring on the South Downs (Andy Li, CC0), whose own lone tree, bench, shadow and worn patch were painted out by image quilting from the same photo, with the sky cut out and about two-thirds of the hard April sun's shading flattened toward overcast (so Weather can relight it). Its aux map is Depth Anything distance plus woody patches, as Weather's. Its top sits at 0.36 of the screen, the horizon at 0.30, so the tree stands against the sky.
- **Growth** (`TreeGrowth.colonize`), replayed from year 1 to the tree's age at every bake, from a seed, deterministically (SplitMix64 hashes of seed, stream and index, the same numbers the Python prototype used):
  - Each year a crown envelope grows to that year's size, after USDA Silvics and Ek (1974): height +0.4 m a year, slowing to 0.15 from 30 to 70; trunk +0.9 cm; crown width 1.12 + 0.221 × DBH(cm); the clear trunk lifts from 0.5 m to 2 m at 30 and 4 m by 80; half growth for two years after planting. It's widest 40% up, pointed when young (superellipse 1.35) and domed when old (2.2), with ±16% lumps.
  - New attractors fill only the new shell (and 3% everywhere); a leader and a whorl of 3–5 laterals a year until 35; five iterations of space colonisation (Runions et al. 2007) from last year's skeleton, on a uniform grid. Kinks (0.2 rad, redrawn at forks) and zigzags (0.12) are fixed when a node is born, so the bare structure never changes afterwards. Limbs below the rising clear trunk are shed.
  - Radii by the pipe model (exponent 2.3), older wood thicker, so limbs taper along their length. Leaves are fresh each year: shoots at the twig tips in a clump field scaled to the crown (3–5 clumps per 4 m of its width, sharp-edged, so the crown is lumps with gaps between), 5–9 leaves each, plus two side twigs per shoot for the winter haze.
  - At 15 the oak is 5.8 m tall with 1.5k live nodes and 27k leaves; at 30, 11.5 m, 7.8k and 109k.
- **Age** (`Phenology.age`): 15 when planted, a year older at each bud break since, when an oak puts on its year's growth in one flush. The seed and the planting day are saved in UserDefaults (`tree.seed`, `tree.planted`) the first time the scene is shown. The tree's height on screen eases from 37% at 15 toward 60% over decades.
- **The bake** (`TreeGrowth.bake`), for the screen at 2x: light through the canopy on a 0.15 m voxel grid of leaf area (Beer–Lambert toward three fixed lights, upper left and upper right behind the viewer and one low ahead for golden hour, plus sky occlusion over 10 directions), with each leaf's lighting leaning 60% toward its leaf mass's outward normal (from a coarser, blurred density grid), so every lump has a sunny side and a shady side, the cauliflower read of real crowns; each leaf a photo card (alpha, detail, normal map, translucency) at its projected size and angle; branches as tapered capsules with the bark photo's luminance, a z-buffer, and a snow cap on the screen-up side of level ones (1.4 + 0.9 × radius px on limbs, up to 8); the snow each leaf would catch (open sky above, facing up: the tops of held clusters); and the tree's contact shadow, what it blocks straight down, at half resolution. Leaves and wood are sorted into three depth slabs, slab 0 the farthest, each four RGBA8 textures:
  - leafL: sqrt(left, right, back ÷ 1.6), coverage
  - leafS: sqrt(ambient ÷ 1.6), turn, fall or held, tint and underside (read `.nearest`)
  - woodL: sqrt(bark × left, right, back ÷ 0.35), coverage
  - woodX: sqrt(bark × ambient ÷ 0.35), snow on the wood, snow on the leaf in front
- **Each leaf's year** (in the shader, from its seeds and the calendar, so the season needs no rebake): it unfolds on its own day in the 16 days after bud break, rose-grey for a week (the pink only shows close up), catkin gold at the crown's scale, then lime, reaching summer green 5 weeks after the leaves are full. Whole branch sectors lean a little warmer or cooler in summer. In autumn each leaf turns within ±17 days of the tree's dates, the top and the sunny outside first and whole branch sectors together, so at the peak the crown's inside is still dark green-bronze, wine to rust (a young tree runs rose-red), browns, and falls. A share of leaves, low and inside, is held (marcescence): 65% at 15, falling to 12% at 40; they go tan after the peak, pale buff by March, and drop just before the buds break.
- **Calendar** (`Phenology`): white oak at 42°N from USA-NPN records (40–45°N, 2010–2025): swell 105, break 115, full 144; onset 278, peak 301, half down 313, bare 318 (days of the year). Elsewhere spring moves 4 days later for each degree further from the equator and autumn 3 sooner (Hopkins; JMA's normals bear it out), with latitudes held to 28°–50°, and south of the equator the year is half a year on. The day is fractional and moves with the clock, so nothing ever jumps.
- **Light** (`relight`): Weather hands over the Sun's (or Moon's) light, its direction and the diffuse light in the ground shader's units. The tree splits the direct light into its three baked directions by where the Sun is relative to the view (Weather faces today's sunset, so golden hour is backlit: a dark crown whose edge leaves glow, through-light more saturated with the blue gone). The tree's real albedos (a leaf is about 0.08) are raised by `gain` 3, since the photo ground's colours carry the photo's own exposure (grass about 0.25), and the skylight inside the crown by `ambient` 0.6; the skylight is π × a patch of clear sky. Then, like the ground at its foot: the night's blue-grey (`u_colour`), haze toward the horizon's sky (as if 0.3 away, not the 1.6 the depth map gives the grass there, which veiled the dark crown), fog (at 1.6, as that grass), and `sqrt(1 − exp(−x))`.
- **Weather on the tree:** rain (or drizzle, showers, a storm, or over 0.2 mm in the last hour) soaks the bark, about two stops darker and a little more saturated, and darkens the leaves; it dries over three hours. Snow falling or lying (over 5 mm) caps the branches; it's gone two hours after it stops and none lies. Wind at the crown (0.9 × the 10 m wind) bends the whole tree like a cantilever from its trunk base and sways the branches with a phase that varies over the crown, with slow gusts and a leaf flutter, all by `u_now`.
- **Contact shadow:** a sprite multiplied over the grass, blurred more up and down than across (seen this low, the shade under the crown is a thin band), the leafy crown's in leaf and only the wood's when bare, deeper in sunshine (20–45%), and only in front of the trunk and just behind it, since beyond the brow the hill falls away to the far fields.
- **The grass's year** (`greenness`, `grass`): Weather's ground shader grades the open grass (not the chalk, trees or soil, and in patches, as green-up and drying are) by a multiplier the tree scene sets. Dormant straw is R/G 1.30, B/G 0.58 in linear light and 1.6 times as bright; peak green R/G 0.70, B/G 0.30; the photo is about 0.6 (late April). From photos and PhenoCam records of northern Illinois and Wisconsin: green-up from three weeks before bud break to ten days after (so the hill is green under a still-bare tree), a little curing in late summer, and dormant from just after the tree is bare to a month later. Weather itself leaves it off.
- **Light and Dark Mode:** like Weather it ignores the appearance; night follows the Sun.

## Settings
| key | label | range | default | drives |
|---|---|---|---|---|
| `tree.held` | Dead leaves in winter | switch | on | the held leaves; off, they fall with the rest |
| `tree.warmer` | Climate, °C warmer | −4…4 | 0 | spring 4 days sooner and autumn 5 later per degree |
| `tree.sway` | Sway | 0–2× | 1× | the wind's bend, sway and flutter |
| `tree.previewDay` | Preview a day of the year | switch | off | moves `now` to that day this year (the Sun, the season and the tree's age) |
| `tree.day` | Day | Jan 1–Dec 31 | Jun 30 | the day, a new `.date` knob format |
| `tree.lock`, `tree.cloudSpeed`, `tree.previewTime`, `tree.previewHour`, `tree.starTrails` | Weather's own | | | as in Weather, under their own keys |
| `tree.seed`, `tree.planted` | (no control) | | first run | this Mac's tree and its planting day |

## Tuning constants
- Composition: trunk base at 42.5% across and 22% down the photo (on turf just below the brow); `species.baseX`, `frac` in `TreeSpecies`.
- Light: `gain` 3, `ambient` 0.6 (`shaderSource`); haze distance 0.3, fog distance 1.6. Contact shadow 0.2 + 0.25 × the sunny share.
- Crown: clump field 3–5 per 4 m, edges (−0.35, 0.5), floor 0.08; envelope lumps ±24%; `massLight` 0.6; `sectorTint` 1; `autumnSpread` 34 days; crook 0.14, zigzag 0.07.
- Shader colours are `TreeSpecies`' (sRGB): green (62,84,26)…(54,76,26), lime (132,146,54), catkin (158,146,78), rose (160,128,118), autumn (122,40,32)…(104,50,38), young red (138,78,64), brown (112,90,64), held (152,122,90), buff (188,164,128), bark (112,100,86), twigs (72,64,58). They're the reference agent's medians of photos of white oaks through the year, in linear light.
- Rain dries in 3 hours, snow on the branches goes in 2.

## Performance
- Release build, 2x, 1512×982, 2026-09-27: CPU 0.44–0.57 ms, GPU 0.49–0.92 ms (1.3 in snow, as Weather). The tree alone is about 0.1–0.2 ms of GPU.
- The bake: 0.2 s at 15 (0.23 at 20, 0.49 at 30, 2.7 at 60), on the main thread when the scene is built (as Weather's first build is), then kept for every copy of the scene at that size, so the Settings preview and another display share it. It happens again once a year.
- Memory: the tree's 12 textures are about 20 MB at 15, 29 at 30; the hilltop photo 23 MB. A bake is shared by every copy of the scene the same size and goes with the last one showing it, its pixel arrays dropped once they're in textures. Until 2026-10-08 the last three bakes stayed for the app's life, each holding its pixels twice (found in the 1.0 review).
- `TreeGrowth` is its own SwiftPM target built with `-O` even in debug (`unsafeFlags`): unoptimised, the bake took about 100 s, which added that to every `swift test`. It's Foundation and simd only, so it has no SpriteKit.

## Gotchas and shortcuts
- **Slab order:** the prototype first stored slab 0 nearest, so the far crown and trunk were drawn over the near leaves; slab 0 is the farthest now.
- **Thresholds on the internode grid:** leafZone was 0.8 = 5 × the 0.16 m internode, and `dtip < leafZone` flipped on 1e-15 rounding between Python and Swift; it's 0.88.
- **Leaves fall opaque:** semi-transparent leaves read as a grey haze, so each is fully on or off on its own day.
- `ponytail:` white oak only (maple and cherry are more `TreeSpecies` and `Phenology` values and a menu); dates from latitude only (local temperature normals would fix western Europe); no droughts in the grass; no transplant slowdown in the age; the bake on the main thread (fine until about 35 years); no cluster cards for old trees (needed past about 80).

## Checked against real photos
- The reference agent measured white oaks through the year (56 photos, open-grown, by age) and the same trees every few days in Ewing, NJ (Famartin's series): summer crown (61–74, 81–97, 28–41), lit (140,166,92); autumn wine (112,68,57); held leaves (94,77,55); spring at crown scale khaki-gold (154,146,85), since the catkins dominate. The render at 11:00 in July: median (82,99,66), lit (108,130,75), shade (57,71,54), sampled at 2x.
- Forms: height over width about 1.8 young, 1.3 middle-aged, 0.8 mature; the young tree has a leader and whorls, as the Virginia sapling series does.
- Grass: 29 photos, mostly northern Illinois (Midewin in February, March, April and May), and PhenoCam greenness.

## Dave's feedback and decisions
- 2026-09-26, the brief: "one tree that lives on my desktop through the real seasons…", with Photoreal wins as the main risk, planned with him first. Three directions were shown with reference photos: a lone tree on a hill, a bonsai by a window, a branch framing the sky.
- He picked the lone tree now and the **bonsai later**, a **white oak** with a species menu to come, dates from **latitude plus a calibration slider**, and a **young tree of about 15** so the growth shows.
- 2026-09-27: the first version shipped (0.47.0), then a tuning pass (0.47.1), compared before and after in the scene: lumpy crowns lit per mass, a darker autumn interior, thicker snow caps and snow on held leaves, darker bark, straighter young limbs, and a contact shadow.

## Ideas / next steps
- The bonsai by a window (Dave's pick for later): a maple bonsai on a bench seen through a window, which winters outdoors to go dormant.
- Japanese maple and Yoshino cherry as a menu: their leaf cards are in the assets agent's atlas; cherry needs its blossom shown as the same cards, pale, for about 10 days.
- The backlit crown is still a little lit at sunset; photos put a leafy crown at a tenth of the sky's brightness with only the rim glowing.
- The tree's own shadow on the grass, swinging with the Sun (the prototype baked ground shadows per light); only the contact shadow is drawn.
- At 100% the leaf cards still show cut-paper edges.
- Leaf litter under the tree after leaf fall; a sheen of frost on cold mornings; rain dripping.

## Checking it
- `SNAPSHOT_SCENE="A Tree for the Year" SNAPSHOT_DEFAULTS="tree.previewDay=1,tree.day=301,tree.lock=2,tree.previewTime=1,tree.previewHour=15,tree.seed=1" swift test -c release -Xswiftc -enable-testing`: autumn peak on a partly cloudy afternoon. The days used for the docs' images: 122 (spring), 180 (summer), 298 (autumn), 15 with `tree.lock=7` (snow).
- `swift test --filter phenologyFollowsLatitude` and `--filter treeBakesTheSameTreeFromASeed`.
