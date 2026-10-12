# Line Drawing

An old print drawn slowly in one unbroken line on a screen of grey powder: the stylus scrapes the powder off the back of the glass, so the line is the dark inside showing through, and it can never lift. It imitates the Etch A Sketch, and that name is used nowhere in the app. "Line Drawing" is a working name, written once (`LineDrawing.title`), until one is settled.

**Hidden while it is built** (`unfinished: true`). Dave picked it on 2026-10-12 from research and mock-ups made that day, and it is going in a step at a time. This page so far covers step 1: one picture, drawn from a shipped route.

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
- **The clock is the wall's.** The moment the picture was begun is kept in the defaults (`linedrawing.began`) and shared by every copy of the scene, so a relaunch, Shuffle or a second display goes on from the same place, and a picture carries on while the wallpaper is covered or the Mac is asleep. Moving the Speed slider moves that moment, so the picture stays as far along as it was.
- **The powder** is a 512-texel tile of grain and soft mottle that repeats, a slow unevenness stretched over the whole screen, light from the upper left and a few bright specks. A line drawn once is pale (62% of the way to the dark inside).
- **When a picture is finished** it rests for a minute, fades out and begins again. Step 2 replaces this with the set of pictures and a soft clearing that leaves a ghost.

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

## Settings

| Setting | Range | What it does | Default |
|---|---|---|---|
| Speed | 1× to 60× | how fast the stylus goes. At 1× it crosses a fortieth of the screen's width a second and the Wave takes 114 minutes; at 60× it takes under two | 1× |

`linedrawing.drawn` (0 to 1, no page in Settings) starts a scene that share of the way through its picture, for the tests and for pictures of it: `SNAPSHOT_DEFAULTS="linedrawing.drawn=0.4"`. Nothing is saved while it is set.

## Cost

Measured by the render test on a 14-inch screen at 2x (M3 Max, 2026-10-12): **0.5 ms of CPU and 0.16 ms of GPU a frame**, the same at 10%, 40% and 100% drawn and in both appearances. Building: the route decodes in 2 ms and stamps in 120 ms for 3024 × 1964, off the main thread. The texture is 24 MB at that size.

Not measured in the app: a 5K or 6K display. A standalone copy of the shader, timed the same way before this was built, took 0.37 to 0.79 ms of GPU there.

## Checking it

- `lineRouteDecodesToItsKnownLength`: the Wave's route has the steps and the clock its bake printed, stays on its grid, and never lifts.
- `lineRouteStampsItsTextures`: the stamp covers a fifth of a 14-inch screen, its first row of bytes is the bottom of the screen (SpriteKit's order), and going over a line again is recorded. Prints the decode and stamp times.
- `lineDrawingLooksTheSameAtAnyFrameRate`: 15, 30 and 60 frames a second give the same picture to the pixel.

```sh
SNAPSHOT_SCENE="Line Drawing" SNAPSHOT_DEFAULTS="linedrawing.drawn=0.4" swift test --filter everySceneRenders
```

## Shortcuts

- A texel takes the time of the pass that covers it most, and the finished line's cover. Where a later line overlaps an earlier one's edge by a sliver, that sliver shows with the earlier line (`ponytail:` in `LineRoute.stamp`).
- The stray marks that join separate pieces are part of every unbroken route: 536 cells of them on the Wave.
