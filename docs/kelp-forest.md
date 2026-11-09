# Kelp Forest

A forest of giant kelp seen from inside it: rope-thin stipes rising in clumps from their holdfasts into blue-green haze, a blade on a gas float every few centimetres up each one, shafts of sunlight coming down through the canopy, and the whole forest swaying together in the swell, dragged by the water rather than springing back. Real species at their real sizes, in water whose colours are sampled from real photos.

Dave asked for it on 2026-11-08 by running the new-wallpaper process: "underwater kelp, start with mockups and come up with a high fidelity design for me and we go from there". A Kelp Forest tank was next in line for the Fish Tank on 2026-10-07 and was dropped with that day's photo cut-outs of big animals ([fish-tank.md](fish-tank.md)); Jellyfish has since shown that shader-drawn water and bodies can work. Two agents researched it that day and two rounds of mock-ups were drawn; Dave chose from them the same evening, and the build began hidden behind the `unfinished` switch.

- **Source:** `Sources/Atrium/KelpForest.swift` (being built).
- **Data:** none. Blade cards are drawn at load; two freely licensed photos of real blades are candidates for photo cards later (Still open).
- **Research:** [the method](kelp-forest/research-method.md) (the plant, the forest, the water and the light in numbers; how kelp moves in swell, surge and current; how to draw it, with costs measured by a SpriteKit probe) and [the look](kelp-forest/research-look.md) (what the eye sees, the views, palettes sampled from real photos, brightness caps, feeds and licences, names). Every figure in them is marked checked or unchecked.
- **Scripts:** `kelp-forest/mock.swift` draws the mock-ups with SpriteKit as the app would; `sheet.py` lays out the sheets and films from the variants in `variants.py`, and `python3 sheet.py stats <sheet>` measures each tile's brightness at desktop size.
- **Where it stands (2026-11-08):** Dave has chosen from both rounds; the build has begun, hidden behind the `unfinished` switch.

## Names and look-alikes
- **Kelp Forest** is the name proposed: the habitat's plain name, like Fish Tank and Jellyfish. It is also Monterey Bay Aquarium's exhibit name, a descriptive use; no US trademark for it turned up (third-party mirrors only, [research-look.md](kelp-forest/research-look.md) §6). Avoid "Seaforest", Sea Change Project's coinage for the Cape's kelp.
- **Every Mac already has filmed kelp,** in Apple's California Kelp Forest and Kelp Dark aerials. This one has to be what film can't: never repeating, a new forest each load, following the real Sun and Light and Dark Mode, tunable.

## Dave's decisions (2026-11-08)
- **Giant kelp, in two views:** of round 1's films, "film1-level and film2-up look awesome, film3-bull was meh, lets focus on the first two". So level through the forest (tipped up 20°, the recommended design) and looking up into the canopy are both views; bull kelp, the mixed edge, the aquarium, just under the canopy and among the holdfasts are set aside.
- **Every light round 2 showed:** "all of your previews look awesome, A, B, C, D, E, F all great, and film 5 level dusk also looks awesome". So the Channel Islands' teal, golden and dusk are all picks in both views, with the teal following Light Mode and dusk Dark Mode as the standard, as recommended. Then, while the build began: "and as with other wallpapers, allow both following of system theme as well as following of day / night cycle". So the Look menu has, as Jellyfish's has, the light look following Light Mode or the day where you are (the Sun), dusk following Dark Mode or the night, and each look on its own; following Light and Dark Mode is the standard.
- **The motion as the research models it:** each frond a chain dragged through a sea of swell, slow surge and current, as both films he liked showed it. The camera stays fixed to the floor (a carried one measured no calmer, Mock-ups round 2).

Still his to decide, once it runs on his desktop: the density, the swell's strength and pace, and whether the swell should follow a real kelp forest's live sea (Open-Meteo's marine feed, CC BY 4.0).

## What the real thing looks like
From the two research reports, cut to what the build uses:
- **Giant kelp** (*Macrocystis pyrifera*): clumps of 10–50 rope-thin stipes (about 0.5–1 cm) from a holdfast of root-like strands 10–50 cm across, plants 3–7 m apart in a deep forest; the longest frond about 1.4 × the depth − 0.8 m, its last quarter lying on the surface. A blade every 4–16 cm, 30–150 cm long and 5–15 cm wide, ridged across and toothed along its edge, each on a pear-shaped float 4–12 × 1–4 cm; few, small, worn blades low down and a dense ruff high up.
- **The water:** green-teal coastal water with 8–12 m visibility; red is gone within a few metres, so only the nearest sunlit blades keep their gold and the rest take the water's colour.
- **The light:** shafts made by the waves and the canopy's gaps, parallel in the water and so fanning from the Sun on screen; Snell's window 97° across overhead, dark mirror outside it; soft caustics on the floor.
- **The motion:** the water moves nearly as one column, ±0.7–1 m on an ordinary day at 9–16 s, with a slower surge of 1–3 minutes and a current that wanders over minutes. A frond is dragged, not sprung: it rights itself over most of a minute. Blades stream with the water's speed past them and flutter by centimetres.

## How it works
The plan. The mock-up drew every blade per pixel, at hundreds of milliseconds a frame; the build keeps its look and its motion but draws each blade once, as a sprite, which the method research measured at about 1 ms of GPU and under 1 ms of CPU for several hundred (research-method.md §3).

1. **The water**, one full-screen shader ported from the mock-up: fog by colour along each line of sight, brighter looking up and toward the Sun; the floor with one soft layer of caustics; the underside of the surface with Snell's window and the canopy; shafts of light where the canopy is open. The canopy is baked once at load into a small tiling texture rather than worked out with noise per pixel.
2. **The sea** on the CPU, as the mock-up's: five swell components, a slow surge and a wandering current, with their phases in Double.
3. **The forest**, a new one each load (seeded by `kelp.seed` for pictures): plants in clumps, each a holdfast and its fronds, every frond a chain of 14 buoyant links stepped at 60 Hz, run for a while at load so it has settled.
4. **Near fronds** (the nearest few plants): each stipe drawn as thin sprites between its chain's points, and each blade a sprite of one of a few blade cards drawn at load (outline, float, ridges and teeth, as the mock-up's), posed every frame from its chain: its place, its angle from the water's flow past it, and its foreshortening. A shared shader colours the cards by the look (lit from the front, or glowing with the light through them), twists and ripples each blade within its card, and fogs it by distance.
5. **Far fronds**: each segment of a frond a single card with its blades drawn in, bent and swayed by the same chain. Far off, a blade streaming on its own can't be seen.
6. **Light and Dark Mode** change only the light (the look's colours, uniforms on every shader), so the forest stays as it is.

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

## Mock-ups, round 2 (2026-11-08)
Giant kelp only, in the two views Dave liked in round 1's films: level through the forest (tipped up 20°, the recommended design) and looking up into the canopy. Near blades now carry the ridges across them and the toothed margins of a real blade, from two photos found for the build's cards (Still open), and stipes are darker than their blades, and the canopy on the surface moves with the water rather than against it, which round 1 had backwards.

1. **The light, in both views** ([round2-light.jpg](kelp-forest/round2-light.jpg)): the Channel Islands' teal (Light Mode), golden, and dusk (Dark Mode), each held to its caps. **Recommended:** Channel Islands by day and dusk in Dark Mode, as one forest whose light changes; golden as a pick.
2. **Dark Mode in motion** ([film5-level-dusk.mp4](kelp-forest/film5-level-dusk.mp4)): the level view at dusk, 20 s. The dusk water is clearer than round 1's, so the fronds stay silhouettes against it, as in the Cape Town photo, rather than sinking into it.

**The camera carried with the swell made no difference**, so it isn't a question. Round 1 suggested that a camera carried part of the way with the water, as a diver is, would calm the near plants. Rendered at 80% of the water's motion and measured as the mean change of each pixel from one frame to the next, the looking-up film moved 0.83 against 0.86 fixed to the floor (95th percentile 1.20 against 1.16). What moves on screen is the fronds' own streaming and turning blades, not the swell carrying the plants. `carry` stays in mock.swift; its film isn't committed. The level film moves 0.34 a frame, the looking-up one 0.86: the near plants in the looking-up view are 4 m off where the level view's are 6 m.

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
- **An anchored camera sees the whole swell.** The water moves as one column, ±0.7 to 1 m on an ordinary day, and the kelp with it, so from a camera fixed to the floor the nearest plant swings a large part of the screen each way every 12 s ([film2-up.mp4](kelp-forest/film2-up.mp4) most of all). A diver is carried by the same swell and sees the forest nearly still, with a slow parallax between near and far. Round 2 tried a camera carried with the water, and it was no calmer (Mock-ups, round 2).
- **Cost:** the mock-up's per-pixel blades take hundreds of milliseconds of GPU a frame (the method research timed an early copy at about 360 ms), fine for pictures. The build would port its look, not its method: the hybrid the method research measured at about 1.2 ms of GPU and 0.55 to 0.75 ms of CPU (research-method.md §3, §5).

## Dave's feedback
- **2026-11-08, on round 1's films:** "film1-level and film2-up look awesome, film3-bull was meh, lets focus on the first two". So giant kelp, seen level through the forest and looking up into the canopy; bull kelp and the mixed edge are set aside.
- **2026-11-08, on round 2:** "all of your previews look awesome, A, B, C, D, E, F all great, and film 5 level dusk also looks awesome". Every light in both views is a pick.

## Still open
- Photo cards of single blades for the near tier. Two candidates found on Wikimedia Commons, licences read from Commons' own field (checked): *Giant Kelp - Macrocystis pyrifera (43168362051).jpg* (CC BY-SA 2.0), a close-up of a blade's ridges and toothed edge in air; *CAS Macrocystis 1.JPG* (CC BY-SA 3.0, EncycloPetey), whole blades backlit in the California Academy of Sciences' tank. Neither is cut out yet; the public-domain *Giantkelp2 300.jpg* shows fronds with their floats from above.
- Fish: a mid-distance school of blacksmith fits the colours (research-method.md §3); not in round 1.
- No `batteryRate`: a near stipe moves far over 2 device pixels a frame at 20 fps, so only a `batteryScale` on the water and far forest saves battery (research-method.md §5).

## Sources
The two research reports, [research-method.md](kelp-forest/research-method.md) and [research-look.md](kelp-forest/research-look.md), carry every source and its licence.
