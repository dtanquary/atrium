# Weather

Green California hills and oak woodland, from a real photo, under whatever the weather is doing where the viewer is right now: clear, partly cloudy, overcast, fog, drizzle, rain, snow or a thunderstorm, by day or by night.

- **Files:** `Sources/Atrium/Weather.swift` holds the scene, the WMO code → `Kind` mapping, `Palette`, and a seeded random number generator. `WeatherSky.swift` holds the physical sky: `Atmosphere`, `SkyCamera` and `SkyLight`. `Resources/weather-*` are its images, credited in `weather-credits.tsv`. It also uses `SkyMath.swift` (for whether the Sun is up) and `Location.swift`; see [live-sky.md](live-sky.md). There's a test in `Tests/AtriumTests/WeatherTests.swift`.
- **Entry:** `weather(size:)` builds `final class WeatherScene: SKScene`, whose `init(size:conditions:)` is the test seam. Its entry in Scenes.swift is "Weather", icon `cloud.sun.fill`, tint `.blue`, with `WeatherScene.knobs`.
- **Kind:** a physical sky baked on the CPU into a small texture, then three shaders: the sky with its clouds, the ground photo relit, and rain or snow.

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
  - **Sky:** a physical atmosphere, after Hillaire's "A Scalable and Production Ready Sky and Atmosphere Rendering Technique" (EGSR 2020): Rayleigh, Mie and ozone, single scattering plus his multiple-scattering approximation, lit by the real Sun and Moon where you are. Twilight, the Earth's shadow and the Belt of Venus come out of the physics; Preetham and Hosek–Wilkie can't do a Sun below the horizon.
    - `Atmosphere.shared` builds two lookup tables once (sunlight through the air, and multiple scattering), about 50 ms in a release build.
    - `SkyLight.bake` marches it for a 128×96 texture over the screen from 0.06 below the horizon to the top, about 20 ms, stored as sqrt(v/4) so values up to 4 near the Sun fit 8 bits. It also returns the colours of sunlight and skylight, all times an exposure.
    - **Exposure** is partial: 0.7·mean^−0.88·0.05^−0.12 of the mean sky luminance, so the picture darkens with the light but far less than the light does (brightness ∝ light^0.12). A 2e−7 floor stands in for airglow and starlight.
    - **Every minute** the scene bakes again off the main thread and crossfades into it over the next minute (`u_before`, `u_after`, `u_blend`), so twilight never steps. The first bake at build is synchronous.
    - **The view** (`SkyCamera`) is level, 64° across, with a shifted lens so the horizon is a straight line at 0.4 of the height. It faces **today's sunset** (`sunsetAzimuth`, from the Sun's declination and your latitude; due west where the Sun doesn't set), so sunsets happen in front, and dawn lights the view from behind with the Belt of Venus over it.
    - **The shader** decodes the sky, adds the rest, then tone-maps like film: `sqrt(1 − exp(−col))`, and dithers.
  - **Stars:** two `starField` layers, faded in from a Sun 4° to 14° below the horizon, dimmed 60% by a bright Moon, thinned where the sky is brighter, and hidden unless it's clear or partly cloudy.
  - **Sun:** a limb-darkened disc 0.28° across with a soft glow, in the colour of sunlight through the air (reddening as it sets), shown down to 1° below the horizon.
  - **Moon:** NASA's LRO near side (`weather-moon.png`, from the CGI Moon Kit), 15 pt in radius (about 2.5× true), at its real place, lit from the real Sun with 1.5% earthshine, and turned so its north points to the celestial pole, as in Live Sky. It's tinted by moonlight through the air, and paler by day. `track()` moves the Sun and Moon every second, since a minute's step would be about the Sun's radius. The Moon also lights the sky as a second light at 2.5e−6·lit³ of the Sun.
  - **Clouds:** one flat layer in the sky shader, seen through the camera, so it shrinks and flattens toward the horizon (after the research prototype's "FLAT" variant). `Conditions.clouds` sets its cover, base and thickness in km, and how flat a sheet it is (`deck`: 0 heaped cumulus, 1 featureless), after the cloud each kind comes from: fair-weather cumulus (partly cloudy), stratocumulus (overcast), stratus (drizzle), nimbostratus (rain, snow), cumulonimbus (storm), and a thin bright layer at 0.3 km for fog.
    - **Shape:** `cloudShape` from two lookups of `CloudNoise` (baked once: 257² tileable value-noise fbm, Worley billows, fine fbm and a warp channel). Baked noise costs about a fifth of computed fbm. It drifts with the wind (`u_wind`, km/s, across the view and a little away) and evolves slowly.
    - **Light:** three looks at the density (here, a little further along the ray for top edges, and toward the Sun for shadow), then: grey bases about as bright as the sky beside them, white sunlit tops, dark sides with bright rims toward the Sun (Henyey–Greenstein forward scattering). A deck is opaque (or the Sun's glow shows through as an orange column), and darker the thicker it is (`exp(−0.5·(thickness − 1))`), down to a storm's slate. Its underside is lumpy: rolls of thicker cloud between thinner, brighter gaps.
    - **The horizon under a deck** (`u_deck`: the underside's colour, and how much it replaces the clear sky's): distant cloud fades into it, and so do the ground's haze and fog. Using the clear sky's horizon there made fog whiter than the grey sky above it, and turned a stormy sunset's hills pink.
    - **Skyglow:** at night low cloud glows faintly orange-grey, like the lights of towns beneath it, so a rainy night isn't black.
    - **Cirrus** at 8 km: fine streaks along the wind, lit pink after sunset down here, on clear and partly cloudy days.
  - **Fog** (`u_fog`: 0.75 for fog, 0.25 drizzle, 0.1–0.25 rain and storm, 0.15–0.35 snow): grey-white whatever the sky's colour, since it's optically thick. On the ground it swallows the far hills first (`1 − exp(−distance·u_fog)`); in the sky it rises from the horizon, over the whole sky in real fog.
  - **Rain and snow:** one full-screen shader over everything (`addPrecipitation`). Rain is four depths of streaks sheared by the wind, the far layers fine and dense, the near ones long, soft and sparse. Snow is five depths of flakes swaying down, the near ones up to 6 pt and out of focus, each kept inside its cell so it's never clipped square. Both take the light around them, so like real rain they show against the hills but hardly against the sky. They run on `u_clock`, which wraps hourly, since `u_time` grows with uptime and at 700 pt/s a float that large loses the streaks.
  - **Lightning** (storm): still the old jagged `SKShapeNode` bolt and double flash, every 4–14 s.
- **Motion:** `update(_:)` eases the sky crossfade, moves the Sun and Moon each second, starts a sky bake each minute, and advances `u_clock`. `dt` is clamped to 0–0.1 s; the render harness produced huge negative values before its fix.

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
- **Preview** (`weather.preview`, `weather.previewKind`, `weather.previewHour`): a switch, a menu of the eight kinds (Clear, Partly cloudy, Overcast, Fog, Drizzle, Rain, Snow, Thunderstorm) and a time of day. While it's on, the scene draws that instead of the live weather, with day or night from the Sun at that time today. Each kind stands in as one code (0, 2, 3, 45, 53, 63, 73, 95) with 15 km/h of wind. The scene keeps polling underneath, so switching it off goes straight back to the live weather.
- `report` holds the latest live weather and `conditions` what's drawn; `redraw()` rebuilds only when the two differ, so any other change to UserDefaults costs nothing.

## Tuning constants
- **Clouds:** `Conditions.clouds`, per kind. Drift is `wind/3600·0.6` km/s.
- **Rain:** lean `min(wind/50, 1)·0.35`; layers fall at 700–1750 pt/s.
- **Snow:** layers fall at 18–74 pt/s, drifting with the wind.
- **Lightning:** flashes at alpha 0.5, then 0.08, then 0.35, then fade.
- **Hills:** the landscape texture covers the bottom 46% of the screen; the tree count scales with width (`w/55` in the middle range, `w/160` in front).

## Performance
- About 0.42 ms CPU and 0.18 ms GPU per frame (release build, 2x, 1512×982). Emitters and a few dozen sprites; nothing heavy per frame.
- A rebuild repaints the landscape, about a 3024×900 px texture, roughly 10 MB. That's cheap enough when the weather changes or at sunrise and sunset.

## Gotchas and shortcuts
- **The decoding bug that hid everything.** `.convertFromSnakeCase` turns `wind_speed_10m` into `windSpeed10M`, so every reply failed to decode silently. The scene sat on its default of a partly cloudy day, even at night. The fix is explicit `CodingKeys`, and `parsesOpenMeteo()` in WeatherTests parses a real reply to keep it fixed.
- **`is_day` isn't requested any more.** Day or night comes from `sunIsUp()`.
- `ponytail:` **the wind always blows left to right.** `wind_direction_10m` would fix that.
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
- **Every state:** `SNAPSHOT_DEFAULTS="weather.preview=1,weather.previewKind=6,weather.previewHour=22" SNAPSHOT_SCENE=Weather swift test` renders a snowy night. The kind is an index: 0 clear, 1 partly cloudy, 2 overcast, 3 fog, 4 drizzle, 5 rain, 6 snow, 7 storm. For exact codes, cloud cover or wind, pass `conditions:` to `WeatherScene(size:conditions:)` from a test.
- `swift test --filter parsesOpenMeteo`.
- **Live check:** `curl "https://api.open-meteo.com/v1/forecast?latitude=40.0&longitude=-90.0&current=weather_code,cloud_cover,wind_speed_10m"`.
