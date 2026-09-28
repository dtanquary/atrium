# Deep Space Tour

Solar System Tour's sister: slow pans and zooms across the best real photos of what lies beyond the Solar System. Nebulae, star clusters, dying stars, galaxies, deep fields and the only two black holes ever imaged, from Webb, Hubble, ESO, Euclid, the Rubin Observatory, Chandra and the Event Horizon Telescope. Each view drifts for a minute, then dissolves into another object, with a caption and two facts. Settings → Show holds the tour on one kind of object.

- **Files:**
  - The engine is Solar System Tour's: `Sources/Atrium/PhotoTour.swift` (`Tour.deepSpace`, settings under `deep.…`). See [solar-system.md](solar-system.md) for how the tour, framing, cut, shader, captions and Caption settings work; everything there applies here.
  - `Sources/Atrium/Resources/deep-photos.tsv`: one row per view: file, object, credit, licence, source, caption, kind, focus and group (Nebulae, Star clusters, Dying stars, Galaxies, Deep fields, Black holes). About reads its credits.
  - `Sources/Atrium/Resources/deep-<name>.heic`, and `deep-thumb-<group>.jpg`, a swatch per group for Settings.
  - `Sources/Atrium/Resources/deep-facts.tsv`: facts per object, each read on its release page.
  - `docs/deep-space/photos.py`: every photo's original, crop, focus, caption and credit; cut with `TOUR=deep python3 docs/solar-system/prep.py`.
- **Entry:** `deepSpaceTour(size:)`. Its registry entry is "Deep Space Tour", icon `star.circle.fill`, tint `.purple`, knobs `Tour.deepSpace.knobs`, palettes `Tour.deepSpace.showChoice`: the six groups.
- **Kind:** photos in one full-screen SKShader, with no live views.

## How it differs from Solar System Tour
- **Show** (`deep.show`) holds the tour on a group, not an object: most objects have one to three photos, so a kind of object is the more useful hold. The tour still moves object to object within it.
- **Whole objects** (`whole()` in photos.py): galaxies, nebulae and clusters on dark sky are shown whole, like a world, but they're already on black as released, so they aren't black-levelled or boxed; a 5% edge fade melts the frame into the screen's black. The black holes are levelled and boxed, since the Event Horizon Telescope's frames sit on a warm near-black.
- **Close-ups** fill the screen and pan, as in Solar System Tour. Long panoramas (Andromeda, the Milky Way's centre) are split into overlapping segments.
- **Quality:** HEIC at 60 (80 in Solar System Tour's older photos); deep-sky photos are busy, and at 1:1 the difference doesn't show.

## Photos
- **Research,** 2026-09-28: three agents (nebulae and star clusters; dying stars and the black holes; galaxies and deep fields) searched ESA/Hubble, ESA/Webb, ESO, NOIRLab, ESA (Euclid), Chandra and the EHT's member institutes, downloaded the largest official files under 400 MB (or the official 10K and 25K downsizes of the gigapixel mosaics), and checked each at 1:1.
- **Real photos only** (Dave): no artist's impressions, simulations or catalogue maps (Gaia's star maps are out). Composites of real exposures from several telescopes and wavelengths are in, with the caption naming the light: infrared, X-ray, radio, narrowband colour.
- **Black holes** (Dave: "use only the highest res you can find of the real thing, I only want those 2 real images"; then, shown other official versions, "include other versions"): M87* (the first image, 2019; a year later, 2024; in polarised light for 2017, 2018 and 2021, from the 2025 release) and Sagittarius A* (2022, and polarised, 2024), all from the Event Horizon Telescope, credited "EHT Collaboration", CC BY 4.0. eventhorizontelescope.org refuses scripted downloads, so they come from ESO, CfA and Perimeter, which republish the same releases. The polarised M87* panels were cut from CfA's unlabelled triptych at its separators.
- **Licences:** CC BY 4.0 (ESA/Hubble, ESA/Webb, ESO, NOIRLab, EHT), public domain (NASA, STScI, Chandra: "no claim to copyright"), CC BY-SA 3.0 IGO (Euclid). Out: the ESA Standard Licence (Webb's big Orion mosaic), anything NC, and Chandra's versions of Tycho and Kepler that add DSS or Pan-STARRS stars (unclear licences), so those two are X-ray only.
- **Size** (Dave, 2026-09-28, shown ~240 MB at 5120 px): capped at 4096 px on the long side, and long strips at 2600 px tall. On a 3024-px-wide screen there's no visible difference; on 5K it's slightly soft only when zoomed in.

## Performance
The same as Solar System Tour's photos: about 0.5 ms CPU and 0.3 ms GPU a frame.

## Dave's feedback and decisions
- 2026-09-28: "what are your thoughts on a similar 'Galactic Tour' where we find the highest quality images from anywhere in the universe, famous nebula, black holes, etc … would it make sense to combine into a single wallpaper or have two?" Two wallpapers on one engine; the name Deep Space Tour, since "galactic" means our own galaxy. Show holds by type. Colour handled as in Solar System Tour. The same Caption settings ("i think same or similar settings would be needing on the galactic tour too"), under `deep.…`.

## Ideas / next steps
- Gaps the research found: no image of the Monkey Head, HH 211, Eta Carinae's Homunculus, the Eskimo, the Ant or the Red Rectangle over about 2400 px; no CC-licensed image of the whole Heart and Soul; Webb's full Orion mosaic is ESA Standard Licence; Hubble's Tarantula mosaics and Webb's IC 348 are over 400 MB (fetchable if the app size allows).
- An "Include deep space" switch in Solar System Tour, if Dave wants the two on one timer.

## Checking it
- `SNAPSHOT_SCENE="Deep Space Tour" SNAPSHOT_DEFAULTS="deep.photo=deep-pillars-webb.heic,deep.at=0.5" swift test --filter everySceneRenders`
- `SETTINGS_SHOT="Deep Space Tour" swift test --filter settingsWindow`: the Show groups.
