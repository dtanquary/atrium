# Pixel Window Seat: a train (planned, not built)

A third window for [Pixel Window Seat](../pixel-window-seat.md): a seat on a slow train, the country sliding past under the real Sun, Moon and stars for your clock and place, with rain on the glass when it rains where you are. It began as "Pixel Night Train" in the 2026-10-10 brainstorm ([ideas.md](../ideas.md)); Dave picked it as "an addition to pixel window seat, doesn't have to be its own wallpaper".

That day two agents researched it (one read the code and worked the geometry, one measured real footage) and one round of mock-ups went to Dave. **Nothing is built.** This page is the plan, the findings and their sources. The two reports in full: [the engine](train-research-engine.md) and [the footage and scenery](train-research-footage.md). When it is built, it becomes a part of `pixel-window-seat.md`.

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
