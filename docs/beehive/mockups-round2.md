# Beehive: mock-ups, round 2 (the stack)

Drawn 2026-11-20 by `mock.swift` from `variants.py`, laid out by `sheet.py`, as round 1 was ([mockups-round1.md](mockups-round1.md) has how a tile is drawn and measured). Round 2 asks only what Dave's round 1 picks opened up ("1 A/C/B/E, 2 A, 3 C, 4 photo, 5 A, 6 stacked, 7 yes, 8 its ok, 9 yes ok"). It draws his choices: honey only, the photo bees, Medium at 1× (a cell 14 points), edge to edge left and right, 22 °C, seed 7, frames stacked as a real observation hive's.

**To redraw:** `python3 -I sheet.py fetch` downloads the bee photograph and the pine scan into `$TMPDIR/beehive-photo/`. Then `python3 -I sheet.py <name> [out dir]` draws `sheet10-stack`, `sheet11-change`, `sheet12-looks`, `sheet13-desk`, `film3-morning`, `film4-change` and `film4-change-60x`. With `HOLES=1` in the environment, the renderer prints each black hole's place.

## What every tile shares
- **The stack, real to scale.** Langstroth frames, from the cut list in Howland Blackiston's *Building Beehives For Dummies* ([dummies.com, "Cut List for Langstroth Frames"](https://www.dummies.com/article/home-auto-hobbies/hobby-farming/beekeeping/cut-list-for-langstroth-frames-170336/), **checked**):
  - Side bars are 9-1/8" tall for a deep frame and 6-1/4" for a medium.
  - The top bar is 19" × 1-1/16" × 3/4" and the bottom bar 17-3/4" × 3/4" × 3/8". I took the 3/4" and the 3/8" as the faces the glass shows (**unchecked** which face is up, though 1-1/16" is the top bar's usual width from above). Its medium top bar reads "11/16" where the deep's reads "1-1/16", most likely a slip. Other sellers' pages give 11/16" top bars, so the figures vary by maker.
  - The comb is what lies between the bars: 203 mm in a deep frame (496 pt), 130 mm in a medium (318 pt).
  - The bee space between one frame's bottom bar and the next one's top bar is 6.4 to 9.5 mm ([Wikipedia, "Langstroth hive"](https://en.wikipedia.org/wiki/Langstroth_hive), **checked**). It is 8 mm here (19.5 pt), drawn as the dark of the hive's far side.
  - A frame's pitch is 585 pt deep and 407 pt medium. About 1.7 deep or 2.4 medium frames show on a 14-inch screen (1512 × 982 pt).
- **The day's frame is the bottom one, wholly on the screen**, its bottom bar on the screen's lower edge.
  - It is drawn out on round 1's clock: a quarter by six, then s₀ + (1 − s₀)(1 − (1 − h/24)²).
  - It hangs in tongues from its top bar, about one tongue for each comb-height of bar (three or four in a deep frame, five or six in a medium), so they join along the bar before they reach the bottom. With round 1's two or three tongues, a frame three times as wide as it is tall left an empty triangle between them up to the top bar.
- **The frames above are the days before**, each baked from its own day's seed (seed − k for k days ago). So the frame above is the very comb drawn out yesterday, and it runs on its own clock 24 hours ahead:
  - In the stack the bottom 28% fills as well, from about 12:00 to 02:00 (round 1 left it empty all day for the cluster).
  - It is capped 2.7 to 5.9 hours later, on the comb's second day. Yesterday's frame closes its last patches of uncapped honey through the morning.
  - The frame two up is all capped, but for 2% of cells never capped, which show as round amber glints.
  - Times are kept in quarter hours over two and a half days (round 1's eighths covered one), each cell's start jittered by up to a quarter hour so a patch doesn't start on the stroke.
- **The bars are wood from a real scan.** Poly Haven's *coated_pine_02* is pine boards, 2k diffuse, 1.05 m across its 2,048 px, CC0 ([polyhaven.com/license](https://polyhaven.com/license), checked in research-look.md; its size is from Poly Haven's API). Each bar is a strip cut from inside one board along its grain.
  - The scan is tinted by its brightness alone to the look's frame wood (research-look.md §3). Its own orange and its coating's glints are left out.
  - The upper arris catches the lamp and the lower is in shade. The top bar casts a soft shadow 9 points down the comb hung from it.
  - The scan holds 1.95 px a millimetre and the screen asks 4.9 at 2x, so the wood is soft at 1:1. It reads as wood at a desktop's distance.
- **The bees** are round 1's: 499 at Medium, the photo atlas, the same cycle and pace.
  - They live in the stack's coordinates and ride with it when it slides.
  - They reach every frame and walk across the bars. Tasks are drawn from all frames, so most bees work the day's building edge and its filling cells, and yesterday's capping in the morning.
  - Festoons hang from the day's frame's lower edge. The cold cluster's site is the day's frame's empty cells (22 °C here, so none forms).
- **The lamp** falls off by a point's place on the screen, not its place on a comb (`u_origin`, `u_screen`), so the frames and bars share one light.
- **The palettes moved**, so round 1's sheets now redraw a little darker than they were measured:
  - Amber's lamp is down 3%. Round 1's desk sheet now measures 86, 147, 173 and 213, inside Amber's caps; it measured 88, 151, 178 and 219.
  - Old Comb's lamp is down 16%, with its cell floors raised from (68,34,12) to (94,52,20) for the research's "each cell's floor and wall lit".
  - Amber lit from behind is up 5%.

## Sheet 10: how deep a frame (`sheet10-stack.jpg`)

| Tile | Median | 99th | 99.9th | Max | Edges | Holes | GPU ms | CPU ms | Walking |
|---|---|---|---|---|---|---|---|---|---|
| A Deep, 06:30 | 78 | 145 | 167 | 205 | 14.9% | 0 / 32 | 0.15 | 0.46 | 66 |
| B Deep, 15:00 | 93 | 144 | 159 | 200 | 17.4% | 0 / 72 | 0.24 | 0.46 | 48 |
| C Deep, 23:00, just after the change | **13** | 143 | 169 | 220 | 12.0% | 0 / 29 | 0.19 | 0.49 | 125 |
| D Medium, 06:30 | 87 | 142 | 157 | 203 | 14.7% | 0 / 10 | 0.19 | 0.45 | 42 |
| E Medium, 15:00 | 93 | 142 | 154 | 203 | 16.0% | 0 / 44 | 0.19 | 0.45 | 49 |
| F Medium, 23:00, just after the change | 77 | 142 | 156 | 202 | 13.1% | 0 / 14 | 0.13 | 0.49 | 98 |

- **The morning is fixed either way.** The median at 06:30 is 78 deep and 87 medium, where round 1's single comb measured 12. Yesterday's comb fills the top of the screen.
- **The darkest hour moved to just after the change** (sheet 11): the new frame comes in with only its first cells.
  - In deep frames that frame is half the screen, and at 23:00 the median falls to 13, round 1's morning again, until about 03:00.
  - In medium frames it is a third, and the median stays at 77.
  - C and F were added to the sheet for this; the brief asked for A, B, D and E.
- **Deep** gives one band of wood and a day's comb half the screen tall, so the building is the picture. **Medium** gives two bands of wood, a smaller day's comb in five or six tongues, and a busier, stripier screen.
- **Recommendation: medium**, because the screen stays mostly comb at every hour. Every sheet after this one is drawn in medium. Deep is the better picture by day, if the dark half-night after the change is acceptable.

## Sheet 11: how the stack moves on (`sheet11-change.jpg`)

Five moments of each, in medium frames, the clock in each frame's corner.

**The change is at 22:00, not six.** On round 1's clock a comb's first cells appear at 22:00 (the quarter drawn by six is spread over the eight hours before), so the next frame has to be in place by then. At six nothing changes. Moving the change to six would need a different clock: a new comb starting empty at six, which the stack could now carry, since the frames above fill the screen.

| Moment | A median | B median | C median | C holes |
|---|---|---|---|---|
| 0 | 97 | 97 | 97 | 0 / 27 |
| ¼ | 94 | 94 | 96 | 0 / 13 |
| ½ | 90 | 90 | 86 | 0 / 15 |
| ¾ | 80 | 80 | 77 | 1 / 13 |
| 1 | 76 | 76 | 77 | 3 / 29 |

- **A, the stack slides up one frame over 30 minutes**, eased in and out:
  - The frame at the top leaves by the screen's top, the day's finished frame moves up, and a new frame comes in at the bottom on its top bar with only its first cells. The bees ride on the comb, and with the work looked at again every half minute they spread onto the new frame's cells.
  - It moves 0.23 points a second on average, 0.34 at the most: under a pixel a second at 2x, slower than a minute hand. A walking bee goes 4.9 to 12 points a second.
  - The screen is never below a median of 76 through it.
- **B, the same slide over 5 minutes.** The same pictures (a strip can't tell them apart), at 1.4 points a second, 2.0 at the most. That is a visible drift, a third of a slow bee's walk, for five minutes. The films show the difference.
- **C, nothing moves: each comb dissolves into the one below's in soft patches over 30 minutes.**
  - Up the stack it can hardly be seen: a capped comb turns into another capped comb.
  - At the bottom, the finished comb is eaten away in dark blotches to the new frame's few cells, a moth-eaten middle (at ½) that is the most hole-like picture of the round.
  - Its bees are those of whichever comb shows most, switching half way, so in a film they would jump.
- **Recommendation: A.** It is the calmest, with nothing on the screen at any moment that isn't a real hive, and no mud. Nothing flashes and nothing goes blank in any of the three.

## Sheet 12: the four looks in the stack (`sheet12-looks.jpg`)

Medium frames at 15:00. Each look is held to research-look.md §3's caps; Amber lit from behind is held to Amber's.

| Tile | Median | 99th | 99.9th | Max | Edges | Holes | Caps |
|---|---|---|---|---|---|---|---|
| A Amber | 93 | 142 | 154 | 203 | 16.0% | 0 / 44 | 75–95, ≤150, ≤175: inside |
| B New Comb (Light Mode) | 157 | 212 | 227 | 255 | 35.4% | 0 / 44 | 140–175, ≤215, ≤230: inside |
| C Old Comb | 59 | 89 | 111 | 173 | 6.0% | 0 / 44 | 40–60, ≤140, ≤160: inside |
| D Amber lit from behind | 75 | 140 | 170 | 245 | 32.5% | 0 / 44 | Amber's: inside |

- **All four are inside their caps this time.** Round 1 missed on Amber (151 and 178), Old Comb (median 63) and New Comb (median 125). In the stack, New Comb's median rises into its range by itself, since more of the screen is comb and less is the room.
- **Old Comb** first measured a median of 67 and 10 black holes in 44 empty cells: fresh pale rims round dark old floors, 2.1 to 2.4×. Its lamp came down and its floors went up, which cleared both.
  - It is now the murkiest look, and its bees almost vanish into its caps at tile size.
- **New Comb's** bars are bright pale pine, still under its caps' brightness. Its bees are the darkest things on it, as research-look.md expects of bees seen through glass.
- **Lit from behind** glows red-orange through the uncapped band, and its never-capped cells show as a sprinkle of red dots across the caps.
- **Hard edges** run 6 to 35%, against the 10% the look research asks: the lattice and the bees, as in round 1.

## Sheet 13: at the app's scale, at 06:30 (`sheet13-desk.jpg`)

The standard in medium frames at 06:30, under a menu bar and folders: median 87, 99th 142, 99.9th 157, max 203, edges 14.7%, holes 0 of 10, GPU 0.14 and CPU 0.48 ms. Round 1's sheet 6 had a median of 12 at this hour.

What shows at a desktop's distance:
- **The two frames above:** mostly capped comb with bees across it, and round amber glints where cells are still open.
- **Two small patches of empty cells** at the bottom of yesterday's frame: its last-drawn cells, drawn just before six, fill a couple of hours later.
- **The day's frame** in five tongues hanging from its top bar, with festoons.
- **The bars** read as pine.

## The films (`film3-morning.mp4`, `film4-change.mp4`, `film4-change-60x.mp4`)

All three are 12 s at 30 fps, H.264 at 756 × 490, checked from contact sheets of frames 2 s apart (crops for the real-pace films, whole frames for the time-lapse).

| Film | What it shows | Size | What the frames show |
|---|---|---|---|
| `film3-morning` | 06:30 in the stack, at the real pace | 196 KB | About one bee in eight walking, the rest still or working in place, festoons hanging still under the day's tongues |
| `film4-change` | Half way through A's 30-minute slide, at the real pace | 224 KB | The stack moves 4 points in 12 s and can't be seen to move; only the bees do |
| `film4-change-60x` | The same slide from a quarter to two thirds of the way through, at 60×, labelled "60×" in the frame | 615 KB | The stack gliding up, the bars passing, the new frame coming in at the bottom on its top bar with a few cells; at 60× the bees dart, which the label owns up to |

## Cost

Measured on the M3 Max at 3024 × 1964, medians of 50 frames, with other sessions rendering (so ±0.2 ms on GPU):

| What | GPU ms | CPU ms |
|---|---|---|
| Medium stack, kept (rasterised `SKEffectNode`) | 0.19–0.24 | 0.45–0.47 |
| Medium stack, drawn every frame | 0.73–0.77 | 0.47 |
| Deep stack, kept / every frame | 0.15–0.41 / 0.76–0.79 | 0.46 |
| The slide, by moving the kept node itself | **0.91–0.92** | 0.54 |
| The slide, by moving a plain node the kept one sits in | 0.19–0.40 | 0.47–0.49 |
| The dissolve, kept / every frame | 0.19–0.20 / 1.15 | 0.49–0.54 |
| Round 1's single comb, kept | 0.23–0.24 | 0.46–0.47 |

- **The bake:** 1.5 to 1.6 ms for a medium stack's three combs (about 3,400 texels each), 1.5 for a deep stack's two, and 2.1 with a dissolve's four: about half a millisecond a comb, against round 1's 1.3 for one comb the screen's size.
- **A slide must move the kept node's parent, not the node.** Moving an `SKEffectNode` that rasterises drew it again on every frame, which cost more than not keeping it at all. Moving the plain node it sits in kept the raster: the slide costs what a still stack costs, and the comb is drawn again only once a second of the farm, as before. `mock.swift` slides that way.
- **The dissolve draws two combs a pixel** whenever it is drawn again, 1.15 ms unkept.
- The CPU is the bees' and the same as round 1's. A slide adds 0.05 ms for looking at the work again every half minute.

## Honest, and not yet

**Honest:**
- The frames' and bars' sizes are a maker's cut list, and the bee space is the textbook one.
- The wood is a real pine scan.
- Each frame above is exactly the comb drawn out on its day, running on its own clock.
- The slide moves real comb and doesn't fade between two pictures.
- The stack's cost was measured, slide and all.

**Not yet:**
- **The bee space is a black strip.** A real observation hive shows through to its far glass there, and has burr comb and bees bridging the gap between frames. The bars carry no propolis, wedge or nails.
- **The wood is soft at 1:1** (1.95 px a mm stretched to 4.9), and every bar is cut from the same 1.05 m scan.
- **At night more bees walk than by day**, 20 to 25% against 12%: night walkers go at half speed, so each walk takes twice as long, and more are walking at any moment. The method wanted the night calmer, so this is tuning for the build.
- **The cluster in the stack** sits on the day's frame's empty cells. After the change that frame is nearly empty, so a cold night's cluster would sit on the new frame's top cells. Not drawn: the round was at 22 °C.
- **The strips' bees** are made afresh for each moment (each tile is its own still). The films carry them through.
- **One frame a day** is round 1's clock, as Ant Colony's farm is a day. A real colony in a strong flow draws a medium frame of foundation in a few days, not one.
- **The 2% of cells never capped** show at desk size as a sprinkle of amber dots across the frames above.

## Assets
- **The bee:** round 1's, the USGS Bee Inventory and Monitoring Lab's photograph (Public Domain Mark 1.0), fetched into `$TMPDIR`.
- **The wood:** Poly Haven, *coated_pine_02*, 2k diffuse JPEG (md5 9d2bb5797918490d00743efe737c1471), CC0. Fetched into `$TMPDIR/beehive-photo/wood.jpg` by `sheet.py fetch`; not in the repository.
- Everything else is drawn.
