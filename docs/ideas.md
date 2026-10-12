# Wallpaper ideas

Ideas for new wallpapers, kept here so they aren't lost. They came out of a brainstorm with Dave on 2026-10-10, aimed at what has worked so far: real data, photoreal, soft and dim, and engines the app already has. Three were picked that day and have been built ([Built](#built)). **None of the rest is researched.** Every data feed, licence and cost under Parked is a guess to check before a build, and a big one starts with mock-ups for Dave to pick from.

When one is picked, it gets its own doc, and that doc is where it is kept from then on.

## Built
Picked by Dave on 2026-10-10, researched and mocked up that day, and built on 2026-10-11 and 12. All three are in the app and hidden: they show only with the `unfinished` switch on (`defaults write com.dtanquary.atrium unfinished -bool true`), until Dave has judged them on his own screen. Each one's doc has what was built, what was measured, what is still wrong and what stands between it and being unhidden.

- **Black Hole.** A lensed accretion disc slowly turning, bending the real Milky Way and catalogue stars behind it; one shader, beside Nebula and Galaxy. Three disc colours, a size slider from a small hole in a wide sky to a close-up wider than the screen, stars that twinkle and a sky that can drift. A wallpaper of its own: [black-hole.md](black-hole.md).
- **Pixel Night Train.** A ground-level window seat: country sliding past on the real clock, with rain on the glass when it rains where you are. Dave picked it as an addition to [Pixel Window Seat](pixel-window-seat.md) rather than a wallpaper of its own, so it is that wallpaper's third window ("Window on: A train"), with three carriages and seven sceneries: [pixel-window-seat/train.md](pixel-window-seat/train.md).
- **Meander.** A river migrating across its floodplain, cutting off oxbows and leaving scroll bars, drawn as lidar relief or as an old map after Harold Fisk's 1944 sheets of the Mississippi (US Army Corps of Engineers, public domain). A new river on each load, in one colour family. A wallpaper of its own: [meander.md](meander.md).

## Parked
In the order they were proposed, most promising first.

- **Valley Fog.** Layered photo ridgelines at dawn with fog flowing slowly between them, lit by Weather's sky. The same cut-out-and-relight approach as Aurora and Weather. It could thicken with the live humidity. The softest, dimmest idea here, which is what Zen Garden wasn't.
- **The Planets, live.** Jupiter as a telescope shows it now: NASA maps lit by a shader, as The Moon does, with the four big moons and their shadows in their real places. Jupiter turns in under ten hours, so it is visibly alive. Saturn with its real ring tilt and Mars could follow. It would nest in Solar System Tour beside The Moon and The Sun.
- **Earth Today.** Real full-disc photos from the weather satellite over the user's hemisphere, played as the last day's loop, as The Sun does with SDO's. NOAA's GOES images are public domain and come every ten minutes; cover and licences outside the Americas (Himawari, Meteosat) need checking. It could nest in Earth from Orbit.
- **Open Sea.** Ocean to the horizon under Weather's sky, with the real Moon and its glitter path, and swell (height, period, direction) from Open-Meteo's marine feed for the nearest coast. The risk is water that looks real inside the 2 ms GPU budget. A night shore with glowing surf could be one of its looks.
- **Cloud Chamber.** Particle tracks condensing in mist: short fat alphas, thin wandering betas, straight muons, in their real proportions, with a slider for how busy it is. Cheap to draw, and it belongs with Schlieren, Turing Patterns and Game of Life. Crystals showed that correct physics doesn't make a thing pretty, so it needs mock-ups first.
- **Ink.** Suminagashi: rings of ink floating on water, slowly stirred. It is flat by nature, so Schlieren's fluid solver is physically right for it. Flowing Gradient's and Lava Lamp's family, with palettes. Incense smoke on black is a near relation on the same solver.
- **Snowfall.** Fireflies' engine (a photo ground, particles in depth, fog, wind) with snow in a forest at blue hour, or under a lamp. It could follow the live weather.

## Smaller than a wallpaper
- **Ocean currents in Wind.** A second flow on the same engine. Open-Meteo's marine feed may carry current speed and direction: unverified.

## Left out on purpose
- **Jellyfish, koi, a fish school:** big animals, or nearly. Photo cut-outs of big animals never moved convincingly in the Fish Tank's Ocean Voyager and Shallow Reef, cut on 2026-10-07. Jellyfish would have to be drawn by a shader, not cut out, to be worth another try.
- **Soap film:** its interference colours are the ones that went olive once Crystals was dimmed for calm.
- **Ferrofluid, sand patterns (Chladni figures):** bright and sharp, as Zen Garden was.
- **A fireplace or a candle:** Campfire is still unfinished; fire comes after that one works.
- **Live flights, live lightning, earthquakes:** as far as I know (unchecked) the flight and lightning feeds restrict reuse, and earthquakes are too sparse to be lively. Pixel City's Airport and Earth from Orbit's storms already cover the first two.
