# Peg Board

A black sheet of holes, edge to edge, with coloured translucent pegs pushed through it one at a time and lit from behind. It shows one thing after another: a snow crystal grown from the middle, or a picture built outline first; each, once whole, under a slow light show; then the sheet goes dark and is cleared for the next.

It imitates Lite-Brite, the peg-light toy Hasbro first sold in 1967. That name is a registered mark and is used nowhere in the app: see [Rights](#rights).

Dave asked for a clone of it on 2026-10-12, "with lights, showing various lighting patterns and what not"; it was researched and mocked up that day, and he chose from the sheets ([Dave's decisions](#daves-decisions-2026-10-12)). It was built the same day in three steps and is flagged `unfinished`: hidden until he has tried it.

- **Source:** `Sources/Atrium/PegBoard.swift` (the scene and its one shader), `Sources/PegLattice/` (the lattice, the crystal, the glow, the charts and the order pegs go in; its own module, built with `-O`).
- **Data:** `Resources/peg-board-charts.txt` (the pictures, cut down to pegs) and `Resources/peg-board-credits.tsv`.
- **Scripts:** `docs/peg-board/cut.py` cuts the charts from their sources; `docs/peg-board/bench.swift` is the timing sketch the shader was tried in before the build ([Cost](#cost)).
- **Pictures of it:** `docs/images/peg-board.jpg`, `peg-board-wave.jpg`; and in `docs/peg-board/`, every picture as the app draws it at each size (`pictures-large.jpg`, `pictures-medium.jpg`, `pictures-small.jpg`), one whole round (`round.jpg`) and the Softness slider (`softness.jpg`).

## Dave's decisions (2026-10-12)

| Question | His pick |
|---|---|
| Name | Peg Board |
| What it shows | all three kinds he was offered, in rotation: pictures built peg by peg from an empty sheet; patterns that grow ("symmetric designs made fresh each time, growing outward"); slow light shows on a finished board, nothing flashing. With a setting: everything, patterns only, pictures only |
| The toy on screen | the sheet alone, edge to edge. He asked to see a light box round it too; mocked up, it read as a tablet's bezel and held only the toy's 1,735 holes, and he chose no box |
| Peg look | "A slider, crisp by default": the measured plastic peg, with Softness down to a glowing disc |
| Peg size | "A slider", settled as three fixed sizes (the toy's own, half, a third; half the default), each picture cut and checked by eye at each, and left out at a size where it does not read |
| Colours | a calmer set by default, the set measured from the real pegs as a second palette |
| Pictures | "nothing religious"; asked whether that covers a sun god on a lace chart or Neptune on a map: "Myth is fine". Only public-domain, CC0, CC BY or CC BY-SA sources; never the toy's own template sheets |

The lead's calls, which he has not ruled on: a Speed slider; the lean shader; three bytes for a peg's place; a fresh start on each load.

## What the real toy looks like

Researched on 2026-10-12. "Looked at" and "measured" mean on the photographs listed under [Reference photographs](#reference-photographs); "read" means a page said so.

- **The toy** (read): designed at Marvin Glass and Associates and sold by Hasbro from 1967: "a light box with small colored plastic pegs that fit into a panel and illuminate to create a lit picture"; a black paper sheet blocks the light except where pegs carry it; eight colours: red, blue, orange, white (clear), green, yellow, pink, violet (https://en.wikipedia.org/wiki/Lite-Brite). One 25-watt bulb behind "a simple sheet of black construction paper" (https://www.museumofplay.org/toys/lite-brite/). Today's are made by Basic Fun with LEDs and "4 different light modes" (https://www.basicfun.com/product/lite-brite-ultimate-classic/); another model names its four "steady light, bounce, flash, or clockwise" (https://www.basicfun.com/product/lite-brite-classic-bold-bright-edition/). The real modes mostly flash; ours do not.
- **The grid** (read): "a grid of 39 rows, which alternated between 44 and 45 holes per row, resulting in a hexagonal ('honeycomb') layout containing 1735 holes" (https://www.pcjs.org/machines/led/lite-brite/). Measured: a lattice fitted to 1,286 of the faint dots on a front-on photograph has basis vectors of 22.59 and 22.70 px at 60.6 degrees, so it is a regular honeycomb to half a percent.
- **The pitch** has no source. Derived: 45 holes across a 12-inch sheet and 39 rows down a 9-inch one fit at about 6.4 mm, a quarter inch, which agrees with peg heads a quarter inch across that nearly touch. Treat it as an estimate. The screen sizes are a refill seller's (https://glowpeg.com/history-lite-brite-refill-design-sheets/).
- **A peg** (looked at): a straight cylinder head with a flat top, a rounded rim and a moulded lip about two thirds of the way out, on a tapered point. Its head is 0.93 to 0.95 of the pitch across, so neighbours all but touch.
- **Lit, in a dark room** (looked at): exposed as a phone exposes it, a fat blob bleached nearly white with only its rim in colour. Exposed lower, a thin bright ring at the rim, a darker face inside it and a small hot dot where the bulb shows through, off-centre and very uneven from peg to peg. Pegs lean, so the blobs are irregular.
- **The paper is not blank** (measured): every unpunched hole shows as a faint dot 0.4 of a pitch across at about three times the paper's level.
- **One bulb is uneven** (measured through bare holes): about 4 to 1 from the middle to a corner.

**The peg colours**, sRGB, the median of saturated, unclipped pixels by hue over seven photographs (`Vivid` in the app), and the calmer set made from them (`Calm`: each one's OKLab chroma times 0.78, its lightness pulled a quarter of the way to the set's middle, and a warmer clear peg):

| | red | pink | orange | yellow | green | blue | violet | clear |
|---|---|---|---|---|---|---|---|---|
| Vivid | 200, 25, 10 | 205, 25, 75 | 220, 95, 10 | 205, 170, 20 | 0, 195, 25 | 5, 80, 190 | 140, 45, 190 | 235, 215, 180 |
| Calm | 188, 65, 50 | 192, 65, 87 | 201, 105, 56 | 185, 159, 65 | 66, 179, 66 | 44, 95, 179 | 138, 72, 178 | 240, 204, 158 |

OKLab is Björn Ottosson's (https://bottosson.github.io/posts/oklab/, public domain by its own statement).

**The glow on the paper**, median sRGB by distance from the nearest lit peg's centre in one dark-room photograph, and the model fitted to it, exposed alike:

| pitches | photograph | model |
|---|---|---|
| 0.55-0.75 | 55, 63, 2 | 57, 55, 10 |
| 0.75-1.0 | 35, 40, 7 | 37, 34, 9 |
| 1-1.5 | 23, 24, 11 | 23, 21, 8 |
| 2-3 | 13, 13, 11 | 14, 13, 8 |
| over 10 | 7, 7, 7 | 7, 7, 7 |

The glow is the peg's own colour and is gone within about three pitches. The model is three terms by distance d in pitches: `0.009 exp(-max(d - 0.47, 0) / 0.16) + 0.0017 exp(-d / 0.5) + 0.00014 exp(-d / 2)`. It was fitted to one photograph.

### Reference photographs
Used for looking and measuring only. No copy is in the repo, and several are non-commercial: none may go on the site or the README.

| What it shows | Credit and licence | Page |
|---|---|---|
| Dark room, front on, a whole board: the lattice, the dots and the glow were measured on it. Its subject is a menorah built in pegs, so under Dave's rule it is cited here and shown nowhere | ekornblut, CC BY-NC-ND 2.0 | https://www.flickr.com/photos/82001511@N00/2089535001 |
| Dim room, a whole lit board | swirlspice, CC BY-NC-SA 2.0 | https://www.flickr.com/photos/10186531@N00/4708123430 |
| Dark room close-up on film, 1986: rings and hot dots | Claire CJS, CC BY-NC-SA 2.0 | https://www.flickr.com/photos/31355686@N00/2801689400 |
| Lit pegs, macro, from above and from the side | Crystl, CC BY 2.0 | https://www.flickr.com/photos/10953991@N00/164866200 and .../164866201 |
| Lit pegs close, from the side | fo.ol, CC BY-SA 2.0 | https://www.flickr.com/photos/37996589754@N01/3531619630 |
| A 1967-style box with no paper and the bulb on: the grid, the holes, the falloff | thomas ambridge, CC BY-SA 3.0 | https://commons.wikimedia.org/wiki/File:Hello_on_a_Lite-Brite.jpg |
| Unlit pegs on black paper in daylight | Nicole Bratt, CC BY-SA 2.0 | https://commons.wikimedia.org/wiki/File:Lite-bright_(7928305212).jpg |
| Loose pegs, backlit: their shape | frankieleon, CC BY 2.0 | https://commons.wikimedia.org/wiki/File:Lite_Brite_Accident_(3029715509).jpg |

Licences are as Openverse and Wikimedia Commons list them.

## How it works

**The lattice.** Rows are half a pitch offset and √3/2 of a pitch apart, with one hole more than the display holds on every side so the sheet runs off its edges. A pitch is 32, 16 or 32/3 points (Large, Medium, Small): the toy's quarter inch on a laptop's display, a half and a third of it. A 14-inch display has 48 by 36, 95 by 71 or 142 by 107 holes in view.

**One shader draws every peg.** For each pixel it finds the nearer of two holes by arithmetic (the nearest in the row below and in the row above), and reads that hole's colour and its place in the order from two small textures, a texel a hole. The peg's face is shaded from the distance to its middle, which a hash of the hole moves a little, as pegs sit crooked: a body, a bright rim line at 0.93 of the radius, a darker band inside it, the lip at 0.66, and the hot dot, whose place and strength the hash also sets. Nothing is drawn thinner than a pixel. So the cost is by the pixel and does not change with the number of pegs or their size.

**The glow needs no blur.** A third texture, 4 by 4 texels a hole, holds the light every lit peg casts on the paper. It is summed on the CPU by stamping one small kernel per peg as pegs go in (`Glow`), 0.0057 ms a peg in the timing sketch, and read smoothly by the shader. It is kept in two states a quarter of a second apart, and the shader shows the one turning into the other, so a peg's glow comes up over a quarter second while the peg is about half lit.

**Time.** The scene moves in steps of a 960th of a second, however many a frame holds, so the picture is the same at 15, 30 and 60 frames a second. The shader is told how many pegs have been begun and lights each by its place in the order: a peg comes in over the first quarter of a second and reaches full in one second at any speed, so a faster build is a wider soft front and not a sparkle. The place is three bytes, since a large display at Small pegs has more than 65,535 holes.

**A round.** Build at 6 pegs a second times Speed; then a light show for 60 s; then the sheet goes dark over 3 s, its pegs fading out with their light, so that what is left is an empty sheet; a second later the next thing begins on it. The fade is a straight line in the light, which on the screen is even: the pegs' brightness falls 19%, 24%, 29% and 28% of the way in its four quarters (eased in and out, as it first was, 12%, 32%, 40% and 16%, and it read as half as long). Where both kinds are shown they take turns, the first at random; the pictures go round in a new order each time.

**A light show** dims pegs and glow together by where they are on the sheet, between 20% and 100% of their light, easing in and out over 3 s. Three, one picked for each sheet: a lobe going round the middle once in 40 s, rings leaving the middle every 20 s, a band crossing every 24 s.

**A snow crystal** is Reiter's model (C. Reiter, "A local cellular model for snow crystal growth", Chaos, Solitons & Fractals 23(4), 2005, 1111-1119: https://ideas.repec.org/a/eee/chsofr/v23y2005i4p1111-1119.html; the rule as on his page, https://webbox.lafayette.edu/~reiterc/mvp/sfn/index.html; written from that description, not checked line by line against the paper). Every hole holds water, a hole is ice from 1 up, water away from the ice diffuses and holes beside it take a little from the air. It grows from the middle hole until it nears the display's edge or reaches 48 pitches, and its pegs go in the order they froze. Four sets of its three numbers give feathery, plump and narrow crystals; its colours run from heart to tips in one of three families.

**A picture** is a chart: a list of holes, each empty or one of the eight colours. `docs/peg-board/cut.py` cuts each from its source at up to three sizes, named for the size of peg they are for: 43 by 30 holes at most for Large pegs, 86 by 61 for Medium and 131 by 93 for Small, which is what a 13-inch display holds at each, less a margin. Every hole takes the picture's average over its own cell and then, for a picture in colour, the nearest peg colour in OKLab with lightness counted 0.7, after the picture's chroma is brought up to the pegs' and with dark, colourless parts or its paper's colour left empty; or, for a print in one ink, a peg from a ramp of one colour family by its lightness, turned over where the ink is to be the light. A peg with no neighbour is taken out. The scene puts up the largest chart of each picture that fits its sheet, in the middle. The order is outline first: the pegs on an edge of their colour, a colour at a time, then the rest, always the nearest peg not yet in.

What was tried and dropped: dithering (confetti), oil paintings (blobs at any size tried), and maps, machines, knots and star charts, whose content is a line thinner than a peg.

## The pictures

All five were cut on 2026-10-12. "Reads at" is by eye on the app's own render (`docs/peg-board/pictures-*.jpg`).

| Chart | Picture | Holder | Licence | Reads at |
|---|---|---|---|---|
| great-wave | Katsushika Hokusai, Under the Wave off Kanagawa, c. 1830-32; its tan sky left empty | The Metropolitan Museum of Art, https://www.metmuseum.org/art/collection/search/45434 | CC0 | Medium, Small |
| wreath | Design for Berlin Wool Work (a wreath of flowers), Carl F. W. Wicht, c. 1860 | Cooper Hewitt, Smithsonian Design Museum, https://collection.cooperhewitt.org/view/objects/asitem/id/96964 | CC0 | Medium, Small |
| stag | Design for Berlin Wool Work, Stag, Thomas Wilhelm Meister, c. 1850 | Cooper Hewitt, https://collection.cooperhewitt.org/view/objects/asitem/id/127556 | CC0 | all three |
| flea | Robert Hooke, a flea, Micrographia, 1665; ink as light, in red, orange and yellow | Wellcome Collection, https://wellcomecollection.org/works/ajveb66y | CC BY 4.0 | all three |
| sol | Federico de Vinciolo, Sol, a lace pattern, 1588; a sun god, which Dave's rule allows | The Metropolitan Museum of Art, https://www.metmuseum.org/art/collection/search/665397 | CC0 | Medium, Small |

The licences as their holders state them:
- **The Met:** it "has waived all copyright and related or neighboring rights to this dataset using the Creative Commons Zero license", and its API gives images "(JPEG format) that are in the public domain" (https://metmuseum.github.io/). The Wave's record said `isPublicDomain: true` when fetched for this.
- **Cooper Hewitt:** CC0 under Smithsonian Open Access; each object's API record gives `usage.access = CC0` (https://creativecommons.org/publicdomain/zero/1.0/).
- **Wellcome Collection:** CC BY 4.0: "You can use this work for any purpose, including commercial uses, without restriction under copyright law. You should also provide attribution to the original work, source and licence." About credits it, as CC BY asks.

All but the Met's general statement and the Wave's record were read by the rights research of 2026-10-12, not by the builder. The image addresses are in `cut.py`.

Left out: a Berlin wool work hunting dog, whose white coat could not be told from its chart's paper; Dürer's Rhinoceros (1515, National Gallery of Art), which shipped in the first build with its ink as light in blue, violet and clear, only just read and only at Small pegs, and was dropped on Dave's word on 2026-10-12; and everything religious (a face of Christ in an early test was removed with its renders).

## Rights

From the rights research of 2026-10-12 (kept with that day's research as `toys/rights/notes.md`), which read the records; the builder did not.

- The toy's name is registered to Hasbro, Inc. for "Toy set comprising a board and light conducting pegs slidably connectable therewith to form various pictures" (US reg. 847826, 1968, renewed 2018; also 3894010 and 8173404). It is used nowhere in the app's interface. The search found no registered look for the board, but it covered word marks only.
- The toy's patent, US 3,530,615, "Illuminated design set", was granted in 1970 and ran out in 1987 (https://patents.google.com/patent/US3530615A/en).
- The toy's printed template sheets are in copyright (first published 1967; 95 years under https://www.copyright.gov/circs/circ15a.pdf) and today's carry no licence (https://basicfun.com/lite-brite-templates/). None was opened, used or copied.
- So: a black sheet of holes with glowing coloured pegs is free; the name, the housing's shape, the logo and the sheets are not. There is no housing here at all.

## Settings

| Setting | Key | What it does | Default |
|---|---|---|---|
| Colors | `pegboard.palette` | Calm, Vivid, or Random, which takes one of the two for each new sheet | Calm |
| Shows | `pegboard.shows` | Everything, Patterns only, Pictures only. A change clears the sheet at once if what is on it is no longer allowed | Everything |
| Speed | `pegboard.speed` | 0.5× to 20× the 6 pegs a second (Dave will judge the default on his desktop). The light show and the clear take the same time at any speed | 1× |
| Peg size | `pegboard.size` | Large, Medium, Small. Another size is another sheet, there and then | Medium |
| Softness | `pegboard.softness` | 0 to 1: the rim, lip and dark band from full to 0.3; the glow ×1 to ×4; the hot dot 0.35 to none; the outline 1.2 to 3 pixels wide; exposure 1.8 to 1.6 to hold the level. Nothing is stamped again, so it is instant | 0 |

`pegboard.seed` and `pegboard.picture` are for the tests and for stills: the same sheets twice, and the picture to put up first.

## Cost

Measured 2026-10-12 on an M3 Max.

- **The app's render test** (debug build, 3024 × 1964, the mean of 30 frames): GPU 0.37 to 0.54 ms; CPU 0.44 to 1.06 ms in runs of this scene alone, and 0.57 and 1.31 in two runs of every scene. Most of the CPU is SpriteKit's own; the stamping and the glow's upload land on four frames a second, and a frame with a tick has not been timed on its own.
- **The shader alone**, in the timing sketch written before the build (`docs/peg-board/bench.swift`: a full-screen `SKShader` through `SKRenderer`, mean of 30 frames; `swiftc -O bench.swift -o bench && ./bench out.png`):

  | | 14-inch 3024 × 1964 | 5K 5120 × 2880 | 6K 6016 × 3384 |
  |---|---|---|---|
  | reading the nearest hole only (what was built) | 0.38 ms | 0.86 ms | 1.2 ms |
  | reading the four holes round each pixel, for an exact tight glow | 0.84 ms | 2.1 ms | 2.9 ms |

  The same at a pitch of 13.5 and of 27 points, and with the board half full or full.
- **On the main thread, once per sheet, while it is dark:** a crystal grows in 2 to 4 ms at Large pegs, 16 to 34 at Medium and 53 to 111 at Small; the largest picture (5,306 pegs) goes up in 9 ms, order and all.
- **How busy it is,** by `docs/meander/measure/busy.py` (the share of pixels on a brightness edge) on the app's stills at Softness 0: a crystal 5.5 to 9.2%, the stag 6%, the Wave and the wreath about 11%, the flea 16.5%. The crystal that scores 9.2% is 6.2% at Softness 0.5 and 2.3% at 1. The wallpapers Dave has kept score 0 to 3.3% (Fish Tank 8.5%), and Game of Life's Classic look, which he called "so busy and wild", 11.1%. Its mean level is 0.08 to 0.14, like Nebula's.
- **How much it moves:** a build at speed 1 changes 0.004 grey levels a pixel a frame at 15 fps (Meander 0.03 to 0.10): nearly still.

## Checking it

```sh
swift test --filter 'snowCrystal|pegBoard'
SNAPSHOT_SCENE="Peg Board" SNAPSHOT_SECONDS=35 SNAPSHOT_DEFAULTS="pegboard.picture=great-wave,pegboard.speed=8,pegboard.seed=7" swift test --filter everySceneRenders
PEGBOARD_STILL=docs/images/peg-board.jpg PEGBOARD_STILL_WIDTH=1600 SNAPSHOT_SECONDS=27.5 SNAPSHOT_DEFAULTS="pegboard.shows=1,pegboard.speed=8,pegboard.seed=6" swift test --filter pegBoardStill
python3 -I docs/peg-board/cut.py <folder of the source pictures> Sources/Atrium/Resources sheet.png
```

- The tests: a crystal has six arms and stays on the sheet at all three sizes; the charts are whole, fit their sizes and are credited; a picture's order is outline first; the picture is the same at 15, 30 and 60 fps part-way through a build, mid-show and after the clear; the clear ends on an empty sheet, so nothing changes on the frame the next thing begins (when the pegs stayed as black shapes, that frame changed by 25 levels of 255; now by 1); the sheet follows Peg size and Shows while it runs.
- **Stills are drawn at the size they are shown at** (`pegBoardStill`): a still reduced afterwards shows a weave in the dotted sheet. `docs/images/peg-board.jpg` is the line above; `peg-board-wave.jpg` is `pegboard.picture=great-wave` at 34.5 s; `Resources/preview-peg-board.jpg` is the first at 1200 wide. The crystal was picked from eight rolls.
- `cut.py` needs each source downloaded by hand under the file name its table gives. After a change, look at its sheet and at the app's render at every size before keeping a chart.

## Shortcuts

- A crystal is grown on the main thread, while the sheet is dark. One to fill a 6K display at Small pegs would want a thread of its own (`snowCrystal`'s `limit` holds it to 48 pitches meanwhile).
- The outline-first order looks through every peg left for each run: fine to about 5,000 pegs, too slow at 50,000.
- Charts stop at 131 by 93 holes, so on a display much larger than a laptop's a picture sits in the middle of the sheet and does not grow.
- The light show's length, the clear and the three shows are fixed numbers, not settings.
- There is no Light Mode look: a black sheet is the toy.
- The halo was fitted to one photograph, and the model's peg is a flat disc: no lean, no side walls, no overlap.

## Still open

Worst first, as the builder saw it on stills; Dave has not seen it run.

1. **Sharp and busy at Softness 0**, the default he chose: see the busy scores above. It is what got Zen Garden cut ("so bright and sharp and not relaxing"), and Softness is the answer he has to hand.
2. **Nearly still at speed 1.** A crystal takes 2 to 3.5 minutes at Medium and a picture 2 to 6; the Wave takes 11 at Small and the flea 15. The slider now goes to 20×, where the flea at Small takes 45 s.
3. **Large pegs have two pictures,** the stag and the flea, and the stag there is a blob with antlers. Nothing else read at 43 by 30 holes.
4. **The light show is faint in stills** and has not been watched moving.
5. **A change of peg size is a hard cut** to a new sheet.
6. **In Settings the page fades from its screenshot, a finished crystal, to the live copy's near-empty sheet,** since a scene starts afresh; and a new peg size starts the sheet again. Sliders are hard to judge until pegs are in. A head start for a scene's first sheet would mend it, at the cost of a desktop that does not start empty: not decided.
7. Not checked: the Settings page itself (its test opens a window on the screen), a 5K or 6K display, a 1x display, a scaled display mode (measured in the mock-ups only: the pegs' sharpness drifts up to 3% across the sheet at pitches whose rows land just off a whole pixel).

## Next ideas

- Ornament drawn on the lattice instead of sampled: six-fold star patterns sit on a honeycomb exactly.
- More charts from old needlework (Cooper Hewitt and the Met hold many, CC0), each needing a crop, a recipe and a look.
- Other grown patterns beside the crystal. A rosette tried in the mock-ups read as a ship's wheel.
- The pegs leaving one by one instead of fading with the sheet.
