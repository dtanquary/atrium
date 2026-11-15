# Earth from Orbit

The whole Earth seen from high above the viewer's own location, like a geostationary satellite parked overhead, set against the real stars behind it. It shows the real line between day and night, today's real clouds, lightning in the storms around the viewer, city lights on the night side, sun glint on the oceans, a lit edge of atmosphere, and the ISS at its live position with its orbit ring.

- **Files:**
  - `Sources/Atrium/EarthFromOrbit.swift`: the scene.
  - `Sources/Atrium/ISS.swift`: `ISS.shared`, the live position, shared with [Night Sky](night-sky.md).
  - `Sources/Atrium/Clouds.swift`: `Clouds.shared`, the live global cloud map.
  - `Sources/Atrium/Storms.swift`: `Storms.shared`, where thunderstorms are around the viewer.
  - `Sources/Atrium/Resources/earth-day.heic` (804 KB) and `earth-night.heic` (490 KB), both 4096×2048 (see Data and licences).
  - Astronomy comes from `SkyMath.swift` and location from `Location.swift`; see [night-sky.md](night-sky.md).
- **Entry:** `earthFromOrbit(size:)` builds `final class EarthFromOrbit: SKScene`. Its entry in Scenes.swift is "Earth from Orbit", icon `globe.americas.fill`, tint `.cyan`, `knobs: EarthFromOrbit.knobs`.
- **Kind:** hybrid. The globe is one sprite with an SKShader sampling two textures; the stars, ISS marker, label and orbit ring are nodes.

## How it works
- **View frame.** `basis` has three Earth-fixed axes: east, north, and the up vector at the viewer's latitude and longitude. The globe is always seen from straight above the viewer. `refresh()` rebuilds it every 5 s from `Location.shared`. The globe sits at (0.58 w, 0.48 h) with radius 0.43 h; the sprite is 12% bigger (`margin`) to leave room for the atmosphere halo.
- **Globe shader:**
  - Each pixel becomes a point on the sphere, turned Earth-fixed through `u_basis`, then latitude/longitude texture coordinates.
  - It samples the day map (`u_texture`), the night-lights map (`u_night`), and the cloud map (see Clouds below). Both maps are `sharedTexture`s, so every display and Settings' live copy share one of each.
  - **Daylight** = `smoothstep(−0.12, 0.1, sun·n) · (0.25 + 0.95·max(sun·n, 0))`, plus 0.03 of earthshine so the night side keeps its shape.
  - **The warm line** (2026-11-15): daylight is tinted `mix((1.3, 0.75, 0.5), 1, smoothstep(−0.02, 0.12, sun·n))`, so cloud and ground go copper and rose in the last 7° or so before night, sunlight through the long path of air, as in pictures from orbit, where the band was neutral grey. The review proposed (1, 0.62, 0.38) over −0.05…0.25: rendered, it was a band 15° wide of muddy tan, since orange on dim grey reads as brown. A physical Rayleigh tint (`exp(−τ·(airmass − 1))`, τ 0.05/0.1/0.24) was worse, a sepia wash over half the day side. The narrower, redder band reads as light, not dirt; at noon over the Americas in November it lies across the Arctic, where the Sun is that low all day.
  - **City lights:** night², tinted warm ×2.2, faded in past the terminator.
  - **Clouds:** `cloud = smoothstep(0.42, 0.95, map)`, crossfaded from `u_cloudsBefore` to `u_clouds` by `u_cloudFade`. Only during that minute's fade is the old map read at all (`if (u_cloudFade < 1.0)`, a branch on a uniform, so the GPU skips it whole): it used to be read at every pixel all the time, holding the same map as the new one. The ground mixes toward the cloud's colour by `cloud × 0.95` before lighting, so clouds are lit by the same daylight and earthshine: bright by day, faint grey on the night side. They dim city lights by `1 − 0.8·cloud` (lights glow through thin cloud) and block sun glint.
  - **The clouds' body** (2026-11-15, from the review of 14 November: clouds read as "cut paper" and "a featureless grey sheet"). The colour follows the map, from (0.62, 0.66, 0.72) for thin decks to white for the thick, cold tops (`smoothstep(0.55, 1, map)`), in place of one grey (0.8, 0.82, 0.86), so the sheets keep the swirls that are in the data. And the map is read once more a step toward the Sun along the ground (`uv2`): as far as a cloud top 8 km up throws its shadow, `0.0013 / sin(height)` of an Earth radius along the Sun's direction, at most 0.02 (1.1°). With the Sun high that's under a pixel, and nothing shows; near the terminator it's 6–8 pixels. A cloud standing above the cloud there is lit, one below it is in its shade (`× clamp(1 + 0.4·(cloud − sunward), 0.55, 1.12)`), and the ground is darkened by it (`× 1 − 0.6·sunward`), the cloud's shadow. Frontal bands get a lit edge and a shaded back, and cellular fields show their cells, in the band near the terminator that was the flattest part of the picture. During a fade the step is read from both maps too.
  - **Sun glint:** a Blinn-style highlight (power 90) only where the day map reads as ocean (blue > red) and there's no cloud.
  - **Atmosphere:** an edge tint of pale blue (0.6, 0.78, 1)·daylight inside the limb, and outside it a hairline of the same pale blue (`exp(−500·(r − 1))`, half strength) over a short blue glow (0.35, 0.6, 1) (`exp(−120·(r − 1))`, 0.6), both brighter on the sunward rim.
  - **A thinner atmosphere** (2026-11-15, from the review of 14 November). The glow was `exp(−40·(r − 1))` at 0.8 in deep blue: measured across the sunlit limb, still 116 of 255 in blue 12 px out and 12 at 60 px, which is 450 km of a globe 844 px in radius, about five times the real air's height. Now it's 255 at the limb, 81 at 5 px, 37 at 10 and gone by 20, a line of air as in whole-Earth photographs. It waits on Dave's pick, from the two side by side: the review asked "the thick blue glow or a thin, true-to-life line of air?", since the thick glow is part of the look he called great. To put it back: the glow at `exp(−40·(r − 1))`, 0.8, no hairline, and the edge tint (0.35, 0.6, 1).
- **Sun.** `u_sun` points at the subsolar point: `Sky.direction(sunRA − GMST, sunDec)`, updated every 5 s. The terminator moves in real time.
- **Stars** (real since 2026-11-15; they were w·h/2500 random white dots, the one made-up thing in the picture): Night Sky's catalogue (`NightSky.catalogue`, the Yale Bright Star Catalogue to magnitude 5.5) in their own colours (`NightSky.starColour`), placed by `placeStars()` in `refresh()`. The sky behind the Earth is the sky straight down from you, through the planet: centred on right ascension = local sidereal time + 12 h, declination = −your latitude (`EarthFromOrbit.behind`, a gnomonic projection on the view's own east and north). Seen from inside the sky like any sky, so its east is on the left: `starsBehindTheEarthAreTheSkyBelow` checks Orion the right way round. About 70° of sky top to bottom: at 60°, as the review proposed, only 140 stars showed at noon over the Americas in November against some 370 random ones before, and the faintest at 30% were all but invisible; at 70°, 170–230 show, the faint ones at 45% and 2.2 pt. They drift with the sky, 15° an hour, which is 4 pt a minute, so they're placed every 5 s (steps of 0.3 pt). Rebuilding the sprites each time takes about 1 ms on the main thread (release), once every 5 s. They don't twinkle, since there's no air up here.
- **ISS:**
  - In `update(_:)`, it takes the interpolated position now and 20 s ahead, converts each to an Earth-fixed vector in Earth radii (`station()`), and projects it with `basis`.
  - `visible()` hides it only when it's behind the globe, meaning facing away but inside the disc.
  - The marker pulses (scales to 2.2× while fading to 0.2 over 1.6 s).
  - The "ISS" label is a separate sibling node at 50% alpha that only follows the marker's position.
  - The orbit ring is a great circle through the two fixes, redrawn at most every 5 s, and broken where it's hidden behind the globe.

## ISS.swift (shared)
- **Source:** `https://api.wheretheiss.at/v1/satellites/25544/positions?timestamps=…`, which is free and needs no key. It returns 10 timestamps covering now to now + 90 s at 10 s steps, and the response gives `latitude`, `longitude`, `altitude` (km), `timestamp` and `visibility` ("daylight" or "eclipsed").
- **Polling:** `poll()` is limited to once every 50 s, however many scenes or displays ask. Scenes call it once a minute from an SKAction started in `didMove`, so it stops while the wallpaper is hidden.
- **Interpolation:** `position(at:)` interpolates linearly between the two surrounding fixes, wrapping longitude with `remainder(…, 360)`. `sunlit` comes from the nearer fix. It returns nil without fresh data, and the marker hides.
- **Failures** are silent (`try?`). If one poll fails, the track runs out after 90 s and the ISS disappears until the next successful poll.

## Clouds.swift
- **Source:** [Live Cloud Maps](https://github.com/matteason/live-cloud-maps) by Matt Eason: `https://clouds.matteason.co.uk/images/4096x2048/clouds.jpg`. It's an equirectangular greyscale map, the same projection as `earth-day.heic`, redrawn every 3 hours from EUMETSAT satellite data. It's CC0; EUMETSAT's terms ask for the credit "Contains modified EUMETSAT data", which is in About and the README. It also comes at 8192, 2048 and 1024 wide.
- **What the map shows:** it's infrared-based, so cold ground and thin haze read as mid-grey. The whole map averages bright (42% of pixels are above 224/255), and the high Arctic is often solid. The `smoothstep(0.42, 0.95, …)` in the shader keeps only the real cloud decks opaque. At 0.3 the far north turned into a flat grey haze.
- **Polling (deliberately lazy; Dave: "long long polling, this is not critical data"):** the scene calls `poll()` every 15 minutes from an SKAction in `didMove`, only while Live clouds is on. `poll()` is a local check: it goes to the network only when the cache file is over 3 hours old (the source's cadence) and at most once an hour, however many displays ask. Requests send the saved `ETag` (UserDefaults `clouds.etag`) as `If-None-Match`. A 304 touches the file's date, restarting the 3 hours; a 200 (1.5 MB) replaces it. In practice that's one request every ~3 hours.
- **Cache:** `~/Library/Caches/com.dtanquary.atrium/clouds.jpg`. `loadCache()` loads it only if no map is in memory. If the file is missing (Caches can be purged), its age counts as infinite and no ETag is sent.
- **The switch** (`updateClouds`, every frame):
  - **At scene build:** if Live clouds is on, the cached map goes straight into `u_clouds`, with no fade. The render harness sees it this way too.
  - **Switched off:** fades to a blank 1×1 texture over 60 s and calls `Clouds.release()`, so the 4K map is freed once the fade ends. Polling stops.
  - **Switched on:** `loadCache()` first, which bumps `version`, so the map fades in from the cache, then `poll()`, which only fetches if the cache is stale.
  - A download that finishes while clouds are off is saved to disk but not loaded.
- **One texture for all displays:** `Clouds.shared.texture` (mipmapped). `version` goes up with each loaded map, and the scene fades to it (`fadeClouds`). When a fade finishes, `u_cloudsBefore` is set to the current map, so the old one is freed.
- **Memory:** about 43 MB of GPU memory for a 4096 map with mipmaps; two maps only during a fade. `ponytail:` the map stays in memory after you switch to another wallpaper with clouds on. Release it in `willMove(from:)` if that matters; multiple displays then need care, since another display may still be showing it.
- **Failures** are silent (`try?`): the last map stays up.

## Lightning (Storms.swift and `updateLightning`)
- **Where storms are:** `Storms.poll(around:)` asks Open-Meteo for `hourly=weather_code`, 24 hours ahead, at 165 points in one request: a grid 4° apart, ±20° of latitude and ±28° of longitude around the viewer (latitudes clamped to ±85°, longitudes wrapped). The reply is a JSON array, one object per point. `cells` is the points with code 95, 96 or 99 (thunderstorm, with hail for 96/99) in the current hour, so the flashes move hour by hour between fetches. These are model storms, not observed strikes. Thunderstorms are small, so the grid stays 4° apart: a coarser one would find fewer storms, not coarser ones.
- **Polling, every 6 hours** (Dave, 2026-09-30: fewer calls; it used to follow each new cloud map, about every 3 hours, at ~1,300 calls a day). A 15-minute SKAction in `didMove` calls `Storms.poll`, which fetches once the forecast is 6 hours old, at most every 10 minutes however many displays ask. Open-Meteo counts each point as a call, so that's at most 4 × 165 = 660 a day, only while Earth from Orbit is on screen. Failures are silent and keep the last forecast, until its 24 hours run out: then there are no storms, rather than the last hour's flashing for good (found in the 1.0 review, 2026-10-08).
- **Refresh Now** on the Settings page (`Refresh.earth`) fetches the storms and checks the cloud map at once, at most every 15 minutes each.
- **Staleness:** storms move roughly 50 km/h, so after 3 hours a cell can be about 150 km (about 10 pt) off. That's fine for ambient flashes.
- **Coverage ceiling:** at 4° (about 440 km) spacing, the grid catches big storm systems but misses isolated cells between points. `ponytail:` a finer grid costs calls quadratically. Better: use the cloud map's brightest (coldest-topped) pixels to fill in storm areas between flagged points.
- **Flashes** (`updateLightning`, every frame):
  - A Poisson process: about one flash every 5 s per cell, at most one a second (capped at 5 cells), each at a random cell.
  - It tries six random spots within ±1.2° of the cell (longitude stretched by 1/cos latitude) and keeps the cloudiest, using `Clouds.cover(latitude:longitude:)`, a 512×256 CPU copy of the cloud map made in `Clouds.show`. So flashes land in thick cloud when the map has it there.
  - Each flash is an additive sprite, 14–34 pt, blue-white (0.8, 0.87, 1). The texture is a bright core with a soft glow, like lightning lighting a cloud from inside. It runs 1–3 strokes (0.03 s up, 0.06–0.15 s down to 15%), then a 0.3 s fade, then removes itself.
  - Strength is 1 on the night side and 0.3 by day (`dark` from the Sun direction, across ±0.1 of the terminator), since lightning is hard to see on sunlit cloud.
  - It's hidden if the spot is on the far side (`z < 0.05` in view space); cells ±20° around the viewer never are.
- **Preview a storm overhead** (`earth.previewStorm`): adds `Storms.preview(around:)`, five made-up cells within about a degree of the viewer, to the real ones. Dave asked for a way to "fake a storm directly over my location to test".
- `ponytail:` **a flash is a sprite, not light in the cloud.** It doesn't reveal cloud texture. The upgrade is flash positions as shader uniforms that brighten `cloud` locally.

## Time, live data and appearance
- **Time:** always real time (`Date()`), unless a render sets `EARTH_AT` (see Checking it). There's no preview setting.
- **Location:** `Location.start()` is called in `didMove`. The view centres on the saved fix, or on the time-zone fallback; see [night-sky.md](night-sky.md).
- **Appearance:** one look. It ignores Light/Dark Mode.

## Data and licences
- `earth-day.heic`: NASA's [Blue Marble Next Generation](https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-topography/) for September 2004 (chosen to avoid December snow) **with topography and without bathymetry** ([the file](https://assets.science.nasa.gov/content/dam/science/esd/eo/images/bmng/bmng-topography/september/world.topo.200409.3x21600x10800.jpg), 21600×10800, 23 MB), public domain. Until 2026-11-15 it was the 2048-wide map *with* bathymetry: its sea-floor shading was painted on the sea, the worst of it a dark hard-edged box in the Caribbean, the deep basin, right where the Sun glints at noon over the Americas; and at 2048 one texel covered 2.6 screen pixels at the middle of the globe, where you live (1.3 now). Without bathymetry the map's sea is near black, and darker still in a band over the shelves, which outlined every coast in black, so the bake lifts it to one deep blue, the old map's median sea (0.027, 0.08, 0.2), under the brighter shallows (the Bahamas, the Red Sea's reefs), before shrinking it, so coasts filter cleanly into it. The sea is whatever is dark and blue at full size (blue over red by 0.01, mean below 0.15): ice is bright and land isn't blue.
- `earth-night.heic`: NASA's [Black Marble 2016](https://science.nasa.gov/earth/earth-observatory/earth-at-night/maps/) at 3 km ([the file](https://assets.science.nasa.gov/content/dam/science/esd/eo/images/imagerecords/144000/144898/BlackMarble_2016_3km.jpg), 13500×6750), public domain, shrunk to 4096. The old 2048 map was the same one shrunk further: its mean level matches to 0.04 of 255, so the lights' gain stays.
- `eoimages.gsfc.nasa.gov`, where these used to be, no longer answers; `assets.science.nasa.gov` has them.
- The bake, from the downloaded files (Lanczos, then `sips -s format heic -s formatOptions 80`, which costs 1 level of 255 on average against the PNG):
  ```python
  from PIL import Image; import numpy as np
  Image.MAX_IMAGE_PIXELS = None
  a = np.asarray(Image.open('world.topo.200409.3x21600x10800.jpg').convert('RGB')).astype(np.float32) / 255
  sea = (a[..., 2] - a[..., 0] > 0.01) & (a.mean(-1) < 0.15)
  a = np.where(sea[..., None], np.maximum(a, [0.027, 0.08, 0.2]), a)
  Image.fromarray((a * 255 + 0.5).astype(np.uint8)).resize((4096, 2048), Image.LANCZOS).save('earth-day.png')
  Image.open('BlackMarble_2016_3km.jpg').convert('RGB').resize((4096, 2048), Image.LANCZOS).save('earth-night.png')
  ```
- The credit is in a comment in `addGlobe()`, and in About (Earth imagery, Earth at night).
- The stars are Night Sky's `stars.txt`, the Yale Bright Star Catalogue, 5th ed. (CDS V/50), public domain, credited in the file's header (see [night-sky.md](night-sky.md)).
- Both load through `resource(_:)` as mipmapped textures.

## Settings
| key | label | range | default | drives |
|---|---|---|---|---|
| `earth.iss` | ISS tracking | toggle | on | Off hides the marker, label and orbit ring, and skips polling (`update` and the poll action both check it) |
| `earth.lightning` | Lightning in storms near you | toggle | on | Off stops flashes and storm polling |
| `earth.previewStorm` | Preview a storm overhead | toggle | off | Adds a fake storm complex over the viewer; shown only while lightning is on |
| `earth.clouds` | Live clouds | toggle | on | Off fades the clouds out, frees the map and stops polling; on fades them back in from the cache, then polls only if the cache is stale |

All are read live through `Self.knobs[i].value` every frame (in `knobs` order: ISS 0, clouds 1, lightning 2, preview 3), with no notification observer needed.

## Tuning constants
- **Globe:** radius 0.43 h, centre (0.58 w, 0.48 h), margin 1.12.
- **Timing:** sun, view and stars refresh every 5 s; orbit ring redraws at most every 5 s; ISS poll every 60 s.
- **ISS marker:** 14 pt, pulsing to 2.2× over 1.6 s.
- **Shader:** city-light gain 2.2, glint power 90, halo falloff 120 (0.6) and hairline 500 (0.5); warm line (1.3, 0.75, 0.5) up to sun·n 0.12.
- **Stars:** 70° of sky top to bottom; diameter `max(2.2, 5.4 − 0.6·V)` pt, alpha `0.45…0.9` (`1.05 − 0.1·V`).

## Performance
- About 0.49 ms CPU and 0.18 ms GPU per frame (release build, 2x, 1512×982) before clouds. With clouds it measured 0.45 ms CPU and 0.3–0.6 ms GPU: two more 4K texture samples per globe pixel. With clouds off it's back to 0.15 ms (blank 1×1 textures). The clouds' body (2026-11-15) reads the map toward the Sun in place of the old map, which is now read only while fading, so the reads a pixel stay at two: measured back to back in release under load from other builds, 0.28–0.44 ms GPU with it against 0.29–0.48 without, no difference to measure.
- The globe shader only covers the globe's sprite. The orbit path rebuilds at most every 5 s.
- **The 4096 maps** (2026-11-15) cost nothing a frame (mipmapped reads cost the same), 1.3 MB of download in place of 0.75, and about 90 MB of GPU memory with mipmaps in place of 22, shared by every display and Settings' copy, where each copy used to load its own. Building the scene takes about 110 ms more on the main thread the first time (decoding the two HEICs: 135 ms against 26, measured with a scratch script that loads and draws them), and nothing for a second copy.
- Plenty of headroom.

- **On battery it runs at 10 fps at most with no storm cell near, and at the battery's rate while there are any** (`batteryRate`, set in `updateLightning` each time it looks for a cell, every 5 s with none; 2026-10-13). Without storms nothing moves even 1 device pixels (2x on a 14-inch MacBook Pro, 3024 × 1964) a second: the ISS marker about 1, its pulse 1.6 s, a new cloud map fades in over 60 s. Lightning strokes rise in 30 ms and fall in 60–150, flickering at 5–11 Hz, which 15 fps or less would merge or miss.

## Gotchas and shortcuts
- `ponytail:` **the orbit ring** comes from two fixes in Earth-fixed axes, so it ignores Earth's spin: about a 3° tilt error.
- **The ISS label** must not be a child of the pulsing marker, or it scales and fades with it.
- **Clouds are a still snapshot** between 3-hourly maps, with no drift. A slow advection (warping the lookup along the jet streams) or a flow between two maps would make them move.
- `ponytail:` **cloud shadows and relief come from one read toward the Sun,** with the map's brightness standing for height. It's right in the band near the terminator, where the Sun is low; the next step would be a height from the map (cold tops are high) and two reads, one near for the cloud's own slopes and one far for its shadow.

## Dave's feedback and decisions
- **Static label.** "Don't blink and scale / fade the ISS text, just have it be a fixed semi faded text next to the ISS … let everything else … be the animated parts." That's why the label is a separate node at 50% alpha. The marker dot still pulses; he didn't ask for that to change.
- **The ISS tracking switch** was his request.
- **Centred on his location,** which he tested and liked.
- **Real clouds** (2026-09-24): he asked how hard "semi global cloud data" for "somewhat realistic cloud coverage" would be, and chose clouds first, with lightning to follow. He asked for the Live clouds switch, with no polling while it's off, loading from the cache first when it's turned back on, and "long long polling, this is not critical data". His verdict on the result: "it looks great".
- **Lightning** (2026-09-24): he asked for bursts "where we believe storms to be in the region around me", and for a fake storm over his location to test with, which became the Preview switch. His verdict: "its great".

## Ideas / next steps
- **Observed lightning** instead of forecast storms: NOAA GOES GLM is public domain but Americas-only, and ships as NetCDF every 20 s. Blitzortung's terms restrict reuse.
- **Lightning that lights the cloud** in the shader (see the ponytail note under Lightning).
- Cloud drift between the 3-hourly maps.
- The Moon. The terminator's warm line is in (2026-11-15); a blue twilight glow past it, lit by the sky, isn't.
- A time-lapse or preview setting.
- Settings for zoom and framing.
- Correcting the orbit ring for Earth's spin.
- Showing the ISS's ground track.

## Checking it
- `SNAPSHOT_SCENE="Earth from Orbit" swift test` renders the current terminator at the fallback location. There's no ISS, because `didMove` never runs in the harness.
- `SNAPSHOT_DEFAULTS="earth.iss=0" …` or `"earth.clouds=0"` checks a switch.
- **Lightning:** `SNAPSHOT_SECONDS=0.034 SNAPSHOT_DEFAULTS="earth.previewStorm=1"` catches the first preview flash (it fires on the first update and is fully up one frame later). Later frames usually fall between flashes.
- Clouds render from the cache file. To seed it: `curl -o ~/Library/Caches/com.dtanquary.atrium/clouds.jpg https://clouds.matteason.co.uk/images/4096x2048/clouds.jpg`.
- **Another moment:** `EARTH_AT=<Unix seconds>` sets the scene's clock (the Sun, and so the terminator), so two renders can be compared at one moment: `EARTH_AT=1794760200` is 16:30 UTC on 15 November 2026, noon over the Caribbean. The cloud map is still the cached one.
- To see the ISS offline, you'd need a temporary test that fills `ISS.shared` and renders. That was done once while building it, then deleted.
