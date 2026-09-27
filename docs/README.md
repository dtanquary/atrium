# Wallpaper docs

One file per wallpaper, recording what the code can't: how each scene works, why it's built the way it is, its settings, cost, shortcuts, Dave's feedback, and ideas for next steps. Read the scene's doc before changing it, and update the doc in the same commit as the change. The app, commands and conventions are in `../CLAUDE.md`.

## Wallpapers

| Wallpaper | Doc | Source | Kind | Settings | Live data | CPU / GPU ms* |
|---|---|---|---|---|---|---|
| Fish Tank | [fish-tank.md](fish-tank.md) | `FishTank.swift`, `FishTankArt.swift`, `Resources/reef-*` | photo cut-outs and shaders | none yet | none | 0.85 / 1.4 |
| Flowing Gradient | [flowing-gradient.md](flowing-gradient.md) | `FlowingGradient.swift` | shader | knobs, 6 palettes, colour cycle | Sun position | 0.47 / 0.55 |
| Lava Lamp | [lava-lamp.md](lava-lamp.md) | `LavaLamp.swift` | shader, blob layout in Swift | knobs, 7 palettes, colour cycle | none | 0.5 / 1.0 |
| Rain on Glass | [rain-on-glass.md](rain-on-glass.md) | `RainOnGlass.swift`, `Resources/rain-*` | baked photo backdrops or procedural bokeh, shader water | 10 photo backdrops, 7 palettes, fade on Random, drip speed, knobs | none | 0.55 / 0.9–1.7 |
| Aurora | [aurora.md](aurora.md) | `Aurora.swift`, `Resources/aurora-*` | perspective shader sky, photo ground lit by it | knobs, 8 palettes, speed, colour fade | none | 0.6 / 1.0–1.45 |
| Nebula | [nebula.md](nebula.md) | `Shaders.swift` | shader | knobs, 7 palettes, change interval | none | 0.45 / 1.6 |
| Galaxy | [galaxy.md](galaxy.md) | `Galaxy.swift` | shader | knobs, 6 real galaxies | none | 0.5 / 1.5–2.1 |
| Live Sky | [live-sky.md](live-sky.md) | `LiveSky.swift`, `SkyMath.swift` | SpriteKit and shaders | switches, preview | location, ISS | 0.64 / 0.90 |
| The Moon | [the-moon.md](the-moon.md) | `TheMoon.swift`, `Resources/moon-*` | LRO maps lit by a shader, baked once a minute | Black, Stars or Sky backdrop, size, brightness, earthshine, preview | location | 0.43 / 0.08–0.19 |
| Earth from Orbit | [earth-from-orbit.md](earth-from-orbit.md) | `EarthFromOrbit.swift`, `ISS.swift`, `Clouds.swift`, `Storms.swift` | shader | ISS, clouds, lightning switches | location, ISS, clouds, storms | 0.45 / 0.31 |
| Weather | [weather.md](weather.md) | `Weather.swift`, `WeatherSky.swift`, `Resources/weather-*` | physical sky, photo ground and clouds, shaders | weather lock, time preview | location, Open-Meteo | 0.55 / 0.45–1.2 |
| Pixel City | [pixel-city.md](pixel-city.md) | `PixelCity.swift` | SpriteKit (pixel canvas) | none yet | location, clock | 0.43 / 0.18 |
| Fireflies | [fireflies.md](fireflies.md) | `Fireflies.swift`, `Resources/fireflies-*` | photo ground, shaders, SpriteKit | density, fog, speed, wind | none | 0.54 / 0.52 |
| Murmuration | [murmuration.md](murmuration.md) | `Murmuration.swift`, `Resources/murmuration-*` | StarDisplay flock in metres, physical sky, photo ground with reflecting water | light (or a whole evening), ground, falcon | none | 1.25–1.8 / 0.45–0.8 |
| Campfire | [campfire.md](campfire.md) | `Campfire.swift`, `CampfireFlames.swift`, `Resources/campfire-*` | photo ground relit by the fire, fluid-sim flames, shaders | none | location (real stars) | 1.11 / 0.84 |
| Game of Life | [game-of-life.md](game-of-life.md) | `GameOfLife.swift` | mutable texture | Calm or Classic, speed, exposure, softness | none | 0.55 / 0.36 |
| Turing Patterns | [turing-patterns.md](turing-patterns.md) | `TuringPatterns.swift` | CPU reaction–diffusion, lit by a shader | pattern (or Drift), motion (Regrow, Flow, Still), speed, 6 palettes | none | 0.9–1.35 / 0.3–0.75 |
| The Sun Today | [sun.md](sun.md) | `Sun.swift` | downloaded SDO images, one shader | 8 wavelengths, shimmer or time-lapse, whole or close-up, Look | SDO via Helioviewer | 0.43–0.52 / 0.38–0.58 |
| Crystals | [crystals.md](crystals.md) | `Crystals.swift` | growth baked in Swift, revealed and coloured by a shader (Michel-Lévy chart) | cycle length, crystal size, thickness, brightness, field stop | none | 0.6 / 0.5–0.9 |
| Wind | [wind.md](wind.md) | `Wind.swift`, `Resources/wind-*` | stateless streaks in one shader (a take on OLIC) over a Natural Earth map | zoom, background, comets or brush strokes, speed, streak length, density, 6 palettes | location, Open-Meteo wind grid | 0.45–0.6 / 1.6 |
| Dappled Light | [dappled-light.md](dappled-light.md) | `DappledLight.swift`, `Resources/dappled-*` | one shader: pinhole images of the Sun, leaf layers baked from real scans, photo plaster | wall facing, leaf cover, near twig, weather lock, moonlight or streetlight, sway, time and eclipse previews | location, Sun and Moon, Open-Meteo | 0.41–0.54 / 0.57–0.99 |

\*Release build, 2x Retina at 1512×982 points, measured 2026-09-24 with `swift test -c release -Xswiftc -enable-testing`. The budget is about 2 ms each for CPU and GPU. Debug builds are pessimistic on CPU (Murmuration runs about 16–19 ms in debug).

## Screenshots

The README's screenshots live in `docs/images` as 1600-pixel JPEGs of the wallpaper alone. The first seven were captured live from the wallpaper window. Galaxy, Fish Tank, Nebula Oxygen and Weather (2026-09-25) were rendered offscreen by the snapshot test at 2x Retina, which is the same pixels without switching the desktop or touching settings. For example: `SNAPSHOT_DEFAULTS="galaxy.kind=Whirlpool" SNAPSHOT_SCENE=Galaxy swift test -c release -Xswiftc -enable-testing`, with `SNAPSHOT_APPEARANCE=light|dark` for the two looks. Each was picked from three or four random rolls. Add or refresh one whenever a wallpaper's look changes. Settings shows one of them behind the top of each wallpaper's page: a 1200-pixel copy in `Sources/Atrium/Resources/preview-<name>.jpg`, plus `preview-<name>-light.jpg` for a Light Mode look. Refresh it with the screenshot: `sips -Z 1200 -s formatOptions 70 docs/images/nebula-hubble.jpg --out Sources/Atrium/Resources/preview-nebula.jpg`.

## Dave's direction so far

- **Favourites:** Nebula first, then Flowing Gradient. They set the bar for the rest.
- **Real over made up:** real data (the real sky, weather and ISS at his location) and colours from real sources (nebula palettes after real objects). He was delighted that Live Sky uses his actual location.
- **Variety without repetition:** a new look on each load (Nebula, Lava Lamp), and slow, seamless cycling when left running, never a hard cut. On 2026-09-26 he asked for Shuffle: Settings → General moves the desktop on to a random wallpaper every 5 minutes to every day, from a checklist of wallpapers, and picking one by hand starts the clock over. It sits beside Open at Login, which the menu already had.
- **Calm motion:** ambient only, with no mouse interaction. Anything flashy or bouncing is distracting (the ISS label was made static). Nudge speeds by small steps.
- **Colours in one family:** jewel tones like Flowing Gradient's. He called Lava Lamp's green-in-blue ugly. Nebulae shouldn't be pink every time.
- **Light and Dark Mode:** scenes that suit both should follow the system appearance (Lava Lamp, Flowing Gradient).
- **Tunable:** options go in the Settings window as data (knobs, switches, palettes), so he can tweak until it looks right. On 2026-09-26 each page got the wallpaper running live behind a glass header, trialled on Nebula first: "yeah the live preview is awesome, add it to all of them."
- **Easy on the battery:** frozen in Low Power Mode, paused when covered. On 2026-09-26 he asked to be able to override this, for demos on battery: Settings → Power has a frame-rate menu (Freeze, 15, 30, 60) for mains power, battery and Low Power Mode, and the menu bar has Full Speed on Battery. Later that day he raised the defaults from 30 and 15 fps to 60 fps plugged in and 30 fps on battery: "it seems to run fine for me on 30 on my battery but we can monitor." Watch battery life and heat at these rates.
- **Workflow:** commit early and often; redeploy after each working change and tell him what to test.
- **Cut:** Zen Garden, on 2026-09-25: "so bright and sharp and not relaxing, opposite of zen." Calm means soft and dim as well as slow. Its code and doc were deleted; they're in git history before the cut.
- **Photoreal wins:** Galaxy only clicked once it was compared side by side with Hubble photos: colours sampled from them, soft edges, a bright disc rather than shapes on black, and an asinh stretch. The Fish Tank and Weather got the same treatment: research agents, real photo cut-outs where they beat procedural (fish, corals, hills, cumulus), physics where it beats photos (Weather's sky), and renders compared with reference photos.
- **Next:** iterate through each wallpaper to improve it, cut the weak ones and add new ones.
