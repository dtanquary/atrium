# Rain on Glass

Looking through a rainy window, with the camera focused on the glass. Behind the glass is a real place, heavily defocused, or a procedural city of bokeh lights. Beads of water sit on the pane, and drops creep down in lurches, now and then run, and leave trails of pearls behind them. Each drop is a strong lens showing a sharp, upside-down view of the scene. Night in Dark Mode, an overcast day in Light Mode.

- **Files:** `Sources/Atrium/RainOnGlass.swift`, using the `shaderCommon` helpers from Shaders.swift (`hash42`, `noise`, `grade`…). Photos are `Resources/rain-<look>-near.jpg`, `-far.jpg` and `-haze.jpg`, credited in `Resources/rain-credits.tsv` and Settings → About.
- **Entry:** `@MainActor func rainOnGlass(size:)` picks the backdrop, and `rainScene(size:backdrop:clock:)` builds one of two `shaderScene`s, `rainPhotoScene` for a photo or `rainBokehScene` for the city, and runs the timer that fades to the next backdrop. Registry entry: icon `cloud.rain.fill`, tint `.gray`, `knobs: rainKnobs`, and a `PaletteChoice` titled "Backdrop" that lists the photos (with `photos:` thumbnails) and then the bokeh palettes.
- **Kind:** a single full-screen SKShader. The water is the same GLSL (`rainWater` and `rainDrops`) over every backdrop, animated by `u_clock`, which runs at the Drip speed.

## Backdrops
Ten photo backdrops, each with a night look for Dark Mode and a day look for Light Mode where a good one exists:

| Backdrop | Night | Day |
|---|---|---|
| Hamburg | Rathausmarkt in the rain (Poly Haven `rathaus`) | a warehouse canal (`hamburg_canal`) |
| Riomaggiore | a wet square with lamps (`vignaioli_night`) | the harbour between painted houses (`vignaioli`) |
| Japan | a Tokyo yokochō with lanterns (Commons, CC BY 3.0) | Hanamikoji in Gion, Kyoto (Commons, CC BY 3.0) |
| Forest | lit windows through bare woods at dusk (`pond_bridge_night`) | misty pines (`misty_pines`) |
| Countryside | lamps across a foggy field (`kloppenheim_04`) | a farm track into fog (`misty_farm_road`) |
| Winter | Blaubeuren's square with string lights (`blaubeuren_church_square`) | a snowy orchard (`snowy_park_01`) |
| Lake | Lake McDonald at dusk (NPS) | Lake McDonald under cloud (NPS) |
| Tropics | a palm-lined street at night (Commons, CC BY 2.0) | Cheow Lan Lake in low cloud (Commons, CC BY 4.0) |
| Cabin | a cabin's two lit windows in snow at blue hour (USFWS) | the same |
| Shanghai | the Bund's neon skyline (`shanghai_bund`) | the same |

The Poly Haven files are CC0 HDRIs; the rest are public domain or CC BY, with authors in `rain-credits.tsv`. The shortlist behind these (12 biomes, about 85 HDRIs and 25 photos judged blurred, not sharp) is in the session notes (`notes/rain-backdrops.md`). What mattered:
- **True HDR wins.** In an HDRI a lamp keeps its energy, so the blur spreads it into a bright disc. A photo tops out at white, so its lamps blur into dim grey smudges unless the bake lifts its clipped highlights.
- **Night beats day.** Many point lights over wet ground look best by far. A day view needs one big shape (a street, a canal, a lake, a ridge) or it turns into grey mush.
- **Aim away from walls.** A camera close to a wall blurs into a flat smear.

The seven bokeh palettes are the original look, drawn procedurally:

| Palette | Lights |
|---|---|
| City | sodium orange, warm white, red tail lights, cool LED blue, rare green (the original look, and still the default) |
| Neon | magenta, cyan, violet, electric blue, rare amber |
| Blue Hour | LED white, steel blue, warm windows, teal, rare red |
| Sunset | gold, rose, amber, lilac, rare cream |
| Harbor | aqua, warm white, green and red channel markers, sodium |
| Holiday | warm fairy lights, red, green, gold, rare blue |
| Graphite | whites and silvers only |

Random rolls any of the seventeen when the scene is built and, unless switched off, fades to another one every 10 minutes (see Settings).

## The bake
Each look is baked offline into three textures at a MacBook's 1512:982 aspect; the shader covers other screens by cropping. The script (`rain/bake.py` in the session scratchpad, about 80 lines of numpy) does:
1. **View.** From an HDRI: a rectilinear view of the equirect (yaw 0 is its middle, + turns right) at the yaw, pitch and horizontal FOV below. From a photo: a full-width crop at the given centre height, decoded to linear light, with near-white pixels lifted up to 7× (a squared ramp above 0.75) so their lamps bloom like real ones.
2. **near** (1024 wide): the view, area-downsampled and tonemapped. It's only ever seen small and upside down inside drops, so 4k HDRIs are plenty.
3. **far** (768 wide): a disc blur of the *linear* light, radius 3% of the width (bokeh discs about 9% of the screen height across, as a 30-40 cm pane at f/1.8 gives), with a soft edge and a slightly brighter rim, then tonemapped.
4. **haze** (128 wide): a Gaussian of sigma 0.2 screen heights, the glow a misted pane scatters light into.

Tonemap: `1 − exp(−x·exposure)`, then sRGB, JPEG at quality 90. Each look is about 150 KB; all 18 are 2.9 MB.

| Look | Source | yaw | pitch | hfov | exposure |
|---|---|---|---|---|---|
| hamburg-night | rathaus | −60 | 3 | 80 | 0.4 |
| hamburg-day | hamburg_canal | 4 | −5 | 70 | 1.0 |
| riomaggiore-night | vignaioli_night | 8 | 3 | 75 | 0.3 |
| riomaggiore-day | vignaioli | −12 | −10 | 70 | 1.2 |
| forest-night | pond_bridge_night | 150 | 3 | 75 | 0.6 |
| forest-day | misty_pines | 0 | 3 | 75 | 1.1 |
| countryside-night | kloppenheim_04 | 10 | 0 | 75 | 0.6 |
| countryside-day | misty_farm_road | −72 | 0 | 75 | 1.1 |
| winter-night | blaubeuren_church_square | −60 | 3 | 80 | 0.4 |
| winter-day | snowy_park_01 | 0 | 3 | 75 | 0.8 |
| shanghai-night | shanghai_bund | 35 | 3 | 70 | 0.5 |

Photos (crop centre height as a fraction of the photo, exposure): japan-night Yokocho.jpg 0.55, 0.7; japan-day Gion6550.JPG 0.55, 1.0; lake-night Lake McDonald and the Sprague Fire at Dusk 0.5, 1.0; lake-day Lake McDonald 0.5, 1.0; tropics-night Tropical City Streets at Night 0.5, 0.4; tropics-day Cheow Lan Lake 0.5, 1.0; cabin-night Cozy cabin at night 0.55, 1.0. The 1920-3840 px Commons downloads are plenty.

## The water
One model over every backdrop, in `p = v_tex_coord * vec2(aspect, 1)` (1 = the screen height). Its numbers come from measured footage of rain on a window (Frank Vincentz's Radevormwald clips, CC BY-SA, measured only) and droplet physics; see Research below.

1. **Sliders.** One per column 0.06 wide, in 70% of columns, radius 0.009-0.017. `travel(t)` is how far a column's slider has gone, stateless:
   - it creeps in bursts: every 8-25 s it lurches 4-9 times over 2-6 s, 5-12% of the screen in all, each lurch a fast start and a slow stop, then sits still
   - every 12-40 s it swallows a bead and runs 15-40% of the screen at about 1 screen height a second, starting at once and slowing to a stop
   - its height wraps from below the screen to above it (`1.12 − mod(travel, 1.4)`), so a new one slides in from the top
   - every slider in a column follows the same wavy track (`track()`: ±0.1 of the column's width either side of its middle, plus noise of ±0.01), as real drops reuse old wet tracks. Kept that close to the middle, a trail and its pearls never cross into the next column; only a big slider's body can, by up to 0.004, and pixels that close to a column's edge also draw the next column's slider (`sliderBody`).
   - it's a teardrop with a round front and a tail stretched 1.25× at rest to 2.75× at speed, pointing more as it speeds up
2. **When did it pass?** `sinceSlider(y)` finds when the column's slider was last at height y by searching its travel back in time (0.6, 1.8, 5.4 … 146 s, interpolated). That gives each point of a track an age:
   - **trail:** the track, 0.8 of the slider's width, stays clear of mist for 5 s, then mists over for 25 s
   - **pearls:** about one per slider radius down the track, a fifth of its width, fixed to the glass, for 2 minutes
   - **sweeping:** a bead is gone if its own column's slider has passed it since it landed, judged at the bead's middle so the whole bead goes at once
   - a faint wet line runs down every track
3. **Beads.** Two grid layers: cells of 0.04 (radius 0.0025-0.007, 60% full) and 0.09 (radius 0.008-0.022, 45%), sizes skewed small (`u²`). Each lands fully formed at a random moment and lasts 40-160 s unless swept. Big ones are up to 1.4× taller than wide, and lumpy (3 and 5 lobes of ±4.5% and ±2.5%) where their edge snags on dirt.
4. **Mist.** A layer of specks (cell 0.016, radius 0.001-0.002) that land and dry at random, faded out along fresh trails.

The water returns `drop` (position inside the drop on a unit disc, coverage, radius) and `wiped` (how clear of mist the glass is).

## Optics
- **The lens.** A drop is a plano-convex water lens. With a 60° contact angle, a ray at normalised radius `s` meets the surface at a slope `a` with `sin a = 0.866 s` and leaves bent by `bend = asin(1.333 sin a) − a` towards the drop's middle. So the drop shows the scene at that angle on the *opposite* side: upside down, and a wide patch of it (at half the radius, about ±0.25 of the screen). The bend doesn't depend on the drop's size. `u_fov` (0.9 rad, the photos' height) turns the angle into texture coordinates.
- **Sharp inside.** The drop's real image forms 5-10 mm behind the glass, inside the camera's depth of field, so drops sample `near`, not `far`.
- **The rim.** Past `s = 0.87` light from outside is totally reflected inside the drop and only the dim room shows: ×0.15 by day, ×0.05 at night, antialiased over a pixel. Transmission falls from 0.98 to 0.89 approaching it. No highlight is painted on: the bright crescent near a drop's bottom by day is the sky, flipped by the lens.
- **Mist.** Rain sits on the outside of the pane, and the sliders sweep an outside mist of drizzle. The fogged glass is `mix(far, haze, 0.3)` plus a faint room glow at night; swept glass shows `far` alone. Wiping removes the haze, not the camera's defocus, so trails keep the same bokeh.
- **Glitter.** At night each speck of mist holds a pinpoint of the brightest lights: 2% of pixels, scaled by how far `far` is above 0.4.
- **Over the bokeh city,** drops sample `city(…, 0.4)` rather than a sharp one, ×1.25 at night. The procedural city is mostly dark sky between its lights, so a sharp view left the drops as dark holes. The mist there is the city's own haze term, and trails still show `city(p, 0.45)`, as before.

## Time and appearance
The water runs on `u_clock`, the `shaderScene` clock for a `speed:` knob: `ShaderScene.update` adds each frame's time × the Drip speed, in Double, so moving the slider never makes the drops jump. It starts somewhere in its first 1000 s, so each build is a fresh pane. A backdrop fade hands the clock to the new scene, and both scenes keep running through the 4 s crossfade (`pausesIncomingScene` and `pausesOutgoingScene` off), so the water carries on unbroken and only the backdrop dissolves. Once the clock passes 8000 s (about two hours of water) the scene fades to a fresh pane of the same backdrop: the shader gets the clock as a Float, which only places a running drop to the pixel while it stays small.

The look follows the system appearance when the scene is built (the app rebuilds on a switch): a photo backdrop uses its `night` look in Dark Mode and its `day` look in Light Mode, and `u_night` (from the look's name) sets the rim, room glow and glitter. The bokeh city uses `u_day`: at night lights add on, and by day the sky is multiplied by `exp(-1.3 × (strength − 0.8 × tint))` and fogged glass lifts it toward white.

## Settings
- **Backdrop** (`rain.palette`, standard "City"): the photos as thumbnails of their defocused view, then the bokeh palettes as swatches. `PaletteChoice.photos` maps a name to its dark and light thumbnail; `title` names the section. A pick rebuilds the scene.
- **Fade to a new backdrop automatically** (`rain.fade`, on) and **Every** (`rain.fadeMinutes`, 1-60, 10): shown under the backdrops while Random is picked (their section is "Colors", which `RandomOnly` shows), like Aurora's. A 10 s `SKAction` timer checks them, so changes apply within 10 s; it counts from when the scene was built. Each display fades on its own, to its own pick.
- **Drops → Drip speed** (`rain.speed`, 0.25-3×, 1×): everything in the water (lurches, runs, landings, misting) runs this much faster or slower. Dave likes the default.
- **Look:** the shared grade sliders (`gradeKnobs("rain")`), live. Contrast pivots at 0.3 at night and 0.7 by day over the bokeh city, and 0.5 over photos.

Suggested knobs, not built yet:

| Key | Label | Range | Default | Drives |
|---|---|---|---|---|
| `rain.intensity` | Rain | drizzle-downpour | steady | bead shares, slider share, burst and run periods |
| `rain.mist` | Mist | 0-0.7 | 0.3 | the haze mix |
| `rain.glass` | Glass height | 12-35 cm | 20 | one scale on `p` for every size |

## Performance
Measured at CPU 0.5-0.65 ms and GPU 0.9-1.7 ms per frame over photos, and GPU 1.64-1.84 ms over the bokeh city (release build, 2x). The GPU numbers vary run to run by ±0.3 ms. The costly part is `sinceSlider` (seven `travel` evaluations), so it only runs for pixels on a slider's track and inside a bead near one. Running it for every bead pixel near a track cost 2.35 ms over the bokeh city.

## Gotchas and shortcuts
- `sliderDrop` returns a `mat3` (drop, then radius, wet line and trail clearness), because SKShader has no `out` or `inout` parameters.
- A trail's clear length is its slider's speed × how long it stays clear. At a minute clear, every column became a full-height ribbon; 5 s clear plus 25 s misting keeps them to the recent stretch.
- A pure sine wobble made the tracks look machined; `track()` uses noise.
- **Cut-off drops (fixed 2026-09-26):** Dave saw drops with one side sliced off along a vertical line. Two causes, both at the 0.06 columns: beads were swept by the slider of each *pixel's* column, so a bead straddling two columns could lose one half; and a slider's body could reach past its column, where the next column's pixels never drew it. Measured over four renders by counting long vertical runs of big pixel jumps: 36 at column edges against 4 mid-column before the fix, 8 against 6 after.
- `ponytail:` drops don't merge (no metaball): a slider swallows a bead by the bead vanishing when the slider reaches its middle.
- `ponytail:` the lens clamps at the photo's edge, so drops near the screen's edge stretch the edge colours.
- `ponytail:` Settings thumbnails read their JPEG on each redraw; they're small.
- The render harness has no `SKView`, so the backdrop fade (which calls `view.presentScene`) can't run there; it was checked with a throwaway test that shows the scene in a real window with the interval at 0.
- A test that writes `UserDefaults.standard` writes the `swiftpm-testing-helper` domain for good, and later test runs (the Settings shot too) read it back; clean up with `defer`.
- The water's motion is easiest to judge from a plot of `travel()` (as done for this pass) rather than from frames.

## Research
From the research agents (session notes `notes/rain-science.md` and `notes/rain-backdrops.md`), at a pane about 32 cm tall (1 mm = 0.0031 of the screen); this scene is scaled up about 1.6×, as if 20 cm of glass filled the screen:
- **Drops:** the biggest static drop, just before it slides, is 4-7 mm across (critical volume 7-19 µL on vertical glass, Quéré 1998). Sizes follow a power law, median about 1 mm; above about 2 mm they're lumpy.
- **Movers:** creepers at 2-15 mm/s in lurches of 0.12-0.3 s with pauses of 0.3-3 s; runners at 3-28 cm/s, which travel 3-7 cm and stop; gushes at 0.5-1 m/s that leave a rivulet breaking into beads within 0.5 s (not built).
- **Trails:** beads a fifth of the slider's width, every half to one width, fixed to the glass for 30-120 s.
- **Impacts:** 40 (light), 140 (steady), 250 (heavy) per screen² per second; a new drop appears fully formed.
- **Optics:** a drop by day is dark on top (0.3-0.45 of the glass beside it) and bright below (1.5-2.5, peaking 70-85% down), measured over 170 drops. At night it holds pinpoint specks of the lights, and fine mist glitters near lamps.
- **Techniques:** Heartfelt (BigWings, CC BY-NC-SA, so technique only) and Lucas Bebber's Codrops rain; Kaneda et al. 1993/1999 and Tatarchuk 2006 (ATI ToyShop) for lattice-based droplet flow.

## Dave's feedback and decisions
- Built in the first "build out all of those ideas" batch by the shaders agent. When that batch landed it was judged the weakest shader scene: the drops don't stand out much.
- 2026-09-24, Dave: "raindrops is great". He asked for colour palettes in Settings, with a default that follows Light or Dark Mode, "then allow a bunch of other color pallets". Hence City as the default, and every palette with both a night and a day look.
- 2026-09-26, Dave: "add more background options to rain on glass. I want to keep what we have as like a bokeh option but lets add other potentially popular options like a rainy city backdrop (but blurry) or country side or cottage", researched across biomes, plus "any other ideas you might have on how to level up this wallpaper". Hence the ten photo backdrops, and the water and lens rebuilt from research, with a Classic switch to compare.
- 2026-09-26, Dave: "new drops are so much better ditch the classic drops". The switch and the old water are gone (they're in git history at 0.24.0). He also asked for a timed fade to a new backdrop on Random, with the interval configurable, and "a drip speed setting that can apply some overall modifier to make drips go faster or slower, i like the current default though".

## Ideas / next steps
- **Rain knob:** drizzle to downpour, driving bead shares, slider count and burst timing; and gushes (rivulets that bead up) in heavy rain.
- **Real weather:** rain only when it's raining where Dave is, at the real intensity (reuse `WeatherScene`'s Open-Meteo report), and day or night from the real Sun rather than the appearance.
- **Merging:** metaball drops, so a slider visibly swallows beads and grows.
- **Living backdrops:** passing headlights along a photo's road, a lit window going dark, a rare distant lightning flash that lights the whole scene.
- **Focus pull:** every few minutes the focus drifts from the glass to the street and back: drops blur into soft discs as the scene sharpens. Real rain footage does this, and it needs no new art (the `near` texture is the sharp scene).
- **Condensation:** a breath of fog on the inside of the pane that slowly clears, or a finger-drawn smiley.
- **More places:** a café across the street, a station platform, a harbour village (Bernd Thaller's Croatian village), Shibuya in the rain.

## Checking it
`SNAPSHOT_SCENE="Rain on Glass" SNAPSHOT_DEFAULTS="rain.palette=Hamburg" SNAPSHOT_APPEARANCE=light SNAPSHOT_DIR=/tmp/rain swift test`, then read the PNG. For motion, `SNAPSHOT_MOVIE=8` and compare a crop across frames, or plot `travel()` in Python.
