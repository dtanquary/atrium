# Jellyfish

Jellyfish drifting and pulsing in dark water, drawn by shaders rather than cut out of photos: real species at their real sizes and pace, lit by a dim lamp, or glowing with their own light only as the real ones do. Every bell squeezes quickly, re-opens slowly and coasts, with its margin lagging behind. Its tentacles trail from where the margin was a moment ago, so a squeeze or a turn runs down them.

It began in [ideas.md](ideas.md) under "Left out on purpose": "Photo cut-outs of big animals never moved convincingly in the Fish Tank's Ocean Voyager and Shallow Reef ... Jellyfish would have to be drawn by a shader, not cut out, to be worth another try." Dave ran it through the new-wallpaper process on 2026-11-07, as "A shader-drawn bell on black, dim and bioluminescent, is the version worth a mock-up." That day two agents researched it and one round of mock-ups was drawn. Nothing is built.

- **Source:** none yet.
- **Data:** none. Everything is drawn; reference photos stay references.
- **Research:** [the method](jellyfish/research-method.md) (swimming numbers, bioluminescence, how to draw it, cost measured with a SpriteKit probe) and [the look](jellyfish/research-look.md) (species, palettes, brightness, names). Every figure in them is marked checked or unchecked.
- **Scripts:** `jellyfish/mock.swift` draws the mock-ups with SpriteKit as the app would; `sheet.py` lays out the sheets and films from the variants in `variants.py`.
- **Where it stands (2026-11-07):** round 1 of mock-ups waits for Dave's picks.

## Names and look-alikes
- **Jellyfish** is the name proposed: plain, like Fireflies. "Jellies" sits beside Apple's own Palau Jellies and Alaskan Jellies aerials, and "Deep Sea" is too near Space Tour's deep space. JELLYFISH is registered in the US for unrelated goods only, checked through third-party mirrors ([research-look.md](jellyfish/research-look.md) §6).
- **Every Mac already has filmed jellies,** in those aerials. This one has to be what film can't: deep species, their own light, never repeating, tunable.

## Mock-ups, round 1 (2026-11-07)
Drawn by `mock.swift` through SKRenderer, as the render test draws a wallpaper, so a tile shows what the app's shaders can draw. Each jelly is one sprite with a shared shader, as the method research recommends. The bell is marched through in 40 steps, so its rim is bright where the line of sight grazes the tissue, not painted on. The pulse, the lagging margin, the delayed-follow tentacles and oral arms, and the turns made only while squeezing all follow research-method.md §1. Jellies are simulated in metres at their real sizes and seen through a camera 50° across, set back as far as the animals are big. Desktop tiles are a 14-inch display at 2x, scaled down.

```sh
cd docs/jellyfish && swiftc -O mock.swift -o $TMPDIR/jelly-mock
python3 sheet.py sheet1-light .   # or sheet2-species, sheet3-crowd, sheet4-motion, sheet5-desk, film1-deep, film2-pulse
```

Each question, with my recommendation:

1. **What light shows them** ([sheet1-light.jpg](jellyfish/sheet1-light.jpg)). A, Into the Deep: a dim lamp on deep red Periphylla, Atolla and a comb jelly on black, after Monterey Bay Aquarium's gallery. B, an ROV's lights: near ones bright, far ones gone, lit marine snow. C, lights off: only their own light, which real jellies make only when touched, so the screen is mostly black. D, crystal jellies under blue light, their fluorescent green ring always on. E, the jelly gallery's lit blue tank of moon jellies. F, a steady blue glow, which no jelly makes. **Recommended:** A as the standard, E as its Light Mode, and B, C and D as a Look menu. F only if Dave wants it knowing it's made up.
2. **Which animals** ([sheet2-species.jpg](jellyfish/sheet2-species.jpg)): moon jelly, Pacific sea nettle, crystal jelly, crown jelly (Atolla), helmet jelly (Periphylla), lobed comb jelly. **Recommended:** each look keeps the animals that really live together: the deep ones in A, B and C, crystal jellies in D, moon jellies and sea nettles in E.
3. **How many, and how near** ([sheet3-crowd.jpg](jellyfish/sheet3-crowd.jpg)): four; ten near, middle and far; one up close; a bloom of thirty helmet jellies, as Norway's Lurefjorden has. **Recommended:** ten as standard, with a slider up to the bloom.
4. **The motion** ([sheet4-motion.jpg](jellyfish/sheet4-motion.jpg), [film1-deep.mp4](jellyfish/film1-deep.mp4), [film2-pulse.mp4](jellyfish/film2-pulse.mp4)): a moon jelly's pulse, a sea nettle's turn, and 12 s of each at the real pace. The research's biggest risk is motion that still reads fake, and its third is the real 0.4 s squeeze feeling twitchy. Judge both from the films. **Recommended:** the real pace as 1× on a Speed slider.

[sheet5-desk.jpg](jellyfish/sheet5-desk.jpg) is A at full size under a menu bar and desktop folders.

## What the mock-ups showed
- **Deep jellies are small.** At 6 to 15 cm, a camera 1 to 6 m off made them specks. The camera is now set back by the animals' size: about 45 cm to 4 m for the deep set, and half as far again for moon jellies.
- **At the real pace they leave.** In the model a 15 cm helmet jelly climbs about 19 cm in 20 s, off the top of the view. A build needs them to come back in, or, for a tank, what aquariums do: a kreisel's slow circular current, which keeps jellies off the walls and in front of the glass.
- **A turning jelly's sprite must widen.** For a few seconds after a turn its far tentacles still hang the old way, outside a box sized for a straight jelly. The mock widens the box by the sine of the turn.
- **Brightness at desktop size**, the brightest of R, G and B out of 255, against the look research's caps (backdrop to 8, broad light to 150, pinpoints to 190):

  | Look | median | 99th pct | 99.9th | max |
  |---|---|---|---|---|
  | A, Into the Deep | 3 | 64 | 94 | 104 |
  | B, ROV lights | 0 | 104 | 135 | 177 |
  | C, lights off | 0 | 34 | 77 | 125 |
  | D, crystal jellies | 6 | 71 | 135 | 157 |
  | E, lit blue tank | 144 | 222 | 255 | 255 |
  | F, steady glow | 0 | 44 | 79 | 151 |

  E is a Light Mode scene and bright on purpose, but jellies clip to white where they overlap on the blue.
- **Not measured:** the mock's cost. It loops over every tentacle and marches 40 steps, where the method's probe measured 0.45 to 0.75 ms of GPU for ten jellies with 24 steps and only the nearest tentacles looked up.

## Still open
- Dave's picks for the four questions above.
- The comb jelly is the weakest drawing: its rows read as dots at a distance.
- The moon jelly's four gonads read as a cross seen side-on; seen from above they'd be its four rings.
- Whether "bioluminescent" in the brief means C (true and mostly black) or F (made up and lovely).

## Sources
The two research reports, [research-method.md](jellyfish/research-method.md) and [research-look.md](jellyfish/research-look.md), carry every source and its licence.
