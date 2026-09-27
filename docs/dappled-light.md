# Dappled Light

Sunlight through a tree onto a warm white plaster wall (komorebi), lit by the real Sun where the viewer is. The light only falls when the Sun is on the wall's side and above the horizon, golden near sunset, gone at night but for faint moonlight at the real phase or a warm streetlight. The live weather softens it under cloud and sets how much the leaves sway. It's the first wallpaper made for Light Mode; in Dark Mode the wall is charcoal.

- **Files:** `Sources/Atrium/DappledLight.swift` (the scene, its textures and its shader). `Resources/dappled-*`: the plaster as three greyscale HEICs, a leaf atlas and one twig, credited in `dappled-credits.tsv`. It uses `SkyMath.swift` for the Sun and Moon, `Location.swift`, `LiveWeather.swift` for cloud and wind, `Atmosphere` (WeatherSky.swift) for the colour of sunlight through the air, and `CloudNoise` for smooth noise.
- **Entry:** `dappledLight(size:)` builds `final class DappledLight: SKScene`. Its entry in Scenes.swift is "Dappled Light", icon `leaf.fill`, tint `.green`, with `DappledLight.knobs` and Weather's status line (`weather.status`) under its Weather menu.
- **Kind:** one full-screen shader over baked textures; the light is worked out on the CPU once a second.

## How it works
- **The wall:** 2.4 m of wall across the screen whatever its size, facing one of eight compass points (Settings). Its frame is (right, up, out) as seen standing in front of it. Every second `light()` turns the Sun (or the Moon or a lamp) into that frame: `from`, a unit vector whose `z` is the cosine of the angle the light meets the wall.
- **Pinhole physics:** every gap between leaves is a pinhole camera, so each bright spot is an image of the Sun: its diameter is 0.0093 × the gap's distance from the wall along the ray (the Sun spans 0.53°), and it's an ellipse on the wall, longer by 1/cos(incidence) along the way the light travels. The shader works in *sky offset*: `u_proj` turns metres on the wall into how far (in Sun radii) the direction a point sees through a gap is from the Sun's centre, per metre of path. In those coordinates every image is a round disc of radius 1 whatever the angle, so the stretch, the size and the eclipse all come for free, and the lookups stay cheap.
- **Layers of the tree**, each shifted by the Sun as a shadow of something that far out from the wall would be (`shift`, depth × tan): so as the Sun crosses the sky the shadows crawl across the wall, the near twig least.
  - **The far crown, 5 m out:** its shadow is a soft mass (the canopy texture's green, clumps of real leaves blurred by the 2 cm the Sun blurs them at that distance), and inside it the gaps make round dapples (`pinholes`): a gap in 22–62% of the 2 × 2 cells of sky offset (more toward the crown's edge), 3 × 3 cells searched, each gap 3.3–7.3 m out (so its image is 0.65–1.45 radii across). Each image is a limb-darkened disc (1 − 0.6(1 − μ)), blurred by the gap's own size (Minnaert: "for a hazy picture the size of the aperture must be added"). Physically a gap's image is as bright as the gap's area over the image's, so pinholes make dim spots; photos show the visible dapples at 0.7–1.6 times the median spot, so each gets a brightness from 0.2 to 1 of full sun, independent of its size, and overlaps add. The first version was dapples alone, a field of polka dots; the reference photos showed they only appear inside the crown's shade, among leaf shadows.
  - **Sprays of leaves, 1.2 m out** (the canopy texture's red): twigs off a few wandering branches, real leaves set alternately along each twig and one at its tip. Their shadow is blurred over the source's image with seven taps (`u_blur` maps sky offset back to the wall, so the blur is the right ellipse), each tap dropped where the Moon covers the Sun, so an eclipse bites their soft edges too. The texture is pre-blurred by a texel so thin twigs don't ghost into double lines between the taps. Turning the tap pattern per pixel hid the ghosting too, but cost 2.2 ms of GPU by thrashing the texture cache.
  - **A twig near the wall, 0.25 m out:** ambientCG's forked twig with three serrated leaves, a sharp shadow hanging into the top right, swaying about its base. Its place is fixed when the scene is built, so it starts on screen and then drifts with the Sun.
  - The canopy texture (1024², 3 m square, tiling) is laid out afresh each launch from one kind of tree: maple, oak or beech.
- **Light and colour:** sunlight is `Atmosphere.sunlight` squared (twice the path, since the low air is hazier than the model's clean air; single strength gave a pale yellow sunset where photos are amber), times a fade from 0.12 down to 0.02 of the cosine so grazing light fades out rather than stopping at an edge. Skylight is blue by day (0.8, 0.88, 1) at 0.075·√(sin h + 0.02), paler blue through twilight, down to the glow of towns (3e−7 of the Sun). Sunlight bounced off the ground adds 0.05·(1 − sin h)³ of it to the shade, which warms it at golden hour, when photos show warm shade, and leaves it blue by day. The plaster's grain is lit by its normal map, so a low Sun rakes across it. The shade gets 20% less skylight under the densest crown (very smooth noise, since the sky is a huge source).
- **Exposure:** the eye adapts: the wall's brightness follows the light only as its 0.18th power, and dims a further 50% at night. It's worked out from the light before clouds, so a cloud passing still dims the wall, as it does to the eye. Tone-mapped like Weather: `sqrt(1 − exp(−x))`.
- **Night:** below 1.5° under the horizon the source becomes the Moon, 2.5 millionths of sunlight at full, falling off as the lit fraction to the 2.5; each gap's image is then the Moon's own phase (`u_src.w` is the cosine of the phase angle, `u_term` points to the bright limb), and the colours shift blue (the Purkinje shift). With Streetlight chosen, a sodium-orange lamp (1, 0.55, 0.2) up to the left instead, 0.8° across (a 20 cm globe 12 m away), on from 1.5° to 4° below the horizon, with only a third of the blue shift. Lamplight is bright for its size, so the eye dims a further 25% under it; before that the lamplit wall looked like a dull afternoon.
- **Dark Mode** (`systemIsDark`, read when the scene is built; the app rebuilds it when the appearance changes): the same stucco in charcoal, (0.060, 0.066, 0.074) in linear light, the colour of Poly Haven's Plastered Wall 05, in exactly the same light. Sunlit patches reach a warm mid-grey (about sRGB 137, 123, 103 at 4:30 pm) over near-black shade, as on the dark walls in the reference photos (lit #64605b over #1c2119); at golden hour the wall goes copper. By night a charcoal wall would be black, so in Dark Mode the sky's glow on it is five times as strong (only the ambient light: boosting the exposure instead lit the streetlight to daylight).
- **Eclipses:** by day `light()` places the Moon over the Sun as seen from here (topocentric, `Sky.moon(_:latitude:longitude:)`, good to 10″; the low-precision series it replaced was 10–30 minutes out and missed totality). While the discs overlap, `u_src` holds the Moon's offset and radius in Sun radii, every dapple becomes the same crescent (flipped through its gap), the soft leaves' taps drop the covered part, and the light dims by the area covered. At annularity every spot becomes a ring. The Moon at night, or the lamp, shows no eclipse. Preview an eclipse fakes a 70% one.
- **Weather** (`LiveWeather`, shared with Weather): clear (codes 0–1 under 30% cloud) keeps the Sun out; broken cloud (code 2, 0–1 over 30%, and showers 80–82) sends it in and out, for as much of the time as the sky is covered, on a 70 s value noise, the dapples blurring into shade as the cloud thickens (`u_wind.z`); anything else (overcast, fog, drizzle, rain, snow, storms) is diffuse light only, grey and even. Wind sways the branches: 1 cm at 10 km/h, growing as wind^1.4 up to 5 cm, in gusts (a 12 s noise), at 0.14–0.43 Hz in two sines per axis with a phase that varies over the wall. Above 5 km/h two in five dapples start to blink (flutter), up to 35% by 20 km/h. The twig turns by up to 0.7° at 10 km/h. Research: branch modes are about 1 Hz and whole trees 0.15–0.5 Hz; leaf flutter is 3–8 Hz. Real flutter at 3–8 Hz looked like flicker, so the blink is 2.4–5.6 Hz and small.

## Settings
| key | label | range | default | drives |
|---|---|---|---|---|
| `dappled.facing` | Wall faces | South … South-east (8) | South-west | the wall's frame; south-west gets the afternoon and a golden, oblique sunset |
| `dappled.cover` | Leaf cover | 0–1 | 0.5 | the crown's threshold and the sprays' weight |
| `dappled.twig` | Leaves near the wall | switch | on | the twig |
| `dappled.weather` | Weather | Live, Clear, Partly cloudy, Overcast | Live | `conditions`; Weather's status line shows under it while Live |
| `dappled.night` | At night | Moonlight, Streetlight | Moonlight | the night source |
| `dappled.sway` | Sway | 0–3× | 1× | sway, flutter and the twig's swing |
| `dappled.previewTime`, `dappled.previewHour` | Preview a time of day, Time | switch, 0–24 h | off, 13:00 | `now` |
| `dappled.previewEclipse` | Preview an eclipse | switch | off | a 70% partial eclipse |

Any change re-runs `light()`; nothing rebuilds.

## Tuning constants
- Wall 2.4 m across; crown 5 m out, sprays 1.2 m, twig 0.25 m; path length clamped at cos 0.25.
- Pinholes: a gap in a cell when `h.z > 0.78 − 0.4·open`, radius (0.1 + 0.3·h.z)·(0.5 + 0.5·open) of the image, brightness 0.2–1.
- Exposure `1.8·(L/0.33)^−0.82/0.33`, × (1 − 0.5·night).

## Performance
- Release build, 2x, 1512×982, 2026-09-26, with other sessions' tests running: 0.41–0.54 ms CPU, 0.57–0.99 ms GPU. The dapples cost most: nine gap images per pixel inside the crown.
- Textures: the plaster 16 MB (2048² RGBA), the canopy 4 MB; both built once per launch, shared by every display and the Settings preview.

## Gotchas and shortcuts
- `ponytail:` **the lamp is at infinity.** A real streetlight's rays spread about ±7° across the wall; here they're parallel.
- `ponytail:` **a bigger source means fewer, bigger gaps.** The gaps are laid out in sky offset, so the lamp (3× the Sun) gets a coarser crown. Pinholes fixed in the tree would be better if the lamp ever matters.
- `ponytail:` **the gaps' layout follows the light.** Hashing the gaps in sky offset means the lattice slowly shears as the Sun moves; at a few mm a minute beside the Sun's own 2 cm drift it can't be seen.
- **Don't randomise texture lookups per pixel** (see the sprays above): 2.2 ms.
- The plaster is three greyscale HEICs packed into one texture at load: a colour HEIC's 4:2:0 chroma wrecks packed channels (correlation 0.33 back), and the PNG is 8 MB.

## Checked against real photos
A research agent gathered 44 reference photos of leaf shadows on walls (scratchpad `dappled/reference`, with `measurements.json`), and measured them in linear light: lit and shade colour, their ratio, lit fraction, dapple size, ellipticity, edge softness and spot-to-spot brightness. The same `measure()` runs on renders, so they compared number for number, 2026-09-26 (a clear 4:30 pm on a south-west wall at 40°N):

| | photos (median) | render |
|---|---|---|
| lit / shade, linear light | 7.7 midday, 4.1 golden | 5.4 at 4:30 pm; 3.8 at 1 pm, when the light is oblique |
| shade's blue, (B/R shade) / (B/R lit) | 1.42 midday, 1.07 golden | 1.5 |
| dapple size / frame width (area-weighted) | 0.035 | 0.030 |
| edge 10–90% / spot diameter | 0.17 | 0.14 |
| spot brightness, p10–p90 of median | 0.72–1.57 | 0.73–1.38 |
| lit fraction | 0.35 in dapple photos, 0.66 with near leaves | 0.55 |

The shade is kept a little lighter than the photos (whose own highlights clip, so their ratios understate), since calm here means soft. Before calibration the ratio was 3, every dapple equally bright, and three times too many of them.

What the photos showed besides:
- The wall is mostly lit, crossed by recognisable leaf and branch shadows; round dapples appear inside the denser shade, not as a field of their own. The first render was all dapples.
- Shade on a white wall is blue-grey; sunlit plaster is warm; at golden hour the light is deep amber and the shadows lavender.
- Near leaves are crisp, far ones melt into soft masses.

## Dave's feedback and decisions
- **The brief** (2026-09-26): the real sun at his location, a wall-facing knob, light that follows the Sun's height, moonlight at the real phase or a warm streetlight, a time preview; pinhole images of the right size and stretch, sharp near leaves and soft far ones, crescents in a real eclipse; cloud softening the dapples and wind setting the sway; compared with photos side by side; "calm means soft and dim too".
- **Dark Mode** (2026-09-26): shown the same scene at 4:30 pm on a white wall exposed down like a dim room, charcoal plaster, dark green plaster and terracotta, and the night look, beside reference photos of dark walls, he picked charcoal plaster (my recommendation: it keeps the real light and the physics).

## Ideas / next steps
- A Wall menu (white, charcoal, dark green, terracotta), if Dave wants the other looks back; the tint is one uniform.
- Poly Haven's own charcoal render (plastered_wall_05, prepared in the scratchpad) in place of the tinted stucco, for its coarser grain.
- Rain: wet plaster darkens and goes glossy, and drips run down it.
- Seasons: bare branches in winter, autumn colour showing through the leaves' light.

## Checking it
- `SNAPSHOT_SCENE="Dappled Light" SNAPSHOT_DEFAULTS="dappled.previewTime=1,dappled.previewHour=16.5,dappled.weather=1" swift test` renders a clear afternoon on a south-west wall at the test's fallback location (40°N, 90°W). Try 13 for midday, 18.3 for golden hour, 19 for dusk, and 22 with `dappled.night=1` for the streetlight. Add `dappled.previewEclipse=1` for crescents, and `SNAPSHOT_APPEARANCE=light|dark` for the white or charcoal wall. The layout of leaves is random each launch, so roll a few for screenshots.
- `swift test --filter eclipsesLineUp` checks the Moon against four real eclipses.
