# Aurora

Green curtains of northern lights, fading up into violet with fine vertical rays, folding slowly over a jagged mountain range and snowy foreground drifts under twinkling stars.

- **Files:** `Sources/Atrium/Shaders.swift`. `aurora(size:)` holds the whole shader. It uses the `shaderCommon` helpers `noise`, `hash21` and `starField(pts, cell, density, t)`.
- **Entry:** `@MainActor func aurora(size:)`, which returns `shaderScene(size:source:)`. Registry entry: icon `wind`, tint `.green`.
- **Kind:** a single full-screen SKShader driven by `u_time`. There is no Swift-side state.

## How it works
It works in `uv = v_tex_coord` (0–1) and `p = uv * vec2(aspect, 1)`.
1. **Sky.** A gradient from dark teal near the horizon to near-black at the top, plus `starField(uv * u_size, 11, 0.3, t)`: one candidate star per 11 pt cell, 30% of them kept, each twinkling.
2. **Three curtains** (a loop, `i = 0..2`, each further back and dimmer by `1 - 0.25 i`).
   - **Lower edge:** `edge = 0.4 + 0.1i + 0.06·fold + 0.14·(noise − 0.5)`. The fold is two slow sines (0.04 and 0.03 rad/s) and the noise drifts at 0.01, so the curtains fold and ripple without looping.
   - **Light:**
     - a bright rim at the edge, `exp(-|h| * 70)`
     - a body fading upward, `exp(-h * 9)`
     - a violet tail higher up, `exp(-h * 4)` × 0.4
     - a faint glow below the edge
   - **Rays:** noise at 45× horizontal frequency, sheared along the folds (`+ fold * 3`) and drifting at 0.15, shaped by `0.25 + 1.4·rays²`.
   - **Patches:** a slow noise mask (`smoothstep(0.25, 0.7, …)`) so brightness comes and goes along each curtain.
   - **Colour:** green (0.2, 1, 0.5) for the body and rim, violet (0.6, 0.25, 1) for the tail.
3. **Soft clip.** `1 − exp(−aurora × 0.9)`, so overlapping curtains don't blow out. It fades above `uv.y` 0.6–1.05.
4. **Far range.** Ridged 4-octave noise (`peaks`) makes sharp summits at 0.08–0.40 of the height. Snow near the summits catches a green-tinted light, mottled by noise gullies. It's a hard silhouette with a 0.0015 anti-aliased edge.
5. **Foreground snow.** Rolling drifts at 0.04–0.125 of the height, lit green, with a sparkle from a second `starField` (cell 7, density 0.08, 3× faster twinkle). Then dither.

## Time and appearance
All motion comes from `u_time`, so a speed knob needs an integrated `u_phase` (the `LavaLamp` pattern). There is no Light Mode look, and it doesn't vary between loads: every load is the same aurora at the same time offset.

## Settings
None yet. Suggested:

| Key | Label | Range | Default | Drives |
|---|---|---|---|---|
| `aurora.speed` | Speed | 0–3 | 1 | integrated phase |
| `aurora.brightness` | Brightness | 0.3–1.5 | 1 | the soft-clip exposure (0.9 today) |
| `aurora.stars` | Stars | 0–1 | 1 | star-field strength |

`aurora.palette`, following real emission lines:
- **Green:** 557.7 nm atomic oxygen, today's look and the default
- **Red crown:** 630 nm oxygen high up, seen in strong storms
- **Blue-violet fringe:** 427.8 nm nitrogen
- **Pink lower edge:** strong displays

Each palette is a body, rim and tail colour, passed as uniforms.

## Tuning constants
- Fold speeds: 0.04 and 0.03. Edge noise drift: 0.01. Ray drift: 0.15. Patch drift: 0.008.
- Ray frequency: 45. Rim sharpness: 70. Body falloff: 9. Tail falloff: 4. Clip: 0.9.
- Peaks: `0.08 + 0.32 × peaks(p.x × 2.2)`.

## Performance
Measured at CPU 0.42 ms and GPU 1.87 ms per frame (release build, 2x). It's the most expensive GPU scene, at the top of the budget. The cost comes from about 25 noise evaluations per pixel: three curtains of 4–5 noise calls each, two star fields, four-octave peaks and the snow noise. If anything is added, cut first: the second ray-noise octave, the snow sparkle field, or run the curtains at half resolution.

## Gotchas and shortcuts
- The mountains are a flat silhouette with mottled snow, with no per-face lighting (the shaders agent flagged this).
- `u_time` doesn't advance in the render harness.
- Adding a fourth curtain costs roughly 0.4 ms of GPU.

## Dave's feedback and decisions
- It was one of the four scenes Dave picked for the picker's first round (with Flowing Gradient, Rain on Glass and Night Sky, later renamed Live Sky), then built by the shaders agent.
- He hasn't commented on it since, and it hasn't had a fidelity pass.
- The parent agent judged it to read well at launch.

## Ideas / next steps
- **Real-colour palettes** (above), rolled on each load like Nebula, with a slow crossfade to a new aurora every few minutes.
- **Substorms:** brightness surges and faster ray motion every few minutes, then calm.
- **Terrain:** lit mountain faces, or a still lake mirroring the curtains.
- **Night only:** follow the real Sun (dimmer or absent by day), as Flowing Gradient's mood does.

## Checking it
`SNAPSHOT_SCENE="Aurora" SNAPSHOT_DIR=/tmp/aurora swift test`. `SNAPSHOT_SECONDS` doesn't move shader time. For other moments, temporarily offset `t` in a scratch copy, as the shaders agent did for its +60 s and +300 s checks.
