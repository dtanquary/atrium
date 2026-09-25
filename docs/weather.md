# Weather

Three ranges of rolling hills with pines and round trees, under whatever the weather is doing where the viewer is right now: clear, partly cloudy, overcast, fog, drizzle, rain, snow or a thunderstorm, by day or by night.

- **Files:** `Sources/Atrium/Weather.swift`. It holds the scene, the WMO code → `Kind` mapping, `Palette`, and a seeded random number generator. It also uses `SkyMath.swift` (for whether the Sun is up) and `Location.swift`; see [live-sky.md](live-sky.md). There's a test in `Tests/AtriumTests/WeatherTests.swift`.
- **Entry:** `weather(size:)` builds `final class WeatherScene: SKScene`, whose `init(size:conditions:)` is the test seam. Its entry in Scenes.swift is "Weather", icon `cloud.sun.fill`, tint `.blue`, with no settings.
- **Kind:** SpriteKit nodes and Core Graphics textures: a gradient sky, painted clouds and hills, and emitters for rain and snow.

## How it works
- **`Conditions`** holds `code` (the WMO weather code), `isDay`, `cloudCover` (%) and `wind` (km/h). `kind` maps the code:
  - 0–1 clear, 3 overcast
  - 45 and 48 fog
  - 51–57 drizzle
  - 61–67 and 80–82 rain
  - 71–77, 85 and 86 snow
  - 95–99 storm
  - anything else partly cloudy

  `intensity` (0.35, 0.65 or 1) comes from the light, moderate and heavy variants of each code.
- **`build()`** throws everything away and rebuilds it for the current conditions. Nothing crossfades.
  - **Sky:** a two-stop vertical gradient from the `Palette`.
  - **Stars:** at night when it's clear (220) or partly cloudy (130); one in eight twinkles.
  - **Sun:** by day, a painted disc with a glow at a fixed spot (0.78 w, 0.8 h), faded to 25% behind cloud or fog.
  - **Moon:** at night, at a fixed spot (0.22 w, 0.8 h). Its phase comes from a mean synodic month (`moonTexture()`), lit on the right while waxing.
  - **Clouds:** painted cumulus (overlapping ellipses, flat base, shaded underside), in three variants per build. When it's grey (overcast, drizzle, rain, snow, storm) there's a full deck of 16 big clouds; otherwise `cloudCover/10` wisps. Bigger clouds sit in front and drift faster.
  - **Hills:** `landscape()` paints three ranges into one texture, hazier with distance, with pines and round trees. It uses `Seeded(state: 11)`, so the hills and trees are the same on every rebuild. In snow the trees are all pines with snowy tips.
  - **Fog:** a vertical haze gradient, plus 5 drifting banks of mist at full density. Rain and snow get a thinner haze.
  - **Rain:** an `SKEmitterNode` of 2×26 streaks. The lean is `min(wind/50, 1)·0.45` rad, and the rate goes 90 (drizzle), then 200–500 (rain), then 550 (storm). `advanceSimulationTime` makes it already raining when it appears.
  - **Snow:** an emitter with `xAcceleration` from the wind and a sway `particleAction`.
  - **Lightning** (storm): a jagged `SKShapeNode` bolt behind the hills plus a double flash across the screen, every 4–14 s (`wait 9 ± 5`).
- **Motion:** in `update(_:)`, clouds and mist banks drift right at their own speed and wrap around. `dt` is clamped to 0–0.1 s; the render harness produced huge negative values before its fix.

## Time, live data and appearance
- **Weather source:** Open-Meteo (`https://api.open-meteo.com/v1/forecast?latitude=…&longitude=…&current=weather_code,cloud_cover,wind_speed_10m`). It's free and needs no key, and is for non-commercial use.
  - It's polled 2 s after `didMove`, to give a remembered location fix a moment to land, then every 15 min, from an SKAction keyed "poll". Polling stops while the wallpaper is hidden.
  - A new build only happens if the conditions actually changed.
- **Parsing:** `WeatherScene.conditions(from:)` uses explicit `CodingKeys`. It returns nil on any decode failure, and the scene keeps showing what it has.
- **Day or night** comes from the real Sun, not the API. `sunIsUp()` checks whether the Sun is above −0.833° (its top edge, allowing for refraction) at `Location.shared` with `Sky.sun`. It's checked at init, on every fetch, and every 60 s by its own action, which rebuilds on a flip. So it's right before the first fetch, offline, and within a minute of sunrise or sunset.
- **Offline default:** `Conditions()` is code 2 (partly cloudy) with `isDay` from the Sun.
- **Location:** `Location.shared.start()` is called in `didMove`; see [live-sky.md](live-sky.md) for the fallback.
- **Appearance:** it ignores Light/Dark Mode. The night palette follows the Sun instead: moonlit blues, and for cloudy nights a low, dim ceiling.

## Settings
None yet.

## Tuning constants
- **Clouds:** 340×140 pt base size; scale 1.3–2.1 in a full deck, 0.8–1.5 otherwise; drift speed `(4 + 0.5·wind)·scale`.
- **Rain:** lean `wind/50·0.45` rad; alpha 0.45 by day, 0.3 at night; speeds 520, 900 and 1000.
- **Snow:** speed 55 ± 30; scale 0.6 ± 0.5; sway 14 pt over 1.4 s.
- **Fog:** 5 banks at 5–12 pt/s.
- **Lightning:** flashes at alpha 0.5, then 0.08, then 0.35, then fade.
- **Hills:** the landscape texture covers the bottom 46% of the screen; the tree count scales with width (`w/55` in the middle range, `w/160` in front).

## Performance
- About 0.42 ms CPU and 0.18 ms GPU per frame (release build, 2x, 1512×982). Emitters and a few dozen sprites; nothing heavy per frame.
- A rebuild repaints the landscape, about a 3024×900 px texture, roughly 10 MB. That's cheap enough when the weather changes or at sunrise and sunset.

## Gotchas and shortcuts
- **The decoding bug that hid everything.** `.convertFromSnakeCase` turns `wind_speed_10m` into `windSpeed10M`, so every reply failed to decode silently. The scene sat on its default of a partly cloudy day, even at night. The fix is explicit `CodingKeys`, and `parsesOpenMeteo()` in WeatherTests parses a real reply to keep it fixed.
- **`is_day` isn't requested any more.** Day or night comes from `sunIsUp()`.
- `ponytail:` **the wind always blows left to right.** `wind_direction_10m` would fix that.
- **Fixed positions.** The Sun and Moon sit at fixed screen spots, not their real sky positions. The Moon's phase is a mean-month approximation, not `Sky.moonPhase`, and it isn't mirrored for the southern hemisphere.
- **No crossfade.** A weather change or a sunrise/sunset flip replaces the scene's content instantly.

## Dave's feedback and decisions
- **The real time of day.** "If the weather one is supposed to be showing my real time weather then it should also be using my real time time of day." It showed a daytime partly cloudy sky at night. That led to finding the decoding bug, and to moving day and night onto the real Sun.
- **After the fix** he said it was "looking much better now".

## Ideas / next steps
- Use `Sky.sun`, `Sky.moon` and `Sky.moonPhase` to place and light the Sun and Moon properly.
- Sunrise and sunset colours in between day and night, with a crossfade between states.
- Wind direction.
- An optional temperature readout with a °F/°C setting, which Dave was offered.
- Seasonal ground colour and leaves.
- Rain puddles and splashes.

## Checking it
- `SNAPSHOT_SCENE="Weather" swift test` renders the offline default: partly cloudy, day or night from the fallback location.
- **Every state:** temporarily point `weather(size:)` at `WeatherScene(size: $0, conditions: .init(code: 95, isDay: false, cloudCover: 100, wind: 30))`. Useful codes are 0 clear, 3 overcast, 45 fog, 61/63/65 rain, 73 snow and 95 storm. Render, look, and revert. `SNAPSHOT_DEFAULTS` can't set conditions.
- `swift test --filter parsesOpenMeteo`.
- **Live check:** `curl "https://api.open-meteo.com/v1/forecast?latitude=40.0&longitude=-90.0&current=weather_code,cloud_cover,wind_speed_10m"`.
