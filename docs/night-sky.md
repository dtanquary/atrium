# Night Sky

The real sky above the viewer right now, looking toward the equator: about 2,900 stars over a photograph of the whole sky (the Milky Way and its dust, the Magellanic Clouds, Andromeda, the Orion Nebula and the rest, each where it really is), constellation lines, the five naked-eye planets, the Moon in its true phase and tilt, the ISS when it's overhead and sunlit, and an occasional meteor. The sky fills the screen down to the horizon unless Settings puts a landscape under it. It's the sky with the daylight switched off: as dark at noon as at midnight, with the Sun drawn among the stars it hides, and a warm band low toward it around sunrise and sunset.

- **Files:**
  - `Sources/Atrium/NightSky.swift`: the scene.
  - `Sources/Atrium/SkyMath.swift`: `enum Sky`, the positional astronomy. Shared with Earth from Orbit, Weather and Flowing Gradient.
  - `Sources/Atrium/Location.swift`: `Location.shared`, the viewer's position. Shared with every live scene.
  - `Sources/Atrium/ISS.swift`: see [earth-from-orbit.md](earth-from-orbit.md).
  - `Sources/Atrium/Resources/stars.txt` and `constellations.txt`.
  - `Sources/Atrium/Resources/sky-*.txt`: the real skylines, made by `docs/night-sky/horizon.py`.
  - `Sources/Atrium/Resources/sky-milky-way.heic`: the photograph of the whole sky, made by `docs/night-sky/sky.py`.
  - `Tests/AtriumTests/SkyTests.swift`.
- **Entry:** `nightSky(size:)` builds `final class NightSky: SKScene`. Its entry in Scenes.swift is "Night Sky", icon `moon.stars.fill`, tint `.blue`, `knobs: NightSky.knobs`.
- **Kind:** hybrid. The background and the Moon are SKShaders; stars, planets, the Sun, the ISS, labels and meteors are sprites; the landscape, when one is switched on, is a Core Graphics texture.

## How it works
- **Projection.** A stereographic projection centred on the horizon point the view faces: south, or north when latitude < 0 (`facingSouth`). Great circles through the centre stay straight, so the horizon is a straight line. `scale` gives about a 120° horizontal field of view; `horizonY` sits on the screen's bottom edge, so the sky fills the screen and nothing in it is below the horizon, or 12% up (`landHorizon`) while a landscape shows. `project()` returns nil for points behind the viewer (`1 + forward <= 0.2`). `place()` hides a node that's below the horizon (z < −0.01) or more than 30 pt off-screen.
- **Frames.** Equatorial directions are J2000 unit vectors. `Sky.horizonMatrix(jd:latitude:longitude:)` turns them into (east, north, up). `refresh()` recomputes every position every 5 s, and on any settings change.
- **Background shader** (`addSkyBackground`): each pixel is un-projected back onto the sphere, as (right, up, forward).
  - A night gradient, a little lighter toward the horizon.
  - **The photograph of the whole sky** (`u_photo`, since 2026-11-14): ESO/S. Brunier's panorama, a plate carrée in galactic coordinates with the galactic centre in the middle, 4096 × 2048 (11 pixels a degree, where a 1512-point display at 2x shows 23 to 30). Each pixel's direction goes screen → horizon → equatorial → the photo's frame through `u_toPhoto`, built in `refresh()`, and is looked up by its longitude and latitude there. It replaced a drawn Milky Way (a disc, a bulge, three octaves of 3D noise and one dust lane).
    - **Lining it up** (`NightSky.toPhoto`): the photo sits 3.8° off true galactic coordinates, enough to put Sirius two and a half degrees from its own picture. The turn that fixes it was fitted to the catalogue: the 700 brightest stars were looked for in the photo, 516 found, and the best rotation leaves them 0.14° out at the median and 0.34° at worst (a point and a half, and four, on a 1512-point display), evenly over the sky. So each star sprite sits on its own star in the photo, and the photo's halo round a bright star reads as that star's glow. Black Hole met the same misfit in this panorama and took its stars out altogether (`docs/black-hole.md`); the same turn would line its glow up with its HYG stars.
    - **Its own stars are turned down to 30%** (`sky.py`). Stretched over a screen the photo's faint stars are soft dots of much the same brightness, tens of thousands of them, and at full strength they drowned the catalogue's stars and the constellation lines: Orion couldn't be picked out. A 9-pixel median takes the stars out and keeps what's spread out; 30% of what it took goes back, as a faint dusting that's denser toward the Milky Way.
    - **Venus and Jupiter are painted out.** They stood in Aquarius and Sagittarius on the nights it was shot (2008–09) and would be two bright stars that aren't there. They were found as the only bright spots in the photo with no catalogue star and no deep-sky object under them; the rest of that list was Omega Centauri, Andromeda, the Magellanic Clouds, and the Beehive, M41, NGC 2516 and Coma clusters. Each is covered with the sky beside it at the same galactic latitude.
    - **In the shader:** the photo less 0.05 (its own sky glow) goes through a film's shoulder, `1 − exp(−1.5·x)`, so the galactic centre doesn't burn out and the faint winter arm still shows, and fades to 45% in the lowest 17° above the horizon, as the real sky does through more air.
  - A twilight band of warm light sits low in the sky, strongest toward the Sun's azimuth (`u_twilight`, `u_sun` in the same right/up/forward frame).
  - ±½/255 dither against banding.
- **Stars:** `stars.txt` holds 2,887 stars to magnitude 5.5, as `RA Dec V B−V` in degrees, J2000.
  - Size is `max(2.2, 11 − 1.55·V)` points, colour comes from B−V (`starColour`), and alpha from V.
  - Stars brighter than V 2 twinkle with fade actions.
- **Constellations:** one `SKShapeNode` path, rebuilt each refresh from `constellations.txt` polylines. A segment breaks where it dips below the horizon. SpriteKit strokes a shape node's whole path again every frame, path unchanged or not, so the path holds only the unbroken runs with a segment on screen, each run whole (cutting off just its off-screen segments moved pixels along the rest), and nothing while the lines are switched off.
- **Planets:** `Sky.planet(_:_:)` gives Mercury to Saturn. Each is a glow sprite with a fixed size and colour and an "ISS"-style label as its child.
- **Sun:** a 48 pt disc and a 360 pt glow, blended toward orange below 12° altitude. It's hidden below the horizon or out of view, and otherwise sits among the stars: in mid-November, in Libra.
- **Moon:** a 46 pt disc (exaggerated; the real Moon is about 5 pt at this scale) drawn by a shader.
  - The shader treats the disc as a sphere lit from `u_light`, wearing NASA's map of the near side (`weather-moon.png`, Weather's, from LRO; since 2026-11-14, in place of 11 hand-placed blobs for the seas).
  - Its shading is `moonShade` (Shaders.swift, shared with Weather): McEwen's lunar-Lambert, as in The Moon, so the light fades toward the terminator instead of stopping at an edge. It's shown as its square root (light to display), over an opaque disc with a little blue earthshine on the dark side, faint enough that the seas only just show in it.
  - The disc is rotated so its north points to the celestial pole on screen (`screenAngle` toward `poleH`).
  - The light direction is measured from the Moon's north using `skyAngle`, which works in the local frame of someone facing the Moon with their head upright. That keeps it correct however the disc is turned.
  - The phase angle comes from `Sky.moonPhase(jd).lit` (`acos(2·lit − 1)`).
  - Glow alpha = 0.5 · lit.
- **Names in the photo** (`sights`, since 2026-11-14): fourteen things worth pointing out get a faint name beside them, under the Labels switch: the Orion, Rosette, Lagoon, Carina and North America nebulae, the Pleiades, the Beehive and Double clusters, Omega Centauri, the Andromeda Galaxy, the Magellanic Clouds, the Coalsack and the center of the Milky Way. From 40°N on a November night that's four at a time. A name sits to the right of what it names, or to the left where the screen's edge is near (`place`), which planets and radiants get too.
- **ISS:** in `update(_:)`, using `ISS.shared.position()` → `Sky.lookDirection` → `place()`. It's shown only while sunlit (the real naked-eye condition), with a label as a child.
- **Meteors:** a painted 140×2 pt streak, fading over 0.7 s, every 15–75 s on a night with no shower (`awaitMeteor`).
  - **The real showers** (since 2026-11-14): `NightSky.showers` lists eleven, from the International Meteor Organization's Working List (its 2026 calendar, table 5): Quadrantids, Lyrids, Eta and Delta Aquariids, Perseids, Orionids, Southern and Northern Taurids, Leonids, Geminids and Ursids, each with the Sun's ecliptic longitude at its peak, its days of activity either side, its radiant and its peak rate. `hourly` gives a shower's rate now: its peak rate at the peak, falling in a straight line of the logarithm to one an hour at each end of its activity.
  - **How many:** a dark sky away from any shower really gives about 8 an hour, shown here as 80. Each shower adds its rate times the sine of its radiant's height, so none while the radiant is down. The wait between meteors is 45 s ÷ ((8 + showers) ÷ 8)^0.7: on Leonid night about 25 s, at the Geminids' peak with Gemini high about 5 s (in life the Geminids would be one every 2 s at this scale, which is a screen of streaks).
  - **Which way:** each meteor belongs to a shower as often as that shower's share of the real rate, and then runs straight away from the radiant along a great circle, 11° to 23° of sky when a quarter of the way round from it and shorter nearer (one beside its radiant is coming almost at you). The rest fall any way down, as all did before.
  - **Radiants:** a 3 pt ring with the shower's name, at the radiant, while the shower gives two an hour or more and the radiant is in view; under the Labels switch.
- **Landscape:** off unless Settings turns it on. `Landscape` (end of NightSky.swift) lists the silhouettes, and `paintGround` paints the one picked into the `ground` node, the first time it's shown and again when the pick changes.
  - **Pine ridge** is drawn: a hill ridge with stands of conifers, rolled afresh each time.
  - **The rest are real skylines**: Monument Valley, the Teton Range, Shiprock, Devils Tower and Mount Fuji. Each is a `sky-<case>.txt` of about 120 to 540 points, degrees right of the view's centre and degrees above the horizon, as seen from the spot its header names. The points go through the same stereographic projection as the stars, so the skyline stands as wide and as tall as it would among them, on any display. Only Shiprock and Fuji are really seen looking south; the others face east, west and north-west.
  - Faint compass letters (SE, S, SW, or NW, N, NE) sit on the ground, or just above the bottom edge without one.

## Time, live data and appearance
- **Time:** `skyDate` is `Date()`, or today at `sky.previewHour` while `sky.previewTime` is on.
- **Daylight:** there is none. Nothing fades with the Sun's height; the one thing that follows it is the twilight glow, `smoothstep(−16, −4) · (1 − smoothstep(4, 14))` of its altitude in degrees.
- **Location:** `Location.shared`, from CoreLocation. It asks for When In Use permission on the first `start()`, from `didMove`. The last fix is saved in UserDefaults (`latitude`, `longitude`). Before the first fix, it falls back to 40°N and a longitude guessed from the standard time-zone offset (DST removed). It's read on every refresh.
- **Network:** only the ISS. Polling starts in `didMove`, once a minute. See [earth-from-orbit.md](earth-from-orbit.md).
- **Appearance:** one look. It ignores Light/Dark Mode, because the sky is dark.

## Astronomy (SkyMath.swift)
- **Planets:** JPL "Approximate Positions of the Planets", table 1 Keplerian elements (1800–2050), with Kepler's equation solved by Newton's method in 5 iterations. Earth's elements give the Sun.
- **Moon:** the main terms of ELP-2000/82 (Meeus, "Astronomical Algorithms", ch. 47: 60 longitude and distance terms, 30 latitude), about 10″, stepped from the equinox of date back to J2000 by −1.397°·T. It replaced the Astronomical Almanac's low-precision series (about 0.3°) on 2026-09-26, for Dappled Light's eclipses, which that series put 10–30 minutes off. `moon(_:latitude:longitude:)` adds the parallax from where the viewer stands (up to 1°) and gives the distance. `moonPhase` gives lit = (1 − m·s)/2, and waxing = the Moon is east of the Sun along the ecliptic.
- **Other helpers:**
  - `siderealTime` is GMST in degrees.
  - `lookDirection` gives the direction from a ground observer to a point at altitude. It uses a spherical Earth, R = 6371 km.
  - `galactic` is the J2000 → galactic rotation matrix.
- **Accuracy:** SkyTests match JPL Horizons within 1° at 2026-01-01 for the Sun, Moon and planets, and the Moon's lit fraction within 0.02 on two dates.

## Data and licences
- `stars.txt`: Yale Bright Star Catalogue, 5th ed. (CDS V/50), public domain. Credit is in the file header.
- `constellations.txt`: d3-celestial (Olaf Frohn), BSD 3-Clause. The full licence notice is kept in the header and must stay there.
- `sky-milky-way.heic`: ESO/S. Brunier, "The Milky Way panorama" (eso0932a), CC BY 4.0, credited in About with what was changed (its stars dimmed, two planets removed, resized). `docs/night-sky/sky.py` makes it from ESO's 6000 × 3000 JPEG; 0.9 MB.
- The showers' dates, radiants and rates: the International Meteor Organization's 2026 Meteor Shower Calendar, table 5 (facts, credited in the README and beside the list in NightSky.swift).
- `sky-*.txt`: horizon angles worked out from elevation data by `docs/night-sky/horizon.py`. The US sites use the USGS 3D Elevation Program (public domain; USGS asks for credit, which About gives), down to 1 m lidar over the buttes and the tower. Fuji uses NASA's SRTMGL1 v3 (30 m, CC0), fetched from ESA's STEP mirror. Each file's header names the viewpoint and the source.

## Settings
| key | label | range | default | drives |
|---|---|---|---|---|
| `sky.constellations` | Constellation lines | toggle | on | `constellations.isHidden` |
| `sky.planetLabels` | Labels | toggle | on | the planets' names, the names of things in the photo, and the meteor showers' radiants (it was Planet labels until 2026-11-14; the key kept its name) |
| `sky.landscape` | Show a landscape | toggle | off | `ground.isHidden`, and `horizonY` (12% up, or the bottom edge) through `u_horizon` |
| `sky.ground` | Landscape (shown while the switch is on) | menu | Pine ridge | which `Landscape` is painted, stored as its place in the list |
| `sky.previewTime` | Preview a time of day | toggle | off | `skyDate` uses the preview hour |
| `sky.previewHour` | Time (shown while previewing) | 0–24 h | 13:00 | the hour for `skyDate` |

`applySettings()` observes `UserDefaults.didChangeNotification` and calls `refresh()` every time, including for unrelated defaults writes. Each call places about 2,900 sprites, which is cheap but not free.

## Tuning constants
- **View:** a 120° field of view (`scale`), horizon at 12% (`landHorizon`).
- **Timing:** refresh every 5 s; meteors every 45 ± 30 s away from a shower.
- **Stars:**
  - size `11 − 1.55·V`, minimum 2.2 pt
  - alpha `1.2 − 0.14·V`, clamped between 0.35 and 1
  - bright stars twinkle to 60% over 0.15–0.5 s
- **Sprite sizes:** Moon 46 pt, Moon glow 220 pt, Sun 48 pt, Sun glow 360 pt.

## Performance
- About 0.55 ms CPU and 0.19 ms GPU per frame (debug build, 2x, 1512×982, measured 2026-11-14). With the drawn Milky Way it was 0.71 ms of GPU the same day: its 3D noise on every pixel was most of the frame, and the photo is one lookup.
- The photo is 34 MB as a texture, shared by every copy (`sharedTexture`) and let go with the last.
- The CPU cost is mostly SpriteKit handling about 2,900 star sprites, which batch because they share one texture. `refresh()` only runs every 5 s.
- Re-stroking the constellations was about 45% of the CPU frame (`sample` of the render test) until 2026-10-14, when the path dropped the runs that are wholly off screen: 162 segments of 325 on a night in October, and the render's CPU went from about 0.3 to 0.14 ms a frame, pixel for pixel the same.
- Well within the 2 ms budget.

- **On battery it runs at 15 fps at most, and at the battery's rate while a meteor crosses** (`batteryRate`, dropped as `meteor()` lights one and back once it has gone, 0.7 s later; 2026-10-13). The ISS is the fastest steady thing, up to about 36 device pixels (2x on a 14-inch MacBook Pro, 3024 × 1964) a second: 2.4 px a frame at 15 fps. Stars twinkle at 1.3 Hz at most and positions move every 5 s. A meteor crosses 180–360 points in 0.7 s, up to 1,030 px a second, every 15–75 s.
- **It no longer draws its sky at half resolution on battery** (`batteryScale`, 2026-10-14 to 2026-11-14). That saved 62% of the drawn Milky Way's GPU time and couldn't be told from full resolution. The photo costs a quarter as much to begin with, and its fine stars would soften.

## Gotchas and shortcuts
- `ponytail:` **precession.** It's ignored since J2000, about 0.35° by 2026. It shifts the whole sky together, so nothing looks wrong relative to itself.
- `ponytail:` **no topocentric parallax for the Moon.** It can sit up to about 1° off its true place against the stars. `Sky.moon(_:latitude:longitude:)` has it now, if Night Sky wants it.
- `ponytail:` **fixed planet sizes.** Real brightness swings (Mars from about magnitude −2.9 to +1.8).
- `ponytail:` **fallback location.** The time-zone guess can be about 15° off in latitude until CoreLocation answers.
- **Twinkle actions.** They set absolute alphas, so anything that fades the bright stars has to go through a parent node, not the star sprites themselves.
- **Moon light and turned discs.** The Moon's light vector must be measured from the Moon's north, not from screen up, or it breaks when the disc is rotated.
- **Render tests** never call `didMove`, so the snapshot has no ISS and no location request.

## Dave's feedback and decisions
- **Name.** He asked for Night Sky based on his real location; it became Live Sky once it followed the day, and Night Sky again on 2026-11-14 (below). The code, file, type, pictures and this doc were renamed each time, and a saved "Live Sky" (the wallpaper on the desktop, Settings' page, Shuffle's skipped list) is moved in main.swift.
- **Daytime behaviour.** At first he chose to stay a night sky but react to the Sun: deep blue by day with only the brightest objects showing. On 2026-11-14 he asked whether Live Sky and Weather should be merged: "I feel like the live sky one is a bit redundant". They overlapped only by day, where Weather's physical sky does the same job far better, and a merge would have cost the star chart its 120° view, its lines and labels, and its sky on a cloudy night. He took the other way out, "move live sky back to night sky": always dark, the Sun drawn among the stars, so Weather is what's out the window and Night Sky is what's behind the daylight and the clouds. The warm band at sunrise and sunset stayed, as the one sign of the hour. The tag `night-sky-always-dark` is the first always-dark version, before any of this.
- **Moon.** "Show the moon phase as it would from my location" meant that the Moon itself should be accurate. A bottom-left phase badge was added, then removed at his request as redundant. Don't bring back a HUD for this.
- **Moon's terminator (2026-10-03).** In Weather he saw the half Moon end in a hard edge by day, where the real one fades into the sky, and asked for this one to be checked too. Both now share `moonShade`.
- **Switches.** He asked for the constellation and planet-label switches.
- **Landscape (2026-10-05).** He asked for a switch to turn the landscape off, and for more silhouettes to choose between. Off means no ground at all, not a flat one: the horizon drops to the bottom edge. Once he had the switch he asked for off to be the default ("i think we should default to no landscape", "it looks nice without a landscape there imo"), so the landscapes are an extra for those who want one.
- **Preview.** Added so he could see the daytime look on demand; now it shows the sky of any hour today.
- **Making it look really cool (2026-11-14).** With the move back to Night Sky he asked to "see if there is anything else we can do to enhance that experience, comets, nebula, whatever you can think of that would make it look really cool". The nebulae came as real ones: the photograph of the whole sky was already in the app for Space Tour (though that copy fades to black at its edges, which would cut a dark seam through Taurus, so this one is made from ESO's original). With it came names for what's in it, the Moon's real face, and meteors from the real showers.
- **Comets were looked at and left out (2026-11-14).** Real ones are there for the asking: NASA JPL's Small-Body Database answers `https://ssd-api.jpl.nasa.gov/sbdb_query.api?fields=full_name,e,q,i,om,w,tp,M1,K1&sb-kind=c&sb-cdata={"AND":["q|LT|4","tp|RG|<a year back>|<a year on>"]}` with about fifty comets' orbits and brightness in 5 KB, and Kepler's equation does the rest. But worked through for tonight, the brightest was C/2024 T5 (ATLAS) at magnitude 13, a thousand times fainter than the faintest star drawn here, and over the year only C/2025 R3 (PANSTARRS) came near the naked eye, about magnitude 8 for a few weeks in April. A real comet would be on screen a few weeks a year, and a made-up one goes against real over made up. Dave to say which he'd rather have.

## Landscapes: what was looked at (2026-10-05)
A research agent compared drawn recipes, real skylines and traced photos, each as a strip against night, twilight and day skies.
- **Real skylines won.** They cost a few KB of text, scale to any width and look real. The method is in `docs/night-sky/horizon.py`: walk outward from the viewpoint along each bearing and keep the highest angle the ground reaches.
  - The National Map's `exportImage` keeps pixels square in degrees: ask for a square image of a box that isn't square in degrees and it quietly widens the box in latitude, which gives a plausible but wrong skyline. The script asks for 2000 × 2000·cos(latitude). It also fails above about 2000 pixels a side, so the script fetches nested squares.
  - To add one: a line in the script's `SITES`, run it, add a case to `Landscape` whose name matches the file, and look at it in a snapshot.
- **Skylines computed and turned down:** the Sierra crest from the Alabama Hills, and Monte Rosa to the Matterhorn from above Zermatt or Gornergrat (walls 10° to 12° high that hide the low sky, with no one shape); Torres del Paine (16°, and SRTM puts a false needle in it); Kilimanjaro from Amboseli (a low dome); Table Mountain across Table Bay (needs its angles stretched 1.5× to read); Monument Valley from US-163 (weaker than the visitor centre's view). Yosemite's walls stand 12° and more from any classic viewpoint.
- **Drawn recipes mostly read as clip art:** saguaros, acacias and bare trees from rules look stamped. Observatory domes and a line of radio dishes (after the VLA) were the two that held up. A city skyline is dead without lit windows and argues with a dark sky; still wind turbines look broken.
- **Traced photos are the next step if more are wanted.** A backlit photo needs only a brightness threshold, and a traced plant looks real where a drawn one doesn't. One photo can't span the screen, so the plan is a low drawn ground with four to six cut-outs scattered on it at varied sizes, some mirrored. Candidates, all on Wikimedia Commons:
  - Joshua trees: "Comet NEOWISE over Queen Valley" and "Milky Way, Jupiter, and night sky over Queen Valley", NPS / Emily Hassell, public domain, 8256 × 5504.
  - Saguaros: "Sunset (2)", Saguaro National Park, tagged both CC BY 2.0 and public domain, so credit it as CC BY 2.0.
  - Stonehenge: "Stonehenge sunset" by Bkamprath, public domain (crop out the people at its right).
  - Mauna Kea's domes: "Mauna Kea Sunset" by Joe Parks, CC BY 2.0, about 100 pixels a dome.
  - Already in the app: the Fireflies meadow's treeline (CC BY 2.0, credited) would make a leafy alternative to the pines.
- **Other software:** Stellarium's polygonal landscapes are the same idea, a text list of horizon angles. Its own landscapes state no licence in a GPL repository, so none were taken.

## Ideas / next steps
- Real planet magnitudes, from distance and phase.
- Topocentric Moon parallax.
- Each shower's own activity curve and its radiant's drift (see the `ponytail:` on `hourly`), and their speeds: Leonids at 71 km/s are quick, Taurids at 27 slow and often bright.
- Real comets, when one is bright enough (see the decisions above for the feed and what it would show).
- Names for the brightest stars, and for the constellations beside their lines.
- Satellite flares and more satellites.
- Stars that dim near the horizon (extinction).
- Twinkling tied to how high a star sits.
- Settings for field of view, direction faced, or the Milky Way on or off.
- More landscapes: see the candidates below.
- The viewer's own horizon, from the same elevation data around where they are.

## Checking it
- `SNAPSHOT_SCENE="Night Sky" swift test` renders the current moment at the fallback location, because the test process has its own defaults domain.
- **Its pictures** (the README's, Settings' still and the menu's tile) were rendered on 2026-11-14, and a preview hour means that hour on the day of the render: 17.45 is dusk with the Milky Way's center setting only in November. Rendered in another month, pick the hour again (in June the same sky is up around 1 am).
- To render a set time: `SNAPSHOT_DEFAULTS="sky.previewTime=1,sky.previewHour=18.8" SNAPSHOT_SCENE="Night Sky" swift test`. Try 13 for the Sun among the stars, about 16.9 for a November sunset's glow at the test's fallback longitude of −90°, and 23 for night. To hide things, add `sky.constellations=0,sky.planetLabels=0,sky.landscape=0`.
- A landscape: add `sky.landscape=1,sky.ground=1` (the number is its place in `Landscape`, 0 for the pines).
- `swift test --filter SkyTests`:
  - positions matched against Horizons
  - the Moon's lit fraction and waxing/waning
  - four real total and annular eclipses line up, seen from their paths (`eclipsesLineUp`)
  - Polaris' altitude equals the latitude
  - an ISS directly overhead points straight up
  - every real skyline's file is there and spans the view (`skylinesSpanTheView`)
  - the photo's bright stars are where the catalogue's are (`skyPhotoLinesUpWithTheStars`)
  - the Perseids, Geminids and Quadrantids are each the strongest shower on their night, and March has none (`showersPeakOnTheirNights`)
- To see where meteors go, set `awaitMeteor`'s 45 to 0.2 for a moment, render `SNAPSHOT_MOVIE=8` and lay the frames over each other, keeping the lighter pixel: the streaks should point back at the ringed radiants.
