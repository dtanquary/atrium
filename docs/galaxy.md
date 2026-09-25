# Galaxy

A spiral galaxy turning slowly in deep space. Every load rolls a new one after a real galaxy (Whirlpool, Pinwheel, Andromeda, the Milky Way, NGC 1300 or Triangulum), with its own tilt, orientation, direction of spin and star field. Its arms are made of blue star clouds on a bright, smooth disc, with translucent reddish-brown dust lanes, feathers and filaments, and chains of pink H II regions along their inner edges, around a cream bulge. The colours were sampled from ESA/Hubble and ESO photos. The disc's own stars sparkle as it turns. Left running, it dissolves into a freshly rolled galaxy every 10 minutes. Built as Nebula's companion, to the same bar.

- **Files:** `Sources/Atrium/Galaxy.swift` holds the knobs, the `kinds` table, the cycling and the shader source. `hash42`, `noise`, `fbm` and `brightStar` come from `shaderCommon` in Shaders.swift. `brightStar` moved there from Nebula so both scenes share it.
- **Entry:** `galaxy(size:)` returns `final class Galaxy: SKScene`. Its registry entry in Scenes.swift sits after Nebula and has:
  - icon `hurricane`, tint `.indigo`
  - `knobs: Galaxy.knobs`
  - palettes `PaletteChoice(key: "galaxy.kind", ...)`, whose swatches are bulge, knots and young stars. The standard is "", meaning Random.
- **Kind:** a full-screen SKShader in a subclass with live uniforms, fully procedural, with no image files.

## How it works
Everything is maths per pixel, per frame, in four coordinate frames:
1. **Screen to disc:** `c` is the pixel relative to the galaxy centre, in galaxy radii (`u_radius` screen heights). `e` turns it by the position angle `u_pa`, so the major axis runs along x. `d = (e.x, e.y·u_spin / u_tilt)` undoes the tilt (`u_tilt` is cos i) to land in the disc's own plane. `u_spin = -1` mirrors the disc, which turns it clockwise with its arms still trailing.
2. **Turning:** `g = turn(d, -u_phase)`. The whole pattern stands still in `g`, so turning the galaxy is just advancing `u_phase`. Everything that belongs to the galaxy is sampled in `g` or `q`, so it all turns together, including the resolved stars and knots.
3. **Swirled space:** `q = turn(g, lr / tan(pitch))`, where `lr = ln(r / r0)`. Turning each radius by its log winds straight rays into logarithmic spirals, so in `q` the arms are just rays at `m·atan(q) = 0`. Noise sampled in `q` gets sheared along the arms by about 1/tan(pitch), which gives the streaks, feathers and lanes for free. `r0` is where the arms start: the bar's ends, or 1.6× the bulge. Inside 0.35·r0 the winding stops, so the centre doesn't alias. Dust noise uses `qn`, the same swirl wound no tighter than a 25° pitch; otherwise tightly wound kinds (Andromeda, at 8°) close their dust into rings.
4. **Arms:** `ph = m·atan(q) + warp`, where `warp` is fbm in `q` scaled by the kind's raggedness. There are three profiles off the same phase, placed the way material streams through a density wave:
   - `crest = pow(½ + ½cos ph, 4 - 2·ragged)` is the arm
   - `lane`, just upstream (ph + 0.45, wobbled by the dust noise), is where gas piles up into dust on the arm's inner edge
   - `hii`, at ph + 0.2, is where new stars light hydrogen pink, right beside the dust, as in the photos
   - `young`, just downstream (ph − 0.35), is where the young blue stars run

   Each arm gets its own strength, `armAmp` from 0.6 to 1 (hashed from the arm's index), so the pattern is lopsided like real ones. Flocculent kinds multiply `crest` by a noise mask, so their arms break into segments.
5. **Light, from a bright disc the arms brighten.** In Hubble images the space between the arms isn't dark: the whole disc is a smooth glow, cream toward the middle and blue-grey outward. The arms are only two to three times brighter than the disc around them. Drawing arms on a dark disc is what made the first version look crisp and CG.
   - disc: `exp(-rt/0.4)`, fading out between 0.9 and 1.6 with no edge. `rt` gives the disc a thickness of 0.15, so steep tilts fade to a soft ellipse instead of a sharp one, and it's also what the branch at 1.6 tests.
   - arm: `crest·inArms·(0.5 + 0.9·clump)`. `inArms` fades the arms in past `r0`. `clump` is two octaves of noise in unswirled `g`, so the arms read as star clouds rather than brush strokes.
   - light: `tint·disc·(0.6 + 1.5·arm)·1.4·√los`. `tint` shades from bulge cream to disc white outward, and toward the young-star blue in the arms and the outskirts. `los = min(1/cos i, 4.5)` is the path through the disc, so tilted discs look brighter.
   - bar: `exp(-(x/L)⁴ - (y/0.2L)²)` in `g`, so it's flat-ended and turns with the disc
   - young stars: `young·inArms·clump·disc`
6. **Dust:** `fbmRidge(qn)` gives fbm `dt` and a ridged multifractal from the same five noise samples. There are four parts:
   - `lane`: narrow (exponent 14), on the arm's inner edge, broken where `lumps + dt` is low
   - `feather`: 18 spurs leaving the arms at a pitch 35° steeper, about half of them kept, only on the upstream side of each arm
   - `web`: the ridges, thin connected filaments everywhere down to the nucleus, stronger on the arms
   - `barLane`: for barred kinds, curved lanes along the bar's leading edges, as in NGC 1300

   The total is scaled by `los`, so tilted galaxies (M31) show stronger lanes. Dust sits in a thin midplane layer, so a third of the old disc's light is in front of it (`screen = mix(absorb, 1, 0.3)`) and lanes redden rather than go black. The arms, young stars and resolved stars get the full `absorb = exp(-dust·(0.5, 0.75, 1.0))`, which is reddish brown because blue is lost first. H II regions get `sqrt(absorb)`.
7. **Resolved stars (`discStar`):** one candidate per cell of `g`. There are two layers:
   - 2.2 pt cells for a fine grain of stars that follows the light (kept up to 85% on the arms, `disc·0.6` elsewhere), each as bright as the disc around it (`min(disc·1.5, 0.12)`), so it reads as texture rather than salt
   - 11 pt cells for bright blue giants just past the crests

   `m` maps a step in the disc to screen points, so every star is a round pinpoint at any tilt. Cells are sized `/u_tilt` so they never get squashed below the star's size.
8. **H II regions (`knot`):** 16 pt cells, kept along `hii` on the arm's inner edge, only where a slow noise (`groups`) allows, and only inside r ≈ 1.2, so they come in chains and complexes. Each is 1–4.5 pt: pink hydrogen glow (`u_knots`, ×2.2) around a blue-white cluster core, dimmer toward the outskirts. They're round on screen, like the stars.
9. **Bulge:** a Sérsic n=2 profile (`3·exp(-3.67√rb)`) plus a nucleus, measured in `e` with an axis ratio of `mix(cos i, 1, 0.6)` (bulges are rounder than discs). The disc cuts through its middle. `behind` is the share of bulge light behind the dust: half face-on, more on the near side of a tilted galaxy. That gives the Andromeda-style dust silhouette across the bulge.
10. **Composite: a Hubble-style stretch.** Brightness gets `asinh(6·lum)/asinh(12)`, the log-like curve used to process Hubble and ESO images. It lifts the faint outer disc so the galaxy fades gradually instead of stopping, and holds the core. It's applied to brightness and not per channel, so colours keep their saturation; the brightest parts pale toward white, as on a real sensor. `col = sky·absorb + stretched light`. The sky behind is described in the next step. `brightStar` foreground stars go on top, untouched by the galaxy's dust, since they're in our own galaxy. Then a `/128` dither.
11. **Background sky:** `starLayer` is drawn twice:
    - 5 pt cells on a square grid, up to 16% kept: faint stars only
    - 17 pt cells on a grid turned 40°, up to 30% kept: the only layer bright enough for a soft halo

    The two grids never line up, so there's no lattice to spot. Both are thinned and thickened by `crowd` (one noise at 160 pt, from 0.25× to 1.75×), which gives loose clusters and emptier patches. Each star's brightness is `pow(h, 6)`, so most are faint. Its colour runs from blue giants through white to orange dwarfs, and it twinkles ±12% at its own rate. `farGalaxy` adds faint tilted smudges in about 12% of 110 pt cells.

**Each load rolls a random:**
- kind, unless one is pinned
- `u_seed`, a new region of every noise field, and a new star field (the background is offset by `u_seed·97`)
- tilt within the kind's range, a few degrees either side of the real galaxy's
- position angle: tilted galaxies stay within about ±30° of level so they fit the screen; face-on ones can point any way. A 50% flip decides which side is near.
- spin direction
- centre (44–56% across, 46–54% up) and radius (0.36–0.44 screen heights, so the arms reach about 0.5)

## Time, live data and appearance
- **Rotation:** `u_phase` is integrated in `update` at `2π/720 × speed` rad/s, one turn every 12 minutes at speed 1. At a typical radius that's 3–4 pt/s, about Nebula's drift. It's wrapped at 2π, and the step is capped at 0.5 s. `SNAPSHOT_SECONDS` moves it forward.
- **Rigid rotation:** the whole disc turns as one piece (`ponytail:` in `update`). Real discs shear, with inner parts turning faster, but a sheared texture winds up tighter forever. Doing it properly means blending two phases, flow-map style, at twice the cost.
- **Cycling:** only while the kind is Random and `galaxy.cycleMinutes` > 0 (default 10). An SKAction waits, then `handOver()` presents a new `Galaxy` with `SKTransition.crossFade(withDuration: 90)`, both scenes still turning. It's rescheduled in `applySettings` only when the interval actually changes, and the wait pauses while the wallpaper is covered.
- **Re-picking:** choosing Galaxy in the menu, or a kind in Settings, crossfades to a fresh roll immediately.
- No location or network use. There's no Light Mode look; it's inherently dark, like Nebula.

## Settings
| key | label | range | default | drives |
|---|---|---|---|---|
| galaxy.brightness | Brightness | 0.4–1.8 | 1 | exposure |
| galaxy.dust | Dust | 0–2 | 1 | multiplies every kind's dust |
| galaxy.rotation | Rotation speed | 0–4 | 1 | turn rate (CPU side); 0 holds it still |
| galaxy.cycleMinutes | New galaxy every | 0–30 min | 10 | shown under Colors, only when Random; 0 is off |

Sections: Look, Motion, and Colors (the kind picker).

**Kinds** (`Galaxy.kinds`), each after a real galaxy and its Hubble and ground-based portraits:

| Kind | After | Arms | Pitch | Bar | Bulge | Ragged | Dust | Tilt | Look |
|---|---|---|---|---|---|---|---|---|---|
| Whirlpool | M51 | 2 | 19° | none | 0.05 | 0.2 | 1.3 | 15–25° | grand design, strung with H II |
| Pinwheel | M101 | 4 | 27° | none | 0.03 | 0.55 | 0.8 | 10–25° | face-on, many open, lopsided arms |
| Andromeda | M31 | 2 | 8° | none | 0.13 | 0.5 | 1.2 | 72–77° | cream bulge, dusty arms, mauve outskirts |
| Milky Way | ours | 2 | 13° | 0.28 | 0.09 | 0.3 | 1.2 | 0–35° | short bar, two main arms |
| Great Barred | NGC 1300 | 2 | 17° | 0.45 | 0.05 | 0.1 | 1.0 | 40–50° | long bar with dust lanes, open arms off its ends |
| Triangulum | M33 | 2 | 30° | none | 0.015 | 0.9 | 0.6 | 50–56° | a flocculent patchwork, rich in H II |

Colours per kind: bulge (cream), old disc (warm grey), young stars (cyan-grey blue) and H II (salmon pink). They were sampled from the photos (M51 heic0506a, M101 heic0602a, NGC 1300 heic0501a, M33 eso1424a, and M31) as the asinh stretch shows them. The stretch keeps hue, so gold bulge colours came out literally orange. Andromeda's outskirts are mauve; Triangulum and NGC 1300 are the bluest. The Milky Way row wasn't sampled; it's in the same family.

## Tuning constants
- Rotation `2π/720` rad/s at speed 1.
- Arms: warp `2 + 5·ragged`; crest exponent `4 - 2·ragged`; lane at ph + 0.45 (exponent 14); H II at ph + 0.2 (exponent 10); young at ph − 0.35 (exponent 8); arm strengths 0.6–1.
- Disc scale length 0.4, fading out between 0.9 and 1.6; the arms brighten it `0.6 + 1.5·arm`.
- Dust: lanes ×1.3, feathers ×0.7 (none on flocculent kinds), web `0.25 + 0.9·crest`, bar lanes ×0.9; all ×`los`; reddening (0.5, 0.75, 1.0); 30% of the old disc in front.
- Stars: 2.2 pt grain kept up to 85% (×`min(disc·1.5, 0.12)`), and 11 pt giants up to 30% (×0.5). H II: 16 pt cells, up to 90% where grouped, inside r ≈ 1.2, ×2.2.
- Bulge `3·exp(-3.67√rb) + 1.5·exp(-60rb²)`. Stretch `asinh(6·lum)/asinh(12)`, with highlights paling above 0.55.
- Cycle every 10 minutes, dissolve 90 s.

## Performance
CPU 0.5 ms and GPU 1.0–1.9 ms per frame (release, 2x), depending on how much of the screen the roll covers: tilted Andromeda is cheapest, and a large Whirlpool is at the budget. Inside the galaxy the cost is mostly two 5-octave fbm calls (warp, and dust with its ridges from the same samples), five single noise calls, three cell lookups and a `log`/`atan` per pixel. The 2.2 pt star grain is the densest lookup. Pixels beyond 1.6 galaxy radii skip all of it and draw only sky; the halo fades out by then, so there's no edge. The cutoff was 2.5, which spent most of the budget on empty space. The layered sky costs about 0.3 ms. During the 90 s dissolve both galaxies render, so it roughly doubles (`ponytail:` in `handOver`).

## Gotchas and shortcuts
- **`u_texture` is taken:** SpriteKit already defines it as the sprite's texture, so a uniform with that name fails to compile ("redefinition of parameter"). The kind's raggedness and dust ride in `u_arms` instead.
- **Stars and knots in a turning, tilted disc:** hashed cells live in `g` so they turn with it, but distances are measured on screen through `m`. Otherwise tilt squashes the stars into dashes.
- **`hash21` repeats:** for whole-number cells it tiles every 50 cells across and 100 up. At 7 pt star cells that's every 350 pt, about four times across the screen, and Dave spotted the pattern in the empty sky. Every cell lookup here (sky, disc stars, knots, far galaxies) uses `hash42` instead, which also gives four random numbers per call.
- **Value noise is grid-aligned:** the clump noise's second octave is rotated, and its contrast kept soft. Hard thresholds on it came out as blocky, stencil-cut shapes.
- **Arm direction:** the arms trail the rotation. The pattern turns anticlockwise in `d`, and `+ln(r)/tan(pitch)` in the swirl makes arms turn clockwise going outward. Both flip together with `u_spin`. This was checked by rendering one fixed roll at two moments.
- Knob lookups go through the named statics `Galaxy.rotation` and `Galaxy.cycleMinutes`, not array indices (the trap Flowing Gradient's doc warns about).
- `u_time` still drives the background twinkle, which doesn't move in tests.

## Dave's feedback and decisions
- He asked for "an ultra high fidelity animated background of a rotating galaxy", using the existing wallpapers and docs as the template. It was built as Nebula's sibling: real objects for colours and shapes, a new roll on every load, a slow dissolve when left running, and calm motion.
- Early renders read as a CG illustration, so these were tuned toward a Hubble photo:
  - arms: brush strokes became star clouds
  - dust: heavy black ribbons became thin, broken lanes on the inner edges
  - the disc: a snowfall of stars became a glowing disc with sparse sparkles
  - knots: evenly spaced beads became clusters
- "A great start, but we need to improve it." First: "The background stars are too uniform, I can see patterns in the stars." The cause was `hash21` tiling. Fixed with `hash42` for every star field (Nebula's and Aurora's too), and the layered, clustered, coloured sky above.
- He asked for research into how 3D tools build galaxies, and for better reference photos, to lift each kind's look. A research agent sampled colours from the photos, compared renders with them, and prototyped the fixes merged here: photo-sampled colours; translucent, tilt-aware dust with feathers, a filament web and bar lanes; H II regions on the arms' inner edges; lopsided arms; a thick disc for steep tilts; and a finer star grain.
- "They look too crisp at the edges and just don't quite resemble the pictures we see from Hubble. Very close, just something is off." Compared with ESA/Hubble's M51 (heic0506a), the main gap was the dark disc: the light model became a bright exponential disc the arms brighten. The rest followed from the photo: an asinh stretch in place of `1 - exp(-x)`, narrower reddish-brown lanes, a finer star speckle, smaller knots in chains, and a paler core.

## Ideas / next steps
- Differential rotation via two blended phases, if rigid turning ever looks wrong up close.
- Companion galaxies: M51's NGC 5195 at the tip of an arm, or M31's M32 and M110.
- Edge-on kinds (Sombrero, NGC 891) need a thick disc and a vertical dust lane, not this thin-disc projection.
- A slow drift or zoom within one galaxy, like Nebula's band idea.
- A Tilt knob, if Dave wants to force face-on views.

## Checking it
```sh
SNAPSHOT_SCENE=Galaxy swift test                                            # a random roll
SNAPSHOT_DEFAULTS="galaxy.kind=Andromeda" SNAPSHOT_SCENE=Galaxy swift test
SNAPSHOT_DEFAULTS="galaxy.kind=Whirlpool,galaxy.rotation=4" SNAPSHOT_SECONDS=30 SNAPSHOT_SCENE=Galaxy swift test   # further round
```
Each render rolls a new tilt, angle and seed. To compare two moments of the same galaxy, temporarily fix `u_seed`, `angle` and `u_spin` in `init`, render at two `SNAPSHOT_SECONDS`, and put them back. To test cycling fast, temporarily shorten the cycle and the 90 s dissolve, then run the app binary directly and check that it survives several handovers.
