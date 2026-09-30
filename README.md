# Atrium

<img src="docs/images/app-icon.png" alt="Atrium's icon: a skylight onto a glowing nebula" width="128">

Living, animated desktop wallpapers for macOS, 20 of them: a reef tank of real fish and corals, slow tours through the best real photos of the Solar System and deep space, the real sky above you right now, your live weather and wind, sunlight through leaves from the real Sun, rising heat as a schlieren camera sees it, drifting nebulae, and more. It's a small menu bar app written in Swift and SpriteKit, with no dependencies.

It's free. [Download it](#download), or build it yourself in a few minutes.

## The wallpapers

Screenshots show the wallpaper alone, with no desktop icons, menu bar or Dock. Everything moves: the fish school, the photos drift and zoom, the wind streams, the nebulae fold, the galaxies turn and the starlings wheel. Galaxy, Nebula and the reef are rebuilt differently on every load. Every wallpaper has its own page in [Settings](#settings). The docs in [`docs/`](docs/README.md) cover each wallpaper in depth: how it works, its settings, cost and ideas for next steps.

- **Nature and weather:** [Fish Tank](#fish-tank) · [Weather](#weather) · [Dappled Light](#dappled-light) · [Rain on Glass](#rain-on-glass) · [Wind](#wind) · [Murmuration](#murmuration) · [Aurora](#aurora) · [Fireflies](#fireflies)
- **Space:** [Solar System Tour](#solar-system-tour) · [Deep Space Tour](#deep-space-tour) · [Nebula](#nebula) · [Galaxy](#galaxy) · [Live Sky](#live-sky) · [Earth from Orbit](#earth-from-orbit)
- **Colour, light and pattern:** [Flowing Gradient](#flowing-gradient) · [Lava Lamp](#lava-lamp) · [Schlieren](#schlieren) · [Turing Patterns](#turing-patterns) · [Game of Life](#game-of-life) · [Pixel City](#pixel-city)

### Nature and weather

#### Fish Tank
A bright reef tank of real fish and corals, cut out of photos: a chromis school, tangs, clownfish in their anemone, and soft corals swaying.

![Fish Tank in motion: fish schooling over the reef under actinic blue, with light rippling across the sand](docs/images/fish-tank.gif)

| ![Fish Tank by day](docs/images/fish-tank-day.jpg) | ![Fish Tank at night](docs/images/fish-tank-actinic.jpg) |
|---|---|
| By day, in Light Mode | Under actinic blue in Dark Mode, its corals fluorescing |

#### Weather
Real hills under your live local weather, beneath a physical sky with the real Sun and Moon: sunrise and twilight, real clouds on the real wind, rain, snow lying on the ground, valley mist and lightning.

| ![Weather, fair](docs/images/weather-fair.jpg) | ![Weather, sunset](docs/images/weather-sunset.jpg) |
|---|---|
| A fair morning, with real clouds drifting on the wind | Sunset from a physical sky, the hills gone to silhouettes |
| ![Weather, fog](docs/images/weather-fog.jpg) | ![Weather, snow](docs/images/weather-snow.jpg) |
| Fog, with mist lying in the valley | Snow falling, and lying on the hills |

#### Dappled Light
Sunlight through a tree onto a warm white plaster wall, from the real Sun where you are: it only falls when the Sun is on the wall's side, and turns golden near sunset. Every gap between the leaves is a pinhole camera, so the dapples are images of the Sun, round or stretched by the angle of the light, and crescents during a real solar eclipse. Near leaves cast sharp shadows, far ones melt into soft shade. Cloud softens it and wind sways the leaves, from the live weather; at night, faint moonlight at the real phase, or a warm streetlight. In Dark Mode the same light falls on charcoal plaster.

| ![Dappled Light on an afternoon](docs/images/dappled-light.jpg) | ![Dappled Light at golden hour](docs/images/dappled-light-golden.jpg) |
|---|---|
| A clear afternoon | Golden hour, just before sunset |
| ![Dappled Light in Dark Mode, on charcoal plaster](docs/images/dappled-light-dark.jpg) | ![Dappled Light during a partial solar eclipse](docs/images/dappled-light-eclipse.jpg) |
| Dark Mode: the same light on charcoal plaster | A partial solar eclipse: every dapple a crescent |

#### Rain on Glass
Drops creeping and running down a rainy window, each a tiny lens showing the street upside down. Behind the glass: ten real places, blurred as a camera focused on the glass sees them (from a wet Hamburg square to a cabin in the snow), or city lights in seven palettes. Turn on Follow the weather and the glass does what the weather where you are would do to a real window: rain when it rains, drops drying when it stops, fog on humid mornings, snow melting into beads, and fern frost growing across the pane over hours below freezing.

| ![Rain on Glass at night](docs/images/rain-on-glass-night.jpg) | ![Rain on Glass by day](docs/images/rain-on-glass-day.jpg) |
|---|---|
| Hamburg at night, in Dark Mode | Riomaggiore by day, in Light Mode |
| ![Rain on Glass following the weather: fern frost](docs/images/rain-on-glass-frost.jpg) | ![Rain on Glass following the weather: fogged glass](docs/images/rain-on-glass-fog.jpg) |
| Following the weather: fern frost on a freezing night, over the Cabin | Fogged glass on a grey morning, over the Countryside |

#### Wind
The live wind around you as thin streaks streaming across the map, in the spirit of the hint.fm wind map and earth.nullschool: a grid of Open-Meteo's hourly forecast, blended from hour to hour, with streaks that speed up, brighten and curl with the real wind, as brush strokes like hint.fm's or comets like nullschool's. Zoom from your town to half the continent, over a map at the opacity you choose: the Earth by day or at night, terrain and the sea floor, or yesterday's satellite view with its real clouds (all from NASA), Natural Earth's shaded relief, or nothing, in six jewel-toned palettes. Light Mode draws the same streaks as ink on paper.

| ![Wind at the continent zoom over the Earth by day, a low spinning off the East Coast](docs/images/wind.jpg) | ![Wind in Light Mode at the region zoom, over the Earth printed on paper](docs/images/wind-light.jpg) |
|---|---|
| Half the continent, over the Earth by day | A region in Light Mode, ink on a pale print of the map |

#### Murmuration
Tens of thousands of starlings wheeling over Brighton's West Pier or a marsh pond, flying like the real thing (a published flight model), mirrored in the water and scattering from a falcon. By default a whole evening plays out, from golden hour to the roost.

![Murmuration in motion: a flock of starlings folding over Brighton's West Pier at sunset](docs/images/murmuration.gif)

| ![Murmuration over the marsh pond](docs/images/murmuration-marsh.jpg) | ![Murmuration over the West Pier at blue hour](docs/images/murmuration-blue-hour.jpg) |
|---|---|
| The marsh pond in the afterglow | The West Pier at blue hour |

#### Aurora
Northern lights over the snowy Tetons, shading through real aurora colours.

| ![Aurora in green](docs/images/aurora-green.jpg) | ![Aurora in purple](docs/images/aurora-purple.jpg) |
|---|---|
| The classic green | The Purple palette |

#### Fireflies
Fireflies drifting over a misty meadow at blue hour.

![Fireflies over a misty meadow at blue hour](docs/images/fireflies.jpg)

### Space

#### Solar System Tour
A slow tour of the Sun's family in 193 of the best photos spacecraft and telescopes have taken: Cassini's Saturn, Juno's Jupiter, Mars Express's Mars, New Horizons' Pluto, Webb's Uranus, Magellan's Venus, the Nile from the space station, and 46 worlds in all, down to Saturn's moon Pan and comet 67P. It also goes down to the ground: rover panoramas on Mars, the Apollo astronauts on the Moon, Huygens on Titan, and the last seconds before landing on comets and asteroids, which Settings can leave out. Each fills the screen, drifting and zooming for a minute, then dissolves into another world, and a world you come back to shows you a different photo. Under each name, a line on the photo and two quick facts about the world, never the same pair twice in a row. The Sun is today's real Sun and the Moon is tonight's real Moon, both live. Settings → Show holds the tour on one world, and Framing can show each photo whole instead of filling the screen.

| ![Solar System Tour: Jupiter from Juno, in enhanced colour](docs/images/solar-system-jupiter.jpg) | ![Solar System Tour: the Nile, Sinai and the Red Sea from the International Space Station](docs/images/solar-system-nile.jpg) |
|---|---|
| Jupiter, from Juno | The Nile and the Red Sea, from the space station |
| ![Solar System Tour: the delta in Jezero crater, from Perseverance](docs/images/solar-system-mars-jezero.jpg) | ![Solar System Tour: John Young, the rover and the lander at Descartes, Apollo 16](docs/images/solar-system-moon-apollo16.jpg) |
| Jezero crater on Mars, from Perseverance | Apollo 16 at Descartes |

##### The Sun, live
One of the Sun's views is the real Sun as NASA's Solar Dynamics Observatory saw it within the last hour or so: today's flares, sunspots and prominences, in eight wavelengths, each in its real SDO colour, from the gold coronal loops of 171 Å to visible light. Plasma pulses out along its loops, its corona streams away, and every few minutes one of today's active regions flares or a prominence erupts off the edge.

| ![The Sun Today, 193 Bronze](docs/images/sun-193.jpg) | ![The Sun Today, 304 Red, with a prominence erupting](docs/images/sun-304-eruption.jpg) |
|---|---|
| 193 Å, the million-degree corona, with a dark coronal hole, on 29 September 2026 | 304 Å, the chromosphere, as a prominence erupts |

It was its own wallpaper, The Sun Today, until it joined Solar System Tour.

##### The Moon, live
When the tour reaches the Moon, one of its views is the Moon filling the screen as it is right now from where you are: its real phase, wobble and tilt, from NASA's LRO maps, with shadows along the terminator, earthshine on the dark side, and copper during a lunar eclipse. Choose black, faint real stars or the real sky behind it. It was its own wallpaper, The Moon, until it joined Solar System Tour.

| ![The Moon, a waxing crescent with earthshine](docs/images/the-moon.jpg) | ![The Moon by day, on the Sky backdrop](docs/images/the-moon-day.jpg) |
|---|---|
| A waxing crescent with earthshine, among the real stars | Today's waning gibbous on the Sky backdrop, its dark side the sky's own blue |
| ![The Moon in the total lunar eclipse of 31 December 2028](docs/images/the-moon-eclipse.jpg) | ![The Moon beside NASA's Dial-a-Moon](docs/images/the-moon-vs-dial-a-moon.jpg) |
| The total lunar eclipse of 31 December 2028, previewed | Checked against NASA's Dial-a-Moon (left of each pair) for phase, libration, tilt and tone |

#### Deep Space Tour
Solar System Tour's sister, beyond the Solar System: slow pans and zooms across 95 of the best real photos of nebulae, star clusters, dying stars, galaxies, deep fields, and the only two black holes ever imaged, from Webb, Hubble, ESO, Euclid, the Rubin Observatory, Chandra and the Event Horizon Telescope. Real photos only: no artist's impressions or simulations. Each object comes with a caption and two facts, and Settings → Show holds the tour on one kind of object.

| ![Deep Space Tour: the Pillars of Creation from Webb](docs/images/deep-space-pillars.jpg) | ![Deep Space Tour: M87*, the first image of a black hole](docs/images/deep-space-m87.jpg) |
|---|---|
| The Pillars of Creation, from Webb | M87*, the first image of a black hole |

#### Nebula
A unique deep-space cloud on every load, in real nebula colours, dissolving into a new one every few minutes.

| ![Nebula, Hubble palette](docs/images/nebula-hubble.jpg) | ![Nebula, Reflection palette](docs/images/nebula-reflection.jpg) |
|---|---|
| The Hubble palette | The Reflection palette |
| ![Nebula, Planetary palette](docs/images/nebula-planetary.jpg) | ![Nebula, Oxygen palette](docs/images/nebula-oxygen.jpg) |
| The Planetary palette | The Oxygen palette |

#### Galaxy
A spiral galaxy turning slowly, after a real one, with dust lanes, star clusters and pink star-forming knots.

| ![Galaxy, Whirlpool](docs/images/galaxy-whirlpool.jpg) | ![Galaxy, Andromeda](docs/images/galaxy-andromeda.jpg) |
|---|---|
| The Whirlpool (M51) and its companion, in colours sampled from Hubble's portrait | Andromeda, steeply tilted, with M32 and M110 beside it |
| ![Galaxy, Great Barred](docs/images/galaxy-barred.jpg) | ![Galaxy, Milky Way](docs/images/galaxy-milky-way.jpg) |
| NGC 1300, the Great Barred Spiral, with dust lanes along its bar | The Milky Way, seen face-on |

#### Live Sky
The real sky above you: stars, planets, the Moon's phase, the Milky Way and the ISS. Deep blue by day.

| ![Live Sky at night](docs/images/live-sky.jpg) | ![Live Sky at dusk](docs/images/live-sky-dusk.jpg) |
|---|---|
| Nine tonight, looking south, with the Milky Way setting in the south-west | Dusk, from Preview a time of day in Settings |

#### Earth from Orbit
The globe above your location with the live day/night line, today's real clouds, lightning in storms near you, city lights and the ISS.

| ![Earth from Orbit at night, over India](docs/images/earth-from-orbit.jpg) | ![Earth from Orbit by day, over North America](docs/images/earth-from-orbit-day.jpg) |
|---|---|
| City lights across India before dawn, with day coming in from the east | Late afternoon over North America, under today's real clouds |

### Colour, light and pattern

#### Flowing Gradient
Soft pools of colour in six palettes, drifting from one palette to the next every few minutes on Random, with silk ribbons that follow the Sun if you turn them on.

| ![Flowing Gradient in Dark Mode](docs/images/flowing-gradient.jpg) | ![Flowing Gradient in Light Mode](docs/images/flowing-gradient-light.jpg) |
|---|---|
| In Dark Mode | The watercolour Light Mode |

#### Lava Lamp
Wax that rises up the middle as round heads on stems that pinch off, sticks to the top a while, then sinks at the sides, lit by the bulb below. Seven jewel-tone palettes, with Light and Dark looks.

| ![Lava Lamp in Dark Mode](docs/images/lava-lamp.jpg) | ![Lava Lamp in Light Mode, Teal palette](docs/images/lava-lamp-light.jpg) |
|---|---|
| Coral in Dark Mode | Teal, in Light Mode |

#### Schlieren
Rising heat as a colour schlieren camera sees it, after the photos of Gary Settles, Andrew Davidhazy and Ted Kinsman. Warm air bends light, and the camera turns each bend into a colour, so the two edges of a candle's plume glow in opposite colours as it rises, sways and curls into turbulence, in slow motion. It uses a real fluid simulation of the room's air. Pick candles, one taper, a mug of coffee or a radiator; a dark-field, rainbow, banded or knife-edge filter; and one of eight palettes, with the lab's round mirror as an option.

| ![Schlieren, candles in the dark field](docs/images/schlieren.jpg) | ![Schlieren, one candle through a rainbow filter after Davidhazy](docs/images/schlieren-rainbow.jpg) |
|---|---|
| Candles glowing in the dark field | One candle through the rainbow filter, after Davidhazy |

#### Turing Patterns
Reaction–diffusion, the chemistry Alan Turing proposed for how animals get their spots and stripes. Patterns grow from a few glowing seeds, then slowly drift from coral to dividing spots to a honeycomb to fingerprint stripes and round again, in six jewel-tone palettes. Patches keep dissolving and growing back in, so it never stops moving, or it can swirl on a slow current instead.

| ![Turing Patterns, fingerprint stripes in Dark Mode](docs/images/turing-patterns.jpg) | ![Turing Patterns, coral in Light Mode](docs/images/turing-patterns-light.jpg) |
|---|---|
| Fingerprint stripes in Dark Mode | Coral, glazed like ceramic, in Light Mode |

#### Game of Life
Conway's cells, reseeding so they never die out. The Calm look shows a long exposure, so cells melt into soft glowing blobs that drift slowly; the Classic look is crisp, quick and colourful.

| ![Game of Life, Calm](docs/images/game-of-life.jpg) | ![Game of Life, Classic](docs/images/game-of-life-classic.jpg) |
|---|---|
| Calm | Classic |

#### Pixel City
A pixel-art skyline that follows your clock, with traffic and windows lighting up through the evening.

| ![Pixel City at dusk](docs/images/pixel-city-dusk.jpg) | ![Pixel City at night](docs/images/pixel-city-night.jpg) |
|---|---|
| Dusk, the windows coming on | Late at night, under the Moon |

## Settings

The first time Atrium opens, a short welcome helps you pick the wallpapers you like (it's in Settings → About → Show Welcome any time after). Choose Settings… (⌘,) from the menu bar icon. Every wallpaper has a page, laid out like System Settings, with its palettes, photos, sliders, switches and menus. The wallpaper runs live behind the top of its page, so each change shows as you make it. General holds Open at Login and Shuffle; Power sets the frame rate on mains power, on battery and in Low Power Mode.

| ![Settings for Solar System Tour: a grid of worlds to hold the tour on](docs/images/settings-solar-system-tour.jpg) | ![Settings for Rain on Glass: ten real places and seven city-light palettes behind the glass](docs/images/settings-rain-on-glass.jpg) |
|---|---|
| Solar System Tour: hold the tour on one world, or let it roam | Rain on Glass: ten real places behind the glass, or city lights in seven palettes |
| ![Settings for Nebula: its palettes and how often a new nebula forms](docs/images/settings-nebula.jpg) | ![Settings for Dappled Light in Light Mode: which way the wall faces, leaf cover, weather and the light at night](docs/images/settings-dappled-light.jpg) |
| Nebula: seven palettes after real nebulae, or Random | Dappled Light, in Light Mode: the wall, the weather and the light at night |

## How it works

macOS has no public API for third-party live wallpapers. This app gives each display a borderless window at the desktop window level (`CGWindowLevelForKey(.desktopWindow)`). That puts it above the system wallpaper and below your desktop icons, on every Space, and it lets clicks pass straight through to the desktop.

It uses public AppKit and SpriteKit APIs only. It uses no private frameworks, makes no changes to system files, needs no SIP changes and doesn't inject code.

Each wallpaper is a SpriteKit scene. Many are full-screen Metal shaders written as `SKShader`s, and whatever can be drawn in code is: skies, water, wax, streaks of wind, starlings, reaction–diffusion and rising heat. Photos come in where they beat anything procedural: the reef's fish and corals, and the landscapes behind Weather, Aurora, Murmuration, Fireflies and Rain on Glass, all cut out of permissively licensed photos and relit; the two tours' photos from spacecraft and telescopes; and NASA's maps of the Earth and the Moon. Live data comes over the network: the weather, the wind, the clouds, the ISS and the Sun.

It's kind to your battery:
- 60 fps on mains power, 30 fps on battery.
- In Low Power Mode it freezes on the current frame.
- Rendering pauses whenever the desktop is fully covered.
- Settings → Power changes each of these rates (Freeze, 15, 30 or 60 fps). For a demo on battery, choose Full Speed on Battery in the menu bar.

The lock screen, and the tint of the menu bar and windows, come from your normal system wallpaper, which Atrium only covers. To match them, turn on **Settings → General → Match the lock screen**: it sets your system wallpaper to a still of Atrium's, refreshed as it changes, and puts yours back when you turn it off or quit.

## Download

Download the DMG from the [Releases](https://github.com/dtanquary/atrium/releases) page, open it, and drag Atrium into Applications.

Atrium isn't notarised by Apple (that needs a paid developer account), so the first time you open it macOS says it can't verify it. To let it through, once:
1. Choose **Done** in that message.
2. Open **System Settings → Privacy & Security**, scroll down to **Security**, and click **Open Anyway** beside Atrium.
3. Confirm with your password or Touch ID, then choose **Open Anyway** again.

After that it opens like any other app. If you'd rather not, build it yourself from the source (below): that needs no exceptions.

To make the DMG yourself: `./dmg.sh` → `build/Atrium-<version>.dmg`.

## Requirements

- macOS 26 or later, on Apple silicon. It's developed and tested on macOS 27.
- Xcode 26 or later, or its command line tools (Swift 6).

## Build and run

```sh
git clone https://github.com/dtanquary/atrium.git
cd atrium
./build.sh                 # release build → build/Atrium.app
open build/Atrium.app
```

`build.sh` runs `swift build -c release`, wraps the binary in a menu-bar-only `.app` (no Dock icon), copies in the data files, and signs it ad hoc for your own Mac. Move the app into `/Applications` if you like.

Once it's running, use the ✨📺 icon in the menu bar to:
- **Pick** a wallpaper.
- Turn on **Shuffle** to move on to a random wallpaper every so often, and choose **Next Wallpaper** to skip ahead. Settings → General sets how often (every 5 minutes to every day) and which wallpapers take part.
- Open **Settings…** (⌘,): a page for each wallpaper, with palettes, sliders and switches that update live, plus General, Power and About.
- Turn on **Open at Login**, here or in Settings → General. macOS may ask you to approve it in System Settings → General → Login Items.
- **Quit**.

To rebuild after pulling changes: `./build.sh && pkill -x Atrium; open build/Atrium.app`

### Updating and uninstalling

- **Update:** download the new DMG and replace the app in Applications, or `git pull && ./build.sh`. Your settings carry over.
- **Uninstall:** turn off **Open at Login** and **Match the lock screen** in Settings → General (the second puts your own wallpaper back), quit Atrium, and move it to the Trash. To remove its settings and caches too:

  ```sh
  defaults delete com.dtanquary.atrium
  rm -rf ~/Library/Caches/com.dtanquary.atrium ~/Library/HTTPStorages/com.dtanquary.atrium "$HOME/Library/Application Support/com.dtanquary.atrium"
  ```

### Permissions and network

- **Location** (optional). Live Sky, Earth from Orbit, Weather, Dappled Light, Wind, Pixel City, the live Moon, Rain on Glass following the weather and Flowing Gradient's time-of-day mood use your location, and the app asks once. If you decline, it guesses from your time zone.
- **Network.** Weather, Dappled Light and Rain on Glass (while following the weather) fetch from [Open-Meteo](https://open-meteo.com) every 15 minutes, sharing one request. Live Sky and Earth from Orbit fetch the ISS position from [wheretheiss.at](https://wheretheiss.at) at most once a minute. Earth from Orbit fetches a global cloud map from [Live Cloud Maps](https://clouds.matteason.co.uk) only once its cached copy is over 3 hours old (1.5 MB when it has changed), and not at all with Live clouds off. For lightning, it asks Open-Meteo for the next day's thunderstorms on a grid around you every 6 hours. Solar System Tour's live Sun, while it's on screen, fetches SDO images from [Helioviewer](https://helioviewer.org) at most every 15 minutes (2048 pixels, 0.3–0.5 MB) or 30 (4096, 1–2 MB, for the close-up), keeping the last few hours on disk. None of them needs an API key. Pages whose wallpaper uses live data have **Refresh Now** in Settings, which fetches at once, at most every 5 to 15 minutes.
- **Wind** uses your location too, and asks Open-Meteo for the next day's hourly wind forecast on a grid around you every 6 hours, for the zoom on screen: 96 points for a town, 384 for a region or half the continent (Open-Meteo counts each point as one of its free 10,000 calls a day, so at most 1,536 a day). The last reply for each zoom stays on disk, so it works offline. With an Earth background it downloads NASA's imagery tiles for the view from [GIBS](https://nasa-gibs.github.io/gibs-api-docs/) once and keeps them: about 1–2 MB for most maps, up to 7 MB at night for half the continent, and a fresh 1–2 MB a day for the satellite view.

## Development

```sh
swift build            # debug build
swift test             # renders every wallpaper offscreen to PNGs and prints each one's per-frame cost
SNAPSHOT_SCENE="Nebula" SNAPSHOT_DIR=/tmp/shots swift test     # one wallpaper
SNAPSHOT_DEFAULTS="gradient.palette=Sunset" SNAPSHOT_APPEARANCE=light swift test   # with settings, in Light Mode
SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_MOVIE=6 swift test       # then 6 seconds of frames at 15 fps, for a GIF
SETTINGS_SHOT="Nebula" swift test --filter settingsWindow   # opens Settings on that page for a moment and captures it
```

- **Tests.** The render test fails if a scene comes out as one flat colour, for example a shader that didn't compile. The astronomy is checked against JPL Horizons, and the weather parser against a real Open-Meteo reply.
- **Adding a wallpaper:** create a file that returns an `SKScene` and add a `Wallpaper` entry in `Sources/Atrium/Scenes.swift`. Its settings are plain data on that entry. [`CLAUDE.md`](CLAUDE.md) covers the scene contract, the ~2 ms per-frame budget, and SpriteKit and shader pitfalls.
- **Layout:**
  - `Sources/Atrium/main.swift`: the app host (windows, menu, power and appearance handling)
  - `Scenes.swift`: the wallpaper list and shared helpers
  - `Settings.swift`: the Settings window
  - one file per wallpaper
  - `Resources/`: data files

## Credits

- Weather data by [Open-Meteo.com](https://open-meteo.com), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- ISS positions from the [Where the ISS at?](https://wheretheiss.at) API.
- Stars from the Yale Bright Star Catalogue, 5th edition (Hoffleit & Warren, CDS V/50), public domain.
- Constellation lines from [d3-celestial](https://github.com/ofrohn/d3-celestial) by Olaf Frohn, BSD 3-Clause. Its notice is kept in `Sources/Atrium/Resources/constellations.txt`.
- Earth imagery from NASA's Blue Marble and Black Marble, public domain.
- Clouds from [Live Cloud Maps](https://github.com/matteason/live-cloud-maps) by Matt Eason, CC0. Contains modified EUMETSAT data.
- The Wind wallpaper's shaded relief is from [Natural Earth](https://www.naturalearthdata.com), public domain, and its maps are NASA's Blue Marble Next Generation (with shaded relief and bathymetry), Black Marble, the Global Web-Enabled Landsat Data (NASA and USGS) and NOAA-20 VIIRS imagery from LANCE, public domain. We acknowledge the use of imagery provided by services from NASA's Global Imagery Browse Services ([GIBS](https://nasa-gibs.github.io/gibs-api-docs/)), part of NASA's Earth Science Data and Information System (ESDIS).
- The Moon's maps are from NASA's [CGI Moon Kit](https://svs.gsfc.nasa.gov/4720) (Ernie Wright, NASA Scientific Visualization Studio), public domain: LROC colour and LOLA heights from the Lunar Reconnaissance Orbiter.
- Planet positions from JPL's [Approximate Positions of the Planets](https://ssd.jpl.nasa.gov/planets/approx_pos.html).
- Images of the Sun courtesy of NASA/SDO and the AIA, EVE, and HMI science teams ([terms](https://sdo.gsfc.nasa.gov/data/rules.php)), via the ESA/NASA [Helioviewer Project](https://helioviewer.org).
- The Weather wallpaper's hills are a public domain photo of Fort Ord National Monument by the Bureau of Land Management, its clouds are cut out of CC0 photos from Poly Haven and Wikimedia Commons, and its Moon is from NASA's CGI Moon Kit. See [`Sources/Atrium/Resources/weather-credits.tsv`](Sources/Atrium/Resources/weather-credits.tsv) and Settings → About.
- The Aurora wallpaper's mountains are a public domain National Park Service photo of the Tetons in winter by A. Falgoust ([source](https://commons.wikimedia.org/wiki/File:Teton_Point_Turnout_in_Winter_(52098766554).jpg)).
- The Murmuration wallpaper's grounds are "Tide bears the last glow - Brighton, UK" by sagesolar, CC BY 4.0 ([source](https://commons.wikimedia.org/wiki/File:Tide_bears_the_last_glow_-_Brighton,_UK.jpg)), with its sky cut away and its sea relit, and a public domain U.S. Fish and Wildlife Service photo of a tundra pond ([source](https://commons.wikimedia.org/wiki/File:Sunset_over_a_tundra_pond_(53708107535).jpg)).
- The Fireflies wallpaper's meadow is "Field at dusk" by Tristan Ferne, CC BY 2.0 ([source](https://www.flickr.com/photos/89056504@N00/7357684410)), with its sky cut away and relit for blue hour. See [`Sources/Atrium/Resources/fireflies-credits.tsv`](Sources/Atrium/Resources/fireflies-credits.tsv).
- The Campfire wallpaper's clearing is the CC0 panorama "Hochsal Forest" by Adrian Kubasa ([source](https://polyhaven.com/a/hochsal_forest)), relit by the fire, with CC0 scans of a stone fire pit by Sebastian Platen and dry branches by Rico Cilliers from Poly Haven. See [`Sources/Atrium/Resources/campfire-credits.tsv`](Sources/Atrium/Resources/campfire-credits.tsv).
- The Rain on Glass backdrops are CC0 HDRIs from Poly Haven by Greg Zaal, Rico Cilliers, Alexander Scholten, Andreas Mischok and Oliksiy Yakovlyev, public domain photos from the National Park Service and USFWS, and CC BY photos from Wikimedia Commons by Douglas Paul Perkins, mariemon, epSos.de and Vyacheslav Argenberg. See [`Sources/Atrium/Resources/rain-credits.tsv`](Sources/Atrium/Resources/rain-credits.tsv) and Settings → About.
- A Tree for the Year's hilltop is "Solitary tree at Cissbury Ring" by Andy Li, CC0 ([source](https://commons.wikimedia.org/wiki/File:Solitary_tree_at_Cissbury_Ring_2026-04-07.jpg)), with its own tree painted out; its oak leaves and bark are CC0 scans by Lennart Demes, ambientCG. See [`Sources/Atrium/Resources/tree-credits.tsv`](Sources/Atrium/Resources/tree-credits.tsv).
- Solar System Tour's photos are from NASA, JPL, ESA, JAXA, the Space Science Institute, JHUAPL/SwRI, NSO and the people who processed them, public domain, CC BY or CC BY-SA. Each one's credit, licence and source is in [`Sources/Atrium/Resources/solar-photos.tsv`](Sources/Atrium/Resources/solar-photos.tsv) and in Settings → About.
- Deep Space Tour's photos are from ESA/Hubble, ESA/Webb, ESO, NOIRLab, ESA's Euclid, NASA's Chandra and the Event Horizon Telescope Collaboration, CC BY 4.0, CC BY-SA 3.0 IGO or public domain. Each one's credit, licence and source is in [`Sources/Atrium/Resources/deep-photos.tsv`](Sources/Atrium/Resources/deep-photos.tsv) and in Settings → About.
- Reef fish, corals and rock in the Fish Tank are cut out of public domain, CC0 and CC BY photos from iNaturalist, Wikimedia Commons and NOAA. Each photographer and licence is listed in [`Sources/Atrium/Resources/reef-credits.tsv`](Sources/Atrium/Resources/reef-credits.tsv) and in Settings → About.

## License

The code is [MIT](LICENSE) © 2026 Dave Tanquary. The photos and data aren't: each keeps its own license (public domain, CC0, CC BY or CC BY-SA), listed under Credits, in the credits files beside them, and in Settings → About. Photos are cropped, cut out, relit or recolored from their originals, and adapted copies of CC BY-SA photos stay CC BY-SA. See [NOTICE](NOTICE).
