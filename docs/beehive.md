# Beehive

An observation hive behind glass: Langstroth medium frames stacked up the screen, edge to edge, the day's comb in the bottom one drawn out cell by cell from its top bar by the wall clock, filled with honey from the top and capped in patches, with bees working across it at their real, slow pace. The frames above are the days before, each the very comb that was drawn out that day, still closing its last caps. At ten at night the next comb's first cells appear and the stack slides up one frame over half an hour; by six a quarter of it is there. When it is cold where you are, the bees gather into a cluster.

It was pick #5 of the "Atrium Wallpaper Ideas" page of 2026-11-14 (a review of the catalogue by the session atrium-37), in these words: "An observation hive behind glass. Comb is drawn out cell by cell through the day, filled with honey and capped, with bees working across it." What is real: "Built on the wall clock, as the ants' nest is. The bees cluster tighter when it is cold where you are." Builds on Ant Colony: "Ant Colony's way of working: a map of when each cell is built, compared with the clock, and painted insects sent to the working faces." Why: "You called Ant Colony great, and this is built the same way." Risk, medium: "Bees are busier than ants, so the pace has to be calmed without looking wrong." Dave ran `/new-wallpaper` on it on 2026-11-18.

- **Research:** [beehive/research-method.md](beehive/research-method.md) (the comb's and the bees' numbers, the pace, the data model on Ant Colony's engine, the cold cluster, and a SpriteKit probe of four ways to draw the bees, `beehive/probe.swift`) and [beehive/research-look.md](beehive/research-look.md) (reference photos measured by `beehive/measure_photos.py`, four palettes and their brightness caps, trypophobia, what can ship, the name). Every figure in them is marked checked or unchecked.
- **Scripts:** `beehive/mock.swift` draws the mock-ups with SpriteKit as the app would; `sheet.py` lays out the sheets and films from `variants.py`; [beehive/mockups-round1.md](beehive/mockups-round1.md) has every tile's measurements and how to redraw them.
- **Source:** `Sources/Atrium/Beehive.swift` (the scene, its shaders and the comb's bake), sharing Ant Colony's clock (`AntColony.Cycle`, with days that begin at ten at night); `Resources/beehive-wood.jpg` (the bars' wood), `beehive-bees.png` (the bees' atlas) and `preview-beehive.jpg` and `-light.jpg` (Settings' stills); `Tests/AtriumTests/BeehiveTests.swift`.
- **Where it stands (2026-11-20):** researched; Dave has picked from rounds 1 and 2 (below); built, hidden behind `unfinished`, in the four steps under How it works (the stack, the bees, Settings, the cold), all in on 2026-11-20; waiting on Dave's word from his desktop.

## Mock-ups, round 1 (2026-11-18)

Nine sheets and two films, each tile drawn by `beehive/mock.swift` with the bake, shader and colony the build would use: the comb grown from a seed by tongues off the top bar, one texel a cell, the cells' tilt, coping rims, honey and caps; one sprite a bee cut from the USGS Bee Inventory and Monitoring Lab's public-domain photograph, at the research's pace (about 12% walking at 0.33 body lengths a second, 45% still). Every tile carries its brightness, its share of hard edges and its count of black holes (a cell's floor more than 2× darker than its rim); [beehive/mockups-round1.md](beehive/mockups-round1.md) has them all and what isn't honest yet. The standard everywhere a sheet doesn't ask: Amber, Medium bees at 1×, honey only, edge to edge, 22 °C, three in the afternoon.

| Sheet | Question | Tiles | Recommendation |
|---|---|---|---|
| `sheet1-look` | the light | A Amber, B Old Comb, C New Comb (Light Mode), D Red Lamp, E Amber lit from behind | A as the standard, C for Light Mode, B as a pick. D is flat, a darkroom; E is the most hole-like |
| `sheet2-holds` | what the comb holds | A honey only, B honey with a band of bee bread, C a brood frame (capped brood, pollen, a honey arch) | A: the fewest holes, and C's brood reads as a flat disc |
| `sheet3-bees` | how many, how big | A Small 1×, B Medium 0.5×, C Medium 1×, D Medium 2×, E Large 1× | C, with Size and Bees settings as Ant Colony has. A and D read as a crawling texture; E reads as bees at a glance |
| `sheet4-bee` | how a bee is drawn (1:1) | A, C the photo cut-out; B, D painted | the photo: the painted bees read as wasps |
| `sheet5-frame` | how much of the hive shows | A edge to edge, B the frame's bars, C the case with its shutter lifted | A, as Ant Colony's tank |
| `sheet6-day` | one comb through its day | 06:00, 09:00, 12:00, 18:00, 00:00, and the change at six half-way | not a choice; it shows two faults (below) |
| `sheet7-cold` | the cold | 20, 14, 8 and −5 °C outside | follow the cold, on by default |
| `sheet8-desk` | at the app's scale | the standard under a menu bar and folders | |
| `sheet9-motion`, `film1-hive`, `film2-morning` | the pace | a walking bee and a bee storing nectar, 2 s a frame; 12 s films at three in the afternoon and half past six in the morning | judge the crawl from the films |

What the mock-ups showed:
- **Close up the comb and the bees read as real** (sheet 4): the cells' floors sit low by their tilt, honey glows in its cells, the photo bees are bees. **At a desktop's distance the comb is close to a plain hex lattice** (the method's risk 3); the patches of state carry it more than the cells do. Hard edges are 15–36% of each desktop tile against the look research's 10%, the lattice itself being edges.
- **The morning is mostly dark screen.** At six a quarter of the comb hangs from the top with festoons under it, and the median of the frame is 12 of 255; at nine it is 13. The subject is there, but three quarters of the screen is the dark room. Fixes for round 2: frames stacked as a real observation hive's are (three deep), the finished ones above and the day's drawn out below, or a later start.
- **The change at six is muddy** half-way (sheet 6, F): a plain crossfade of two combs of different outlines.
- **No black holes on any tile** (the worst cell 1.84×), but the uncapped band and the empty lower cells are still a field of cells; the research says distance and blur don't help with trypophobia.
- **Brightness:** Amber's 99th and 99.9th percentiles are 151 and 178 against 150 and 175, Old Comb's median 63 against 40–60, New Comb's median 125 against 140–175; each is a small change of the lamp. The evening tiles' median is about 101 against Amber's 95, as more of the comb is capped.
- **Cost** (the mock-up's renderer, 14-inch display at 2x): the comb kept 0.15 ms of GPU, drawn every frame 0.83; the bees 0.46 ms of CPU at 1×, 0.65 at 2×.

## Mock-ups, round 2 (2026-11-20)

Four sheets and three films on the stacked frames Dave chose, drawn in his picks (honey only, the photo bees, Medium at 1×, edge to edge) by the same scripts, now with a stack of Langstroth frames to scale, the frames above baked from the days before (the frame above is yesterday's very comb, still closing its last caps), bars cut from Poly Haven's CC0 pine scan, and the slide. [beehive/mockups-round2.md](beehive/mockups-round2.md) has every tile's measurements, the real frame sizes (checked) and how to redraw them.

| Sheet | Question | Tiles | Recommendation |
|---|---|---|---|
| `sheet10-stack` | how deep a frame | deep and medium frames at 06:30, 15:00 and 23:00 | medium: mostly comb at every hour (median 77 or more). Deep is the better daytime picture but half dark from 22:00 to about 03:00 (median 13) |
| `sheet11-change` | how the stack moves on | A slide up one frame over 30 minutes, B over 5, C each comb dissolving into the one below in patches | A: under a pixel a second, never below median 76. C eats the comb in black blotches, the most hole-like picture of the round |
| `sheet12-looks` | the four looks in the stack | Amber, New Comb, Old Comb, Amber lit from behind | all four now inside their caps (small lamp changes); Old Comb is murky and its bees nearly vanish |
| `sheet13-desk` | at the app's scale | medium, Amber, 06:30 | median 87 where round 1 had 12, no black holes |
| `film3-morning`, `film4-change`, `film4-change-60x` | the pace | 06:30; the slide at real pace; the slide at 60×, labelled | |

What the mock-ups showed:
- **Stacking fixes the morning** in either depth: 06:30's median is 78 (deep) or 87 (medium) against round 1's 12.
- **The change has to be at 22:00, not six.** On round 1's clock a comb's first cells appear at 22:00 (a quarter is drawn overnight by six), so the new frame must be in place by then. Changing at six would need a comb that starts empty at six. Bees build in the dark of the hive all night, so 22:00 is the honest hour.
- **Moving the kept comb node re-rasterises it every frame** (0.91 ms of GPU during a slide); moving a plain parent node keeps the raster (0.19–0.40, as a still). The build slides the parent.
- **Cost of the medium stack:** 0.19–0.24 ms of GPU kept, 0.73–0.77 drawn every frame, 0.45–0.47 of CPU; the three combs bake in 1.5–1.6 ms.
- **Not right yet:** the bee space between frames is a black strip with no wax or bees bridging it; the wood is soft at 1:1 (the scan holds 1.95 px a millimetre, the screen asks 4.9); 20–25% of bees walk at night against 12% by day; the 2% of never-capped cells show as amber dots at desk size; the cold cluster isn't drawn in the stack yet.

## Names and look-alikes

From the look research (search excerpts of trademark aggregators; the USPTO's own search was not run, so this is a record search, not a clearance, to be checked before the Mac App Store, as Ant Colony's Rights say).

- **Beehive** pairs with Ant Colony and clashes with nothing in the menu. Night Sky labels the Beehive Cluster (M44) on the sky, a label and not a menu name. No live registered BEEHIVE mark in classes 9 or 42 turned up; pending applications exist.
- **Honeycomb** and **Hive** are crowded in software (and Honeycomb names the comb alone, the one picture the trypophobia questionnaire uses). **Observation Hive** is the descriptive fallback, used in the description.
- **No skep** (the domed straw hive) anywhere, in the picture, the tile, the site's card or the icon sheet: it is an emblem of the Church of Jesus Christ of Latter-day Saints and of Utah, and of Freemasonry (Etching's rule: nothing religious). A frame hive's comb seen face-on carries none of it.

## Dave's decisions (2026-11-20)

- **Trypophobia: a warning in Settings.** Told that honeycomb is one of the trypophobia questionnaire's two pictures, that distance and blur don't help, and that the uncapped band and the empty bottom are still a field of open cells, he said: "just put a warning in the settings if we build it". So the comb isn't redesigned away from cells; Beehive's Settings page carries a short note that the picture is a honeycomb of open cells, for anyone who finds that uncomfortable. The round 1 measures (most cells capped, no larvae, no cell's floor more than 2× darker than its rim) stay.
- **Round 1's picks**, in his words: "1 A/C/B/E, 2 A, 3 C, 4 photo, 5 A, 6 stacked, 7 yes, 8 its ok, 9 yes ok". He had them on one page with a recommendation beside each.
  - **Look (sheet 1): Amber, New Comb, Old Comb, and Amber lit from behind**, all four as picks. Amber is the standard, as recommended, and New Comb is Light Mode's. He took E as well, which I had called the most hole-like; it is held to its own brightness caps in round 2. Not Red Lamp.
  - **What the comb holds (sheet 2): honey only.** No bee bread, no brood.
  - **Bees (sheet 3): Medium at 1×** as the standard, with Size and Bees settings as Ant Colony has.
  - **The bee (sheet 4): the photo**, cut from the USGS photograph. Not the painted bee.
  - **Frame (sheet 5): edge to edge**, no case or side bars.
  - **The morning (sheet 6): stacked frames**, as a real observation hive's are: finished frames above, the day's drawn out in the bottom one, which also replaces the muddy crossfade at six. Not a later start.
  - **The cold (sheet 7): follow it**, on by default.
  - **At desktop size (sheet 8): "its ok"**: the comb near a hex lattice from across the desk passes.
  - **The pace (sheet 9 and the films): "yes ok"**: the crawl as drawn, about one bee in eight walking at 2–5 mm/s.
- **Round 2's picks**, in his words: "1 medium, 2 A, 3 22:00, 4 all four, 5 ok".
  - **Medium frames** (sheet 10), about two and a half on a 14-inch screen, mostly comb at every hour. Not deep.
  - **The stack slides up one frame over 30 minutes** (sheet 11, A). Not the 5-minute slide, not the dissolve.
  - **At 22:00**, when the new comb's first cells appear on the clock (a quarter drawn overnight by six). Not a comb starting empty at six.
  - **All four looks** in the stack (sheet 12), with Old Comb's bees lifted to stand out.
  - **The desk at 06:30 and the films pass** ("5 ok").
- **Then the build**, hidden behind `unfinished: true`, in the steps under How it works.

## How it works

The plan, from the research and both rounds. Where the build goes another way, a line beginning **As built** is added here.

- **Ant Colony's engine.** A day's comb is baked once off the main thread from its seed as one map, one RGBA8 texel a cell: the share of the day's drawing done when the cell starts, the hours it fills and is capped (quarter hours over two and a half days), and what it holds. One shader a look compares the map with the comb's clock and draws the cells (cube-rounded on a bent lattice, coping rims, the floor pushed down by the cell's tilt, honey by Beer–Lambert, domed grainy caps, a warm lamp from the upper left), kept in a rasterised `SKEffectNode` whose uniforms are set only when they change. `mock.swift`'s `Comb` and shader are the starting point.
- **The clock.** A comb's day runs from 22:00 to 22:00. A quarter is drawn by six, then s₀ + (1 − s₀)(1 − (1 − h/24)²) with s₀ = 0.25. Ant Colony's `Cycle` (the farm, when it began, its pace; Speed 1× to 8×; a farm begins only on the hour at 1×) is shared rather than copied, with the hour a day begins as a parameter (Ant Colony's six, Beehive's 22:00), and Ant Colony's pictures stay the same to the byte.
- **The stack.** Langstroth medium frames to scale (a comb 130 mm, 318 pt at Medium; a pitch of 407 pt), edge to edge left and right, the day's frame at the bottom with its bottom bar on the screen's lower edge. The frames above are the previous days' combs, each from its own day's seed and on its own clock, so the frame above is yesterday's comb, closing its last caps. The bars are cut from Poly Haven's CC0 `coated_pine_02`, shipped as a resource, tinted by brightness to the look.
- **The change at 22:00.** The whole stack slides up one frame over 30 minutes (scaled by Speed) by moving a plain parent node, never the rasterised one (that re-rasterises every frame: 0.91 ms of GPU against 0.19–0.40). The bees ride on the comb.
- **The bees.** One sprite each from an atlas of poses cut from the USGS Bee Inventory and Monitoring Lab's public-domain photograph (shipped as a resource, credited in About), lit from the viewer's side, dimmed to the lamp. Round 1's colony: 0.2 a cm² × Bees, about 12% walking at 2–5 mm/s, 45% still, 40% working in place at the cells the map says are being built, filled and capped; festoons from the day's frame's lower edge in the morning; stepped in sixtieths as Ant Colony's ants are, setting only what moves each frame. Old Comb's bees are lifted to stand out (Dave, round 2).
- **The cold.** `LiveWeather.shared.latest?.temperature` where you are, smoothed over 30 minutes; no report counts as warm. From 18 °C the walkers slow and draw in; below 14 °C a cluster forms on the day's frame's empty cells under its honey, tighter below 10 °C with bees head first in cells. On by default, a switch to turn it off.
- **Settings** (`beehive.`): Look (Amber, New Comb, Old Comb, Lit from Behind; the standard follows Light and Dark Mode, Amber in Dark and New Comb in Light), Speed (1× to 8×), Bee size (Small, Medium, Large: a cell 10, 14 or 20 points), Bees (0.5× to 2×), Follow the cold. A footnote warns that the picture is a honeycomb of open cells, for anyone who finds that uncomfortable (Dave, 2026-11-20). Pins for pictures: `beehive.day`, `beehive.hour`, `beehive.temp`. `HeadStart` for Settings' copy; `batteryRate` 15.
- **Steps**, each a commit, a patch bump and a deploy:
  - **(a) The still:** the stack baked and drawn in Amber, the wood, the clock shared with Ant Colony, hidden, with `preview-beehive.jpg`.
  - **(b) The bees:** the atlas, the colony, `HeadStart`.
  - **(c) Settings and the slide:** the four looks, Size, Bees, Speed, the footnote, the change at 22:00.
  - **(d) The cold:** the live temperature and the cluster.

## The build so far

- **(a) The still stack (2026-11-20).** `Beehive.swift` bakes each comb of the stack from its day (`Comb`, ported from `mock.swift`: 0.5 ms a comb at Medium on a 14-inch display, on the main thread) and draws it with round 2's Amber shader and lamp, the bars cut from the pine scan, all in one rasterised `SKEffectNode` whose uniforms move in steps of ten seconds of the comb's clock. The clock is Ant Colony's `Cycle` with a day that begins at 22:00 (`AntColony.day(at:dawn:)`); Ant Colony's snapshot at a pinned day and hour is the same to the byte before and after. The slide came with this step, since the stack is laid out by it: a comb's first half hour of its own clock eases the stack up one pitch by moving a plain parent node, and the stack is laid out afresh, twice a day, for the screen and a frame below it while it slides and for the screen alone after. The snapshot at 15:00 measures median 96, 99th 143, 99.9th 159 at desktop size (Amber's caps: 75–95, 150, 175; the bees, still to come, bring the median down, as round 2's 93 with bees shows); 06:30 and 22:15 (half way up the slide) were looked at too. Cost in the render test: about 0.4 ms of CPU and 0.12 of GPU a frame.
  - **As built:** no kind texture and no bee bread or brood branches in the shader (honey only, Dave's pick): a cell's random number is a hash of its lattice place. A comb is cut to the part of the screen it covers, so the rasterised texture is the screen's size at rest; the bars are drawn whole.
- **(b) The bees (2026-11-20).** `Bees` is round 1 and 2's colony, ported: 0.2 to a cm² (499 on a 14-inch display at Medium), each cycling through a walk, a spell of work at a cell the map says is being drawn out, filled or capped, and a spell still; one sprite each from an atlas of ten poses cut from the USGS photograph (`Resources/beehive-bees.png`, 38 KB, drawn by `mock.swift`'s `atlasOut` at Large in the photograph's own light), dimmed and tinted by the look and the lamp through the sprite's colour, set only when a bee has moved half a hundredth of the lamp. They live in the stack's points under the same plain node, so they ride the slide, and when a new comb goes in under the stack they move up one frame with theirs. Stepped in sixtieths of a second by the wall's clock, at most a second's worth in one frame. The 06:30 and 15:00 pictures match round 2's sheets: bees crowded on the small comb in the morning with festoons under its tongues, spread over the frames in the afternoon. Brightness at 15:00, desktop size: median 93, 99th 142, 99.9th 155, inside Amber's caps; at 06:30 median 85. Cost in the render test (a debug build): 1.16 ms of CPU and 0.3 to 0.5 of GPU a frame. The first cut gave way by looking at every bee for every walker, 6.3 ms; a grid of squares a bee long brought it down.
  - **As built:** spells in place and still are as long again at night as by day, divided by the night's pace (0.45), so a night walk twice as long doesn't make twice as many walkers (round 2 counted 20–25% walking at night). Festoons form as bees walk to hang under the day's frame's edge while there are fewer than the morning's share (18% at six, none once 75% is drawn), and each hangs 10 to 40 minutes; sleepers stay 10 to 60 minutes in an empty cell; both were forever in the mock-ups, which ran three minutes. Pairs passing food form only when the colony is made. No `HeadStart`: the stack is never empty, so Settings' copy opens on comb and bees at any hour.

- **(c) Settings (2026-11-20).** Look, Speed, Bee size and Bees, and the footnote, as the Settings section below has them; Light Mode's still `preview-beehive-light.jpg` (New Comb). Each look measured at 15:00 at desktop size, with its bees, against research-look.md's caps: Amber median 93, 99th 142, 99.9th 155 (75–95, 150, 175); New Comb 155, 211, 225 (140–175, 215, 230); Old Comb 59, 99, 120 (40–60, 140, 160), its bees now pale enough to stand out; Lit from Behind 75, 140, 174 (held to Amber's). Small at 2× (1,200 bees, five frames on the screen), Large (two frames), 22:15 half way up the slide and Speed 8× were looked at too. Cost in a release build of the render test: 0.66 ms of CPU and 0.20 of GPU at the standard, 0.68 and 0.15 with 1,200 bees; in the debug build 1.14 and 2.33.

- **(d) The cold (2026-11-20).** Follow the cold, on by default: the air where you are from `LiveWeather` (Open-Meteo, polled every 15 minutes while it is on, as Dappled Light does), followed over half an hour; no report yet, or the switch off, is a warm day (22 °C), since the report's own fallback of 15 °C would gather the bees. From 18 °C the bees draw in toward the cluster's place and rest longer, fewer of them working; below 15 °C a share of them form a cluster (85% below 10 °C) packed in rings at 0.6 to 1.9 bees a cm² on the day's frame's empty cells under its honey, a share head first in cells below 10 °C. Each bee has a place in the colony: the first places join first as the air cools and leave last as it warms, each at the end of its own spell, so a cluster gathers or loosens over minutes. On yesterday's frame while the day's comb has under 30 empty cells (the first hours after ten at night). Its page shows the live weather's line under the switch, and Refresh Now. `beehive.temp` pins the air for pictures.
  - **As built:** the cluster sits under the tongue of the day's comb that hangs lowest near the middle, below the middle of its empty cells, with at most half its disc below the comb's lower edge (all of it kept on the comb pushed it up into yesterday's frame). At 85% of 499 bees and 1.6 to 1.9 a cm² its disc is about 400 points across, wider than a medium comb is tall (318), so it reaches over the top bar into the frame above, as a winter cluster spans frames in a real observation hive. Snapshots at 18:00 at 20, 14, 8 and −5 °C match round 1's sheet 7: spread, gathering, then a packed disc; 8 and −5 °C look alike. Cluster bees look again every 2 to 10 minutes and walk to their place if it has moved by half a bee. `BeehiveTests.swift` checks the clock (a quarter by six, the day from ten to ten, the comb before a month's first) and the cluster's share at 22 and 5 °C.

## Settings

Under `beehive.`, as data on its `Wallpaper` entry:
- **Look** (`beehive.look`): 0 New Comb in Light Mode and Amber in Dark Mode (the standard, listed last), 1 Amber, 2 New Comb, 3 Old Comb, 4 Lit from Behind. Each is its own shader source; Old Comb's bees take Amber's light, lifted from its own to stand out on the dark wax (Dave, 2026-11-20).
- **Speed** (`beehive.speed`, 1× to 8×): a comb a day at 1×, the next beginning at ten at night; above it the next begins as each is done (Ant Colony's `Cycle`), and the slide takes half an hour divided by it. The bees keep their real pace.
- **Bee size** (`beehive.size`): Small, Medium, Large, a cell 10, 14 or 20 points across. The frames are to scale with the bees, so Small has more of them on the screen.
- **Bees** (`beehive.bees`, 0.5× to 2×): 0.2 bees to a cm² at 1×, 1,200 at the most.
- **Follow the cold** (`beehive.cold`, on): the bees gather and cluster when the air where you are is cold; the live weather's line and Refresh Now under it.
- A footnote under the Hive section: "Beehive is a honeycomb of open cells. If clusters of holes make you uneasy, you may prefer another wallpaper." (Dave, 2026-11-20: "just put a warning in the settings").
- Kept by the scene, not settings: `beehive.comb`, `beehive.began` and `beehive.paced`, the shared cycle (Ant Colony's three, under Beehive's names).

## Cost

Measured by the render test on the M3 Max, 14-inch display at 2x, with other sessions at work (GPU times move by ±0.3 ms with their load):

| | CPU ms (release) | GPU ms | CPU ms (debug) |
|---|---|---|---|
| Still stack, no bees (step a) | | 0.12 | 0.4 |
| Medium, 1× (499 bees) | 0.66 | 0.15–0.5 | 1.14 |
| Small, 2× (1,200 bees) | 0.68 | 0.15–0.5 | 2.33 |

- The stack is drawn again only when the comb's clock moves a step, every ten seconds of its own (1.25 s at Speed 8): the shader costs about 0.75 ms of GPU then (round 2's figure), and nothing in between.
- A comb bakes in about 0.5 ms at Medium on the main thread; the stack is laid out twice a day (as the slide begins and ends) and when Look or Bee size changes.
- The render test steps 30 frames a second, two sixtieths of the colony a frame; on the desktop at 60 fps it is one.
- `batteryRate` 15: a walker at Large goes at most 17 points a second, 2.3 pixels a frame at 15 fps.

## Checking it

```sh
SNAPSHOT_SCENE="Beehive" SNAPSHOT_DEFAULTS="beehive.day=20261120,beehive.hour=15" swift test --filter everySceneRenders
```
Each look: add `beehive.look=1` (Amber) to `4` (Lit from Behind); `beehive.size=0` and `beehive.bees=2` for the most bees; `SNAPSHOT_APPEARANCE=light` for Light Mode's New Comb, its still `preview-beehive-light.jpg`. A release build's cost: the same with `swift test -c release -Xswiftc -enable-testing`. The cold: `beehive.temp=8` (or 20, 14, −5) with `beehive.hour=18`, as round 1's sheet 7. `beehive.day` pins the comb's day (the comb begun at 22:00 that day, like 20261120) and `beehive.hour` the time of day on the clock (6.5 for 06:30, 22.25 for half way up the slide); with either the scene keeps a clock of its own from its first frame and saves nothing. Settings' still is that 15:00 picture, `sips -s format jpeg -Z 1200 -s formatOptions 70 Beehive.png --out Sources/Atrium/Resources/preview-beehive.jpg`. Ant Colony's picture to compare before and after a change to the shared clock: `SNAPSHOT_SCENE="Ant Colony" SNAPSHOT_DEFAULTS="antcolony.day=20261012,antcolony.hour=9"`.

## Shortcuts

- `ponytail:` pairs of bees passing food are made only when the colony is (at a build or a change of size or number), so they thin out over a day; a bee settling to rest beside another could pair with it if they're missed.

## Dave's feedback

- **2026-11-20, on step (a)** (the still stack, before the bees were in): "I need you to add some settings to the beehive mode, how fast the bees go, let me lock to a specific time of day so i can test other times, not seeing any bees at night i get it but just not the impressive thing, maybe at night we have bees moving around very slowly unlike day what do you think". Step (a) had no bees at any hour; they came with (b). What it changes:
  - **A Bee speed setting**, how fast the bees go (0.5× to 3×), apart from Speed, which is how fast the comb is drawn.
  - **A time of day to hold**: a switch and an hour slider in Settings, freezing the comb and the bees at that hour (the `beehive.hour` pin, made a setting).
  - **Night as the real hive has it**, agreed: every forager is home at night, so the comb is fuller than by day and quieter: more bees on it, fewer walking, at about half the day's pace, some asleep head first in empty cells. A dense, calm carpet with a few slow movers, not an empty comb.
