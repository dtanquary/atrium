# The train: the engine research

A research agent's report as it was sent on 2026-10-10, unedited, kept so its detail and sources aren't lost. The plan beside it is the summary and has Dave's decisions; where the two differ, the plan is later. `scratch/` was the session's temporary folder: the scripts and pictures worth keeping were copied into this folder, the rest (downloaded references, video clips) is gone and its source URLs are below.

Train view 1/11: geometry. The near field is a blur at any real speed, and the picture is standing things, not ground.

Computed (python, paths in 11/11) from the airliner's own lens (PixelWindowSeat.swift:106-112): Large pane 340 x 221 on the 378 x 246 canvas, focal 265 px, looking square out of the side.

The law: a thing Z metres out from the track moves focal x speed / Z px/s, whatever its height and whatever the eye's height. A thing h m tall stands h x focal / Z px.

Z       px per m   px/s at 40 / 80 / 120 / 200 km/h
5 m     53         589 / 1179 / 1768 / 2947
12 m    22         246 / 491 / 737 / 1228
20 m    13         147 / 295 / 442 / 737
50 m    5.3        59 / 118 / 177 / 295
100 m   2.65       29 / 59 / 88 / 147
200 m   1.33       15 / 29 / 44 / 74
300 m   0.88       10 / 20 / 29 / 49
500 m   0.53       5.9 / 12 / 18 / 29
1 km    0.27       2.9 / 5.9 / 8.8 / 15
2 km    0.13       1.5 / 2.9 / 4.4 / 7.4
8 km    0.033      0.4 / 0.7 / 1.1 / 1.8
30 km   0.009      0.1 / 0.2 / 0.3 / 0.5

Nearer than this, a thing moves more than 1 / 4 / 16 px a frame at 30 fps:
40 km/h:  98 m / 25 m / 6 m
80 km/h:  196 m / 49 m / 12 m
120 km/h: 295 m / 74 m / 18 m
200 km/h: 491 m / 123 m / 31 m

For scale, what Dave has accepted as calm: the airliner at 1x tops out at 3.3 px/s of ground and 5.3 px/s of cloud, 103 s to cross the pane, and 53 px/s at 10x (computed from the same lines). Pixel City's cars run 14 to 22 px/s (docs/pixel-city.md:36).

Conclusion:
- Yes, the near field is a blur whatever we do. At 80 km/h everything within 200 m skips pixels, and a mast 4 m out crosses the pane in 7 frames at 49 px a frame. No eye height, sill or lens changes that: it depends on distance and speed alone.
- Flat ground is the wrong thing to draw. From 3 m up, all the ground beyond 200 m is 4 rows of the picture (6 rows from 4.5 m). The calm part of a train view is things standing up against the sky: trees 100 to 300 m off (13 to 30 px tall), woods and villages at 0.5 to 2 km (3 to 9 px), hills and mountains beyond.
- It stays readable and calm at 40 to 60 km/h, with nothing separate drawn nearer than about 100 to 150 m and the ground in front of that as a flat, low-contrast band. At 80 km/h the first readable things are 200 m off; at 200 km/h, half a km.
- 1 px a frame is the line for thin things (poles, trunks, lamps). Broad things (a tree's crown, a house) tolerate about twice that.

---

Train view 2/11: geometry. Rows, the sill, a higher eye, looking ahead (all computed).

Flat ground by row. A row d under the horizon is eye x focal / d away, a pixel of it spans eye / d metres, and it slides speed x d / eye px/s. Eye 3 m, the airliner's layout (horizon 62% up, 137 rows of ground):

d     away     m/px    px/s at 40 / 80 / 120 / 200 km/h
1     796 m    3.0     3.7 / 7.4 / 11 / 19
4     199 m    0.75    15 / 30 / 44 / 74
10    80 m     0.30    37 / 74 / 111 / 185
30    27 m     0.10    111 / 222 / 333 / 556
65    12 m     0.046   241 / 481 / 722 / 1204
137   5.8 m    0.022   507 / 1015 / 1522 / 2537

Rows of the 137 moving more than 1 / 4 / 16 px a frame:
eye 3 m:   40 km/h 129 / 105 / 8;  80: 133 / 121 / 73;  120: 135 / 127 / 94;  200: 136 / 131 / 112
eye 4.5 m: 40 km/h 125 / 89 / 0;   80: 131 / 113 / 40;  120: 133 / 121 / 73;  200: 135 / 128 / 99
So 4.5 m buys two rows. An upper deck or an embankment doesn't help.

The sill. Assuming an eye 0.45 to 0.6 m from the glass and a sill 0.25 to 0.35 m below it (my guess at a coach, for train-scenery to correct), the sill cuts the view 29 to 30 degrees down: ground nearer than 5 m (eye 3 m) or 8 m (eye 4.5 m). The pane's own foot is already 27 degrees down. A real sill hides none of the blur, which runs from 5 m to 200 m. Hiding it would take a sill drawn 1 degree under the horizon.

A much higher eye does work. The pane's bottom row, in px/s at 40 / 80 km/h: eye 30 m: 51 / 101; eye 60 m: 25 / 51. It is under 30 px/s from 51 m up at 40 km/h and from 101 m at 80. That is a line along a hillside, or a viaduct: there the airliner's row engine works again with a metre-scale world. It isn't a ground-level train, and it can't show flat country.

Looking a little ahead makes it worse. Through this lens a thing Z out moves cos2(yaw + a) / cos2(a) times its side-view speed, where a is its angle across the pane (plus or minus 32.7 degrees). At the trailing edge / centre / leading edge:
15 degrees: 1.28 / 0.93 / 0.64
30 degrees: 1.41 / 0.75 / 0.30
45 degrees: 1.35 / 0.50 / 0.06
66 degrees: 0.98 / 0.17 / 0.03
Nothing gets slower everywhere until the view is turned 66 degrees toward the nose, and any turn loses the whole-pixel slide: things speed up and grow as they cross.

How the existing settings work: the airliner's Looking is a compass bearing for the Sun, not a turn of the camera (PixelWindowSeat.swift:190), and its Seat only shows or hides the wing (:381). Both carry over; neither helps here. The orbit's Ahead does turn the camera, by giving every pixel its own ring (PixelOrbit.swift:75, :150), but that is for cells of flat ground on a ball, and its doc says it has only been looked at as stills (docs/pixel-window-seat.md:239, :263).

Cloud from below is calm for free: a base 1.2 km up, at the top of the sky (84 rows), is 3.8 km off at 14 m a pixel and slides 0.8 px/s at 40 km/h. Ten rows up it is 32 km off and all but still.

---

Train view 3/11: reuse map (read from the code).

Unchanged, callable as they are:
- The pane and window sizes: `PixelWindowSeat.pane(_:)` (PixelWindowSeat.swift:124), which PixelOrbit already borrows. Its 8:5 cap is a real train window's shape; for the airliner it is the liberty.
- The canvas: `Pixels`, `RGB`, `mix`, `smoothstep`, `bayer`, `SeededRandom` (PixelCity.swift:3634-3772), `PixelCity.skyColours` and `sunColour` (:1049, :1063), and `Sky` for the Sun, the Moon and its phase.
- Cloud and storms as a world: `SeatWorld.cover`, `cloud`, `storm`, `lightning`, `heights` (PixelWindowSeat.swift:657, :769, :725, :735, :747) are km-scale and stay right from below. `SeatWorld.peaks` (:692) gives far mountain ranges. `shore`, `urban`, `climate` and `biome` (:644-720) can say what country we are in, sampled along the track with the map stretched about 12 times, since the airliner covers 15 km a minute and a train about one.
- Settings plumbing: `shownWhen`, `hiddenWhen`, `lockedWhen` (Settings.swift:19-23, :637), the status line (:516, :594), the 0.8 s dissolve into a new scene (PixelWindowSeat.swift:150-157), the 30 s wall-clock repaint (:421), the time preview (:163), the tenth-of-a-second clamp (:418).
- Live weather: `LiveWeather.shared.poll()` and `.latest` (LiveWeather.swift:30, :39: one shared request, at most every 10 minutes), started from `didMove` as the Airport does (PixelCity.swift:172-179). `GlassWeather.rainAmount` and `shower` (RainWeather.swift:254, :261) turn mm an hour into how hard it rains on glass.

Needs lifting out, or a variant (all private or inline today):
- The sky painter. Bands, glare, stars, Moon and Sun, then the light tables, are about 90 lines inside `redraw` (PixelWindowSeat.swift:203-290). Lift into a shared function, or copy.
- The cabin. `outsidePane` and `paintCabin` (:330-374) are private, and PixelOrbit repeats the outline (PixelOrbit.swift:262-267). A carriage wants small corners, a sill and a curtain: a third painter, or one with the corner radius as a parameter.
- The shared flight. `flown` and `flownAt` (:65-67, :422): the same shape, its own variable, in metres.
- The ring machinery. `Row`, `advance` and the `ceiling` painter (:437-503, :577). The idea carries over. The code ties one ring to one picture row (`r = q - apron`, :475) and one colour to a column (:493).
- `Paint` and the lighting (:262-277, :586): the same tables, without the 20% veil of 11 km of air, and with haze by metres.
- `hash`, `noise`, `fbm`, `scatter`, `blend`, `pack` and `rgb` are private (:1003-1053). PixelOrbit repeats five of them on purpose (docs/pixel-window-seat.md:104, :251).

New:
- A metre-scale world of standing things, and their art.
- Cloud painted from below (the cloud loop at :504-542, turned over).
- The near ground as streaks.
- Rain on the glass, the weather's lean on sky and haze, the carriage, and a third mode in Settings.

Doesn't carry over: `SeatWorld.ground`, `surface`, `lowland`, `mountain` and `desert` (:784-989). They are a map seen from above at 76 m to 1.4 km a pixel. From 3 m up that map is 4 rows tall.

---

Train view 4/11: recommended architecture.

A third scene, `PixelTrain` in `PixelTrain.swift`, picked in `pixelWindowSeat(size:)` (PixelWindowSeat.swift:4), as `PixelOrbit` was. The same kind of scene: one picture painted on the CPU into a mutable texture, with the carriage as a second texture over it.

Reuse the ring engine's idea, not its rows. Three sets of rings, each sliding by whole pixels and laying a column once, as it comes in at the leading edge, exactly as `advance` does (:437):

1. Standing rings: about 12, at distances we choose, from about 110 m to 60 km. A ring is a strip of palette bytes one pane wide and as tall as its tallest thing. Its foot sits eye x focal / Z rows under the horizon, and a metre stands focal / Z px. With the eye 3.5 m up, px/s at 40 / 60 / 80 km/h (computed):
   110 m    lineside trees, a hedge      12 m is 29 px    27 / 40 / 54
   180 m    trees, a farm                15 m is 22 px    16 / 25 / 33
   300 m    houses, poles along a road   8 m is 7 px      10 / 15 / 20
   500 m    copses, a village            15 m is 8 px     5.9 / 8.8 / 12
   900 m    woods, a spire               30 m is 9 px     3.3 / 4.9 / 6.5
   1.8 km   a low rise, pylons           40 m is 6 px     1.6 / 2.5 / 3.3
   3.5, 7 and 15 km   hills              120 to 800 m is 9 to 14 px    under 1.3
   30 and 60 km   mountains (`peaks`)    2.5 to 3.5 km is 15 to 22 px  about 0.1
2. Ground rows: one per picture row under the horizon, material only, as the airliner's are. Their cells are stretched along the track so that none is shorter than the row moves in two frames. The near ground becomes long, soft dashes that flow, and nothing in it can strobe.
3. Sky rows: the airliner's cloud layer seen from below, one strip per row above the horizon.

Paint far to near and let the near overwrite. The airliner paints near to far with a `ceiling` per column, which needs solid columns; a tree on its trunk, or a pole, is not one. The cost is a few thousand pixels painted twice.

Why strips of bytes and not one height per column: the doc's own lesson is that up close "a column of one tone reads as a block of ice" (docs/pixel-window-seat.md:106). Near things need drawn shapes: small stamps (a tree, a house, a barn, a spire), made once per ring size in code, as Pixel City makes its pines and houses (PixelCity.swift:1781-1810), and copied in a column at a time. Far rings fill their columns from a height line: noise for woods and hills, `SeatWorld.peaks` for ranges, coloured by height in bands, snow over rock over forest, as `drawMountains` does (PixelCity.swift:1737). One kind of ring serves both.

The world stays stateless: what stands at column n of ring k comes from hashes of the place, so every display and Settings' preview see the same country, as with `SeatWorld`.

One rule keeps it calm at any speed. Each ring knows its px/s. Thin things (poles, trunks, lamps) are laid only on rings under about 30 px/s, and broad things under about 60. As Speed goes up the near rings empty out and the far country carries on. It is the airliner's rule that things too small to see are left out (docs/pixel-window-seat.md:36), applied to things too fast to see.

---

Train view 5/11: the new world, item by item. How each would be painted; the costs are estimates.

Every one is a rule for filling a ring's column, so each costs a few hashes per new column and nothing per frame beyond copying its bytes.

- Ballast, track bed, fences, the verge: the ground rows nearest us, which move 300 to 2,500 px/s. Two or three close tones of one colour, in dashes. No posts, no sleepers.
- Fields: the ground rows further off, each field one tone for a stretch of track, with hedges as dark ends. They are thin: 8 or 9 rows hold everything beyond 100 m.
- Trees and hedgerows: stamps on the 110 to 500 m rings, with a lit side and a shaded side by where the Sun is (`sunSide`, PixelWindowSeat.swift:201). Beyond that, a ragged dark line from noise.
- Farmhouses, barns, a church: stamps on the 180 to 900 m rings, with one or two window bytes that turn to a lamp's colour after dark, each coming on at its own draw as the airliner's lamps do (:487).
- Telegraph poles or catenary masts: beside the track they are the strobe. Draw them only as a line along a far road, 300 m off: 7 px tall, 44 px apart, 10 to 20 px/s. The wire between is one more byte per column.
- Far hills and mountains: height lines on the 3.5 to 60 km rings, hazed toward the horizon's colour.
- Towns with lit windows: a set of skyline stamps on the 500 m to 1.8 km rings where `urban` runs high, and at night orange and white lamps on the same rings.
- Water: a lake or the sea beside the line is ground rows of water with the airliner's glitter path (:292-304, :484), which is random in time and not tied to the slide. It is the one near field that is calm by nature, so Coast should be the showpiece.
- Stations and platforms: 3 m from the eye, so readable only when the train slows and stops. That needs the speed to follow a profile shared by all displays. A later step, and a question for Dave.
- Embankments and cuttings: a cutting is a green wall across the lower pane, and an embankment a slightly higher eye, which 2/11 shows does nothing. Leave both out at first.
- Bridges and viaducts: a girder bridge is the strobe again. A viaduct over a valley is the high-eye case from 2/11, the one place where flat ground opens out below. Worth a mock-up later, not the first build.
- Tunnels: a black pane. Dave's rule is that realism must not leave it black. Leave out.
- Level crossings: flashing lights passing at speed. Leave out.

Memory: 12 strips of 340 columns by up to 40 rows, about 100 KB, on top of the picture and sky buffers the airliner already has (590 KB). No data files.

---

Train view 6/11: rain on the glass, live weather, the carriage, the night.

Rain on the glass. A few dozen drops kept in a small array and painted over the finished picture. A bead is two pixels, a light one under a dark one. It sits still, then runs along a slanted line and leaves a tail of three to eight pixels that fades. The slant comes from the train's speed: straight down when stopped, flatter as it goes faster. I have no measured angle; train-scenery's footage should set it. Cost: under 1,000 blended pixels a paint, against the picture's 75,000. It has to be looked at moving: small bright things that step are what Dave called "stray moving white blocks" on the Overlook (docs/pixel-city.md:106, :194).

Live weather, from the report the app already fetches (LiveWeather.swift:12-27), with no new request:
- rain plus showers, times 4 for mm an hour, through `GlassWeather.rainAmount` (RainWeather.swift:149, :254): how many drops, and how often they run.
- cloudCover: leans `SeatWorld.weather` to Clear, Scattered, Broken or Overcast (PixelWindowSeat.swift:657). The airliner's doc already lists this as an idea (docs/pixel-window-seat.md:463), and it would serve the airliner too.
- visibility: how far the haze lets us see, so the far rings fade out in rain and fog.
- snowDepth and snowfall: white fields and roofs through the materials, and flakes later.
The render tests never fetch, so it needs a preview menu (Dry, Drizzle, Rain, Snow) to be tested or photographed at all, as Rain on Glass has (RainWeather.swift:13).

The carriage. A variant of `paintCabin` (PixelWindowSeat.swift:338): the same dark wall, a pane with small corners, a sill, a curtain gathered at one side, perhaps a table's edge and a small shaded lamp. At night the lamp's reflection is a dim warm patch in the glass, with a ghost of the seat. All of it goes into the second texture, repainted every 30 s, so it costs nothing per frame. It is fixed geometry, so it can be matched to a mock-up exactly, as the Cupola's dome was: every one of its 77,456 pixels by day (docs/pixel-window-seat.md:256).

The night is the part to design first, since it is the idea's name. From a train the dark country really is black. What can be lit:
- the Moon and stars, which are already there;
- farm windows and yard lights on the 180 to 900 m rings;
- a town's lamps;
- a far road with a pair of headlights;
- snow under the Moon;
- the lamp in the glass, and rain beads catching it.
Lamps will have to be denser than life, as the airliner's are: 10 to 30% of a block against a real 1.5 to 3% (docs/pixel-window-seat.md:109). A lamp nearer than the 30 px/s line would be a streak, and is left out.

---

Train view 7/11: calm motion. The ways out, and what each costs.

1. A slow train. The strongest lever, since everything scales with speed. If 1x is 50 km/h, thin things are calm from 123 m out and the 300 m ring runs at 12 px/s, slower than a Pixel City car. Cost: none in code. It is less of an express; Dave already chose the real pace over a faster one for the airliner (docs/pixel-window-seat.md:283).
2. The Speed slider as it is (`seat.speed`, 0.5x to 10x). With 1x at 50 km/h it runs from 25 km/h to 500. It only works across that range with number 3.
3. Cull by speed. Each ring lays thin things only under about 30 px/s and broad ones under about 60. A fast train loses its near rings and keeps the far ones. Cost: a fast train's foreground is plain. This is the rule I would make everything else depend on.
4. Pole spacing and contrast. Spacing doesn't help: a pole 4 m out crosses in 7 frames at 80 km/h however far apart the poles are. Distance does: the same line 300 m off is calm. Low contrast helps the ground, not a pole against the sky.
5. Looking ahead. Worse, not better (2/11), and it loses the whole-pixel slide.
6. A higher eye. 4.5 m does nothing. 50 to 100 m works, as a hillside line or a viaduct, and brings the airliner's flat-ground engine back. It is a different picture: out over a valley, not across a field.
7. Hiding the nearest ground. A real sill hides nothing useful (2/11). What works is composition: put the horizon 40 to 45% up the pane and not 62%, so there are 88 to 99 rows of ground and not 137, and let the Dock and a table's edge take the lowest of them.
8. Water beside the line. A lake or the sea has nothing in it to blur.
9. Streaks. Near rows drawn as long dashes in close tones, each at least twice as long as the row moves in a frame. They flow at the true speed and say "moving" without one thing to follow. Cost: scenes must look the same at 15, 30 and 60 fps (CLAUDE.md:7), so a dash's length has to go by px/s, not by the frame.
10. Paint rate. The airliner caps painting at 30 a second (PixelWindowSeat.swift:177). Keep the cap: at 60 fps the near dashes then step every other frame, which dashes hide.

Recommended together: 1x at 45 to 50 km/h; the cull; the lower horizon; a streaked verge; the first separate things at about 110 m; and Coast as a scenery, with water for its near field.

Two things to look at in frame strips before anything ships, since the Overlook's steam was passed on stills alone (docs/pixel-city.md:194):
- the 110 m ring at 1x, which at 27 to 40 px/s is the fastest thing with a shape;
- lamps at night on any ring over about 15 px/s.

---

Train view 8/11: where it lives, and its Settings.

A third scene behind the same wallpaper, which is what docs/ideas.md:9 records Dave chose. The code agrees: the pane, sky, clock, place, window sizes, Looking, Speed, Scenery, Clouds, Lightning and the time preview are all shared, and the name already fits. The precedent the other way is Pixel Spaceport, a city for a day and then its own wallpaper built by the same class (docs/pixel-city.md:13). If `PixelTrain` is kept self-contained, that stays a small change later.

The switch is the awkward part. `seat.orbit` is a toggle, and every gate tests one key for "on" (Settings.swift:637). Two ways:
- A. A second toggle, `seat.train`, hidden while Earth orbit is on. Settings.swift barely changes: the airliner's Seat has to hide for two switches, and a knob has one `hiddenWhen` (:21). The result is three exclusive modes on two switches, one of which hides the other.
- B. One menu, "Window on: An airliner, A train, The space station", and gates that can test a menu's value. About ten lines in `KnobRow` (:625-637, :662). `seat.orbit` moves to the new key: it shipped in v0.107.0-beta, so a stored 1 has to carry over, and the doc's recipes and two tests name it (OrbitTests.swift:84, :105).
I recommend B, as its own commit before the train.

The page, with the train picked:
View
- Window on: the menu.
- Seat: Facing forward or Facing back (which way the land slides). New, train only.
- Window: Small, Medium, Large, None. Shared.
- Looking: the compass menu. Shared with the airliner.
Journey
- Speed: shared. 1x is a slow train.
- Scenery: shared, the same seven. Ocean reads as the line along the shore, City as towns.
- Stops at stations: Never, Sometimes, Often. Later, if Dave wants it.
- Clouds, and Lightning in far-off storms: shared.
Weather
- Follow the weather where you are: a switch, with the live report under it (the wallpaper's `status`, Scenes.swift:16, reading `weather.status`).
- Preview the weather: Off, Dry, Drizzle, Rain, Snow.
Preview
- Preview a time of day, and Time. Shared.
Hidden for the train: the airliner's Seat, and the orbit's five.

Name and blurb. The wallpaper keeps "Pixel Window Seat". Its blurb today is "A pixel-art window seat on a flight that never lands, or on the space station." (Scenes.swift:88). Proposed: "A pixel-art window seat on a plane, a train or the space station." In the menu the mode is "A train": "Night Train" is only true after dark, since it follows the real clock. The icon stays `airplane`. Welcome.swift names the wallpaper, not its modes (:16, :21), so nothing changes there.

---

Train view 9/11: cost, and the risks ranked.

Cost. Nothing was built or run. These are scaled from the doc's own measurements.
- The airliner paints its Large pane's 75,140 pixels in about 1.3 ms when it paints every frame (docs/pixel-window-seat.md:98): 17 ns a pixel. At 1x it paints every other frame of the test's 30, which is how it comes to 0.77 to 1.18 ms.
- The train has to paint every frame, since its near ground moves every frame. The same pixel count, simpler ground, a few thousand pixels painted twice: I estimate 1.0 to 1.4 ms of CPU a frame at Large, and 1.3 to 1.7 with no window (92,988 pixels). Inside the 2 ms budget, above today's airliner.
- A way down, if wanted: the sky, the cloud and every ring beyond about 2 km move under 3 px/s. Keep them as one buffer, repainted when one of them steps, and copy it. That leaves about 30,000 pixels a frame, perhaps 0.6 to 0.9 ms.
- GPU: one texture upload and two sprites, as now (0.12 to 0.38 ms).
- New columns: a few hundred to a few thousand a second, each a handful of hashes. A mountain column is the dearest, at about forty noise lookups (:99), and one arrives every several seconds.
- A new scene: 12 rings of 340 columns and about 100 ground rows. I would expect it under the orbit's 45 ms (:229).
- Memory: about 100 KB of rings on top of 590 KB of picture and sky. No map.
- Network: none, or the one shared weather request every 10 minutes.

Risks, worst first:
1. It doesn't look like a train window. Stamps 8 to 30 px tall carry the whole picture, and noise columns read as blocks. Mock-ups first, painted as geometry.
2. Motion that isn't calm: the 110 m ring, night lamps, rain beads. Only frame strips show it.
3. A black night. Do the night mock-up before the day one.
4. The near band reads as a dead stripe across the lower third. The horizon's height and the dashes need Dave's eye on a mock-up.
5. Three modes in Settings: moving `seat.orbit` without breaking the orbit.
6. Lifting the sky out of the airliner's `redraw`: it must leave the airliner's pictures the same, byte for byte.
7. Scenery pacing. The airliner's country changes every one to five minutes at 15 km a minute. At 1 km a minute, keeping that pace means stretching the map 12 times, and a mountain range is then 2 km long.
8. Weather that can't be tested live: the tests never fetch, so the previews carry it.
9. Speed at 10x (500 km/h): everything nearer than 1.2 km is culled. It will look empty unless the train gets a lower top speed.
10. Two copies running, as with Settings' preview open (Sources/CLAUDE.md, step 8): the distance travelled is shared, as `flown` is; each scene's drops can be its own.

---

Train view 10/11: step plan. Files, and what would accept each step.

0. Mock-ups, with no app code. A script paints the 378 x 246 canvas from a list of rings (distance, height line, stamps): day over fields, night with the lamp, the coast, rain; plus 8 frames of motion at the proposed 1x. Accept: Dave picks the horizon's height, the near band, the carriage and what 1x is. Kept as geometry so the build can be matched to it, as the Cupola was.

1. The mode menu. Settings.swift (`Knob`, `KnobRow`), PixelWindowSeat.swift:4 and :13-36, PixelOrbit.swift:14-24, OrbitTests.swift, and the doc's 12 mentions of `seat.orbit`. Accept: `SETTINGS_SHOT` of each mode shows only its own rows; a stored `seat.orbit=1` still opens the station; the orbit's tests pass; its documented shots come out the same, byte for byte.

2. Lift the sky and the pane's outline out of the airliner. PixelWindowSeat.swift:203-290 and :330. Accept: the fourteen airliner screenshots the same before and after, byte for byte.

3. `PixelTrain`: rings, the slide, far-to-near painting, flat-tone height lines and ground rows, the shared sky, the airliner's cabin for now. New: Sources/Atrium/PixelTrain.swift and Tests/AtriumTests/TrainTests.swift. Accept: the silhouettes are the mock-up's to the pixel; `trainRunsAtAnySize` (a laptop, a portrait display, an ultrawide and a tiny one, each window size, as OrbitTests.swift:104 does); `trainSlidesByDistance` (in two seconds each ring moves focal x speed / Z px, to a pixel); the render test prints under 1.5 ms.

4. The country: stamps, fields, towns, lamps, and the Scenery menu through `SeatWorld`. Accept: one sheet of every scenery by day, at dusk and by night; `trainNothingThinIsFast` (at every Speed from 0.5x to 10x, no ring holding a thin thing is over 30 px/s); `trainNightIsNeverBlack` (along an hour of track, every minute's view has lit pixels).

5. Motion: the dashes, the cull, the paint rate. Accept: strips of each scenery at 15, 30 and 60 fps; a script over `SNAPSHOT_MOVIE` frames that finds no bright pixel jumping more than its own width between frames; then Dave on his desktop.

6. Cloud from below, and lightning. Accept: sheets from Clear to Overcast at noon and at sunset; `windowSeatLightningIsRare` already covers the rhythm.

7. Weather: follow, previews, drops, haze, snow. PixelTrain.swift, and Scenes.swift for `status`. Accept: a test from report to state, as RainWeatherTests has; a sheet of each preview; a strip of the drops; one run by hand against the live report, as the orbit's two switches had (docs/pixel-window-seat.md:265).

8. The carriage and the lamp. Accept: every pixel of it is the mock-up's.

9. Stations, if wanted. Accept: a test that no stop outlasts its limit and that something moves all through it.

10. The doc (a Train part of docs/pixel-window-seat.md, with train-scenery's sources and their URLs), screenshots, the blurb, the README, and a minor version bump in build.sh.

Steps 1 and 2 can ship on their own. Steps 3 to 5 are the train, and I would not show it to Dave before 5.

---

Train view 11/11: the questions only Dave can answer, and what all this rests on.

Questions:
1. One menu for airliner, train and station (my pick), or a second switch beside Earth orbit?
2. What is 1x? I would say 45 to 50 km/h, a slow scenic train. At a real 120 km/h nothing nearer than 300 m has a shape.
3. Should the slider's top be lower for the train? 10x of 50 is 500 km/h.
4. The lower third: a flat, softly streaked field with the horizon 40 to 45% up, or the airliner's higher horizon and more blur? A mock-up should put this to him.
5. A hillside or viaduct view from 50 m up, as one of the sceneries? It is the only way to see land laid out below, and it is the airliner's engine.
6. How much carriage: a plain frame, a sill and curtain, or a table with a lamp and its reflection at night?
7. Does it stop at stations?
8. Follow the weather: on or off by default? Rain on Glass's is off (RainWeather.swift:7) and the Airport's wind is on (PixelCity.swift:30). And should the live report set the cloud, the haze and snow on the fields too, or only the rain on the glass?
9. Night: are lamps denser than life all right, as on the airliner?
10. Poles: none near the track, only a far line along a road. Is the view acceptable without the classic passing poles, or should a slow train get them?
11. Which railway: wires overhead, telegraph poles, the steam age? That is train-scenery's ground.

What this rests on:
- Read: CLAUDE.md, Sources/CLAUDE.md, docs/README.md, docs/ideas.md:9, docs/pixel-window-seat.md lines 1-368 and 457-489 (the rest of the Cupola's research and the Sources list only as headings), docs/pixel-city.md in part, PixelWindowSeat.swift whole, PixelOrbit.swift to line 552 less `layWing`'s body, the canvas and sky parts of PixelCity.swift, LiveWeather.swift, RainWeather.swift in part, OrbitTests.swift, WindowSeatTests.swift, the gating in Settings.swift. PixelCupola.swift only as an outline of its functions.
- Computed: every number in 1/11 and 2/11 and the ring table in 4/11, by two scripts in scratch/train/ : geometry.py and plan.py. geometry.py checks itself against the doc's own figures first (the Medium pane's nearest row, 20 km off at 90 m a pixel; the doc's 90 m is Medium's, and at Large it is 76 m).
- Assumed, with no source: the eye 3 to 3.5 m above the ground, where the sill and the seat are, poles every 50 to 60 m and a mast 2.5 to 4 m from the eye, the heights of trees and houses. train-scenery should correct them. The law in 1/11 doesn't depend on any of them.
- Estimated, not measured: every cost in 9/11. Nothing was built, run or tested, and no mock-up was painted.
- Not worked out: the slant of rain on a moving window, and how stamps look at 8 to 30 px.
- One correction to 8/11: the Spaceport's precedent is at docs/pixel-city.md:12, not :13.
- Blocked: nothing. Nothing in the repo was changed.
