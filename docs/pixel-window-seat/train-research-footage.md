# The train: the footage and scenery research

A research agent's report as it was sent on 2026-10-10, unedited, kept so its detail and sources aren't lost. The plan beside it is the summary and has Dave's decisions; where the two differ, the plan is later. `scratch/` was the session's temporary folder: the scripts and pictures worth keeping were copied into this folder, the rest (downloaded references, video clips) is gone and its source URLs are below.

train-refs 1/8: MEASURED MOTION (the one fact that shapes the build). More messages follow: lineside, windows, scenery, night+rain, genre, recommendation, stills.

Method: my script cross-correlates each of 20 horizontal bands of a clip with itself one frame later and takes the median shift, in frame widths per second (W/s). Scripts in scratchpad/train/scripts (flow.py, poles.py, slit.py).

THE LAW (measured, r = 0.993 to 0.999 on four clips): sideways speed is zero at the horizon and grows in a straight line with distance below it, exactly as in the airliner. Speed in W/s = (v / h) x (drop below the horizon as a fraction of frame WIDTH), v = train speed, h = eye height above that ground. Focal length cancels. The airliner has h = 11 km; a train has h = 3 m, so the same picture runs about 100 times faster.

Measured v/h and horizon:
- Swedish regional leaving Heby, public domain, https://archive.org/details/EvaVikstromStockFootageViewFromaTrainHebyMorgongavainAugust2006 : 14-24 s v/h = 5.3 /s, horizon 42% from top; 36-46 s v/h = 7.6 /s, horizon 38% (accelerating; about 60 then 85 km/h if the eye is 3.2 m above the field, my assumption).
- Tokaido Shinkansen over paddies, CC BY 2.0, https://commons.wikimedia.org/wiki/File:T%C5%8Dkaid%C5%8D_Shinkansen,_view_of_Ino,_Hiratsuka,_Kanagawa.ogv : v/h = 7.8 /s, horizon 48%. At 270 km/h that puts the eye 9.6 m up: the viaduct. A bullet train on a viaduct flows no faster than a country train on the flat.
- Trans-Mongolian in the Gobi, CC BY-SA 2.0, https://commons.wikimedia.org/wiki/File:Mongolia_Gobi_train.webm (cropped to the pane): v/h = 3.4 /s, horizon 66% down the pane. The slow one.

What that means on screen (Heby, 14-24 s, bands top to bottom):
- sky and cloud: 0.010 W/s (100 s to cross). Sun and Moon stand still unless the track curves.
- far tree line just under the horizon: 0.04-0.10 W/s (10-25 s).
- field 10% of frame height below horizon: 0.4 W/s (2.5 s).
- 25% below: 1.1 W/s (0.9 s). Bottom edge: 2.2 W/s (0.45 s).
So only the first fifth of the frame's height under the horizon takes over a second to cross. The bottom third is streaks at any real speed, even 60 km/h. Hiratsuka gave the same figures (0.4, 1.15, 2.2 W/s).

Masts: British electrified line, CC BY 4.0, https://commons.wikimedia.org/wiki/File:Duddeston_to_(nearly)_New_Street_-_2026-09-28_-_Andy_Mabbett.webm : six masts in a row passed 1.5-2.1 s apart (mean 1.8 s) at 0-12 s. A far-side mast (across the other track) took about 1.1 s to cross and reads as a crisp shape; a near-side one crossed 70% of the frame in 0.17 s (0.24 s for the whole frame): a flick. ICE on LGV Est, CC0, https://commons.wikimedia.org/wiki/File:ICE_9574_on_LGV_Est_window_view.webm : masts every 0.50-0.57 s (last five, 22.7-24.8 s), each one frame wide at 30 fps; a near-side mast is a translucent grey band 15% of the frame wide for 6-7 frames. Two flicks a second.

A wall of trees 5-15 m off (Heby 84-140 s, 30% of that clip) is full-frame flicker, every band above 1.5 W/s: the least calm thing a train window shows.

Computed from the law for a 16:10 screen, horizon 45% down, crossing time of the bottom row: 40 km/h eye 3 m: 0.8 s. 40 km/h eye 10 m (viaduct, sea wall, hillside): 2.6 s. 100 km/h eye 3 m: 0.3 s. 100 km/h eye 10 m: 1.05 s. A hill 2 km off at 40 km/h with a 60 degree view: 190 s.

Not usable: Commons' File:Train-window.webm is credited "Sora/OpenAI" (AI-made), so I dropped it. YouTube returned 403 to every video download, so nothing from YouTube was measured, only thumbnails looked at.

---

train-refs 2/8: THE RAILWAY'S EDGE: what stands there, how far apart, and which of it is calm.

Read (sources beside each):
- Overhead masts. Britain: "generally spaced 50-60 m apart", 65 m at most, closer on curves; contact wire 4.7 m above the rail; wires in 1200-1500 m lengths; plants cleared within 6 m of the track (Network Rail / Scotland's Railway guide, 2021, https://alanbaxter.co.uk/s/Scotlands-Railway-Guide-to-Overhead-Line-Equipment-November-2021.pdf). Germany: up to 80 m, 65 m on high-speed lines, new builds no more than 67 m; wire 5.5 m, 5.3 m high-speed (https://de.wikipedia.org/wiki/Oberleitung). Japan: about 50 m, less on curves; wire 5.1 m (https://ja.wikipedia.org/wiki/架空電車線方式). French-pattern high-speed: 63 m at most (https://koreascience.kr/article/CFKO200624718636207.pdf).
- Old telegraph poles: 25 to 40 a mile, most lines 32-35, so 40-64 m apart, "forty a mile" = 132 ft; every tenth pole banded (hobbyist forum, not a standard: https://forum.trains.com/t/telegraph-pole-spacing/64580).
- Second track: centres 3.26 m apart in Britain, 4.0 m in Germany (4.5 m at 250 km/h), 4.2 m on a French LGV, 4.23 m on the Tokaido Shinkansen (https://en.wikipedia.org/wiki/Track_spacing). So a passing train's side is about a metre from your glass.
- Platforms: 915 mm above the rail in Britain, 550 or 760 mm in the EU, 1100 mm in Japan, 1250 mm Shinkansen (https://en.wikipedia.org/wiki/Railway_platform_height).
- Not found with a source: how far masts and fences stand from the track. My estimate: masts 3 m from the track's centre, the fence 5-15 m.

Computed from those spacings: with masts 55 m apart one passes every 5.0 s at 40 km/h, 2.0 s at 100, 1.2 s at 160, 0.66 s at 300. Measured (message 1): 1.8 s on the British clip, 0.55 s on the ICE.

Measured or seen in the clips:
- Shinkansen between Kyoto and Osaka (https://commons.wikimedia.org/wiki/File:T%C5%8Dkaid%C5%8D_Shinkansen,_between_Ky%C5%8Dto_and_%C5%8Csaka.ogv, slit-scan of 20-60 s): the parapet and noise wall fill the bottom 32% of the frame as a brown streak. A pole crossed the frame in 4-5 frames (0.16-0.2 s) at 30 s.
- Narita Express over a river (https://commons.wikimedia.org/wiki/File:N%27Ex_view_from_Naka_River_to_Shin-Koiwa_Station.ogv, first seconds): a truss bridge's diagonals strobe across the whole window.
- Heby clip: a level crossing at about 120 s is one blurred frame of white gates and a waiting car; the station at 144 s on, arriving slowly, is the calmest and most readable part of the whole clip (red wooden station house, lamp posts, platform edge).

My sorting for a wallpaper.
Calm: wires rising to each far-side pole and sagging between (one swell every 4.5 s at 40 km/h with 50 m poles: the genre's signature motion); far-side masts and telegraph poles 8 m or more away (cross in a second or more); an embankment or cutting slowly rising to hide the view and falling again; a parallel road with a car keeping pace (https://commons.wikimedia.org/wiki/File:Northbound_on_the_Gautrain_2_-_Little_car_companion.webm, not downloaded); a river or canal alongside; a distant line with another train's lit windows; rolling slowly into a station.
A flick or a jolt: near-side masts and signal posts (0.1-0.25 s across); truss bridges; tunnels (a cut to black, then the cabin's reflection); a passing train (a 200 m train at 100 km/h each way is 3.6 s of full-frame flicker a metre away); platforms at speed; a wall of trees or a noise barrier; mileposts and cabinets (too small to read, just noise).
So: draw the far side of a double track (poles, wires, the other rails), keep the near side bare, and treat tunnels, bridges and passing trains as rare events behind a switch, like the airliner's lightning.

---

train-refs 3/8: THE WINDOW AND THE EYE.

Read:
- Shinkansen N700, standard class: glass 520 mm high x 500 mm wide, sill 780 mm above the floor, one per seat row (pitch 1,040 mm); its area was cut to about 60% of the 700's to save weight (https://ja.wikipedia.org/wiki/新幹線N700系電車). Nearly square and small, an airliner's window again. Platform and floor 1,250 mm above the rail (https://en.wikipedia.org/wiki/Railway_platform_height).
- Amtrak Superliner: coach windows 24 x 66 in (61 x 168 cm), two-piece, one per row; upper floor 104.5 in (2.65 m) above the rail; car 4.93 m tall; the Sightseer Lounge has "floor-to-ceiling windows" that "wrap upward into the ceiling" (https://en.wikipedia.org/wiki/Superliner_(railcar)).
- Floors in general: standard-gauge trains 1,300-1,370 mm above the rail, British and narrow-gauge ones 800-1,200 mm (same platform-height page).
- Glacier Express: panorama cars since 1986-93 and 2006, 2+1 seats in first, meals at the seat (https://en.wikipedia.org/wiki/Glacier_Express, https://de.wikipedia.org/wiki/Glacier-Express). No window size found.
- British Mark 1: slam doors, 90-100 mph (https://en.wikipedia.org/wiki/British_Rail_Mark_1). No window size there.
- Not found: sizes for a TGV, a Wagons-Lits sleeper or the panoramic cars.

Computed (a seated eye is about 1.2 m above the floor: seat 0.43 m + sitting eye height 0.79 m, my figure): eye above the rail about 2.5 m on a Shinkansen or European intercity, 2.3 m on a Mark 1, 2.2 m on the Swiss metre gauge, 3.85 m upstairs in a Superliner. Add 0.5-1 m of track bed for height above the field. On an N700 the eye is 81% of the way up the pane, so on flat ground the horizon lies a fifth of the way down the glass; in a tall picture window it lies 40-60% down, which is what the clips showed (38-48%; 66% in the Gobi sleeper).
What the seat hides: 0.5 m from the glass with the sill 0.4 m below the eye, the nearest ground in view is 3.75 m out; from 1.75 m back it is 13 m out. Sitting back from the window is how a real passenger loses the blur.

Measured by me on the stills (glass width : height):
- TGV bar car: 1.94:1, corners about 20% of the height, a lit soffit above (refs/frame-tgv-buffet.jpg).
- EuroNight sleeper: 1.46:1, corners about 12%, black gasket, a catch at top centre (refs/frame-sleeper-euronight-morning.jpg).
- Mark 1 bay: whole window 1.2:1; a main pane 1.7:1 under two sliding top-lights that take about 28% of the height; a table between facing seats in blue moquette (refs/frame-mk1-window.jpg, CC0).
- Norwegian coach: about 1.25:1, rounded, dark wood surround, an orange seat top each side (refs/view-snow-norway.jpg).
- Trans-Mongolian sleeper: a bar across at about 42% down, the upper part opens (refs/clip-gobi-window-frame.jpg).
- From the stated sizes: Superliner coach 2.75:1, N700 0.96:1.
- Panoramic cars (refs/frame-glacier-express-panorama.jpg, frame-rhb-panorama.jpg, frame-superliner-sightseer.jpg, frame-alaska-dome.jpg): side glass plus a curved roof light, slim pillars; they read as a glasshouse, not as a window.

What frames the glass in the photographs: a narrow sill or fold-down table; a roller blind's lip or a curtain on a rail; a luggage rack's line above; a seat's shoulder or headrest at one side; a coat hook; top-lights; a reading lamp in sleepers and Pullmans (refs/frame-pullman.jpg has the wooden sill).

For a 16:10 screen, my ranking:
1. A wide picture window, 1.8-2.0:1, big rounded corners, as on a European intercity or TGV bar car. It fills the screen with an even border and needs no stretching (the airliner's pane had to be widened). A sill with a table's edge below and a blind's lip above say train.
2. The Mark 1 bay: table, two seat backs, top-lights. Most character, symmetrical, pixel-friendly, reads as a train with nothing outside. Glass is about half the screen.
3. A sleeper at night: 1.45:1 window, lamp, curtain. The genre's favourite (message 6), but the glass is a third to half of the frame.
Not recommended: the Shinkansen's (too small, and it is the airliner again) and panoramic cars (roof glass does not read at this size, and their big view shows most near blur).

---

train-refs 4/8: SCENERY TO HOLD ON, with the real lines that show each and what a painter should draw. Facts read at the URL given; the tell-tale lists are mine, from the stills and clips.

1. WATER ALONGSIDE (calmest by the motion law: no near ground at all). Sea wall: Dawlish, 6.4 km at the foot of red cliffs beside the open sea, Brunel 1846, five short tunnels, the Parson and Clerk rocks (https://en.wikipedia.org/wiki/South_Devon_Railway_sea_wall; refs/view-coast-dawlish.jpg is a wave breaking over it, seen from the train). Lake: Erhai from train K9613 (refs/clip-lake-erhai.jpg), Lake Zell from the Transalpin (refs/view-lake-masts-transalpin.jpg). Draw: a railing or low wall as the only near thing, water to the horizon with a glitter path under the Sun or Moon, far shore as one blue band, boats, cloud shadows; crepuscular rays in the Erhai clip.
2. FARMLAND AND PADDIES. Tokaido Shinkansen, 285 km/h, 515 km (https://en.wikipedia.org/wiki/T%C5%8Dkaid%C5%8D_Shinkansen); the Hiratsuka clip (refs/clip-shinkansen-paddies.jpg): flat green paddies in small plots, glasshouses, a pylon line, tiled-roof hamlets, blue hills with cloud sitting on them, and from the viaduct you look down on roofs. Sweden (refs/clip-heby-fields-pd.jpg, public domain): gold and green fields in big blocks, dark spruce edge, red farmhouses, one pole line. England (refs/view-day-countryside.jpg): hedged fields, one telegraph pole, cumulus.
3. ALPINE PASS. Bernina: 2,253 m at Ospizio Bernina, 7% grades, Lago Bianco, Morteratsch glacier, Brusio spiral viaduct, 196 bridges and 55 tunnels, World Heritage 2008 (https://en.wikipedia.org/wiki/Bernina_Express). Glacier Express: 291 km in about 8 hours, Oberalp 2,033 m, Landwasser Viaduct, Rhine gorge (https://en.wikipedia.org/wiki/Glacier_Express). Flam: 20.2 km, 866 m of climb, 40 km/h at most, Kjosfossen waterfall (https://en.wikipedia.org/wiki/Fl%C3%A5m_Line). Draw: the train's own red cars on a curve ahead (refs/view-alps-bernina.jpg), a valley floor far below (so the near field is far), larch and spruce, stone viaduct arches, snow-shed and tunnel blinks, a milky lake.
4. DESERT AND STEPPE. Trans-Mongolian in the Gobi (refs/clip-gobi-window-frame.jpg, refs/view-desert-gobi.jpg): ochre grass to a dead-level horizon, one low blue range, a fence line, almost nothing near. Nullarbor: 478.193 km of dead-straight track, "dry and desolate", no permanent stream crossed (https://en.wikipedia.org/wiki/Trans-Australian_Railway). Jordan (refs/view-desert-jordan.jpg): banded red escarpment, scrub dots. The slowest-looking view there is; needs dust devils, a far road, cloud shadow to stay alive.
5. SNOW. Bergen Line: 371 km, 1,237 m at its top, Finse station 1,222 m, across the Hardangervidda plateau (https://en.wikipedia.org/wiki/Bergen_Line). Norway cliff valley (refs/view-snow-norway.jpg), Kyiv dawn (refs/clip-dawn-snow.jpg: everything blue-grey, lamps still lit), Anqing (Commons clip: snow on dark pines, grey sky). Draw: white fields with only fence tops and tree trunks dark, blue shadow, snow fences, yellow windows at dusk. Japan's "snow country" line is the Joetsu Line of Kawabata's novel (https://en.wikipedia.org/wiki/Snow_Country).
6. FOREST. Sweden again: a spruce and birch wall is flicker (message 1). Only usable as a far edge or from above.
7. CITY BY NIGHT, ELEVATED. Kyiv (refs/clip-night-city-windows.jpg): see message 5. The famous ones are Tokyo's Yamanote and Chuo lines (https://en.wikipedia.org/wiki/Yamanote_Line) and Chicago's Loop (https://en.wikipedia.org/wiki/Chicago_%22L%22); I found no openly licensed side-window night clip of either.
8. RIVER GORGE WITH CASTLES: the Middle Rhine (https://en.wikipedia.org/wiki/West_Rhine_Railway), not researched further.

"After a real one" candidates, each a recognisable sequence rather than a texture: the Dawlish sea wall (red cliffs, five tunnels, sea), the Bernina (lake, glacier, spiral viaduct), the Tokaido with Fuji (I could not confirm from a source which stretch shows it), the Nullarbor, the Bergen Line over Hardangervidda. Dawlish and a lake shore fit the motion law best: the near ground is water.

---

train-refs 5/8: NIGHT.

Measured on the night train out of Kyiv (CC BY 3.0, Eelis Hyvärinen, https://commons.wikimedia.org/wiki/File:Night_train_from_Kyiv_to_Chernivtsi_(Ukraine).webm; frames saved as refs/clip-night-city-windows.jpg and clip-night-station-lamps.jpg):
- Lit pixels: 0.2-2.0% of the frame in eleven frames across 0-88 s; 0.74% over 56-86 s. (The airliner research found 1.5-3% from the air.)
- Their colours, 56-86 s: 37% warm (mean #d2c08e), 27% white (#b9bab3), 36% blue-green (#9eadb8; an LED-lit tower is in shot, so this share is high).
- The dark is not blue and not black: mean #1d1817, a warm brown-black, with a sky lighter than the buildings (frame medians 16-41 of 255). Tower blocks are silhouettes slightly darker than the sky with a sparse grid of lit windows, perhaps one in six.
- Pace, 56-72 s: the lit blocks drift at 0.07-0.10 W/s (10-14 s to cross), the near ground at 0.15-0.20. A night train leaving a city is slow, and it reads calm.
- What there is to see: white station floodlights with star-shaped flare in a row along a yard; orange street lamps with haloes; yellow windows; red tail lights and a wet road's sheen; one blue-and-green LED facade. In the dawn half of the clip (100 s on) everything is blue-grey snow with the lamps still lit.

The reflection, computed (assumptions marked):
- Glass returns about 4% of the light at each surface (n = 1.5; https://en.wikipedia.org/wiki/Fresnel_equations), so 8% for one pane and 15% for double glazing.
- Cabin lighting: I assumed 200 lux (between a living room's 50 and an office's 320-500, https://en.wikipedia.org/wiki/Lux; the railway lighting standard EN 13272 exists but I could not read its figure). Pale walls at 200 lux have a luminance near 32 cd/m2, so their reflection is 2.5-5 cd/m2.
- Outside under a full moon (0.05-0.3 lux, same page) a field is 0.003-0.02 cd/m2: the reflection is 100 to 1,000 times brighter. At the dark limit of civil twilight (3.4 lux) the land is still about 15 times dimmer than the reflection. On an overcast day (1,000 lux) the land is 15-25 times brighter than it, and in full daylight several hundred times.
- So the glass turns from window to mirror during civil twilight, with the crossover at about 50 lux outside. After that only lamps come through (a lamp is thousands of cd/m2), and you see the land only with the cabin lights off or your face to the glass.
- By day the reflection still shows over anything dark, and ceiling lamps show even over the sky: refs/view-day-ceiling-lights-reflected.jpg (a row of pale dashes across the sky), refs/view-desert-jordan.jpg (the opposite windows as pale ghosts), refs/view-dusk-station.jpg (an orange ghost of the cabin over a peach sky, platform lamps lit), refs/view-night-sleeper-window.jpg (station lights as streaks under a faint cabin).

How artists handle it:
- Kawabata's Snow Country opens on exactly this: a girl's face in the evening window with the landscape sliding behind it, and a light in the hills shining through her eye (https://en.wikipedia.org/wiki/Snow_Country; from memory of the book).
- Hopper's Compartment C, Car 293 (1938) leaves the reflection out: a lit green compartment and a small dusk landscape in the glass (https://en.wikipedia.org/wiki/Compartment_C_Car_293; from memory).
- All nine night ambience videos whose pictures I looked at (message 6) keep the outside readable as a dim blue or green scene and put the warmth inside as a lamp. None paints a true mirror. The genre cheats, as our lifted orbit night does.

Suggestion: the outside stays readable (a lifted, blue-shifted night, lamps at about 1% of pixels, mostly warm), and the reflection is a faint ghost of a lamp, a seat's shoulder and a dashed line of ceiling lights, drawn only over the dark parts, fading in as the Sun goes from 0 to 6 degrees below the horizon, with a switch. A true mirror would hide the wallpaper.

---

train-refs 6/9 (one more than promised): RAIN AND SNOW ON THE GLASS.

Footage. Commons and the Internet Archive had no rain-on-a-train-window video I could find, and YouTube refused downloads, so I measured three clips from Pexels. The Pexels licence is free to use but is not a Creative Commons licence, so they sit in scratchpad/train/pexels and not in refs.

Measured:
- Moving train on a viaduct, speed unknown (https://www.pexels.com/video/raindrops-sliding-on-a-train-window-4640062/, frames at 1.5-5.5 s; the scene behind crosses at 0.10-0.22 W/s): the water travels as two to four long thin threads that each span the whole pane, lying about 9 degrees below level, dropping toward the rear. A thread wobbles in small zigzags (about 3% of the pane's height) and keeps to the same path for seconds while water runs along it; a new one starts as a fat pale ribbon and thins to a dark line. Between the threads small beads sit still.
- Train creeping through a yard (https://www.pexels.com/video/raindrops-on-train-window-13255056/, 2-8 s; scene speed under 0.01 W/s): hundreds of beads, each a teardrop with its tail upward, and trails that run straight down with a slight lean. Beads did not move between frames half a second apart; a drop only runs once it has merged with others.
- Heavy rain, Koblenz to Luxembourg (refs/view-rain-heavy.jpg, CC BY-SA 4.0, Smiley.toerist): the pane is a sheet of fine parallel streaks, about 15 degrees off the window's vertical by my measure (the camera is rolled, so give or take 10), with three thick wavy threads near the top lying level. Two regimes on one pane. The train's speed at that moment is unknown.
- From an ICE in rain (refs/view-rain-ice.jpg, CC0, Daniel Mietchen): the glass is a film, and trees outside are soft green blobs. Wet glass blurs the view more than it decorates it.
- Standing train (refs/view-rain-droplets.jpg, CC BY-SA 4.0): beads only, each a tiny upside-down picture of what is behind it.
- Night (https://www.pexels.com/video/raindrop-reflections-on-nighttime-metro-glass-31069867/): beads are dark-rimmed dots each holding a speck of light; the lamps behind are soft discs of blue and orange because the camera, like the eye, focuses on the glass.

Read and computed:
- Raindrops fall at about 2 m/s (0.5 mm drizzle) to 9 m/s (5 mm) (https://en.wikipedia.org/wiki/Rain). Seen from a moving train the rain in the air outside therefore slants at atan(v / fall speed) from the vertical: 51-80 degrees at 40 km/h, 72-86 at 100 km/h, 84-89 at 300. Above about 60 km/h falling rain is nearly level streaks.
- On the glass, my estimate, not a measurement: the air's push on a drop grows with its area and the square of the airspeed, its weight with its volume, so small drops and fast trains run flat, big drops and slow trains run down, and a stopped train's run straight down. That fits the three clips. The one paper found is on car side windows and says drop size and wind speed decide the direction, including upward; its full text returned 403, so I have only the abstract (https://doi.org/10.1051/emsci/2019002).

For the painter: (1) beads that stay put, denser with heavier rain; (2) a few long level threads at speed, tilting toward vertical as the train slows, straight down at a stop: tie the angle to the Speed slider and it is both true and a nice touch; (3) each thread persists and wobbles rather than streaking by; (4) outside, soften and lower the contrast of the view in rain; (5) at night give each bead one bright pixel taken from the nearest lamp's colour.

Snow: not found. No clip showed snow falling past the glass (Anqing and Kyiv show lying snow), so flake behaviour on a moving window is unmeasured.

---

train-refs 7/9: THE GENRE. Reference only, all copyrighted, nothing copied or kept beyond thumbnails in scratchpad/train/genre. I could look at each one's picture (its public thumbnail) but not its motion: YouTube returned 403 to downloads. View counts are from YouTube's search on 2026-10-10.

1. Spirited Away (2001), the sea railway; clip "The Sixth Station", 8.0M views, https://www.youtube.com/watch?v=VbRmFSQYeac . A train on a flooded plain under sunset cumulus. Its secret is that there is no near field at all: water to the horizon, then single far things.
2. "Relaxing Spirited Away Train Ride", 2.0M, https://www.youtube.com/watch?v=-t1YQYwlikg : a side bench under a row of windows, hand straps, red seats, violet dusk in the glass.
3. "Falling asleep on the train at night when it's raining", 6.6M, https://www.youtube.com/watch?v=UARcKU2LuWY : grey-blue, a big rainy window over a bunk, mountains as one shape.
4. "Train Sounds & Rain for Sleep", 5.1M, https://www.youtube.com/watch?v=-xiF9YIIUk4 : a wall-wide window of blue rain, one wall lamp.
5. "Night Train Ambience on a Rainy Night", 4.5M, https://www.youtube.com/watch?v=GlrhYhvM490 : wood-panelled sleeper seen head-on, window a third of the width, a lit table lamp under it, beds and curtains each side; amber inside, grey-green outside.
6. "The Hogwarts Express | Train Ride + Rain", 2.9M, https://www.youtube.com/watch?v=Ub9FroGpl_g : the facing-seats compartment.
7. "Cosy Sleeper Train on a Rainy Evening", 2.7M, https://www.youtube.com/watch?v=aRwvWi1MYr0 : flat illustration, orange cabin, a low wide window of navy starry rain, lamp and open book.
8. "Rainy Night Train Journey, Dimly Lit Sleeper", 1.5M, https://www.youtube.com/watch?v=oTqlVuGk8Yc : nearly one colour (dark teal); a rounded window about 1.9:1 across 55% of the frame, beads on it, pine silhouettes; no lamp.
9. "Autumn Night Train Window, Rainy Coast View", 26k, https://www.youtube.com/watch?v=6mp9Ye0jyvs : anime style, a green commuter car's bench with a bag on it, a wide window over a bay town's lights; teal with warm specks.
10. Chillhop's "Harlow x Chillhop [Train Ride Relax]", 49k, https://www.youtube.com/watch?v=p9c2WAy_Q04 : the raccoon dozing at a window table with coffee, a mesa at dusk, everything in one amber family.
11. Pixel art, small channels (several look machine-made): "Interlaken Train Ride, Lake Brienz Window View", https://www.youtube.com/watch?v=sjSQXhhWKIc : the window is about 80% of the frame at 2.4:1, a turquoise lake and Alps, a sill with a cat, a cup and a lamp; the nearest thing to Dave's brief. "Rainy Pixel Train Ambience", https://www.youtube.com/watch?v=8pIUr-Qvpcs : navy carriage, one amber lamp. "Night Train Lofi, fireflies", https://www.youtube.com/watch?v=zFiY1BK0mgY : a dining table by a tall window, crescent moon, lanterns.
12. Prior art closest in idea: Ben Villiere's "Passenger", generative art about glancing out of a train window at an endless world, with 8 themes, 5 landscape types and a day-night cycle (https://www.raster.art/artwork/passenger-by-ben-villiere/about ; from a search summary only, the page returned 429).
13. For mood, not a window view: Toyoi Yuuta (1041uuu), 8-bit loops of everyday Japan, one of a level crossing with a train passing (https://spoon-tamago.com/nostalgic-gifs-of-everyday-life-in-japan-animated-by-yuuta-toyoi/).
No well-known pixel-art window-seat piece by a named pixel artist turned up, as with the airliner.

What the calm ones share (from the pictures):
- One warm light inside against one cool family outside. Two colour families, no more.
- The window is flat and head-on.
- Outside has at most three depths (sky, far silhouette, mid lights or trees) and nothing between the track and the middle distance. Almost none draws poles. They dodge the blur by leaving the near field out.
- Rain on the glass does the moving, so the land can be slow.
- Something still to rest the eye on: lamp, cup, cat, book.
- 9 of the 13 are night or rain, 2 dusk, 2 sunny (both pixel).
- Glass share: a third to half of the frame in the sleeper kind, about 80% in the window-view kind.
Unmeasured: how fast their layers scroll.

---

train-refs 8/9: SPEED FOR CALM, LIVE DATA, MY RECOMMENDED DEFAULT, AND WHAT TO PUT TO DAVE.

Real speeds (read): Glacier Express 291 km in about 8 hours, so about 36 km/h by my division, "the slowest express train in the world" (https://en.wikipedia.org/wiki/Glacier_Express). Flam line 20.2 km in 50-59 minutes, 40 km/h at most uphill and 30 down (https://en.wikipedia.org/wiki/Fl%C3%A5m_Line). Superliner 100 mph, 161 km/h (https://en.wikipedia.org/wiki/Superliner_(railcar)). Tokaido Shinkansen 285 km/h (https://en.wikipedia.org/wiki/T%C5%8Dkaid%C5%8D_Shinkansen). Measured for feel: the slow Gobi train's ground at the foot of the pane crossed in 1.2 s; the night train's lit blocks in 10-14 s.

The sum that decides it (from the law in message 1; a 16:10 screen, a 60 degree view, which is an eye 1.2 m back from a 1.5 m window): bottom row's crossing time = 5 x h / v seconds when the horizon is 68% down the screen (h in metres, v in m/s).
- 40 km/h, eye 3 m above flat fields: 1.35 s. A rush, and it is the truth for flat country.
- 40 km/h, eye 10 m up: 4.5 s. Eye 20 m up: 9 s. The nearest ground in view is then 43-87 m off.
- 100 km/h, eye 20 m up: 3.6 s.
- A range 3 km off: 280 s. Trees 500 m off: 47 s. A pole line 25-30 m off: 2.4-2.8 s per pole, one every 4.5 s at 50 m spacing. A far-side mast 8 m off: 0.75 s, too quick.
For comparison the airliner's bottom row takes about 100 s, so this would still be the livelier wallpaper by ten times.

Recommended default.
- Train: a slow scenic one at 40 km/h true speed (1x), after the Glacier Express's pace. Speed slider 0.5x to 3x, as the airliner has.
- The liberty, in place of the airliner's "features drawn larger": the line runs high. On a ledge, embankment, viaduct or sea wall, 10-20 m above a wide valley, lake or shore, so the land starts 40 m and more away. Real scenic lines do this; ours does it all the time.
- Big sky: horizon 65-70% down (the Gobi pane was 66%, the English field still about 70%). That halves the fast ground on screen and gives the real Sun, Moon, stars and weather the room.
- Near things: one pole line with sagging wires 25-30 m out and nothing nearer. Tunnels, truss bridges, a passing train and stations as rare events behind a switch, stations approached slowly.
- Frame: the wide picture window (about 1.9:1, rounded) with a sill, a table's edge and a blind's lip. Window sizes and None as the airliner has.
- Night: lifted and readable, lamps about 1% of pixels, mostly warm; a faint cabin ghost that grows through civil twilight, with a switch.
- Rain when it rains where the user is: beads, plus two to four level threads whose tilt follows Speed.

Choices most worth mock-ups for Dave:
1. The frame: wide picture window filling the screen / Mark 1 bay with table, seats and top-lights / night sleeper with lamp and curtain.
2. The near ground: high line with no near field (water or a valley below) / true flat country with the bottom band as soft streaks / the genre's scrolling layers, which are familiar but not true.
3. The night glass: readable night with no reflection / with the faint ghost / a true mirror with only lamps coming through.
A fourth if wanted: 40 km/h scenic against 100 km/h, as a ten-second strip each (see the memory note about checking motion, not stills).

Live data: no new feed needed. From what the app has: the Sun's altitude sets the mirror's strength; rain rate sets bead density; temperature picks snow or rain; the date and hemisphere pick green, gold or stubble fields. One real-data idea that is a file, not a feed: bake a real line's profile (heights and land cover along the Bernina or the Dawlish coast, from public-domain SRTM and Natural Earth) so the scenery comes in the real order. Bigger than the first version needs. I did not check those data sets.

---

train-refs 9/11: REFERENCE STILLS, part 1: window frames. (Three credit messages, so 11 in all.)

All in scratch/train/refs/ , 42 files, 7 MB. Full URLs for every file are in refs/CREDITS.tsv (file, title, author, licence, source). Each source below is https://commons.wikimedia.org/wiki/File: followed by the title given, spaces as underscores. Photos are 1280 px copies unless the original was smaller.

- frame-mk1-window.jpg: Andy Li, CC0. "Train window of the West Somerset Railway 2025-07-27.jpg". The Mark 1 bay: table, facing seats, top-lights. The best single frame reference.
- frame-mk1-compartment.jpg: James E. Petts, CC BY-SA 2.0. "BR Mark I corridor carriage, interior - 26419418910.jpg". Compartment window, moquette, veneer.
- frame-tgv-buffet.jpg: TeaMeister, CC BY 2.0. "Watching the world go by - from the buffet car of a French high-speed train - Flickr - TeaMeister.jpg". The wide rounded picture window with a lit soffit.
- frame-sleeper-euronight-morning.jpg: Clay Gilliland, CC BY-SA 2.0. "From the overnight Cologne to Vienna EuroNight sleeper train. (11356968335).jpg". Black rounded window from a dark compartment, fields at first light.
- frame-sleeper-nightjet.jpg: Dining Car (Flickr), CC BY-SA 2.0. "Nightjet NJ40490 DSCF1860 (51204425343).jpg". Through a Nightjet window, the field blurred.
- frame-pullman.jpg: Ethan Long, CC BY-SA 2.0. "Essex Steam Train Pullman Car Window (53796625423).jpg". Wooden sill and catch.
- frame-superliner-sightseer.jpg: 4300streetcar, CC BY 4.0. "Amtrak Superliner Sightseer Lounge on Southwest Chief in New Mexico May 2024 1.jpg".
- frame-superliner-coach.jpg: Peter W. Svendsen, CC BY-SA 3.0. "California Zephyr near Denver, Co. wiki pws.JPG". Coach window with a passenger's reflection.
- frame-glacier-express-panorama.jpg: JoachimKohler-HB, CC BY-SA 4.0. "1. Klasse Glacier-Express Panoramia-Wagen (2014).jpg".
- frame-rhb-panorama.jpg: dirt (Flickr), CC BY 2.0. "Rhätische Bahn Panoramawagon.jpg". Snow outside.
- frame-alaska-dome.jpg: Richard N Horne, CC BY-SA 4.0. "Interior of an Alaska Railroad train Ultra Dome Car at the Denali National Park.jpg".
- frame-intercity-cd.jpg: Leif Jørgensen, CC BY-SA 4.0. "Interior of ČD Bbmpz 73 54 84-90 019-7 04.jpg". A Czech intercity window from inside, with a reflection.
- frame-shinkansen.jpg: shankar s., CC BY 2.0. "The seats on Shinkansen trains are in 3 - 2 formation (49495464251).jpg". Looks down the aisle; the small windows barely show. Weak: no good openly licensed N700 window-seat photo turned up.

Gaps: no TGV seat-and-window photo, no classic Wagons-Lits compartment with lamp and curtain, no British slam-door seen from outside. The sleeper-with-lamp look is known only from the copyrighted ambience videos.

Note for whoever builds: licences here are CC BY and CC BY-SA as well as CC0. They are for looking at. Nothing of them should be traced or shipped unless its licence and credit go into About, and the CC BY-SA ones would bind any cut-out made from them.

---

train-refs 10/11: REFERENCE STILLS, part 2: views by day, dusk, night and rain. Same folder (scratchpad/train/refs/), same rule for the source: https://commons.wikimedia.org/wiki/File: plus the title, spaces as underscores; full URLs in refs/CREDITS.tsv.

Day:
- view-day-countryside.jpg: James Petts, CC BY-SA 2.0. "Train window landscape (24014361208).jpg". English fields, one telegraph pole with wires, cumulus; horizon about 70% down.
- view-lake-masts-transalpin.jpg: Dining Car (Flickr), CC BY-SA 2.0. "EC164 Transalpin 20200808 134651 (50262359866).jpg". A lake past a hedge, near catenary masts, the track curving.
- view-alps-bernina.jpg: Armineaghayan, CC BY-SA 4.0. "Bernina Express from Train window by ArmAg (1).jpg". The train's own red cars on a curve, fog.
- view-mountains-jasper-dome.jpg: Steverelei, CC BY-SA 3.0. "Jasper lake mountains from dome.jpg". Lake and range through a framed window.
- view-snow-norway.jpg: Ciara Ní Riain, CC BY-SA 4.0. "Train window view Norway.jpg". A snowy cliff valley in a rounded window between two orange seat tops; a frame reference as well.
- view-desert-jordan.jpg: Rockingsammy, CC BY-SA 4.0. "Deserts of jordan.jpg". Red escarpment, with the opposite windows reflected as pale ghosts.
- view-desert-gobi.jpg: Matthewmayer (assumed by Commons), CC BY 2.5. "Trans mongolian gobi.jpg". The train curving ahead over steppe.
- view-coast-dawlish.jpg: Derek Harper, CC BY-SA 2.0. "Breaking wave near Dawlish - geograph.org.uk - 721232.jpg". A wave bursting over the sea wall, from the train.

Reflections by day:
- view-day-ceiling-lights-reflected.jpg: Almanta, CC BY-SA 4.0. "Train illumimation reflected on window.jpg". The cabin's lamps as a dashed line across the sky, over a rail yard with masts and a signal.
- view-day-reflection-tgv.jpg: Phillip Capper, CC BY 2.0. "Felicity reflective, Paris-Milan TGV, 2009 - Flickr - PhillipC.jpg". Hands and a camera reflected over a cliff.

Dusk and night:
- view-dusk-station.jpg: Junkyardsparkle, CC0. "Northridge metrolink station from train at sundown.jpg". Platform lamps lit against a peach sky, an orange ghost of the cabin.
- view-night-sleeper-window.jpg: Andrew Nash, CC BY-SA 2.0. "Night Train Vienna to Brescia Italy 2012 - 10 (6821515349).jpg". A station passing as streaks of light under a faint reflection.

Rain:
- view-rain-heavy.jpg: Smiley.toerist, CC BY-SA 4.0. "Heavy rain on train Koblenz Luxembourg.jpg". The sheet of fine streaks and the level threads (message 6).
- view-rain-ice.jpg: Daniel Mietchen, CC0. "Blick aus einem ICE-Fenster bei Regen.jpg". Seat, side table, blind and a film of water blurring the trees.
- view-rain-droplets.jpg: Jules Verne Times Two, CC BY-SA 4.0. "Rain droplets on the window of a narrow-gauge train coach, Mariefred station, Eastern Södermanland Railway Museum, Sweden julesvernex2.jpg". Beads on a standing coach's glass.

Gaps: no openly licensed still of a lit landscape at night from a train with the cabin's reflection, none of rice paddies by day other than the clip frame, none of falling snow.

---

train-refs 11/11 (last): CLIP FRAMES, WHAT WAS BLOCKED, TWO CORRECTIONS.

Frames I cut from the open clips, in scratchpad/train/refs/ (URLs in refs/CREDITS.tsv; the clips themselves, 235 MB, are in scratchpad/train/video/):
- clip-heby-fields-pd.jpg (20 s), clip-heby-level-crossing-pd.jpg (126.1 s), clip-heby-station-pd.jpg (170 s): Eva Vikström, public domain, https://archive.org/details/EvaVikstromStockFootageViewFromaTrainHebyMorgongavainAugust2006 . The only public-domain footage; 188 s of fields, forest, a crossing and a station.
- clip-shinkansen-paddies.jpg (3 s): Cristina Bejarano, CC BY 2.0, Commons "Tōkaidō Shinkansen, view of Ino, Hiratsuka, Kanagawa.ogv".
- clip-shinkansen-parapet.jpg (58 s): Mike B in Colorado, CC BY 2.0, "Tōkaidō Shinkansen, between Kyōto and Ōsaka.ogv".
- clip-gobi-window-frame.jpg (10 s): Clay Gilliland, CC BY-SA 2.0, "Mongolia Gobi train.webm".
- clip-night-city-windows.jpg (62 s), clip-night-station-lamps.jpg (12 s), clip-dawn-snow.jpg (140 s): Eelis Hyvärinen, CC BY 3.0, "Night train from Kyiv to Chernivtsi (Ukraine).webm".
- clip-uk-masts-lineside.jpg (4.6 s): Andy Mabbett, CC BY 4.0, "Duddeston to (nearly) New Street - 2026-09-28 - Andy Mabbett.webm".
- clip-ice-mast-smear.jpg (11.9 s): RAIL P (RAIL.PHOTOGRAPHY), CC0, "ICE 9574 on LGV Est window view.webm". A near-side structure filling the frame as a grey smear.
- clip-snow-ceiling-light-reflection.jpg (14 s): Fumikas Sagisavas, CC BY 4.0, "View of Anqing snow scene from the high-speed train window (20250208 ~ Video 1).webm".
- clip-lake-erhai.jpg (12 s): Nikita Yang, CC BY-SA 4.0, "The view of Mount Cang and Erhai Lake outside the train K9613 in winter 2015.ogv".
- clip-truss-bridge-strobe.jpg (1 s): Dushan Hanuska, CC BY-SA 2.0, "N'Ex view from Naka River to Shin-Koiwa Station.ogv".
Also looked at, not used: "Bewegungsparallaxe (Wetterau).webm" (Rhetos, CC BY-SA 4.0), a German teaching clip of this very parallax in 10x slow motion; its captions spoiled the band measurement.

Corrections to earlier messages:
- Message 2 said the Heby level crossing is at about 120 s. It is at 125.8-126.5 s and lasts 0.65 s from the first sight of the waiting car to the last: crossbuck and car as a doubled, blurred glimpse.
- Message 1 used 270 km/h for the Shinkansen. The line's top speed is 285 km/h (its Wikipedia page), which puts the eye 10 m above the paddies, not 9.6. I do not know that train's actual speed.

Blocked or failed, and not worked round:
- Commons' search API returned 429 once, early (my script fired twelve searches in a row; my mistake). I waited ten minutes and then kept to one file every 13 s; no 429 after that. 13 clips and 29 stills came down.
- Two Commons transcodes returned 404 ("Tokyo to Kyoto on the bullet train", "Brahmapur to Icchapuram train window view"); the originals are 0.7 and 2.8 GB, so I left them.
- YouTube: 403 on every video download. Only search listings and thumbnails were read.
- 403: the Emergent Scientist paper on drops on car windows (page and PDF). 429: raster.art ("Passenger"). Connection refused: Bane NOR's overhead-line rules.
- Dropped: Commons "Train-window.webm", credited to Sora/OpenAI, so not real footage; deleted from the scratchpad.

Not verified, flagged where used: every train's actual speed in the clips (only v/h is measured); cabin lighting of 200 lux; mast and fence distances from the track; the seated eye height of 1.2 m; the two book and painting descriptions; genre motion speeds.

Scripts, in scratchpad/train/scripts/: flow.py (band speeds), poles.py (pole timings), slit.py (slit-scans), wmget.py (polite Commons fetch), cinfo.py and csearch.py (licences, search). Working sheets are in scratchpad/train/frames/. Nothing was written in the repo.
