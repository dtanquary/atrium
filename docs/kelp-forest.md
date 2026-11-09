# Kelp Forest

A forest of giant kelp seen from inside it: rope-thin stipes rising in clumps from their holdfasts into blue-green haze, a blade on a gas float every few centimetres up each one, shafts of sunlight coming down through the canopy, and the whole forest swaying together in the swell, dragged by the water rather than springing back. Real species at their real sizes, in water whose colours are sampled from real photos.

Dave asked for it on 2026-11-08 by running the new-wallpaper process: "underwater kelp, start with mockups and come up with a high fidelity design for me and we go from there". A Kelp Forest tank was next in line for the Fish Tank on 2026-10-07 and was dropped with that day's photo cut-outs of big animals ([fish-tank.md](fish-tank.md)); Jellyfish has since shown that shader-drawn water and bodies can work. Two agents researched it that day and one round of mock-ups was drawn. Nothing is built.

- **Source:** none yet.
- **Data:** none yet. The build would want 4 to 8 freely licensed photos of single giant kelp blades with their floats, to cut out as cards (research-method.md §6); none have been looked for.
- **Research:** [the method](kelp-forest/research-method.md) (the plant, the forest, the water and the light in numbers; how kelp moves in swell, surge and current; how to draw it, with costs measured by a SpriteKit probe) and [the look](kelp-forest/research-look.md) (what the eye sees, the views, palettes sampled from real photos, brightness caps, feeds and licences, names). Every figure in them is marked checked or unchecked.
- **Scripts:** `kelp-forest/mock.swift` draws the mock-ups with SpriteKit as the app would; `sheet.py` lays out the sheets and films from the variants in `variants.py`, and `python3 sheet.py stats <sheet>` measures each tile's brightness at desktop size.
- **Where it stands (2026-11-08):** round 1 of mock-ups waits for Dave's picks.

## Names and look-alikes
- **Kelp Forest** is the name proposed: the habitat's plain name, like Fish Tank and Jellyfish. It is also Monterey Bay Aquarium's exhibit name, a descriptive use; no US trademark for it turned up (third-party mirrors only, [research-look.md](kelp-forest/research-look.md) §6). Avoid "Seaforest", Sea Change Project's coinage for the Cape's kelp.
- **Every Mac already has filmed kelp,** in Apple's California Kelp Forest and Kelp Dark aerials. This one has to be what film can't: never repeating, a new forest each load, following the real Sun and Light and Dark Mode, tunable.

## Mock-ups, round 1 (2026-11-08)
Drawn by `mock.swift` through SKRenderer, as the render test draws a wallpaper. The world is in metres: a floor 8.5 to 12 m down, a camera 60–64° across. A full-screen shader draws the water (fogged by colour with distance, brighter looking up), the underside of the surface with Snell's window and the canopy lying on it, the floor with soft caustics, and shafts of sunlight fanning out from the Sun where the canopy lets it through. Each frond is a sprite whose shader hangs its blades along a spine of eight points: each blade on a short stalk with its float, at its own bearing round the stipe, twisting as a ribbon does, streaming with the water past it and fluttering by centimetres; few, small worn blades low down and a dense ruff high up, as research-method.md §1 has it.

**The motion is the research's model**, not a sine: each frond is a chain of 14 buoyant links from its holdfast, dragged toward the water's velocity as |u − v|^0.6 (u − v), with links that don't stretch, stepped at 60 Hz and run 150 s before the first frame so the forest has settled. The water is five swell components in a narrow band round a 12 s peak (so it comes in sets and never repeats), a slow surge of 100 to 160 s under them, and a weak current that wanders over minutes. A frond rights itself over most of a minute, as the literature's estimate of 27 to 58 s says; it never springs back.

Colours are the look research's samples of real photos, and each tile is held to its brightness caps (Light Mode: median 90 to 140, 99th percentile up to 210, 99.9th up to 230; Dark Mode: median 25 to 45) by an exposure on the brighter views. Desktop tiles are a 14-inch display at 2x, scaled down.

```sh
cd docs/kelp-forest && swiftc -O mock.swift -o $TMPDIR/kelp-mock
python3 sheet.py sheet1-view .   # or sheet2-water, sheet3-kelp, sheet5-desk, film1-level, film2-up, film3-bull
```

Each question, with my recommendation:

1. **Where we look from** ([sheet1-view.jpg](kelp-forest/sheet1-view.jpg)). A, level through the forest into the haze; B, tipped up 30° toward the light, with shafts between the stipes; C, looking up into the canopy and the Sun; D, just under the canopy; E, an aquarium's kelp tank through its window, after Monterey Bay Aquarium's; F, low among the holdfasts on sunlit sand. **Recommended:** between A and B, tipped up 20°, as the standard, with a Tilt setting from A up to C, since both research reports put the level view first for calm and the looking-up view as the drama. F as a pick of its own. Not D: everything near is big, so it needs photo blades the mock-up doesn't have, and it reads drawn. E only if Dave wants a tank, as Fish Tank already is one.
2. **The water and the light** ([sheet2-water.jpg](kelp-forest/sheet2-water.jpg)), each sampled from a real photo: A, the Channel Islands' sunlit teal with olive-gold kelp; B, the same all teal, the kelp taking the water's colour; C, overcast, after a photo of bull kelp; D, golden and backlit (Patagonia); E, Monterey green; F, dusk, deep blue (Cape Town). **Recommended:** A in Light Mode and F in Dark Mode, one forest whose light changes, as Jellyfish's lit tank and glow share their animals; C and D in a Look menu. B only if the gold reads as a clash (Lava Lamp's green-in-blue); the gold here is held to the nearest sunlit blades. E is the palest and least like the others.
3. **Which kelp** ([sheet3-kelp.jpg](kelp-forest/sheet3-kelp.jpg)): A, giant kelp, many fronds from one holdfast; B, bull kelp, one stipe to a float and its tuft of blades; C, a forest's edge with bull kelp among giant kelp, as at exposed edges in California; D, bull kelp looking up. **Recommended:** giant kelp as the subject, with bull kelp as a pick: its floats against the light are the strongest silhouette here, and it's cheaper to draw.
4. **The motion** ([film1-level.mp4](kelp-forest/film1-level.mp4), [film2-up.mp4](kelp-forest/film2-up.mp4), [film3-bull.mp4](kelp-forest/film3-bull.mp4)): 20 s of each at the real pace, a 1 m swell at 12 s. The research's worst risk is motion that reads fake, which is how the Fish Tank's big animals died. Judge it before the look: does the forest sway as one but ripple across, slack and dragged, and do the blades stream and flutter rather than flap? **Recommended:** the real pace, with Swell and Speed settings; whether the swell follows a real kelp forest's live sea (Open-Meteo's marine feed, CC BY 4.0) is for later.

[sheet5-desk.jpg](kelp-forest/sheet5-desk.jpg) is the recommended design at full size under a menu bar and desktop folders: tipped up 20°, between A and B, in the Channel Islands' water (median 134, 99th percentile 180, max 204).

## What the mock-ups showed
- **Brightness at desktop size**, the brightest of R, G and B out of 255 (median, 99th, 99.9th percentile, max), against the look research's caps:

  | Tile | median | 99th | 99.9th | max |
  |---|---|---|---|---|
  | View A, level | 133 | 182 | 192 | 210 |
  | View B, tipped up 30° (exposure 0.6) | 131 | 185 | 195 | 203 |
  | View C, looking up (exposure 0.42) | 130 | 183 | 187 | 239 |
  | View D, under the canopy | 123 | 135 | 141 | 169 |
  | View E, the aquarium | 110 | 149 | 155 | 169 |
  | View F, the holdfasts | 129 | 178 | 194 | 212 |
  | Water B, all teal | 100 | 180 | 190 | 212 |
  | Water C, overcast | 129 | 183 | 191 | 223 |
  | Water D, golden | 99 | 162 | 170 | 185 |
  | Water E, Monterey green | 130 | 208 | 217 | 255 |
  | Water F, dusk (exposure 0.4) | 48 | 74 | 77 | 80 |

  Looking up came out at a median of 192 and a 99th percentile of 255 before its exposure was cut to 0.42. Held to the caps, the window goes grey and most of the view's drama with it: the research's warning that the brightest view fights "soft and dim" holds. Dusk sits a little over Dark Mode's median of 25 to 45.
- **The gold is small.** At the level view's distances the water takes the kelp's colour within a few metres, so only the nearest blades read gold, as the look research predicted. The forest stays in one teal family; the price is that the kelp's own colour is mostly hidden.
- **Drawn blades read as drawn up close.** At 5 m and more the procedural blades pass; nearer (views C, D and E) they are flat, even shapes. The method research's photo cards of real blades are the fix in a build.
- **A level view with too many plants is a tangle of grass**, not a forest. Ten clumps of 6 to 16 fronds, the nearest 6 m off, keep open water between them; fewer reads as bars.
- **An anchored camera sees the whole swell.** The water moves as one column, ±0.7 to 1 m on an ordinary day, and the kelp with it, so from a camera fixed to the floor the nearest plant swings a large part of the screen each way every 12 s ([film2-up.mp4](kelp-forest/film2-up.mp4) most of all). A diver is carried by the same swell and sees the forest nearly still, with a slow parallax between near and far. A camera carried part of the way with the water would be calmer and truer to dive footage; it is a question for round 2, judged in films.
- **Cost:** the mock-up's per-pixel blades take hundreds of milliseconds of GPU a frame (the method research timed an early copy at about 360 ms), fine for pictures. The build would port its look, not its method: the hybrid the method research measured at about 1.2 ms of GPU and 0.55 to 0.75 ms of CPU (research-method.md §3, §5).

## Still open
- Dave's picks for the four questions above.
- Whether the camera stays fixed or is carried part of the way with the swell, as a diver is (What the mock-ups showed).
- Photo cards of single blades: none found yet, and the near tier needs them.
- Fish: a mid-distance school of blacksmith fits the colours (research-method.md §3); not in round 1.
- No `batteryRate`: a near stipe moves far over 2 device pixels a frame at 20 fps, so only a `batteryScale` on the water and far forest saves battery (research-method.md §5).

## Sources
The two research reports, [research-method.md](kelp-forest/research-method.md) and [research-look.md](kelp-forest/research-look.md), carry every source and its licence.
