# Pixel City

A pixel-art city that follows the real Sun and clock. The sky moves through dawn, day, dusk and night, with the Sun and Moon in their real places and stars after dark. Windows light up and go dark through the evening, cars and buses run in both lanes (with headlights at night), a beacon blinks on the tallest tower, and the odd plane crosses. Settings picks the city:

- **Waterfront** (the default, from 2026-10-04): a downtown seen across water, which mirrors it in ripples. The skyline peaks in the middle and falls away to low flanks, so the Sun and Moon rise and set in view, and the walls are lit from wherever the Sun really is.
- **Street:** the original, side-on from the kerb, with a near and a far row of plain blocks.
- **Foothills** (2026-10-04): a small downtown far off under three ridges of mountains, the highest snow-capped, across a valley floor with a highway and a line of pines.

- **Files:** `Sources/Atrium/PixelCity.swift`, which holds everything: the scene, both cities, the `Pixels` canvas, sprite art as strings, `SeededRandom`, the water's shader and its own low-precision `skyPosition()` for the Sun. It reads `Location.swift` ([live-sky.md](live-sky.md)).
- **Entry:** `pixelCity(size:)` builds `final class PixelCity: SKScene`. Its entry in Scenes.swift is "Pixel City", icon `building.2.fill`, tint `.pink`, with `PixelCity.knobs`.
- **Kind:** SpriteKit on a low-resolution canvas. Two backdrop textures are repainted every 30 s, the sky and the city in front of it, and sprites for the moving things all sit under a `canvas` node scaled up by the pixel size. Every texture uses `.nearest` filtering, so it stays crisp.

## How it works
- **Resolution:** `pixel = max(2, round(height/240))` points per art pixel, so 4 pt on a 982 pt-tall display. The canvas is `w × h` art pixels (378 × 246 there). Motion rounds to whole art pixels so nothing blurs.
- **Layers,** by `zPosition`: the sky (0), clouds (1), the plane (1.5), the city (2), the water (2.5), cars (3 and 4), the beacon (5). The city texture is clear wherever the sky shows, so clouds and planes pass behind the towers.
- **A city is a case of `City`** (the menu's order, stored as the index, so new ones go at the end). `layOut()` sets what differs: `ground` (the row the city stands on), `waterRows`, `crest` (for each column, the row where the sky begins, which is the horizon the Sun and Moon rise over) and `skyBase` (the lowest of those, where the sky's gradient starts). `classic` is true for the Street, which keeps its first, simpler sky and light.
- **`layOut()`** builds everything that never changes, and runs again when Settings picks another city. Each city has its own skyline (`layOutStreet`, `layOutWaterfront`, `layOutFoothills`) from a fixed `SeededRandom`, so it's identical on every redraw and every display. Shared by both: 170 stars, 3 cloud masks, a pool of 6 cars per lane with headlights (7 sedan colours plus a bus), a plane with blinking nav lights, and the beacon (0.25 s on, 1.25 s off) on the landmark.
- **`redraw()`** runs at init, every 30 s and when a setting changes. It paints the sky into one `Pixels` buffer and the city into another:
  - **Sky:** a gradient between zenith and horizon colours from `skyColours(elevation, morning:)`. The stops run −18°, −10°, −4°, 0°, 6° and 15°, and dawn is pinker than dusk. Around a low Sun the horizon's colour changes with the compass (`horizonToward`): orange under the Sun and, opposite it, the pink band over the Earth's shadow, so a sunset sky differs from one side of the screen to the other. It's quantised into 14 bands with 4×4 Bayer dithering, plus a sun glow around a low Sun in 5 flat rings, dithered only where two rings meet (dithering right across each ring left a halo of loose dots).
  - **Stars** fade in below about −5°; the brightest get a small cross.
  - **Moon:**
    - **Phase:** from a mean synodic month counted from the new Moon of 2000-01-06 18:14 UTC.
    - **Position:** the Sun's ecliptic longitude plus phase × 360° (no lunar inclination).
    - **Lit side:** on the right while waxing.
    - **Earthshine** on the dark part at night.
    - **Size:** an 8-pixel radius. A thin crescent is drawn at least 1.6 pixels wide, because at this size a true one breaks into specks.
  - **Sun:** a 6-pixel-radius disc, orange near the horizon.
  - **Street** (`drawStreet`, standing on `streetBase`): sidewalks, road markings, and a lamp every 46 pixels casting a three-step pool of light at night.
  - Clouds, cars and the plane are recoloured for the light: day and night car textures, the plane turning into a dark silhouette, and headlights fading in at night. A headlight is a pool of light lying on the road ahead, added to the road's colour (`blendMode = .add`) and drawn under the car in front. Clouds are solid, so they hide the stars behind them.
- **`update(_:)`** runs every frame:
  - **Cars:** they move at their cruise speed (buses 11–14, cars 14–22 art pixels per second). A car closes up behind a slower car in the same lane (gap < 6) instead of driving through it.
  - **Spawning:** new cars come in from the pool every `(1.5–6 s) / traffic`, where `traffic` is an hourly table with rush hours at 08:00 and 17:00 and quiet small hours. 10% of spawns are buses.
  - **Clouds** drift and wrap.
  - **Plane:** one every 40–120 s, at 7 px/s, somewhere in the top 20% of the sky.

### The Street city
- **Far row:** hazy blue-grey buildings. **Near row:** brick, stone and concrete blocks (`Kind.box`, drawn by `draw`), with per-building window spacing (`floor`, `pitch`) and a roof (plain, ledge, setback or water tank).
- **The landmark:** the widest near building around 3/5 across is raised to 50% height, with an antenna and the beacon.
- **Light:** facades darken toward moonlit blue at night, and the far row takes on the horizon colour as haze. The only direction in it is `keyFront`: a Sun or Moon at our backs lights the fronts, which by default happens on summer mornings and evenings.
- **Windows** turn on one by one via `isLit()` with three seeded draws per window. About 65% are lit on an evening schedule: people get home between 16:30 and 21:00 and go to bed between 21:00 and 03:00. 30% come on for early risers from 05:30. 3% are always on (stairwells and night owls). The colours are mostly warm tungsten, with a few cool blue or white ones.

### The Waterfront city
Built from a design review on 2026-10-04 (see Dave's feedback below), after a look at a few openly licensed pixel-art cityscapes on OpenGameArt for what makes them read: side walls in a darker tone, lights in sparse dashes rather than a grid, stepped silhouettes, several depth rows. Nothing was copied; all of it is drawn in code.

- **Composition,** bottom to top: water (the bottom 21%, calm, and where the Dock sits), a 6-row quay wall, the street on top of it (`streetBase` is above the water here, so the traffic clears the Dock), then the city, with a far shore of low hills (`drawHorizon`) behind the gaps.
- **Skyline** (`layOutWaterfront`, seed 2030, picked from six for its shape and for parks where the Sun sets): `downtown(x)` is 1 across the middle quarter and falls to 0 by 30% either side of centre, and every height is a share of the sky above the street scaled by it. Three rows:
  - **Haze:** windowless towers behind downtown only (`Kind.haze`), 80% of the way to the sky's colour, with a few specks of light at night.
  - **Far:** stone, glass and slab buildings at half the detail. On the flanks half the plots are left open.
  - **Near:** downtown is stone and glass towers and slabs; the flanks are brick walk-ups, slabs and parks (40% of flank plots, `drawParks`: a hedge and round trees lit from the Sun's side). Buildings touch or stand 3 or more pixels apart, because a 1-pixel gap glows like a glitch at dusk.
  - **The landmark:** the widest near building around 55% across becomes a stone tower two thirds of the sky tall, with a crown, a spire and the beacon.
- **Four kinds of building** (`Kind`, drawn by `drawTower`):
  - **`deco`:** stone tiers stepping in to a crown, windows in tall strips between piers, a lit doorway.
  - **`glass`:** a curtain wall that mirrors the sky (zenith at its top, horizon at its foot, so it warms at sunset), a dark line at every floor, mullions, a lobby, and a flat, slanted or plant-room top.
  - **`brick`:** a walk-up with sash windows and sills under a cornice, a fire escape on about half, a shop under a striped awning (lit from 7 until it closes, between 8 and 11 at night), and a tank, stair head or chimney on the roof.
  - **`slab`:** concrete with ribbon windows, on columns over an open ground floor.
- **Light with a direction.** `ambient` is what the sky gives every wall (cooler toward dusk, moonlit blue at night). The Sun, and after dark the Moon scaled by its real phase, add to walls that face them: `keyRight` and `keyLeft` for side walls, `keyFront` for fronts, `keyTop` for roof edges, each the cosine of the angle between the light and that wall. By default we look toward the equator, so the Sun is behind the city for most of the day: fronts stay in the sky's cool light and only catch the Sun when it's behind us (summer mornings and evenings), while side walls light up warm at one end of the day and fall into shadow at the other. Looking another way (Settings → Looking) changes all of it: face east and the fronts turn gold at sunset, with the Sun out of the picture behind us. Glass fronts mirror the horizon at our backs (`behind`). `lit(colour, key, shade:)` applies it.
- **Side walls.** Each building shows a sliver of the wall facing the middle of the screen (`side`, 1 to 5 pixels, wider toward the edges), as one-point perspective would. So in the morning the walls on show right of centre are sunlit, and in the evening those left of centre.
- **Windows in dashes** (`storey`): a floor's windows are lit a run of neighbours at a time. Homes (brick, and half the slabs) keep the Street's evening hours, with 45% of rooms on that schedule instead of 65%, in warm light of varying brightness. Offices (the rest) light `officeShare` of their runs: half at dusk, falling to 8% by midnight and rising again from 05:30, in cool white on most glass and slab buildings and warm on stone. Each run's draw is fixed by the building's seed, so as the share falls the same runs go dark in the same order. Taller roofs carry red corner lights.
- **Where the Sun and Moon land** (`place`, for every city but the Street): azimuth spans about 260° across the screen (200° on the Street), so sunrise and sunset stay on screen all year at mid latitudes. Elevation runs as the 0.75 power of elevation / 70°, which gives a low Sun more room, and a body below the horizon drops out of sight within about half a degree. The horizon it sets behind is `crest` at that column, which it clears by 15° up.
- **Sky:** the same gradient, with only 40% of each band dithered into the next (`band`), the city's own mauve glow at night, strongest low over downtown, and stars that fade out toward the horizon.
- **Water** (`addWater`, `waterShader`): one sprite with a shader that reads the sky and city textures. Each water row shows the quay wall, then the city from street level up, squashed 1.8 times (the street lies flat and out of sight). Rows slide sideways by whole pixels on two sine waves, wider toward the viewer, the image fades toward a deep-water colour, and short dashes of sky colour drift on every other row. It animates by `u_now`.

### The Foothills city
The first of the cities Dave picked from the research below. Everything the Waterfront has (the light, the sky, windows in dashes) applies; what's new is the land.

- **Composition,** bottom to top: a dark bank of pines (under the Dock), a valley floor of fields with a highway across it, the city band on `ground` (27% up), then three ridges and the sky.
- **Mountains** (`layOutFoothills`, `drawMountains`, seed 2041): each ridge is five octaves of noise between random knots, the first two folded (`1 − |2v − 1|`) so the peaks come to points. Far to near they are rock with snow above a wavering line, lower rock with a few snow tips, and forested foothills, each hazier than the one in front.
  - **Faces:** a pixel's face slopes right, left or toward us by the difference in the ridge's height either side of it, over a span that widens downhill (2 pixels at the crest to 16), so light and shadow run down from the peaks in streaks instead of the mountain being one flat tone. One side is always the brighter, the one the Sun is on.
  - **The Sun counts as higher the higher up a face is** (up to 5° at the top), so the peaks glow after the valley is in shade and light first at dawn.
- **`crest`** follows the highest ridge, so the Sun and Moon rise and set behind the mountains themselves. Real mountains seen from a city stand only a few degrees high; these fill a third of the screen, so the true horizon would hide the Sun for hours.
- **The city band:** the Waterfront's far-row buildings (stone, glass, slab, with windowless towers behind) at a third of their usual haze (`farHaze`), a downtown 36% across (`downtown`) and low buildings with open ground elsewhere. The landmark is the tallest, with a mast and the beacon.
- **The valley floor** (`drawPlain`, seed 77): six bands of grass paling toward the city, strips of field, 70 houses and trees thickening toward town (a house lights one window at night on the homes' hours), and a pine bank along the bottom, each tree lit on the Sun's side.
- **The highway:** the same traffic as the other cities at a distance. `speck` draws a car as a dash of paint by day and only its tail light and headlight by night; they run at 0.35 of the usual speed (`carPace`) from a pool of 14 a lane.

## Time, live data and appearance
- **Time:** `now`: the real time, or today at the preview hour while Settings is previewing one. The hour for windows and traffic is the local clock hour.
- **Sun:** `skyPosition()` at `Location.shared` (low precision, about 1°). `night = smoothstep(4°, −8°, sun elevation)`.
- **Placement:** sky positions go onto the canvas looking along `heading()` (`place()`): toward the equator, or the compass point picked in Settings.
- **No network.** `Location.shared.start()` is called in `didMove`.
- **Appearance:** it ignores Light/Dark Mode. The real Sun already sets the look.

## Settings
`PixelCity.knobs`, read with `knob(_:)`. A change repaints at once (`settingsChanged`), and a change of city lays the scene out again first.
- **City** (`city.view`): Street, Waterfront or Foothills, as the index into `City`. Waterfront is the default.
- **Looking** (`city.looking`): Toward the midday Sun (the default: toward the equator, which keeps the Sun and Moon in the sky and the city backlit) or one of eight compass points. Dave asked for it on 2026-10-04 after reading that the Waterfront's fronts stay in cool shade at sunset: "lets add support for the sun direction perhaps". The Waterfront's flanks were laid out for the default, so looking east or west the Sun rises or sets behind downtown.
- **Preview a time of day** (`city.previewTime`, `city.previewHour`): shows today at that hour instead of now, the only way to see a sunset at noon. Off by default.

## Tuning constants
- **Canvas:** 240 art pixels per screen height; the street is 26 rows tall; lamps every 46 px.
- **Waterfront:** water `0.21 × h` rows, quay 6 rows; `downtown` runs from 1 at 12% off centre to 0 at 30%; the landmark is 0.66 of the sky above the street; the reflection is squashed 1.8 times.
- **Foothills:** ground `0.27 × h`; ridges (base, relief, as shares of the sky above the ground) 0.36 + 0.22, 0.22 + 0.17, 0.07 + 0.12; snow line 0.47; haze 0.36, 0.28, 0.14; highway 14–17 rows below the ground.
- **Timing:** redraw every 30 s.
- **Window schedule** (`isLit`): home 16.5 h + 4.5·rand; bed 21 h + 6·rand; early risers 5.5 h + 1.5·rand. `officeShare`: 0.5 until 18:00, down to 0.08 by midnight, 0.08 to 0.45 between 05:30 and 08:00.
- **Traffic:** the `traffic` table has 24 hourly multipliers.
- **Vehicles:** the car pool has 6 per lane; cars reach at most 22 px/s.
- **Planes:** 40–120 s apart, 7 px/s.

## Performance
- About 0.45 ms CPU and 0.15 ms GPU per frame for either city (release build, 2x, 1512×982, measured 2026-10-04: 0.42–0.50 and 0.12–0.18 across both cities by day and night).
- The 30 s repaint costs about 3 ms once, for either city. It loops over every art pixel in Swift for the sky, draws the city over a second buffer, and builds two `CGImage`s.
- Per-frame work is a few dozen sprites and, on the waterfront, one small shader over the water. Lots of headroom.

## Gotchas and shortcuts
- **Its own maths.** `skyPosition()` and the Moon phase duplicate what `SkyMath` does better (`Sky.sun`, `Sky.moon`, `Sky.moonPhase`). The Moon can be about 5° off, since it has no lunar inclination, and its lit side isn't mirrored for the southern hemisphere.
- **Clock versus Sun.** The hour for windows and traffic is the local clock, while the Sun uses location, so a viewer far from their time zone's centre gets slightly mismatched light and windows.
- **`dt` is clamped** to 0–0.1 s in `update`, because the render harness once fed wildly negative steps.
- **Snapshots** use the fallback location: 40°N at the time zone's standard meridian, so the Sun can be minutes to about half an hour off from the viewer's real one.
- **Keep it crisp:** motion must stay rounded to whole art pixels, and new textures must use `.nearest`. The water's shader floors to art pixels itself.
- **Seeded draws must not depend on the hour.** `drawTower` makes the same random draws in the same order on every repaint and only compares them with the hour, or the lights would reshuffle every 30 s.
- **The water mirrors the two backdrop textures only** (`ponytail:` in the source), so cars and clouds have no reflection.
- **The Sun often sets behind a building.** The flanks are low and half open, not empty, so on some days the last few degrees are hidden and only the glow shows. That's the real azimuth doing it.
- **Lights come on in a batch** every 30 s rather than one at a time.

## Dave's feedback and decisions
- It was built in the first batch of scenes ("build out all of those ideas") and not touched again until October.
- He wants every live scene to follow his real location and time. This one does, through the Sun's position, not just the clock.
- **2026-10-04, design review.** He asked for "a deep dive design review… to push it to the next level of fidelity". The review rendered eleven times of day and found: the Sun dropped behind the Street's solid far row 1.5 to 3.5 hours before sunset and was never seen low; light had no direction; every building was the same box; at 21:00 about 68% of windows were lit, all alike; the traffic sat under the Dock and the top 40% was empty sky; and nothing moved between repaints but cars, clouds, the beacon and a plane. Shown a ranked list, he said "proceed based on your own recommendation", which was: light from the real Sun, a waterfront composition and a kit of building kinds, as a second choice in Settings to compare with the Street. That's the Waterfront. The smaller faults were fixed for both cities first (headlights, the Sun's halo, the Moon's size, stars through clouds).
- **Every city stays.** While it was being built he asked for "other 'pixel city' backdrops entirely… 1 or 2 more 'cities' that can be toggled in the settings, maybe like a sweeping city landscape", so the Street isn't removed as the loser of a comparison: City is a menu to add to. He hasn't yet said what he thinks of the Waterfront.
- **More cities, 2026-10-04.** A research agent ranked eight backdrops by how good each would look against how hard it is to draw in code: Foothills, Overlook (down over rooftops to a far skyline), Long Bridge (a suspension bridge across a bay), Hillside Town (houses up a slope above a harbour), Park (trees that follow the season), Old Town (a clock tower showing the real time), Desert City and Elevated Railway. It advised against a neon alley (flashy, hides the sky, hardest to generate), a canal city (the Waterfront again) and a snowy town (better as live-weather snow everywhere), and found no openly licensed art good enough or the right size to ship, so each is drawn in code. Shown the top four, Dave picked all of them: Foothills, Overlook, Long Bridge and Hillside Town. Overlook carries a risk the agent flagged: its middle distance of roofs may turn to noise at this size.

## Ideas / next steps
From the 2026-10-04 review, not yet done:
- **Cities still to build** of the four Dave picked: Long Bridge, Hillside Town, Overlook. Foothills could take weather well: a snow line that follows real snowfall, a cloud deck over the peaks, fog in the valley.
- **Life:** windows switching one at a time, rooftop steam, slow star twinkle, birds at dawn, a traffic light with cars queueing, a lit train or ferry every few minutes, reflections of the cars' lights in the water.
- **More vehicles** (taxi, van, truck, bike) with ground shadows.
- **Clouds:** layered, of varied size, lit from the Sun's side, their number from the real cloud cover.
- **Weather** from `LiveWeather.shared`, which costs no extra calls: rain with a wet road, snow settling on roofs, fog eating the far rows, wind steering clouds and steam.
- **The real night sky:** bright stars from Live Sky's catalogue, so Orion really rises over the skyline; the Moon from `SkyMath` (and delete `skyPosition`); the ISS.
- **A clock-and-temperature sign** on the landmark showing the real time and Open-Meteo temperature.
- **The calendar:** street trees that follow the date, string lights in December.
- **Colour:** authored ramps per time of day, snapped to about 40 colours, to end the muddy transitions.
- **Finer pixels** as a setting (3 pt instead of 4 pt), one panorama continuing across displays, a new skyline now and then.
- **A bridge** on the waterfront's left flank, for the Sun to rise behind.
- **More settings:** traffic, planes, follow the weather, a neon or cyberpunk night.

## Checking it
- `SNAPSHOT_SCENE="Pixel City" swift test` renders the current time at the fallback location, as the Waterfront.
- **Particular times and cities:** `SNAPSHOT_DEFAULTS="city.previewTime=1,city.previewHour=19.2,city.view=0" SNAPSHOT_SCENE="Pixel City" swift test` renders today at that hour (`city.view=0` is the Street, 1 the Waterfront, 2 Foothills). On 2026-10-04 the Waterfront was checked at 7:18, 12:48, 17:12, 18:18, 18:27, 19:00, 21:00 and 21:30, and the Street at 12:48 and 19:24. `city.looking` is the menu's index: 0 toward the midday Sun, then 1 north round to 8 north-west; sunset was checked looking east (3), west (7) and north (1).
- **Traffic, planes and the water:** use `SNAPSHOT_SECONDS=30` or more; `SNAPSHOT_MOVIE=3` saves frames to compare for the ripples.
- **Foothills** was checked on 2026-10-04 at 7:18, 10:30, 12:48, 17:48, 18:30 and 21:30.
- **Screenshots:** `pixel-city-dusk.jpg` is the Waterfront at 19:00 on 4 October and `pixel-city-night.jpg` the Street at 23:30, both at the fallback location from a release build. `preview-pixel-city.jpg` is a 1200-pixel copy of the first.
