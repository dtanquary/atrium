# Game of Life

Conway's Game of Life on a board that wraps at the edges, drawn as soft rounded cells glowing in pastel colours that drift across the screen and slowly shift. Births bloom in, deaths leave a fading trail, and when the board stalls, fresh patches of random cells are dropped in, so it never dies out.

- **Files:** `Sources/Atrium/GameOfLife.swift` holds the `GameOfLife` scene and its `cellShader`. `frameTime` comes from Fireflies.swift.
- **Entry:** `@MainActor func gameOfLife(size:)`, which returns `final class GameOfLife: SKScene`. Registry entry: icon `square.grid.3x3.fill`, tint `.orange`.
- **Kind:** a simulation on the CPU, feeding an `SKMutableTexture` with one texel per cell and nearest filtering. A shader on one full-screen sprite draws the cell shapes and colour.

## How it works
1. **Board.**
   - `cellSize` is 9 pt, which gives 168 × 110 cells at 1512×982 (rounded up; the board is centred and may overhang slightly).
   - It starts 28% alive.
   - `cells` and `next` are `[UInt8]` buffers that are swapped each generation.
2. **Step (`step()`).**
   - One generation every `stepInterval` of 0.14 s (about 7 per second), counted from `frameTime`.
   - Standard B3/S23 rules with wrap-around neighbours, run in unsafe buffers.
   - It counts how many cells changed.
3. **Stall detection.**
   - `ponytail:` "quiet" means fewer than 0.3% of cells changed for 12 generations in a row.
   - This catches boards of still lifes and blinkers, which a detector looking for repeating states would miss.
   - When quiet, `seed()` drops three round patches of random cells (radius 9 cells, 40% alive) at random spots.
4. **Glow (`upload()`, every frame).**
   - Each cell's glow sits in the red channel of an RGBA pixel buffer.
   - Alive cells ease toward 255 (`g += (255 − g) × 90/256`); dead cells decay (`g −= g × 16/256`) until they drop to 20 or below, then snap to 0.
   - The buffer is copied into the texture with `modifyPixelData`.
5. **Shader (`cellShader`).**
   - Samples the glow at each cell's centre, so cells stay crisp.
   - Draws a rounded square (inset 0.2, radius 0.16) with a soft halo (0.18).
   - Colour comes from a cosine palette over x, y and `u_time × 0.01`, a full hue cycle every 100 s, mixed 35% toward white for pastels.
   - Glow is shaped by `pow(glow, 1.4)`, over a dark navy background with a vignette.

## Time and appearance
- The simulation runs on `frameTime`.
- The hue drift runs on `u_time`, so it doesn't advance in the render harness.
- It's always dark, with no Light Mode look. Each load starts from a random board.

## Settings
None yet. Suggested:

| Key | Label | Range | Default | Notes |
|---|---|---|---|---|
| `life.speed` | Generations per second | 2–20 | 7 | `stepInterval = 1 / value`; live |
| `life.cellSize` | Cell size | 5–16 pt | 9 | resizes the board, so rebuild on change |
| `life.trails` | Trails | 0–1 | 0.5 | scales the death decay (today 16/256 per frame) |

A `life.palette` could offer Drift (today's rainbow), Mono (one hue), Warm and Cool, plus a Light Mode look with dark cells on paper, like Flowing Gradient's.

## Tuning constants
- `cellSize` 9, `stepInterval` 0.14, initial density 0.28.
- Stall rule: 0.3% for 12 generations. Reseed: 3 patches, radius 9, density 0.4.
- Easing: births 90/256 per frame, deaths 16/256 per frame, floor 20.
- Shader: inset 0.2, radius 0.16, halo 0.18, hue speed 0.01, pastel mix 0.35.

## Performance
Measured at CPU 0.47 ms and GPU 0.52 ms per frame (release build, 2x). CPU cost is the per-frame glow easing over about 18.5k cells, plus copying the 74 KB buffer (`let bytes = pixels` makes a copy every frame), plus a generation step 7 times a second. In debug it measured about 2.6 ms of CPU. There's comfortable headroom in release.

## Gotchas and shortcuts
- **Frame-rate-dependent easing:** glow is eased per frame, not per second. At 15 fps on battery, trails last twice as long in real time (about 1.3 s at 30 fps, about 2.6 s at 15 fps). Scale the easing by `dt` if that matters.
- **Blobby reseeds:** reseeded patches arrive as visible round blobs (flagged by the nature agent).
- **Rebuild on resize:** `cols` and `rows` are fixed at load, so changing the cell size means rebuilding the scene.

## Dave's feedback and decisions
- Built by the nature agent in the first batch.
- No specific feedback yet, and no fidelity pass.

## Ideas / next steps
- **Better reseeds:** drop known patterns (gliders, lightweight spaceships, an R-pentomino, the occasional glider gun) instead of round blobs, so new life arrives with character.
- **Looks:** a Light Mode look and palettes.
- **Variation:** vary the rules between loads (HighLife B36/S23, Day & Night) for different textures.

## Checking it
`SNAPSHOT_SCENE="Game of Life" SNAPSHOT_SECONDS=30 SNAPSHOT_DIR=/tmp/life swift test`. The simulation and glow advance with `SNAPSHOT_SECONDS`; the hue drift doesn't. Check around 30 s and 120 s to see that stall reseeding keeps the board alive.
