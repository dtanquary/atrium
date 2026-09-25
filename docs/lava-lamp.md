# Lava Lamp

Full-screen view inside a lava lamp. Glowing jewel-tone wax heats in a molten pool at the bottom, rises as stretched teardrops that pinch off on thin necks, slumps wide at the top and sinks back. The liquid is lit from below by a bulb. It follows Light/Dark Mode.

- **Files:** `Sources/Atrium/LavaLamp.swift` holds the knobs, palettes, colour cycling and shader source. Noise and `hash11` come from `shaderCommon` in Shaders.swift.
- **Entry:** `lavaLamp(size:)` returns `final class LavaLamp: SKScene`. Its registry entry in Scenes.swift has icon `lamp.table.fill`, tint `.orange`, `knobs: LavaLamp.knobs`, and palettes `PaletteChoice(key: "lava.palette", ...)`. The swatches are liquid-lit to wax-hot, `[3]` and `[1]`. The standard is "", meaning Random.
- **Kind:** a full-screen SKShader (metaballs), in a subclass with live uniforms.

## How it works
**Wax field (`field`):** 8 blobs plus the pool, as metaballs `r²/d²` with analytic gradients. Wax is wherever the field passes 1. Each blob (driven by `hash11(i + seed)`):
- **Size:** radius `(0.045 + 0.075·h1²)·u_blobSize`, so mostly small with a few big ones.
- **Trip:** a phase `s = fract(t/(55 + 50·h2) + h3)`, one trip every 55–105 s. `height(s)` rests in the pool, rises, lingers at the top and sinks back more slowly than it rose.
- **Speed and stretch:** `speed` is the derivative of height. Moving wax stretches tall (`sy = 1 + 0.9·|speed|`); wax resting at the top slumps wide.
- **Tail:** each blob drags a second, smaller ball (0.55 r) behind its motion. Rising wax trails a neck off the pool that thins and pinches off; sinking wax drips.
- **Pool:** a heaving surface near y ≈ 0.03 with a `1/d²` field, so blobs rise off it on necks.

**Wobble:** `p + u_wobble·noise` before evaluating the field, so edges are soft and irregular rather than perfect ellipses.

**Liquid:**
- `mix(liquidDeep, liquidLit, 0.15 + 0.95·cone·u_bulb)`: a soft cone of light rising from the bulb
- plus the wax's own glow scattering into the liquid (`u_glow`)

**Wax shading:**
- **Thickness:** `thick = 1 - exp(-(f-1)·0.9)` rises from the edge and levels off. That stops overlapping balls showing hot spots.
- **Normals:** curvature is mostly near the edge (`×(1 - 0.8·thick)`), so overlaps don't dimple the surface.
- **Subsurface:** deep to hot colour by thickness and `heat` (hotter near the bottom).
- **Light:** a hot-core glow, light from below, the bulb glowing through thin undersides, and a soft satin sheen rather than a glassy highlight.

**Edge:** one pixel of antialiasing from the field's gradient. Thin wax is translucent: `u_opacity + (1 - u_opacity)·smoothstep(thick)`.

**Glass:** darker toward the sides (`0.62 + 0.38·sin(πx)`), two faint vertical window reflections, then dither.

## Time, live data and appearance
- **Time:** `u_phase` is integrated in `update` (`dt × speed`, dt capped at 0.5 s), so the speed slider never jumps and `SNAPSHOT_SECONDS` moves it forward.
- **Palette at build:** the pinned `lava.palette` by name, otherwise random. Each palette has `dark` and `light` 4-colour sets, `[waxDeep, waxHot, liquidDeep, liquidLit]`, chosen by `systemIsDark`.
- **Colour cycle:** only when the palette is Random and `lava.cycleMinutes` > 0. An SKAction repeats every N minutes and eases all four colours to another palette in the current look over 60 s (`cycle()`). It's rescheduled in `applySettings` only when the interval actually changes.
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
- Blob count: 8 (the loop in `field`). Trip length: 55–105 s. Neck ball: 0.55 r at `1.8·r·speed` behind.
- Pool: height 0.03, heave `0.018·sin(4x + 0.15t) + 0.01·sin(9x - 0.22t)`, strength `0.0028/d²`.
- Rest height −0.06 (inside the pool), top 0.62–0.92.
- Satin sheen: 0.12 × pow(·, 18). Cycle fade: 60 s.

## Performance
CPU 0.45 ms and GPU 1.86 ms per frame (release, 2x). That's near the top of the ~2 ms GPU budget. The 8 blobs × 2 balls with gradients per pixel dominate. Fewer blobs, or dropping the tails, would cut it. The colour-cycle fade adds nothing to the GPU (it only animates uniforms).

## Gotchas and shortcuts
- `ponytail:` the colour cycle is a straight RGB blend, so opposite pairings pass through a muddier middle for part of the minute. Blend in a perceptual space if it ever looks dull.
- **Possibly wrong:** `pow(negative, 2.0)` in the cone and window-reflection terms (`pow((x - 0.5)/0.6, 2.0)` and similar). GLSL and Metal leave `pow` of a negative base undefined. It renders fine today, perhaps because the translator folds it to `x*x`, but `d*d` would be safe.
- Knobs are read by array index: `Self.knobs[0]` (speed) and `[6]` (cycle minutes). Reordering breaks them.
- Unused uniforms (`u_speed`, `u_cycleMinutes`) are created for every knob. That's harmless.
- The agent chose a colour blend over a Nebula-style scene crossfade, because two sets of blobs overlapping looks like a double exposure.
- There's no true bloom, just a glow approximated from the wax field. Wax never collects at the top.

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

## Ideas / next steps
- A perceptual (OKLab-style) colour blend for the cycle.
- A real bloom pass.
- Wax that sometimes collects at the top.
- If GPU cost matters, try 6 blobs or conditional tails.

## Checking it
```sh
SNAPSHOT_SCENE="Lava Lamp" SNAPSHOT_SECONDS=40 swift test          # integrated phase, so time moves forward
SNAPSHOT_DEFAULTS="lava.palette=Teal" SNAPSHOT_APPEARANCE=light SNAPSHOT_SCENE="Lava Lamp" swift test
```
To check the colour cycle quickly, temporarily set `lava.cycleMinutes` very low. It's a slider value, so a fraction like 0.1 isn't possible (it rounds), so temporarily change the `* 60` in `applySettings` instead.
