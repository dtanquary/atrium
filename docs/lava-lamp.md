# Lava Lamp

Full-screen view inside a lava lamp. Glowing jewel-tone wax heats in a molten pool over the bulb and rises up the middle as round heads on stems that neck and pinch off. Most of it sticks to the top for a while, pancaked, then slides out and sinks near the cooler sides, sometimes dripping off the top on a thread. The liquid is lit from below by a bulb. It follows Light/Dark Mode.

- **Files:** `Sources/Atrium/LavaLamp.swift` holds the knobs, palettes, colour cycling, the blob layout (`layBlobs`) and the shader source. Noise comes from `shaderCommon` in Shaders.swift.
- **Entry:** `lavaLamp(size:)` returns `final class LavaLamp: SKScene`. Its registry entry in Scenes.swift has icon `lamp.table.fill`, tint `.orange`, `knobs: LavaLamp.knobs`, and palettes `PaletteChoice(key: "lava.palette", ...)`. The swatches are liquid-lit to wax-hot, `[3]` and `[1]`. The standard is "", meaning Random.
- **Kind:** a full-screen SKShader (metaballs), in a subclass with live uniforms.

## How it works
**Blob layout (`layBlobs`, Swift):** every frame, after integrating the time, Swift works out where the 8 heads and their 8 stems are and packs them into four `mat4` uniforms, one per column: `u_blobs0`/`u_blobs1` hold heads as (x, y, radius, stretch), `u_blobs2`/`u_blobs3` hold stems as (anchor x, anchor y, radius, 1/the head's radius). The shader needs 1/r for its lighting, and dividing there cost about 0.25 ms. It's a pure function of the time, so it looks the same at any frame rate. The time is kept in Double (`time`), so the layout stays smooth after days of running; `u_phase` is only its Float copy for the wobble and pool heave. This used to run in the shader for every pixel, which was 60% of the frame (see Performance).

It follows how real lamps convect (the research agent's sources: [Wikipedia on lava lamps](https://en.wikipedia.org/wiki/Lava_lamp) and Rayleigh–Taylor plumes, and [Phys. Rev. E 80, 046307](https://link.aps.org/doi/10.1103/PhysRevE.80.046307), whose lava-lamp regime has warm blobs rise, "attach to the top surface for a while", then sink). Each blob, from `hash(i + seed + trip·k)`, the shader's `hash11` ported to Double:
- **Trips:** a phase `s` through a trip every 60–110 s. `trip = floor(u)` feeds the hashes, so every trip rolls a new size, lane and height, and no path repeats.
- **Size:** radius `(0.028 + 0.1·h1²)·blobSize`, from pea-sized droplets to fist-sized heads (a healthy lamp has a mix; Mathmos says one big blob or many small ones means it's overheating). It shrinks to 0 at both ends of the trip, while buried in the pool, so a re-roll never pops.
- **Height:** `height(s)` rests in the pool, rises, lingers at the top, and sinks back more slowly than it rose. 65% of trips (`h2 < 0.65`) reach the top (`1 - 0.45r`, so they press against it); the rest turn back at 0.5–0.85.
- **Lanes:** it rises over the bulb (`rise`, 0.3–0.7 of the width), slides out along the top as it cools (`s` 0.40–0.66), and sinks toward the nearer, cooler wall (`sink`, 0.1–0.22 of the width further out, kept inside 0.07–0.93).
- **Shape:** heads stay round (real plume heads never stretch into tall eggs). `sy = (1 - 0.38·parked)·(1 + 0.12·max(-speed, 0))`: pancaked while parked on the top, a little long while dripping.
- **Stems:** while rising (`s` < 0.5) a column runs from the pool under its lane `(rise, -0.02)` to the head, radius `0.7r·k²` with `k = 1 - smoothstep(0.16, 0.32, s)`, so it thins and pinches off (squared, so a thin thread goes quickly instead of hanging on as a string). Trips that reached the top then drip: a thread from `(x, 1.02)` of radius `0.4r`, fading in at `s` 0.54–0.6 and pinching off by 0.72.

**Wax field (the loop in `main`, shader):** the 8 heads as metaballs `r²/d²`, the 8 stems as tapered segments, and the pool, all with analytic gradients. Wax is wherever the field passes 1.
- **Stem (`stem`):** a segment from the anchor to the head, thick at the anchor and 0.3× under the head, so it necks just below it. Its field is softened to `2r²/(d² + r² + 0.00015)`: still 1 at its radius, but it peaks at 2 on the axis instead of spiking. With a plain `r²/d²`, or without the constant, every stem's axis and every vanishing thread showed as a hard seam in the shading.
- **Pool:** a nearly flat surface near y ≈ 0.03 (heave `0.006·sin(4x + 0.1t) + 0.004·sin(9x - 0.13t)`) with a `1/d²` field, so heads rise off it on stems. Real pools are flat; the heads resting in it make the bumps.
- The column indices are clamped (`b0[min(i, 3)]`), since the GPU may read both sides of a `?:`.

**Wobble:** `p + u_wobble·noise` before evaluating the field, so edges are soft and irregular rather than perfect ellipses.

**Liquid:**
- `mix(liquidDeep, liquidLit, 0.15 + 0.95·cone·u_bulb)`: a soft cone of light rising from the bulb
- plus the wax's own glow scattering into the liquid (`u_glow`)

**Wax shading:** the only light in a real lamp is the bulb underneath (Mathmos's bulbs are directional, "directing the light into the lava"), so every blob glows brightest on its underside and dims toward its top. Real wax is opaque satin with no dark outline.
- **Where in its blob (`dl`):** alongside the field, the loop sums `lp += ball·(q - centre)/r` for the heads, so `dl = lp/f` is this pixel's offset from its blob's centre in radii (y from −1 underneath to +1 on top), smooth even where blobs merge. Stems don't add to it. The pool adds only below its surface (`clamp(…, -1, 0)`), so the top of the pool stays pale and hot rather than dimming like the top of a blob. Deriving `dl` from the gradient direction instead was tried by the agent: it leaves pinwheels and dents wherever the gradient vanishes.
- **Thickness:** `thick = 1 - exp(-(f-1)·0.9)` rises from the edge and levels off. That stops overlapping balls showing hot spots.
- **Colour:** `under = smoothstep(0.9, -0.9, dl.y)`. Deep to hot by `0.15 + 0.5·under + 0.25·heat + 0.3·thick`, then `×(0.7 + 0.4·under + 0.2·heat)` and a soft limb `×(0.85 + 0.15·z)`. Tops fall to the palette's deep colour rather than darkening; a darker floor (0.55) turned them muddy brown.
- **Glow:** a hot core `waxHot·(0.12 + 0.25·heat)·thick²` at every height, so the luminous cores survive, plus the bulb through the thin underside, a crescent `0.45·(1 - z)³·under·(0.4 + heat)`.
- **Sheen:** faint, `0.06·pow(·, 10)`, from a normal built from `dl`. The old `0.12·pow(·, 18)` gave merged heads a pair of highlights like eyes.

**Edge:** one pixel of antialiasing from the field's gradient. Thin wax is translucent: `u_opacity + (1 - u_opacity)·smoothstep(thick)`.

**Glass:**
- **Refraction:** a cylinder of liquid seen from outside magnifies the middle and crowds the sides into the walls, as every whole-lamp photo shows. So the field is evaluated at a warped x, `u = 2x - 1`, `p.x = aspect·(0.5 + 0.5·u·(0.8 + 0.2u²))`: 0.8× across the middle, 1.4× at the edges. Wax sliding toward a wall narrows and speeds up. The cone and glass terms use the plain x. It costs nothing measurable.
- darker toward the sides (`0.62 + 0.38·sin(πx)`), two faint vertical window reflections, then dither.

## Time, live data and appearance
- **Time:** `time` (Double) is integrated in `update` (`dt × speed`, dt capped at 0.5 s) and copied to `u_phase`, so the speed slider never jumps and `SNAPSHOT_SECONDS` moves it forward.
- **Palette at build:** the pinned `lava.palette` by name, otherwise random. Each palette has `dark` and `light` 4-colour sets, `[waxDeep, waxHot, liquidDeep, liquidLit]`, chosen by `systemIsDark`.
- **Colour cycle:** only when the palette is Random and `lava.cycleMinutes` > 0. An SKAction repeats every N minutes and eases all four colours to a different palette in the current look over 60 s (`cycle()`). The palette showing is tracked by index in `current`: a finished blend isn't bit-for-bit the colours it aimed at, so the old check (comparing colours) sometimes failed to rule out the current palette and "changed" to the same one. It's rescheduled in `applySettings` only when the interval actually changes.
- **Appearance:** a Light/Dark switch rebuilds the scene through the app (crossfade). A new palette pick rebuilds it too, if it's showing.

## Settings
| key | label | range | default | drives |
|---|---|---|---|---|
| lava.speed | Speed | 0.2–3 | 1 | phase rate (CPU side) |
| lava.blobSize | Blob size | 0.6–1.6 | 1 | blob radius multiplier |
| lava.wobble | Wobble | 0–0.04 | 0.018 | edge irregularity |
| lava.glow | Glow | 0–0.6 | 0.3 | wax glow in the liquid |
| lava.bulb | Bulb | 0.3–1.5 | 1 | strength of the bulb's light cone |
| lava.opacity | Wax opacity | 0.4–1 | 0.72 | opacity of thin wax edges |
| lava.cycleMinutes | Change colors every | 0–30 | 8 (0 = off) | cycle interval, shown only while Random |
| lava.brightness | Brightness | 0.4–1.5 | 1 | the shared grade (`gradeKnobs("lava")`) |
| lava.contrast | Contrast | 0.5–1.5 | 1 | 〃 |
| lava.saturation | Saturation | 0–2 | 1 | 〃 |
| lava.hue | Hue shift | −180–180° | 0 | 〃 |

Sections: Colors (swatches plus the cycle interval), Motion, Light, Look. The Look sliders go through `grade()` from `shaderCommon`, just before the dither (see `docs/nebula.md`). Its contrast pivot, `u_pivot`, is set when the scene is built: 0.3 for the dark liquids and 0.7 for Light Mode's pale ones, the same split as Rain on Glass. The grade comes after the colour cycle, so a hue shift follows the pairings as they change.

**Palettes** (`LavaLamp.palettes`): jewel-tone wax drawn from Flowing Gradient's family so the two feel related. Light Mode keeps the same hues in pale liquids.

| Palette | Dark Mode | Light Mode |
|---|---|---|
| Coral | coral in indigo | coral in pale lavender |
| Soft Blue | soft blue in navy | soft blue in sky |
| Magenta | magenta in violet | magenta in blush |
| Teal | teal in deep blue | teal in mist |
| Peach | peach in plum | peach in cream |
| Lavender | lavender in midnight | lavender in periwinkle |
| Rose | rose in deep teal | rose in seafoam |

## Tuning constants
- Blob count: 8 (the loop in `layBlobs` and `field`). Trip length: 60–110 s. Radius 0.028–0.128.
- Height: `smoothstep(0.06, 0.40, s) - smoothstep(0.56, 0.94, s)`, from −0.05 (inside the pool) to the top.
- Ceiling: 65% of trips, top at `1 - 0.45r`, pancake `sy` down to 0.62 while parked (`s` 0.34–0.66; 0.3 as much for trips that turn back).
- Lanes: rise at 0.3–0.7 of the width; slide out over `s` 0.40–0.66 by 0.1–0.22 of the width; sway `0.02·sin(0.03t + 2i)`.
- Stem: 0.7r at the pool, tapering to 0.3× under the head; softening constant 0.00015. Drip thread: 0.4r. Both grow in as the head clears its anchor, from 0.5r to 2.5r away.
- Pool: height 0.03, heave `0.006·sin(4x + 0.1t) + 0.004·sin(9x - 0.13t)`, strength `0.0028/d²`.
- Satin sheen: 0.12 × pow(·, 18). Cycle fade: 60 s.

## Performance
CPU about 0.5 ms and GPU 1.0 ms per frame (release, 2x): the stems add about 0.2 ms over plain balls, the lighting's second accumulator about 0.1. It was 1.86 ms of GPU until the blob layout moved to Swift. The research agent measured where the time went (seed 17, Coral, 40 s): removing the wobble noise saved 0.02 ms, the tails 0.09, all the wax shading 0.02, and cutting 8 blobs to 6 saved 0.27. Replacing the per-blob hashes, `height()` and `sin` with constants, keeping all 16 balls, took it from 1.77 to 0.66 ms. So summing the balls is cheap; recomputing each blob's position at every pixel wasn't. The CPU side is 8 blobs of arithmetic a frame. The colour-cycle fade adds nothing to the GPU (it only animates uniforms).

## Gotchas and shortcuts
- `ponytail:` the colour cycle is a straight RGB blend, so opposite pairings pass through a muddier middle for part of the minute. Blend in a perceptual space if it ever looks dull.
- The cone and window-reflection terms square with `d*d`, not `pow(d, 2.0)`: GLSL and Metal leave `pow` of a negative base undefined.
- Knobs are read by array index: `Self.knobs[0]` (speed), `[1]` (blob size) and `[6]` (cycle minutes). Reordering breaks them.
- Unused uniforms (`u_speed`, `u_blobSize`, `u_cycleMinutes`) are created for every knob. That's harmless.
- The blob matrices are passed to `field` and `balls` as parameters, since SKShader uniforms are only visible inside `main()`. Indexing a `mat4` column with the loop counter (`m[i]`) compiles and runs.
- The CPU hash (Double `sin`) doesn't match the GPU's float `sin`, so a given seed lays out differently than it did before the move. That doesn't matter: the seed is random per load.
- The agent chose a colour blend over a Nebula-style scene crossfade, because two sets of blobs overlapping looks like a double exposure.
- `LAVA_SEED=17` fixes the random seed, so before/after renders of a look change show the same blobs.
- There's no true bloom, just a glow approximated from the wax field.
- The stem gradient ignores how the taper changes along the segment. It's close enough for shading.
- **Stems need room:** a stem squeezed into a short gap (a head just leaving the pool, or parked against the top over its drip anchor) makes its taper a near step in the field. Because the field reaches far, that showed as straight seams fanning across the liquid, with creases in the wax outline. So a stem's radius grows in with the gap, `smoothstep(0.5r, 2.5r, |y - anchor y|)`. It showed up in about one frame in four at 50 s; a 2-minute run at 3× speed afterwards had no seams.

## Dave's feedback and decisions
- He asked for a "next level" pass with more colour variety. The agent's critique of the original:
  - identical glossy orange eggs
  - mechanical sine bobbing
  - a flat liquid
  - one colour pairing

  That led to the trip, neck and shading rewrite, plus eight classic real-lamp pairings.
- "The lava behaviour looks good, but it defaulted to a pretty ugly green and blue." He wanted prettier colours like the gradient's. The classic pairings (orange in red, the Astro red in yellow, green in blue, and so on) were replaced with the seven jewel tones.
- He asked for it to follow the system's Dark/Light setting: darker lava colours in Dark Mode, lighter in Light Mode.
- He said yes to sliders and a palette picker in Settings.
- He asked for a research pass on photos and videos of real lamps, with the suggestions implemented. The agent found: per-blob maths was 60% of the GPU frame (moved to Swift); real rising wax is a round head on a stem rooted in the pool, not a stretched egg; wax sticks to the top a while, rises over the bulb and sinks at the sides; paths repeated every trip; and there were no small droplets. Those became the layout above. It advised skipping floating specks in the liquid (they read as a starfield), a whole-lamp framing (it would fill under a third of the screen), and the heating coil (it's never visible from the front).

## Ideas / next steps
- A perceptual (OKLab-style) colour blend for the cycle.
- A real bloom pass.
- A warm-up phase after login, with tall "stalagmite" towers before it settles (the Mathmos FAQ describes it). Low value; only if Dave asks.
- The layout is in Swift now, so motion ideas (per-trip re-rolls, rising up the middle and sinking at the sides, wax that sticks at the top) are plain Swift rather than per-pixel shader code.

## Checking it
```sh
SNAPSHOT_SCENE="Lava Lamp" SNAPSHOT_SECONDS=40 swift test          # integrated phase, so time moves forward
SNAPSHOT_DEFAULTS="lava.palette=Teal" SNAPSHOT_APPEARANCE=light SNAPSHOT_SCENE="Lava Lamp" swift test
LAVA_SEED=17 SNAPSHOT_SECONDS=36 SNAPSHOT_SCENE="Lava Lamp" swift test   # the same blobs every run, for before/after
```
To check the colour cycle, run it at its shortest interval for six changes (about 15 s of wall time):
```sh
SNAPSHOT_DEFAULTS="lava.cycleMinutes=1" SNAPSHOT_SECONDS=365 SNAPSHOT_SCENE="Lava Lamp" swift test
```
A temporary `print` in `cycle()` shows each pick.
