# Campfire

A campfire in a forest clearing at night: flickering flames over a teepee of logs and glowing coals inside a stone ring, embers floating up, faint smoke, a fallen log to sit on, and a warm light on the ground under a starry sky framed by tall pines.

- **Files:**
  - `Sources/Atrium/Campfire.swift`: the `Campfire` scene
  - `Fireflies.swift`: the shared helpers it uses (`backdrop`, `treeline`, `verticalGradient`, `radialGlow`, `softDot`, `pine`, `frameTime`, `rgb`)
- **Entry:** `@MainActor func campfire(size:)`, which returns `final class Campfire: SKScene`. Registry entry: icon `flame.fill`, tint `.red`.
- **Kind:** SpriteKit. Painted Core Graphics props plus four `SKEmitterNode`s; the flicker is set in `update(_:)`.

## How it works
The fire sits at (0.5 w, 0.2 h). Draw order by zPosition:
1. **Sky (z 0–1).** A night gradient, and `width / 6` stars (252) above 42% of the height. Every ninth star twinkles with a fade `SKAction`.
2. **Woods (z 2–2.5).** A pine-heavy treeline at 40% of the height (80% pines, half resolution), and a ground gradient over the bottom 42%.
3. **Framing pines (z 3).** Two painted textures, each 28% of the width: three big pines on the left and three on the right (at 0.72 w), 50–86% of the height.
4. **Ground light (z 4).** An additive radial glow, 0.95 w × 0.5 h, centred on the fire.
5. **Stone ring.** Fourteen stones on a 200 × 44 pt ellipse, split in two so the flames sit between the halves:
   - back half at z 5, lit on its lower face (it faces the fire)
   - front half at z 8, lit only on its top edge
6. **Logs (z 6).** A 220 × 150 pt texture: four 22 pt logs leaning into a teepee, each with an orange stroke on the side facing the flames, over a squashed radial gradient of coals.
7. **Flames (z 7).** Two additive emitters sharing a teardrop texture (32 × 64 painted, particles 40 × 80):

   | | Body | Core |
   |---|---|---|
   | Birth rate | 130/s | 55/s |
   | Lifetime | 0.95 s | 0.55 s |
   | Spread | 76 pt | 36 pt |
   | Speed | 140 | 95 |
   | Scale | 1 | 0.6 |
   | Colour | yellow → orange → red → dark | cream → gold → orange |

   Both use yAcceleration 110 and scale speed −0.85, and are pre-run 2 s with `advanceSimulationTime`.
8. **Bench (z 9).** A fallen log at (0.27 w, 0.12 h), 300 × 50 pt, with a cut end showing growth rings.
9. **Embers (z 10).** 7/s, each living 4 ± 2 s, rising at 110 ± 50 with slight gravity. A `particleAction` sways them ±14 pt; additive, pre-run 6 s.
10. **Smoke (z 11).** 5/s, each living 9 s, starting 110 pt above the fire. It grows (+0.45/s) with peak alpha only 0.09; pre-run 9 s.
11. **Halo (z 12).** An additive 520 pt glow, 70 pt above the fire.

**Flicker (`update`).** `f = 0.86 + 0.07 sin 7.3t + 0.05 sin(12.9t + 1) + 0.03 sin(23.1t + 2)`. Three unrelated frequencies, so it never visibly loops. `f` drives the ground-light alpha and xScale and the halo alpha. The flames' xAcceleration sways with `35 sin 1.7t + 20 sin(4.3t + 2)`, so the fire leans and dances.

## Time and appearance
Driven by `frameTime` in `update(_:)` plus the emitters' own time. It's always night, with no Light Mode look. Trees, stars and stone sizes are random on each load.

## Settings
None yet. Suggested; emitter properties can all be changed live:

| Key | Label | Range | Default | Drives |
|---|---|---|---|---|
| `campfire.fire` | Fire size | 0.5–1.5 | 1 | flame birth rate and scale |
| `campfire.embers` | Embers | 0–2 | 1 | ember birth rate |
| `campfire.smoke` | Smoke | switch | 1 | hides the smoke emitter |
| `campfire.flicker` | Flicker | 0–1 | 1 | the sine amplitudes in `flicker()` |

## Tuning constants
- Fire position (0.5 w, 0.2 h), the emitter numbers above, the flicker terms, the halo (520 pt), and the ground light (0.95 w × 0.5 h).

## Performance
Measured at CPU 0.45 ms and GPU 0.28 ms per frame (release build, 2x). Cost is emitter updates (about 150 live flame particles) and additive overdraw. There's comfortable headroom.

## Gotchas and shortcuts
- **Fixed sizes:** props are fixed point sizes (ring 260 × 80, logs 220 × 150, halo 520, bench 300 × 50). They don't scale with the screen, so on a large display the fire looks small in the frame.
- **Static firelight:** the firelight is additive glow sprites only. The framing pines and woods are static textures and don't flicker with the fire.
- **Stone layering:** the two stone halves are what place the flames between them. Keep both z values (5 and 8) either side of the flames (7).

## Dave's feedback and decisions
- Built by the nature agent in the first batch.
- No specific feedback yet, and no fidelity pass.

## Ideas / next steps
- **Scale:** size the props to the screen.
- **Livelier fire:**
  - occasional bursts of sparks and a crackle flare
  - logs slowly burning down over hours
  - firelight flickering on the nearest tree trunks and the bench
- **Sky:** a Moon (real phase, from `Sky.moonPhase`), and real stars reused from Live Sky's catalogue.

## Checking it
`SNAPSHOT_SCENE="Campfire" SNAPSHOT_SECONDS=10 SNAPSHOT_DIR=/tmp/fire swift test`. Emitters and flicker advance with `SNAPSHOT_SECONDS`. The flames are random each frame, so compare shape and colour rather than exact pixels.
