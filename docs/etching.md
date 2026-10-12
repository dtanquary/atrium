# Etching

Old etchings, engravings and woodcuts drawn line by line: each one slowly, in one unbroken line, on a screen of grey powder. The screen imitates the Etch A Sketch's: a stylus scrapes the powder off the back of the glass, so the line is the dark inside showing through, and it can never lift. That name is used nowhere in the app.

**Hidden while Dave tests it** (`unfinished: true`). He asked for it on 2026-10-12 (a wallpaper in that toy's style "where intricate public domain images become slowly drawn out over time starting from fresh"), it was researched and mocked up that day, and built the same day in three steps.

**The name is Dave's pick** (2026-10-12): Etching names the old prints being drawn, is not a piece of the toy's mark, and nobody holds it ([below](#names-and-look-alikes)). It was built under the working name "Line Drawing", which is why its module is still `LineRoute`.

## Names and look-alikes

From the rights research of 2026-10-12, which read the US Patent and Trademark Office's records (status pages are `https://tsdr.uspto.gov/statusview/sn<serial>`). Not a lawyer's advice.

- **The toy's name is a registered word mark** of Spin Master Ltd. (reg. 725595, serial 72110281, live), and since 2026-05-05 also for "downloadable computer software applications featuring digital art and drawing" (reg. 8237930, serial 97223677). So the name is not the wallpaper's, and appears in no menu, setting, store listing or keyword.
- **The toy's shape is registered too** (reg. 1587707, serial 73701288): a drawing of a frame, a screen and two circles in the lower corners, with no colour claimed. Red with white knobs is its famous look. So a frame, if one comes, is plainly not the toy's: another material and colour, the dials not in the lower corners.
- **The mechanism is free:** one unbroken line scraped into grey powder. The patents are long expired.
- **Dave asked whether "Etch" alone was safe.** Spin Master holds only the full name and two variants, and ten other owners hold ETCH for other things. It is an ordinary word, but it is the first word of the mark, and beside a grey screen and a dial-drawn line it reads as a reference to the toy. The research's order of risk, low to high: Line Drawing, Etching, Etch, the toy's full name. **Etching** names the pictures, is not a fragment of the mark, and no live mark is exactly ETCHING; Dave chose it.

## Dave's decisions (2026-10-12)

- **The line is unbroken, with shading:** the picture's outlines, then its shading as hatching, the stylus going back along lines already drawn to get from place to place. He saw it beside a line that lifts and chose this.
- **"Screen alone now, frame later."** The screen fills the display. He saw a walnut frame with brass dials and a graphite one mocked up, and chose "our own frame" for later; the picture's rectangle is kept relative to the screen so a frame can take a smaller one.
- **Detail: "Both, as a setting":** the toy's own line width, and a line half as wide. He will judge the default on his desktop; it starts at the toy's.
- **A Speed slider:** "be sure to include a speed slider on the line drawing (etch) wallpaper in case a user wants to see it go faster".
- **The screen follows the system's appearance:** 152 of 255 in Light Mode, 104 in Dark Mode. Changed the same day, once he saw it on his desktop, in Dark Mode: "something off with final etching background color, it does not match any of the mockups that showed a brighter paper like color, is it auto reacting to light and dark theme? it so we need to make the background on etching a configurable option". It was reacting: the mock-ups he approved all showed the bright screen, and his Mac showed the dim one. So the screen is now a setting, Screen: Light (the bright powder, the default, whatever the system is in), Dark, or Match System, which is what it did before.
- **Pictures:** "nothing religious". Classical myth is fine.

The lead's calls, which Dave has not ruled on: progress follows the wall clock; a finished picture rests, clears softly to a ghost, and the next begins; the gone-over line is darker; the Picture menu has Random first.

## How it works

- **A picture is a route**, not an image: the cells the stylus steps through, in order, on a grid of 1024 × 640 (one cell is one step; the line is 1.44 cells wide). `docs/etching/bake.py` makes a route from a picture; the app ships only routes (`Resources/etching-<name>.route`).
- **The route is stamped once** into two textures, off the main thread (`LineRoute.stamp`, in the `LineRoute` module, which is built optimised even in debug). One holds when each texel is first drawn, as a 24-bit share of the route's clock, and how much of it the finished line covers; the other when it is gone over again, to the same 24 bits, and the ghost of the picture before. Until the stamp lands the screen is bare, which is how a drawing starts anyway; then the picture so far fades up over 0.4 s.
- **One shader compares those times with a clock.** So a frame costs the same however much is drawn, and the CPU does nothing per frame but set the clock.
- **Every read of a texture is at a texel's centre.** SpriteKit smooths any texture a shader reads, whatever its filtering mode says, and a time smoothed between a drawn texel and a bare one is a moment when nothing happened: lines would arrive thin and ragged. With a texel to each pixel that is one read of each texture. Above the 14-inch size the textures have a texel to two pixels each way, and the shader reads the four round each pixel, compares each with the clock, and only then mixes them: a pixel softer, a quarter of the memory. A standalone test before the build found 8.8% of pixels wrong when read at plain coordinates, with `.nearest` or `.linear` alike, and 24 in 5.9 million at texel centres.
- **The clock is the wall's** (`Etching.Cycle`). Which picture is on the screen, the one before it and the moment this one was begun are kept in the defaults (`etching.drawing`, `etching.before`, `etching.began`) and shared by every copy of the scene, so a relaunch, Shuffle or a second display goes on from the same place, and a picture carries on while the wallpaper is covered or the Mac is asleep. Moving the Speed slider, or changing the Detail, moves that moment, so the picture stays as far along as it was.
- **A picture is drawn, rests, clears, and the next begins.** It rests for five minutes at speed 1 (less when hurried, never under 20 s), then clears over 12 s whatever the speed: a soft fade, sooner in some places than others, as a shake lays the powder back unevenly. A ghost of its whole line stays (8% of the way to the dark inside) and fades away under the next picture, over its first six minutes of drawing at speed 1 (`Cycle.ghosting`). As first built the ghost stayed until the next clearing, and a print with big darks left a grey shape under the next picture for its whole time: a flaw, not a feature. The next picture is chosen as the clearing starts and stamped during it, so it begins on the frame the clearing ends.
- **A line drawn once is pale; gone over, it is dark.** The first pass draws a line 62% of the way to the dark inside and the second the rest, so outlines the stylus travels along come out bolder, as on the toy.
- **Going back along a line, the stylus goes eight times as fast** as it draws (`LineRoute.haste`, and `HASTE` in the bake). Nothing new appears while it does, but for a pale line turning dark the first time it is gone over. At twice the drawing pace, as first built, a picture stood still for up to 26 s at a time and for 32 to 39% of its clock; at eight times the longest spell is 3.6 to 6.5 s and it is still for 11 to 14%. The lead asked for this once Dave was to watch it at 1×; a frame with dials that keep turning would be the other answer.
- **The screen is bright or dim by a setting** (Screen: Light, Dark or Match System), read every frame. Changing it, or the system's appearance changing under Match System, eases its two colours to the other's over two seconds, under the picture, with nothing rebuilt: the scene watches the appearance itself (`followsAppearance`), so the app never builds it afresh for one.
- **The picture keeps clear of the menu bar:** the grid is fitted below the top 4% of the screen (a notched MacBook's bar is 3.8%).
- **The powder** is a 512-texel tile of grain and soft mottle that repeats, a slow unevenness stretched over the whole screen, light from the upper left and a few bright specks. The slow unevenness is kept faint: it read as cloudy patches on a bare screen at the mock-ups' strength. Measured on a bare screen 2560 px wide with the light taken off, the level's spread after an 80 px blur is 0.86% of the level, where the mock-ups' was 1.67% and the first build's 1.43%. The light falls off by 5% across the bright screen and by 2% across the dim one, where 5% read as a vignette.

## The look, and the real toy

Measured on 2026-10-12 from photos (line widths as a share of the screen's width; levels of 255).

| | The real toy | Here |
|---|---|---|
| A line's width | 1/353 to 1/434 on a soft photo, so too wide; near 1/1200 on a scan of an expert's hatching | 1/711 (Standard), 1/1422 (Fine) |
| Finest hatching | rows 1/610 apart (George Vlosich III's work) | 1/512 (Standard), 1/1024 (Fine) |
| A line drawn once, against the screen | 0.68 to 0.70 of its level, blurred, so the true line is darker | about 0.6 |
| Gone over, against the screen | 0.33 | 0.33 |
| The screen | neutral grey, 137 to 191 with the room's light | 152 (Light), 104 (Dark) |
| The screen's shape | 1.40 to 1.43 wide for 1 high | the display's own |

The photos: a classic toy with an outline drawing, the best unprocessed one found (https://upload.wikimedia.org/wikipedia/commons/5/5a/Etch_A_Sketch_engine_drawing.jpg, CC BY 2.0 per Wikimedia Commons); a close scan and whole works by George Vlosich III (https://gvartwork.com/pages/etch-a-sketch, no licence, reference only); three of Jane Labowitch's (https://www.intrepidtravel.com/adventures/the-worlds-best-etch-a-sketch-artist-does-india/, no licence, reference only).

- **How the experts shade** is what the routes copy: horizontal hatching at an even pitch, then vertical in the darks, then scraped solid, with thick outlines from going over them. Labowitch: "I sometimes have to go over the same area over a dozen times to get the darkest tones" (the page above).
- **How the toy works:** "The inside surface of the glass screen is coated with aluminum powder, which is then scraped off by a movable stylus"; "The "black" line merely exposes the darkness inside the toy" (https://en.wikipedia.org/wiki/Etch_A_Sketch).
- **Not matched:** the real screen has a sheen that moves across it with the light, and its lines are softer and more often doubled, where going back along one misses by a line's width. No sharp unprocessed close-up of a single line was found, and no photo of a cleared screen: the clearing and its ghost are a guess.

## The route's file

Little-endian. `LRT1`; the grid's width and height in cells; the picture's rectangle on it (x, y, width, height); the start cell (x, y), all 16-bit; the number of steps (32-bit); the route's clock as a 32-bit float (cells of drawing, a step back along a line counting an eighth); the length of what follows (32-bit). Then the runs, deflated (raw DEFLATE, which `NSData.decompressed(using: .zlib)` reads): one byte to a run of steps one way, bit 7 set while the stylus goes back along its own line, bits 6 to 4 the direction (east, south, west, north, then the four diagonals from south-east round), bits 3 to 0 the run's length less one.

The app eases each position by one step (a quarter of each neighbour), so corners round a little, and takes the clock along the eased line.

## Making a route

```sh
python3 docs/etching/bake.py <folder of source pictures> Sources/Atrium/Resources          # all six, standard
python3 docs/etching/bake.py <folder of source pictures> Sources/Atrium/Resources --fine   # all six, fine
python3 docs/etching/bake.py <folder of source pictures> Sources/Atrium/Resources wave     # one
```

Needs numpy, scipy, Pillow and clang (for `route.c`, the one slow loop). The source pictures are not in the repo: `PICTURES` in `bake.py` gives each one's address, the file name it is looked for under, and its crop. A bake is the same every time. What it does:

1. **Darkness on the grid:** the picture, cropped, fitted to the grid with a margin, its paper tone taken as bare screen.
2. **Lines:** cells darker than their surroundings (the picture less a 2.5-cell blur of itself), thinned to one cell wide with Zhang and Suen's thinning (T. Y. Zhang and C. Y. Suen, "A fast parallel algorithm for thinning digital patterns", Communications of the ACM 27(3), 1984, https://doi.org/10.1145/357994.358023). Bold strokes are drawn first.
3. **Shading:** six layers switched on by darkness. Horizontal rows every 8 cells, then 4, then 2; vertical columns every 4, then 2; then solid. Neighbouring rows are joined at alternate ends, so the stylus zigzags as a hand does.
4. **One route:** the stylus walks to an undrawn neighbour, straight on first. Stuck, it takes the cheapest way to the nearest wanted cell: back along lines already drawn, or, where a piece of the picture stands alone, across bare screen (a stray mark, costed at twenty times a step back so it is the last resort). The whole picture's outlines come first, then each depth of shading over the whole picture, so a half-drawn picture is a whole composition and not a finished corner.

The fine routes are the same bake on a grid of 2048 × 1280, so everything is half the size: a line half as wide, hatching twice as close.

Tried in the research and dropped: a line that lifts (floating dashes half-way, and two dials could not draw it), finishing the nearest ink first (a finished corner and a bare screen for an hour), hatching alone (stray marks across the bare areas), TSP art and a raster squiggle (neither looks like the toy or like a person drawing).

## The pictures

All landscape, bold, and not religious. Each is shipped as its two routes only; the credits are also in `Resources/etching-credits.tsv`, which Settings → About lists.

| Picture | Source | Licence | At speed 1 | Fine |
|---|---|---|---|---|
| The Great Wave: Hokusai, *Under the Wave off Kanagawa*, c. 1830–32 | The Met, 45434: https://www.metmuseum.org/art/collection/search/45434 | CC0 (The Met's Open Access; `isPublicDomain` true) | 80 min | 152 min |
| The Rhinoceros: Dürer, 1515 | The Met, 356497: https://www.metmuseum.org/art/collection/search/356497 | CC0, as above | 85 min | 168 min |
| A Flea: Hooke, *Micrographia*, Schem. XXXIV, 1665 | Wellcome Collection, L0084699: https://wellcomecollection.org/works/ajveb66y | **CC BY 4.0: must be credited** ("Wellcome Collection") | 80 min | 150 min |
| Interlace: Bourgoin, *Les éléments de l'art arabe: le trait des entrelacs*, plate 96, 1879 (part) | Getty Research Institute, via the Internet Archive: https://archive.org/details/gri_33125012261786/page/n240 | Public domain (the Archive's record: not in copyright) | 23 min | 33 min |
| Flying Machine: O. and W. Wright, US patent 821,393, Fig. 1, 1906 | US Patent and Trademark Office: https://patents.google.com/patent/US821393A | Public domain (patent drawings; the Office asks to be acknowledged) | 27 min | 49 min |
| Mishima Pass: Hokusai, *Mishima Pass in Kai Province*, c. 1830–32 | The Met, 56346: https://www.metmuseum.org/art/collection/search/56346 | CC0, as above | 82 min | 161 min |

The licence lines for the flea, the interlace and the patent were read at their sources by the rights research of 2026-10-12; The Met's for the three prints from its API (`isPublicDomain`) and its API page (https://metmuseum.github.io/: the dataset is under Creative Commons Zero).

- **All six work at both widths.** Fine is the better picture every time: the Rhinoceros gets its scales and plates back, and the Wrights' reference numerals become legible.
- **Mishima Pass at the standard width is the weakest:** the print's graded sky becomes a dark band of hatching along the top, and the ground under the tree is muddled. It is kept because it reads as a tree, a mountain and clouds, and is clearly better fine. A candidate to cut.
- **What suits a single line,** from nine pictures tried: one large subject or one bold pattern, its lines at least two line-widths apart, landscape. Patent drawings, geometric ornament, a natural-history plate of one specimen and bold woodcuts work. Fine tonal engraving, crowded charts and anything that depends on lettering do not: Dürer's *Melencolia I* came out a muddle (and its winged figure reads as an angel, so it is out anyway), and his star chart a tangle.
- **Dropped:** Hokusai's *Ejiri in Suruga Province* (The Met, 36493), because it shows a wayside shrine.

## Settings

| Setting | Range | What it does | Default |
|---|---|---|---|
| Picture | Random, or one of the six | Random draws a different picture each time. Picking one clears the screen for it there and then, and it is drawn over and over | Random |
| Detail | Standard, Fine | the line's width: the toy's own, or half that. The picture stays as far drawn as it was and is stamped again | Standard |
| Speed | 1× to 60× | how fast the stylus goes. At 1× it crosses a fortieth of the screen's width a second as it draws and a picture takes 23 to 85 minutes (33 to 168 fine); at 60× the longest takes a minute and a half (under three) | 1× |
| Screen | Light, Dark, Match System | the powder: bright (152 of 255) or dim (104) whatever the system's appearance, or bright in Light Mode and dim in Dark Mode. A change eases over two seconds, under the picture | Light |

Three more keys, with no page in Settings, set a scene up for the tests and for pictures of it; with any of them the scene keeps a cycle of its own and saves nothing: `etching.drawn` (0 to 1) starts it that share of the way through its picture, `etching.cleared` (0 to 1) that far through its clearing, and `etching.ghost=1` lays the next picture's ghost under it.

The screenshots (`docs/images/etching.jpg`, the dim screen, and `-light.jpg`, the bright one) are the Great Wave 70% drawn (`etching.drawn=0` gives the bare screen the unevenness was measured on). They were made when the screen followed the appearance; now the screen is asked for by name (`etching.screen=0` Light, `1` Dark):

```sh
SNAPSHOT_SCENE="Etching" SNAPSHOT_DEFAULTS="etching.drawn=0.7,etching.picture=1,etching.screen=1" swift test --filter everySceneRenders
```

The Settings page has one still, `preview-etching.jpg`, of the bright screen, in both appearances: the page's live copy is bright as it comes, and a dim still in Dark Mode would fade to a bright picture.

## Cost

Measured by the render test on a 14-inch screen at 2x (M3 Max, 2026-10-12): **0.45 to 0.65 ms of CPU and 0.22 to 0.29 ms of GPU a frame**, whatever the picture, its detail and however much of it is drawn, in on either screen and while clearing.

- **Building:** a standard route decodes in 2 ms and stamps in about 120 ms for 3024 × 1964, off the main thread; a fine one, of four times the steps, in about 150 ms. A scene built part-way through a picture stamps the one before as well, for its ghost.
- **Memory:** the two textures are 48 MB at that size, and a byte a texel more (6 MB) is kept for the next ghost. At 5K, with a texel to two pixels each way, 28 MB; at 6K, 39 MB.
- **Shipped:** twelve routes, 942 KB.
- **Not timed in the app:** a 5K or 6K display (a test draws the picture at 5K through the four-read shader). A standalone copy of the shader, timed the same way before this was built, took 0.57 ms of GPU at 5K and 0.79 at 6K. Nor a GPU slower than an M3 Max, nor the frame on which a texture is first sent.

## Checking it

- `lineRouteDecodesToItsKnownLength`: the Wave's route has the steps and the clock its bake printed, stays on its grid, and never lifts.
- `lineRouteStampsItsTextures`: the stamp covers a fifth of a 14-inch screen, its first row of bytes is the bottom of the screen (SpriteKit's order), and going over a line again is recorded. Prints the decode and stamp times.
- `etchingHasEveryPictureAtBothWidths`: all twelve routes decode on their grids, and the longest is done in under five minutes at the top of the Speed slider.
- `etchingLooksTheSameAtAnyFrameRate`: 15, 30 and 60 frames a second give the same picture to the pixel.
- `etchingCycleFollowsTheClock`: drawing, resting, clearing and the next picture by the clock alone; the Speed slider and the Detail leave a picture as far along as it was; a picked picture follows at once; a day away comes back to a picture part-way through.
- `etchingClearsToAGhost`: full, half cleared and a ghost hold less and less line; and the picture is drawn at a 5K display's size.
- `etchingDrawsTheFineLine`: the fine route is drawn, with a thinner line, and nothing is drawn under the menu bar.
- `etchingFollowsTheAppearance`: set to Match System, the screen's level goes from Light Mode's to Dark Mode's in two seconds.
- `etchingScreenIsTheOneAskedFor`: as it comes the screen is the bright one in Dark Mode; set to Dark it eases to the dim one, and is the dim one in Light Mode.

## Shortcuts

- A texel takes the time of the pass that covers it most, and the finished line's cover. Where a later line overlaps an earlier one's edge by a sliver, that sliver shows with the earlier line (`ponytail:` in `LineRoute.stamp`).
- The stray marks that join separate pieces are part of every unbroken route: 536 cells of them on the Wave.
- The tracer is not an artist: shading in small pale areas turns into boxy meanders, hatching never follows a form, and at the standard width lettering is illegible.

## What is wrong, and next

- **Not yet seen on a desktop.** Everything above is from the render test's pictures. The Settings page has not been opened: the test that does it puts a window on the screen.
- **At 1× the picture still stands still for a few seconds at a time** while the stylus goes back along its line: up to 4.8 s on the Wave and 6.5 on the flea, 11 to 14% of the clock. A frame with dials would show them turning then.
- **The Settings page's live copy shows the same moment as the desktop,** so in a picture's first minutes it is a nearly bare screen.
- **A frame with dials** ("frame later"): the screen is 1.40 : 1 on the toy, so a frame costs picture (62% of the display in the mock-ups). Dials would turn about five times to cross the screen; a fine knurl strobes at 15 frames a second, so theirs would be coarse or blurred.
- **More pictures:** the set is six. The research's shortlist has 25, in four kinds.
