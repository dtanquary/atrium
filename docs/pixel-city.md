# Pixel City

A pixel-art skyline that follows the real Sun and clock. The sky moves through dawn, day, dusk and night, with the Sun and Moon in their real places and stars after dark. Windows light up and go dark through the evening, cars and buses run in both lanes (with headlights at night), a beacon blinks on the tallest tower, and the odd plane crosses.

- **Files:** `Sources/Wallpaper/PixelCity.swift`, which holds everything: the scene, the `Pixels` canvas, sprite art as strings, `SeededRandom`, and its own low-precision `skyPosition()` for the Sun. It reads `Location.swift` ([live-sky.md](live-sky.md)).
- **Entry:** `pixelCity(size:)` builds `final class PixelCity: SKScene`, whose `init(size:at:)` is the test seam (a fixed `Date`). Its entry in Scenes.swift is "Pixel City", icon `building.2.fill`, tint `.pink`, with no settings.
- **Kind:** SpriteKit on a low-resolution canvas. One backdrop texture is repainted every 30 s, and sprites for the moving things all sit under a `canvas` node scaled up by the pixel size. Every texture uses `.nearest` filtering, so it stays crisp.

## How it works
- **Resolution:** `pixel = max(2, round(height/240))` points per art pixel, so 4 pt on a 982 pt-tall display. The canvas is `w × h` art pixels. Motion rounds to whole art pixels so nothing blurs.
- **`layOut()`** runs once, from `SeededRandom(state: 2026)`, so the city is identical on every redraw and every display.
  - **Far row:** hazy blue-grey buildings.
  - **Near row:** brick, stone and concrete buildings, with per-building window spacing (`floor`, `pitch`) and a roof (plain, ledge, setback or water tank).
  - **The landmark:** the widest near building around 3/5 across is raised to 50% height, with an antenna and a red beacon (0.25 s on, 1.25 s off).
  - **Also:** 170 stars, 3 cloud masks, and a pool of 6 cars per lane with headlight beams. There are 7 sedan colours plus a bus, and a plane with blinking nav lights.
- **`redraw()`** runs at init and every 30 s, and repaints the whole backdrop with a `Pixels` buffer:
  - **Sky:** a gradient between zenith and horizon colours from `skyColours(elevation, morning:)`. The stops run −18°, −10°, −4°, 0°, 6° and 15°, and dawn is pinker than dusk. It's quantised into 14 bands with 4×4 Bayer dithering, plus a sun glow around a low Sun, also dithered into 5 steps.
  - **Stars** fade in below about −5°; the brightest get a small cross.
  - **Moon:**
    - **Phase:** from a mean synodic month counted from the new Moon of 2000-01-06 18:14 UTC.
    - **Position:** the Sun's ecliptic longitude plus phase × 360° (no lunar inclination).
    - **Lit side:** on the right while waxing.
    - **Earthshine** on the dark part at night.
  - **Sun:** a 6-pixel-radius disc, orange near the horizon.
  - **Buildings:**
    - Facades darken toward moonlit blue at night, and the far row takes on the horizon colour as haze.
    - Windows turn on via `isLit()` with three seeded draws per window. About 65% are lit on an evening schedule: people get home between 16:30 and 21:00 and go to bed between 21:00 and 03:00. 30% come on for early risers from 05:30. 3% are always on (stairwells and night owls). The colours are mostly warm tungsten, with a few cool blue or white ones.
  - **Street:** sidewalks, road markings, and a lamp every 46 pixels casting a three-step pool of light at night.
  - Clouds, cars and the plane are recoloured for the light: day and night car textures, headlight beams fading in at night, and the plane turning into a dark silhouette.
- **`update(_:)`** runs every frame:
  - **Cars:** they move at their cruise speed (buses 11–14, cars 14–22 art pixels per second). A car closes up behind a slower car in the same lane (gap < 6) instead of driving through it.
  - **Spawning:** new cars come in from the pool every `(1.5–6 s) / traffic`, where `traffic` is an hourly table with rush hours at 08:00 and 17:00 and quiet small hours. 10% of spawns are buses.
  - **Clouds** drift and wrap.
  - **Plane:** one every 40–120 s, at 7 px/s, somewhere in the top 20% of the sky.

## Time, live data and appearance
- **Time:** `fixedTime ?? Date()`. The hour for windows and traffic is the local clock hour.
- **Sun:** `skyPosition()` at `Location.shared` (low precision, about 1°). `night = smoothstep(4°, −8°, sun elevation)`.
- **Placement:** sky positions go onto the canvas looking toward the equator (`place()`). Azimuth spans about 200° across the screen, and elevation 0–70° spans the sky.
- **No network.** `Location.shared.start()` is called in `didMove`.
- **Appearance:** it ignores Light/Dark Mode. The real Sun already sets the look.

## Settings
None yet.

## Tuning constants
- **Canvas:** 240 art pixels per screen height; the street top is at row 26; lamps every 46 px.
- **Timing:** redraw every 30 s.
- **Window schedule** (`isLit`): home 16.5 h + 4.5·rand; bed 21 h + 6·rand; early risers 5.5 h + 1.5·rand.
- **Traffic:** the `traffic` table has 24 hourly multipliers.
- **Vehicles:** the car pool has 6 per lane; cars reach at most 22 px/s.
- **Planes:** 40–120 s apart, 7 px/s.

## Performance
- About 0.43 ms CPU and 0.18 ms GPU per frame (release build, 2x, 1512×982).
- The 30 s repaint costs about 3 ms once in a release build. It loops over every art pixel in Swift and builds a `CGImage`.
- Per-frame work is a few dozen sprites. Lots of headroom.

## Gotchas and shortcuts
- **Its own maths.** `skyPosition()` and the Moon phase duplicate what `SkyMath` does better (`Sky.sun`, `Sky.moon`, `Sky.moonPhase`). The Moon can be about 5° off, since it has no lunar inclination, and its lit side isn't mirrored for the southern hemisphere.
- **Clock versus Sun.** The hour for windows and traffic is the local clock, while the Sun uses location, so a viewer far from their time zone's centre gets slightly mismatched light and windows.
- **`dt` is clamped** to 0–0.1 s in `update`, because the render harness once fed wildly negative steps.
- **Snapshots** use the fallback location: 40°N at the time zone's standard meridian, so the Sun can be minutes to about half an hour off from the viewer's real one. Before the DST fix in Location.swift it was about an hour.
- **Keep it crisp:** motion must stay rounded to whole art pixels, and new textures must use `.nearest`.

## Dave's feedback and decisions
- It was built in the first batch of scenes ("build out all of those ideas"). Dave hasn't asked for changes yet.
- He wants every live scene to follow his real location and time. This one does, through the Sun's position, not just the clock.

## Ideas / next steps
- Switch to `SkyMath` for the Sun and Moon, and delete `skyPosition`.
- Weather tie-in: rain or snow from Weather's Open-Meteo conditions.
- Seasonal touches: holiday lights, snow on roofs.
- Settings: density, traffic, planes, palette (for example a neon or cyberpunk night).
- A second landmark, or a bridge.
- Reflections on a wet street.

## Checking it
- `SNAPSHOT_SCENE="Pixel City" swift test` renders the current time at the fallback location.
- **Particular times:** temporarily change `pixelCity(size:)` to `PixelCity(size: $0, at: <date>)`, render, and revert. The agent checked 12:30, 17:52 (dusk), 18:40, 23:30, 05:48 (dawn), 06:45 and 07:15.
- **Traffic and planes:** use `SNAPSHOT_SECONDS=30` or more, now that the harness runs `update(_:)` properly.
