# Atrium

<img src="docs/images/app-icon.png" alt="Atrium's icon: a skylight onto a glowing nebula" width="128">

Living, animated desktop wallpapers for macOS, 24 of them: a reef tank of real fish and corals, slow tours through the best real photos of the Solar System and deep space, the real sky above you right now, your live weather and wind, sunlight through leaves from the real Sun, rising heat as a schlieren camera sees it, drifting nebulae, a black hole that bends the Milky Way around it, a pixel-art spaceport where rockets launch and land, and more. It's a small menu bar app written in Swift and SpriteKit, with no dependencies.

It's free and open source, for macOS 26 or later on Apple silicon. See it move at **[atrium.show](https://atrium.show)**, [download it](#download), or [build it yourself](#build-from-source) in a few minutes.

## The wallpapers

Screenshots show the wallpaper alone, with no desktop icons, menu bar or Dock. The first of each wallpaper's pictures is a 12-second loop of it moving, drawn by the app itself, the same ones its cards play on [atrium.show](https://atrium.show). Everything moves: the fish school, the photos drift and zoom, the wind streams, the nebulae fold, the galaxies turn, the starlings wheel and the rockets launch and land. Galaxy, Nebula and the reef are rebuilt differently on every load. Every wallpaper has its own page in [Settings](#settings). The docs in [`docs/`](docs/README.md) cover each wallpaper in depth: how it works, its settings, cost and ideas for next steps.

- **Nature and weather:** [Fish Tank](#fish-tank) · [Weather](#weather) · [Dappled Light](#dappled-light) · [Rain on Glass](#rain-on-glass) · [Wind](#wind) · [Murmuration](#murmuration) · [Aurora](#aurora) · [Fireflies](#fireflies) · [Meander](#meander)
- **Space:** [Solar System Tour](#solar-system-tour) · [Deep Space Tour](#deep-space-tour) · [Nebula](#nebula) · [Galaxy](#galaxy) · [Black Hole](#black-hole) · [Live Sky](#live-sky) · [Earth from Orbit](#earth-from-orbit) · [Pixel Spaceport](#pixel-spaceport)
- **Color, light and pattern:** [Flowing Gradient](#flowing-gradient) · [Lava Lamp](#lava-lamp) · [Schlieren](#schlieren) · [Turing Patterns](#turing-patterns) · [Game of Life](#game-of-life) · [Pixel City](#pixel-city) · [Pixel Window Seat](#pixel-window-seat)

### Nature and weather

#### Fish Tank
A bright reef tank of real fish and corals, cut out of photos: a chromis school, tangs, clownfish in their anemone, and soft corals swaying.

| <img src="docs/images/fish-tank.webp" alt="Fish Tank by day, moving: fish schooling over the reef, with light rippling across the sand" width="1600"> | ![Fish Tank at night](docs/images/fish-tank-actinic.jpg) |
|---|---|
| By day, in Light Mode | Under actinic blue in Dark Mode, its corals fluorescing |

Settings → Fish Tank holds the lighting at daylight or actinic blue whatever the appearance, or puts the lights out on a timer at night, and sets how many fish there are and whether marine snow drifts.

#### Weather
Real hills under your live local weather, beneath a physical sky with the real Sun and Moon: sunrise and twilight, real clouds on the real wind, rain, snow lying on the ground, valley mist and lightning.

| <img src="docs/images/weather.webp" alt="Weather at sunset, moving" width="1600"> | ![Weather, fair](docs/images/weather-fair.jpg) |
|---|---|
| Sunset from a physical sky, the hills gone to silhouettes | A fair morning, with real clouds drifting on the wind |
| ![Weather, fog](docs/images/weather-fog.jpg) | ![Weather, snow](docs/images/weather-snow.jpg) |
| Fog, with mist lying in the valley | Snow falling, and lying on the hills |

#### Dappled Light
Sunlight through a tree onto a warm white plaster wall, from the real Sun where you are: it only falls when the Sun is on the wall's side, and turns golden near sunset. Every gap between the leaves is a pinhole camera, so the dapples are images of the Sun, round or stretched by the angle of the light, and crescents during a real solar eclipse. Near leaves cast sharp shadows, far ones melt into soft shade. Cloud softens it and wind sways the leaves, from the live weather; at night, faint moonlight at the real phase, or a warm streetlight. The wall can be white plaster, terracotta limewash, clay plaster, whitewashed brick, or lap siding in sage or dusty blue, whose laps shade a line under each board. Or the light can fall on an oak floor, in the open or through a window, where the patch of panes stretches as the Sun drops. In Dark Mode the same light falls on charcoal plaster.

| <img src="docs/images/dappled-light.webp" alt="Dappled Light at golden hour, moving" width="1600"> | ![Dappled Light on an afternoon](docs/images/dappled-light.jpg) |
|---|---|
| Golden hour, the leaves swaying | A clear afternoon |
| ![Dappled Light in Dark Mode, on charcoal plaster](docs/images/dappled-light-dark.jpg) | ![Dappled Light during a partial solar eclipse](docs/images/dappled-light-eclipse.jpg) |
| Dark Mode: the same light on charcoal plaster | A partial solar eclipse: every dapple a crescent |
| ![Dappled Light on sage lap siding](docs/images/dappled-light-siding.jpg) | ![Dappled Light on an oak floor, through a window](docs/images/dappled-light-window.jpg) |
| Sage lap siding | An oak floor by a window, mid-afternoon |

#### Rain on Glass
Drops creeping and running down a rainy window, each a tiny lens showing the street upside down. Behind the glass: ten real places, blurred as a camera focused on the glass sees them (from a wet Hamburg square to a cabin in the snow), or city lights in seven palettes. Turn on Follow the weather and the glass does what the weather where you are would do to a real window: rain when it rains, drops drying when it stops, fog on humid mornings, snow melting into beads, and fern frost growing across the pane over hours below freezing.

| <img src="docs/images/rain-on-glass.webp" alt="Rain on Glass at night, moving" width="1600"> | ![Rain on Glass by day](docs/images/rain-on-glass-day.jpg) |
|---|---|
| Hamburg at night, in Dark Mode | Riomaggiore by day, in Light Mode |
| ![Rain on Glass following the weather: fern frost](docs/images/rain-on-glass-frost.jpg) | ![Rain on Glass following the weather: fogged glass](docs/images/rain-on-glass-fog.jpg) |
| Following the weather: fern frost on a freezing night, over the Cabin | Fogged glass on a gray morning, over the Countryside |

#### Wind
The live wind around you as thin streaks streaming across the map, in the spirit of the hint.fm wind map and earth.nullschool: a grid of Open-Meteo's hourly forecast, blended from hour to hour, with streaks that speed up, brighten and curl with the real wind, as brush strokes like hint.fm's or comets like nullschool's. Zoom from your town to half the continent, over a map at the opacity you choose: the Earth by day or at night, terrain and the sea floor, or yesterday's satellite view with its real clouds (all from NASA), Natural Earth's shaded relief, or nothing, in six jewel-toned palettes. Light Mode draws the same streaks as ink on paper.

| <img src="docs/images/wind.webp" alt="Wind at the continent zoom over the Earth by day, moving, a low spinning off the East Coast" width="1600"> | ![Wind in Light Mode at the region zoom, over the Earth printed on paper](docs/images/wind-light.jpg) |
|---|---|
| Half the continent, over the Earth by day | A region in Light Mode, ink on a pale print of the map |

#### Murmuration
Tens of thousands of starlings wheeling over Brighton's West Pier or a marsh pond, flying like the real thing (a published flight model), mirrored in the water and scattering from a falcon. By default a whole evening plays out, from golden hour to the roost.

| <img src="docs/images/murmuration.webp" alt="Murmuration over the West Pier at blue hour, moving: the flock folding over the pier" width="1600"> | ![Murmuration over the marsh pond](docs/images/murmuration-marsh.jpg) |
|---|---|
| The West Pier at blue hour | The marsh pond in the afterglow |

#### Aurora
Northern lights over the snowy Tetons, shading through real aurora colors.

| <img src="docs/images/aurora.webp" alt="Aurora in purple, moving" width="1600"> | ![Aurora in green](docs/images/aurora-green.jpg) |
|---|---|
| The Purple palette, at 2× speed | The classic green |

#### Fireflies
Fireflies drifting over a misty meadow at blue hour.

![Fireflies over a misty meadow at blue hour, moving](docs/images/fireflies.webp)

#### Meander
A river wandering across its floodplain. It's a simulation, not a film: each bank moves by the bend of the water against it, so the loops grow and shift down the valley, a neck narrows until the river cuts through it and leaves an oxbow lake, and its old courses stay written on the ground behind it. There's a new river each time it loads. It's drawn two ways: as relief, the ground shaded by its height above the water in one color family, the way lidar maps of real floodplains are, or as an old map with each former course in the ink of its age, after [Harold Fisk's 1944 maps](https://commons.wikimedia.org/wiki/File:Ancient_Courses_Mississippi_River_Meander_Belt,_Plate_22_Sheet_06.jpg) of the Mississippi. Each look has four color families, or Random, which slowly repaints the running river in another every ten minutes, and each follows Light and Dark Mode on the same river. In Settings you can keep the river within the screen or let it wander past the edges, and set its size, its speed, how long old courses and lakes last, and the picture's brightness, contrast, saturation and hue.

| <img src="docs/images/meander.webp" alt="Meander as relief in Rainforest, moving" width="1600"> | ![Meander as an old map in the inks of Fisk's 1944 sheets, in Light Mode](docs/images/meander-old-map.jpg) |
|---|---|
| Relief, in Rainforest, at 2× speed | Old map, in the inks of Fisk's 1944 sheets, in Light Mode |
| ![Meander as relief in Rainforest, in Light Mode](docs/images/meander-light.jpg) | ![Meander as relief in Amethyst](docs/images/meander-amethyst.jpg) |
| Relief in Light Mode, as ink on paper | Another river, in Amethyst |
| ![Meander as an old map in Salmon, in Dark Mode](docs/images/meander-salmon.jpg) | ![Meander as relief in Survey Blue, with Full view](docs/images/meander-full-view.jpg) |
| Old map in Salmon, in Dark Mode | Full view, in Survey Blue: the river free to wander past the edges |

#### Ant Colony
A colony of ants digging its nest in a thin tank seen from the side, with your display as the glass. At six in the morning the tank is whole, with a few ants on top of it. Through the day a shaft goes down, branches and opens into rooms, what's dug out piles up around the entrances, and more ants walk in as the nest grows. By the next morning it's finished, and a new one begins. Each nest is made from the date, so every day's is different, and nothing is downloaded. The digging is fastest early: nearly half is done by noon and three quarters by six in the evening. The ants walk as real ones do, three legs at a time with their feet planted on the tunnel's walls, in short bouts with stops between. Two that meet stop and touch antennae. At the end of a tunnel being dug, one ant digs while others wait behind it, then carries a grain up to the pile by the entrance. In Settings, Look picks what they dig in: Gel, the standard, a deep blue gel lit from its base, or Bright Gel, Sand, White Sand or Earth. Speed runs from 1×, a nest a day beginning at six in the morning, to 8×, a nest every three hours, one after another; the ants walk no faster. Ant size is Small, Medium (the standard) or Large, and smaller ants get a bigger nest to dig. Colony size sets how many ants there are once the nest is done, from half to twice the standard number.

| <img src="docs/images/ant-colony.webp" alt="Ant Colony in Gel, moving: dark ants walking the pale tunnels of a nest dug in deep blue gel" width="1600"> | ![Ant Colony in Bright Gel, the same nest with rays of light over the lamps in its base](docs/images/ant-colony-bright-gel.jpg) |
|---|---|
| Gel, the standard look, at five in the afternoon: the nest about 70% dug | Bright Gel: the same nest at the same moment |
| ![Ant Colony in Sand, red ants in tunnels through dim, warm sand](docs/images/ant-colony-sand.jpg) | ![Ant Colony in White Sand, red ants in tunnels through pale sand](docs/images/ant-colony-white-sand.jpg) |
| Sand, another day's nest at five in the afternoon | White Sand, at three in the afternoon |
| ![Ant Colony in Earth, red ants in dark tunnels through yellow-brown soil](docs/images/ant-colony-earth.jpg) | ![Ant Colony in Gel with Large ants, early in the day: one shaft down from the surface and its first three branches, with four ants in them](docs/images/ant-colony-large.jpg) |
| Earth, at four in the afternoon | Large ants in Gel at nine in the morning: the first shaft and its first branches |

### Space

#### Solar System Tour
A slow tour of the Sun's family in 193 of the best photos spacecraft and telescopes have taken: Cassini's Saturn, Juno's Jupiter, Mars Express's Mars, New Horizons' Pluto, Webb's Uranus, Magellan's Venus, the Nile from the space station, and 46 worlds in all, down to Saturn's moon Pan and comet 67P. It also goes down to the ground: rover panoramas on Mars, the Apollo astronauts on the Moon, Huygens on Titan, and the last seconds before landing on comets and asteroids, which Settings can leave out. Each fills the screen, drifting and zooming for a minute, then dissolves into another world, and a world you come back to shows you a different photo. Under each name, a line on the photo and two quick facts about the world, never the same pair twice in a row. The Sun is today's real Sun and the Moon is tonight's real Moon, both live. Settings → Show holds the tour on one world, and Framing can show each photo whole instead of filling the screen.

| <img src="docs/images/solar-system-tour.webp" alt="Solar System Tour: Jupiter from Juno, in enhanced color, moving" width="1600"> | ![Solar System Tour: the Nile, Sinai and the Red Sea from the International Space Station](docs/images/solar-system-nile.jpg) |
|---|---|
| Jupiter, from Juno | The Nile and the Red Sea, from the space station |
| ![Solar System Tour: the delta in Jezero crater, from Perseverance](docs/images/solar-system-mars-jezero.jpg) | ![Solar System Tour: John Young, the rover and the lander at Descartes, Apollo 16](docs/images/solar-system-moon-apollo16.jpg) |
| Jezero crater on Mars, from Perseverance | Apollo 16 at Descartes |

##### The Sun, live
One of the Sun's views is the real Sun as NASA's Solar Dynamics Observatory saw it about an hour ago (two or three in visible light): today's flares, sunspots and prominences, in eight wavelengths, each in its real SDO color, from the gold coronal loops of 171 Å to visible light. Plasma pulses out along its loops, its corona streams away, and every few minutes one of today's active regions flares or a prominence erupts off the edge.

| ![The Sun Today, 193 Bronze](docs/images/sun-193.jpg) | ![The Sun Today, 304 Red, with a prominence erupting](docs/images/sun-304-eruption.jpg) |
|---|---|
| 193 Å, the million-degree corona, with a dark coronal hole, on September 29, 2026 | 304 Å, the chromosphere, as a prominence erupts |

##### The Moon, live
When the tour reaches the Moon, one of its views is the Moon filling the screen as it is right now from where you are: its real phase, wobble and tilt, from NASA's LRO maps, with shadows along the terminator, earthshine on the dark side, and copper during a lunar eclipse. Choose black, faint real stars or the real sky behind it.

| ![The Moon, a waxing crescent with earthshine](docs/images/the-moon.jpg) | ![The Moon by day, on the Sky backdrop](docs/images/the-moon-day.jpg) |
|---|---|
| A waxing crescent with earthshine, among the real stars | Today's waning gibbous on the Sky backdrop, its dark side the sky's own blue |
| ![The Moon in the total lunar eclipse of December 31, 2028](docs/images/the-moon-eclipse.jpg) | ![The Moon beside NASA's Dial-a-Moon](docs/images/the-moon-vs-dial-a-moon.jpg) |
| The total lunar eclipse of December 31, 2028, previewed | Checked against NASA's Dial-a-Moon (left of each pair) for phase, libration, tilt and tone |

#### Deep Space Tour
Solar System Tour's sister, beyond the Solar System: slow pans and zooms across 95 of the best real photos of nebulae, star clusters, dying stars, galaxies, deep fields, and the only two black holes ever imaged, from Webb, Hubble, ESO, Euclid, the Rubin Observatory, Chandra and the Event Horizon Telescope. Real photos only: no artist's impressions or simulations. Each object comes with a caption and two facts, and Settings → Show holds the tour on one kind of object.

| <img src="docs/images/deep-space-tour.webp" alt="Deep Space Tour: the Pillars of Creation from Webb, moving" width="1600"> | ![Deep Space Tour: M87*, the first image of a black hole](docs/images/deep-space-m87.jpg) |
|---|---|
| The Pillars of Creation, from Webb | M87*, the first image of a black hole |

#### Nebula
A unique deep-space cloud on every load, in real nebula colors, dissolving into a new one every few minutes.

| <img src="docs/images/nebula.webp" alt="Nebula, Hubble palette, moving" width="1600"> | ![Nebula, Reflection palette](docs/images/nebula-reflection.jpg) |
|---|---|
| The Hubble palette | The Reflection palette |
| ![Nebula, Planetary palette](docs/images/nebula-planetary.jpg) | ![Nebula, Oxygen palette](docs/images/nebula-oxygen.jpg) |
| The Planetary palette | The Oxygen palette |

#### Galaxy
A spiral galaxy turning slowly, after a real one, with dust lanes, star clusters and pink star-forming knots.

| <img src="docs/images/galaxy.webp" alt="Galaxy, Whirlpool, turning" width="1600"> | ![Galaxy, Andromeda](docs/images/galaxy-andromeda.jpg) |
|---|---|
| The Whirlpool (M51) and its companion, in colors sampled from Hubble's portrait, turning at 4× speed | Andromeda, steeply tilted, with M32 and M110 beside it |
| ![Galaxy, Great Barred](docs/images/galaxy-barred.jpg) | ![Galaxy, Milky Way](docs/images/galaxy-milky-way.jpg) |
| NGC 1300, the Great Barred Spiral, with dust lanes along its bar | The Milky Way, seen face-on |

#### Black Hole
A black hole and the disc of glowing gas turning around it, seen nearly edge on in front of the real Milky Way, all of it bent by the hole's gravity. The far side of the disc lifts into an arch over the black shadow and its underside shows as a ring below, the side turning toward you is the brighter one, and the stars behind slide and double around the edge. None of that is painted: every pixel's ray of light is bent around the hole, and the disc glows by its temperature, as hot metal does. The sky is [ESO's panorama](https://www.eso.org/public/images/eso0932a/) of the Milky Way with over 100,000 real stars from the [HYG catalogue](https://codeberg.org/astronexus/hyg), which twinkle. In Settings, pick the disc's heat (orange, white-gold or blue-white), its size from small in a wide sky to a close-up, its brightness, glow and streaks, how fast it turns, and how bright the stars and the Milky Way are. Drift sets the whole sky turning slowly, as if you were circling the hole.

| <img src="docs/images/black-hole.webp" alt="Black Hole with an orange disc, turning" width="1600"> | ![Black Hole with a white-gold disc, small in a wide sky](docs/images/black-hole-wide.jpg) |
|---|---|
| The orange disc at its standard size, turning at 2× speed | White-gold, small in a wide sky, the Milky Way bent around it |
| ![Black Hole with a blue-white disc at twice the size](docs/images/black-hole-blue-white.jpg) | ![Black Hole close up, the orange disc wider than the screen](docs/images/black-hole-close.jpg) |
| Blue-white, at 2× | The close-up, at 3× |

#### Live Sky
The real sky above you: stars, planets, the Moon's phase, the Milky Way and the ISS. Deep blue by day. Settings can stand it on a landscape: a pine ridge, or the real skyline of Monument Valley, the Tetons, Shiprock, Devils Tower or Mount Fuji, worked out from elevation data and drawn at its true size among the stars.

| <img src="docs/images/live-sky.webp" alt="Live Sky at night over the pine ridge" width="1600"> | ![Live Sky at dusk](docs/images/live-sky-dusk.jpg) |
|---|---|
| Half past eight at night, looking south over the pine ridge, with the Milky Way setting in the south-west | Dusk over Monument Valley, one of the landscapes in Settings |

#### Earth from Orbit
The globe above your location with the live day/night line, today's real clouds, lightning in storms near you, city lights and the ISS.

| <img src="docs/images/earth-from-orbit.webp" alt="Earth from Orbit at night, over India" width="1600"> | ![Earth from Orbit by day, over North America](docs/images/earth-from-orbit-day.jpg) |
|---|---|
| City lights across India in the evening, the day going off to the west | Late afternoon over North America, under today's real clouds |

#### Pixel Spaceport
A pixel-art launch site that never stops, drawn like [Pixel City](#pixel-city) and lit by the same real Sun, seen from the bank across a lagoon. A rocket rolls out of the hangar lying on its transporter, climbs the ramp to the pad and is stood up, then fuels through a count you can follow on the countdown board on the near bank. It lifts off on a cloud of steam and arcs away, shrinking to a spark at the top of its trail. A little over a minute later its booster comes back, lights its landing burn, drops its legs and lands beside the pad, and a crane carries it off while the next rocket rolls out.

- **Fourteen rockets,** each with its own switch in Settings: Falcon 9 and Falcon Heavy, Starship, SLS, the Space Shuttle, the Saturn V, Gemini-Titan, Mercury-Atlas and Mercury-Redstone from the 1960s, and from abroad Ariane 5, Soyuz, Long March 5, Japan's H3 and India's LVM3. They are drawn to one scale, so a Saturn V stands as tall as the pad's tower and a Redstone not much taller than its floodlights. The countdown board names the one on the pad.
- **Four of them come back.** A Falcon 9's booster lands beside the pad, and a Falcon Heavy's two land side by side. Starship has a pad of its own: its tower's arms lift it onto the mount, and catch its booster when that flies back. A little later its ship comes home too: it falls on its belly, flips upright on its engines and lands on a landing zone. And two and a half minutes after a Shuttle launch its orbiter glides in to the runway along the shore, rolls out behind a drag chute and is towed away. Rockets whose boosters come back and rockets that fly once take turns, so a booster returns after every other lift-off.
- **Each flies as itself.** The big NASA rockets and Ariane roll out standing on a crawler; the Shuttle and SLS leave the thick white trail of their solid boosters; the Saturn V climbs slowly.
- **A tip of the hat:** when a rocket from abroad is on the pad, its country's flag goes up a second pole beside the Stars and Stripes: the French tricolour for Ariane 5, and Russia's, China's, Japan's and India's for the others.
- **How often:** a lift-off every four minutes or so, or anywhere from every two minutes to every twelve with the Launches slider.
- **The light is the real Sun's,** as in Pixel City, and you can choose which way you look or preview a time of day. A night launch lights its own steam, and for half an hour after sunset the trail still catches the Sun above a pad already in shadow.
- **All of it is mirrored in the lagoon,** the flames included.
- **It runs to its own clock,** unless you switch on Follow real launches in its Settings: then, in the ten minutes before a real lift-off of a rocket it draws, the pad is cleared for that rocket, the board counts the real time down and says LIVE, and it lifts off at the real T−0 (holds hold it; a scrub sends it back to the hangar). The schedule comes from [Launch Library 2](https://thespacedevs.com/llapi) by The Space Devs, a few KB about once an hour (see Privacy below); off, it makes no network requests. The rockets are drawn after the real ones, without names or logos on them; Atrium isn't affiliated with SpaceX, NASA or any other space agency or launch company.

![Pixel Spaceport's fourteen rockets on the pad, from Mercury-Redstone to Starship](docs/images/pixel-spaceport-fleet.jpg)

| <img src="docs/images/pixel-spaceport.webp" alt="Pixel Spaceport at sunset, Starship lifting off on a cloud of steam" width="1600"> | ![Pixel Spaceport at sunset, a Falcon Heavy's two boosters landing](docs/images/pixel-spaceport-double.jpg) |
|---|---|
| Starship lifting off at sunset | A Falcon Heavy's two boosters coming home |
| ![Pixel Spaceport by day, a rocket being stood up as a booster lands](docs/images/pixel-spaceport-day.jpg) | ![Pixel Spaceport after sunset, the trail lit pink above a pad in shadow](docs/images/pixel-spaceport-twilight.jpg) |
| The next rocket is stood up as the last one's booster lands | After sunset, the trail still in sunlight |
| ![Pixel Spaceport at night, a Falcon Heavy floodlit on the pad](docs/images/pixel-spaceport-heavy.jpg) | ![Pixel Spaceport at night, a booster on its landing burn](docs/images/pixel-spaceport-night.jpg) |
| A Falcon Heavy on the pad, nine seconds from lift-off | A booster on its landing burn at night |
| ![Pixel Spaceport at sunset, a Saturn V eight seconds after lift-off](docs/images/pixel-spaceport-saturn.jpg) | ![Pixel Spaceport by day, the Space Shuttle seven seconds after lift-off](docs/images/pixel-spaceport-shuttle.jpg) |
| A Saturn V at sunset | The Space Shuttle by day |
| ![Pixel Spaceport by day, an Ariane 5 on the pad with the French flag beside the Stars and Stripes](docs/images/pixel-spaceport-ariane.jpg) | ![Pixel Spaceport at night, SLS floodlit on the pad](docs/images/pixel-spaceport-sls.jpg) |
| An Ariane 5 on the pad, the tricolour up beside the Stars and Stripes | SLS floodlit at night |
| ![Pixel Spaceport by day, Starship on its own pad beside its tower](docs/images/pixel-spaceport-starship.jpg) | ![Pixel Spaceport at sunset, Starship's booster coming down to the tower's arms](docs/images/pixel-spaceport-catch.jpg) |
| Starship on its own pad | Its booster coming back to the tower's arms |
| ![Pixel Spaceport at sunset, Starship's ship swinging upright on its engines](docs/images/pixel-spaceport-flip.jpg) | ![Pixel Spaceport at sunset, Starship's ship coming down on a landing zone](docs/images/pixel-spaceport-ship.jpg) |
| Then its ship comes home: the flip | Down on its engines |
| ![Pixel Spaceport by day, the Shuttle's orbiter rolling out along the runway behind its drag chute](docs/images/pixel-spaceport-orbiter.jpg) | ![Pixel Spaceport at sunset, a Soyuz lifting off with Russia's flag beside the Stars and Stripes](docs/images/pixel-spaceport-soyuz.jpg) |
| The Shuttle's orbiter home, rolling out behind its drag chute | A Soyuz at sunset, its flag up beside the Stars and Stripes |

### Color, light and pattern

#### Flowing Gradient
Soft pools of color in six palettes, drifting from one palette to the next every few minutes on Random, with silk ribbons that follow the Sun if you turn them on.

| <img src="docs/images/flowing-gradient.webp" alt="Flowing Gradient in Dark Mode, moving" width="1600"> | ![Flowing Gradient in Light Mode](docs/images/flowing-gradient-light.jpg) |
|---|---|
| The Midnight palette in Dark Mode, with its silk ribbons | The watercolor Light Mode |

#### Lava Lamp
Wax that rises up the middle as round heads on stems that pinch off, sticks to the top a while, then sinks at the sides, lit by the bulb below. Seven jewel-tone palettes, with Light and Dark looks.

| <img src="docs/images/lava-lamp.webp" alt="Lava Lamp in Dark Mode, moving" width="1600"> | ![Lava Lamp in Light Mode, Teal palette](docs/images/lava-lamp-light.jpg) |
|---|---|
| Coral in Dark Mode | Teal, in Light Mode |

#### Schlieren
Rising heat as a color schlieren camera sees it, after the photos of Gary Settles, Andrew Davidhazy and Ted Kinsman. Warm air bends light, and the camera turns each bend into a color, so the two edges of a candle's plume glow in opposite colors as it rises, sways and curls into turbulence, in slow motion. It uses a real fluid simulation of the room's air. Pick candles, one taper, a mug of coffee or a radiator; a dark-field, rainbow, banded or knife-edge filter; and one of eight palettes, with the lab's round mirror as an option.

| <img src="docs/images/schlieren.webp" alt="Schlieren, candles in the dark field, moving" width="1600"> | ![Schlieren, one candle through a rainbow filter after Davidhazy](docs/images/schlieren-rainbow.jpg) |
|---|---|
| Candles glowing in the dark field | One candle through the rainbow filter, after Davidhazy |

#### Turing Patterns
Reaction–diffusion, the chemistry Alan Turing proposed for how animals get their spots and stripes. Patterns grow from a few glowing seeds, then slowly drift from coral to dividing spots to a honeycomb to fingerprint stripes and round again, in six jewel-tone palettes. Patches keep dissolving and growing back in, so it never stops moving, or it can swirl on a slow current instead.

| <img src="docs/images/turing-patterns.webp" alt="Turing Patterns, fingerprint stripes in Dark Mode, moving" width="1600"> | ![Turing Patterns, coral in Light Mode](docs/images/turing-patterns-light.jpg) |
|---|---|
| Fingerprint stripes in Dark Mode | Coral, glazed like ceramic, in Light Mode |

#### Game of Life
Conway's cells, reseeding so they never die out. The Calm look shows a long exposure, so cells melt into soft glowing blobs that drift slowly; the Classic look is crisp, quick and colorful.

| <img src="docs/images/game-of-life.webp" alt="Game of Life, Calm, moving" width="1600"> | ![Game of Life, Classic](docs/images/game-of-life-classic.jpg) |
|---|---|
| Calm | Classic |

#### Pixel City
A pixel-art city that follows your clock and the real Sun, with traffic and windows lighting up through the evening. Pick a city: the Waterfront, a downtown mirrored in the water with its walls lit from wherever the Sun is; Foothills, a small downtown under snow-capped mountains that hold the last of the sunlight; the Long Bridge, strung with lights across a bay; Hillside Town, tiled houses stacked above a harbour; the Overlook, out over a sea of rooftops; or the Airport, across a bay, where airliners land, taxi to the terminal and take off again into the real wind, mirrored in the water. It can move between them by itself every few minutes. You can also choose which way you look, so the Sun sets in view or lights the buildings from behind you.

| <img src="docs/images/pixel-city.webp" alt="Pixel City's Waterfront at dusk, moving" width="1600"> | ![Pixel City's Foothills on a clear morning](docs/images/pixel-city-foothills.jpg) |
|---|---|
| The Waterfront at dusk, the windows coming on | Foothills on a clear morning |
| ![Pixel City's Long Bridge at night](docs/images/pixel-city-bridge.jpg) | ![Pixel City's Hillside Town in the afternoon](docs/images/pixel-city-hillside.jpg) |
| The Long Bridge at night, strung with lights | Hillside Town in the afternoon |
| ![Pixel City's Overlook at sunset](docs/images/pixel-city-overlook.jpg) | ![Pixel City's Hillside Town at night](docs/images/pixel-city-hillside-night.jpg) |
| The Overlook at sunset | Hillside Town at night, its lamps in the harbour |
| ![Pixel City's Airport at sunset](docs/images/pixel-city-airport.jpg) | ![Pixel City's Airport at night](docs/images/pixel-city-airport-night.jpg) |
| The Airport at sunset, an airliner just down | The Airport at night |

#### Pixel Window Seat
The view from a window seat, in the same pixel art as [Pixel City](#pixel-city): on a flight that never lands, on a slow train, or on the space station, by **Window on** in its Settings. From the airliner, the land below is made up as you go and never repeats: ocean with ships and their wakes, coasts with surf and shallows, cities on their grids of avenues, farmland in sections, forest, rivers and highways, mountains that stand up in front of one another with snow on their crests, desert with red rock, dunes and dark blocks of orchard, and country under snow beside a sea of ice. Cloud comes and goes with the land, from a clear sky through scattered cumulus to a solid floor of cloud, and casts its shadows on the ground; now and then a far-off storm flickers with lightning. The Sun, Moon and stars are the real ones where you are, so you fly through your own dawn, day, sunset and night, when the cities turn to webs of orange and white lamps. The land slides past as it does from a real airliner, the near ground quicker than the far, and at a real flight's pace, or anything from half to ten times it in Settings. You can also hold it over one kind of country, pick how cloudy it is, turn the lightning off, sit over the wing or ahead of it, make the window smaller or take it away and have the view fill the screen, and choose which way it faces, so the Sun sets in it.

Set **Window on** to A train and the seat is in a carriage on a slow scenic line, rolling at 48 km/h (30 mph) through country made up as it goes: farmland with its trees, lanes, houses and villages, a lake beside the line, mountains, a city, a city across the water, snow and desert, one giving way to the next, or held on the one you pick. Everything slides by at its own distance, the trees by the track quickly and the far hills hardly at all, behind a line of poles whose wires rise and dip. The Sun, Moon and stars are the real ones, and so is the weather: it follows the report where you are, with haze, fog, overcast, rain that streaks the glass, falling snow and thunderstorms. Choose the carriage: a plain window, a sill and a curtain, or a table with a lamp that comes on as it gets dark, its reflection in the glass at night. Speed runs from half to ten times, and you can turn off the poles, the rain on the glass or the weather, hold the sky at one kind of cloud, or preview any weather and any time of day.

Set **Window on** to The space station and the window is on the International Space Station. The real Earth turns below at the station's own pace, an orbit every 93 minutes: three quarters of an hour over daylight, an orbital sunset, then city lights, moonlit cloud and the green line of the airglow, and a sunrise. The ground is NASA's Blue Marble and the lights its Black Marble, repainted in the wallpaper's own colors, and a solar array wing lies where the airliner's wing was, gold one day and its dark cells the next. Look out of the side, ahead or straight down, at half to ten times the real pace, or from the station's Cupola, its dome of seven windows facing the Earth:

- **Into the Cupola.** You float in the module above the dome and look down into it, the ground sliding by in the round window and the six panes around it.
- **From the Cupola.** Your head is in the dome, looking through a fisheye lens: the whole Earth is a disc behind the panes, with the Sun, the Moon and the stars beyond its edge.

The dome is modeled on NASA's photographs of the real Cupola, with its windows at their real sizes. Outside it hang a Soyuz, a Progress, the tip of a solar array and the round window's shutter; set Seat to Clear of it and they're gone. The two switches below work from the Cupola as they do from the window.

Two switches tie it to the real thing. Both are off until you turn them on:

- **Follow the real ISS.** The window looks down on the ground the station is crossing at this moment, in its real daylight or dark. Its position comes from [wheretheiss.at](https://wheretheiss.at) once a minute, and the wallpaper flies on in between. While it's on, Speed is held at the real pace. With it off, the station flies an orbit of its own with the real one's shape, at whatever speed you set, on a track that shifts 23° west each time round, so no two passes look down on the same country.
- **Today's real clouds.** In place of made-up weather, the cloud is today's: a satellite map of the whole Earth, redrawn every three hours (the one [Earth from Orbit](#earth-from-orbit) shows), so the fronts and storms lie where they really are.

With both on, the window shows roughly what the crew sees out of theirs right now.

| <img src="docs/images/pixel-window-seat.webp" alt="Pixel Window Seat over a coast, a city and farmland in the morning, moving" width="1600"> | ![Pixel Window Seat at sunset, looking west over a coast as the lamps come on](docs/images/pixel-window-seat-sunset.jpg) |
|---|---|
| A coast, a city and its farmland in the morning | Sunset, looking west, the lamps coming on |
| ![Pixel Window Seat over mountains in the early morning, forest in the valleys and snow on the far crests](docs/images/pixel-window-seat-mountains.jpg) | ![Pixel Window Seat at sunset over desert mountains](docs/images/pixel-window-seat-canyon.jpg) |
| Mountains in the early morning | Desert mountains at sunset |
| ![Pixel Window Seat over desert, a river with fields along it and a plateau of red rock](docs/images/pixel-window-seat-desert.jpg) | ![Pixel Window Seat over farmland and forest under snow](docs/images/pixel-window-seat-snow.jpg) |
| Desert, with a river and its strip of fields | Farmland and forest under snow |
| ![Pixel Window Seat at night over a city](docs/images/pixel-window-seat-night.jpg) | ![Pixel Window Seat at night, a far-off storm cloud lit from inside by lightning](docs/images/pixel-window-seat-storm.jpg) |
| A city at night, its avenues in orange and white | A far-off storm, lit by its own lightning |
| ![Pixel Window Seat above a deck of cloud with holes in it](docs/images/pixel-window-seat-clouds.jpg) | ![Pixel Window Seat over farmland under broken cloud](docs/images/pixel-window-seat-countryside.jpg) |
| Above a deck of cloud | Farmland under broken cloud |
| ![Pixel Window Seat over a city on a river at midday](docs/images/pixel-window-seat-city.jpg) | ![Pixel Window Seat at night, a city ending at the dark sea](docs/images/pixel-window-seat-coast-night.jpg) |
| A city at midday | Night, where a city meets the sea |
| ![Pixel Window Seat from the seat ahead of the wing, early in the morning over a coast](docs/images/pixel-window-seat-ahead.jpg) | ![Pixel Window Seat with no window, the sunset filling the screen](docs/images/pixel-window-seat-view.jpg) |
| The seat ahead of the wing, early in the morning | No window: the view alone, at sunset |
| <img src="docs/images/pixel-window-seat-train.webp" alt="Pixel Window Seat on a train, moving: mountains sliding past at dusk behind a table and its lit lamp" width="1600"> | ![Pixel Window Seat on a train through farmland by day, seen over a table and its lamp](docs/images/pixel-window-seat-train-countryside.jpg) |
| On a train: the mountains at dusk, from the table and its lamp | Farmland by day |
| ![Pixel Window Seat on a train beside a lake, the Sun's glitter on the water, with a sill and a curtain](docs/images/pixel-window-seat-train-lake.jpg) | ![Pixel Window Seat on a train passing a city at night, the lamp lit on the table](docs/images/pixel-window-seat-train-city.jpg) |
| A lake beside the line, from the carriage with a sill and a curtain | A city at night |
| ![Pixel Window Seat on a train in falling snow](docs/images/pixel-window-seat-train-snow.jpg) | ![Pixel Window Seat on a train in the desert late in the afternoon, the Sun low over red mesas](docs/images/pixel-window-seat-train-desert.jpg) |
| Snow falling over snow country | The desert, late in the afternoon |
| ![Pixel Window Seat on a train in the rain, drops on the glass and the lamp lit under a dark sky](docs/images/pixel-window-seat-train-rain.jpg) | ![Pixel Window Seat on a train in the mountains by day, through a plain window](docs/images/pixel-window-seat-train-plain.jpg) |
| Rain on the glass, and the lamp lit under a dark sky | The plain window, in the mountains |
| ![Pixel Window Seat on a train beside a lake by day, a city on the far shore behind trees, wharves and moored boats, the Sun's glitter on the water](docs/images/pixel-window-seat-train-city-water.jpg) | ![Pixel Window Seat on a train at dusk, a city across the water with its windows and the quay's lamps lit under pink cloud](docs/images/pixel-window-seat-train-city-water-dusk.jpg) |
| A city across the water, behind its shore of trees, wharves and moored boats | A city across the water at dusk, the quay's lamps coming on |
| <img src="docs/images/pixel-window-seat-orbit-live.webp" alt="Pixel Window Seat in Earth orbit, moving: Greece and the Aegean sliding past under the Earth's curved edge, real cloud over Italy, a gold solar array wing reaching out from the window's corner" width="1600"> | <img src="docs/images/pixel-window-seat-orbit-sunrise.webp" alt="Pixel Window Seat in Earth orbit, moving: city lights sliding past in the dark, then the Sun breaking over the Earth's edge and lighting the solar array gold" width="1600"> |
| Earth orbit, where the real station was at 13:19 UTC on October 10, 2026: south of Italy, looking over Greece under that day's real clouds | An orbital sunrise, at ten times the real speed |
| ![Pixel Window Seat in Earth orbit: the Earth's curved edge over Cuba and Florida under made-up weather, the gold solar array wing in the corner](docs/images/pixel-window-seat-orbit.jpg) | ![Pixel Window Seat in Earth orbit at night: city lights, the dark wing and the green line of the airglow](docs/images/pixel-window-seat-orbit-night.jpg) |
| Over Cuba and Florida, with its own weather | The southeastern United States at night, under the airglow |
| ![Pixel Window Seat in Earth orbit as dawn reaches the ground, the land red and orange under the gold wing](docs/images/pixel-window-seat-orbit-dawn.jpg) | ![Pixel Window Seat in Earth orbit over north India, the wing's dark cells up and snow along the Himalaya](docs/images/pixel-window-seat-orbit-himalaya.jpg) |
| Dawn reaching north India | The same country by day, the wing's cell side up |
| ![Pixel Window Seat in Earth orbit looking ahead along its track over the Mediterranean](docs/images/pixel-window-seat-orbit-ahead.jpg) | ![Pixel Window Seat in Earth orbit looking straight down on the Nile delta, a corner of the solar array below](docs/images/pixel-window-seat-orbit-down.jpg) |
| Looking ahead, toward Italy | Straight down on the Nile delta and Sinai |
| <img src="docs/images/pixel-window-seat-orbit-cupola.webp" alt="Pixel Window Seat in Earth orbit from inside the Cupola, moving: the dark Earth as a disc behind seven windows, city lights drifting across the panes, then the Sun rising over the Earth's edge in one pane and lighting the dome's copper rims" width="1600"> | ![Pixel Window Seat in Earth orbit from inside the Cupola by day: the Earth as a disc behind the round window and six panes, the Sahara in the middle and the Mediterranean coast toward the edge, a Soyuz and a Progress in the pane behind](docs/images/pixel-window-seat-orbit-cupola-day.jpg) |
| From the Cupola: an orbital sunrise, at ten times the real speed | From the Cupola by day, over North Africa and the Mediterranean |
| ![Pixel Window Seat in Earth orbit from inside the Cupola at night: city lights on the dark Earth in every pane, stars beyond its edge](docs/images/pixel-window-seat-orbit-cupola-night.jpg) | ![Pixel Window Seat in Earth orbit looking down into the Cupola from the module above: the Nile delta in the round window, desert and sea in the six panes around it](docs/images/pixel-window-seat-orbit-cupola-into.jpg) |
| From the Cupola at night, over the southeastern United States | Into the Cupola, over the Nile delta |

## Settings

The first time Atrium opens, a short welcome lets you try the wallpapers on your desktop and shuffle between them all (it's in Settings → About → Show Welcome any time after). Choose Settings… (⌘,) from the menu bar icon. Every wallpaper has a page, laid out like System Settings, with its palettes, photos, sliders, switches and menus (Fish Tank has none yet). The wallpaper runs live behind the top of its page, so each change shows as you make it. General holds Open at Login, Shuffle and Match the lock screen; Power sets the frame rate when plugged in, on battery and in Low Power Mode.

| ![Settings for Solar System Tour: a grid of worlds to hold the tour on](docs/images/settings-solar-system-tour.jpg) | ![Settings for Rain on Glass: ten real places and seven city-light palettes behind the glass](docs/images/settings-rain-on-glass.jpg) |
|---|---|
| Solar System Tour: hold the tour on one world, or let it roam | Rain on Glass: ten real places behind the glass, or city lights in seven palettes |
| ![Settings for Nebula: its palettes and how often a new nebula forms](docs/images/settings-nebula.jpg) | ![Settings for Dappled Light in Light Mode: the surface, which way the wall faces, leaf cover, weather and the light at night](docs/images/settings-dappled-light.jpg) |
| Nebula: seven palettes after real nebulae, or Random | Dappled Light, in Light Mode: the surface, the wall, the weather and the light at night |

## How it works

macOS has no public API for third-party live wallpapers. This app gives each display a borderless window at the desktop window level (`CGWindowLevelForKey(.desktopWindow)`). That puts it above the system wallpaper and below your desktop icons, on every Space, and it lets clicks pass straight through to the desktop.

It uses public AppKit and SpriteKit APIs only. It uses no private frameworks, makes no changes to system files, needs no SIP changes and doesn't inject code.

Each wallpaper is a SpriteKit scene. Many are full-screen Metal shaders written as `SKShader`s, and whatever can be drawn in code is: skies, water, wax, streaks of wind, starlings, reaction–diffusion, rising heat, and the pixel-art cities and rockets. Photos come in where they beat anything procedural: the reef's fish and corals, and the landscapes behind Weather, Aurora, Murmuration, Fireflies and Rain on Glass, all cut out of permissively licensed photos and relit; the scanned walls, floors and leaves of Dappled Light; the two tours' photos from spacecraft and telescopes; and NASA's maps of the Earth and the Moon. Live data comes over the network: the weather, the wind, the clouds, the ISS and the Sun.

It's kind to your battery:
- 60 fps plugged in, 30 fps on battery.
- In Low Power Mode it freezes on the current frame.
- Rendering pauses whenever the desktop is fully covered.
- Settings → Power changes each of these rates (Freeze, 15, 30 or 60 fps). For a demo on battery, choose Full Speed on Battery in the menu bar.

The lock screen, and the tint of the menu bar and windows, come from your normal system wallpaper, which Atrium only covers. To match them, turn on **Settings → General → Match the lock screen**: it sets your system wallpaper to a still of Atrium's, refreshed as it changes, and puts yours back when you turn it off or quit. One gap: after an Aerial screen saver, the lock screen shows the Aerial's last frame rather than the wallpaper, so pick another screen saver, or set it to start Never in System Settings → Lock Screen.

## Download

**[Download the DMG from Releases](https://github.com/dtanquary/atrium/releases)**, open it, and drag Atrium into Applications. It needs macOS 26 or later, on Apple silicon.

It's signed with a Developer ID and notarized by Apple, so it opens like any other app. Until 1.0 the releases are betas, marked Pre-release.

Open Atrium and a short welcome lets you try the wallpapers. After that it lives in the menu bar, with no Dock icon unless Settings is open. Bugs and ideas are welcome in [Issues](https://github.com/dtanquary/atrium/issues).

## Using it

Atrium's icon in the menu bar is a TV with sparkles (✨📺). Use it to:
- **Pick** a wallpaper from the grid of pictures: its name shows as the pointer passes over it. To move through them with the arrow keys, by typing a name, or with VoiceOver, set Settings → General → **Wallpapers in the menu** to Names, a list in words.
- **Pause** the wallpaper on its current frame, and **Resume** it. The icon dims while it's paused, a wallpaper you pick meanwhile is held still too, and quitting Atrium ends the pause. While Settings → Power is already freezing it (in Low Power Mode, unless changed), the menu says so in its place.
- Turn on **Shuffle** to move on to a random wallpaper every so often, and choose **Next Wallpaper** to skip ahead. Settings → General sets how often (every 5 minutes to every day, or on every unlock) and which wallpapers take part.
- Open **Settings…** (⌘,): a page for each wallpaper, with palettes, sliders and switches that update live, plus General, Power and About.
- Turn on **Open at Login**, here or in Settings → General. macOS may ask you to approve it in System Settings → General → Login Items.
- Turn on **Full Speed on Battery** to run on battery as fast as when plugged in.
- **Quit**.

### Updating and uninstalling

- **Update:** Atrium looks for a new version once a day. When there is one, it opens **Settings → Software Update** once, behind whatever you're doing (after that the menu bar menu offers it), with what's new and **Install and Relaunch**: Atrium downloads the files that changed (a few MB for most updates, not the whole app again), checks the result is signed by its developer, puts it in place of the old one and reopens. Your settings carry over. Turn off **Check for updates automatically** there to look only when you open that page. A copy built from source updates with `git pull && ./build.sh`.
- **Uninstall:** turn off **Open at Login** and **Match the lock screen** in Settings → General (the second puts your own wallpaper back), quit Atrium, and move it to the Trash. To remove its settings and caches too:

  ```sh
  defaults delete com.dtanquary.atrium
  rm -rf ~/Library/Caches/com.dtanquary.atrium ~/Library/HTTPStorages/com.dtanquary.atrium "$HOME/Library/Application Support/com.dtanquary.atrium"
  ```

### Privacy, permissions and network

Atrium has no account and no analytics. The services below are every connection it makes, each only while a wallpaper that uses it is running, apart from the check for updates.

- **Location** (optional). Live Sky, Earth from Orbit, Weather, Dappled Light, Wind, Pixel City, Pixel Spaceport, Pixel Window Seat, the live Moon, Rain on Glass following the weather and Flowing Gradient's time-of-day mood use your location, and the app asks once. If you decline, it guesses from your time zone. It's kept on your Mac, and only leaves it rounded to about a kilometer, as the place Open-Meteo forecasts for (and, for Wind's maps, as the tiles it asks NASA for).
- **Network.** Weather, Dappled Light, Rain on Glass and Pixel Window Seat's train (while following the weather) and Pixel City's Airport (while following the wind) fetch from [Open-Meteo](https://open-meteo.com) every 10 to 15 minutes, sharing one request. Live Sky and Earth from Orbit fetch the ISS position from [wheretheiss.at](https://wheretheiss.at) at most once a minute, and so does Pixel Window Seat in Earth orbit while Follow the real ISS is on. Earth from Orbit fetches a global cloud map from [Live Cloud Maps](https://clouds.matteason.co.uk) only once its cached copy is over 3 hours old (1.5 MB when it has changed), and not at all with Live clouds off; Pixel Window Seat fetches the same map only while its Today's real clouds is on. For lightning, it asks Open-Meteo for the next day's thunderstorms on a grid around you every 6 hours. Solar System Tour's live Sun, while it's on screen, fetches SDO images from [Helioviewer](https://helioviewer.org) at most every 15 minutes (2048 pixels, 0.3–0.5 MB) or 30 (4096, 1–2 MB, for the close-up), keeping the newest two of each wavelength on disk. None of them needs an API key. Weather, Dappled Light, Rain on Glass, Earth from Orbit and Wind have **Refresh Now** on their Settings pages, which fetches at once, at most every 5 to 15 minutes. Pixel Spaceport, while Follow real launches is on, asks [Launch Library 2](https://thespacedevs.com/llapi) by The Space Devs for the next few launches: about once an hour, and three times in the last twelve minutes before one it will fly (a few KB each; the free limit is 15 requests an hour per internet address, shared by every Mac on your network, so Atrium stays well under it). Nothing about you is in the request.
- **Updates.** Once a day, and whenever you open Settings → Software Update, Atrium asks GitHub's API for its latest releases (a few KB). Only when you choose Install and Relaunch does it download anything more: the files that changed since your version, from that release's disk image on GitHub (a few MB for most updates), or the whole image (about 400 MB) if that can't be done. Turn off Check for updates automatically there to stop the daily look.
- **Wind** asks Open-Meteo for the next day's hourly wind forecast on a grid around you every 6 hours, for the zoom on screen: 96 points for a town, 384 for a region or half the continent (Open-Meteo counts each point as one of its free 10,000 calls a day, so at most 1,536 a day). The last reply for each zoom stays on disk, so it works offline. With an Earth background it downloads NASA's imagery tiles for the view from [GIBS](https://nasa-gibs.github.io/gibs-api-docs/) once and keeps them: about 1–2 MB for most maps, up to 7 MB at night for half the continent, and a fresh 1–2 MB a day for the satellite view.

## Build from source

You need macOS 26 or later on Apple silicon, and Xcode 26 or later or its command line tools (Swift 6). It's developed and tested on macOS 27.

```sh
git clone https://github.com/dtanquary/atrium.git
cd atrium
./build.sh                 # release build → build/Atrium.app
open build/Atrium.app
```

`build.sh` runs `swift build -c release`, wraps the binary in a menu-bar-only `.app` (no Dock icon), copies in the data files, and signs it ad hoc for your own Mac. Move the app into `/Applications` if you like.

To rebuild after pulling changes: `./build.sh && pkill -x Atrium; open build/Atrium.app`

The notarized DMG on the Releases page comes from `./release.sh`, which needs a Developer ID (the setup is at its top).

## Development

```sh
swift build            # debug build
swift test             # renders every wallpaper offscreen to PNGs and prints each one's per-frame cost
SNAPSHOT_SCENE="Nebula" SNAPSHOT_DIR=/tmp/shots swift test     # one wallpaper
SNAPSHOT_DEFAULTS="gradient.palette=Sunset" SNAPSHOT_APPEARANCE=light swift test   # with settings, in Light Mode
SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_MOVIE=6 swift test       # then 6 seconds of frames at 15 fps, for a GIF
SETTINGS_SHOT="Nebula" swift test --filter settingsWindow   # opens Settings on that page for a moment and captures it
```

- **Tests.** The render test fails if a scene comes out as one flat color, for example a shader that didn't compile. The astronomy is checked against JPL Horizons, and the weather parser against a real Open-Meteo reply.
- **Adding a wallpaper:** create a file that returns an `SKScene` and add a `Wallpaper` entry in `Sources/Atrium/Scenes.swift`. Its settings are plain data on that entry. [`CLAUDE.md`](CLAUDE.md) covers the scene contract, the ~2 ms per-frame budget, and SpriteKit and shader pitfalls.
- **Layout:**
  - `Sources/Atrium/main.swift`: the app host (windows, menu, power and appearance handling)
  - `Scenes.swift`: the wallpaper list and shared helpers
  - `Settings.swift`: the Settings window
  - `Updater.swift`: the daily check for a new version, and Settings → Software Update
  - one file per wallpaper
  - `Resources/`: data files
  - `Tests/AtriumTests/`: the render, astronomy and weather tests
  - `docs/`: a doc for each wallpaper
  - `site/`: the website, [atrium.show](https://atrium.show)

## Credits

- Weather data by [Open-Meteo.com](https://open-meteo.com), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- ISS positions from the [Where the ISS at?](https://wheretheiss.at) API.
- Stars from the Yale Bright Star Catalogue, 5th edition (Hoffleit & Warren, CDS V/50), public domain.
- Constellation lines from [d3-celestial](https://github.com/ofrohn/d3-celestial) by Olaf Frohn, BSD 3-Clause. Its notice is kept in `Sources/Atrium/Resources/constellations.txt`.
- Earth imagery from NASA's Blue Marble and Black Marble, public domain.
- Clouds from [Live Cloud Maps](https://github.com/matteason/live-cloud-maps) by Matt Eason, CC0. Contains modified EUMETSAT data.
- The Wind wallpaper's shaded relief is from [Natural Earth](https://www.naturalearthdata.com), public domain, and its maps are NASA's Blue Marble Next Generation (with shaded relief and bathymetry), Black Marble, the Global Web-Enabled Landsat Data (NASA and USGS) and NOAA-20 VIIRS imagery from LANCE, public domain. We acknowledge the use of imagery provided by services from NASA's Global Imagery Browse Services ([GIBS](https://nasa-gibs.github.io/gibs-api-docs/)), part of NASA's Earth Science Data and Information System (ESDIS).
- The Moon's maps are from NASA's [CGI Moon Kit](https://svs.gsfc.nasa.gov/4720) (Ernie Wright, NASA Scientific Visualization Studio), public domain: LROC color and LOLA heights from the Lunar Reconnaissance Orbiter.
- Planet positions from JPL's [Approximate Positions of the Planets](https://ssd.jpl.nasa.gov/planets/approx_pos.html).
- Images of the Sun courtesy of NASA/SDO and the AIA, EVE, and HMI science teams ([terms](https://sdo.gsfc.nasa.gov/data/rules.php)), via the ESA/NASA [Helioviewer Project](https://helioviewer.org).
- The Weather wallpaper's hills are a public domain photo of Fort Ord National Monument by the Bureau of Land Management, its clouds are cut out of CC0 photos from Poly Haven and Wikimedia Commons, and its Moon is from NASA's CGI Moon Kit. See [`Sources/Atrium/Resources/weather-credits.tsv`](Sources/Atrium/Resources/weather-credits.tsv) and Settings → About.
- The Aurora wallpaper's mountains are a public domain National Park Service photo of the Tetons in winter by A. Falgoust ([source](https://commons.wikimedia.org/wiki/File:Teton_Point_Turnout_in_Winter_(52098766554).jpg)).
- The Murmuration wallpaper's grounds are "Tide bears the last glow - Brighton, UK" by sagesolar, CC BY 4.0 ([source](https://commons.wikimedia.org/wiki/File:Tide_bears_the_last_glow_-_Brighton,_UK.jpg)), with its sky cut away and its sea relit, and a public domain U.S. Fish and Wildlife Service photo of a tundra pond ([source](https://commons.wikimedia.org/wiki/File:Sunset_over_a_tundra_pond_(53708107535).jpg)).
- The Fireflies wallpaper's meadow is "Field at dusk" by Tristan Ferne, CC BY 2.0 ([source](https://www.flickr.com/photos/89056504@N00/7357684410)), with its sky cut away and relit for blue hour. See [`Sources/Atrium/Resources/fireflies-credits.tsv`](Sources/Atrium/Resources/fireflies-credits.tsv).
- Campfire (unfinished, and hidden for now): its clearing is the CC0 panorama "Hochsal Forest" by Adrian Kubasa ([source](https://polyhaven.com/a/hochsal_forest)), relit by the fire, with CC0 scans of a stone fire pit by Sebastian Platen and dry branches by Rico Cilliers from Poly Haven. See [`Sources/Atrium/Resources/campfire-credits.tsv`](Sources/Atrium/Resources/campfire-credits.tsv).
- The Rain on Glass backdrops are CC0 HDRIs from Poly Haven by Greg Zaal, Rico Cilliers, Alexander Scholten, Andreas Mischok and Oliksiy Yakovlyev, public domain photos from the National Park Service and USFWS, and CC BY photos from Wikimedia Commons by Douglas Paul Perkins, mariemon, epSos.de and Vyacheslav Argenberg. See [`Sources/Atrium/Resources/rain-credits.tsv`](Sources/Atrium/Resources/rain-credits.tsv) and Settings → About.
- The Dappled Light wallpaper's surfaces are CC0 scans from Poly Haven: "White Stucco", "Painted Plaster Wall" and "Patterned Clay Plaster" by Amal Kumar, "Whitewashed Brick" by Charlotte Baglioni and "Oak Wood Planks" by Dimitrios Savva; and from ambientCG, "Wood Siding 009" by Lennart Demes. Its leaves and twig are CC0 scans by Lennart Demes, ambientCG. See [`Sources/Atrium/Resources/dappled-credits.tsv`](Sources/Atrium/Resources/dappled-credits.tsv).
- A Tree for the Year (unfinished, and hidden for now): its hilltop is "Solitary tree at Cissbury Ring" by Andy Li, CC0 ([source](https://commons.wikimedia.org/wiki/File:Solitary_tree_at_Cissbury_Ring_2026-04-07.jpg)), with its own tree painted out; its oak leaves and bark are CC0 scans by Lennart Demes, ambientCG. See [`Sources/Atrium/Resources/tree-credits.tsv`](Sources/Atrium/Resources/tree-credits.tsv).
- Black Hole's Milky Way is ESO/S. Brunier's panorama, CC BY 4.0 ([source](https://www.eso.org/public/images/eso0932a/)), with its own stars taken out and their light spread into the glow; its stars are the [HYG database](https://codeberg.org/astronexus/hyg) v4.4 by David Nash, CC BY-SA 4.0, and the star file made from it stays under CC BY-SA 4.0. See [`Sources/Atrium/Resources/blackhole-credits.tsv`](Sources/Atrium/Resources/blackhole-credits.tsv). Its light-bending tables use three expressions from Eric Bruneton's [black_hole_shader](https://github.com/ebruneton/black_hole_shader), BSD 3-Clause; its notice is kept in `NOTICE`.
- Solar System Tour's photos are from NASA, JPL, ESA, JAXA, the Space Science Institute, JHUAPL/SwRI, NSO and the people who processed them, public domain, CC BY or CC BY-SA, with three from JAXA under the Japanese Government Standard Terms of Use 2.0 (compatible with CC BY 4.0). Each one's credit, license and source is in [`Sources/Atrium/Resources/solar-photos.tsv`](Sources/Atrium/Resources/solar-photos.tsv) and in Settings → About.
- Deep Space Tour's photos are from ESA/Hubble, ESA/Webb, ESO, NOIRLab, the Rubin Observatory, ESA's Euclid, NASA's Chandra and the Event Horizon Telescope Collaboration, CC BY 4.0, CC BY-SA 3.0 IGO or public domain. Each one's credit, license and source is in [`Sources/Atrium/Resources/deep-photos.tsv`](Sources/Atrium/Resources/deep-photos.tsv) and in Settings → About.
- Pixel Spaceport's rockets are drawn in code after the real ones, without names or logos. The times their strap-on boosters fall away come from ESA, ISRO, Spaceflight Now, Spaceflight101, The Planetary Society and Wikipedia, listed under Sources in [`docs/pixel-spaceport.md`](docs/pixel-spaceport.md#sources).
- Pixel Window Seat's Cupola is drawn in code from NASA's photographs of the real one ([S130-E-009694](https://images.nasa.gov/details/s130e009694) and ISS038-E-013587), with the window sizes ESA [published](https://esamultimedia.esa.int/docs/hsf_research/Climate_change_ISS_presentations/Cupola_Deloo.pdf).
- Reef fish, corals and rock in the Fish Tank are cut out of public domain, CC0 and CC BY photos from iNaturalist, Wikimedia Commons and NOAA. Each photographer and license is listed in [`Sources/Atrium/Resources/reef-credits.tsv`](Sources/Atrium/Resources/reef-credits.tsv) and in Settings → About.

## License

The code is [MIT](LICENSE) © 2026 Dave Tanquary. The photos and data aren't: each keeps its own license (public domain, CC0, CC BY, CC BY-SA or the Japanese Government Standard Terms of Use 2.0), listed under Credits, in the credits files beside them, and in Settings → About. Photos are cropped, cut out, relit or recolored from their originals, and adapted copies of CC BY-SA photos stay CC BY-SA. See [NOTICE](NOTICE).
