# Murmuration

A starling murmuration at sunset: thousands of tiny dark birds swirling as one shape-shifting cloud over a low treeline and reeds, thickening and thinning as the flock folds in depth. An unseen falcon dives through every 26 seconds and the flock bursts apart around it.

- **Files:**
  - `Sources/Atrium/Murmuration.swift`: the `Murmuration` scene
  - `Fireflies.swift`: the shared helpers it uses (`backdrop`, `treeline`, `grassFringe`, `radialGlow`, `frameTime`, `rgb`)
- **Entry:** `@MainActor func murmuration(size:)`, which returns `final class Murmuration: SKScene`. Registry entry: icon `bird.fill`, tint `.brown`.
- **Kind:** SpriteKit sprites, with a 3D boids simulation on the CPU every frame.

## How it works
1. **Backdrop.**
   - A sunset gradient from peach at the horizon, through coral and mauve, to dusky blue.
   - The sun is an additive radial glow 0.9 × the screen height across, at (0.7 w, 0.1 h).
   - Seven streaks of cloud tinted peach-pink.
   - A treeline at 8% of the height (half resolution) and a reed fringe (7%).
2. **Flock size.** `Int(w × h / 1100)` birds, 1,350 at 1512×982. They start in an ellipse around (0.45 w, 0.62 h) at z ±150, flying right at 90–130 pt/s.
3. **Drawing.**
   - `ponytail:` each simulated bird is one 12 pt sprite of four dots (`cluster`), so about 1,300 boids read as about 5,000 starlings.
   - Each sprite has a random rotation and alpha 0.85.
   - Perspective: scale `s = focal / (focal − z)` with focal 1300, and the position is projected toward the screen centre. Nearer birds are bigger and spread outward, so folds look darker and denser.
   - All sprites share one texture, so they batch into one draw.
4. **Neighbours (`simulate(dt)`).**
   - Birds are bucketed into a 3D grid of 40 pt cells (`neighbourRadius`) with a counting sort (`cellStart` and `cellItems`) over the 3×3×3 cells around each bird.
   - Each bird looks at no more than 10 neighbours (real starlings track about seven), so cost is linear in flock size.
   - The loops use unsafe buffers to avoid array bounds checks.
5. **Forces.**
   - separation within 20 pt: `900 × (1 − d/20) / d`
   - alignment ×2.4
   - cohesion at 0.4 ± 0.2, breathing over about 126 s
   - a constant-strength pull (45) toward a roaming target that wanders ±26% of the width and ±10% of the height, so the flock turns without collapsing to a point
   - z pulled back toward 0 (×0.35)
   - soft walls at 30–82% of the height and 12–88% of the width (×4)
   - speed clamped to 90–170 pt/s
6. **The falcon.**
   - It crosses for 5 s in every 26 s cycle (19–24 s), through where the target was, at an angle that steps by 0.9 rad each cycle.
   - Birds within 130 pt flee (`1100 × (1 − d/130) / d`).
   - The falcon is never drawn; you only see the flock tear open.

## Time and appearance
- Driven by `frameTime` deltas in `update(_:)`.
- The target, cohesion and falcon run on scene time.
- It's always sunset, with no Light Mode look, and the flock starts differently on each load.

## Settings
None yet. Suggested:

| Key | Label | Range | Default | Notes |
|---|---|---|---|---|
| `murmuration.flock` | Flock size | 0.3–1.5 | 1 | multiplies the `w × h / 1100` count; rebuild on change; CPU scales linearly |
| `murmuration.falcon` | Falcon | switch | 1 | turns the dives off |
| `murmuration.speed` | Speed | 0.5–1.5 | 1 | scales `dt` |

A `murmuration.palette` of skies could offer Sunset (today's), Winter Afternoon (pale gold) and Dusk (blue).

## Tuning constants
- Grid and physics: `neighbourRadius` 40, `personalSpace` 20, `depth` 400, `focal` 1300, neighbour cap 10.
- Forces: alignment 2.4, cohesion 0.4 ± 0.2, target pull 45, walls ×4, speed 90–170.
- Falcon: every 26 s for 5 s, radius 130, strength 1100.
- Density: 1 bird per 1100 pt².

## Performance
- Measured at CPU 1.09 ms and GPU 0.24 ms per frame (release build, 2x). It has the highest CPU cost of any scene.
- In debug it's 16–19 ms (bounds-checked Swift), so always measure CPU with `swift test -c release -Xswiftc -enable-testing`.
- The count scales with screen area: a 2560×1440 point display gets about 3,350 birds, estimated at about 2.7 ms, which is over budget. Each display runs its own flock.
- `var fill = Array(start)` allocates about 23k Int32 (about 90 KB) every frame; a reusable buffer would remove that.

## Gotchas and shortcuts
- `ponytail:` four-dot clusters stand in for more boids. The pattern is fixed, so it can look repetitive at the thin edges of the flock (noted by the nature agent).
- The flock isn't seeded, so no two loads match and snapshots aren't reproducible.
- The walls are soft. With perspective, near birds can still drift past the screen edge.

## Dave's feedback and decisions
- Built in the first batch.
- When it was deployed, Dave was told it's the most expensive scene and asked to report if his fans spun up or the Mac got warm. He never reported a problem.
- It hasn't had a fidelity pass.

## Ideas / next steps
- **Cap for big screens:** limit the bird count by CPU budget rather than area, or run the simulation at 15 Hz and interpolate.
- **Bird variety:** vary the cluster patterns or animate wingbeats, to break up repetition.
- **Flock behaviour:** let the flock split into two and merge back; a visible falcon silhouette as an option.
- **Real sunset:** follow the real sunset time and colour, a golden-hour sky that deepens to dusk. Birds roost at dark, so the flock could settle into the reeds.

## Checking it
`SNAPSHOT_SCENE="Murmuration" SNAPSHOT_SECONDS=40 SNAPSHOT_DIR=/tmp/mur swift test`. The simulation runs in `update(_:)`, so `SNAPSHOT_SECONDS` advances it; check 5, 40 and 120 s to make sure the flock stays on screen and doesn't collapse. Use a release build for timing.
