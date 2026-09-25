# Earth from Orbit

The whole Earth seen from high above the viewer's own location, like a geostationary satellite parked overhead, set against a still starfield. It shows the real line between day and night, today's real clouds, lightning in the storms around the viewer, city lights on the night side, sun glint on the oceans, a lit edge of atmosphere, and the ISS at its live position with its orbit ring.

- **Files:**
  - `Sources/Atrium/EarthFromOrbit.swift`: the scene.
  - `Sources/Atrium/ISS.swift`: `ISS.shared`, the live position, shared with [Live Sky](live-sky.md).
  - `Sources/Atrium/Clouds.swift`: `Clouds.shared`, the live global cloud map.
  - `Sources/Atrium/Storms.swift`: `Storms.shared`, where thunderstorms are around the viewer.
  - `Sources/Atrium/Resources/earth-day.jpg` (486 KB) and `earth-night.jpg` (263 KB), both about 2048×1024.
  - Astronomy comes from `SkyMath.swift` and location from `Location.swift`; see [live-sky.md](live-sky.md).
- **Entry:** `earthFromOrbit(size:)` builds `final class EarthFromOrbit: SKScene`. Its entry in Scenes.swift is "Earth from Orbit", icon `globe.americas.fill`, tint `.cyan`, `knobs: EarthFromOrbit.knobs`.
- **Kind:** hybrid. The globe is one sprite with an SKShader sampling two textures; the stars, ISS marker, label and orbit ring are nodes.

## How it works
- **View frame.** `basis` has three Earth-fixed axes: east, north, and the up vector at the viewer's latitude and longitude. The globe is always seen from straight above the viewer. `refresh()` rebuilds it every 30 s from `Location.shared`. The globe sits at (0.58 w, 0.48 h) with radius 0.43 h; the sprite is 12% bigger (`margin`) to leave room for the atmosphere halo.
- **Globe shader:**
  - Each pixel becomes a point on the sphere, turned Earth-fixed through `u_basis`, then latitude/longitude texture coordinates.
  - It samples the day map (`u_texture`), the night-lights map (`u_night`), and the cloud map (see Clouds below).
  - **Daylight** = `smoothstep(−0.12, 0.1, sun·n) · (0.25 + 0.95·max(sun·n, 0))`, plus 0.03 of earthshine so the night side keeps its shape.
  - **City lights:** night², tinted warm ×2.2, faded in past the terminator.
  - **Clouds:** `cloud = smoothstep(0.42, 0.95, map)`, crossfaded from `u_cloudsBefore` to `u_clouds` by `u_cloudFade`. The ground mixes toward cloud grey (0.8, 0.82, 0.86) by `cloud × 0.95` before lighting, so clouds are lit by the same daylight and earthshine: bright by day, faint grey on the night side. They dim city lights by `1 − 0.8·cloud` (lights glow through thin cloud) and block sun glint.
  - **Sun glint:** a Blinn-style highlight (power 90) only where the day map reads as ocean (blue > red) and there's no cloud.
  - **Atmosphere:** an edge tint of (0.35, 0.6, 1)·daylight, plus a halo outside the disc that's brighter on the sunward rim.
- **Sun.** `u_sun` points at the subsolar point: `Sky.direction(sunRA − GMST, sunDec)`, updated every 30 s. The terminator moves in real time.
- **Stars:** about w·h/2500 still sprites. They don't twinkle, since there's no atmosphere up here. Brightness is `random³`.
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
- **Source:** [Live Cloud Maps](https://github.com/matteason/live-cloud-maps) by Matt Eason: `https://clouds.matteason.co.uk/images/4096x2048/clouds.jpg`. It's an equirectangular greyscale map, the same projection as `earth-day.jpg`, redrawn every 3 hours from EUMETSAT satellite data. It's CC0; EUMETSAT's terms ask for the credit "Contains modified EUMETSAT data", which is in About and the README. It also comes at 8192, 2048 and 1024 wide.
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
- **Where storms are:** `Storms.poll(around:)` asks Open-Meteo for `current=weather_code` at 165 points in one request: a grid 4° apart, ±20° of latitude and ±28° of longitude around the viewer (latitudes clamped to ±85°, longitudes wrapped). The reply is a JSON array, one object per point. Points with code 95, 96 or 99 (thunderstorm, with hail for 96/99) become `cells`. These are model storms, not observed strikes.
- **Polling follows the clouds** (Dave: "can we just do it every time we update the clouds?"). `updateClouds` calls `Storms.poll` whenever it fades to a newly loaded cloud map, so storms refresh about every 3 hours and match the clouds the flashes snap to. `poll` itself only guards against repeats within 10 minutes (several displays see the same new map). A 15-minute SKAction in `didMove` covers the other cases: it polls if storms are over 3 hours old with clouds off, or over 4 hours old with clouds on (at launch, when the cloud map came back unchanged, or after a failed download). Open-Meteo counts each point as a call, so that's about 8 × 165 ≈ 1,300 calls a day, only while Earth from Orbit is on screen. Failures are silent and keep the last cells.
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
- **Time:** always real time (`Date()`). There's no preview seam.
- **Location:** `Location.start()` is called in `didMove`. The view centres on the saved fix, or on the time-zone fallback; see [live-sky.md](live-sky.md).
- **Appearance:** one look. It ignores Light/Dark Mode.

## Data and licences
- `earth-day.jpg`: NASA Blue Marble, September 2004 (chosen to avoid December snow), public domain.
- `earth-night.jpg`: NASA Black Marble 2016, public domain.
- The credit is in a comment in `addGlobe()`.
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
- **Timing:** sun and view refresh every 30 s; orbit ring redraws at most every 5 s; ISS poll every 60 s.
- **ISS marker:** 14 pt, pulsing to 2.2× over 1.6 s.
- **Shader:** city-light gain 2.2, glint power 90, halo falloff 40.
- **Stars:** density one per 2,500 pt².

## Performance
- About 0.49 ms CPU and 0.18 ms GPU per frame (release build, 2x, 1512×982) before clouds. With clouds it measured 0.45 ms CPU and 0.3–0.6 ms GPU: two more 4K texture samples per globe pixel. With clouds off it's back to 0.15 ms (blank 1×1 textures).
- The globe shader only covers the globe's sprite. The orbit path rebuilds at most every 5 s.
- Plenty of headroom.

## Gotchas and shortcuts
- `ponytail:` **the orbit ring** comes from two fixes in Earth-fixed axes, so it ignores Earth's spin: about a 3° tilt error.
- **The ISS label** must not be a child of the pulsing marker, or it scales and fades with it.
- **Clouds are a still snapshot** between 3-hourly maps, with no drift. A slow advection (warping the lookup along the jet streams) or a flow between two maps would make them move.
- `ponytail:` **no cloud shadows or thickness.** At this scale, shadows are a pixel or two. Add a shadow offset away from the Sun if the globe gets zoomed in.
- **The stars** are random on each load, not a real star field.

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
- The Moon, and the terminator's twilight band.
- A time-lapse or preview setting.
- Settings for zoom and framing.
- Correcting the orbit ring for Earth's spin.
- Showing the ISS's ground track.

## Checking it
- `SNAPSHOT_SCENE="Earth from Orbit" swift test` renders the current terminator at the fallback location. There's no ISS, because `didMove` never runs in the harness.
- `SNAPSHOT_DEFAULTS="earth.iss=0" …` or `"earth.clouds=0"` checks a switch.
- **Lightning:** `SNAPSHOT_SECONDS=0.034 SNAPSHOT_DEFAULTS="earth.previewStorm=1"` catches the first preview flash (it fires on the first update and is fully up one frame later). Later frames usually fall between flashes.
- Clouds render from the cache file. To seed it: `curl -o ~/Library/Caches/com.dtanquary.atrium/clouds.jpg https://clouds.matteason.co.uk/images/4096x2048/clouds.jpg`.
- To see daylight over the Americas at night, temporarily change `Sky.julianDate(Date())` in `refresh()` to `Date(timeIntervalSinceNow: 12 * 3600)`, and revert it before committing.
- To see the ISS offline, you'd need a temporary test that fills `ISS.shared` and renders. That was done once while building it, then deleted.
