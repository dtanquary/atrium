# The Moon

A full-screen, photoreal Moon as it is right now from where the viewer stands: its real phase, libration (the monthly wobble that shows a little more of one limb, then the other) and tilt, sized by its real distance, and turned as the sky turns so the viewer's zenith stays up. It's lit the way the Moon's dusty ground reflects light, so the full moon is flat, with no limb darkening, and brightens in its last day before full (the opposition surge). Crater shadows along the terminator come from real LRO heights. Earthshine lights the dark side, strongest near new moon, and on the night of a real lunar eclipse the Moon turns copper in the Earth's shadow.

- **Files:**
  - `Sources/Atrium/TheMoon.swift`: the scene (`TheMoon`), the offscreen bake (`MoonBaker`), and the Moon's geometry as an `extension Sky` (`moonAxes`, `moonView`, `MoonView`, `earthShadow`).
  - `Sources/Atrium/Resources/moon-colour.heic` (1.3 MB), `moon-east.heic` (1.1 MB), `moon-north.heic` (0.8 MB) and `moon-height.heic` (0.3 MB): the near side at 16 pixels a degree, 3200×2880. See Data below.
  - `Tests/AtriumTests/MoonTests.swift`.
  - The Moon's position comes from `Sky.moonPosition` and `Sky.moon(_:latitude:longitude:)` in `SkyMath.swift` (Meeus ch. 47, about 10″), the Sun from `Sky.sun`, and the sky from Weather's `Atmosphere` in `WeatherSky.swift`.
- **Entry:** `theMoon(size:)` builds `final class TheMoon: SKScene`. Its entry in Scenes.swift is "The Moon", right after Live Sky, icon `moonphase.waxing.gibbous`, tint `.gray`, `knobs: TheMoon.knobs`.
- **Kind:** a baked shader. `MoonBaker` renders the lit Moon with an SKShader into a texture through its own `SKRenderer`, and the scene shows it as one sprite.

## How it works
- **Geometry** (`Sky.moonView`), all in J2000 equatorial vectors:
  - The Moon from the viewer, topocentric (parallax moves it up to 1° and changes the libration by up to 1°), and its distance.
  - The Moon's body axes (`Sky.moonAxes`), by Cassini's laws as Meeus ch. 53 sets them out: the pole 1.54242° from the ecliptic pole, on the far side from the orbit's pole, and the prime meridian at the orbit's node plus F + 180°. Ω and F are Meeus's, and the axes are stepped back to J2000 by the same general precession as `moonPosition`.
  - The Sun seen from the Moon (from 1 AU minus the Moon's position), so the phase angle is the Moon's own.
  - Libration is the viewer's direction in the Moon's axes; the position angle is the Moon's pole against celestial north on the sky.
- **Bake** (`MoonBaker.bake`), once a minute, on a Settings change or a new location fix, at most once a frame:
  - A square the size of the disc at 2x (about 1600 pixels on a 14-inch MacBook), north up and east left, as the sky shows it.
  - Each pixel becomes a point on the sphere, turned into the Moon's axes by `u_view`, then longitude and latitude on the maps.
  - The read-back texture becomes the sprite's `SKTexture`. About 17 ms (release, 1618 px), so a frame is dropped once a minute, which a Moon that barely moves hides.
- **Upright:** each frame, `upright()` turns the sprite (and the stars) by the parallactic angle, so the zenith is up as for someone looking at the Moon with their head upright. This swings through the night, and turning a baked sprite costs nothing, so it's smooth while the lighting only updates each minute.
- **Size:** `moon.size` × the screen's shorter side × 385,000 km ÷ the Moon's real distance, so it's about 14% bigger at perigee than at apogee, as Dial-a-Moon shows.
- **Lighting** (the shader):
  - **Normals** from LOLA, bent around the sphere by the local east and north. Slopes facing away from the viewer fall back to the sphere, since they're out of sight behind the rise.
  - **Reflectance:** McEwen's lunar-Lambert, `L·2μ₀/(μ₀+μ) + (1−L)·μ₀`, where L(g) = 1 − 0.019g + 2.42e−4g² − 1.46e−6g³ (g, the phase angle, in degrees), floored at 0.4 because the fit ends near 100°. At full moon it's pure Lommel-Seeliger: flat, with no limb darkening.
  - **Opposition surge:** Hapke's shadow-hiding term, `1 + 0.25/(1 + tan(g/2)/0.05)`: about +25% at full, gone within a few days.
  - **Exposure per phase,** as a photographer would set it: divided by the brightest the disc gets (1 up to quarter, then sin g), so a crescent's limb looks as bright as a quarter's. Only the surge is left to show.
  - **Shadows:** 20 steps toward the Sun over LOLA's heights, from 1.4 km out to about 190 km over the curve (each step 1.28× the last), keep the highest ground's angle. The ground is lit by how much of the Sun's 0.27°-radius disc clears it. The same march toward the viewer finds ground hidden behind a rise. What shows there is the rise's lit face, so shadows hide at full moon as they really do, without black specks along the limb.
  - **Earthshine:** lit from the viewer's direction (so flat, like a full moon), bluish (0.7, 0.88, 1.25). Strength 0.1 × the Earth's phase from the Moon as a Lambert sphere, to the 4th power, less 0.05, so it's strongest near new moon and gone by quarter. In the Sky backdrop it fades as the sky brightens (`1 − sky/0.01`), since any lit sky outshines it.
  - **Earth's shadow** (`Sky.earthShadow`, mirrored in the shader): a cone from a spherical Earth 2% larger for its atmosphere (Chauvenet, as eclipse tables use it), umbra `1.02 − along·0.00461` and penumbra `1.02 + along·0.00470` Earth radii. Sunlight falls linearly across the penumbra. In the umbra it's copper, (1, 0.38, 0.12) × (0.08 + edge³), brighter toward the edge, with a blue fringe (0.03, 0.12, 0.15) where the light skims the ozone. While the Moon is in the umbra, direct light is exposed ×(1 + 60·coverage), as a photo exposed for the copper shows it, so the last sliver of sunlight burns white.
  - **Colour:** LROC's colour at half saturation (closer to what the eye sees), with a contrast of albedo^1.37 in linear light to match the tones of NASA's own renders. Then linear to 0.8, a soft shoulder to white, sRGB gamma, and ±½/255 dither.
- **Backdrops** (`moon.backdrop`):
  - **Black.**
  - **Stars:** the Yale catalogue (`LiveSky.catalogue`) around the Moon's real place, projected gnomonically on a far wider scale than the Moon (about 40° of sky top to bottom), faint (1.8–5 pt, alpha 0.3–0.85), in their B−V colours. The Moon's disc hides them.
  - **Sky:** the physical sky where the Moon is, from `Atmosphere.march` at the Moon's azimuth and at its altitude −0.2, 0 and +0.2 rad, as a three-texel gradient. Partial auto-exposure `0.4·(L/0.1)^0.25` makes it pale blue by day, deep blue or violet at dusk, and black at night. It's laid over everything with `.screen` blending: the air is in front of the Moon, and screen never clips its bright side. The dark side takes the sky's colour, as a daytime Moon's does. The Moon is tinted by the air it's seen through, `Atmosphere.sunlight` at its altitude over that at the zenith, so it rises orange. Stars fade as the sky brightens.

## Time, live data and appearance
- **Time:** `date` is now, or now plus `moon.previewDays` days while `moon.preview` is on. The slider covers a month, but any number of days works through `defaults`, e.g. the next total lunar eclipse (2028-12-31 16:52 UTC).
- **Location:** `Location.shared`, started in `didMove(to:)`. A new fix writes UserDefaults, which triggers a bake.
- **Network:** none.
- **Appearance:** one look; it ignores Light and Dark Mode.

## Data and licences
NASA's [CGI Moon Kit](https://svs.gsfc.nasa.gov/4720) by Ernie Wright, NASA Scientific Visualization Studio, public domain, from LRO's LROC camera and LOLA laser altimeter teams. It's credited in Settings → About. The four resources were cut from `lroc_color_16bit_srgb_8k.tif` (the 2025 colour map) and `ldem_16.tif` (heights in km over 1737.4 km, 16 pixels a degree) to the near side, longitude −100…100° (the ±8° libration and the limb), all latitudes, at 16 pixels a degree. Row 0 is 90°N. The far side near the poles, which libration can tip into view in a sliver a few pixels from the limb, clamps to the map's edge. Normals are central differences of the heights (east ones divided by cos latitude), stored as `n·0.5 + 0.5` in greyscale HEIC (quality 0.7 via `sips`), so each channel keeps full resolution rather than HEVC's halved chroma. Heights are stored as (h + 10)/21. At load, `MoonBaker.grey` reads each file's own 8-bit values without colour management and packs east, north and height into one RGBA texture. The recipe:

```python
# numpy + Pillow; col 0 of both maps is -180°
col = Image.open('lroc_color_16bit_srgb_8k.tif').resize((3200, 2880), Image.LANCZOS, box=(80 * 8192 / 360, 0, 280 * 8192 / 360, 4096))
h = np.asarray(Image.open('ldem_16.tif'), dtype=np.float64)[:, 1280:4480]
step, lat = np.pi / 180 / 16, (90 - (np.arange(2880) + 0.5) / 16) * np.pi / 180
hp = np.pad(h, 1, mode='edge')
east = (hp[1:-1, 2:] - hp[1:-1, :-2]) / (2 * 1737.4 * step * np.maximum(np.cos(lat), 0.01)[:, None])
north = (hp[:-2, 1:-1] - hp[2:, 1:-1]) / (2 * 1737.4 * step)
norm = np.sqrt(1 + east ** 2 + north ** 2)  # save -east/norm and -north/norm as n*0.5+0.5, and (h+10)/21, then sips → heic
```

Linear normals at quality 0.7 lose about 0.013 of slope (RMS) to compression; a square-root encoding halves the quantisation but doubles the files, and compression dominates anyway.

## Settings
| key | label | range | default | drives |
|---|---|---|---|---|
| `moon.backdrop` | Backdrop | Black, Stars, Sky | Stars | what's behind the Moon |
| `moon.size` | Size | 0.4–1 | 0.8 | the disc against the screen's shorter side, at mean distance |
| `moon.brightness` | Brightness | 0.5–2× | 1× | the sunlit side's exposure |
| `moon.earthshine` | Earthshine | 0–3× | 1× | the dark side's earthshine |
| `moon.preview` | Preview another day | toggle | off | `date` runs ahead |
| `moon.previewDays` | Days from now | 0–29.5 | 7 | how far ahead, shown while previewing |

Any UserDefaults change triggers a bake on the next frame, so dragging a slider re-lights the Moon live.

## Tuning constants
- **Base exposure** 1.25 × brightness × surge ÷ brightest; **earthshine** 0.1.
- **Shadow march:** 20 steps from 0.0008 rad, ×1.28 each; the Sun's radius 0.0047 rad, the viewer's horizon eased over ±0.003.
- **Stars:** about 40° of sky top to bottom; diameter `max(1.8, 5 − 0.6·V)`, alpha `1 − 0.12·V` clamped to 0.3–0.85.
- **Sky:** `0.4·(L/0.1)^0.25`, sampled ±0.2 rad around the Moon; below the horizon the Moon is drawn as if it were as high above it.

## Performance
- About 0.43 ms CPU and 0.08 ms GPU per frame with Black or Stars, and 0.19 ms GPU with Sky (release, 2x, 1512×982). It draws two or three sprites.
- The bake is about 17 ms once a minute (release, 1618 px), mostly the two 20-step marches over about 2 million pixels. The first bake also decodes the maps (about 50 ms).
- `update(_:)` does a few trig functions for the parallactic angle.

## Gotchas and shortcuts
- `ponytail:` **optical libration only.** Physical libration adds under 0.04°. NASA's numbers match to 0.03° without it.
- `ponytail:` **below the horizon,** the Sky backdrop draws the Moon as if it were as high above the horizon, rather than as a black disc. Its tilt is still the real one.
- `ponytail:` **the maps stay in memory** once the Moon has shown (about 75 MB with mipmaps).
- **Two copies.** Settings runs a second copy while its page is open, with its own `MoonBaker`. The maps are shared statics.
- **The render test** never calls `didMove`, so it uses the fallback location and never asks for one.
- **`SKTexture(data:)`** rows run bottom up, so the terrain is packed with its rows flipped.
- **The Earth's shadow only exists behind the Earth.** At new moon the umbra's and penumbra's radii cross, and a ramp between them divides by a negative width. Both `Sky.earthShadow` and the shader guard on `along > 0`.

## Dave's feedback and decisions
- **The brief (2026-09-26):** a full-screen photoreal Moon at its real phase, libration and tilt from his location; CGI Moon Kit data kept modest; lunar-Lambert/Hapke reflectance with the opposition surge; earthshine; copper in a real eclipse; checked against Dial-a-Moon like SkyTests checks Horizons; baked rather than shaded every frame; Black, Stars and Sky backdrops to compare in Settings; a time preview to scrub a month.
- **Backdrops (2026-09-26):** "all 3 as a choice for now": Black, Stars and Sky stay in Settings, with Stars the default.

## Ideas / next steps
- Physical libration, if anyone ever notices 0.03°.
- The limb's real mountain profile, from LOLA, instead of a perfect circle.
- A "Next eclipse" preview that searches for the next one, rather than typing days into `defaults`.
- Twinkling or extinction for the Stars backdrop.

## Checking it
- `swift test --filter MoonTests`:
  - phase, distance, subsolar point, libration and position angle against NASA's Dial-a-Moon at six 2026 dates (within 0.05°; they agree to 0.03°)
  - the 2026-03-03 total lunar eclipse: 98% of the disc in the umbra at 11:00 UTC, all of it at 11:33, none at the new moon before
- Side by side with Dial-a-Moon: `MOON_COMPARE=/some/dir swift test --filter moonRenders` saves our geocentric, north-up Moon for those dates at Dial-a-Moon's scale (0.35 pixels an arcsecond). Their frames come from `https://svs.gsfc.nasa.gov/api/dialamoon/2026-01-03T10:00` (the `image.url` field). `docs/images/the-moon-vs-dial-a-moon.jpg` pairs them, theirs on the left. Full-moon tones match to within a few levels at the 10th, 50th and 90th percentiles.
- Snapshots: `SNAPSHOT_DEFAULTS="moon.backdrop=2,moon.preview=1,moon.previewDays=7.5" SNAPSHOT_SCENE="The Moon" swift test`. For an eclipse, set `moon.previewDays` to the days until one (2028-12-31 16:52 UTC).
