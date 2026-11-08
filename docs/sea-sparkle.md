# Sea Sparkle

A beach at night in a bloom of bioluminescent plankton. Each wave is dark until it breaks. A line of cyan light runs along its lip as the break peels along the crest, the whitewater lights and rolls in, fading over a few seconds, and the swash leaves points of light on the wet sand. The sky above is dark, with the real stars and, if wanted, the real Moon. It's drawn by one shader, in which each wave's break, bore and swash are worked out by formula from a handful of numbers the CPU hands it each frame.

Dave asked for it on 2026-11-07: "I have an idea for like a bioluminescence shoreline, can we do that in high fidelity without killing the battery?" It is the night-shore look parked under Open Sea in [ideas.md](ideas.md) ("A night shore with glowing surf could be one of its looks"). That day two agents researched it and one round of mock-ups was drawn. Nothing is built.

- **Source:** none yet.
- **Data:** none yet. Candidates: Open-Meteo's Marine API for the live swell at a named bloom beach (CC BY 4.0, tested), the app's real stars and Moon, and Poly Haven's CC0 Fish Hoek Beach for a backdrop ([research-look.md](sea-sparkle/research-look.md) §4).
- **Research:** [the method](sea-sparkle/research-method.md) (surf and light in numbers, how to draw it, cost measured with a SpriteKit probe, which battery levers apply) and [the look](sea-sparkle/research-look.md) (the real thing in photos and footage, palettes, brightness, photos and feeds, names). Every figure in them is marked checked or unchecked.
- **Scripts:** `sea-sparkle/mock.swift` draws the mock-ups with SpriteKit as the app would; `sheet.py` lays out the sheets and films from the variants in `variants.py`.
- **Where it stands (2026-11-07):** round 1 of mock-ups is with Dave.

## Names and look-alikes
- **Sea Sparkle** is the name proposed: the common name of *Noctiluca scintillans*, used by the news for glowing seas, and as plain as Fireflies. Strictly it names *Noctiluca*, not San Diego's *Lingulodinium*. An iPad sightings app, "Sea Sparkle: Bioluminescence", uses it; no SEA SPARKLE trademark was found, checked only through third-party mirrors. **Glowing Surf** is the fallback.
- **Avoid:** "Sea of Stars" (a 2023 game, and beside Apple's "Sea Stars" aerial), "Glowing Tide" (an existing screensaver of this subject), "Blue Tide" (Tide detergent; BLOO TIDE is registered for surfboards), "Night Surf" (a Stephen King story), "Red Tide" (a harmful bloom), "Blue Tears" (Matsu's tourism name).
- **Every stock "bioluminescent beach" live wallpaper** is neon and pulses with the waves. This one has to be dim, real and never repeating.
- **Beside Jellyfish:** both glow blue. This one's light sits about 10–15° of hue greener (cyan against Jellyfish's sapphire), and falls in bands and lace on a beach under a sky rather than in points on black ([research-look.md](sea-sparkle/research-look.md) §2). Agree the split with Jellyfish before either ships.

## Mock-ups, round 1 (2026-11-07)
Drawn by `mock.swift` through SKRenderer, as the render test draws a wallpaper, so a tile shows what the app's shaders can draw. The method is the research's (§3, A): a level camera; each pixel below the horizon meets the sea or the sand; each wave's crest moves in at √(g h) over a plane beach, breaks where its height reaches 0.78 of the depth (furthest out at its peak, so the break peels along the crest), and becomes a bore of glowing foam that shrinks as it comes in and leaves a fading trail. Then its swash runs up the sand and back. On top of the research's probe the mock adds:
- each wave's face, its foam pile and a soft halo of spray over a breaking crest;
- the glow mirrored in the sea and in wet sand;
- billows and lace from Weather's baked `CloudNoise`, copied, so the build can share the texture.

The waves come from a seeded train with sets (bigger waves about every seven), each with its own peak along the shore. Colours are the look research's samples. Desktop tiles are a 14-inch display at 2x, scaled down.

```sh
cd docs/sea-sparkle && swiftc -O mock.swift -o $TMPDIR/sea-mock
python3 sheet.py sheet1-view .   # or sheet2-light … sheet7-desk, film1-long, film2-bluff
```

Each question, with my recommendation:

1. **Where we stand** ([sheet1-view.jpg](sea-sparkle/sheet1-view.jpg)). A, from a bluff 12 m up; B, at the water's edge; C, from the beach with a long lens, the photographers' view (Seal Beach, Olson's San Diego); D, looking along the beach. The view decides the battery: see the motion table below. **Recommended:** C as the standard, since it looks most like the real photos, with the other three as a View menu. A is the one that can also be capped at 20 fps on battery.
2. **How the light shows** ([sheet2-light.jpg](sea-sparkle/sheet2-light.jpg)). A, as video shows it: sheets of cyan. B, as the eye sees it: paler and dimmer. C, as a long exposure: waves smoothed to mist and a lifted sky. D, *Noctiluca*: the light broken into points, as every *Noctiluca* photo shows it. **Recommended:** A as the standard, and D as a Kind setting (Sheets or Points), since the two organisms really do look different. B reads as dull, and C is brighter than the caps (median 57).
3. **The surf** ([sheet3-surf.jpg](sea-sparkle/sheet3-surf.jpg)): small spilling waves (0.6 m), moderate (1.3 m), big sets (2.2 m), and plunging waves on a steeper beach. **Recommended:** Live by default, the real swell at a real bloom beach from Open-Meteo, moving between A and C, with Calm, Moderate and Big to hold it. Each load rolls a gentle or a steep beach, so both spilling and plunging waves turn up.
4. **The colour** ([sheet4-colour.jpg](sea-sparkle/sheet4-colour.jpg)): Cyan as footage shows it, Azure nearest the eye's "electric blue", Teal as the Wadden Sea photos show it. **Recommended:** Cyan as the standard and Azure as an option. Teal puts a green glow under a blue sky, Lava Lamp's mistake.
5. **The sky** ([sheet5-sky.jpg](sea-sparkle/sheet5-sky.jpg)): no Moon; a half Moon; a full Moon, honestly lifting sky, sea and sand while the glow stays as it is; a headland with a town's lights. The Moon is drawn at its real size, half a degree. **Recommended:** tonight's real Moon by default, real over made up, with None as a choice. The headland comes with the place, and the town's warm lights go behind a switch, since they're another colour family.
6. **The motion** ([sheet6-motion.jpg](sea-sparkle/sheet6-motion.jpg), [film1-long.mp4](sea-sparkle/film1-long.mp4), [film2-bluff.mp4](sea-sparkle/film2-bluff.mp4)): one wave frame by frame, then 12 s at the real pace from the long lens and from the bluff. **Recommended:** the real pace as 1× on a Speed slider.

[sheet7-desk.jpg](sea-sparkle/sheet7-desk.jpg) is C at full size under a menu bar and desktop folders.

## What the mock-ups showed
- **Brightness at desktop size**, the brightest of R, G and B out of 255. The look research's caps are 8–20 for the frame median, 150 for the broad glow and 190 for points:

  | Tile | median | 99th | 99.9th | max |
  |---|---|---|---|---|
  | View A, bluff | 23 | 85 | 138 | 206 |
  | View B, water's edge | 28 | 103 | 156 | 204 |
  | View C, long lens | 31 | 135 | 162 | 209 |
  | View D, along the beach | 28 | 94 | 149 | 204 |
  | Light B, as the eye | 23 | 86 | 111 | 199 |
  | Light C, long exposure | 57 | 147 | 164 | 237 |
  | Light D, points | 29 | 182 | 199 | 209 |
  | Surf C, big sets | 35 | 157 | 189 | 212 |
  | Sky C, full Moon | 54 | 132 | 188 | 255 |

  The medians sit above the research's 8–20 because the research's own sky colour (#050d1c) reaches 28 and fills a third of the frame. The glow keeps to the caps except at a few points (the maxima are sparkles on the sand and the full Moon's disc).
- **Cost:** the mock's shader takes **1.5–1.9 ms of GPU** at 3024×1964 (bluff 1.89, long lens 1.71, water's edge and along 1.48), against Nebula's 1.47 on the same probe. That's three times the research's probe, which drew no faces, halo or reflections. At half resolution, which is what Settings → Power's lighter drawing on battery would use, it takes **0.46–0.50 ms**. The build's first job is to bring the full-resolution figure down: skip each wave where it can't reach the pixel (the research measured that), and find each crest in one pass instead of two.
- **The fastest motion on screen** decides the frame rate on battery: about 2 device pixels a frame or less looks the same as 30 fps. Device pixels a frame at 30 / 20 fps, for a 1.3 m swell on a gentle beach (worked out from the model):

  | View | bore at the break | bore near the shore | swash | the break running along the crest (8 m/s) |
  |---|---|---|---|---|
  | A, bluff | 0.6 / 0.9 | 1.3 / 1.9 | 4.1 / 6.2 | 7.4 / 11.1 |
  | B, water's edge | 0.2 / 0.2 | 0.6 / 1.0 | 12.5 / 18.8 | 9.4 / 14.0 |
  | C, long lens | 0.4 / 0.6 | 1.2 / 1.8 | 6.2 / 9.4 | 22.6 / 33.9 |
  | D, along the beach | 0.1 / 0.1 | 0.3 / 0.4 | 2.9 / 4.4 | 7.8 / 11.8 |

  The bores themselves move slowly in every view. What moves fast is the swash and the break running along the crest, and both are soft brightness fronts, not objects. So a cap of 20 is worth a side-by-side for A and D, and not for B or C.
- **One wave on a gentle beach takes about 25 s** from breaking to the sand, so two or three bores are in at once, as the method research said. With the glow fading as measured (56% within 2.8 s of its peak), the older bores went dark and only one line glowed. The mock keeps a third of the light while a bore still churns. That tail is my reading of the footage, not a measurement, and it should be a setting.
- **Flaws to fix in a build or the next round:**
  - From the long lens the ends of a breaking section still read as a box: a lit block beside darker shoulders.
  - At full size the foam reads a little like marble. Its billows need to be smaller and rounder.
  - The Moon at its real size is a speck on a 14-inch display.
  - The along-the-beach view's dry sand is a flat colour.

## Still open
- Dave's picks for the six questions above.
- The name.
- Whether the backdrop is drawn (as here) or a relit photo: Poly Haven's CC0 Fish Hoek Beach has the headlands and a town ([research-look.md](sea-sparkle/research-look.md) §4).
- Whether a mostly black picture saves backlight power on mini-LED MacBook Pros: unmeasured, and the method research gives a way to measure it (§5).

## Sources
The two research reports, [research-method.md](sea-sparkle/research-method.md) and [research-look.md](sea-sparkle/research-look.md), carry every source and its licence.
