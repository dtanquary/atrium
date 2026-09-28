# Solar System

A slow tour of the Sun's family in the best photos spacecraft and telescopes have taken. Each view drifts and zooms for a minute (Ken Burns), then dissolves into the next. The tour moves from world to world, not photo to photo, so each visit to a world shows the next of its photos. The Sun and the Moon are live: today's Sun from SDO (The Sun Today's scene) and the Moon as it is right now where you are (The Moon's scene), run inside this one. Settings can hold the tour on one world.

- **Files:**
  - `Sources/Atrium/SolarSystem.swift`: the scene (`SolarSystem`), the tour (`pickNext`), the framing and cut (`cut`), and the shader.
  - `Sources/Atrium/Resources/solar-photos.tsv`: one row per view, from the Sun outward: file, world, credit, licence, source, caption, kind (`disc`, `closeup` or `live`) and focus. About reads its credits.
  - `Sources/Atrium/Resources/solar-<name>.heic`: the photos, cut by `docs/solar-system/prep.py`. `solar-thumb-<world>.jpg`: a 152×92 swatch per world for Settings.
  - `docs/solar-system/photos.py`: every photo's original, crop, focus, caption and credit, the source of truth for the TSV. `docs/solar-system/prep.py` cuts them (see Photos below).
- **Entry:** `solarSystem(size:)`. Its registry entry is "Solar System", icon `smallcircle.filled.circle`, tint `.orange`, knobs `SolarSystem.knobs`, then The Sun's (with `TheSun.wavelengthKnob`) and The Moon's, each moved under its own section with `Knob.in(_:)`, and palettes `SolarSystem.bodyChoice`: the worlds, each with its thumbnail.
- **Kind:** photos in one full-screen SKShader, and two live scenes nested in this one.

## How it works
- **A view** is a row of the TSV. `disc`: a whole world (or a crescent) on black. `closeup`: a surface or cloud tops that always fill the screen. `live`: `TheSun` or `TheMoon`.
- **The tour** (`pickNext`): the world held in Settings, or else a random world not among the last half of all worlds shown (`solar.recent`), weighted by how many views it has up to 3, so Saturn and Jupiter come round more often than Umbriel but not twelve times as often. Then that world's next view in the TSV's order (`solar.seen`, a count per world), so a return to Saturn shows a different Saturn. Both are kept in UserDefaults, so the rotation carries on across launches. Two live views never follow each other (see Gotchas). Each display and the Settings preview tour on their own, sharing the counts.
- **Timing:** each view shows for `solar.seconds` (60 s), then the next dissolves in over 6 s with a smoothstep. A view's motion runs over its time plus its dissolve out, so nothing stops moving on screen. The next photo is cut in the background once the current one has fully arrived; if it isn't ready, the current view holds at the end of its motion.
- **Framing** (`cut`), in photo pixels and points:
  - **Whole worlds** fit 86% of the screen's height or 94% of its width at their widest, and zoom by `solar.zoom` (1.25×) or the row's own zoom. The zoom heads halfway to the focus, so the world stays whole and near the middle; the wide end is jittered by up to 4% of the screen.
  - **Never soft:** the tight end is capped at 1.5 screen pixels per photo pixel. A small photo (Voyager's Umbriel, 280 px) shows smaller on black instead, as Dave chose.
  - **Close-ups** cover the screen at their widest and zoom toward the focus, clamped so the screen never leaves the photo. They start from the focus's reflection through the middle, so a long strip (Juno's limbs, Pluto at sunset) pans across it.
  - **Direction:** half zoom in, half out (`Bool.random()`).
- **The cut:** only the part of the photo the motion ever shows (the union of its two ends' views, which contain every frame between: the left edge is concave in time and the right convex), decoded off the main thread, scaled with Core Graphics' high interpolation so the widest moment is one texel per screen pixel (or the photo's own pixels, if fewer). After that the texture only ever magnifies, so fine detail like ringlets never aliases or shimmers.
- **Shader:** both views (showing, and dissolving in) are sampled with Catmull-Rom in nine bilinear taps (Sigg and Hadwiger's trick), which stays sharp as it slowly magnifies where bilinear blurs, and pulses as the photo slides across texels. Outside a photo is black. A live view's slot is clear, and the sprite blends with `.alpha` (premultiplied), so the live scene below shows through; the dissolve between a photo and a live view is the photo's alpha. ±½/255 dither.
- **Live views:** `liveScene` builds `TheSun` or `TheMoon`, adds it as a child below the photo sprite, and passes it `update(_:)` each frame and `didMove(to:)`. SpriteKit runs actions on a nested scene and draws it (checked on 2026-09-27), but never calls those two itself. A live view that's next is built hidden when chosen, so its images load behind the current photo, and removed once the next view has dissolved in.
- **Captions** (`solar.captions`): the world's name (SF Pro 26 pt semibold, 82% white) over one line (13 pt, 60%): what, which spacecraft, when, and the colour if it isn't true colour. They fade in 1.5 s after a view arrives, over 3 s, and out as the next begins. A soft shadow in the shader behind the bottom-left corner keeps them readable on a bright photo. The Moon's line names the picked phase when it isn't real time.

## Settings
- **Show** (`solar.body`, by name; empty is Random): the palette slot, as a grid of worlds with thumbnails. Random tours them all; a world holds the tour there, still moving through its views. Picking one rebuilds the scene.
- **Tour:** Each view for (`solar.seconds`, 20–300 s, 60), Zoom (`solar.zoom`, 1–1.6×, 1.25), Names (`solar.captions`, on), Brightness (`solar.brightness`, 0.4–1.2×, 1; photos only, the live views have their own).
- **The Sun:** Wavelength (`sun.light`, Random or one of the eight), then the rest of the Sun's settings (see [sun.md](sun.md)). Show holds the palette slot, so the wavelength became a menu.
- **The Moon:** the Moon's settings (see [the-moon.md](the-moon.md)).
- **For trying things out** (`defaults write com.dtanquary.atrium …`): `solar.photo` pins one view by file name (`live-the-sun`, `live-the-moon` for the live views), `solar.at` (0–1) holds the motion at that point, for snapshots.

## Photos
- **What's in:** whole worlds and close-ups from orbit, the best-looking version of each, true or enhanced colour, infrared or radar, with the caption saying which (Dave's picks, 2026-09-27). No surface landscapes, famous-moment shots (Earthrise, Pale Blue Dot), renders, or spacecraft in frame.
- **Research,** 2026-09-27: five agents, one per region (Sun to Moon; Mars and the small worlds; Jupiter; Saturn; Uranus outward), searched NASA Photojournal (now at science.nasa.gov, full-size files under `assets.science.nasa.gov/content/dam/science/psd/photojournal/pia/piaNN/piaNNNNN/`), images.nasa.gov, ESA, ESA/Webb and ESA/Hubble, JAXA, pluto.jhuapl.edu and Wikimedia Commons and Flickr (for citizen processing), downloaded the originals, and checked each one at 1:1.
- **Licences:** public domain, CC BY or CC BY-SA only (ESA's CC BY-SA 3.0 IGO, Webb's and Hubble's CC BY 4.0), credited in About from the TSV. Out: anything non-commercial or unclear. Juno images processed by volunteers are often NC (Seán Doran, Gerald Eichstädt, Björn Jónsson) or published by NASA with no licence (PIA21641's south pole, PIA26484's Io), so only those marked CC BY are in. Callisto (Justin Cowart's Voyager 2 mosaic) was CC BY 2.0 when Wikimedia Commons' licence review checked it; its Flickr page now says CC BY-NC, but a CC licence can't be withdrawn from a copy already given under it.
- **Cutting** (`prep.py`, with numpy, Pillow, scipy and ffmpeg):
  - **Load** as floats, colour-managed to sRGB; 16-bit TIFFs Pillow can't read go through ffmpeg as rgb48.
  - **Crop** (`crop`, fractions of the original): labels, credit text, logos, projection edges.
  - **Despeckle** (`despeckle`): JunoCam frames carry a grid of dark marks every 118 px; pixels more than t darker than their 5-pixel median (t = 0.12) are replaced by the 7-pixel median. Dark only: both ways caught 6% of pixels, real cloud texture.
  - **Black level,** whole worlds only: the black point is the border's median plus 3σ of its noise (exact zeros, a padded frame, left out), and a soft toe, y²/(y + 0.015), keeps faint haze and night sides instead of clipping them. Every photo then sits on the same black, so the dissolves don't pump.
  - **Box,** whole worlds only: the biggest bright blob (so stars and small moons don't widen it), or `box` for a crescent or a world with its moon, plus 7% margin, padded with black.
  - **Fade** (`feather`, a fraction of the short side): a whole world cut off by its original's frame (the 2012 eruption, Artemis II's Orientale, Pluto's haze ring, 67P) fades out there instead of ending in a straight line inside the black margin. It runs after the black level. With `keepblack` and a full `box`, it also floats a photo with no black around it (Titan before the rings, Daphnis in the Keeler gap, 67P's cliffs) on black.
  - **Saturation** (`saturation`): the research agent's 8-bit conversions of Mars Express's global mosaic came out much redder than Viking's globes; 0.7 brings them into the same butterscotch.
  - **Size:** whole worlds at most 3200 px (`cap`; 4000–4800 for the Sun and Pluto, which zoom deeper), close-ups 5120 px, long strips keep a 3400 px short side. `shrink` takes an upscaled original back toward its real sharpness (Andrea Luck's Neptune close-up 0.6, Triton 0.7, Arrokoth and Nix 0.6).
  - **Save:** HEIC at quality 80 via `sips`, with an sRGB profile and ±½ dither; clean at 1:1. Whole worlds are mostly black, so many are under 0.2 MB.
  - **Focus** (`at`) is given in the original's fractions, as the research agents reported it, and moved through the crop, box and scaling.
  - **Thumbnails:** each world's first photo (or the one marked `thumb`): whole worlds 62% of the box around the middle, close-ups from their middle.
- **The order** within a world is the order the tour shows them: the best first.

## Performance
- 0.49–0.55 ms CPU and 0.26–0.32 ms GPU for a photo, 0.85 ms GPU with the live Sun (release, 2x Retina at 1512×982, 2026-09-27). A dissolve samples two photos, still well under a millisecond.
- **Memory:** two textures at up to screen size (24 MB each at 3024×1964), plus a transient full decode while cutting (up to 70 MB, in the background).
- **Cutting** takes 110–240 ms per photo. Only the first view is cut on the main thread, when the scene is built, so the render test has a photo.
- **App size:** 109 MB of photos: 136 photos of 44 worlds, plus the live Sun and Moon (2026-09-27).

## Gotchas and shortcuts
- **SpriteKit leaves a texture uniform undeclared while its texture is nil,** and the shader then fails to compile. Both slots start with a 1-pixel black texture.
- **A child's zPosition adds to its parent's,** so a nested live scene's own layers (The Moon's sky at 2, its disc at 1) drew over the photo layer at 1: the live Moon popped in and out instead of dissolving (Dave, 2026-09-27: "the 1st image did not fade out it popped out"). The photo layer is at 100 and the caption at 101, above anything the live scenes use.
- **Nested scenes ignore alpha** in their own shaders, so a live view can't be faded. The photo layer sits above it and fades instead. Two live views would both show through at once, which is why the tour never puts them back to back.
- **Render tests** never finish a background cut (the detached task needs the main actor the test holds), so they only ever show the first view; use `solar.photo` and `solar.at` to see a given photo at a given point.
- `ponytail:` every display and the Settings preview cut their own copy of a photo. Share cuts across copies if memory on many displays matters.
- `ponytail:` the first cut blocks the main thread for up to 240 ms. Start on black and cut it in the background if the switch to Solar System feels sticky.

## Credits and terms
Every photo's credit, licence and source is in `solar-photos.tsv`, listed in Settings → About under "Solar System's photos". The live Sun and Moon keep their own credits.

## Dave's feedback and decisions
- 2026-09-27: "slow panning and zooming between all of the best solar system photos we can find, at least one of each planet and any moon we can get high res imagery of … super high quality." Picked: whole worlds and close-ups from orbit (not surface landscapes or famous moments); the best-looking version of each, true or enhanced; small photos shown smaller on black rather than skipped; photos bundled in the app.
- "you can do many of a planet if you find many, we want to just shuffle around the solar system … when we shuffle back to saturn we use a different one from last shuffle": the tour is by world, with a rotation per world.
- "consider folding the sun and moon wallpaper directly into this one since its redundant, and then just provide a settings option to lock to a specific solar body": the live Sun and Moon are views in the tour, and Show holds it on one world. The Sun Today and The Moon left the menu; main.swift moves anyone on either to Solar System held on that world, and an old wavelength pick to `sun.light`.

## Ideas / next steps
- **Gaps the research found:** Deimos, Vesta, Eros, Janus, Epimetheus, Prometheus, Pandora, Hydra and Amalthea have nothing over about 700 px with a clear licence. No Saturn ring close-up reaches 4000 px (Grand Finale frames are 1024). Itokawa, Hope (EMM) and Tianwen-1 images have unclear licences. HiRISE's colour strips above 4K are 300–800 MB JP2s, not fetched. Juno's south pole (PIA21641) and Io's north pole (PIA26484) name a processor but no licence; asking would get them in.
- A slow parallax of the stars behind whole worlds was ruled out: photos of planets don't show stars, and Dave prefers real over made up.
- A Show choice for several worlds (a planet and its moons) if holding on one is too narrow.

## Checking it
- `SNAPSHOT_SCENE="Solar System" SNAPSHOT_DEFAULTS="solar.photo=solar-pluto-true.heic,solar.at=1" swift test --filter everySceneRenders`: one photo at the end of its motion (which end is random).
- `SNAPSHOT_DEFAULTS="solar.photo=live-the-moon"`: the live Moon inside the tour.
- `SETTINGS_SHOT="Solar System" swift test --filter settingsWindow`: the Show grid.
- `defaults read com.dtanquary.atrium solar.seen` and `solar.recent`: the rotation.
