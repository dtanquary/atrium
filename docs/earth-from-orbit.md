# Earth from Orbit

The whole Earth seen from high above the viewer's own location, like a geostationary satellite parked overhead, set against a still starfield. It shows the real line between day and night, city lights on the night side, sun glint on the oceans, a lit edge of atmosphere, and the ISS at its live position with its orbit ring.

- **Files:**
  - `Sources/Atrium/EarthFromOrbit.swift`: the scene.
  - `Sources/Atrium/ISS.swift`: `ISS.shared`, the live position, shared with [Live Sky](live-sky.md).
  - `Sources/Atrium/Resources/earth-day.jpg` (486 KB) and `earth-night.jpg` (263 KB), both about 2048×1024.
  - Astronomy comes from `SkyMath.swift` and location from `Location.swift`; see [live-sky.md](live-sky.md).
- **Entry:** `earthFromOrbit(size:)` builds `final class EarthFromOrbit: SKScene`. Its entry in Scenes.swift is "Earth from Orbit", icon `globe.americas.fill`, tint `.cyan`, `knobs: EarthFromOrbit.knobs`.
- **Kind:** hybrid. The globe is one sprite with an SKShader sampling two textures; the stars, ISS marker, label and orbit ring are nodes.

## How it works
- **View frame.** `basis` has three Earth-fixed axes: east, north, and the up vector at the viewer's latitude and longitude. The globe is always seen from straight above the viewer. `refresh()` rebuilds it every 30 s from `Location.shared`. The globe sits at (0.58 w, 0.48 h) with radius 0.43 h; the sprite is 12% bigger (`margin`) to leave room for the atmosphere halo.
- **Globe shader:**
  - Each pixel becomes a point on the sphere, turned Earth-fixed through `u_basis`, then latitude/longitude texture coordinates.
  - It samples the day map (`u_texture`) and the night-lights map (`u_night`).
  - **Daylight** = `smoothstep(−0.12, 0.1, sun·n) · (0.25 + 0.95·max(sun·n, 0))`, plus 0.03 of earthshine so the night side keeps its shape.
  - **City lights:** night², tinted warm ×2.2, faded in past the terminator.
  - **Sun glint:** a Blinn-style highlight (power 90) only where the day map reads as ocean (blue > red).
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

It's read live through `Self.knobs[0].value` every frame, with no notification observer needed.

## Tuning constants
- **Globe:** radius 0.43 h, centre (0.58 w, 0.48 h), margin 1.12.
- **Timing:** sun and view refresh every 30 s; orbit ring redraws at most every 5 s; ISS poll every 60 s.
- **ISS marker:** 14 pt, pulsing to 2.2× over 1.6 s.
- **Shader:** city-light gain 2.2, glint power 90, halo falloff 40.
- **Stars:** density one per 2,500 pt².

## Performance
- About 0.49 ms CPU and 0.18 ms GPU per frame (release build, 2x, 1512×982).
- The globe shader only covers the globe's sprite. The orbit path rebuilds at most every 5 s.
- Plenty of headroom.

## Gotchas and shortcuts
- `ponytail:` **the orbit ring** comes from two fixes in Earth-fixed axes, so it ignores Earth's spin: about a 3° tilt error.
- **The ISS label** must not be a child of the pulsing marker, or it scales and fades with it.
- **No clouds on the globe.** A NASA cloud layer would be the next step for realism.
- **The stars** are random on each load, not a real star field.

## Dave's feedback and decisions
- **Static label.** "Don't blink and scale / fade the ISS text, just have it be a fixed semi faded text next to the ISS … let everything else … be the animated parts." That's why the label is a separate node at 50% alpha. The marker dot still pulses; he didn't ask for that to change.
- **The ISS tracking switch** was his request.
- **Centred on his location,** which he tested and liked.

## Ideas / next steps
- A cloud layer (NASA cloud composites), maybe drifting.
- The Moon, and the terminator's twilight band.
- A time-lapse or preview setting.
- Settings for zoom and framing.
- Correcting the orbit ring for Earth's spin.
- Showing the ISS's ground track.

## Checking it
- `SNAPSHOT_SCENE="Earth from Orbit" swift test` renders the current terminator at the fallback location. There's no ISS, because `didMove` never runs in the harness.
- `SNAPSHOT_DEFAULTS="earth.iss=0" …` checks the switch.
- To see the ISS offline, you'd need a temporary test that fills `ISS.shared` and renders. That was done once while building it, then deleted.
