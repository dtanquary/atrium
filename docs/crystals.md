# Crystals

Vitamin C crystallising on a microscope slide between polarisers. Spherulites nucleate in the dark liquid, grow outward as round crystals and fans of radiating fibres, each with the dark Maltese cross that polarised light gives them, and meet along boundaries. The slide holds, melts back to the dark liquid and crystallises again in a new pattern, about every 7 minutes. Colours come from physics, not a palette: the interference colour of light through a birefringent crystal.

- **Files:** `Sources/Atrium/Crystals.swift` holds the `Crystals` scene, its `bake`, the `michelLevy` chart and the shader. `SplitMix` comes from Aurora.swift, `frameTime` from Fireflies.swift. `Tests/AtriumTests/CrystalsTests.swift` checks the chart and a bake.
- **Entry:** `@MainActor func crystals(size:)`, which returns `final class Crystals: SKScene`. Registry entry: icon `hexagon.fill`, tint `.yellow`.
- **Kind:** each cycle's crystals are baked into textures in Swift; one full-screen shader reveals them over time and colours them.

## How it works
1. **Bake** (`bake`, once a cycle): nuclei, and from them the time the growth front reaches every point. Texels are 2 pt.
   - **Nucleation, Johnson–Mehl style.** About 20 candidate nuclei at the standard size (the screen plus a 15% margin, at one per `spacing²` with `spacing` = 0.36 × screen height × Crystal size), two-thirds in the open liquid: half of those at once, the rest tailing off exponentially (τ 0.19 of the growth time, up to 0.42), and on half the slides one "hero" 0.12 early. The remaining third form on the rims of crystals already growing (VANOX's "necklace of beads") and grow outward as fans. A nucleus that lands on crystal already there is dropped.
   - **Growth.** Each front moves at a steady speed (±15% per crystal) until it meets another or runs out of material. Speed varies around the circle: 6–14 gentle lobes (±4–8%), up to 35% stretch along an axis, and a one-sided fan for rim nuclei. Arrival time is `born + distance / speed(angle)`; the first to arrive owns the texel. Equal-age neighbours meet on straight lines, younger ones on curves, as real ones do.
   - **Pools of liquid.** On 75% of slides each crystal can only grow for 0.45–0.8 of the growth time (±2.5% around its rim, in 5–12 gentle scallops), so they stop short and leave dark liquid between them, as in most micrographs.
   - **Thickness.** Each crystal's retardation is drawn from the slide's tint range: first-order grey-white (120–280 nm, 1 in 5 slides), straw and gold (280–450, 3 in 5), or the second order's violet, blue and sky (480–720, 1 in 5). One tint dominates each slide, as in real ones. It's modulated by a slowly varying film (±10%), a radial trend (open nuclei thicker at the centre, rim fans paler at the root) and a 30% thicker rim.
   - **Bands** on 25% of slides: soft dark concentric growth bands (15–30% darker), 6–12% of `spacing` apart, wandering ±8% around the circle and closer together further out.
   - **Stored** in three RGBA8 `SKMutableTexture`s. SpriteKit's mutable textures only take bytes (half and float formats come out as garbage), so values that need precision are split over two channels as `hi + lo/255`; linear filtering is linear per channel, so the shader's sum is the filtered value at 16-bit precision.
     - `growth`: arrival time (0–1 of the growth, ×0.95) and retardation (as a coordinate into the chart).
     - `nucleus`: the owning crystal's nucleus, x and y. Sampled with nearest filtering: blending two crystals' nuclei at a boundary gives a meaningless one.
     - `marks`: distance to the boundary with another crystal (0–8 pt), the band shade, and the signed distance to the rim where a crystal stopped (±8 pt). A boundary is where the next front ties with this one (the gap between their arrival times over how fast it widens across it), where this crystal stops and a neighbour that reaches further carries on, or where a crystal that would have got here first stopped short. Liquid texels take the crystal whose rim is nearest, so every field runs smoothly across the rim and the rim is where that distance crosses 0: smooth edges at any texel size.
2. **Shader**, per pixel:
   - **Reveal:** crystal where `u_grow` has passed its arrival time, the rim distance is positive and the melt hasn't reached it.
   - **Extinction:** the fibres point straight out from the nucleus, so the crystal's optic axes are radial and tangential. Brightness goes as sin²(2θ) of that angle against the polarisers, giving the dark cross along the polarisers on every crystal, whatever its shape. Fibres splay, so the cross is crisp at the centre (90% contrast) and fills in toward the rim (50%), as measured on the references (the arms bottom out at 20–33% of the peak).
   - **Colour:** the chart at the pixel's retardation × Thickness. It starts at 55% behind the front and thickens to full over 12% of the growth (about 25 s), as the film deposits behind a real front, so every growing crystal has a pale grey-white edge.
   - **Fibres:** silky streaks: value noise around the nucleus (wrapping, so there's no seam) by radius × 0.12, with the count doubling each time the radius doubles, so the fibres branch and stay about 1–2 pt apart; each octave's coarse layer continues the last one's fine layer, so there are no rings where they change. They vary brightness (±22%) and retardation (±5%), in broader bundles (11 around, ±15%).
   - **Boundaries:** each pixel reads the nuclei of the four texels around it. Where they differ, a boundary crosses the cell: each texel's boundary distance, signed by which crystal it belongs to, crosses 0 right on the boundary, so the pixel takes the crystal on its side (blended over about a point) and the groove follows the line exactly. Before that, each pixel took its nearest texel's crystal and boundaries stepped with the 2-pt texels. Only boundary cells pay for the second crystal.
   - **Details:** a dark groove about 1 pt wide along boundaries (real ones are depleted grooves a few µm wide), a thin bright fringe inside the rim, a faint halo 6 pt into the liquid (14%, as slightly out of focus), a small darker core at each nucleus, and the bands.
   - **Polarisers:** Dark Mode is crossed polarisers, `0.32 × light` over a near-black liquid. Light Mode is parallel polarisers, `0.8 × (1 − light)` on white: the same physics, so the crystals show the complementary colours (straw becomes blue, violet becomes pastel yellow) and the crosses turn white.
   - **Field:** a gentle vignette; with the round field stop, a soft-edged circle 94% of the screen height across, black outside, as seen down an eyepiece.

## The Michel-Lévy chart (`michelLevy`)
The colour of a crystal between crossed polarisers is the lamp's spectrum times sin²(πΓ/λ) for retardation Γ = thickness × birefringence (Sørensen, "A revised Michel-Lévy interference colour chart based on first-principles calculations", Eur. J. Mineral. 2013). `michelLevy` computes it for 0–3000 nm in 1024 steps: a 3200 K halogen lamp (Planck's law), 380–780 nm every 5 nm, summed by the CIE 1931 2° observer (the multi-lobe Gaussian fit of Wyman, Sloan and Shirley, JCGT 2013, within about 1% of the tables), turned into linear sRGB and white-balanced to the lamp as a camera would. Colours outside sRGB (low-order yellows, second-order blue, third-order green) are desaturated toward their own luminance rather than clipped, which keeps their hue. It goes into a 1024×1 texture, gamma-encoded. Parallel polarisers are 1 minus it. The research agent's independent Python version matched it (250 nm white at Y 0.97, 550 nm deep violet at Y 0.05, 800 nm pale green-white). After white balance, a 6500 K lamp differs by only a few 8-bit steps. `ponytail:` it ignores the dispersion of birefringence (about +10% from red to blue), which only shifts colours above ~1000 nm.

Vitamin C's refractive indices are about 1.46, 1.60 and 1.75 (Grenapin et al., Nanophotonics 2023), so a very birefringent crystal: 1 µm of film gives lavender-grey, 2 µm white to pale straw, 3 µm straw and gold, 5 µm the second order. Citric acid (Δn ≈ 0.016) only reaches first-order grey.

## Time and appearance
A cycle runs in parts (`advance`), each at its own rate from the current settings, so moving a slider changes the pace from then on without jumping:
- **Growth**: `u_grow` runs 0 → 1 over 230 s ÷ Growth speed. At 1× that's the speed real ascorbic acid grows at (Yamazaki et al., arXiv 1311.5219: 5–7 µm/s, so a 10× field fills in 3–4 minutes), linear in time like a real front.
- **Hold**: whatever Cycle length leaves after the growth, melt and liquid, at least 20 s (about 2 minutes at the defaults), while the last colour thickens in. So a slow growth speed can make a cycle longer than Cycle length.
- **Melt**, 0.27 × the growth time (about a minute), about four times as fast as it grew: `u_level` sweeps back down the arrival times, so the last grown goes first: rims, boundaries and small late crystals, then back toward the nuclei, as on a hot stage. Each retreating edge thins through the lower orders to grey and black, and a ±3% noise makes it ragged. `ponytail:` real vitamin C decomposes at its melting point (190 °C), so a real slide couldn't do this; the melt is licence, modelled on hot-stage videos of other small molecules.
- **Liquid** for 13 s, then new seeds. The new slide goes in while it's dark, so there's never a cut.
- The next slide is baked on a background task during the melt. If it isn't ready at the end, the slide waits in the dark.
- It opens 30% into a cycle (growth about half done), by running the cycle forward in 1 s steps. `CRYSTALS_AT` sets that fraction and `CRYSTALS_SEED` the first slide, for snapshots.
- Everything steps by `frameTime`, so it looks the same at any frame rate and stops while hidden. No `u_now`.
- Light Mode is parallel polarisers (above). The app rebuilds the scene when the appearance changes.

## Settings
| Key | Label | Range | Default | Notes |
|---|---|---|---|---|
| `crystals.cycle` | Cycle length | 2–30 min | 7 | live; the hold takes up what growth and melt leave |
| `crystals.speed` | Growth speed | 0.25–4× | 1 | live: 1× is real ascorbic acid, about 4 minutes to grow; the melt keeps pace |
| `crystals.size` | Crystal size | 0.5–2× | 1 | melts the current crystals in about 17 s and grows the new size |
| `crystals.thickness` | Thickness | 0.3–3× | 1 | live: scales the retardation, so low is first-order grey and high climbs the orders |
| `crystals.brightness` | Brightness | 0.3–1.5 | 1 | live |
| `crystals.stop` | Round field stop | switch | off | live: full screen or an eyepiece circle, for Dave to compare |

## Tuning constants
- Crossed exposure `0.32`, liquid `(0.0006, 0.0008, 0.0013)` linear; parallel white `0.8`.
- Fibres `44 × 2^floor(log2(r/6))` around, radial `0.12`; bundles 11 around.
- Cross contrast `mix(0.9, 0.5, smoothstep(0, 0.6, r / spacing))`, fibre wobble ±0.03 rad and a slow ±0.125 rad.
- Colour thickening `0.55 + 0.45 × smoothstep(0, 0.12, age)`.
- Groove `smoothstep(0.3, 1.1 pt)` of the signed distance; fringe `1 + 0.6 exp(−rim / 0.8 pt)`; halo `0.14 × smoothstep(−6, 0, rim)³`; core 1–4% of `spacing`.

## Performance
GPU about 0.75–0.9 ms and CPU about 0.47 ms per frame (release, 2x, 2026-09-27). The shader is six texture reads, one chart read, four value-noise calls and an `atan`; boundary cells add four texture reads and a second crystal. The bake takes about 0.2 s at the standard size, 0.1 s at 2× and 0.8 s at 0.5× (it scales with texels × nuclei); only the first slide bakes on the main thread, when the scene is built.

## Gotchas and shortcuts
- `SKMutableTexture(size:pixelFormat:)` accepts `kCVPixelFormatType_64RGBAHalf` and `128RGBAFloat` but samples them as bytes. Split values over two byte channels instead (above).
- SplitMix seeded with small consecutive numbers gives correlated second draws (seeds 1–5 all rolled "fill the field"). Use large, varied `CRYSTALS_SEED`s.
- The nucleus texture is nearest-filtered, so on its own a boundary steps by a texel; the four-texel blend above fixes it. An unsigned distance can't do that job: interpolated between two texels either side of a boundary it never reaches 0, so a groove drawn from it breaks into dashes. Signing it by the crystal each texel belongs to crosses 0 on the line.
- SKShader has no `notEqual` or other vector comparisons (the Metal translation fails at runtime); compare with `dot(abs(a − b), vec4(1))`.
- Noise around a nucleus by angle needs to wrap (`ring`), or `atan`'s jump at ±180° leaves a seam along one radius.
- `ponytail:` the bake checks every nucleus for every texel; a coarse grid of candidate nuclei would make it several times faster if the first load ever feels slow.

## Research and references
Two research agents collected 15 polarised micrographs (mostly Wikimedia Commons ascorbic acid, CC BY / BY-SA; Molecular Expressions and microbehunter for comparison only) and frames from 11 time-lapses (VANOX's ascorbic acid, citric acid, PEO and other polymer spherulites, salol, hot-stage melts). What made it into the scene:
- Every cross in a frame has the same orientation, locked to the polarisers; the arms are wedges, crisp at the nucleus and filling in toward the rim.
- Fibres are short radial dashes 1–2 px wide, neighbouring ones slightly different in colour and brightness.
- One tint dominates a photo; colour follows thickness (concentric zones, thicker rims), never the angle.
- Restful references are first-order (black, grey, white, straw) with lots of black liquid; garish ones are second- and third-order colours over the whole frame. The target was mean luminance 0.15–0.25 with 30–50% near-black; slides come out at 0.1–0.35.
- The front is followed by colour thickening in over ~25 s; new nuclei keep appearing for about half the growth, often on the rims of older crystals.
- Hot-stage melts go from the edges, boundaries and small grains first, 3–10 times faster than growth.

## Dave's feedback and decisions
- 2026-09-26, the brief: vitamin C crystallising between crossed polarisers, then melting and growing again; physics for colour and brightness; baked arrival field revealed by time; soft and dim with microscope depth of field; compare a round field stop with full screen. Knobs: cycle length, crystal size, thickness.
- 2026-09-27: "we need controls over crystal speed, also do another visual pass to try to make the crystals look smoother and nicer." That added Growth speed (and cycle parts timed in seconds rather than fractions of the cycle), and the smoothing pass: boundaries drawn exactly from a signed distance instead of stepping with the texels, silky fibres without the hashed speckle, seamless fibre octaves, softer scallops, softer and rarer bands, a smooth core, and a faint halo at the rims. Round field stop vs full screen still to be compared.

## Ideas / next steps
- A first-order (λ) plate as a look: the cross turns magenta and the quadrants blue and yellow. It needs the fibres' slow direction, which is radial here (ascorbic acid is length-slow).
- Very slow stage drift, or slowly rotating the polarisers, during the hold.
- A few specks of dust and tiny bright crystallites in the liquid, as in the grey rosette reference.
- A shallower depth of field: blur the thickest crystals slightly, as real thick ones go soft.

## Checking it
```sh
SNAPSHOT_SCENE=Crystals swift test                                     # a random slide, 30% into its cycle
CRYSTALS_SEED=2938471 CRYSTALS_AT=0.7 SNAPSHOT_SCENE=Crystals swift test    # a fixed slide at the hold
CRYSTALS_AT=0.9 SNAPSHOT_SCENE=Crystals swift test                     # melting
SNAPSHOT_DEFAULTS="crystals.stop=1" SNAPSHOT_APPEARANCE=light SNAPSHOT_SCENE=Crystals swift test
swift test --filter "michelLevyColours|crystalsBake"
```
To watch whole cycles on the desktop, `defaults write com.dtanquary.atrium crystals.cycle -float 0.5` (30 s), then delete the key.
