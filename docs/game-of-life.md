# Game of Life

Conway's Game of Life on a board that wraps at the edges. When the board stalls, fresh patches of random cells are dropped in, so it never dies out. It has two looks, switched by Settings → Calm:

- **Calm** (the default): 1.5 generations a second, shown as a long exposure. Each cell glows by its average over the last 3 seconds, melted into soft liquid blobs in one family of jewel blues. Still lifes and blinkers hold a steady glow, and only real movement shows, as slow drifts.
- **Classic:** the first look. 7 generations a second, crisp rounded cells in pastel colours that drift across the screen. Births bloom in and deaths leave a fading trail.

- **Files:** `Sources/Atrium/GameOfLife.swift` holds the `GameOfLife` scene and its `cellShader`. `frameTime` comes from Fireflies.swift.
- **Entry:** `@MainActor func gameOfLife(size:)`, which returns `final class GameOfLife: SKScene`. Registry entry: icon `square.grid.3x3.fill`, tint `.orange`.
- **Kind:** a simulation on the CPU, feeding an `SKMutableTexture` with one texel per cell and nearest filtering. A shader on one full-screen sprite draws the cell shapes and colour.

## How it works
1. **Board** (both looks).
   - `cellSize` is 9 pt, which gives 168 × 110 cells at 1512×982 (rounded up; the board is centred and may overhang slightly).
   - It starts 28% alive.
   - `cells` and `next` are `[UInt8]` buffers that are swapped each generation.
2. **Step (`step()`).**
   - One generation every 1/`life.speed` s in Calm (1.5 a second), or every `classicInterval` of 0.14 s in Classic (about 7 a second), counted from `frameTime`.
   - Standard B3/S23 rules with wrap-around neighbours, run in unsafe buffers.
   - It counts how many cells changed.
3. **Stall detection.**
   - `ponytail:` "quiet" means fewer than 0.3% of cells changed for 12 generations in a row.
   - This catches boards of still lifes and blinkers, which a detector looking for repeating states would miss.
   - When quiet, `seed()` drops three round patches of random cells (radius 9 cells, 40% alive) at random spots.
4. **Classic glow (`upload()`, every frame).**
   - Each cell's glow sits in the red channel of an RGBA pixel buffer.
   - Alive cells ease toward 255 (`g += (255 − g) × 90/256`); dead cells decay (`g −= g × 16/256`) until they drop to 20 or below, then snap to 0.
   - The buffer is copied into the texture with `modifyPixelData`.
5. **Calm exposure (`expose()`, every frame).**
   - `exposed` holds each cell's average state as a Float, eased toward 0 or 1 by `1 − exp(−dt / exposure)`, so it's the same at any frame rate. 8 bits would stall: at 60 fps a 3 s exposure moves under one level a frame.
   - Red gets the average; green gets a 3×3 blur of it (weights 1, 2, 1 ÷ 8, wrapping at the edges).
   - Why it's calm: a blinker's arms are alive half the time, so they settle at half glow with a small, slow ripple instead of flashing 3.5 times a second. A glider slides about 3 pt a second, trailing a comet tail. A reseed fades in over a few seconds as a soft cloud instead of popping in as a blob.
6. **Shader (`cellShader`).** `u_calm` picks the look; the texture filters linearly, so Classic's reads at cell centres are exact.
   - Classic samples the glow at each cell's centre, so cells stay crisp.
   - Draws a rounded square (inset 0.2, radius 0.16) with a soft halo (0.18).
   - Colour comes from a cosine palette over x, y and `u_now × 0.01`, a full hue cycle every 100 s, mixed 35% toward white for pastels.
   - Glow is shaped by `pow(glow, 1.4)`, over a dark navy background with a vignette.
   - Calm reads the blurred average through a cubic B-spline in four linear taps (GPU Gems 2, ch. 20). A smoothstep between cells left a visible grid of flat spots.
   - It thresholds that into blobs with soft edges (`smoothstep(0.16, 0.3)`), brighter in fuller cores, plus a faint halo. With softness at 0 it draws Classic's rounded cells by the average instead.
   - Colour mixes sapphire, teal and amethyst by two slow sines over position and `u_now`, lifted toward ice blue in the brightest cores, at 72% brightness.

## Time and appearance
- The simulation runs on `frameTime`.
- The hue drift runs on `u_now`, so it advances with `SNAPSHOT_SECONDS`.
- It's always dark, with no Light Mode look. Each load starts from a random board.

## Settings
All live, read each frame; nothing rebuilds. The last three only show while Calm is on.

| Key | Label | Range | Default | Notes |
|---|---|---|---|---|
| `life.calm` | Calm | switch | on | off is the Classic look, unchanged |
| `life.speed` | Generations a second | 0.5–4 | 1.5 | |
| `life.exposure` | Exposure (seconds) | 0–6 | 3 | the averaging time; 0 shows the live board |
| `life.softness` | Softness | 0–1 | 1 | 0 is rounded cells, 1 is liquid blobs |

Still to come: a cell size (it resizes the board, so it needs a rebuild), and palettes (Flowing Gradient's jewel families would fit) with a Light Mode look.

## Tuning constants
- `cellSize` 9, `classicInterval` 0.14, initial density 0.28.
- Stall rule: 0.3% for 12 generations. Reseed: 3 patches, radius 9, density 0.4.
- Easing: births 90/256 and deaths 16/256 every 30th of a second (scaled by the frame time), floor 20.
- Shader: inset 0.2, radius 0.16, halo 0.18, hue speed 0.01, pastel mix 0.35.
- Calm: blob edge 0.16–0.3, core 0.3–0.6, halo 0.12, ice-blue lift 0.4 over 0.4–0.8, brightness 0.72, colour sines at 0.012 and 0.0096 rad/s.

## Performance
Calm measured at CPU 0.55 ms and GPU 0.36 ms per frame (release build, 2x, 2026-09-26); the exposure and blur cost about as much as Classic's integer easing. Classic measured at CPU 0.47 ms and GPU 0.52 ms. CPU cost is the per-frame glow easing over about 18.5k cells, plus copying the 74 KB buffer (`let bytes = pixels` makes a copy every frame), plus a generation step 7 times a second. In debug it measured about 2.6 ms of CPU. There's comfortable headroom in release.

## Gotchas and shortcuts
- **Whole-number glow:** a dying cell loses at least 1 of its 255 each frame, otherwise the smaller steps at 60 fps round to 0 and leave cells glowing forever.
- **Blobby reseeds:** reseeded patches arrive as visible round blobs (flagged by the nature agent).
- **Rebuild on resize:** `cols` and `rows` are fixed at load, so changing the cell size means rebuilding the scene.

## Dave's feedback and decisions
- Built by the nature agent in the first batch.
- 2026-09-26: "cool but so crazy on the eyes, its so busy and wild." The cause: 7 generations a second with births at full brightness in about 0.1 s, so blinkers all over the screen flash at 3.5 Hz and pull the eye. Calm was built as a switch to compare with Classic. Over 4 s of frames at 15 fps, Classic changes 1.41 grey levels per pixel per frame on average, with 2% of pixels jumping more than 20 levels. Calm changes 0.22, with none jumping.
- 2026-09-26, after comparing them live: "keep both as a choice I guess, but default to calm for game of life." The Calm switch stays, on by default.
- At the same time he asked for reaction–diffusion, which became its own wallpaper.

## Ideas / next steps
- **Better reseeds:** drop known patterns (gliders, lightweight spaceships, an R-pentomino, the occasional glider gun) instead of round blobs, so new life arrives with character.
- **Looks:** a Light Mode look and palettes.
- **Variation:** vary the rules between loads (HighLife B36/S23, Day & Night) for different textures.

## Checking it
`SNAPSHOT_SCENE="Game of Life" SNAPSHOT_SECONDS=30 SNAPSHOT_DIR=/tmp/life swift test`, with `SNAPSHOT_DEFAULTS="life.calm=0"` for Classic. To measure busyness, add `SNAPSHOT_MOVIE=4` and compare consecutive frames. The simulation and glow advance with `SNAPSHOT_SECONDS`; the hue drift doesn't. Check around 30 s and 120 s to see that stall reseeding keeps the board alive.
