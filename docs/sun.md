# The Sun Today

The real Sun as NASA's Solar Dynamics Observatory (SDO) saw it within the last hour or so, in one wavelength at a time: the gold loops of the corona in 171 Å, the red chromosphere in 304, sunspots in visible light. Today's flares, sunspots and prominences show up the day they happen. Brought to life: plasma pulses out along the bright loops, active regions flicker, the corona streams outward, and every few minutes one of today's active regions flares or a prominence erupts off the limb. It's built to sit beside [Nebula](nebula.md): real colours from a real source, calm motion, a new look on each load.

- **Files:** `Sources/Atrium/Sun.swift`: the scene (`TheSun`), its shader, `decode(_:_:)`, `sunTilt(at:)` and `SunImages`, which fetches and caches the images. `Tests/AtriumTests/SunTests.swift` reads a real Helioviewer reply and checks the tilt.
- **Entry:** since 2026-09-27, the Sun's live view in Solar System Tour (see [solar-system.md](solar-system.md)), which builds `TheSun(size:)` and runs it nested in its own scene, passing it `update(_:)` and `didMove(to:)`. Its settings are under The Sun on Solar System Tour's page: `TheSun.wavelengthKnob` then `TheSun.knobs`. Until then it was its own wallpaper, "The Sun Today", icon `sun.max.fill`, tint `.orange`, with its wavelength as the palette.
- **Name:** Dave asked for "The Sun, today", but Shuffle keeps the wallpapers it skips as one comma-separated string (`shuffle.skip`), so a comma in a name would break it.
- **Kind:** downloaded photos, drawn by one full-screen SKShader.

## Where the images come from
- **Helioviewer** (the ESA/NASA Helioviewer Project, api.helioviewer.org), not SDO's own site. Research on 2026-09-26 found:
  - SDO's `sdo.gsfc.nasa.gov/assets/img/latest/latest_*.jpg` all carry a grey caption ("SDO/AIA 171 2026-09-21 15:26:46 UT") in the bottom left, and have been frozen since 21 September 2026. SDO's site has a banner about "a hardware failure with its data storage". Its browse archive (`/assets/img/browse/YYYY/MM/DD/`) is live for AIA, about 11 minutes behind, but is captioned too, its daily listing grows to 1.1 MB, and it has had no HMI since the 24th.
  - Helioviewer's `downloadImage` serves the same data full-disc, in SDO's standard colour tables (SolarSoft's `aia_lct`, matched within 1/255), with no caption, watermark or logo. AIA runs about 50 minutes behind real time, HMI 2–3 hours. HMI's visible light comes in grey.
- **Two requests per frame:**
  - `getClosestImage/?date=<ISO time>&sourceId=<id>` returns about 300 bytes of JSON: `id`, and `date` as "2026-09-27 01:08:45" in UTC (`SunImages.frame`).
  - `downloadImage/?id=<id>&width=<2048|4096>&type=jpg` returns the image. It never changes once published, so there's no ETag to keep: a frame is fetched once and kept by its time.
  - Source ids: 94 = 8, 131 = 9, 171 = 10, 193 = 11, 211 = 12, 304 = 13, 335 = 14, HMI continuum = 18.
- **Geometry:** every image is centred, and the solar disc's radius is 0.3895 of the image's width (Helioviewer's `rsun` of about 1595 in 4096 pixels). It isn't read from the reply: the Sun's apparent size really does change by ±1.7% over the year, and a fixed scale keeps that.
- **Which width:** `width` asks for 4096 when twice the disc's on-screen radius in points (2x Retina) is over 1.15 × the 2048 image's radius, otherwise 2048. On a 14" MacBook Pro the whole Sun is 2048 (1:1) and the close-up is 4096. At 2048, the close-up is 2.6× enlarged and JPEG blocks show.
- **Polling** (`SunImages.poll`): the scene asks every 60 s from an SKAction started in `didMove`, so it stops while hidden. `poll` itself goes to the network at most every 15 minutes per channel and width (30 for 4096), however many displays ask.
  - It asks for the frame closest to now; if that isn't cached, it downloads it.
  - It keeps the newest two frames per channel and width: one to show, and one another display may still be fading from.
  - Failures are silent and leave the cache as it was.
- **Cache:** `~/Library/Caches/com.dtanquary.atrium/sun/<width>/<source>-<unix time>.jpg`. The scene shows the newest cached frame as it's built, so it's there at once and offline. Until the first image arrives, it shows a dim disc in the wavelength's colour, and fades from that in 3 s.
- **Bandwidth,** for one channel on screen all day: at 2048 about 30 MB (171) to 50 MB (304); HMI 24 MB. At 4096 every 30 minutes about 50 MB (171) to 100 MB (304).

## How it works
- **Crop:** each frame is decoded off the main thread (`decode(_:_:)`, about 20 ms at 2048) into a bitmap holding only the part of the image the framing shows, plus 0.03 radii for the shimmer. The close-up keeps about a fifth of a 4096 image, about 15 MB, not 64. `u_crop` and `u_cropNext` say which part each texture holds, so frames of different widths or crops can crossfade.
- **Also from each frame** (`decode`): a grey copy of the crop 16 times smaller, `u_blur`, which drawn with linear filtering is a blur, for the loops' flow; and the brightest knots on the disc (local maxima of a 48-pixel copy, where the disc is 19 pixels across its radius, the top eight), today's active regions, for flares and eruptions to start from. SpriteKit's shaders reject `texture2D` with a mipmap bias, so the blur can't come from the frame's own mipmaps.
- **Shader:**
  - `d = (pts − u_disc.xy) / u_disc.z` is the pixel in solar radii; the disc is `(w/2, h/2, 0.38h)` for the whole Sun, or `(0.78w, −0.35h, 1.05h)` for the close-up, rising off the bottom right with the north pole's plumes at the top.
  - **Corona past the image:** the images end 1.28 radii out (the sides of the frame), so past 1.2 radii each pixel samples the image at 1.2 radii in the same direction and fades by `exp(−14(r − 1.2))`, as 193's corona does. That smears streamers radially, which is how they run, and hides the frame's square edge. The first try faded the image out between 1.12 and 1.28 instead, which left a visible ring.
  - **Visible light** comes in grey and is tinted to NASA's orange (`visibleLight`, sampled from SDO's own HMIIC images): black to umbra red `#9D1400` at 0.25, limb `#E94E03` at 0.47, `#FC9200` at 0.75, centre `#FFB11C` at 0.86. The grey levels are measured from Helioviewer's HMI: 220/255 at the centre, about 120 near the limb.
  - Then `grade()` (the Look sliders, pivot 0.3) and a 1/128 dither.
- **Motion** (Settings → View → Motion), two to compare:
  - **Still, with a shimmer at the edge** (0): off the disc (from 0.97 to 1.1 radii in), the corona flickers ±14% in fine radial streaks that drift outward about a third of a solar radius a minute (`r·2.5 − u_now·0.015` in noise space), plus a coarser layer so no noise cells show, and wavers by up to ±0.5% of the radius. The disc itself stays still. A new image crossfades in over 30 s.
  - **Alive** (1, the default): the same, and more, all scaled by **Liveliness** (`sun.life`, 0–2):
    - **Corona:** its streaks stream out three times as fast, and flicker 60% more.
    - **Plasma along the loops:** where a pixel is brighter than `u_blur` there (a loop), noise pulses travel along the blur's downhill slope, away from the active regions' cores, ±30% bright, about 0.008 radii a second (`dot(d, away)·60 − u_now·0.5`, stretched 60:22 along the flow). The slope sets the direction, so the pulses run out along the loops that fan from each core, as plasma does, and fade where the slope is flat. The mask keeps it to loops.
    - **Flicker:** active regions (bright in `u_blur`) brighten and dim ±15% over tens of seconds.
    - **Flares and eruptions**, every few minutes (`sun.events`, default 5, the first 10–25 s after the wallpaper appears, then every 0.5–1.5 intervals, at random): a **flare** (60%) at one of the four brightest knots the framing shows, or an **eruption** off the limb above a knot near the edge (over 0.75 radii out), or anywhere on the limb the framing shows.
      - **Flare** (`u_flare`: x, y, seconds, strength 0.6–1): brightness `(1 − e^(−t/3))·e^(−t/35)`, so it flashes within seconds and fades over a minute. The loops within about 0.06 radii brighten up to 4×, with a soft bloom in the channel's hot colour, AIA's diagonal diffraction cross (its entrance filter's mesh) at the peak, and a faint ring, an EIT wave, spreading over the disc at 0.012 radii a second.
      - **Eruption** (`u_eruption`: angle, seconds, strength, size 0.14–0.24 radii): an arch whose feet stay on the limb, its top rising `0.003t + 0.00008t²` radii beyond its starting height, so faster and faster. Its outline is ragged by noise, its thickness varies along it, threads (fbm) run along it, a haze fills it, and it fades by `e^(−t/60)` over about two minutes. It's coloured through the channel's own table, low to mid to hot as it brightens, mostly mid, so in 304 it's red with yellow threads. It shows only off the disc. The first tries were a clean grey ring lifting away (a smoke ring), then a thin wiggly thread; comparing with 304 prominences gave the thicker, hazier, ragged arch.
      - Neither in visible light, which shows neither; nor the flow or flicker, which have no loops to follow there.
    - Set `sun.nextEvent` to `flare` or `eruption` (`defaults write com.dtanquary.atrium sun.nextEvent flare`) to have every event be that kind, starting a second after the scene is built.
- **Turned to now** (`turnBack` in the shader): the Sun turns about 0.55° an hour, so a new image, an hour or so fresher, would crossfade in shifted. Each frame is turned on to now before it's drawn:
  - Each pixel on the disc becomes a point on the sphere, about an axis tipped toward us by B0 (`sunTilt(at:)`, ±7.25° over the year, Meeus ch. 29), and is moved back along its latitude by the Sun's synodic differential rotation since the frame was taken: `13.72 − 2.39 sin²φ − 1.78 sin⁴φ` degrees a day (Snodgrass and Ulrich 1990). `u_age` and `u_ageNext` are those hours, from the frame times in the file names, updated every frame.
  - "Now" is the clock, but never more than 4 hours past the newest frame, so a stale cache (offline, say) isn't turned far.
  - A point that was round the far side then keeps its place (a sliver at the east limb); off the disc, the corona isn't turned.
  - Checked 2026-09-27 with phase correlation on the time-lapse (since cut): frames three hours apart were 21 px apart, turned ones 0.
  - So the image turns in real time, by about a point every 15 minutes.
- **Changing:** `advance()` runs every second from an SKAction and does one thing at a time (`busy`): load a new framing (a cut) or a newly arrived image. `update(_:)` runs the crossfade by elapsed time (`frameTime`), and the flares and eruptions (`updateEvents`).
- **Clocks:** the shimmer and flow run on `u_now`, so they're smooth for days. Crossfades and events step with the scene's frames, so they pause while the wallpaper is hidden. Moving Liveliness makes the corona's streaks jump once, since their drift is `u_now` times a rate.
- No Light Mode look: space is black.

## Settings
- **Wavelength** (`sun.light`, a menu: 0 is Random, then the eight in the order of `wavelengths`): picked when the scene is built. It was a palette stored by name (`sun.wavelength`) while the Sun was its own wallpaper; Solar System Tour's palette slot holds its worlds, so it became a menu, and main.swift moves an old pick across once.

| Name | Channel | What it shows | Swatch (25, 50, 85% of the table) |
|---|---|---|---|
| 171 Gold | AIA 171 Å, Fe IX, 0.6 MK | the quiet corona's loops, polar plumes | `r0, c0, b0` |
| 193 Bronze | AIA 193 Å, Fe XII, 1.2 MK | corona, dark coronal holes | `c1, c0, c2` |
| 211 Purple | AIA 211 Å, Fe XIV, 2 MK | active regions | `c1, c0, c3` |
| 304 Red | AIA 304 Å, He II, 50,000 K | chromosphere, prominences, filaments | `r0, g0, b0` |
| 131 Teal | AIA 131 Å, Fe XX, 10 MK | flares (dim and grainy between them) | `g0, r0, r0` |
| 94 Green | AIA 94 Å, Fe XVIII, 6 MK | flares (dim and grainy between them) | `c2, c3, c0` |
| 335 Blue | AIA 335 Å, Fe XVI, 2.5 MK | active regions | `c2, c0, c1` |
| Visible | HMI continuum, 6173 Å | the surface, sunspots, limb darkening | NASA's HMIIC orange |

  The tables are from `aia_lct.pro`: `c0 = i`, `c1 = √(255 i)`, `c2 = i²/255`, `c3 = (c1 + c2/2)·2/3`, and `r0, g0, b0` is IDL's Red Temperature table (`r0 = 255 i/176`, `g0 = 255(i − 120)/135`, `b0 = 255(i − 190)/65`, clamped).
- **View:**
  - **Motion** (`sun.motion`): Still, or Alive (the default). A comparison for Dave; the loser goes once he's picked (see "Compare, then lock in").
  - **Framing** (`sun.framing`): Whole Sun or Close-up, also still to pick.
  - **A flare or eruption every** (`sun.events`, 0 (Off) to 20 minutes, default 5). One minute is handy for watching them.
  - **Liveliness** (`sun.life`, 0–2, default 1): how strongly the loops pulse and flicker, and how fast and strongly the corona streams.
  - The last two show for Still too: `shownWhen` would hide them only once Motion had been changed, since `KnobRow` counts a gate that was never set as on.
- **Look:** `gradeKnobs("sun")`, brightness, contrast, saturation and hue, as in Nebula.

## Performance
- Release, 2x Retina at 1512×982: CPU 0.43–0.52 ms, GPU 0.38–0.58 ms per frame, measured 2026-09-26 for 193, 304 and visible whole and 171 and 304 close up. That's two texture reads and four noise calls a pixel. The turns on the disc (a few trig calls each) put it at 0.42 ms GPU whole and 0.89 ms close up, where the disc fills the screen.
- Alive, measured 2026-09-27 on battery with other sessions busy, when Nebula measured 3.75 ms against its usual 1.6: whole 0.72 ms, close-up 1.6–2.1 ms, and 1.4 ms during an eruption. The still close-up measured the same then, so the flow (five reads of `u_blur`, two noise calls) costs little; scaled by Nebula's ratio, Alive is about 0.3 ms whole and 0.7–0.9 ms close up. An eruption's fbm runs only while one's under way.
- Decoding runs off the main thread; each new texture (with mipmaps, for the small Settings preview) uploads on its first frame.
- **Memory:** two textures, the frame showing and the next. For the whole Sun, 16 MB each plus mipmaps; for the close-up, 15 MB each.

## Gotchas and shortcuts
- The render tests never call `didMove`, so they never download; they show whatever's cached, or the placeholder disc. Async decodes don't finish in the render test's loop either, so a new image never arrives in a test.
- `ponytail:` the flow follows the blur's slope, not the loops themselves: pulses run out from each active region, along the loops that fan out of it, but across the odd loop that doesn't. Following each loop would need its direction from the image's second derivatives (a Hessian of nine reads a pixel), with its sign fixed some other way.
- `ponytail:` 4096 downloads are 1–2 MB, mostly pixels the close-up crops away. Helioviewer's `takeScreenshot` can render just a region, but as a PNG of several MB taking 6 s; its tile API could fetch only the tiles on screen, if bandwidth matters.
- `ponytail:` Random picks a wavelength per load; unlike Nebula it doesn't move on to another while running. Shuffle and the 12-hour rebuild give variety. Cycling would mean fetching another channel each time.
- SDO's own latest images are frozen, and SDO's HMI browse images stopped on 24 September. If Helioviewer lags or goes down, the last cached frames stay up.

## Credits and terms
- SDO's rules (sdo.gsfc.nasa.gov/data/rules.php): its images "are not copyrighted", non-commercial use "is strongly encouraged and requires no expressed authorization", and it asks for "Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams." NASA's guidelines ask that use doesn't imply endorsement and that the NASA insignia isn't used.
- Helioviewer publishes no terms or rate limit; its API's example config allows 3000 requests a minute. This asks for about 2 an hour per channel.
- Settings → About and the README credit "NASA/SDO and the AIA, EVE, and HMI science teams, via the ESA/NASA Helioviewer Project".

## Dave's feedback and decisions
- 2026-09-27, after trying the time-lapse at 3×: "the sun one is really awesome but it just lacks the "life" the other animated wallpapers have. Even when I move to 3x time lapse its hard to see movement, I just see the jump back to the beginning. Can we do anything to not use time lapse and instead find some interesting artistic way to animate the sun at times?" That cut the time-lapse, its speed and its three-hour backfill (the forward loop and turning to now are in commit 061a383), and added Alive: the flow, flicker, livelier corona, flares and eruptions.
- 2026-09-27: "is there any way to do an accelerated time lapse just to test what it looks like over time / add something to the settings to control the looping time lapse speed, do your best to create seamless loops". That added Time-lapse speed, the forward loop, and turning every frame to now.
- 2026-09-26, the brief: the real Sun right now, wavelength as the palette after real colours, stored by name with Random as the default. Research the source first; cache and poll politely like Clouds; crossfade when a new image arrives. Calm motion: compare a shader shimmer over the latest still with a time-lapse of real frames, and a whole disc with a big disc off one edge, in Settings. No text on screen. It should earn a place beside Nebula.

## Ideas / next steps
- More events: coronal rain falling back down loops after a flare, jets and spicules flickering at the limb in 304, a slow filament eruption on the disc.
- Real flares: NOAA's GOES X-ray feed could trigger a flare at the real flaring region when one's under way, beside the artistic ones.
- Pick the close-up's edge where today's activity is (the brightest limb), rather than always the north-east.
- A slow wavelength cycle on Random, like Nebula's.

## Checking it
```sh
# sun.light: 1 171 Gold, 2 193 Bronze, 3 211 Purple, 4 304 Red, 5 131 Teal, 6 94 Green, 7 335 Blue, 8 Visible
SNAPSHOT_SCENE="Solar System Tour" SNAPSHOT_DEFAULTS="solar.photo=live-the-sun,sun.light=2" swift test                  # whatever's cached
SNAPSHOT_SCENE="Solar System Tour" SNAPSHOT_DEFAULTS="solar.photo=live-the-sun,sun.light=4,sun.framing=1" swift test    # close-up
SNAPSHOT_SCENE="Solar System Tour" SNAPSHOT_DEFAULTS="solar.photo=live-the-sun,sun.light=1" SNAPSHOT_MOVIE=8 swift test # the flow and shimmer
SNAPSHOT_SCENE="Solar System Tour" SNAPSHOT_SECONDS=8 SNAPSHOT_DEFAULTS="solar.photo=live-the-sun,sun.light=1,sun.nextEvent=flare" swift test      # a flare near its peak
SNAPSHOT_SCENE="Solar System Tour" SNAPSHOT_SECONDS=20 SNAPSHOT_DEFAULTS="solar.photo=live-the-sun,sun.light=4,sun.nextEvent=eruption" swift test  # an eruption
ls ~/Library/Caches/com.dtanquary.atrium/sun/*/          # what's been fetched
```
The render test only shows cached frames: run the app on that wavelength (and framing) first, or it shows the placeholder disc.
