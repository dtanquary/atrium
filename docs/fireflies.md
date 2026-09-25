# Fireflies

A forest at dusk: four treelines receding into violet fog under a fading pink-to-indigo sky with a few stars. About a hundred fireflies drift slowly in the gaps between the nearer treelines, flashing softly on their own rhythms.

- **Files:** `Sources/Wallpaper/Fireflies.swift`.
  - The `Fireflies` scene.
  - **The helpers shared by all five nature scenes**, below `// MARK: - Shared by the nature scenes`:
    - `frameTime(_:_:)`: the clamped frame delta
    - `rgb` and `mixRGB`
    - `verticalGradient(_:)`
    - `backdrop(_:_:)`: a dithered sky sprite
    - `radialGlow(diameter:stops:)` and `softDot()`
    - `treeline(width:base:hills:trees:spacing:color:pineChance:clearing:resolution:)`
    - `pine`, `broadleaf` and `grassFringe`

  Changes to these helpers affect Campfire and Murmuration too.
- **Entry:** `@MainActor func fireflies(size:)`, which returns `final class Fireflies: SKScene`. Registry entry: icon `sparkle`, tint `.yellow`.
- **Kind:** SpriteKit sprites. Everything static is painted once with Core Graphics; the fireflies are sprites moved in `update(_:)`.

## How it works
1. **Sky.** `backdrop` with stops from pink-mauve (0.25), through violet (0.5) and deep indigo (0.8), to near-black (1). The dither shader stops dark skies from banding. There are 40 `softDot` stars above 60% of the height.
2. **Four treelines,** far to near, from the `layers` table:

   | Layer | Base (× height) | Tree heights (× height) | Spacing (pt) | Pines | Clearing | Resolution |
   |---|---|---|---|---|---|---|
   | 0 | 0.34 | 0.10–0.20 | 12–26 | 70% | none | half |
   | 1 | 0.27 | 0.16–0.30 | 20–42 | 60% | none | half |
   | 2 | 0.17 | 0.26–0.46 | 45–90 | 60% | 42–55% of width | full |
   | 3 | 0.05 | 0.50–0.85 | 150–300 | 100% | 30–68% of width | full |

   - Colour steps from the fog colour toward near-black (shade 0.25 → 0.97), so distance reads as haze.
   - Each treeline sprite has zPosition `i × 10`.
   - A mist gradient (the fog colour at alpha 0.55 fading to 0, 16% of the height tall) sits at the foot of the next layer back (`i × 10 + 5`), so fog pools between rows.
   - The two back layers are painted at half resolution, which softens them and saves memory.
3. **Grass.** A fringe of grass blades along the bottom, 9% of the height, at z 45.
4. **Fireflies.** `Int(width / 14)` of them, 108 at 1512 pt.
   - Each gets a depth (layer 1, 2 or 3, weighted toward the front) that sets its scale (0.35/0.55/0.8/1.2 of a 64 pt glow) and its z, just in front of that treeline (`depth × 10 + 6`).
   - Its home is 20 pt to 0.3 of the height above that treeline's base.
   - The texture is `fireflyGlow()`, a radial glow from white-yellow at the core to transparent lime, drawn with additive blending.
5. **Motion (`place()`, every frame).**
   - **Drift:** a Lissajous path around home. x uses two sines of 60 and 25 pt amplitude; y uses 30 and 12 pt. Speeds are 0.05–0.25 rad/s, with random phases.
   - **Blink:** each has a 2.5–7 s period and a random offset. It flashes for 0.9 s shaped by `sin²` and sits at alpha 0.08 the rest of the time.

## Time and appearance
Time is accumulated from `frameTime` in `update(_:)`, so it pauses with the view and never jumps after a sleep. It's always dusk, with no Light Mode look and no link to the real time. The layout (trees, homes, rhythms) is random on each load.

## Settings
None yet. Suggested:

| Key | Label | Range | Default | Notes |
|---|---|---|---|---|
| `fireflies.count` | Fireflies | 0.3–2 | 1 | multiplier; set at load, so rebuild on change (like a palette pick) |
| `fireflies.blink` | Blink rate | 0.5–2 | 1 | divides `period`; live |
| `fireflies.fog` | Fog | 0–1 | 0.55 | mist alpha |
| `fireflies.sync` | Synchronous flashing | switch | 0 | see Ideas |

A `fireflies.palette` could offer Dusk (today's violet), Moonlit (cool blue fog) and Summer Evening (warm amber).

## Tuning constants
- Layer table as above; firefly density `w / 14`; the depth weights; drift amplitudes 60/25 and 30/12 pt; blink 0.9 s in a 2.5–7 s period; idle alpha 0.08.

## Performance
Measured at CPU 0.49 ms and GPU 0.41 ms per frame (release build, 2x). CPU is mostly placing 108 sprites every frame; GPU is additive overdraw from the glows and the full-screen treeline textures. There's plenty of headroom.

## Gotchas and shortcuts
- `broadleaf` builds its canopy from about 40 small ellipses, which show as circles at large sizes. That's why the front layer is 100% pines. Improve `broadleaf` before using it big.
- The treelines are full-screen-width textures painted at 2x. The front layers are large in memory, while the back two are half resolution.
- Stars don't twinkle here (Campfire's do).

## Dave's feedback and decisions
- Built by the nature agent in the "build out all of those ideas" batch, then deployed without specific feedback.
- It hasn't had a fidelity pass.
- General direction applies: calm motion, and colours in the Flowing Gradient family.

## Ideas / next steps
- **Synchronous flashing,** like the real synchronous fireflies (*Photinus carolinus*) of the Great Smoky Mountains: waves of flashes sweeping through the swarm, with dark pauses between.
- **Follow the real day:** fireflies only come out after sunset. By day it could be a sunlit forest, or a Light Mode look.
- **Moonrise,** or reflections in a pond in the clearing.
- **Better leafy trees,** so the foreground isn't all pines.

## Checking it
`SNAPSHOT_SCENE="Fireflies" SNAPSHOT_SECONDS=20 SNAPSHOT_DIR=/tmp/ff swift test`. Motion runs through `update(_:)`, so `SNAPSHOT_SECONDS` advances drift and blinking. Only the frames that happen to catch a flash show bright fireflies.
