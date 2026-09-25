# Weather

Green California hills and oak woodland, from a real photo, under whatever the weather is doing where the viewer is right now: clear, partly cloudy, overcast, fog, drizzle, rain, snow or a thunderstorm, by day or by night.

- **Files:** `Sources/Atrium/Weather.swift` holds the scene, its shaders, and the WMO code → `Kind` mapping with each kind's clouds, rain, snow and fog. `WeatherSky.swift` holds the physical sky (`Atmosphere`, `SkyCamera`, `SkyLight`) and `CloudNoise`. `Resources/weather-*` are its images, credited in `weather-credits.tsv`. It also uses `SkyMath.swift` (the Sun and Moon) and `Location.swift`; see [live-sky.md](live-sky.md). There's a test in `Tests/AtriumTests/WeatherTests.swift`.
- **Entry:** `weather(size:)` builds `final class WeatherScene: SKScene`, whose `init(size:conditions:)` is the test seam. Its entry in Scenes.swift is "Weather", icon `cloud.sun.fill`, tint `.blue`, with `WeatherScene.knobs`.
- **Kind:** a physical sky baked on the CPU into a small texture, then three shaders: the sky with its clouds, the ground photo relit, and rain or snow.

## How it works
- **`Conditions`** holds `code` (the WMO weather code), `cloudCover` (%), `wind` (km/h), `windFrom` (°), `highCloud` (%), `snowDepth` (m) and `visibility` (m). `kind` maps the code:
  - 0–1 clear, 3 overcast
  - 45 and 48 fog
  - 51–57 drizzle
  - 61–67 and 80–82 rain
  - 71–77, 85 and 86 snow
  - 95–99 storm
  - anything else partly cloudy

  `intensity` (0.35, 0.65 or 1) comes from the light, moderate and heavy variants of each code.
- **`build()`** throws everything away and rebuilds it for the current conditions: the sky, the ground, rain or snow, and lightning. It only runs when the weather changes, and then `redraw()` crossfades over 4 s from a snapshot of how the scene looked (`SKView.texture(from:)`). Day and night need no rebuild: the sky bakes every minute and eases between bakes.
  - **Sky:** a physical atmosphere, after Hillaire's "A Scalable and Production Ready Sky and Atmosphere Rendering Technique" (EGSR 2020): Rayleigh, Mie and ozone, single scattering plus his multiple-scattering approximation, lit by the real Sun and Moon where you are. Twilight, the Earth's shadow and the Belt of Venus come out of the physics; Preetham and Hosek–Wilkie can't do a Sun below the horizon.
    - `Atmosphere.shared` builds two lookup tables once (sunlight through the air, and multiple scattering), about 50 ms in a release build.
    - `SkyLight.bake` marches it for a 128×96 texture over the screen from 0.06 below the horizon to the top, about 4 ms in release across all cores, stored as sqrt(v/4) so values up to 4 near the Sun fit 8 bits. It also returns the colours of sunlight and skylight, all times an exposure.
    - **Exposure** is partial: 0.7·mean^−0.88·0.05^−0.12 of the mean sky luminance, so the picture darkens with the light but far less than the light does (brightness ∝ light^0.12). A 2e−7 floor stands in for airglow and starlight.
    - **Every minute** the scene bakes again off the main thread and crossfades into it over the next minute (`u_before`, `u_after`, `u_blend`), so twilight never steps. The first bake at build is synchronous.
    - **The view** (`SkyCamera`) is level, 64° across, with a shifted lens so the horizon is a straight line at 0.45 of the height, just under the photo's lowest skyline. It faces **today's sunset** (`sunsetAzimuth`, from the Sun's declination and your latitude; due west where the Sun doesn't set), so sunsets happen in front, and dawn lights the view from behind with the Belt of Venus over it.
    - **The shader** decodes the sky, adds the rest, then tone-maps like film: `sqrt(1 − exp(−col))`, and dithers. By night (the Sun 3° to 11° below) it first moves 60% toward a blue-shifted grey, the Purkinje shift, so moonlit clouds are silver rather than the beige of moonlight through the air.
  - **Stars:** two `starField` layers, faded in from a Sun 4° to 14° below the horizon, dimmed 60% by a bright Moon, thinned where the sky is brighter, and hidden unless it's clear or partly cloudy.
  - **Sun:** a limb-darkened disc 0.28° across with a soft glow, in the colour of sunlight through the air (reddening as it sets), shown down to 1° below the horizon.
  - **Moon:** NASA's LRO near side (`weather-moon.png`, from the CGI Moon Kit), 15 pt in radius (about 2.5× true), at its real place, lit from the real Sun with 1.5% earthshine, and turned so its north points to the celestial pole, as in Live Sky. It's tinted by moonlight through the air, and paler by day. `track()` moves the Sun and Moon every second, since a minute's step would be about the Sun's radius. The Moon also lights the sky as a second light at 2.5e−6·lit³ of the Sun.
  - **Ground:** a photo of Fort Ord National Monument (BLM California, public domain, 7379 px wide, shot on an overcast May morning, so there are no hard shadows to fight the real Sun) with the sky cut out, as `weather-ground.heic` (4096×1485 with alpha, 1.4 MB). `weather-ground-aux.png` (2048×743) holds its distance in red and its trees in green. Both are decoded once, statically.
    - **Distance** is log distance, 0 nearest to 1 at the far mountains (32 times further), estimated offline by a research agent with Apple's Core ML Depth Anything V2 Small over overlapping tiles, fitted to a whole-image pass and snapped to the ridgelines with a guided filter. The valley floor reads 0.38, the oak ridge 0.74. The shader turns it into `(32^d − 1)/3.1`, 0 to 10. The first version was a per-column ramp up to the skyline, which made fog a flat wash.
    - **Trees** are found as compact dark blobs (a black top-hat whose element shrinks with distance), so cloud shadows and shaded slopes aren't mistaken for woodland; a colour classifier flooded them. It's used soft: `1 − smoothstep(0.3, 0.7, tree)` is open ground.
    - It covers the bottom 56% of the screen, cropped at the bottom on wider screens so the sky keeps its share. The horizon is at 0.45, just under the lowest point of the skyline.
    - **Light:** the shader treats the photo's colours (squared, roughly linear) as lit by the overcast it was taken in, and multiplies by `u_light`: skylight plus the Sun's (or the Moon's) direct light on the slopes that face it, over 8. `direct()` is `0.55·z + 0.35·front·cos + 0.15`, where `front` is 1 with the light behind the viewer. Facing a low Sun we see the hills' shaded sides, so there's little; just after sunrise only some slopes catch it (×0.4). Under a deck of cloud the light is grey, even and half the day's (`cloudiness`), darker for thicker cloud, plus skyglow at night.
    - **Adapting:** the land's own light is compressed by its brightness (`^−0.38`), as an eye adapts. Physically correct numbers left the hills almost black facing a sunset, so even half a percent of haze from the glow swamped them.
    - **Night:** it dims by 60% more from a Sun 2° to 11° below the horizon, and fades toward blue-grey (the Purkinje shift) by moonlight. The exposure also dims 50% at night, so a moonlit night looks like night rather than a long exposure; tonight's full Moon lit it like a dull day before that.
    - **Haze:** each point fades toward the sky 0.03 above the horizon over its column, by `1 − exp(−0.05·distance)`. The low air is lit by the Sun less as it sinks (`u_hazeLit`, down to 25% after sunset, turning bluer), since near the ground it's in the Earth's shadow while the high sky still glows; without that the whole land glowed orange at dusk. Under a deck the haze takes the deck's grey (`u_deck`, twice as strongly as the sky's horizon does, since the low air under a storm is dark even where the far sky is clear).
    - **Backlit** (`u_backlit`: a Sun low and ahead, or its afterglow): the photo's far ridges are pale with its own haze, so they darken up to 50% with distance, into the layered silhouettes of real sunset photos (dark mauve, about (93,75,78), not glowing).
    - **Snow** on the ground and the **lightning** flash are described below.
    - **Valley mist** (`u_mist`): drifting patches in a band at the valley floor's distance (0.42 ± 0.09), so it lies between the near slopes and the ridges, as the depth map makes possible. It forms on still (under 12 km/h), clear or partly cloudy mornings from before dawn until the Sun is about 10° up, and lies there in fog (0.7) and after rain (0.3). Keying its noise to distance made it follow the contours like snowdrifts, so it's keyed to the screen instead.
    - The photo's own low clouds above the ridge were cleared from the cut (anything over 4 px above the skyline).
  - **Cumulus are photos** (`addPhotoClouds`): nine real clouds (eight cumulus and a tower) cut out of CC0 Poly Haven sky panoramas and a CC0 Commons photo by a research agent (keying out the sky, decontaminating the edges, `weather-cloud-*.heic`, 0.5 MB in all). Procedural cumulus came out as flat smears; the photos have real puffs and wisps. Five more cuts were dropped because their clouds ran into the photo's frame, and the straight edge showed at sunset even feathered.
    - **How many:** 3 + 7·cover when partly cloudy, 1–4 on a mainly clear day with some cover, and one in seven a far tower (cumulus congestus). Overcast, rain, snow and storms use the deck instead.
    - **Where:** each at a real place, 6–40 km away (more far than near) with its base 1.3–1.6 km up, so far clouds come out smaller and lower, and the ridge hides the farthest. Towers stand 26–40 km off with lower bases, so the ridge hides the bottom of their photos. Width is the cloud's real size (1–5 km) over its distance.
    - **Drift:** every frame with the real wind at 1.3× the 10 m speed. At 15 km/h a cloud 10 km off takes about 50 minutes to cross the view, which is calm and true. One that drifts out of view fades back in over 30 s on the upwind side.
    - **Light** (`photoCloudShaderSource`): the photo's brightness, from its 2nd to 98th percentile, maps from skylight to sunlight (`u_cloudAmb`, `u_cloudSun`), shadier toward the base. Raising that to a power made the puffs blotchy, so it stays linear. Near the Sun (`a_back`) the body darkens a little and the thin edges glow. Far clouds fade into the sky behind them (`a_far`, 1 − e^(−d/45 km)), and the night shift applies. The faint veil of sky the cut leaves (alpha under 0.2) is clipped, since it glowed as a rectangle at sunset.
  - **Clouds:** one flat layer in the sky shader, seen through the camera, so it shrinks and flattens toward the horizon (after the research prototype's "FLAT" variant). `Conditions.clouds` sets its cover, base and thickness in km, and how flat a sheet it is (`deck`: 0 heaped cumulus, 1 featureless), after the cloud each kind comes from: stratocumulus (overcast), stratus (drizzle), nimbostratus (rain, snow), cumulonimbus (storm), and a thin bright layer at 0.3 km for fog.
    - **Shape:** `cloudShape` from two lookups of `CloudNoise` (baked once: 257² tileable value-noise fbm, Worley billows, fine fbm and a warp channel). Baked noise costs about a fifth of computed fbm. It drifts with the wind (`u_wind`, km/s, across the view and a little away) and evolves slowly.
    - **Light:** three looks at the density (here, a little further along the ray for top edges, and toward the Sun for shadow), then: grey bases about as bright as the sky beside them, white sunlit tops, dark sides with bright rims toward the Sun (Henyey–Greenstein forward scattering). A deck is opaque (or the Sun's glow shows through as an orange column), and darker the thicker it is (`exp(−0.6·(thickness − 1))`), down to a storm's slate. By day a deck is brighter overhead than at the horizon (the CIE overcast sky, `0.75 + 1.2·z`) and faintly blue. Its underside is lumpy: rolls of thicker cloud between thinner, brighter gaps.
    - **The horizon under a deck** (`u_deck`: the underside's colour, and how much it replaces the clear sky's): distant cloud fades into it, and so do the ground's haze and fog. Using the clear sky's horizon there made fog whiter than the grey sky above it, and turned a stormy sunset's hills pink.
    - **Skyglow:** at night low cloud glows faintly orange-grey, like the lights of towns beneath it, so a rainy night isn't black.
    - **Cirrus** at 8 km: fine streaks along the wind, lit pink after sunset down here, on clear and partly cloudy days, from `cloud_cover_high`.
    - On clear and partly cloudy days the layer has no cover; the cumulus are photos.
  - **Fog** (`u_fog`: 0.75 for fog, 0.25 drizzle, 0.1–0.25 rain and storm, 0.15–0.35 snow): grey-white whatever the sky's colour, since it's optically thick. On the ground it swallows the far hills first (`1 − exp(−0.45·distance·u_fog)`); in the sky it rises from the horizon, over the whole sky in real fog.
  - **Rain and snow:** one full-screen shader over everything (`addPrecipitation`). Rain is four depths of streaks sheared by the wind, the far layers fine and dense, the near ones long, soft and sparse. Snow is five depths of flakes swaying down, the near ones up to 6 pt and out of focus, each kept inside its cell so it's never clipped square. Both take the light around them, so like real rain they show against the hills but hardly against the sky. They run on `u_clock`, which wraps hourly, since `u_time` grows with uptime and at 700 pt/s a float that large loses the streaks.
  - **Lightning** (storm), after the research into real flashes: every 15–45 s for code 95, 8–25 s for 96 and 99, from an SKAction so it pauses while hidden. Never a full-screen white flash.
    - **Strokes:** one to four return strokes at 0, 60, 130 and 220 ms (±10 ms), peaks 1, 0.7, 0.9 and 0.5, each decaying in 30 ms, plus a 0.08 glow of continuing current for 0.35 s (NOAA JetStream). At 30 fps each stroke lasts a frame or two, which reads right. `update(_:)` feeds the brightness to `u_flash`.
    - **In the cloud:** the sky shader lights the cloud around `u_flashPos`, brightest in medium-thick cloud and broken up by the cloud's own lumps; a round glow looked like a lamp behind paper. The hills get a faint blue-white lift.
    - **Bolts:** three in ten near flashes show one, drawn fresh each time by midpoint displacement with forks (after Reed & Wyvill 1994): a violet glow, a paler halo and a white core, faded out at the top where it leaves the cloud. It's added between the sky and the hills, which hide its foot.
    - **Far flashes:** a quarter light the horizon widely, with no bolt, like sheet lightning.
- **Motion:** `update(_:)` eases the sky crossfade, moves the Sun and Moon each second, starts a sky bake each minute, and advances `u_clock`. `dt` is clamped to 0–0.1 s; the render harness produced huge negative values before its fix.

## Time, live data and appearance
- **Weather source:** Open-Meteo (`https://api.open-meteo.com/v1/forecast?latitude=…&longitude=…&current=weather_code,cloud_cover,cloud_cover_high,wind_speed_10m,wind_direction_10m,snow_depth,visibility`). It's free and needs no key, and is for non-commercial use.
  - `wind_direction_10m` (where it blows from) sets which way clouds drift and rain and snow lean (`windToward`).
  - `snow_depth` lays snow on the ground (`snowCover`: a dusting at 1 cm, white by 5 cm), whether or not it's snowing now. The open grass turns white, shaded by the photo's own light and shade so the hills keep their form; the oaks (the aux texture's green) darken, lose colour and catch snow on their brighter parts.
  - `cloud_cover_high` sets the cirrus; `visibility` sets how thick fog is (0.9 at 100 m, 0.4 at 1 km).
  - The extras are optional in the decoder, since not every weather model has them.
  - It's polled 2 s after `didMove`, to give a remembered location fix a moment to land, then every 15 min, from an SKAction keyed "poll". Polling stops while the wallpaper is hidden.
  - A new build only happens if the conditions actually changed, and it crossfades.
- **Parsing:** `WeatherScene.conditions(from:)` uses explicit `CodingKeys`. It returns nil on any decode failure, and the scene keeps showing what it has.
- **Day and night** come from the real Sun and Moon where you are, through the physical sky, so they're right before the first fetch and offline. `is_day` isn't requested.
- **Offline default:** `Conditions()` is code 2 (partly cloudy), 40% cover, a 10 km/h west wind.
- **Location:** `Location.shared.start()` is called in `didMove`; see [live-sky.md](live-sky.md) for the fallback.
- **Appearance:** it ignores Light/Dark Mode. Night follows the Sun instead: moonlit and dim, or under cloud a low ceiling faintly lit by towns.

## Checked against real photos
A research agent sampled 94 reference photos (Wikimedia Commons) across 18 states, averaging patches in linear light (its folder: `scratchpad/weather/reference/`, with `curated.json`). The renders were sampled in the same places and compared, 2026-09-25:

| State | Sky top, mine / photos | Notes |
|---|---|---|
| Clear noon | (107,148,195) / (111,147,198) | a near match straight out of the physics |
| Overcast | (176,177,184) / (194,199,205) | was (153,153,158) and flat: brightened by day, faintly blue, brighter overhead than at the horizon (the CIE overcast sky) |
| Drizzle | (183,183,190) / (195,201,209) | was (141,140,145); a thinner deck |
| Rain | (144,146,152) / (137,147,161) | |
| Storm | (115,118,124) / (94–107,107–124) | darker than rain, with a lighter horizon beyond it |
| Moonlit night | (25,32,43) / (20,32,58) | was grey; bluer by the Purkinje shift |

What changed from it:
- **Sunset and dusk:** real far ridges are dark mauve silhouettes (93,75,78), not glowing. The low air is lit by weak, reddened sunlight, so the ground's haze dims with the Sun's height (`u_hazeLit`) and turns bluer after sunset, and when the land is backlit (`u_backlit`) the photo's pale far ridges darken with distance.
- **Rain slants at atan(wind ÷ fall speed)**, about 7 m/s for raindrops: 30° in a 15 km/h wind blowing across. It was 5–10°.
- **Lightning-lit cloud** is mauve in photos (#b3a0a8), not blue-white.
- **Under a storm** the sky's horizon keeps some of the clear sky beyond it, but the ground's haze takes the storm's grey (`under`).
- The reference's greens and cloud colours were for the old painted palette; the photo ground and the physical sky replaced both.

## Settings
- **Preview** (`weather.preview`, `weather.previewKind`, `weather.previewHour`): a switch, a menu of the eight kinds (Clear, Partly cloudy, Overcast, Fog, Drizzle, Rain, Snow, Thunderstorm) and a time of day. While it's on, the scene draws that instead of the live weather, with the sky, Sun and Moon at that time today (moving the time bakes the sky again at once). Each kind stands in as one code (0, 2, 3, 45, 53, 63, 73, 95) with a 15 km/h wind from 250°, 12 cm of snow on the ground for Snow, and 400 m visibility for Fog. The scene keeps polling underneath, so switching it off goes straight back to the live weather.
- `report` holds the latest live weather and `conditions` what's drawn; `redraw()` rebuilds only when the two differ, so any other change to UserDefaults costs nothing.

## Tuning constants
- **Clouds:** `Conditions.clouds`, per kind. The deck drifts at `wind/3600·0.6` km/s, the photo cumulus at `wind/3600·1.3`.
- **Rain:** lean `across·min(wind m/s ÷ 7, 1)`; layers fall at 700–1750 pt/s.
- **Snow:** layers fall at 18–74 pt/s, drifting with the wind.
- **Ground:** covers the bottom 56% of the screen; horizon at 0.45; lit by `sunlit / 8`, compressed `^−0.38`.
- **Exposure:** `0.7·mean^−0.88·0.05^−0.12`, halved at night.

## Performance
- Release build, 2x, 1512×982, measured 2026-09-25: about 0.5 ms CPU in every state. GPU 0.45–0.7 ms for clear, cloudy, fog and twilight, 0.85 ms for rain and storms, 1.2–1.3 ms for snow (five flake layers; the first cut would be making the nearest layers an emitter).
- The sky bake is 4 ms a minute, off the main thread. The first build also makes the atmosphere tables and cloud noise and decodes the photo, about 200 ms once per launch; later builds take about 4 ms.
- Memory: the ground photo is 24 MB as a texture (4096×1485), the rest is small.

## Gotchas and shortcuts
- **The decoding bug that hid everything.** `.convertFromSnakeCase` turns `wind_speed_10m` into `windSpeed10M`, so every reply failed to decode silently. The scene sat on its default of a partly cloudy day, even at night. The fix is explicit `CodingKeys`, and `parsesOpenMeteo()` in WeatherTests parses a real reply to keep it fixed.
- **SKShader can't return early from `main()`**: the Metal translation needs a value on every path, so it fails to compile. Use if/else.
- **`u_time` grows with uptime**, so fast motion (rain at 700+ pt/s) loses precision in a float; rain and snow run on `u_clock`, which wraps hourly and so reshuffles them once an hour.
- **Physically right isn't always right on screen.** Facing a sunset the hills came out almost black, and a full Moon made night look like a dull day. Both needed the eye's adaptation added back (ground compression, night dimming).

## Dave's feedback and decisions
- **The real time of day.** "If the weather one is supposed to be showing my real time weather then it should also be using my real time time of day." It showed a daytime partly cloudy sky at night. That led to finding the decoding bug, and to moving day and night onto the real Sun.
- **After the fix** he said it was "looking much better now".
- **The high-fidelity pass** (2026-09-25): "Give it the same level of treatment we gave galaxy, nebula, and fish tank. Do in depth research, gather assets and resources needed to make that scene visually look a lot nicer without too much impact to performance." Three research agents ran: rendering techniques (prototyping a physical sky, procedural ridges and clouds), reference photos and colours, and photo assets. Where they disagreed (procedural ridges against a photo ground) the renders settled it: the photo read as a photograph by day, and graded as backlit it held up at sunset too, so the physical sky and the photo ground were combined.

## Ideas / next steps
- An optional temperature readout with a °F/°C setting, which Dave was offered.
- Seasonal ground colour: Fort Ord's grass is golden from June to November while the oaks stay green; the tree mask could drive it by month and hemisphere.
- A rainbow when it's showering with the Sun low behind the view (the research has the geometry: 42° around the antisolar point, red outside, a fainter reversed bow at 51°).
- Cloud shadows drifting over the hills, and far rain shafts under showers.
- Backlit photo clouds near the Sun; the cutter couldn't separate them from the glare.

## Checking it
- `SNAPSHOT_SCENE="Weather" swift test` renders the offline default: partly cloudy, at this moment where you are.
- **Every state:** `SNAPSHOT_DEFAULTS="weather.preview=1,weather.previewKind=6,weather.previewHour=22" SNAPSHOT_SCENE=Weather swift test` renders a snowy night. The kind is an index: 0 clear, 1 partly cloudy, 2 overcast, 3 fog, 4 drizzle, 5 rain, 6 snow, 7 storm. For exact codes, cloud cover or wind, pass `conditions:` to `WeatherScene(size:conditions:)` from a test.
- `swift test --filter parsesOpenMeteo`.
- **Live check:** `curl "https://api.open-meteo.com/v1/forecast?latitude=40.0&longitude=-90.0&current=weather_code,cloud_cover,cloud_cover_high,wind_speed_10m,wind_direction_10m,snow_depth,visibility"`.
