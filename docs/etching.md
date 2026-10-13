# Etching

Old etchings, engravings and woodcuts drawn line by line: each one slowly, in one unbroken line, on a screen of grey powder. The screen imitates the Etch A Sketch's: a stylus scrapes the powder off the back of the glass, so the line is the dark inside showing through, and it can never lift. That name is used nowhere in the app.

**Hidden while Dave tests it** (`unfinished: true`). He asked for it on 2026-10-12 (a wallpaper in that toy's style "where intricate public domain images become slowly drawn out over time starting from fresh"), it was researched and mocked up that day, and built the same day in three steps.

**The name is Dave's pick** (2026-10-12): Etching names the old prints being drawn, is not a piece of the toy's mark, and nobody holds it ([below](#names-and-look-alikes)). It was built under the working name "Line Drawing", which is why its module is still `LineRoute`.

## Names and look-alikes

From the rights research of 2026-10-12, which read the US Patent and Trademark Office's records (status pages are `https://tsdr.uspto.gov/statusview/sn<serial>`). Not a lawyer's advice.

- **The toy's name is a registered word mark** of Spin Master Ltd. (reg. 725595, serial 72110281, live), and since 2026-05-05 also for "downloadable computer software applications featuring digital art and drawing" (reg. 8237930, serial 97223677). So the name is not the wallpaper's, and appears in no menu, setting, store listing or keyword.
- **The toy's shape is registered too** (reg. 1587707, serial 73701288): a drawing of a frame, a screen and two circles in the lower corners, with no colour claimed. Red with white knobs is its famous look. So a frame, if one comes, is plainly not the toy's: another material and colour, the dials not in the lower corners.
- **The mechanism is free:** one unbroken line scraped into grey powder. The patents are long expired.
- **Dave asked whether "Etch" alone was safe.** Spin Master holds only the full name and two variants, and ten other owners hold ETCH for other things. It is an ordinary word, but it is the first word of the mark, and beside a grey screen and a dial-drawn line it reads as a reference to the toy. The research's order of risk, low to high: Line Drawing, Etching, Etch, the toy's full name. **Etching** names the pictures, is not a fragment of the mark, and no live mark is exactly ETCHING; Dave chose it.

## Dave's decisions (2026-10-12)

- **The line is unbroken, with shading:** the picture's outlines, then its shading as hatching, the stylus going back along lines already drawn to get from place to place. He saw it beside a line that lifts and chose this.
- **"Screen alone now, frame later."** The screen fills the display. He saw a walnut frame with brass dials and a graphite one mocked up, and chose "our own frame" for later; the picture's rectangle is kept relative to the screen so a frame can take a smaller one.
- **Detail: "Both, as a setting":** the toy's own line width, and a line half as wide. He will judge the default on his desktop; it starts at the toy's.
- **A Speed slider:** "be sure to include a speed slider on the line drawing (etch) wallpaper in case a user wants to see it go faster".
- **The screen follows the system's appearance:** 152 of 255 in Light Mode, 104 in Dark Mode. Changed the same day, once he saw it on his desktop, in Dark Mode: "something off with final etching background color, it does not match any of the mockups that showed a brighter paper like color, is it auto reacting to light and dark theme? it so we need to make the background on etching a configurable option". It was reacting: the mock-ups he approved all showed the bright screen, and his Mac showed the dim one. So the screen is now a setting, Screen: Light (the bright powder, the default, whatever the system is in), Dark, or Match System, which is what it did before. Once that reached his desktop: "the light screen looks right now" (2026-10-12). Light stays the default.
- **Pictures:** "nothing religious". Classical myth is fine.
- **On his desktop, the same evening:** "etching is great", and more drawings are wanted as options later ([the research note](#what-is-wrong-and-next)).
- **The picture fills the screen:** "lets also attempt to scale etching images up to "cover mode" so they fill the screen even if we loose a bit of content, or just make this an option in the settings, I personally would enable this if it was a setting". It is a setting, Fill the screen, and on unless turned off ([below](#filling-the-screen)).

The lead's calls, which Dave has not ruled on: progress follows the wall clock; a finished picture rests, clears softly to a ghost, and the next begins; the gone-over line is darker; the Picture menu has Random first.

## How it works

- **A picture is a route**, not an image: the cells the stylus steps through, in order, on a grid of 1024 × 640 (one cell is one step; the line is 1.44 cells wide). `docs/etching/bake.py` makes a route from a picture; the app ships only routes (`Resources/etching-<name>.route`).
- **The route is stamped once** into two textures, off the main thread (`LineRoute.stamp`, in the `LineRoute` module, which is built optimised even in debug). One holds when each texel is first drawn, as a 24-bit share of the route's clock, and how much of it the finished line covers; the other when it is gone over again, to the same 24 bits, and the ghost of the picture before. Until the stamp lands the screen is bare, which is how a drawing starts anyway; then the picture so far fades up over 0.4 s.
- **One shader compares those times with a clock.** So a frame costs the same however much is drawn, and the CPU does nothing per frame but set the clock.
- **Every read of a texture is at a texel's centre.** SpriteKit smooths any texture a shader reads, whatever its filtering mode says, and a time smoothed between a drawn texel and a bare one is a moment when nothing happened: lines would arrive thin and ragged. With a texel to each pixel that is one read of each texture. Above the 14-inch size the textures have a texel to two pixels each way, and the shader reads the four round each pixel, compares each with the clock, and only then mixes them: a pixel softer, a quarter of the memory. A standalone test before the build found 8.8% of pixels wrong when read at plain coordinates, with `.nearest` or `.linear` alike, and 24 in 5.9 million at texel centres.
- **The clock is the wall's** (`Etching.Cycle`). Which picture is on the screen, the one before it and the moment this one was begun are kept in the defaults (`etching.drawing`, `etching.before`, `etching.began`) and shared by every copy of the scene, so a relaunch, Shuffle or a second display goes on from the same place, and a picture carries on while the wallpaper is covered or the Mac is asleep. Moving the Speed slider, or changing the Detail, moves that moment, so the picture stays as far along as it was.
- **A picture is drawn, rests, clears, and the next begins.** It rests for five minutes at speed 1 (less when hurried, never under 20 s), then clears over 12 s whatever the speed: a soft fade, sooner in some places than others, as a shake lays the powder back unevenly. A ghost of its whole line stays (8% of the way to the dark inside) and fades away under the next picture, over its first six minutes of drawing at speed 1 (`Cycle.ghosting`). As first built the ghost stayed until the next clearing, and a print with big darks left a grey shape under the next picture for its whole time: a flaw, not a feature. The next picture is chosen as the clearing starts and stamped during it, so it begins on the frame the clearing ends.
- **A line drawn once is pale; gone over, it is dark.** The first pass draws a line 62% of the way to the dark inside and the second the rest, so outlines the stylus travels along come out bolder, as on the toy.
- **Going back along a line, the stylus goes eight times as fast** as it draws (`LineRoute.haste`, and `HASTE` in the bake). Nothing new appears while it does, but for a pale line turning dark the first time it is gone over. At twice the drawing pace, as first built, a picture stood still for up to 26 s at a time and for 32 to 39% of its clock; at eight times the longest spell is 3.6 to 6.5 s and it is still for 11 to 14%. The lead asked for this once Dave was to watch it at 1×; a frame with dials that keep turning would be the other answer.
- **The screen is bright or dim by a setting** (Screen: Light, Dark or Match System), read every frame. Changing it, or the system's appearance changing under Match System, eases its two colours to the other's over two seconds, under the picture, with nothing rebuilt: the scene watches the appearance itself (`followsAppearance`), so the app never builds it afresh for one.
- **The picture fills the screen** unless Fill the screen is turned off: its own rectangle on the grid is scaled until it covers the display, and what is over is cut off at the edges ([below](#filling-the-screen)). Turned off, the whole grid is fitted below the top 4% of the screen, clear of the menu bar (a notched MacBook's bar is 3.8%), and centred, with bare powder beside it.
- **The powder** is a 512-texel tile of grain and soft mottle that repeats, a slow unevenness stretched over the whole screen, light from the upper left and a few bright specks. The slow unevenness is kept faint: it read as cloudy patches on a bare screen at the mock-ups' strength. Measured on a bare screen 2560 px wide with the light taken off, the level's spread after an 80 px blur is 0.86% of the level, where the mock-ups' was 1.67% and the first build's 1.43%. The light falls off by 5% across the bright screen and by 2% across the dim one, where 5% read as a vignette.

## Filling the screen

Fill the screen (`etching.fill`, on unless turned off) is where a route's grid goes in the textures, and nothing else (`Etching.placement`). The picture's rectangle, which every route's heading gives, is scaled until it covers the display and centred; what is over lies outside the textures. The menu bar's band is not kept clear: the picture runs under it. The frame line every route begins with is six cells outside the picture, so it is never seen. **One picture is never filled:** the Airship, whose hull would lose both its rounded ends at a 14-inch screen's sides and read as a long box. It is marked whole or not at all (`Etching.whole`) and is fitted inside, below the menu bar, whichever way the switch is; no other picture is marked. Turning it on or off stamps the picture again, as changing the Detail does: the old textures stay up until the new ones land.

- **Nothing waits for a stylus that is out of sight.** In `LineRoute.stamp`, a step whose own line is off the textures' edge takes no time, and the clock it would have taken comes off every time after it. Tried first at the pace of going back along a line, eight times the drawing's: the frame alone held a bare screen for 15 s at the start of every picture. At 64 times it was 1.8 s, more than some pictures ever stand still fitted. A step is out of sight by its own line and not by its width: a row of hatching just off the edge was otherwise waited for, to show a sliver (11.5 s on the fine flea).
- **Under the menu bar is out of sight too.** The bar does not show the wallpaper through it, so a step whose line lies wholly in the top 4% of a filled screen (`placement`'s `covered`) takes no time either. Before it counted, the stylus worked there with nothing else changing for up to 83 s on Mishima Pass (133 fine), whose sky is a band of hatching along the top, 30 s on the flea (43) and 13 s on the Rhinoceros. The line is stamped there all the same, for a display that has no bar.
- **The shared cycle is as it was.** Which picture is up, and when it rests, clears and gives way, still come from the routes' own clocks and the wall's, the same for every display. A display whose picture is cut off finishes drawing before that clock says and rests the longer. So two displays of different shapes are a little differently far along the same route, and turning Fill on or off moves the picture a little along it.
- **The line is wider and the stylus quicker across the glass** by as much as the picture is scaled up: on a 14-inch screen from 1.13 times (Kajikazawa, Polyhedra, Twelve-Pointed Stars) to 1.44 (the Interlace), where the line is 1/494 of the screen's width for the fitted 1/711.
- **Going over a line again** is told from drawing it by the clock between the two passes (`apart`), and that clock is now the display's own. Stamped for a 14-inch screen with and without the time taken off, at most 2,200 of a picture's 0.4 to 2.2 million texels of line differ (the first six pictures) in whether they were gone over.

Measured on 2026-10-12 for a 14-inch screen (3024 × 1964, 1.54 wide for 1 high), at 1×, each as Standard and then Fine, with the fitted figure in brackets. A picture narrower than that screen is cut at the top and the bottom, a wider one at the left and the right, never both. "Still" is the longest stretch in which no texel of the line below the menu bar's band changes, neither drawn nor gone over (`etchingNeverWaitsOutOfSight`). "Back or away" is the longest run of steps back along a line, off the edge or under the bar, by the route alone: the measure of the 3.6 to 6.5 s above.

| Picture | Cut off, at each of | Drawn in, minutes | Still, seconds | Back or away, seconds |
|---|---|---|---|---|
| The Great Wave | top and bottom, 1.7% | 76 (80), 145 (152) | 1.8 (1.8), 0.9 (1.2) | 4.8 (4.8), 4.9 (5.7) |
| The Rhinoceros | top and bottom, 4.4% | 78 (85), 156 (168) | 1.2 (1.4), 1.2 (1.3) | 3.6 (3.9), 4.7 (4.0) |
| A Flea | top and bottom, 8.0% | 70 (80), 134 (150) | 1.2 (2.0), 0.3 (2.1) | 4.3 (6.5), 3.6 (3.8) |
| Interlace | top and bottom, 10.7% | 16 (23), 22 (33) | 0.7 (0.7), 1.1 (1.9) | 5.0 (3.6), 3.6 (3.9) |
| Flying Machine | top and bottom, 8.4% | 25 (27), 46 (49) | 1.5 (2.5), 1.3 (2.4) | 3.7 (5.9), 4.9 (6.2) |
| Mishima Pass | top and bottom, 0.1% | 71 (82), 140 (161) | 1.4 (1.4), 1.4 (2.2) | 4.2 (4.2), 4.4 (5.1) |
| Velocipede | top and bottom, 3.3% | 26 (28), 54 (56) | 0.8 (0.8), 0.8 (0.8) | 3.7 (4.1), 4.3 (4.3) |
| Airship | nothing: kept whole, so fitted (filled, 8.5% at the left and the right) | 26 (26), 42 (42) | 1.2 (1.2), 1.1 (1.1) | 4.3 (4.3), 4.3 (4.3) |
| Polyhedra | left and right, 2.7% | 67 (71), 133 (137) | 2.1 (2.4), 1.7 (2.3) | 4.7 (5.8), 6.2 (6.2) |
| Kajikazawa | left and right, 0.6% | 84 (89), 159 (167) | 1.3 (2.6), 0.8 (2.2) | 4.0 (6.6), 2.8 (5.7) |
| Twelve-Pointed Stars | left and right, 0.2% | 25 (29), 38 (42) | 0.5 (0.4), 1.8 (0.8) | 3.7 (3.5), 3.2 (3.2) |
| Woven Bands | top and bottom, 0.4% | 26 (29), 40 (44) | 0.3 (0.4), 0.8 (0.9) | 4.4 (3.3), 4.4 (3.8) |
| Pont Neuf (Fine only) | left and right, 5.6% | 210 (249) | 0.5 (1.6) | 4.3 (5.4) |

- **Nothing that shows stands still for 2.5 s,** which is what `etchingNeverWaitsOutOfSight` holds; the longest is 2.05 s (Polyhedra), where fitted it is 2.58 (Kajikazawa). That each route be no stiller than it is fitted is not held, because that compares noise: one texel changing in the middle of a run back along lines splits a spell in two. Two routes were stiller filling than fitted by more than a quarter of a second, both under 2 s. The fine Twelve-Pointed Stars, by 1.0 s (1.77 for 0.76): the same 640 steps back along lines either way, which fitted are broken in two by a texel or so changing between them; counting a change only where two texels change at once it is 1.9 s filling and 2.1 fitted. And the Airship at the standard width, by 0.35 s (1.51 for 1.16), two runs back along lines being joined by 118 steps off the left edge: measured before it was kept whole, and no longer so, since it is never filled.
- **Five figures got worse by the route's measure,** most of all Woven Bands at the standard width (4.4 s for 3.3) and the Interlace (5.0 for 3.6): two runs back along lines, with a stretch out of sight between them, now run together. Lines are turning dark through them, and all are inside what the other pictures do fitted (6.6 s).
- **What is lost** on that screen: the top of the Rhinoceros's back, the undersides of its feet and the date over its name; the top of the flea's back and its feet; "Fig. 1" over the Flying Machine, of which the bottom half is left at the top edge; a fifth of the Interlace's pattern, which has no subject to lose. Of the seven added since, the Airship would lose both rounded ends of its hull, the worst of all thirteen, and so is never filled. Pont Neuf loses a strip of the map at each side. The Wave, Mishima Pass and the rest lose nothing that reads.
- **A wider display loses more.** At 16 : 9, of the first six, the cut at the top and the bottom is each 6.8% (Mishima Pass) to 15.9% (the Interlace), 10.5% for the Rhinoceros and 13.6% for the flea.
- **A display with no menu bar** (a second display without one, or a bar set to hide itself) shows the top 4% of a filled screen, and there the line arrives at no pace: each stretch of it all at once, as the stylus would have passed. Most on Mishima Pass, where that is nine minutes of the sky's hatching (18 fine).

## The look, and the real toy

Measured on 2026-10-12 from photos (line widths as a share of the screen's width; levels of 255).

| | The real toy | Here |
|---|---|---|
| A line's width | 1/353 to 1/434 on a soft photo, so too wide; near 1/1200 on a scan of an expert's hatching | 1/711 (Standard), 1/1422 (Fine) |
| Finest hatching | rows 1/610 apart (George Vlosich III's work) | 1/512 (Standard), 1/1024 (Fine) |
| A line drawn once, against the screen | 0.68 to 0.70 of its level, blurred, so the true line is darker | about 0.6 |
| Gone over, against the screen | 0.33 | 0.33 |
| The screen | neutral grey, 137 to 191 with the room's light | 152 (Light), 104 (Dark) |
| The screen's shape | 1.40 to 1.43 wide for 1 high | the display's own |

The photos: a classic toy with an outline drawing, the best unprocessed one found (https://upload.wikimedia.org/wikipedia/commons/5/5a/Etch_A_Sketch_engine_drawing.jpg, CC BY 2.0 per Wikimedia Commons); a close scan and whole works by George Vlosich III (https://gvartwork.com/pages/etch-a-sketch, no licence, reference only); three of Jane Labowitch's (https://www.intrepidtravel.com/adventures/the-worlds-best-etch-a-sketch-artist-does-india/, no licence, reference only).

- **How the experts shade** is what the routes copy: horizontal hatching at an even pitch, then vertical in the darks, then scraped solid, with thick outlines from going over them. Labowitch: "I sometimes have to go over the same area over a dozen times to get the darkest tones" (the page above).
- **How the toy works:** "The inside surface of the glass screen is coated with aluminum powder, which is then scraped off by a movable stylus"; "The "black" line merely exposes the darkness inside the toy" (https://en.wikipedia.org/wiki/Etch_A_Sketch).
- **Not matched:** the real screen has a sheen that moves across it with the light, and its lines are softer and more often doubled, where going back along one misses by a line's width. No sharp unprocessed close-up of a single line was found, and no photo of a cleared screen: the clearing and its ghost are a guess.

## The route's file

Little-endian. `LRT1`; the grid's width and height in cells; the picture's rectangle on it (x, y, width, height); the start cell (x, y), all 16-bit; the number of steps (32-bit); the route's clock as a 32-bit float (cells of drawing, a step back along a line counting an eighth); the length of what follows (32-bit). Then the runs, deflated (raw DEFLATE, which `NSData.decompressed(using: .zlib)` reads): one byte to a run of steps one way, bit 7 set while the stylus goes back along its own line, bits 6 to 4 the direction (east, south, west, north, then the four diagonals from south-east round), bits 3 to 0 the run's length less one.

The app eases each position by one step (a quarter of each neighbour), so corners round a little, and takes the clock along the eased line.

## Making a route

```sh
python3 docs/etching/bake.py <folder of source pictures> Sources/Atrium/Resources          # every picture, standard
python3 docs/etching/bake.py <folder of source pictures> Sources/Atrium/Resources --fine   # every picture, fine
python3 docs/etching/bake.py <folder of source pictures> Sources/Atrium/Resources wave     # one
```

Needs numpy, scipy, Pillow and clang (for `route.c`, the one slow loop). The source pictures are not in the repo: `PICTURES` in `bake.py` gives each one's address, the file name it is looked for under, and its crop, with what else it needed: a sheet turned on its side (`rot`), signatures painted out (`blank`), or a plate's faint construction lines dropped (`lift`). A patent's file is one sheet of the Patent Office's PDF, taken out with `pdfimages` as `bake.py` says. A picture named in `FINE_ONLY` gets no standard route. A bake is the same every time. What it does:

1. **Darkness on the grid:** the picture, cropped, fitted to the grid with a margin, its paper tone taken as bare screen.
2. **Lines:** cells darker than their surroundings (the picture less a 2.5-cell blur of itself), thinned to one cell wide with Zhang and Suen's thinning (T. Y. Zhang and C. Y. Suen, "A fast parallel algorithm for thinning digital patterns", Communications of the ACM 27(3), 1984, https://doi.org/10.1145/357994.358023). Bold strokes are drawn first.
3. **Shading:** six layers switched on by darkness. Horizontal rows every 8 cells, then 4, then 2; vertical columns every 4, then 2; then solid. Neighbouring rows are joined at alternate ends, so the stylus zigzags as a hand does.
4. **One route:** the stylus walks to an undrawn neighbour, straight on first. Stuck, it takes the cheapest way to the nearest wanted cell: back along lines already drawn, or, where a piece of the picture stands alone, across bare screen (a stray mark, costed at twenty times a step back so it is the last resort). The whole picture's outlines come first, then each depth of shading over the whole picture, so a half-drawn picture is a whole composition and not a finished corner.

The fine routes are the same bake on a grid of 2048 × 1280, so everything is half the size: a line half as wide, hatching twice as close.

Tried in the research and dropped: a line that lifts (floating dashes half-way, and two dials could not draw it), finishing the nearest ink first (a finished corner and a bare screen for an hour), hatching alone (stray marks across the bare areas), TSP art and a raster squiggle (neither looks like the toy or like a person drawing).

## The pictures

Thirteen, all landscape, bold, and not religious: six from the first build and seven added later the same day, when Dave picked "More Etching pictures" from a list. Each is shipped as its routes only; the credits are also in `Resources/etching-credits.tsv`, which Settings → About lists. The Picture menu stores its pick by place, so a new picture goes at the end of `Etching.pictures`.

| Picture | Source | Licence | At speed 1 | Fine |
|---|---|---|---|---|
| The Great Wave: Hokusai, *Under the Wave off Kanagawa*, c. 1830–32 | The Met, 45434: https://www.metmuseum.org/art/collection/search/45434 | CC0 (The Met's Open Access; `isPublicDomain` true) | 80 min | 152 min |
| The Rhinoceros: Dürer, 1515 | The Met, 356497: https://www.metmuseum.org/art/collection/search/356497 | CC0, as above | 85 min | 168 min |
| A Flea: Hooke, *Micrographia*, Schem. XXXIV, 1665 | Wellcome Collection, L0084699: https://wellcomecollection.org/works/ajveb66y | **CC BY 4.0: must be credited** ("Wellcome Collection") | 80 min | 150 min |
| Interlace: Bourgoin, *Les éléments de l'art arabe: le trait des entrelacs*, plate 96, 1879 (part) | Getty Research Institute, via the Internet Archive: https://archive.org/details/gri_33125012261786/page/n240 | Public domain (the Archive's record: not in copyright) | 23 min | 33 min |
| Flying Machine: O. and W. Wright, US patent 821,393, Fig. 1, 1906 | US Patent and Trademark Office: https://patents.google.com/patent/US821393A | Public domain (patent drawings; the Office asks to be acknowledged) | 27 min | 49 min |
| Mishima Pass: Hokusai, *Mishima Pass in Kai Province*, c. 1830–32 | The Met, 56346: https://www.metmuseum.org/art/collection/search/56346 | CC0, as above | 82 min | 161 min |
| Velocipede: P. Lallement, US patent 59,915, Fig. 1, 1866 | US Patent and Trademark Office: https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/0059915 | Public domain (patent drawings, as below) | 28 min | 56 min |
| Airship: F. Graf Zeppelin, "Navigable Balloon", US patent 621,195, Figs. 1 and 2, 1899 | US Patent and Trademark Office: https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/0621195 | Public domain (patent drawings, as below) | 26 min | 42 min |
| Polyhedra: Jost Amman after Wenzel Jamnitzer, *Perspectiva Corporum Regularium*, plate F.IIII, 1568 | The Met, 339008: https://www.metmuseum.org/art/collection/search/339008 | CC0 (`isPublicDomain` true) | 71 min | 137 min |
| Kajikazawa: Hokusai, *Kajikazawa in Kai Province*, c. 1830–32 | The Met, 56727: https://www.metmuseum.org/art/collection/search/56727 | CC0 (`isPublicDomain` true) | 89 min | 167 min |
| Twelve-Pointed Stars: Bourgoin, the same book, plate 98 (part) | Getty Research Institute, via the Internet Archive: https://archive.org/details/gri_33125012261786/page/n244 | Public domain (the Archive's record, as below) | 29 min | 42 min |
| Woven Bands: Bourgoin, the same book, plate 71 (part) | Getty Research Institute, via the Internet Archive: https://archive.org/details/gri_33125012261786/page/n190 | Public domain (the Archive's record, as below) | 29 min | 44 min |
| Pont Neuf (Fine only): Louis Bretez, engraved by Claude Lucas, *Plan de Paris* (the Turgot map), sheet 11, 1739 (part) | Norman B. Leventhal Map & Education Center, Boston Public Library; the file from Wikimedia Commons: https://commons.wikimedia.org/wiki/File:Turgot_map_of_Paris,_sheet_11_-_Norman_B._Leventhal_Map_Center.jpg | Public domain (as below: the holder says "No known copyright restrictions") | none | 249 min |

The licence lines, as read at their sources on 2026-10-12:

- **The Met** (five prints): each object's record in its API has `isPublicDomain` true (`https://collectionapi.metmuseum.org/public/collection/v1/objects/<id>`), and its API page says the dataset is under Creative Commons Zero (https://metmuseum.github.io/).
- **Wellcome** (the flea): "You can use this work for any purpose, including commercial uses, without restriction under copyright law. You should also provide attribution to the original work, source and licence." (its page, above; read by the rights research).
- **Patent drawings** (three): "Subject to limited exceptions reflected in 37 CFR 1.71(d) & (e) and 1.84(s), the text and drawings of a patent are typically not subject to copyright restrictions." (https://www.uspto.gov/terms-use-uspto-websites). The sheets used carry no copyright notice.
- **Bourgoin's book** (three plates): the Internet Archive's record gives `possible-copyright-status` as `NOT_IN_COPYRIGHT` and names no licence (https://archive.org/metadata/gri_33125012261786). Bourgoin died in 1907.
- **The Turgot map:** the Boston Public Library's repository gives the atlas "No known copyright restrictions." and "No known restrictions on use." (https://www.digitalcommonwealth.org/search/commonwealth:3f462t71h). That record is the atlas of twenty sheets; the sheet's own page at the Map Center answered with an error on both tries that day. Wikimedia Commons tags the file "Public domain". The holder's words are not "public domain", though an engraving of 1739 is: worth a second look before a public release.

Nothing religious, by looking at each whole picture and not its title. The Pont Neuf crop took the most care: it was cut to leave out a church at its right edge (on the quay the sheet labels "Augustins") and a hall with tall round-arched windows along its top, and the two buildings the sheet marks with a cross nearby lie outside it, one above and one below. What it shows is the bridge, Henri IV's statue, Place Dauphine, the quays, boats, and the pump house on the bridge, which the sheet labels "Samaritaine": a building with windows here, its label a squiggle once drawn. (The real pump house was named for a carving on its front, from memory; nothing of that can be seen at this size.)

- **Twelve work at both widths.** Fine is the better picture every time: the Rhinoceros gets its scales and plates back, the patents' reference letters become legible, and the polyhedra get their engraved shading.
- **Pont Neuf is fine only.** At the standard line the river's ruled water and the houses' windows turn to a muddle; fine, it is the most intricate picture in the set and the longest, over four hours at speed 1. It ships with no standard route. Picked by name it is drawn fine whatever Detail says, and its name in the menu says "(Fine only)"; Random draws it only while Detail is Fine (`Etching.fineOnly`, `Etching.choices`). That is the least code that is honest about it: a menu whose picks depend on another menu would have needed new machinery in Settings.
- **Kajikazawa's sky is the second set's weak spot:** the print's graded band along the top becomes rows of hatching, as Mishima Pass's does, though narrower and paler. A lighter tone curve thinned the band but lost the fishing lines, so it is kept as it is.
- **Mishima Pass at the standard width is the weakest:** the print's graded sky becomes a dark band of hatching along the top, and the ground under the tree is muddled. It is kept because it reads as a tree, a mountain and clouds, and is clearly better fine. A candidate to cut.
- **What suits a single line,** from nine pictures tried: one large subject or one bold pattern, its lines at least two line-widths apart, landscape. Patent drawings, geometric ornament, a natural-history plate of one specimen and bold woodcuts work. Fine tonal engraving, crowded charts and anything that depends on lettering do not: Dürer's *Melencolia I* came out a muddle (and its winged figure reads as an angel, so it is out anyway), and his star chart a tangle.
- **Dropped:** Hokusai's *Ejiri in Suruga Province* (The Met, 36493), because it shows a wayside shrine.
- **Tried for the second set and dropped:**
  - Hokusai's *South Wind, Clear Sky* (The Met, 36490): no outline to speak of, so it came out as a field of stripes for a sky, worse than Mishima Pass. *Storm below Mount Fuji* (36492) was not baked: it is nearly all dark tone, and The Met's file is small.
  - Sikorsky's helicopter (US patent 1,994,488, sheet 1): three figures and dozens of reference numerals, so at the standard line it is a scatter of squiggles round a shape that is hard to read.
  - Not baked, from looking at their sheets: Edison's phonograph (US patent 200,521), a long narrow figure with a large solid disc; and Lilienthal's glider (544,816), a fan of hatching with a small figure.
  - A crop of de' Barbari's *View of Venice* at the Arsenal (Cleveland Museum of Art, 1949.565, CC0): dense even when fine, and it reads as texture more than as a place. The Pont Neuf does the same job better.
  - A Bourgoin plate with curves: none found. Small pictures of 92 of the first 113 plates were looked at; the few that look curved small (plates 14 to 16) are bands of short straight runs at full size, and sparse, so they were not baked.

## Settings

| Setting | Range | What it does | Default |
|---|---|---|---|
| Picture | Random, or one of the thirteen | Random draws a different picture each time. Picking one clears the screen for it there and then, and it is drawn over and over | Random |
| Detail | Standard, Fine | the line's width: the toy's own, or half that. The picture stays as far drawn as it was and is stamped again | Standard |
| Speed | 1× to 60× | how fast the stylus goes. At 1× it crosses a fortieth of the grid's width a second as it draws and a picture takes 23 to 89 minutes (33 to 168 fine, and 249 for the one that is fine only), less where part of it is cut off; at 60× the longest takes a minute and a half (just over four, fine) | 1× |
| Screen | Light, Dark, Match System | the powder: bright (152 of 255) or dim (104) whatever the system's appearance, or bright in Light Mode and dim in Dark Mode. A change eases over two seconds, under the picture | Light |
| Fill the screen | on, off | on, the picture is scaled until it covers the display and what is over is cut off at the edges; off, it is fitted inside, below the menu bar, with bare powder beside it. The Airship is fitted inside either way. The picture is stamped again and goes on from about where it was | on |

Three more keys, with no page in Settings, set a scene up for the tests and for pictures of it; with any of them the scene keeps a cycle of its own and saves nothing: `etching.drawn` (0 to 1) starts it that share of the way through its picture, `etching.cleared` (0 to 1) that far through its clearing, and `etching.ghost=1` lays the next picture's ghost under it.

The screenshots (`docs/images/etching.jpg`, the dim screen, and `-light.jpg`, the bright one) are the Great Wave 70% drawn and fitted inside the screen (`etching.drawn=0` gives the bare screen the unevenness was measured on). They were made when the screen followed the appearance, and before Fill the screen; now each is asked for by name (`etching.screen=0` Light, `1` Dark; `etching.fill=0` fitted):

```sh
SNAPSHOT_SCENE="Etching" SNAPSHOT_DEFAULTS="etching.drawn=0.7,etching.picture=1,etching.screen=1,etching.fill=0" swift test --filter everySceneRenders
```

The Settings page has one still, `preview-etching.jpg`, of the bright screen, in both appearances: the page's live copy is bright as it comes, and a dim still in Dark Mode would fade to a bright picture.

## Cost

Measured by the render test on a 14-inch screen at 2x (M3 Max, 2026-10-12): **0.45 to 0.65 ms of CPU and 0.22 to 0.29 ms of GPU a frame**, whatever the picture, its detail and however much of it is drawn, in on either screen and while clearing.

- **Building:** a standard route decodes in 2 ms and stamps in about 120 ms for 3024 × 1964, off the main thread; a fine one, of four times the steps, in about 150 ms. Filling the screen, where the line is wider, 49 to 161 ms, and 56 to 270 ms fine (fitted, 38 to 128 and 50 to 259). A scene built part-way through a picture stamps the one before as well, for its ghost.
- **Memory:** the two textures are 48 MB at that size, and a byte a texel more (6 MB) is kept for the next ghost. At 5K, with a texel to two pixels each way, 28 MB; at 6K, 39 MB.
- **Shipped:** twenty-five routes, 1.9 MB (the first six pictures' twelve were 942 KB).
- **Not timed in the app:** a 5K or 6K display (a test draws the picture at 5K through the four-read shader). A standalone copy of the shader, timed the same way before this was built, took 0.57 ms of GPU at 5K and 0.79 at 6K. Nor a GPU slower than an M3 Max, nor the frame on which a texture is first sent.

## Checking it

- `lineRouteDecodesToItsKnownLength`: the Wave's route has the steps and the clock its bake printed, stays on its grid, and never lifts.
- `lineRouteStampsItsTextures`: the stamp covers a fifth of a 14-inch screen, its first row of bytes is the bottom of the screen (SpriteKit's order), and going over a line again is recorded. Prints the decode and stamp times.
- `etchingHasEveryPictureAtBothWidths`: all twenty-five routes decode on their grids; the one picture with no standard route is the one whose name says so, and Random leaves it out at Standard; and the longest is done in under five minutes at the top of the Speed slider.
- `etchingLooksTheSameAtAnyFrameRate`: 15, 30 and 60 frames a second give the same picture to the pixel.
- `etchingCycleFollowsTheClock`: drawing, resting, clearing and the next picture by the clock alone; the Speed slider and the Detail leave a picture as far along as it was; a picked picture follows at once; a day away comes back to a picture part-way through.
- `etchingClearsToAGhost`: full, half cleared and a ghost hold less and less line; and the picture is drawn at a 5K display's size.
- `etchingDrawsTheFineLine`: the fine route is drawn, with a thinner line, and fitted inside the screen nothing is drawn under the menu bar; and the fine-only picture is drawn the same whatever Detail says.
- `etchingFillsTheScreen`: the Interlace's line runs off the top and the bottom of a 14-inch screen, and off the left and the right of the same screen turned upright; with Fill the screen off there is no line at any edge, nor under the menu bar. The Airship, kept whole, has no line at any edge with it on, and is the same picture as with it off.
- `etchingNeverWaitsOutOfSight`: for every route a picture ships, on a 14-inch screen with Fill the screen on, the longest stretch in which nothing that shows, below the menu bar, changes is under 2.5 s, and the drawing is done no later than fitted. Prints both for each, filling and fitted.
- `etchingFollowsTheAppearance`: set to Match System, the screen's level goes from Light Mode's to Dark Mode's in two seconds.
- `etchingScreenIsTheOneAskedFor`: as it comes the screen is the bright one in Dark Mode; set to Dark it eases to the dim one, and is the dim one in Light Mode.

## Shortcuts

- A texel takes the time of the pass that covers it most, and the finished line's cover. Where a later line overlaps an earlier one's edge by a sliver, that sliver shows with the earlier line (`ponytail:` in `LineRoute.stamp`).
- The stray marks that join separate pieces are part of every unbroken route: 536 cells of them on the Wave.
- The tracer is not an artist: shading in small pale areas turns into boxy meanders, hatching never follows a form, and at the standard width lettering is illegible.

## What is wrong, and next

- **Filling the screen cuts into three subjects** on a 14-inch screen, and further on a wider display: the Rhinoceros's back and feet, the flea's back and feet, and the Flying Machine's caption ([Filling the screen](#filling-the-screen)). Only the Airship, which lost both ends of its hull, is kept whole (`Etching.whole`). A picture could carry how much of itself may be cut, or be baked to a wider crop.
- **Seen on a desktop by Dave alone.** What the builders judged is all from the render test's pictures. He has since run it on his own desktop and called it great (2026-10-12). No builder has opened the Settings page: the test that does it puts a window on the screen.
- **At 1× the picture still stands still for a few seconds at a time** while the stylus goes back along its line: up to 4.8 s on the Wave and 6.5 on the flea, 11 to 14% of the clock. A frame with dials would show them turning then.
- **The Settings page's live copy shows the same moment as the desktop,** so in a picture's first minutes it is a nearly bare screen.
- **A frame with dials** ("frame later"): the screen is 1.40 : 1 on the toy, so a frame costs picture (62% of the display in the mock-ups). Dials would turn about five times to cross the screen; a fine knurl strobes at 15 frames a second, so theirs would be coarse or blurred.
- **More pictures, to research:** Dave, 2026-10-12, having run it on his desktop: "we will likely want to add more etching drawings as options in the future, make a future research note for that". The set is thirteen. For the round that adds to it:
  - **Start with** what the first shortlist of 25 left untried: Ramelli's book wheel, Nolli's plan of Rome, Waldseemüller's world map, Haeckel's line plates of radiolaria. Then more of the kinds already in the set: woodcuts and engravings with a bold line, patent drawings, scientific plates, pattern books, old city plans.
  - **Where the thirteen came from**, each with terms that allow shipping: The Met's Open Access (CC0), the Wellcome Collection (CC BY 4.0, credited), the Getty Research Institute by way of the Internet Archive, the Leventhal Map & Education Center at the Boston Public Library, and US patent drawings ([The pictures](#the-pictures) has every address).
  - **Rules:** nothing religious (classical myth is fine); public domain, CC0, CC BY or CC BY-SA only, the licence read at its source and quoted in the table; landscape, or a landscape crop.
  - **What to check before a picture goes in:** that it reads at the standard line and not only the fine one (Pont Neuf ships fine only); how long it takes at speed 1 (the set runs 23 to 89 minutes); the longest the screen stands still while the stylus goes back; and what Fill the screen cuts from it on a 14-inch and a wider display ([Filling the screen](#filling-the-screen)).
  - **What one costs:** two routes of about 75 KB each in the app, a line in `etching-credits.tsv`, an entry in `PICTURES` in `bake.py` and a row in the table. The Picture menu stores its pick by place, so new ones go at the end of `Etching.pictures`.
  - The menu is fourteen long already (Random and thirteen) and flat: a `.choice` menu has no groups. A much longer set may want them, by kind or by maker (the lead's view; Dave has not been asked).
