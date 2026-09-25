# Live Sky

The real sky above the viewer right now, looking toward the equator: about 2,900 stars, the Milky Way, constellation lines, the five naked-eye planets, the Moon in its true phase and tilt, the ISS when it's overhead and sunlit, and an occasional meteor, above a treeline. It stays a night sky, but it reacts to the Sun: deep blue by day with only the brightest objects, the Sun drawn when it's in view, and sunrise and sunset glow at their real times.

- **Files:**
  - `Sources/Wallpaper/LiveSky.swift`: the scene.
  - `Sources/Wallpaper/SkyMath.swift`: `enum Sky`, the positional astronomy. Shared with Earth from Orbit, Weather and Flowing Gradient.
  - `Sources/Wallpaper/Location.swift`: `Location.shared`, the viewer's position. Shared with every live scene.
  - `Sources/Wallpaper/ISS.swift`: see [earth-from-orbit.md](earth-from-orbit.md).
  - `Sources/Wallpaper/Resources/stars.txt` and `constellations.txt`.
  - `Tests/WallpaperTests/SkyTests.swift`.
- **Entry:** `liveSky(size:)` builds `final class LiveSky: SKScene`. Its entry in Scenes.swift is "Live Sky", icon `moon.stars.fill`, tint `.blue`, `knobs: LiveSky.knobs`.
- **Kind:** hybrid. The background and the Moon are SKShaders; stars, planets, the Sun, the ISS, labels and meteors are sprites; the ground is a Core Graphics texture.

## How it works
- **Projection.** A stereographic projection centred on the horizon point the view faces: south, or north when latitude < 0 (`facingSouth`). Great circles through the centre stay straight, so the horizon is a straight line. `scale` gives about a 120° horizontal field of view; `horizonY` sits 12% up the screen. `project()` returns nil for points behind the viewer (`1 + forward <= 0.2`). `place()` hides a node that's below the horizon (z < −0.01) or more than 30 pt off-screen.
- **Frames.** Equatorial directions are J2000 unit vectors. `Sky.horizonMatrix(jd:latitude:longitude:)` turns them into (east, north, up). `refresh()` recomputes every position every 5 s, and on any settings change.
- **Background shader** (`addSkyBackground`): each pixel is un-projected back onto the sphere, as (right, up, forward).
  - It mixes a night gradient and a day gradient by `u_day`.
  - The Milky Way is computed in galactic coordinates through `u_galactic` (screen → horizon → equatorial → galactic, built in `refresh()`): a disc, a bulge toward the galactic centre, three octaves of 3D value noise, and a dust lane. It fades by day.
  - A twilight band of warm light sits low in the sky, strongest toward the Sun's azimuth (`u_twilight`, `u_sun` in the same right/up/forward frame).
  - A halo around the Sun by day, and ±½/255 dither against banding.
- **Stars:** `stars.txt` holds 2,887 stars to magnitude 5.5, as `RA Dec V B−V` in degrees, J2000.
  - Size is `max(2.2, 11 − 1.55·V)` points, colour comes from B−V (`starColour`), and alpha from V.
  - Stars brighter than V 2 twinkle with fade actions.
  - Stars are grouped into 16 parent layers by half magnitude (`starLayers`), so daylight fades a whole magnitude band by setting one layer's alpha. The twinkle actions keep owning each star's own alpha, and the two don't fight.
- **Constellations:** one `SKShapeNode` path, rebuilt each refresh from `constellations.txt` polylines. A segment breaks where it dips below the horizon.
- **Planets:** `Sky.planet(_:_:)` gives Mercury to Saturn. Each is a glow sprite with a fixed size, colour and typical magnitude (used only for daytime fading) and an "ISS"-style label as its child.
- **Sun:** a 48 pt disc and a 360 pt glow, blended toward orange below 12° altitude. It's hidden below the horizon or out of view.
- **Moon:** a 46 pt disc (exaggerated; the real Moon is about 5 pt at this scale) drawn by a shader.
  - The shader treats the disc as a sphere lit from `u_light`, with 11 hand-placed maria blobs.
  - The disc is rotated so its north points to the celestial pole on screen (`screenAngle` toward `poleH`).
  - The light direction is measured from the Moon's north using `skyAngle`, which works in the local frame of someone facing the Moon with their head upright. That keeps it correct however the disc is turned.
  - The phase angle comes from `Sky.moonPhase(jd).lit` (`acos(2·lit − 1)`).
  - Glow alpha = 0.5 · lit · (1 − 0.7 · day).
- **ISS:** in `update(_:)`, using `ISS.shared.position()` → `Sky.lookDirection` → `place()`. It's shown only while sunlit (the real naked-eye condition), with a label as a child.
- **Meteors:** a painted 140×2 pt streak every 15–75 s (`wait 45 ± 30`), fading over 0.7 s.
- **Ground:** a hill ridge and stands of conifers painted once (`addHorizon`), plus faint compass letters (SE, S, SW, or NW, N, NE).

## Time, live data and appearance
- **Time:** `skyDate` is `Date()`, or today at `sky.previewHour` while `sky.previewTime` is on.
- **Daylight:**
  - `day = smoothstep(−14°, 4°, sun altitude)`
  - the faintest magnitude still shown is `limit = 6 − 4.5·day`, so about magnitude 1.5 at noon
  - planets fade by the same rule using their fixed magnitudes
  - constellation alpha = 1 − day
  - twilight glow = `smoothstep(−16, −4) · (1 − smoothstep(4, 14))`
- **Location:** `Location.shared`, from CoreLocation. It asks for When In Use permission on the first `start()`, from `didMove`. The last fix is saved in UserDefaults (`latitude`, `longitude`). Before the first fix, it falls back to 40°N and a longitude guessed from the standard time-zone offset (DST removed). It's read on every refresh.
- **Network:** only the ISS. Polling starts in `didMove`, once a minute. See [earth-from-orbit.md](earth-from-orbit.md).
- **Appearance:** one look. It ignores Light/Dark Mode, because the sky is inherently dark.

## Astronomy (SkyMath.swift)
- **Planets:** JPL "Approximate Positions of the Planets", table 1 Keplerian elements (1800–2050), with Kepler's equation solved by Newton's method in 5 iterations. Earth's elements give the Sun.
- **Moon:** the Astronomical Almanac low-precision series (about 0.3°), stepped from the equinox of date back to J2000 by −1.397°·T. `moonPhase` gives lit = (1 − m·s)/2, and waxing = the Moon is east of the Sun along the ecliptic.
- **Other helpers:**
  - `siderealTime` is GMST in degrees.
  - `lookDirection` gives the direction from a ground observer to a point at altitude. It uses a spherical Earth, R = 6371 km.
  - `galactic` is the J2000 → galactic rotation matrix.
- **Accuracy:** SkyTests match JPL Horizons within 1° at 2026-01-01 for the Sun, Moon and planets, and the Moon's lit fraction within 0.02 on two dates.

## Data and licences
- `stars.txt`: Yale Bright Star Catalogue, 5th ed. (CDS V/50), public domain. Credit is in the file header.
- `constellations.txt`: d3-celestial (Olaf Frohn), BSD 3-Clause. The full licence notice is kept in the header and must stay there.

## Settings
| key | label | range | default | drives |
|---|---|---|---|---|
| `sky.constellations` | Constellation lines | toggle | on | `constellations.isHidden` |
| `sky.planetLabels` | Planet labels | toggle | on | the planet nodes' label children |
| `sky.previewTime` | Preview a time of day | toggle | off | `skyDate` uses the preview hour |
| `sky.previewHour` | Time (shown while previewing) | 0–24 h | 13:00 | the hour for `skyDate` |

`applySettings()` observes `UserDefaults.didChangeNotification` and calls `refresh()` every time, including for unrelated defaults writes. Each call places about 2,900 sprites, which is cheap but not free.

## Tuning constants
- **View:** a 120° field of view (`scale`), horizon at 12% (`horizonY`).
- **Timing:** refresh every 5 s; meteors every 45 ± 30 s.
- **Stars:**
  - size `11 − 1.55·V`, minimum 2.2 pt
  - alpha `1.2 − 0.14·V`, clamped between 0.35 and 1
  - bright stars twinkle to 60% over 0.15–0.5 s
- **Daylight:** `day` smoothstep between −14° and 4°; the magnitude limit runs from 6 at night to 1.5 by day.
- **Sprite sizes:** Moon 46 pt, Moon glow 220 pt, Sun 48 pt, Sun glow 360 pt.
- **Planet magnitudes:** Mercury 0, Venus −4.2, Mars 0.5, Jupiter −2.2, Saturn 0.7.

## Performance
- About 0.64 ms CPU and 0.90 ms GPU per frame (release build, 2x, 1512×982).
- The GPU cost is the full-screen background shader: 3D noise for the Milky Way on every pixel.
- The CPU cost is mostly SpriteKit handling about 2,900 star sprites, which batch because they share one texture. `refresh()` only runs every 5 s.
- Well within the 2 ms budget.

## Gotchas and shortcuts
- `ponytail:` **precession.** It's ignored since J2000, about 0.35° by 2026. It shifts the whole sky together, so nothing looks wrong relative to itself.
- `ponytail:` **no topocentric parallax for the Moon.** It can sit up to about 1° off its true place against the stars.
- `ponytail:` **fixed planet magnitudes.** Real ones swing (Mars from about −2.9 to +1.8). They only affect daytime fading.
- `ponytail:` **hand-placed maria.** A real lunar albedo map would add fidelity.
- `ponytail:` **fallback location.** The time-zone guess can be about 15° off in latitude until CoreLocation answers.
- **Twinkle actions.** They set absolute alphas, which is why daylight fading goes through the parent layers. Don't fade the star sprites themselves.
- **Moon light and turned discs.** The Moon's light vector must be measured from the Moon's north, not from screen up, or it breaks when the disc is rotated.
- **Render tests** never call `didMove`, so the snapshot has no ISS and no location request.

## Dave's feedback and decisions
- **Name.** He asked for Night Sky based on his real location; it was renamed Live Sky once it followed the day. The code, file and type were renamed, and a saved "Night Sky" selection is migrated in main.swift.
- **Daytime behaviour.** He chose option 3: stay a night sky but react to the Sun. The tag `night-sky-always-dark` keeps the always-dark version, in case he wants separate Day and Night wallpapers (`git show night-sky-always-dark:Sources/Wallpaper/NightSky.swift`).
- **Moon.** "Show the moon phase as it would from my location" meant that the Moon itself should be accurate. A bottom-left phase badge was added, then removed at his request as redundant. Don't bring back a HUD for this.
- **Switches.** He asked for the constellation and planet-label switches.
- **Preview.** Added so he could see the daytime look on demand.

## Ideas / next steps
- Real planet magnitudes, from distance and phase.
- Topocentric Moon parallax.
- A real lunar albedo texture.
- A meteor rate that follows the showers (Perseids, Geminids).
- Satellite flares and more satellites.
- Stars that dim near the horizon (extinction).
- Twinkling tied to how high a star sits.
- Settings for field of view, direction faced, or the Milky Way on or off.

## Checking it
- `SNAPSHOT_SCENE="Live Sky" swift test` renders the current moment at the fallback location, because the test process has its own defaults domain.
- To render a set time: `SNAPSHOT_DEFAULTS="sky.previewTime=1,sky.previewHour=18.8" SNAPSHOT_SCENE="Live Sky" swift test`. Try 13 for noon, about 18.8 for sunset at the test's fallback longitude of −90°, and 23 for night. To hide things, add `sky.constellations=0,sky.planetLabels=0`.
- `swift test --filter SkyTests`:
  - positions matched against Horizons
  - the Moon's lit fraction and waxing/waning
  - Polaris' altitude equals the latitude
  - an ISS directly overhead points straight up
