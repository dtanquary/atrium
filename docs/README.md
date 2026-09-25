# Wallpaper docs

One file per wallpaper, recording what the code can't: how each scene works, why it's built the way it is, its settings, cost, shortcuts, Dave's feedback, and ideas for next steps. Read the scene's doc before changing it, and update the doc in the same commit as the change. The app, commands and conventions are in `../CLAUDE.md`.

## Wallpapers

| Wallpaper | Doc | Source | Kind | Settings | Live data | CPU / GPU ms* |
|---|---|---|---|---|---|---|
| Fish Tank | [fish-tank.md](fish-tank.md) | `FishTank.swift`, `FishTankArt.swift`, `Resources/reef-*` | photo cut-outs and shaders | none yet | none | 0.7 / 1.35 |
| Flowing Gradient | [flowing-gradient.md](flowing-gradient.md) | `FlowingGradient.swift` | shader | knobs, 6 palettes | Sun position | 0.47 / 0.55 |
| Lava Lamp | [lava-lamp.md](lava-lamp.md) | `LavaLamp.swift` | shader | knobs, 7 palettes | none | 0.45 / 1.86 |
| Rain on Glass | [rain-on-glass.md](rain-on-glass.md) | `Shaders.swift` | shader | knobs, 7 palettes, day look | none | 0.45 / 1.40 |
| Aurora | [aurora.md](aurora.md) | `Shaders.swift` | shader | knobs, 8 palettes | none | 0.42 / 1.88 |
| Nebula | [nebula.md](nebula.md) | `Shaders.swift` | shader | knobs, 7 palettes | none | 0.45 / 1.52 |
| Galaxy | [galaxy.md](galaxy.md) | `Galaxy.swift` | shader | knobs, 6 real galaxies | none | 0.5 / 1.5–2.1 |
| Live Sky | [live-sky.md](live-sky.md) | `LiveSky.swift`, `SkyMath.swift` | SpriteKit and shaders | switches, preview | location, ISS | 0.64 / 0.90 |
| Earth from Orbit | [earth-from-orbit.md](earth-from-orbit.md) | `EarthFromOrbit.swift`, `ISS.swift`, `Clouds.swift`, `Storms.swift` | shader | ISS, clouds, lightning switches | location, ISS, clouds, storms | 0.45 / 0.31 |
| Weather | [weather.md](weather.md) | `Weather.swift` | SpriteKit | none yet | location, Open-Meteo | 0.42 / 0.18 |
| Pixel City | [pixel-city.md](pixel-city.md) | `PixelCity.swift` | SpriteKit (pixel canvas) | none yet | location, clock | 0.43 / 0.18 |
| Fireflies | [fireflies.md](fireflies.md) | `Fireflies.swift` | SpriteKit | none yet | none | 0.49 / 0.41 |
| Murmuration | [murmuration.md](murmuration.md) | `Murmuration.swift` | SpriteKit (3D boids) | none yet | none | 1.09 / 0.24 |
| Campfire | [campfire.md](campfire.md) | `Campfire.swift` | SpriteKit emitters | none yet | none | 0.45 / 0.28 |
| Game of Life | [game-of-life.md](game-of-life.md) | `GameOfLife.swift` | mutable texture | none yet | none | 0.47 / 0.52 |

\*Release build, 2x Retina at 1512×982 points, measured 2026-09-24 with `swift test -c release -Xswiftc -enable-testing`. The budget is about 2 ms each for CPU and GPU. Debug builds are pessimistic on CPU (Murmuration runs about 16–19 ms in debug).

## Dave's direction so far

- **Favourites:** Nebula first, then Flowing Gradient. They set the bar for the rest.
- **Real over made up:** real data (the real sky, weather and ISS at his location) and colours from real sources (nebula palettes after real objects). He was delighted that Live Sky uses his actual location.
- **Variety without repetition:** a new look on each load (Nebula, Lava Lamp), and slow, seamless cycling when left running, never a hard cut.
- **Calm motion:** ambient only, with no mouse interaction. Anything flashy or bouncing is distracting (the ISS label was made static). Nudge speeds by small steps.
- **Colours in one family:** jewel tones like Flowing Gradient's. He called Lava Lamp's green-in-blue ugly. Nebulae shouldn't be pink every time.
- **Light and Dark Mode:** scenes that suit both should follow the system appearance (Lava Lamp, Flowing Gradient).
- **Tunable:** options go in the Settings window as data (knobs, switches, palettes), so he can tweak until it looks right.
- **Easy on the battery:** 15 fps on battery, frozen in Low Power Mode, paused when covered.
- **Workflow:** commit early and often; redeploy after each working change and tell him what to test.
- **Cut:** Zen Garden, on 2026-09-25: "so bright and sharp and not relaxing, opposite of zen." Calm means soft and dim as well as slow. Its code and doc were deleted; they're in git history before the cut.
- **Photoreal wins:** Galaxy only clicked once it was compared side by side with Hubble photos: colours sampled from them, soft edges, a bright disc rather than shapes on black, and an asinh stretch. Cartoony looks (he named the Fish Tank) are next in line for the same treatment.
- **Next:** iterate through each wallpaper to improve it, cut the weak ones and add new ones.
