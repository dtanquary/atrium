# Beehive: mock-ups, round 1 (the big choices)

Drawn 2026-11-18 by `mock.swift` (SpriteKit's `SKRenderer`, as the app draws a wallpaper) from `variants.py`, laid out by `sheet.py`. Every desktop tile is the comb's shader and the bees' sprites at 3024 × 1964, written at desktop size (1512 × 982) and scaled to a 640 × 400 tile. Sheet 4's crops and sheet 9's strips are the screen's own pixels at 2x. Each tile's second caption line is measured:
- GPU and CPU time a frame at 3024 × 1964, the medians of 50 frames after 20, stepped at 60 fps, as the method probe timed them. Nebula reads about 1.7 ms of GPU on this M3 Max, with other sessions busy.
- Brightness: the brightest of R, G and B at desktop size, out of 255.
- Hard edges: the share of pixels more than 24 from the pixel 2 px away, at 1,200 px across.
- Holes: black holes among the empty cells showing. A black hole is a drawn, empty cell with no bee near it whose floor's luma is less than half its brightest rim's. That is the 2× rule from research-look.md §4, measured on the 2x frame's values as research-look.md §2 measures a photo.

**To redraw a round:** `python3 -I sheet.py fetch` downloads the bee photograph into `$TMPDIR/beehive-photo/` (or `$BEEHIVE_PHOTO_DIR`). Then `python3 -I sheet.py <name> [out dir]` draws a sheet and prints its table. The names are `sheet1-look`, `sheet2-holds`, `sheet3-bees`, `sheet4-bee`, `sheet5-frame`, `sheet6-day`, `sheet7-cold`, `sheet8-desk`, `sheet9-motion`, `film1-hive` and `film2-morning`. The renderer is rebuilt by itself when `mock.swift` changes. No frame is left on disk: films are piped to ffmpeg.

## What every tile shares
- **The comb** is baked from a seed (`Comb` in mock.swift, 1.3 ms for a 14-inch display), one texel a cell:
  - It records the share of the day's building done when the cell starts (16 bits), the hour it starts to fill and the hour it is capped (eighths of an hour from six hours before six), and what it holds.
  - Two or three tongues hang from the top edge. Each is about as high as it is wide, pointed and then rounding, and slows as it nears the bottom. Its edge is ragged by a cell or two, and the tongues join where they meet.
  - The share drawn follows research-method.md §3: s₀ + (1 − s₀)(1 − (1 − h/24)²), with s₀ = 0.25.
  - A cell's walls rise over 1.5 hours of the farm's clock, so the growing edge is a band two or three cells deep. The method said 20 minutes, which left a band under a cell deep, an edge of whole hexagonal tiles. While a cell's walls rise it is a rounded pit that joins its neighbours, with a thick, rough, pale rim.
  - Nectar arrives 2.2 to 4.3 hours after a cell is drawn, from the top down, in patches, and fills over 1.5 hours.
  - Caps follow 2.7 to 5.9 hours after a cell is full, in patches, the top corners first, each cap closing from the rim inward over 15 minutes.
  - The last 28% of the comb to be drawn, the bottom, stays empty all day for the cluster.
- **The shader** (one source a look, as the app keeps them) works as research-method.md §4 describes:
  - It finds the nearest cell by cube rounding on a lattice bent by up to a third of a cell over about 26 cells, and reads that cell's texel at its centre.
  - The coping rim is 0.84 points wide, smoothed by `fwidth` and lit from the upper left.
  - The floor is pushed down by 0.28 to 0.38 of a cell for the cell's tilt, showing a band of the upper inner wall. The floor is three rhombi shaded apart, with a little occlusion.
  - Honey is Beer–Lambert: the floor times a transmittance a unit deep, raised to the honey's depth, with one still highlight once the cell is nearly full.
  - Caps are domed and grainy, with a groove where each meets its wall. Wax has grain in two octaves, and new wax is paler.
  - A warm lamp beyond the upper left dims toward red, so the far side goes brown and never olive.
- **The bees** are one sprite each from an atlas of ten poses, the head toward +x, lit from the viewer's side, each with a soft contact shadow baked in. The poses are four of walking, standing, head in a cell, the tip in a cell, grooming, hanging in a festoon, and fanning.
  - The photo atlas is the USGS bee (below), masked from its black ground by its brightness, its head turned to +x, with painted legs under it that step in tripods.
  - The painted atlas is drawn in CoreGraphics in research-look.md's bee colours.
  - Both are dimmed to the comb's lamp: the photo's studio light × 0.62, then the look's tint. Each bee takes the lamp's falloff at its place through the sprite's colour.
- **The colony** runs at research-method.md §2's numbers:
  - Density is 0.2 a cm² of screen × Bees (499 on a 14-inch display at Medium), stepped in sixtieths from when the comb landed. Each tile is 180 s on, as Ant Colony runs its ants three minutes on.
  - Each bee cycles through walking, a spell in place and a spell still. Walkers go 2 to 5 mm/s (half that from 21:00 to 06:00), turn at most 45° a second, give way to a bee just ahead and step by the distance they walk. Walks run 2.5 to 7 body lengths to a cell being built, filled or capped, or to anywhere drawn.
  - A spell in place lasts 20 to 90 s: building (a slow nod at the rim), storing (head in a cell being filled), capping (small movements) or grooming. A still spell lasts 20 s to 5 minutes, log-uniform.
  - At most two bees work one cell. 7% sleep in empty cells, and a few pairs face to face pass food.
  - In the morning up to 18% hang in festoons, two or three strands a curtain, from the lower edge.
  - The result is 61 of 499 walking (12%) at 15:00, near the method's "about 60".
  - Only what moves is set each frame: Ant Colony's rule of counting the sprites and the properties set.
- **The cold** follows research-method.md §5, set by `temp`:
  - Between 18 and 14 °C, walkers halve and resting places draw in toward the cluster's site.
  - From 15 °C down, a cluster takes up to 85% of the bees, at 0.6 to 1.6 a cm² from 14 to 10 °C, then up to 1.9.
  - Below 10 °C a growing share go head first into cells, up to 40% at −20 °C.
  - The cluster sits on the empty cells under the honey, its disc kept on the comb.
- **The standard** for everything a sheet doesn't ask: Amber, Medium (a cell 14 points, a bee 29), 1×, honey only, edge to edge, the photo atlas, 22 °C, seed 7, and 9 farm hours (15:00).

## Caps
From research-look.md §3:

| Look | Median | 99th | 99.9th | Other |
|---|---|---|---|---|
| Amber | 75–95 | ≤ 150 | ≤ 175 | glints ≤ 200, hard edges under 10% |
| Old Comb | 40–60 | ≤ 140 | ≤ 160 | |
| New Comb | 140–175 | ≤ 215 | ≤ 230 | |
| Red Lamp | 25–40 | ≤ 110 | | |

**Every Amber tile misses the hard-edge cap** (it measures 15–29%, where 10% is the cap). Its 99th and 99.9th percentiles sit a hair over theirs (151 and 178 on the standard). The rims of the pale growing edge and the bees' outlines are most of it. The real comb photos measure 3% (new comb) to 46% (a frame covered in bees) by the same measure, so a comb with bees on it won't get under 10%. The misses are in **bold** below.

## Sheet 1: the light (`sheet1-look.jpg`)

| Tile | Median | 99th | 99.9th | Max | Edges | Holes | GPU ms | CPU ms |
|---|---|---|---|---|---|---|---|---|
| A Amber | 88 | **151** | **178** | 219 | **21.4%** | 0 / 216 | 0.15 | 0.50 |
| B Old Comb | **63** | 111 | 144 | 183 | 11.0% | 1 / 216 | 0.15 | 0.53 |
| C New Comb (Light Mode) | **125** | 214 | **239** | 255 | 36.3% | 0 / 216 | 0.15 | 0.51 |
| D Red Lamp | 39 | 77 | 94 | 118 | 4.8% | 0 / 216 | 0.16 | 0.46 |
| E Amber lit through from behind | 77 | 163 | 194 | 239 | 34.4% | 0 / 216 | 0.16 | 0.45 |

- **A** is the comb a warm lamp shows: tan capped honey across the top, a band of deep amber uncapped honey with a glint in each full cell, then the pale growing edge of empty cells.
- **B** is the darkest. Its caps glow against the dark wax, and the honey reads well.
- **C**'s median is held down by the room behind the comb, a warm grey, which takes the lower part of the screen at this hour. Its caps were warmed after reading grey beside the yellow wax, as the look report warned. Its wax and caps are the brightest thing in the set.
- **D** is one deep red, flat and calm. It reads as a darkroom, and the comb's structure is hard to see.
- **E** is the inverse of the rest: glowing floors and dark walls. It is the most hole-like picture on the sheet, a lattice of lit cells, and has no cap of its own (it was held to Amber's).

## Sheet 2: what the comb holds, at 20:00 (`sheet2-holds.jpg`)

| Tile | Median | 99th | 99.9th | Max | Edges | Holes |
|---|---|---|---|---|---|---|
| A Honey only | **101** | 149 | 164 | 203 | 20.4% | 0 / 308 |
| B Honey and a band of bee bread | **102** | 148 | 163 | 203 | 20.0% | 0 / 279 |
| C A brood frame | **101** | 148 | 163 | 203 | 17.9% | 0 / 204 |

By 20:00 most of the comb is capped, so the median rises past Amber's cap.
- **B**'s bee bread is a band 3 to 4 cells deep between the honey and the empty bottom, in three colours, packed half way up the cell and never capped.
- **C** has a capped brood ellipse in the lower middle, a pollen ring round it and a honey arch over it. Its brood caps are domed and darker, and at tile size the ellipse reads as a flat salmon disc. No larvae are drawn: an uncapped brood cell is drawn as an empty cell.
- A brood frame isn't something a comb drawn in one day could hold. Brood takes about nine days to cap. C shows the layout, not the timing.

## Sheet 3: how many bees, and how big (`sheet3-bees.jpg`)

| Tile | Bees | Walking | Median | 99th | 99.9th | Edges | GPU ms | CPU ms |
|---|---|---|---|---|---|---|---|---|
| A Small, 1× | 978 | 94 | 90 | 152 | 179 | 28.7% | 0.17 | 0.60 |
| B Medium, 0.5× | 250 | 28 | 90 | 151 | 178 | 20.8% | 0.20 | 0.40 |
| C Medium, 1× | 499 | 61 | 88 | 151 | 178 | 21.4% | 0.19 | 0.46 |
| D Medium, 2× | 998 | 149 | 85 | 149 | 175 | 22.2% | 0.24 | 0.65 |
| E Large, 1× | 245 | 51 | 89 | 149 | 174 | 15.2% | 0.23 | 0.42 |

The sizes are worked out from research-method.md's table: a cell is 10, 14 or 20 points.
- At tile size, A's and D's bees read as a texture of dashes, the "crawling carpet" of the method's risk 1.
- E's bees are big enough to be bees at a glance.

## Sheet 4: how a bee is drawn, at 1:1 device pixels (`sheet4-bee.jpg`)

| Tile | Median | 99th | 99.9th | Max | Edges |
|---|---|---|---|---|---|
| A Photo, capped honey | 104 | 149 | 162 | 184 | 2.6% |
| B Painted, capped honey | 105 | 149 | 162 | 184 | 4.1% |
| C Photo, the building edge | 63 | 162 | 192 | 220 | 5.4% |
| D Painted, the building edge | 58 | 164 | 192 | 220 | 6.9% |

- The photo bees read as bees. Their furred thorax, banded abdomen and folded wings are the real worker's.
- The painted bees read as drawn bees, striped and wasp-like.
- The cell detail shows here, and is lost at desktop size: the caps' grain and domes, the honey's glint, the band of upper wall in empty cells and the rounded pits at the edge.

## Sheet 5: how much of the hive shows (`sheet5-frame.jpg`)

| Tile | Median | 99th | 99.9th | Max | Edges | Holes |
|---|---|---|---|---|---|---|
| A Edge to edge | 88 | 151 | 178 | 219 | 21.4% | 0 / 216 |
| B The frame's top bar and sides | 82 | 148 | 175 | 215 | 19.6% | 1 / 183 |
| C The case, the shutter lifted | 70 | 144 | 171 | 218 | 16.6% | 1 / 95 |

- **B**: the top bar is 46 points of pine and the side bars 30, with a soft shadow on the comb, and the comb hangs from the bar. Bees walk over the wood (a few on the top bar).
- **C** adds a darker case border and the shutter's lower edge across the top, with its shadow. There is no skep anywhere.
- The wood is flat grain from noise: no photo texture was used, and it would need one (Poly Haven's CC0 woods) to stand up at 1:1.

## Sheet 6: one comb through its day (`sheet6-day.jpg`)

| Tile | Median | 99th | 99.9th | Max | Edges | Walking | GPU ms |
|---|---|---|---|---|---|---|---|
| A 06:00, 25% | 12 | 157 | **190** | 227 | 12.0% | 119 | 0.40 |
| B 09:00, 43% | 13 | 154 | **186** | 228 | 16.8% | 89 | 0.40 |
| C 12:00, 58% | 77 | **153** | **185** | 233 | 20.4% | 69 | 0.49 |
| D 18:00, 81% | 98 | 149 | 169 | 206 | 20.9% | 68 | 0.16 |
| E 00:00, 95% | 104 | 147 | 158 | 186 | 18.4% | 81 | 0.15 |
| F 06:00, the next comb dissolving in, half way | 62 | 146 | 165 | 195 | 8.6% | 119 | 0.14 |

- **A and B** are mostly the dark room behind the comb (median 12–13). All 499 bees are on a quarter to two fifths of the screen, with festoons hanging as short curtains from the lower edge. This is the method's risk 5: in the morning the screen is mostly dark, and bees and festoons have to carry it.
- **F** is a plain crossfade of the old comb, whole, with the new one at a quarter. Half way it is muddy: two lattices at half strength, and the old comb's ghost over the dark. The bees stay as they were. A dissolve cell by cell, or in soft patches, would read better, but it was not tried.

## Sheet 7: the cold, at 18:00 (`sheet7-cold.jpg`)

| Tile | Median | 99th | 99.9th | Max | Edges | Walking |
|---|---|---|---|---|---|---|
| A 20 °C | 98 | 149 | 169 | 206 | 20.9% | 68 |
| B 14 °C | 98 | 150 | 170 | 206 | 20.7% | 71 |
| C 8 °C | 99 | 150 | 170 | 206 | 20.3% | 13 |
| D −5 °C | 99 | 150 | 170 | 206 | 20.1% | 15 |

- **B** shows the gathering: walkers drawn toward the lower middle and a small cluster starting there.
- **C and D** show a disc of about 420 bees packed on the empty cells under the honey, a mat with no cells showing, while the rest of the comb is nearly bare. D's is a little smaller and denser, with a share of the bees head first in cells. At tile size C and D look alike: the tightening from 8 to −5 °C is about 10% of the disc's width.
- The comb keeps its clock in the cold, as the method proposed. Real bees would stop building.

## Sheet 8: at the app's scale (`sheet8-desk.jpg`)

The standard (Amber, Medium, 1×, honey, 15:00) at a 14-inch desktop's size, under a menu bar and folders: median 88, 99th 151, 99.9th 178, max 219, edges 21.4%, 0 black holes in 216 empty cells, GPU 0.23 and CPU 0.46 ms.

## Sheet 9 and the films: motion (`sheet9-motion.jpg`, `film1-hive.mp4`, `film2-morning.mp4`)

- **The strips:** a walking bee crosses about 100 points in 10 s at 4 mm/s (0.33 body lengths a second), stepping as it goes. A bee storing nectar is its rear end out of a filling cell, foreshortened, and walks off at about 7 s.
- **`film1-hive`:** 12 s at 15:00, H.264 at 756 × 490, 246 KB.
- **`film2-morning`:** 12 s at 06:30, the small comb crowded and festoons hanging, 184 KB.
- **What the films show:** contact sheets of crops 2 s apart, looked at in place of watching. About one bee in eight is walking, slowly. The rest hold still or move a point or two in place. Nothing darts, flashes or flies. The morning film is denser, about 24% walking in its first minutes, a carpet across the small comb.

## Cost
This is the renderer's own cost, measured on the M3 Max with other sessions rendering. The bake takes 1.3 ms. Medians of 50 frames:

| Comb | Bees | GPU ms | CPU ms |
|---|---|---|---|
| kept (rasterised `SKEffectNode`) | 499 (1×) | 0.15 | 0.46 |
| kept | 998 (2×) | 0.32 | 0.67 |
| drawn every frame | 499 | 0.83 | 0.46 |
| drawn every frame | 998 | 0.86 | 0.65 |

- The finished shader costs 0.83 ms of GPU drawn every frame, two to three times the method probe's floor, as the method expected. Kept, it costs 0.15.
- The CPU figure counts the bees' step, with a give-way check that is O(n²) over neighbours, and the sprites' placement. It is under the 2 ms budget at 2×.
- In the films the comb is drawn again once a second of the farm, as the app would step it.

## Honest, and not yet
**Honest:**
- The bake, the shader, the lamp and the caps are what the build would use.
- The pace, the shares and the cluster are the research's numbers.
- The bee photograph is public domain.
- Sizes are real: a 5.74 mm cell and a 12 mm worker.

**Not yet:**
- **The bee's legs are painted under the photo.** The photograph's own legs are folded under it.
- **The poses are few and simple.** Head in a cell and tip in a cell are crops of the photograph, foreshortened by a squash, not drawn from a bee seen end-on. Grooming and fanning are the standing pose with legs or a wing blur added. A festoon bee is the standing bee with long legs, not a bee seen hanging.
- **The bees are all one bee,** ±5% in size: one worker, one colour.
- **No bee walks on the glass,** with its underside showing.
- **The honey has no depth beyond its colour and one glint.** There is no meniscus ring and no light through the wax.
- **The wood is noise,** not a scan.
- **The six-o'clock change is a plain crossfade** (sheet 6, F).
- **At desktop size the comb is a fine hexagonal lattice.** It reads as a honeycomb, and at a glance it is close to a hex pattern. The tilt, the rims and the patches of state help, but only up close (sheet 4). This is the method's risk 3, and Dave's eye should decide it.
- **Trypophobia:** no black holes by the 2× rule on any tile (worst 1.84×). But the uncapped honey band and the empty bottom are still a field of cells, and the research says blur and distance don't help.

## Assets
- **The bee:** USGS Bee Inventory and Monitoring Lab, *Apis mellifera, light body, back, beltsville, md 2017-05-26-15.12* (Flickr 34886290922). It is marked Public Domain Mark 1.0 on its Flickr page (checked in research-look.md §5), and Commons' licence field for the same file reads "Public domain" (read through the Commons API on 2026-11-18). It is fetched at 1,920 px from Commons into `$TMPDIR` and is not in the repository.
- **Everything else** is drawn: the comb, the wood and the painted bee.
