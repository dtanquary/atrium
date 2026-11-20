# Beehive

An observation hive behind glass: one comb seen face-on, edge to edge across the screen, drawn out cell by cell through the day from the top bar down, filled with honey from the top and capped in patches, with bees working across it at their real, slow pace. At six in the morning a quarter of the comb is there; by the evening most of it is capped; the next morning a new comb dissolves in under the bees. When it is cold where you are, the bees gather into a cluster.

It was pick #5 of the "Atrium Wallpaper Ideas" page of 2026-11-14 (a review of the catalogue by the session atrium-37), in these words: "An observation hive behind glass. Comb is drawn out cell by cell through the day, filled with honey and capped, with bees working across it." What is real: "Built on the wall clock, as the ants' nest is. The bees cluster tighter when it is cold where you are." Builds on Ant Colony: "Ant Colony's way of working: a map of when each cell is built, compared with the clock, and painted insects sent to the working faces." Why: "You called Ant Colony great, and this is built the same way." Risk, medium: "Bees are busier than ants, so the pace has to be calmed without looking wrong." Dave ran `/new-wallpaper` on it on 2026-11-18.

- **Research:** [beehive/research-method.md](beehive/research-method.md) (the comb's and the bees' numbers, the pace, the data model on Ant Colony's engine, the cold cluster, and a SpriteKit probe of four ways to draw the bees, `beehive/probe.swift`) and [beehive/research-look.md](beehive/research-look.md) (reference photos measured by `beehive/measure_photos.py`, four palettes and their brightness caps, trypophobia, what can ship, the name). Every figure in them is marked checked or unchecked.
- **Scripts:** `beehive/mock.swift` draws the mock-ups with SpriteKit as the app would; `sheet.py` lays out the sheets and films from `variants.py`; [beehive/mockups-round1.md](beehive/mockups-round1.md) has every tile's measurements and how to redraw them.
- **Where it stands (2026-11-20):** researched; Dave has picked from round 1 (below); round 2, on the stacked frames, is being drawn. Nothing in `Sources/` yet.

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
- **Still his to decide:** what stacked frames open up, in round 2: how many frames show and how the bars between them look, and how the stack moves on at six.
