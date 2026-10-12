# Line Drawing

An old print drawn slowly in one unbroken line on a screen of grey powder: the stylus scrapes the powder off the back of the glass, so the line is the dark inside showing through, and it can never lift. It imitates the Etch A Sketch, and that name is used nowhere in the app. "Line Drawing" is a working name, written once (`LineDrawing.title`), until one is settled.

**Hidden while it is built** (`unfinished: true`). Dave picked it on 2026-10-12 from research and mock-ups made that day, and it is going in a step at a time. In so far: six pictures drawn from shipped routes, a Picture menu, the clearing between pictures and its ghost, the darker gone-over line, and both appearances. Still to come: the Detail setting, its Settings preview and screenshot.

## Dave's decisions (2026-10-12)

- **The line is unbroken, with shading:** the picture's outlines, then its shading as hatching, the stylus going back along lines already drawn to get from place to place. He saw it beside a line that lifts and chose this.
- **The screen alone, edge to edge, for now;** a frame with dials later. The picture's rectangle is kept relative to the screen so a frame can take a smaller one.
- **Detail is to be a setting:** the toy's own line width, and a line half as wide. Not built yet.
- **A Speed slider,** in his words "in case a user wants to see it go faster".
- **The screen follows the system's appearance:** 152 of 255 in Light Mode, 104 in Dark Mode.
- **Nothing religious** among the pictures; classical myth is fine.

## How it works

- **A picture is a route**, not an image: the cells the stylus steps through, in order, on a grid of 1024 × 640 (one cell is one step; the line is 1.44 cells wide, about 1/700 of the screen's width, as measured on photos of the real toy). `docs/line-drawing/bake.py` makes a route from a picture; the app ships only routes (`Resources/line-<name>.route`, 48 KB for the Wave).
- **The route is stamped once** into a texture, off the main thread, as the scene is built (`LineRoute.stamp`, in the `LineRoute` module, which is built optimised even in debug). Each texel holds when it is first drawn, as a 24-bit share of the route's clock, and how much of it the finished line covers. Until the stamp lands the screen is bare, which is how a drawing starts anyway; then the picture so far fades up over 0.4 s.
- **One shader compares that time with a clock.** So a frame costs the same however much is drawn, and the CPU does nothing per frame but set the clock.
- **Every read of the texture is at a texel's centre.** SpriteKit smooths any texture a shader reads, whatever its filtering mode says, and a time smoothed between a drawn texel and a bare one is a moment when nothing happened: lines would arrive thin and ragged. With a texel to each pixel that is one read. Above the 14-inch size the texture has a texel to two pixels each way, and the shader reads the four round each pixel, compares each with the clock, and only then mixes them: a pixel softer, a quarter of the memory.
- **The clock is the wall's** (`LineDrawing.Cycle`). Which picture is on the screen, the one before it and the moment this one was begun are kept in the defaults (`linedrawing.drawing`, `linedrawing.before`, `linedrawing.began`) and shared by every copy of the scene, so a relaunch, Shuffle or a second display goes on from the same place, and a picture carries on while the wallpaper is covered or the Mac is asleep. Moving the Speed slider moves that moment, so the picture stays as far along as it was.
- **A picture is drawn, rests, clears, and the next begins.** It rests for five minutes at speed 1 (less when hurried, never under 20 s), then clears over 12 s whatever the speed: a soft fade, sooner in some places than others, as a shake lays the powder back unevenly. A ghost of its whole line stays (8% of the way to the dark inside) under the next picture, and goes when that one clears. The next picture is chosen as the clearing starts and stamped during it, so it begins on the frame the clearing ends.
- **A line drawn once is pale; gone over, it is dark.** A second texture holds when each texel is gone over again (16 bits), and the ghost in a spare channel. The first pass draws a line 62% of the way to the dark inside and the second the rest, so outlines the stylus travels along come out bolder, as on the toy.
- **The screen follows the system's appearance by itself** (`followsAppearance`): its two colours ease to the other mode's over two seconds, under the picture, with nothing rebuilt.
- **The powder** is a 512-texel tile of grain and soft mottle that repeats, a slow unevenness stretched over the whole screen, light from the upper left and a few bright specks.

## The route's file

Little-endian. `LRT1`; the grid's width and height in cells; the picture's rectangle on it (x, y, width, height); the start cell (x, y), all 16-bit; the number of steps (32-bit); the route's clock as a 32-bit float (cells of drawing, a step back along a line counting half); the length of what follows (32-bit). Then the runs, deflated (raw DEFLATE, which `NSData.decompressed(using: .zlib)` reads): one byte to a run of steps one way, bit 7 set while the stylus goes back along its own line, bits 6 to 4 the direction (east, south, west, north, then the four diagonals from south-east round), bits 3 to 0 the run's length less one.

The app eases each position by one step (a quarter of each neighbour), so corners round a little, and takes the clock along the eased line.

## Making a route

```sh
python3 docs/line-drawing/bake.py <folder of source pictures> Sources/Atrium/Resources wave
```

Needs numpy, scipy, Pillow and clang (for `route.c`, the one slow loop). The source pictures are not in the repo: `PICTURES` in `bake.py` gives each one's address and the file name it is looked for under. What it does:

1. **Darkness on the grid:** the picture, cropped, fitted to the grid with a margin, its paper tone taken as bare screen.
2. **Lines:** cells darker than their surroundings (the picture less a 2.5-cell blur of itself), thinned to one cell wide with Zhang and Suen's thinning (T. Y. Zhang and C. Y. Suen, "A fast parallel algorithm for thinning digital patterns", Communications of the ACM 27(3), 1984, https://doi.org/10.1145/357994.358023). Bold strokes are drawn first.
3. **Shading:** six layers switched on by darkness. Horizontal rows every 8 cells, then 4, then 2; vertical columns every 4, then 2; then solid. Neighbouring rows are joined at alternate ends, so the stylus zigzags as a hand does.
4. **One route:** the stylus walks to an undrawn neighbour, straight on first. Stuck, it takes the cheapest way to the nearest wanted cell: back along lines already drawn, or, where a piece of the picture stands alone, across bare screen (a stray mark, costed at twenty times a step back so it is the last resort). The whole picture's outlines come first, then each depth of shading over the whole picture, so a half-drawn picture is a whole composition and not a finished corner.

## The pictures

All landscape, bold, and not religious (Dave's rule). Each is shipped as its route only; the credits are also in `Resources/line-drawing-credits.tsv`, which Settings → About lists.

| Picture | Source | Licence | At speed 1 |
|---|---|---|---|
| The Great Wave: Hokusai, *Under the Wave off Kanagawa*, c. 1830–32 | The Met, 45434: https://www.metmuseum.org/art/collection/search/45434 | CC0 (The Met's Open Access; `isPublicDomain` true) | 114 min |
| The Rhinoceros: Dürer, 1515 | The Met, 356497: https://www.metmuseum.org/art/collection/search/356497 | CC0, as above | 120 min |
| A Flea: Hooke, *Micrographia*, Schem. XXXIV, 1665 | Wellcome Collection, L0084699: https://wellcomecollection.org/works/ajveb66y | **CC BY 4.0: must be credited** ("Wellcome Collection") | 105 min |
| Interlace: Bourgoin, *Les éléments de l'art arabe: le trait des entrelacs*, plate 96, 1879 (part) | Getty Research Institute, via the Internet Archive: https://archive.org/details/gri_33125012261786/page/n240 | Public domain (the Archive's record: not in copyright) | 32 min |
| Flying Machine: O. and W. Wright, US patent 821,393, Fig. 1, 1906 | US Patent and Trademark Office: https://patents.google.com/patent/US821393A | Public domain (patent drawings; the Office asks to be acknowledged) | 41 min |
| Mishima Pass: Hokusai, *Mishima Pass in Kai Province*, c. 1830–32 | The Met, 56346: https://www.metmuseum.org/art/collection/search/56346 | CC0, as above | 109 min |

The licence lines for the flea, the interlace and the patent were read at their sources by the rights research of 2026-10-12; The Met's for the three prints from its API (`isPublicDomain`) and its API page (https://metmuseum.github.io/: the dataset is under Creative Commons Zero).

What suits a single line, from nine pictures tried: one large subject or one bold pattern, its lines at least two line-widths apart, landscape. Patent drawings, geometric ornament, a natural-history plate of one specimen and bold woodcuts work. Fine tonal engraving, crowded charts and anything that depends on lettering do not: Dürer's *Melencolia I* came out a muddle, and his star chart a tangle.

## Settings

| Setting | Range | What it does | Default |
|---|---|---|---|
| Picture | Random, or one of the six | Random draws a different picture each time. Picking one clears the screen for it there and then, and it is drawn over and over | Random |
| Speed | 1× to 60× | how fast the stylus goes. At 1× it crosses a fortieth of the screen's width a second and a picture takes 32 to 120 minutes; at 60× the longest takes two | 1× |

Three more keys, with no page in Settings, set a scene up for the tests and for pictures of it; with any of them the scene keeps a cycle of its own and saves nothing: `linedrawing.drawn` (0 to 1) starts it that share of the way through its picture, `linedrawing.cleared` (0 to 1) that far through its clearing, and `linedrawing.ghost=1` lays the next picture's ghost under it.

```sh
SNAPSHOT_SCENE="Line Drawing" SNAPSHOT_DEFAULTS="linedrawing.drawn=0.4,linedrawing.picture=2" swift test --filter everySceneRenders
```

## Cost

Measured by the render test on a 14-inch screen at 2x (M3 Max, 2026-10-12): **0.5 to 0.65 ms of CPU and 0.22 to 0.29 ms of GPU a frame**, whatever the picture and however much of it is drawn, in both appearances and while clearing. Building: a route decodes in 2 ms and stamps in about 120 ms for 3024 × 1964, off the main thread; a scene built part-way through a picture stamps the one before as well, for its ghost. The two textures are 48 MB at that size, and a byte a texel more (6 MB) is kept for the next ghost.

At a 5K display's size the half-resolution path is drawn by a test but not timed in the app. A standalone copy of the shader, timed the same way before this was built, took 0.57 ms of GPU at 5K and 0.79 at 6K with 28 and 39 MB of textures.

## Checking it

- `lineRouteDecodesToItsKnownLength`: the Wave's route has the steps and the clock its bake printed, stays on its grid, and never lifts.
- `lineRouteStampsItsTextures`: the stamp covers a fifth of a 14-inch screen, its first row of bytes is the bottom of the screen (SpriteKit's order), and going over a line again is recorded. Prints the decode and stamp times.
- `lineDrawingLooksTheSameAtAnyFrameRate`: 15, 30 and 60 frames a second give the same picture to the pixel.
- `lineDrawingCycleFollowsTheClock`: drawing, resting, clearing and the next picture by the clock alone; the Speed slider leaves a picture as far along as it was; a picked picture follows at once; a day away comes back to a picture part-way through.
- `lineDrawingClearsToAGhost`: full, half cleared and a ghost hold less and less line; and the picture is drawn at a 5K display's size, through the four-read shader.
- `lineDrawingFollowsTheAppearance`: the screen's level goes from Light Mode's to Dark Mode's in two seconds.

## Shortcuts

- A texel takes the time of the pass that covers it most, and the finished line's cover. Where a later line overlaps an earlier one's edge by a sliver, that sliver shows with the earlier line (`ponytail:` in `LineRoute.stamp`).
- The stray marks that join separate pieces are part of every unbroken route: 536 cells of them on the Wave.
