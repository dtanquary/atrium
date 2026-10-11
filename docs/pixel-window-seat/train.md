# Pixel Window Seat: a train (being built, hidden)

A third window for [Pixel Window Seat](../pixel-window-seat.md): a seat on a slow train, the country sliding past under the real Sun, Moon and stars for your clock and place, with rain on the glass when it rains where you are. It began as "Pixel Night Train" in the 2026-10-10 brainstorm ([ideas.md](../ideas.md)); Dave picked it as "an addition to pixel window seat, doesn't have to be its own wallpaper".

That day two agents researched it (one read the code and worked the geometry, one measured real footage) and one round of mock-ups went to Dave. It is being built on the branch `night-train`, hidden from everyone until Dave has seen it move: [The build so far](#the-build-so-far) says what is in. This page is the plan, the findings and their sources. The two reports in full: [the engine](train-research-engine.md) and [the footage and scenery](train-research-footage.md). When it is built, it becomes a part of `pixel-window-seat.md`.

## Dave's decisions (2026-10-10)
- **Where it lives:** inside Pixel Window Seat, not its own wallpaper.
- **Settings switch:** one menu of three, "Window on: An airliner, A train, The space station", in place of today's Earth orbit switch. Anyone with Earth orbit on must keep it (`seat.orbit` shipped in v0.107.0-beta).
- **Carriage:** all three as a Settings choice: a plain window, a sill and a curtain, a table and its lamp (sheet 1, tiles A, B, C). I recommended the table; he took all three.
- **1× on the Speed slider:** 48 km/h, a slow scenic train.
- **Poles and wires:** yes, with a Settings switch, on by default: a line of telegraph poles 28 m out, 50 m apart, with two wires that rise to each pole and sag between (sheet 2, tile F, and its film).
- **Rain on the glass** when it rains where you are: yes, on by default, with a switch and a preview menu (tile G).
- **Scenery in the first version,** besides countryside: lake and coast (tiles D and E), mountains, snow, desert and city. He ticked all four offered.
- **The glass after dark:** the lamp's ghost only, with the table; no ghost of the whole cabin.

Not asked yet: stations, tunnels and passing trains; which railway (overhead wires, telegraph poles, the steam age: the mock-up drew telegraph poles); a line running high above a valley.

## Dave's feedback
- **2026-10-11, the first build on his desktop** (countryside and the lake, the plain window, a clear sky): "night train has potential, please spin up developer agents to work on all the pending 'still to build' items and get them integrated". Those items, as listed to him: clouds, weather and rain on the glass, the three carriage interiors, and mock-ups then builds of mountains, snow, desert and the city. They are being built in three streams, each on a branch of its own: the sky and weather, the carriages, the four sceneries.

## The finding that shapes it
A thing `Z` metres from the track slides `focal × speed / Z` pixels a second, whatever its height and whatever the eye's height. With the airliner's lens (focal 265 art pixels):

| Z | px per m | px/s at 40 / 80 / 120 km/h |
|---|---|---|
| 5 m | 53 | 589 / 1179 / 1768 |
| 20 m | 13 | 147 / 295 / 442 |
| 110 m | 2.4 | 27 / 54 / 80 |
| 300 m | 0.88 | 10 / 20 / 29 |
| 1 km | 0.27 | 2.9 / 5.9 / 8.8 |
| 8 km | 0.033 | 0.4 / 0.7 / 1.1 |

For scale, what Dave has accepted as calm: the airliner tops out at 3.3 px/s of ground at 1×, and Pixel City's cars run 14 to 22 px/s.

- **The near field is a blur at any real speed.** At 80 km/h everything within 200 m moves more than a pixel a frame. A mast 4 m out crosses the pane in 7 frames.
- **Flat ground is the wrong thing to draw.** From 3 m up, all the ground beyond 200 m is 4 rows of the picture. The calm part of a train's view is things standing against the sky.
- **What doesn't help:** a real sill (it hides only the nearest 5 to 8 m; the blur runs from 5 m to 200 m), an upper deck (4.5 m buys two rows), looking ahead (the trailing edge gets up to 1.41 times faster).
- **What does:** a slow train; nothing separate drawn nearer than about 110 m; a low horizon and a big sky; water beside the line, which has nothing in it to blur; a line that runs high, 10 to 20 m above a valley or a shore, so the land starts 40 m and more away.

Real footage agrees. Measured on four openly licensed clips (bands of each frame cross-correlated a frame apart): sideways speed is zero at the horizon and grows in a straight line below it (r = 0.993 to 0.999), exactly as in the airliner, but about 100 times faster, since the eye is 3 m up and not 11 km. On a Swedish regional train at about 60 km/h the far tree line took 10–25 s to cross the frame, a field a tenth of the frame's height below the horizon 2.5 s, the bottom edge 0.45 s. A wall of trees 5–15 m off is full-frame flicker, the least calm thing a train window shows. A bullet train on a viaduct flows no faster than a country train on the flat.

## How it would be built
A third scene, `PixelTrain` in `Sources/Atrium/PixelTrain.swift`, picked in `pixelWindowSeat(size:)` as `PixelOrbit` is. The same kind of scene: one picture painted on the CPU into a mutable texture, the carriage a second texture over it.

- **Standing rings.** About 11, at fixed distances from 110 m to 60 km. A ring is a strip of palette bytes one pane wide; its foot sits `eye × focal / Z` rows under the horizon, and a metre stands `focal / Z` pixels. Each slides by whole pixels and lays a column once, as it comes in at the leading edge, as the airliner's rows do. Near rings are filled from small drawn stamps (a tree, a fir, a house, a church), far ones from a height line (the land's swell with its fields, hills, ranges). Painted far to near.
- **Ground rows**, one per picture row under the horizon: fields in belts of distance beyond 100 m; nearer, one crop for a long way, drawn out into soft dashes each at least twice as long as its row moves in a frame, so nothing in it can strobe. Level lines (a lane and its hedge at 62 m in the mock-up) stay still on screen and give the near field structure.
- **Sky rows:** the airliner's cloud layer seen from below, 1.2 km up, each row above the horizon one distance.
- **The world stays stateless:** what stands at column n of ring k comes from hashes of the place, so every display and Settings' preview see the same country.
- **One rule keeps it calm at any speed:** thin things (poles, trunks, lamps) only on rings moving under about 30 px/s, broad things under about 60. As Speed goes up the near rings empty and the far country carries on.
- **Reused as they are:** the pane and window sizes, the canvas, the sky colour tables, `SeatWorld`'s cloud, storms and far ranges, the Settings gates, the time preview, `LiveWeather` and `GlassWeather.rainAmount`.
- **To lift out of the airliner first:** its sky painter (about 90 lines inside `redraw`) and the cabin's outline; both must leave the airliner's pictures the same byte for byte.
- **Doesn't carry over:** the airliner's flat-ground world, a map seen from above.
- **Cost (estimated):** 1.0–1.4 ms of CPU a frame at Large, against the airliner's 0.77–1.18, since the near ground moves every frame. About 100 KB of rings. No data files.

## The build so far
Hidden: Settings offers the train only with `unfinished` set (`defaults write com.dtanquary.atrium unfinished -bool true`, then relaunch), the switch that shows a wallpaper hidden as unfinished. Without it the page, what it stores and every picture are as they were. In a test or a snapshot, which read their own defaults: `SNAPSHOT_DEFAULTS="unfinished=1,seat.orbit=2"`.

### Step 1, the mode menu (2026-10-11)
- **In:** `seat.orbit` keeps its key and now says which window: 0 the airliner, 1 the space station, 2 the train (`PixelOrbit.mode`). Without `unfinished` it is the Earth orbit switch it was. With it, it is a menu, "Window on: An airliner, A train, The space station", listed in that order and stored 0, 2, 1 (`Knob.order`), so a stored 1 is still the station.
- **Gates on a menu's pick:** `Knob.shownAt` and `hiddenAt` (Settings.swift). The airliner's Seat shows at 0 and the orbit's five rows at 1; Looking, Scenery and the time preview hide at 1 only, so the train has them.
- **The train's rows for now:** Window on, Window, Looking, Speed, Scenery, Clouds, Lightning, the time preview. Its own (the carriage, poles, rain) come with their steps.
- **Checked by running:** `windowSeatOffersTheTrainOnlyUnfinished` (the switch's page lists the same rows as before for the airliner and the station; the menu's page lists each window's own; a stored 1 opens the station; the Speed slider is held by Follow the real ISS only at the station). The 25 pictures of `shots.sh` (the airliner's fourteen documented screenshots and one with the Medium window; the orbit's nine and one with no window) are the same files before and after, byte for byte, and two runs of one build are the same too. All 69 tests pass in a release build.
- **Not checked:** the Settings window itself, which the test can only photograph by opening it on screen: `SETTINGS_SHOT="Pixel Window Seat" swift test --filter settingsWindow`, then with `SNAPSHOT_DEFAULTS="seat.orbit=1"`, and for the menu with `SNAPSHOT_DEFAULTS="unfinished=1,seat.orbit=2"`. The app was not run.
- **Wrong, or a shortcut:** picking the train still flies the airliner, until step 3. If `unfinished` is taken away again after the train was picked, the stored 2 reads as the switch on and flies the station with the station's rows hidden, until the switch is touched (a `ponytail:` on `PixelOrbit.picker`).

### Step 2, the sky and the pane's outline lifted out (2026-10-11)
- **In:** `SeatSky` (PixelWindowSeat.swift): the airliner's own lines for where the Sun and Moon stand, the banded sky with its glare, stars, Moon and Sun, and the light on the land (the Moon's, the sky's, the Sun's, the haze's colour and the veil's), moved out of `redraw` into a type that takes a moment, a place, Settings' Looking, a pane's size and the row of its horizon. The airliner builds one every 30 s and reads it. `PixelWindowSeat.outside(_:_:_:round:)` is the pane's outline for any pane and any corner radius; the airliner's own is its default.
- **Left alone:** the orbit's frame keeps its own copy of the outline (PixelOrbit.swift, `paintFrame`), since it also needs the two half-measures the outline is made from, for its bolts.
- **Checked by running:** the 25 pictures of `shots.sh` are the same files as before step 1, byte for byte. All 69 tests pass in a release build. No new compiler warnings.
- **Not checked:** a sky for any horizon but the airliner's (62% up the pane); the train's is lower, and step 3 is the first to build one. The app was not run.

### Step 3, `PixelTrain`: rings, the slide, far-to-near painting (2026-10-11)
- **In:** `Sources/Atrium/PixelTrain.swift` holds the scene (`PixelTrain`), the country (`TrainWorld`) and its materials (`TrainMat`); `pixelWindowSeat(size:)` builds it while `seat.orbit` is 2. Eleven rings from 60 km to 110 m, each a strip of materials a pane wide that slides by whole pixels and lays a column once; the ground a row at a time; the shared sky over a horizon 30% up the pane; and round the pane the plain window of sheet 1, tile A, drawn through the lifted outline.
- **What the rings hold so far:** hills and ranges as lines of heights (60, 30 and 15 km); the land's swell with hedged fields and patches of wood on its face (7 km to 500 m) and a ragged line of woods along its top. The three nearest (300, 180 and 110 m) are empty until step 4's stamps. The ground: fields in belts beyond 100 m; the lane and its hedge 62 m out; then one crop for a long way and the railway's grass, as soft dashes.
- **`TrainWorld` is `train.py` line for line,** in doubles and with Python's rounding (to the nearest even), so it can be checked against the mock-ups' painter: `TRAIN_MATCH=/some/folder swift test --filter trainWritesItsCountry`, then `python3 docs/pixel-window-seat/train_match.py /some/folder`.
- **The light** is the airliner's (the sky's and the Sun's, from `SeatSky`) without its veil of air, times 0.78 so that a material at one in the afternoon is its own colour. The night is lifted 3.9 times, with a floor of (9, 13, 27), and things fade to the horizon's colour over 26 km. Both numbers were set by measuring the build against the mock-ups at the same hours: the near field is (119, 167, 91) by day against the mock-up's (119, 165, 88), and (21, 35, 50) at night against (24, 31, 47).
- **The sky looks higher than the airliner's,** 30° up against 18°. `SeatSky` takes `bands`, the rows the sky needs to go from the horizon's colour to the zenith's: the train gives it the airliner's (38% of the pane's height), so the two windows have one sky at one height, and above that it goes on deepening toward (0.3, 0.69, 0.88) of the zenith's colour. That is what the mock-ups did by carrying the airliner's top band on up. By day the top of the pane is (25, 82, 161) against the mock-up's (21, 78, 159); stretched over the whole taller sky, as it first was, it was (56, 110, 179) and pale for a long way up.
- **Checked by running:**
  - **Against the mock-ups:** 660,960 bytes compared, 0 differ: the eleven rings' strips and the 66 ground rows (material, and which tone of its dash) at four places along the line, metre 52,000 (the sheets') among them. Changing one byte makes it report 1.
  - **The slide,** `trainSlidesByDistance`, pixels moved in two seconds against `focal × speed / Z × 2`: 60 km 0 (0.12), 30 km 0 (0.24), 15 km 1 (0.47), 7 km 1 (1.01), 3.5 km 2 (2.02), 1.8 km 4 (3.93), 900 m 8 (7.86), 500 m 15 (14.14), 300 m 24 (23.57), 180 m 39 (39.29), 110 m 65 (64.29).
  - **The same, measured in pictures** (frames a second apart from a film, each row of the picture matched against itself shifted): the tree line 7 px a second (7.07 by the law), and ground rows 6, 10, 14, 24, 44 and 62 under the horizon 23, 38, 54, 92, 167 and 236 (22.9, 38.1, 53.3, 91.4, 167.6, 236.2).
  - **Any size:** `trainRunsAtAnySize` builds and runs it for a laptop, a portrait display, an ultrawide one and two tiny ones, with each size of window and with none.
  - **Cost,** release, 2x, 1512 × 982, Large window, four runs taken in turn with the airliner: 0.63 to 0.74 ms of CPU a frame (0.69 to 0.80 with no window), against the airliner's 0.87 to 1.06 (1.11 to 1.19). GPU 0.09 to 0.43 ms for both; it is noisy (one picture read 0.13 and then 0.43).
  - **What ships:** the 25 pictures of `shots.sh` are still the same files as before step 1. All 72 tests pass, in release and in debug.
- **Looked at,** each reduced to its art pixels and enlarged four times, so nothing was resampled: one in the afternoon, 18:18, 18:36, 19:36 and 23:00 on 11 October at the fallback place, at `TRAIN_AT=52000` (`TRAIN_AT=52000 SNAPSHOT_DEFAULTS="unfinished=1,seat.orbit=2,seat.previewTime=1,seat.previewHour=13" SNAPSHOT_SCENE="Pixel Window Seat" swift test -c release -Xswiftc -enable-testing --filter everySceneRenders`); and six frames a second apart. By day it is sheet 1's country without its trees, houses and cloud. At sunset the glare stands over the land where the Sun went down and the far fields take the horizon's orange. At night the land is a navy shape under the stars.
- **Wrong, or not done:**
  - **Nothing is lit at night** and nothing stands near the line: lamps, trees, houses and the lane's poles are step 4. Until then the near field is one flat slab, by day and by night.
  - **At sunset the near field is cooler than the mock-ups' light would make it,** (51, 74, 68) against (60, 51, 40) at 18:36. Their warmth was the airliner's orange haze, which 11 km of air gives and a field 50 m off doesn't have. No sheet Dave saw was at sunset.
  - **Three pale specks under the Sun** on 11 October are the Moon, a day old: the shared sky draws a thin crescent as a few pixels, in the airliner too.
  - **The frame is not matched to the mock-up** pixel for pixel; that is for the carriages step.
  - **Moving the Speed slider lays the near ground's dashes again,** since their length goes by the speed, so they jump as it moves.
  - **No cull by speed yet,** and nothing above 1× has been looked at.
  - **Not looked at:** any window size but Large, a portrait or an ultrawide display (the test only builds and runs them), Settings' preview, the app.

### Step 4, the country (2026-10-11)
**What stands on the rings** (the first of this step's commits).
- **In:** the mock-ups' stamps, ported like the rest: a broadleaf tree, a fir, a house (render, brick or stone, hipped or gabled, with windows and a chimney) and a village church, one thing to a plot of track; the lane's poles on the 300 m ring; and lamps. A cell's top bit marks a lamp: a house's window (four in five of them), or a light in a town on the far swells. Lamps come on through dusk, each at its own draw, as the airliner's do.
- **Lit from the Sun's side:** stamps are lit from the right or the left of the picture by where the Sun is (`TrainWorld.sun`), and everything is laid again when that changes. With the Sun within 15° of straight ahead or behind, the side stays as it was.
- **The cull** (`TrainWorld.thin` and `broad`): a ring lays nothing thin (a lamp, a pole, a church's spire, a hedge's end in a ground row) where it slides faster than 36 px a second, and nothing that stands (a tree, a house) faster than 60. The plan said about 30 for thin things; the sheets' own field hedges reach 34 at 1×, so it is 36. A trunk counts as part of its tree. At 1× nothing is culled; the nearest ring's trees go at 1.9×, its neighbour's lamps at 1.8×. A change of Speed lays everything again.
- **Lights that show only after dark, added to the mock-ups' country** (and to `train.py`, so the two still agree): its own had a minute in the hour's test with no lamp in view, and several with one to three. Far off (the 7, 3.5 and 1.8 km rings), the windows of farms too small to draw, a few together, on the swell's face or at its foot; nearer (900 to 180 m), a lamp in a farm's yard 4 to 7 m up, in three plots of ten. They are lamps with nothing drawn under them, so the day's picture is the sheets'.
- **Checked by running:** against the mock-ups, 660,960 bytes compared, 0 differ, now with stamps, the lane's poles and lamps on both sides (the strips compared hold 854 lamps). `trainNothingThinIsFast`: at nine speeds from 0.5× to 10×, 6,000 columns of each ring. `trainNightIsNeverBlack`: lamp pixels showing, a minute apart for an hour from metre 52,000, as the painter shows them: 2 at the least (a wooded stretch), 15 to 35 as a rule, 50 at the most. Before the added lights the same hour ran from 0 to 43.

**The pole line** (the second commit).
- **In:** the telegraph poles of sheet 2, tile F, 28 m out and 50 m apart, 8.2 m tall, with two wires that rise to each pole and sag between (`TrainWorld.poleLine`), painted in front of everything, its wires at two thirds. Settings: **Poles and wires beside the line** (`seat.poles`, on by default), a row of the train's own.
- **It is the exception to the cull,** by Dave's pick: at 1× a pole slides 126 px a second, 4 a frame, crosses the pane in 2.7 s, and one passes every 3.75 s. It is the fastest thing with a shape. From 1.8× (230 px a second, a pole across in under a second and a half) the line is left out (`TrainWorld.poleLimit`); that number is mine, not Dave's.
- **A pole slides in and out at the pane's edges.** The mock-up drew one only once all of it was inside, so its arm appeared six pixels at a time.
- **Settings' rows for the train** are now Window on, Window, Looking, Speed, Poles and wires, and the time preview. The airliner's Scenery is the airliner's alone (the train gets a menu of its own with the lake), and Clouds and Lightning hide for the train until cloud is painted from below (a `ponytail:` on them). Without `unfinished` the page lists what it did.
- **Checked by running:** the pole line's pixels against `train.py`'s at four places, 300,560 more bytes, 0 differ, leaving out the columns of a pole that is half in view (961,520 compared in all). The 25 pictures of `shots.sh` are the same files as before step 1.

**The lake** (the third commit).
- **In:** sheet 2's lake, tiles D and E. `TrainWorld.shore` says how far from the track the land reaches before the water, at a place along the line. A row of ground beyond the shore is water, and a ring nearer than the far shore (the 1.8 km ring) lays nothing where it stands in the water; a tree whose plot is in the water is left out whole, not cut at the shore. The pole line has poles only on land, and a wire only between two poles that stand.
- **The water** goes by where a pixel is on the pane, not by what slides under it, as in the mock-up: each row is the sky that many rows above the horizon turned over and deepened toward its own blue; ripples three to sixteen pixels long shimmer in place, each lighter, darker or plain for about a second; under the Sun, while its disc is in the sky, a path of glitter is reshuffled five times in two seconds; and after dark each lamp on the far shore leaves a broken streak in the water under it.
- **Settings: Scenery** (`seat.country`), the train's own menu: Changing (the default), Countryside, A lake beside the line. Left to change, a lake lies beside 29% of the line, 4 km of it at the median (five minutes at 1×) and 10 km at the ninetieth percentile, with 9 km of country between (26 km at the ninetieth); at each end the shore closes in on the track over a few hundred metres (`trainPassesLakes`).
- **Mountains, snow, desert and the city are not built:** Dave has to see mock-ups of them first.

**The whole step, checked by running** (release, in the worktree, unless said):
- **Against the mock-ups:** 961,520 bytes compared, 0 differ: the rings' strips with their stamps, poles and lamps, the ground rows, and the pole line, at four places.
- **The night against sheet 2's tile E** (the lake at night, metre 52,000, 23:00), the build's picture read back as art pixels beside `train.py`'s view: lamps 135 pixels of the pane's 75,140 (0.18%) against the mock-up's 140 (0.19%); lamps and their streaks in the water 369 (0.49%) against 347 (0.46%); the sky above the land (17, 16, 36) in both; the land (21, 34, 49) against (24, 31, 47); the water (9, 12, 29) against (10, 12, 30). Through countryside at night: 47 lamp pixels (0.06%) against 46, and the land (13, 23, 40) against (15, 22, 39). The sheets' own share of lit pixels is a fifth of one per cent, not the one per cent the research note suggests.
- **An hour at night,** `trainNightIsNeverBlack`, lamp pixels showing a minute apart: through countryside 2 to 49; beside a lake 3 to 93.
- **Cost,** Large window, three runs taken in turn with the airliner: countryside 0.70 to 0.78 ms of CPU a frame by day and 0.72 to 0.78 by night; the lake 0.71 to 0.80; the airliner 1.01 to 1.06. GPU 0.09 to 0.34 ms.
- **What ships:** the 25 pictures of `shots.sh` are the same files as before step 1. All 75 tests pass in release; the train's seven pass in debug too.
- **Looked at,** as art pixels enlarged: countryside by day and at night at metre 52,000 (sheet 1's tile A, without its cloud), with the pole line (tile F); the hour's darkest minute, a wooded stretch with two yard lamps; the lake by day (tile D) and at night (tile E, without the table); a lake beginning, at four moments as its shore closes in; and eight frames a second apart through countryside.

**Wrong, or not done, after step 4:**
- **Two things in it are mine and not Dave's:** the lights that show only after dark, and the speed above which the pole line is left out.
- **The sky has no cloud** (step 6), which the sheets had; nor has the water any to mirror.
- **The near field below the lane is still one slab at night,** as on the sheets: nothing nearer than 180 m is lit.
- **A lake's shore is a hard edge** between field and water: no beach, no reeds. And there is no glitter under the Moon.
- **Things pop in or out when everything is laid again:** on a change of Speed, of Scenery, or of the side the Sun is on (twice a day).
- **Lamps do not flicker,** as the airliner's do behind trees; they are steady.
- **Not looked at:** dusk, when only some lamps are on; any Speed but 1×; any window size but Large; a portrait or ultrawide display; Settings' page with the train's rows; the app.
- **Motion has only been glanced at** (eight frames a second apart). Strips at 15, 30 and 60 fps are step 5.

### Step 5, motion (2026-10-11)
- **A change of Speed lays nothing again.** The distance run already added up; what jumped was what was laid by the speed. Now:
  - **Rings** keep what each stretch of their columns was laid by (`TrainWorld.Laying`: the speed and the Sun's side when it came into view). A change takes hold at the leading edge, and a tree or a house goes by where its left edge is, so none is ever half laid. At 3× the nearest ring's trees slide out whole and no more come in.
  - **Ground rows** add up how far along their dashes they have got (`GroundRow.dashed`), so the dashes that come in are longer or shorter and none in view moves.
  - **The pole line** is on or off from a pole on (`PixelTrain.strung`), two poles beyond the leading edge: it runs out at a pole, with every wire in view keeping both its poles, and comes back in at one.
  - **The Sun's side** goes the same way as the speed, so the twice-daily change is never seen.
  - **Scenery and Poles and wires** dissolve into a new scene over 0.8 s with both still running, as the airliner's Scenery does.
- **It paints every frame, up to 60 a second** (it was 30): at 60 a pole steps 2 px a frame, not 4.
- **Lamps have a limit of their own,** `TrainWorld.bright`, 30 px a second: a pixel a frame at 30 frames a second. Nothing changes at 1× (the fastest lamp is at 20); the 180 m ring's windows go dark from 1.5×.
- **What a fast train does to the ground:**
  - a row of the far fields that slides faster than 60 px a second is drawn as the near field is, one crop in dashes (from 1.8× the rows nearest 100 m; at 10× all but the top one);
  - a crop of the near field is as many times longer as the train is faster, in steps of a half again, so one lasts a couple of minutes at any speed;
  - above 1.2× a crop's end is the two crops by turns for a few seconds, not a hard edge;
  - a hedge's end on a swell's face is culled with the other thin things.
- **The scene compares the window with the one it was built for** (`windowOn`), not with the train's number. A scene built by a test, where the window isn't the train, took every change of setting for a change of window and ignored it, so the first speed test passed without testing anything.
- **Films, with no GPU and nothing on screen:** `trainFilmsItself` steps a scene at a frame rate and writes each frame as the pane's art pixels, and `train_strips.py` measures a film and lays frames out to look at (`TRAIN_FILM=/tmp/f.bin TRAIN_FILM_FPS=30 TRAIN_FILM_SECONDS=6 TRAIN_FILM_DEFAULTS="seat.previewTime=1,seat.previewHour=23,seat.country=1" swift test -c release -Xswiftc -enable-testing --filter trainFilmsItself`, then `python3 docs/pixel-window-seat/train_strips.py /tmp/f.bin strip.png`; `TRAIN_FILM_THEN="seat.speed=3@2"` moves a setting part way through, `TRAIN_FILM_SIZE=1080x1920` films another display).
- **Checked by running** (release, in the worktree; each decisive check twice, the two runs compared, since every worktree's tests share one defaults domain):
  - **Lamps a frame apart,** countryside at night, 6 s at 1×: at 30 frames a second a lamp is in the same pixel a frame later 82.9% of the time, a pixel on 14.6%, and behind something or gone 2.3%; at 60, 91.1%, 7.2% and 1.5%; at 15, 68.1% and 27.0%, with 0.9% two pixels on, which is the 180 m ring's lamps at 20 px a second. (The films also count 19 lamps of 6,723 as two or three pixels on at 30 frames a second: a lamp gone behind a tree with another lamp beside it. `trainLampsMoveAPixelAtATime` settles it: at 30 and at 60 frames a second, at seven speeds, no ring slow enough to hold lamps moves more than a pixel in a frame.) Beside the lake at night no lamp moves more than a pixel at any of the three rates.
  - **The pole** steps 8 to 9 px a frame at 15 frames a second, 4 to 5 at 30 and 2 to 3 at 60: 126 px a second each time.
  - **How much changes from one frame to the next** at 30 frames a second: none of the sky; 7% round the horizon; 47% of the near field through countryside (its dashes, in tones 3% apart) and 2% of the lake, with a quarter of it at each reshuffle of the ripples and glitter, five times in two seconds.
  - **The same picture at any frame rate,** `trainLooksTheSameAtAnyFrameRate`: after 2.2 s from the same metre, scenes stepped 15, 30 and 60 times a second have painted the same pixels, through countryside and beside the lake.
  - **The slider,** `trainKeepsItsCountryAsTheSpeedChanges`: at the moment Speed goes to 3×, 10×, 0.5× and back to 1×, not one pixel of the picture changes.
  - **Against the mock-ups:** 961,520 bytes compared, 0 differ, twice. `shots.sh` twice: the two runs the same 25 files, and the same as before step 1. 79 tests pass in release; the train's eleven in debug too.
  - **Cost,** Large window, three runs in turn with the airliner: 0.70 to 0.74 ms of CPU a frame at 1×, 0.88 at 10× (ten times the columns to lay), the airliner 0.99 to 1.04. GPU 0.14 to 0.18. The render test steps 30 frames a second; at 60 on a real display it paints twice as often for the same cost a frame, which has not been measured in the running app.
- **Looked at,** as strips of art pixels:
  - twelve frames one after another at 30 a second, countryside by day and by night: the pole, the wires, the nearest trees, the lamps;
  - frames a tenth of a second apart beside the lake by day and by night;
  - 0.5×, 2×, 4× and 10× by day, after the pane had refilled: at 2× the pole line and the 110 m ring are gone and the 180 m ring's trees and houses lead; at 4× the 300 m ring leads; at 10× nothing stands nearer than 900 m and the fields under the horizon are long bands. The near field is one calm crop at every speed. Nothing strobes at any of them, so the slider's top can stay at 10×, which is 480 km/h and looks like it.
  - the Speed slider moved from 1× to 3× two seconds into a film: the frame it moves in is the frame before it moved on, the pole line ends at a pole, and the near trees leave whole;
  - the Small window, no window, the Medium window at night beside the lake, and a portrait display's pane (121 × 175) by day and night.
- **The sunset is warm-lit.** Two ways were rendered side by side at 17:54 and 18:18 on 11 October, and the warm one picked (the team lead's choice, by Dave's rule that realism must not leave a picture dim). By the sky's light and the Sun's alone the land at sunset was a dim, cool green under the glow: the near field (76, 88, 51) at 17:54 and (60, 77, 58) at 18:18. With the glow along the horizon lighting the land too, two fifths of the horizon's colour while the Sun is low, it is (108, 125, 69) and (95, 110, 73), olive and gold, and the land keeps its colours until the sky has lost its own. Noon and night are untouched: the glow's share is nothing with the Sun over 12° up or more than 10° down. (The switch the two were rendered with, `TRAIN_WARM`, is gone.)
- **Wrong, or not done:**
  - **A change of Speed can start a new crop at the leading edge,** which sweeps across the near field once as any crop's end does: the crops' length goes by the speed. In steps, so a drag of the slider makes a few of these and not one a tick.
  - **At 15 frames a second a lamp on the 180 m ring steps two pixels** one frame in three, and the pole 8 or 9. Only a Power setting of 15 gives that rate.
  - **No test follows a tree through a change of speed** to prove it is never half laid; that rests on how `column` is written and on the film looked at.
  - **Not done here:** cloud, weather, the carriages, stations (steps 6 to 9).
  - **Not looked at:** dusk with the lamps half on, beyond one picture at 18:18; Settings' page; the app.

### After step 5: the train's rows under their own title (2026-10-11)
- **In:** with the train picked, Speed, Scenery and Poles and wires sit under **Journey**, not Flight. They are still rows of the page's Flight section; the section goes by another title while the menu is at the train (`Wallpaper.retitled`, Scenes.swift; `SectionTitle`, Settings.swift; `PixelWindowSeat.journey`). So no section is added or left empty, and nothing is retitled unless the train is offered: for the airliner and the station, with `unfinished` on or off, every row and section is as it was. The train's page reads View (Window on, Window, Looking), Journey (Speed, Scenery, Poles and wires), Preview.
- **Why not a section of the train's own:** Settings draws a section for every name among a page's knobs, shown or not, so a Journey section would have stood empty on the airliner's and the station's pages, and Flight empty on the train's.
- **Checked by running:** `windowSeatOffersTheTrainOnlyUnfinished` (Flight is titled Journey at the train and Flight at the airliner and the station; View and Preview keep their names; without the train the wallpaper retitles nothing). The whole suite, 79 tests, twice; the byte check, 961,520 compared, 0 differ; `shots.sh` twice, the two runs the same 25 files and the same as before step 1.
- **Not checked:** the Settings window itself, which was not opened: the title is read from the same stored pick the rows go by, but it has not been seen. The blurb and the preview picture are still the airliner's, until the train ships.

## Research for the next mock-ups
- **The window.** Real glass, width to height: a TGV bar car 1.94:1, a EuroNight sleeper 1.46:1, a British Mark 1 bay 1.2:1 with top-lights, an Amtrak Superliner coach 2.75:1, a Shinkansen N700 0.96:1 (520 × 500 mm: an airliner's window again). The mock-ups' pane is the airliner's, 1.54:1. A wide picture window (about 1.9:1) fills a 16:10 screen best.
- **The eye:** about 2.5 m above the rail on a European intercity, 3.85 m upstairs in a Superliner; add 0.5–1 m of track bed.
- **Poles.** Overhead masts stand 50–65 m apart (Britain 50–60 m, Germany up to 80, Japan about 50), old telegraph poles 40–64 m. A near-side mast is a flick (0.17 s to cross most of the frame on a British clip; two flicks a second on an ICE). A pole line 25–30 m out is calm: 2.4–2.8 s to cross, one every 4.5 s at 40 km/h, with the wire rising to each pole and sagging between, which is the genre's signature motion. The mock-ups have no near poles, only a far line along a lane.
- **Calm, or a jolt.** Calm: a far pole line and its wires, a parallel road with a car keeping pace, a river alongside, a distant train's lit windows, rolling slowly into a station. A jolt: near masts, truss bridges, tunnels, a passing train (3.6 s of full-frame flicker a metre away), platforms at speed, a wall of trees. Treat tunnels, bridges and passing trains as rare events behind a switch, if at all.
- **Scenery to hold on**, as the airliner holds on ocean or desert, with real lines that show each: water alongside (the Dawlish sea wall; a lake shore), farmland and paddies (the Tokaido Shinkansen; Sweden; England), an alpine pass (the Bernina, the Glacier Express, the Flåm line), desert and steppe (the Trans-Mongolian in the Gobi, the Nullarbor), snow (the Bergen line), a city by night from an elevated line. Water alongside fits the motion law best.
- **Night.** On a real night train out of Kyiv, lit pixels were 0.2–2% of the frame, mostly warm; the dark was a warm brown-black, not blue, with the sky lighter than the buildings. The glass turns from window to mirror during civil twilight: a lit cabin's reflection is 100 to 1,000 times brighter than a moonlit field. Every night-train picture people love cheats and keeps the outside readable, with the warmth inside as a lamp. So: a lifted, readable night (as the Earth orbit's is), lamps at about 1% of pixels, and the reflection as a faint ghost that grows through twilight.
- **Rain on the glass.** Beads sit still and only run once they have merged. On a moving train the water travels as two to four long threads lying about 9° below level, each keeping its path for seconds; on a creeping train the trails run straight down. So tie the threads' tilt to Speed. Wet glass also blurs the view more than it decorates it. Snow on a moving window: no footage found.
- **The genre** (ambience videos and pixel loops, all copyrighted, reference only): one warm light inside against one cool family outside; a flat, head-on window; at most three depths outside and nothing between the track and the middle distance (they dodge the blur by leaving the near field out); rain doing the moving; something still to rest the eye on (a lamp, a cup, a cat).

## Step plan
0. **Mock-ups** (two rounds done). Still to show Dave before their steps: mountains, snow, desert and a city by night, each as geometry.
1. **The mode menu.** `Settings.swift` (`Knob`, `KnobRow`: about ten lines so a gate can test a menu's value), the knobs in `PixelWindowSeat.swift` and `PixelOrbit.swift`, `OrbitTests.swift`. Accept: each mode's Settings shot shows only its own rows; a stored `seat.orbit=1` still opens the station; the orbit's documented shots come out the same byte for byte. Its own commit, before the train.
2. **Lift the sky and the pane's outline out of the airliner.** Accept: the airliner's screenshots the same before and after, byte for byte.
3. **`PixelTrain`:** rings, the slide, far-to-near painting. Accept: silhouettes match the mock-up to the pixel; each ring moves `focal × speed / Z` in two seconds, to a pixel; runs at any size; under 1.5 ms.
4. **The country:** stamps, fields, towns, lamps, Scenery. Accept: no ring holding a thin thing is over 30 px/s at any Speed; along an hour of track at night every minute's view has lit pixels.
5. **Motion:** the dashes, the cull. Accept: frame strips at 15, 30 and 60 fps; no bright pixel jumping more than its own width between frames; then Dave on his desktop. Don't show him the train before this step.
6. **Cloud from below.**
7. **Weather:** follow, previews (the tests never fetch, so previews are the only way to test it), drops, haze, snow.
8. **The carriages**, each matched to its mock-up pixel for pixel, as the Cupola was.
9. **Stations**, if wanted.
10. Fold this page into `pixel-window-seat.md`; screenshots, the blurb ("A pixel-art window seat on a plane, a train or the space station."), the README, a minor version.

## Risks, worst first
1. It doesn't look like a train window: stamps 8 to 30 px tall carry the whole picture.
2. Motion that isn't calm: the 110 m ring (32 px/s at 1×, the fastest thing with a shape), night lamps, rain beads. Only frame strips show it.
3. The near field reads as a dead stripe across the lower third. The first mock-up showed exactly this (a flat green slab by day, black by night) until the horizon was lowered to 30% up the pane and the night lifted.
4. Three modes in Settings without breaking the orbit.
5. Scenery pacing: the airliner covers 15 km a minute and the train under one, so the airliner's map must be stretched about 12 times to keep its pace of change.
6. Speed at 10× is 480 km/h: everything nearer than a kilometre is culled. The train may want a lower top speed.

## Mock-ups
In this folder, painted by `train.py` as geometry (the lens, the rings, the hashes are the ones a build would use, so a build can be matched to it):
- `train-sheet1.png`: a plain window, a sill and a curtain, a table and its lamp, each by day and by night. Eye 3.5 m, horizon 30% up the pane, 48 km/h. The sky, Sun and stars are the app's own, from renders of the airliner (`train-base/`: `SNAPSHOT_DEFAULTS="seat.wing=1,seat.window=3,seat.previewTime=1,seat.previewHour=13,seat.clouds=1,seat.scenery=3"`, and hours 18.6, 19.6 and 23), reduced to art pixels.
- A 14 s film of 48 km/h against 80 km/h went with it: `python3 train_film.py`.
- `train-sheet2.png` (`python3 train.py 52000 sheet2`): a lake beside the line by day (D) and at night from the table (E), the pole line (F), rain at dusk (G). Its film, the lake, the poles and the rain side by side at 48 km/h: `python3 train_film2.py`.
- In the mock-up the lake's ripples shimmer in place and don't slide (water has nothing in it to follow); the Sun's glitter is a path of dashes under it; each lamp on the far shore leaves a broken streak in the water. The rain is about 120 still beads, a light pixel over a dark one, kept faint so they don't read as stray white specks, and four threads 9° below level with water running along them.
- `train_geometry.py` and `train_plan.py`: the arithmetic behind the tables above, by the engine research agent.
- `train_match.py`: sets what the build's `TrainWorld` lays against `train.py`, byte for byte (see The build so far). For that, `train.py`'s speckle now goes by a pixel's height above its ring's foot. On the sheets it went by the row counted from the top of a strip as tall as the tallest thing in view, so a hill's speckle would have reshuffled whenever a taller one slid in. The shapes are the same; a sheet painted afresh differs from the saved one only in which pixels of a hill or a wood take the darker tone.
- `shots.sh`: Pixel Window Seat's documented screenshots, the airliner's and the orbit's, rendered into a folder, for checking byte for byte that a step of the build left them alone.
- Light at dusk and night is the ratio of the airliner's own ground at that hour to noon's, with the night lifted (×2.1 and a blue floor), so it is a guess at the engine's light, not the engine's.

## Sources
Footage measured (all openly licensed)
- Sweden, leaving Heby, public domain: https://archive.org/details/EvaVikstromStockFootageViewFromaTrainHebyMorgongavainAugust2006
- Tokaido Shinkansen over paddies, CC BY 2.0: https://commons.wikimedia.org/wiki/File:T%C5%8Dkaid%C5%8D_Shinkansen,_view_of_Ino,_Hiratsuka,_Kanagawa.ogv
- Trans-Mongolian in the Gobi, CC BY-SA 2.0: https://commons.wikimedia.org/wiki/File:Mongolia_Gobi_train.webm
- A British electrified line (masts), CC BY 4.0: https://commons.wikimedia.org/wiki/File:Duddeston_to_(nearly)_New_Street_-_2026-09-28_-_Andy_Mabbett.webm
- ICE on LGV Est (masts), CC0: https://commons.wikimedia.org/wiki/File:ICE_9574_on_LGV_Est_window_view.webm
- Night train from Kyiv, CC BY 3.0: https://commons.wikimedia.org/wiki/File:Night_train_from_Kyiv_to_Chernivtsi_(Ukraine).webm
- Rain (Pexels licence, measured only): https://www.pexels.com/video/raindrops-sliding-on-a-train-window-4640062/, https://www.pexels.com/video/raindrops-on-train-window-13255056/

The railway's edge
- Overhead line spacing, Britain: https://alanbaxter.co.uk/s/Scotlands-Railway-Guide-to-Overhead-Line-Equipment-November-2021.pdf; Germany: https://de.wikipedia.org/wiki/Oberleitung; Japan: https://ja.wikipedia.org/wiki/架空電車線方式
- Telegraph pole spacing (a hobbyists' forum, not a standard): https://forum.trains.com/t/telegraph-pole-spacing/64580
- Track spacing: https://en.wikipedia.org/wiki/Track_spacing. Platform and floor heights: https://en.wikipedia.org/wiki/Railway_platform_height

Windows and trains
- Shinkansen N700: https://ja.wikipedia.org/wiki/新幹線N700系電車. Superliner: https://en.wikipedia.org/wiki/Superliner_(railcar)
- Glacier Express (291 km in about 8 hours): https://en.wikipedia.org/wiki/Glacier_Express. Flåm line (40 km/h at most): https://en.wikipedia.org/wiki/Fl%C3%A5m_Line. Bernina: https://en.wikipedia.org/wiki/Bernina_Express. Bergen line: https://en.wikipedia.org/wiki/Bergen_Line. Dawlish sea wall: https://en.wikipedia.org/wiki/South_Devon_Railway_sea_wall. Nullarbor: https://en.wikipedia.org/wiki/Trans-Australian_Railway

Night and rain
- Glass reflects about 4% a surface: https://en.wikipedia.org/wiki/Fresnel_equations. Light levels: https://en.wikipedia.org/wiki/Lux. Raindrop fall speeds: https://en.wikipedia.org/wiki/Rain

Not verified: every train's actual speed in the clips (only speed over eye height is measured); the seated eye's height (1.2 m above the floor); how far masts and fences stand from the track; cabin lighting of 200 lux; every cost above.
