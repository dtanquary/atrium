# Peg Board

A black sheet of holes, edge to edge, with coloured translucent pegs pushed through it one at a time and lit from behind. It shows one thing after another: a pattern made fresh, of [eight kinds](#the-patterns) in turn, or a picture built outline first; each, once whole, under a slow light show; then the sheet goes dark and is cleared for the next.

It imitates Lite-Brite, the peg-light toy Hasbro first sold in 1967. That name is a registered mark and is used nowhere in the app: see [Rights](#rights).

Dave asked for a clone of it on 2026-10-12, "with lights, showing various lighting patterns and what not"; it was researched and mocked up that day, and he chose from the sheets ([Dave's decisions](#daves-decisions-2026-10-12)). It was built the same day in three steps behind the `unfinished` switch, and has been shown to everyone since 0.111.0 (2026-10-13, when Dave said "unhide all 3 of the new ones").

- **Source:** `Sources/Atrium/PegBoard.swift` (the scene and its one shader), `Sources/PegLattice/` (the lattice, the crystal, the glow, the charts and the order pegs go in; its own module, built with `-O`). `Patterns.swift` there makes the seven kinds of [pattern](#the-patterns) beside the crystal.
- **Data:** `Resources/peg-board-charts.txt`: the pictures, which are the app's own figures, drawn for pegs.
- **Scripts:** `docs/peg-board/draw.py` draws the figures and writes the charts ([The pictures](#the-pictures)); `docs/peg-board/bench.swift` is the timing sketch the shader was tried in before the build ([Cost](#cost)).
- **Pictures of it:** `docs/images/peg-board.jpg`, `peg-board-sailboat.jpg`; and in `docs/peg-board/`, every figure as the app draws it at each size (`figures-large.jpg`, `figures-medium.jpg`, `figures-small.jpg`), one whole round (`round.jpg`), the three light shows over a figure (`light-show.jpg`) and the Softness slider (`softness.jpg`).

## Dave's decisions (2026-10-12)

| Question | His pick |
|---|---|
| Name | Peg Board |
| What it shows | all three kinds he was offered, in rotation: pictures built peg by peg from an empty sheet; patterns that grow ("symmetric designs made fresh each time, growing outward"); slow light shows on a finished board, nothing flashing. With a setting: everything, patterns only, pictures only |
| Patterns beside the crystal | seven of the fourteen mocked up for him, asked kind by kind (relayed 2026-10-13): of the growths, "Reef, Plate"; of the geometric, "Blocks"; of the fractals, "Triangles, Hexaflake"; of the spirals and flowers, "Pinwheel, Rose". All eight take turns |
| The toy on screen | the sheet alone, edge to edge. He asked to see a light box round it too; mocked up, it read as a tablet's bezel and held only the toy's 1,735 holes, and he chose no box |
| Peg look | "A slider, crisp by default": the measured plastic peg, with Softness down to a glowing disc |
| Peg size | "A slider", settled as three fixed sizes (the toy's own, half, a third; half the default), each picture cut and checked by eye at each, and left out at a size where it does not read |
| Colours | a calmer set by default, the set measured from the real pegs as a second palette. Once he had run it: "the color options are good" |
| Pictures | "nothing religious"; asked whether that covers a sun god on a lace chart or Neptune on a map: "Myth is fine". Only public-domain, CC0, CC BY or CC BY-SA sources; never the toy's own template sheets |
| The pictures, once he had run it at Large pegs | "on peg board, pictures are hard to make out, but the pattern looks good". Asked what to do: "Draw our own: simple bold figures designed hole by hole for each peg size (a sailboat, a butterfly, a flower), the way a person would make them on the toy. Mock-ups first for you to judge; the old-print charts go if these read better." |
| The drawn figures (2026-10-13, on the mock-ups) | the eight put forward, and of the four left out "Balloon and snail too" and "Lighthouse, redrawn"; not the moon with stars |
| The old prints (2026-10-13) | "Remove them all" |

The lead's calls, which he has not ruled on: a Speed slider; the lean shader; three bytes for a peg's place; a fresh start on each load.

## Dave's feedback

**2026-10-12, after running it on his desktop** (a 14-inch display; Shows at Patterns only, Large pegs, which is 48 by 36 holes there, Softness 0, Speed about 10, the Calm colours):

> on peg board, pictures are hard to make out, but the pattern looks good, I only see 1 pattern ever though but it does look really cool, the color options are good

- **Pictures are hard to make out.** Asked what to do about it, he picked "Draw our own": figures drawn for pegs, not cut down from prints and charts.
- **The pattern looks good, and there is only one.** There are four snow crystals (four sets of Reiter's numbers) in three colour families, but at Large pegs a crystal is 13 holes from heart to tip and the four come out alike. Asked which kinds of new pattern to mock up, he picked all four offered: growth, geometric, fractals, spirals and flowers. A new pattern has to read at Large pegs first, and to differ from the crystal and from the others at a glance. He then picked seven of the fourteen shown him: [The patterns](#the-patterns).
- **The colours are good:** the two sets and Random stay as they are.

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

**A round.** Build at 6 pegs a second times Speed; then a light show for 60 s; then the sheet goes dark over 3 s, its pegs fading out with their light, so that what is left is an empty sheet; a second later the next thing begins on it. The fade is a straight line in the light, which on the screen is even: the pegs' brightness falls 19%, 24%, 29% and 28% of the way in its four quarters (eased in and out, as it first was, 12%, 32%, 40% and 16%, and it read as half as long). Where both pictures and patterns are shown they take turns, the first at random; the pictures go round in a new order each time, and so do the eight kinds of pattern.

**In Settings** the page's own copy gets a head start: `LivePreview` asks any scene that is a `HeadStart` (Scenes.swift, added for this; nothing else adopts it yet) to skip ahead as it is made, and this one puts every peg of its first sheet in at once, lit and with its glow, and goes straight to the light show; it does the same after a change of peg size. So Softness, the colours and the size can be judged as they are moved. From there the round goes on as usual, and the desktop's copy is never asked: it starts from an empty sheet.

**A light show** dims pegs and glow together by where they are on the sheet, between 20% and 100% of their light, easing in and out over 3 s. Three, one picked for each sheet: a lobe going round the middle once in 40 s, rings leaving the middle every 20 s, a band crossing every 24 s.

**A snow crystal** is Reiter's model (C. Reiter, "A local cellular model for snow crystal growth", Chaos, Solitons & Fractals 23(4), 2005, 1111-1119: https://ideas.repec.org/a/eee/chsofr/v23y2005i4p1111-1119.html; the rule as on his page, https://webbox.lafayette.edu/~reiterc/mvp/sfn/index.html; written from that description, not checked line by line against the paper). Every hole holds water, a hole is ice from 1 up, water away from the ice diffuses and holes beside it take a little from the air. It grows from the middle hole until it nears the display's edge or reaches 48 pitches, and its pegs go in the order they froze. Four sets of its three numbers give feathery, plump and narrow crystals; its colours run from heart to tips in one of three families.

**A picture** is a chart: a list of holes, each empty or one of the eight colours. The pictures are the app's own figures, drawn for pegs ([The pictures](#the-pictures)), each with a chart for each size of peg: 43 by 30 holes at the most for Large pegs, 86 by 60 for Medium and 129 by 90 for Small, which is within what a 13-inch display holds at each, less a margin. The scene puts up the largest chart of each picture that fits its sheet, in the middle: on a laptop's display, the one for its peg size. The order is outline first: the pegs on an edge of their colour, a colour at a time, then the rest, always the nearest peg not yet in. The pictures go round, each once, in an order shuffled afresh each time round.

## The pictures

Eleven figures drawn for the board, in 33 charts: every one at all three peg sizes. `docs/peg-board/figures-large.jpg`, `figures-medium.jpg` and `figures-small.jpg` are all of them as the app draws them.

The first pictures were old prints cut down to pegs ([below](#before-them-prints-cut-down-to-pegs)). Dave ran those on his desktop at Large pegs on 2026-10-12: "on peg board, pictures are hard to make out, but the pattern looks good". Asked what to do about the pictures, he picked: "Draw our own: simple bold figures designed hole by hole for each peg size (a sailboat, a butterfly, a flower), the way a person would make them on the toy. Mock-ups first for you to judge; the old-print charts go if these read better." Twelve were drawn that day and eight put forward. On 2026-10-13 he judged them on sheets of the app's own stills, beside the prints: he kept the eight, and of the four left out said "Balloon and snail too" and "Lighthouse, redrawn". He did not pick the moon with stars. Of the prints he said "Remove them all".

**A figure is geometry, not a picture cut down.** `docs/peg-board/draw.py` holds each as a list of flat shapes (polygons, discs, thick lines with round ends), each in one of the eight peg colours, the later over the earlier; a shape of "none" is empty holes, which on a black sheet is a dark line. Nothing is averaged or matched: every hole takes the colour of the shape its own middle is in. Each was drawn from nothing for that file. No picture, chart or template sheet was copied or traced, so a figure has no source and needs no credit.

**The drawing's units are the holes of a chart for Large pegs,** the size Dave runs: x counts holes along a row and y counts rows from the top, 43 by 30 at the most. So at Large pegs a figure is set hole by hole: an edge goes between two rows or two holes, a spot goes on a hole (a disc of radius 1.2 is that hole and the six round it, the board's own dot; 2.1 takes the next ring too), and a line of single pegs runs along a row or a diagonal of the honeycomb. The charts for Medium and Small pegs are the same drawing at two and three holes to a unit, 86 by 60 and 129 by 90 at the most: the same shapes with smoother edges, nothing added but the balloon's ropes (a shape can be marked for some sizes only, `only`). A figure with `mirror` is drawn as its left half and folded, so it is the same on both sides to the hole.

**The look:** two to four colours, big flat areas, nothing dithered or shaded, the sheet round the figure empty. A row of empty holes does for a line: the mast between the sailboat's sails, the gap under the mushroom's cap and between the butterfly's wings, the V of the tulip's middle petal, the owl's pupils, the fish's eye, the turns of the snail's shell. Nothing is thinner than two pegs but the butterfly's feelers, the snail's eye stalks, the ring of the fish's bubble and the lighthouse's rays, which Dave accepted. The scene's outline-first order suits them: every colour's outlines go up before anything is filled, so a figure can be told about a third of the way in.

| Chart | Colours | At Large pegs | Reads at |
|---|---|---|---|
| sailboat | clear and yellow sails, a red hull, blue waves | 32 by 28 holes, 438 pegs | all three |
| butterfly | violet and pink wings with clear spots, yellow body | 35 by 28, 623 | all three |
| tulip | red, green | 20 by 30, 309 | all three |
| fish | orange with clear stripes, yellow tail and fins, a blue bubble | 37 by 26, 466 | all three |
| rocket | red nose and fins, clear body, a blue window, yellow flame | 18 by 29, 217 | all three |
| owl | violet, clear eyes, yellow beak and feet, an orange branch | 22 by 29, 429 | all three |
| mushroom | red cap with clear spots, clear stem, green grass | 26 by 29, 455 | all three |
| cactus | green, in an orange pot, with a pink flower | 19 by 30, 287 | all three |
| balloon | red and yellow stripes, an orange basket | 23 by 30, 418 | all three; at Large its envelope is faceted, like a paper lantern |
| snail | an orange shell, a yellow body | 34 by 27, 426 | all three; at Large its shell, a coil two pegs wide, comes out six-sided |
| lighthouse | red and clear stripes, a yellow lamp and rays, blue waves | 31 by 30, 312 | all three; at Large its two slanting rays are steps of three and four pegs |

"Reads at" is by the builder's eye on the app's own stills of a 1512 by 982 point display, Softness 0. At Small pegs they read but are plain: flat areas of thousands of pegs, which no hand would set, and long to build (the butterfly is 5,565 pegs, 15 minutes at speed 1).

**Changed after Dave's look** (2026-10-13), each seen before and after on the app's stills:
- The lighthouse's light was a wedge of yellow that read as a flag. It is now three rays from a yellow lamp, to one side only: one each side made a cross with the tower, which is never to come back. At Medium and Small pegs the rays are clean lines; at Large the two that slant are stepped.
- The fish's tail and fins were red, too close to its orange body in the Calm colours. They are yellow.
- The tulip was the weakest at Large pegs. Its leaves are longer and stand up beside the stem (309 pegs from 264) and its petals' tips are two pegs, not one.

**Drawn and left out:** a crescent moon with stars and a cloud. It read as a night sky, but a star of seven pegs looks like a flower at Large pegs, and a crescent beside stars is close to an emblem of a faith. Dave did not pick it, and its drawing is gone from draw.py (it is in git history, in the commit that first added the file).

**Learnt on the way:**
- A disc of radius 1.8 about a hole is thirteen holes in the shape of a six-pointed star. Spots are 7 or 19 holes.
- On offset rows an upright edge at a whole or a half x goes through holes' middles; at a quarter x it is a zigzag half a hole deep, which is what an upright edge is on this board. An upright band two holes wide cannot be centred on a hole: the tulip's stem sits a quarter of a hole right of its bloom.
- A sliver left between two shapes comes out as a dotted line. The snail's shell was first a disc with a spiral of empty holes, which left dots along its rim; it is now one thick coiled line.
- A wedge of one colour reads as a thing, not as light. Rays with dark between them read as light.
- Calm's red, pink and orange are close: keep them apart, or part them with a row of empty holes.

### Before them: prints cut down to pegs

Until 0.111.1 (2026-10-13) the pictures were thirteen old prints and needlework charts, each cut down to pegs by averaging it over the holes: Hokusai's Wave, two Berlin wool work charts (a wreath and a stag), Hooke's flea, four of Vinciolo's lace patterns of 1588 and five pages of Sibmacher's pattern book of 1597. They came from the Met, Cooper Hewitt and the Wellcome Collection, all CC0 but the flea (CC BY 4.0), and were credited in About. At Large pegs seven of them had a chart and none was strong: the stag was a blob with antlers, the lion a ragged beast.

They are gone from the app with everything of theirs: the 32 charts, the scripts that cut them (`cut.py`, and `grid.py` to find a charted pattern's net), `peg-board-credits.tsv` and its line in About, and the sheets of them at each size. All of it is in git history. `git show 5b90618:docs/peg-board.md` is this doc as it stood with them: the table of the thirteen with each holder's address and licence, what the holders say in their own words, the pattern books looked through page by page, and what was left alone under Dave's rule on religious pictures. `git show 5b90618:docs/peg-board/cut.py` has each image's address.

What they taught, which the figures are drawn by: a picture averaged over holes is blurred; dithering is confetti; oil paintings were blobs at any size tried; a map, a machine, a knot or a star chart is a line thinner than a peg; a needlework chart can go a square to a hole and still not read in 30 rows; and a picture that fills its paper leaves no sheet empty and reads as camouflage.

## The patterns

Eight kinds, each made fresh from the scene's seeded numbers and built in the order it is made. **They take turns:** each comes once, in a new order every round, before any comes again, and none follows itself, across rounds or a change of peg size either (`nextKind`). The first was the snow crystal, [above](#how-it-works). Dave, having run that alone: "I only see 1 pattern ever". Fourteen more kinds were mocked up for him on 2026-10-12 and he picked seven ([his decisions](#daves-decisions-2026-10-12)); the rest are under [Tried and dropped](#tried-and-dropped).

Each of the seven gives the holes in the order their pegs go in and one of four tones a peg (`Pattern`, in `Sources/PegLattice/Patterns.swift`), which the scene turns into three colours of one family and the clear peg, from the colour set in use. Five such families: blue, violet and pink; red, orange and yellow; green, blue and violet; violet, pink and orange; blue, green and yellow. A peg still takes a second to light, so nothing flashes.

| Kind | What it is | Its build | What the seed varies | How it reads |
|---|---|---|---|---|
| `reef` | A row of branching things grown from the floor of the sheet, each its own tone: a peg at a time wanders in from above and stops where it first touches the floor or what has grown, staying three times in ten, which thickens the branches. It stops at a count of pegs: held to a height, it piled up along the line in a flat cap | all of them rising together, as they grew | everything: no two are alike | At Large pegs a row of seaweed, the tallest to two thirds of the height; finer, and more of them, at the others. Its roots are where the Dock is |
| `plate` | A plate grown ring by ring from the middle hole: every hole freezes on the step it has one of the rule's numbers of frozen holes round it, until one would freeze off the sheet. Toned by when it froze | ring by ring, each ring round | one of six rules, each of which makes one plate (1; 1 or 3; 1, 3 or 5; 1 or 2; 1 or 5; 1, 3, 4, 5 or 6 frozen neighbours) | A filled hexagon, 26 holes across at Large, with a lace of holes in it and three bands of tone. One outline, with a different inside; one rule at Small gives six lobes |
| `blocks` | Tumbling blocks: hexagons cut in three diamonds that the eye takes for cubes, the tops clear. Whole cubes only | a cube at a time from the middle out, its top first | their size; and, one time in three, the right faces left dark | Cubes at once where they are three holes a side or more; two a side, at Large, as a woven band; with dark faces, as steps. The strongest at Medium and Small, and the brightest: see [Cost](#cost) |
| `triangles` | Pascal's triangle less the numbers a prime divides: Sierpinski's triangles for 2, their cousins for 3 and 5, toned by the remainder | a row at a time from its point, each row from its middle | the prime, which way up, and with them the size | Reads at every size |
| `hexaflake` | A hole and the six round it, that and six copies of it three times as far out, and so on | the middle flake of each level, then the six round it | the size of a step (one hole, or two or three with a cluster of seven pegs at each point) and so how many levels fit; whether the smallest flakes are rings of six with no middle; how it is toned (by level, or by which of the seven flakes of one level a point is in) | A lacy six-fold flake, the nearest of these to the crystal |
| `pinwheel` | Spiral arms of even width from a clear hub, each its own tone | all arms winding outward together | two to five arms, which way they wind and how tightly | Reads at once. At Large the arms have six corners, as anything round has at that size |
| `rose` | A flower from above: a clear middle, a ring of short petals and a ring of long ones between them, each with a round end | a petal at a time: the middle, the short petals in turn round it, then the long ones, each from its foot to its tip | five, seven or eight petals at Large, seven to twelve at the others, never six; and how it is turned | A flower at every size: a primrose at Large, a daisy at the others |

**Changed since he picked,** and not yet seen by him:
- **The rose goes in petal by petal.** Laid from the middle out, all its petals at once, it was a disc with dark spokes for the middle half of its build: a wheel, which is what a rosette in the first mock-ups was taken for. Now it is a small flower gaining petals at every moment (`toys/pegs2/rotation/rose-build.jpg`, six moments at Large and at Medium).
- **The hexaflake varies.** It was the same shape every time. Its shape cannot turn (it has the lattice's own six directions), so what varies is its scale and levels, whether its smallest flakes are hollow, and its toning: by its choices, 17 different designs at Large pegs, 8 at Medium (where only one size fills the sheet) and 22 at Small, before colour (`toys/pegs2/rotation/hexaflake.jpg`, ten seeds at Large and five at each of the others). Leaving out the middle flake at a higher level, or at a step of three holes, was tried and taken out: the gap it leaves is a six-pointed star of thirteen holes or more.
- **A reef is made on another thread** (`Reserve` in PegBoard.swift): see [Cost](#cost).

**Pegs and time,** at Large · Medium · Small on a 14-inch display (the test `pegBoardPatternsFitTheSheet` prints them, from six seeds). A build is its pegs at 6 a second times Speed, and a second for the last to light:

| Kind | Pegs | Build at Speed 1 | At Speed 10 | Made in, ms |
|---|---|---|---|---|
| crystal | 217 to 303 · 829 to 1,259 · 1,735 to 2,673 | 37 s to 52 s · 2.3 min to 3.5 min · 4.8 min to 7.4 min | 5 s to 6 s · 15 s to 22 s · 30 s to 46 s | 2 to 4 · 16 to 34 · 53 to 111 |
| reef | 152 to 215 · 631 to 891 · 1,452 to 2,048 | 26 s to 37 s · 1.8 min to 2.5 min · 4.0 min to 5.7 min | 4 s to 5 s · 12 s to 16 s · 25 s to 35 s | 8.5 · 86 · 389, on another thread |
| plate | 499 to 721 · 1,999 to 3,367 · 4,339 to 7,957 | 84 s to 2.0 min · 5.6 min to 9.4 min · 12 min to 22 min | 9 s to 13 s · 34 s to 57 s · 73 s to 2.2 min | 0.2 · 1.0 · 3.2 |
| blocks | 624 to 972 · 2,550 to 4,752 · 4,992 to 10,692 | 1.8 min to 2.7 min · 7.1 min to 13 min · 14 min to 30 min | 11 s to 17 s · 44 s to 80 s · 84 s to 3.0 min | 0.0 · 0.0 · 0.1 |
| triangles | 216 to 243 · 648 to 729 · 1,215 to 2,250 | 37 s to 42 s · 1.8 min to 2.0 min · 3.4 min to 6.3 min | 5 s · 12 s to 13 s · 21 s to 38 s | 0.0 · 0.1 · 0.1 |
| hexaflake | 240 to 343 · 1,668 to 1,717 · 1,668 to 2,401 | 41 s to 58 s · 4.7 min to 4.8 min · 4.7 min to 6.7 min | 5 s to 7 s · 29 s to 30 s · 29 s to 41 s | 0.0 · 0.0 · 0.0 |
| pinwheel | 287 to 305 · 1,456 to 1,485 · 3,496 to 3,503 | 49 s to 52 s · 4.1 min · 9.7 min | 6 s · 25 s to 26 s · 59 s | 0.0 · 0.1 · 0.3 |
| rose | 399 to 405 · 2,032 to 2,053 · 4,891 to 4,933 | 68 s · 5.7 min · 14 min | 8 s · 35 s · 83 s | 0.1 · 0.2 · 0.5 |

At Dave's Speed 10 and Large pegs a pattern is whole in 4 to 17 s and then sits under the light show for a minute. Blocks at Small pegs and Speed 1 take a quarter to half an hour, and 40 s to a minute and a half at 20×, the slider's top. Of six spread seeds the test counts six different reefs, hexaflakes, pinwheels and roses at each size, five plates (all there are), four to six fields of blocks and four triangles.

**Where each comes from.** All were written from the builder's memory of these, not checked against the papers:
- `reef`: diffusion-limited aggregation, T. Witten and L. Sander, "Diffusion-Limited Aggregation, a Kinetic Critical Phenomenon", Physical Review Letters 47, 1400 (1981), https://doi.org/10.1103/PhysRevLett.47.1400.
- `plate`: Norman Packard's snowflakes of the 1980s; the family is set out in J. Gravner and D. Griffeath, "Modeling snow crystal growth I: rigorous results for Packard's digital snowflakes", Experimental Mathematics 15(4), 2006, https://www.projecteuclid.org/euclid.em/1175789778. The rules here were picked by eye for plates that differ and have not been checked against that paper's list.
- `triangles`: https://en.wikipedia.org/wiki/Sierpi%C5%84ski_triangle, under Pascal's triangle. `hexaflake`: https://en.wikipedia.org/wiki/Hexaflake.
- `blocks` is old paving and patchwork: https://en.wikipedia.org/wiki/Rhombille_tiling. `pinwheel` and `rose` are the builder's own drawing.

### Tried and dropped

Fifteen kinds were built for the mock-ups, on a branch that was never merged. Dave was shown fourteen and picked seven; these eight are not in the code:

| Kind | What it was | Why it is out |
|---|---|---|
| `coral` | the reef's growth from the middle hole, toned by how far out | Not picked. At Large pegs a scrap of twig, about 100 pegs; good at Medium and Small |
| `frost` | the same from all four edges, the middle left dark | Not picked. Failed at Large: a few twigs on the edges, half off the display |
| `flame` | flame stitch (https://en.wikipedia.org/wiki/Bargello_(needlework)): bands of tone in one zigzag over the whole sheet | Not picked. Read strongly, and lit every hole: a mean level of 0.34 against the crystal's 0.09 to 0.12, and 25% busy at Large |
| `flowsnake` | Gosper's curve (https://en.wikipedia.org/wiki/Gosper_curve), one line that fills an island | Not picked. The same island every time; only its build was worth watching |
| `spiro` | one line weaving between two rings, crossing itself in loops | Not picked. At Large, four of five were a tangle of wire netting; a clean line at Medium. Drawn with points, as a wheel in a ring draws it, it had come out as a five-pointed star in one line |
| `rings` | rings of colour about the middle | Not picked. A target, with nothing in it to find; nested hexagons at Large |
| `sunflower` | a sunflower's head (H. Vogel, "A better way to construct the sunflower head", Mathematical Biosciences 44, 1979, 179-189, https://doi.org/10.1016/0025-5564(79)90080-4) | Not picked. Failed at Large: 115 to 157 pegs scattered as confetti |
| `stars` | six-pointed stars set point to point | **Never shown to Dave,** on the builder's call, which the lead upheld: each star is a hexagram, which most people read as the Star of David, and his rule is nothing religious |

Not built: Koch's snowflake, whose first step is a hexagram; crystals seeded in several places that meet.

**How they were judged:** by eye, on the app's own renders of a 14-inch display (1512 by 982 points) with Dave's settings, Calm and Softness 0: five seeds a kind at Large and at Medium, one at Small, six moments of eight builds, and a film of four building at Speed 10. The sheets are kept with that day's research (`toys/pegs2/patterns/`, and `toys/pegs2/rotation/` for what changed after his pick), not in the repo.

**Found by looking, and worth keeping in mind:**
- **Seeds 1 to 4 are the wrong ones to judge by.** A kind makes its first choice (a size, a rule, how many arms) with the seed's second number, and for seeds 1, 2, 3 and 5 that number is 0.70 to 0.75: the first sheets showed four tiles of one choice and made every kind look the same each time. The sheets and the test use seeds picked for numbers spread from 0 to 1. Spread the same way, the crystal's four kinds and three families give two shapes at Large, of 217 or 218 pegs and of 301 or 303, in one six-armed outline.
- **Six-pointed stars turn up unasked** on a lattice with six directions: as a tiling, as Koch's first step, as the gap where a hexaflake's middle is left out, as a spirograph's figure. Three of the five plates on his sheet have a six-pointed star as their inner band of tone, and the crystal is itself a star of six arms; Dave has picked both. A hexagram, drawn or left as a gap, is what is kept out.
- **A reef let round from one side of the sheet to the other grew a bare pole up the edge:** a peg that crossed landed on the edge column behind the branches that would have caught it. The sides are walls.
- **Anything round is cut to a hexagon if it is made in a window of holes as wide as its reach:** rows are closer together than the holes in one, so the window has to be wider by 2/√3 (`Sheet.span`). It showed only on the Small sheet.
- **A thin ring at Large pegs is a hexagon anyway:** a ring a peg wide and under eight holes out is one on this lattice.

## Rights

The pictures are the app's own drawings, made from nothing for it: no source, no licence, no credit. What follows is about the toy.

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

`pegboard.seed` and `pegboard.picture` are for the tests and for stills: the same sheets twice, and the picture to put up first. `pegboard.pattern` is the kind of pattern to put up first: `crystal`, or one of the seven names under [The patterns](#the-patterns).

## Cost

Measured 2026-10-12 on an M3 Max.

- **The app's render test** (debug build, 3024 × 1964, the mean of 30 frames): GPU 0.37 to 0.54 ms; CPU 0.44 to 1.06 ms in runs of this scene alone, and 0.57 and 1.31 in two runs of every scene. Most of the CPU is SpriteKit's own; the stamping and the glow's upload land on four frames a second, and a frame with a tick has not been timed on its own.
- **The shader alone**, in the timing sketch written before the build (`docs/peg-board/bench.swift`: a full-screen `SKShader` through `SKRenderer`, mean of 30 frames; `swiftc -O bench.swift -o bench && ./bench out.png`):

  | | 14-inch 3024 × 1964 | 5K 5120 × 2880 | 6K 6016 × 3384 |
  |---|---|---|---|
  | reading the nearest hole only (what was built) | 0.38 ms | 0.86 ms | 1.2 ms |
  | reading the four holes round each pixel, for an exact tight glow | 0.84 ms | 2.1 ms | 2.9 ms |

  The same at a pitch of 13.5 and of 27 points, and with the board half full or full.
- **On the main thread, once per sheet, while it is dark:** a crystal grows in 2 to 4 ms at Large pegs, 16 to 34 at Medium and 53 to 111 at Small; the largest picture, the butterfly at Small pegs (5,565 pegs), goes up in 10 ms, order and all.
- **The seven other patterns** are made in under 4 ms at any size ([their table](#the-patterns)), but for the reef: 0.4 s at Small pegs. So a reef is made on another thread, from the moment its sheet of holes is, or the last reef was put up (`Reserve`). A new sheet never opens on a reef, so it has had a minute and more by the time it is wanted, and the scene waits for it only if it has not. What it is depends on its own seed alone, so the same sheets still come twice.
- **The step on which a pattern begins,** making it, sending it to the shader and all, at Small pegs (measured 2026-10-13 in a test not kept, the reef given a second to be made): a reef 2.1 to 2.5 ms; triangles, a hexaflake and a pinwheel 1.7 to 3.6; a rose 4.8; a plate 7.4; blocks 7.9 to 8.6; and a crystal 55 to 100. The crystal is now the one that holds the main thread.
- **How busy the patterns are,** by the measure in the next line, one still each at Large · Medium pegs: a crystal 3.8 to 5.7% · 5.6 to 8.9%, a reef 2.7 · 4.8%, triangles 3.8 · 4.6%, a pinwheel 4.9 · 9.3%, a hexaflake 5.5 · 10.6% (as it was when picked), a rose 7.3 · 13.9%, a plate 10.2 · 16.7% and blocks 17 · 26%, with a mean level of 0.26 against the crystal's 0.09 to 0.12: blocks cover most of the sheet.
- **How busy it is,** by `docs/meander/measure/busy.py` (the share of pixels on a brightness edge) on the app's stills at Softness 0: a crystal 5.5 to 9.2%; a figure at Large pegs 3.6% (the rocket) to 9.5% (the butterfly), and the butterfly at Medium and Small pegs 18%, since every peg has a rim (the figures' stills measured 3024 pixels across). The crystal that scores 9.2% is 6.2% at Softness 0.5 and 2.3% at 1. The wallpapers Dave has kept score 0 to 3.3% (Fish Tank 8.5%), and Game of Life's Classic look, which he called "so busy and wild", 11.1%. Its mean level is 0.08 to 0.15, like Nebula's.
- **How much it moves:** a build at speed 1 changes 0.004 grey levels a pixel a frame at 15 fps (Meander 0.03 to 0.10): nearly still.

## Checking it

```sh
swift test --filter 'snowCrystal|pegBoard'
PEGBOARD_STILLS=jobs.tsv swift test --filter pegBoardStills   # many stills in one run: a line each of file, width, moment and defaults, with tabs between
SNAPSHOT_SCENE="Peg Board" SNAPSHOT_SECONDS=35 SNAPSHOT_DEFAULTS="pegboard.picture=sailboat,pegboard.speed=8,pegboard.seed=7" swift test --filter everySceneRenders
PEGBOARD_STILL=docs/images/peg-board.jpg PEGBOARD_STILL_WIDTH=1600 SNAPSHOT_SECONDS=27.5 SNAPSHOT_DEFAULTS="pegboard.pattern=crystal,pegboard.shows=1,pegboard.speed=8,pegboard.seed=6" swift test --filter pegBoardStill
python3 -I docs/peg-board/draw.py Sources/Atrium/Resources sheet.png large    # draws the figures and writes the charts; the sheet is optional
PEGBOARD_STILL=docs/images/peg-board-sailboat.jpg PEGBOARD_STILL_WIDTH=1600 PEGBOARD_HEAD_START=1 SNAPSHOT_SECONDS=0 SNAPSHOT_DEFAULTS="pegboard.picture=sailboat,pegboard.size=0" swift test --filter pegBoardStill
```

- The tests: a crystal has six arms and stays on the sheet at all three sizes; every figure has a whole chart for each peg size, and the scene puts it up at that size; with pictures only, every figure goes up once before any comes again, in another order the next time round, and with everything shown both kinds come; a picture's order is outline first; the picture is the same at 15, 30 and 60 fps part-way through a build, mid-show and after the clear; the clear ends on an empty sheet, so nothing changes on the frame the next thing begins (when the pegs stayed as black shapes, that frame changed by 25 levels of 255; now by 1); the sheet follows Peg size and Shows while it runs; Settings' own copy is whole on its first frame and the desktop's is empty.
- The patterns' tests: each of the seven kinds, at each size and from six seeds, lays each hole once and stays on the display. The six are never one picture. The eight kinds each come once a round, in a new order, none following itself. A new sheet never opens on a reef, and the frame-rate test runs a second time with a reef first.
- **Stills are drawn at the size they are shown at** (`pegBoardStill`; with `PEGBOARD_HEAD_START=1` and `SNAPSHOT_SECONDS=0` it draws the first frame of Settings' own copy, every peg in at full light): a still reduced afterwards shows a weave in the dotted sheet. `docs/images/peg-board.jpg` is the third line above; `peg-board-sailboat.jpg` is the last, a figure whole at Large pegs; `Resources/preview-peg-board.jpg` is the first of those at 1200 wide. The crystal was picked from eight rolls. The sheets in `docs/peg-board/` are stills 756 pixels across, set side by side unreduced: `figures-*.jpg` each figure whole at one peg size; `round.jpg` the owl at Speed 8 from an empty sheet at 3, 11, 25, 45, 71.5, 73.5, 78 and 90 s; `light-show.jpg` the butterfly whole (`PEGBOARD_HEAD_START=1` with `SNAPSHOT_SECONDS` 3 to 23) under `pegboard.seed` 1, 3 and 6, which give the rings, the lobe and the band.
- `draw.py`'s sheet is its charts at one size as plain discs, to look at while drawing. After a change, look at the app's own still of the figure at every size (`pegboard.size` 0, 1 and 2 in the line above) before keeping it.

## Shortcuts

- A crystal is grown on the main thread, while the sheet is dark: 53 to 111 ms at Small pegs, where a reef's 400 now go to another thread. It could be made ahead in the same way (`Reserve`); it draws its numbers from the scene's own generator, so the doc's stills would come out as other crystals. One to fill a 6K display at Small pegs would want that (`snowCrystal`'s `limit` holds it to 48 pitches meanwhile).
- A plate is grown by looking at every hole of its window on every step: about 3 ms on a laptop at Small pegs, and about four times that on a display twice as wide.
- A reef asked for first (`pegboard.pattern=reef`, which only tests and stills do) is waited for on the main thread.
- The outline-first order looks through every peg left for each run: fine to about 5,000 pegs, too slow at 50,000.
- A round's order is shuffled without a look at the round before, so the last figure of one round can be the first of the next: with pictures only, the same figure twice running, about one round in eleven.
- Charts stop at 129 by 90 holes, so on a display much larger than a laptop's a picture sits in the middle of the sheet and does not grow. And a chart goes up only where it fits with a hole to spare all round: at Large pegs on a display under 804 points high (1280 by 800) the four figures of 30 rows (the tulip, the cactus, the balloon and the lighthouse) are not offered.
- The light show's length, the clear and the three shows are fixed numbers, not settings.
- There is no Light Mode look: a black sheet is the toy.
- The halo was fitted to one photograph, and the model's peg is a flat disc: no lean, no side walls, no overlap.

## Still open

**From Dave, having run it** at Large pegs and Patterns only on 2026-10-12 ([his words](#daves-feedback)):

- **Pictures are hard to make out:** answered with the app's own figures, drawn for pegs. [The pictures](#the-pictures) has what he said of them.
- **Only one pattern:** answered with [seven more kinds](#the-patterns) of his picking, in turn with the crystal. He has not seen them running, nor what was [changed after his pick](#the-patterns).
- **A reef's roots sit where the Dock is,** on the bottom rows of the sheet. Left as it is, on the lead's word.
- **Blocks are bright:** three to four times as busy as a crystal and nearly three times its level, as the sheets he picked from said.

**As the builders saw it on stills,** worst first; he has not spoken to these:

1. **Sharp and busy at Softness 0**, the default he chose: see the busy scores above. It is what got Zen Garden cut ("so bright and sharp and not relaxing"), and Softness is the answer he has to hand.
2. **Nearly still at speed 1.** A crystal takes 2 to 3.5 minutes at Medium. A figure takes 0.6 to 1.7 minutes at Large pegs (217 to 623 pegs), 2.4 to 7 at Medium and 5 to 15 at Small. The slider goes to 20×, where the butterfly at Small takes 46 s.
3. **Narrow figures leave the sheet empty.** At Large pegs the rocket, the cactus and the tulip are 18 to 20 holes wide on a sheet of 48, and no figure is taller than 30 rows of the 36 a 14-inch display shows: drawn for a 13-inch one. Nothing fills the sheet as a crystal does.
4. **The figures are plain at Small pegs:** flat areas of thousands of pegs that no hand would set, long to build, and busy (the butterfly scores 18% there and at Medium, against 9.5% at Large). They were drawn for Large.
5. **At Large pegs the lighthouse's two slanting rays are steps** of three and four pegs, and the balloon and the snail are faceted. The light is to one side only, for good: one each side made a cross with the tower.
6. **The light show has been seen over a figure only as stills** four seconds apart (`docs/peg-board/light-show.jpg`), not moving. It takes pegs down to about half their brightness on screen, in a ring, a lobe or a band that drifts across; in a still that is a soft shadow lying on part of the figure.
7. **A change of peg size is a hard cut** to a new sheet.
8. Not checked: the Settings page itself (its test opens a window on the screen), so the head start has been seen only as the scene's first frame, not behind the page; a 5K or 6K display, a 1x display, a scaled display mode (measured in the mock-ups only: the pegs' sharpness drifts up to 3% across the sheet at pitches whose rows land just off a whole pixel).

## Next ideas

- Ornament drawn on the lattice instead of sampled. (Six-fold star patterns sit on a honeycomb exactly, and each star is a hexagram: see `stars` under [Tried and dropped](#tried-and-dropped).)
- More figures, and wide ones that fill a Large sheet (a train, a whale, a row of houses); and figures drawn for the 48 by 36 holes a 14-inch display shows where the display has them.
- A rosette tried in the first mock-ups read as a ship's wheel, and so did the rose part-way through its build until it was laid petal by petal.
- The pegs leaving one by one instead of fading with the sheet.
