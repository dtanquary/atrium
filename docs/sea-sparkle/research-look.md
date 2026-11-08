# Sea Sparkle: the look research

A research agent's report on the look of a bioluminescent night shore, written 2026-11-07. How to draw it within the battery budget is in [research-method.md](research-method.md). Every claim is marked **checked** (the page that says so was read on 2026-11-07), **excerpt** (seen only in a search summary), **unchecked**, or **measured** (sampled by me from the photos and video listed, with scripts kept in `$TMPDIR/seasparkle-scripts/`, downloads in `$TMPDIR/seasparkle-dl/`; neither is in the repo). A Commons licence marked checked means Commons' own licence field for that file, which is only as good as the uploader's claim.

## Summary and recommendation

1. **What it is:** a line of cyan light where each wave breaks, spreading into the whitewater and fading as the foam runs up the beach, under a dark sky, with points of light on the wet sand. In footage the surf's glow swells over a second or two and fades over several, so it is soft. Only the sand's sparkles are true flashes.
2. **The place to start:** Fish Hoek, False Bay. Poly Haven's CC0 panorama and 27 backplates show a long sandy beach with spilling breakers, a headland each side and a hillside town. Sea sparkle has been reported there (Nov 2023, Aug 2025). It is the one real place found with a CC0 photo and a documented glow.
3. **Colour:** the light is 473 nm, but cameras show it anywhere from cyan to azure depending on white balance. Default to **Cyan**, as footage shows it: glow body #145f69, core #137596, brightest foam #378daf, on a #050d1c sky. That keeps it apart from Jellyfish's Sapphire (#005e96 at the same cap), which is azure points on black.
4. **Brightness:** frame median 8 to 20, broad glow capped at 150, sparkles at 190, as Jellyfish caps them. The backdrop here isn't black (sky, sand), so it sits higher than Jellyfish's 0 to 8.
5. **Real data:** swell from Open-Meteo's Marine API at the chosen beach (tested at four places), the real Moon and real stars. No live bloom feed is good enough to switch the glow on and off.
6. **Name:** **Sea Sparkle**, the organism's own common name and as plain as Fireflies. An iPad sightings app shares it. **Glowing Surf** is the fallback.
7. **Against it:** real blooms are rare, so any "follow the real bloom" switch would leave the beach dark most nights. The subject is close to Jellyfish's glow. Every stock "bioluminescent beach" live wallpaper is neon and pulsing.

## 1. What the real thing looks like

### The organisms
| | *Lingulodinium polyedra* (San Diego) | *Noctiluca scintillans* ("sea sparkle") | *Pyrodinium bahamense* (Puerto Rico) |
|---|---|---|---|
| Where | Southern California red tides (Scripps FAQ, checked) | Worldwide coasts: False Bay, Jervis Bay, Hong Kong, Matsu, Wadden Sea, Kerala, New Zealand | Mosquito Bay, Vieques; Laguna Grande; La Parguera (excerpt) |
| Cell size | about 40 µm (Wikipedia, checked, secondary) | 400 to 1,500 µm (Wikipedia citing DORIS, checked, secondary) | unchecked |
| Flash | about 100 ms ([Latz lab](https://latzlab.ucsd.edu/bioluminescence/dinoflagellates/dinoflagellate-bioluminescence/), checked); rises in 22 to 40 ms (Latz et al. 2026, table of others' figures, checked) | 80 ms (Wikipedia citing Britannica, checked, secondary) | "about a tenth of a second" (excerpt) |
| Emission | **473.3 nm, 30 nm wide** (Latz, Deheyn and Sprecher 2026, Table 1, [PMC13103706](https://pmc.ncbi.nlm.nih.gov/articles/PMC13103706/), checked) | 474 to 476 nm (a patent, excerpt); dinoflagellates average 476.6 ± 3.2 nm ([Frontiers 2023 review](https://www.frontiersin.org/journals/marine-science/articles/10.3389/fmars.2023.1299602/full), excerpt) | unchecked |
| By day | "reddish-brown" water (Scripps FAQ, checked) | pink or orange above about 1.5 million cells/L (Wikipedia, checked, secondary) | unchecked |

- **Night only.** *Lingulodinium*'s clock builds its light proteins at dusk and breaks them down by dawn. Its cells can't be set off by touch until night begins ([PMC4298066](https://pmc.ncbi.nlm.nih.gov/articles/PMC4298066/), excerpt). Each cell recharges by day for the next night (Latz lab, checked). Locals say the glow starts 45 to 60 minutes after sunset and is best about 75 minutes after ([La Jolla guide](https://lajolla.ca/blog/activities-blog/bioluminescence-in-la-jolla-your-guide-to-the-nighttime-glow/), excerpt).
- **Sheets or points.** *Lingulodinium* is small and dense, so whitewater glows as a continuous sheet (San Diego photos and video). *Noctiluca* is ten times bigger, and in every *Noctiluca* photo here the light breaks into separate points: Paraparaumu, Matsu, Spiekeroog, Zeebrugge (measured, by eye). That is a real difference worth a setting.

### Where the glow sits in a breaking wave
From the 2020 surf video below (51 frames at 10 fps) and the stills:
- **The swell and the unbroken face are dark.** Light first shows as a thin bright line along the lip as it pitches, peeling along the crest. Wide shots show only this: one or two cyan lines on the break.
- **Then the whole whitewater lights,** brightest at its turbulent top, textured like the foam itself. In the video the lit area grows for about 1.5 s after the lip first lights. Its mean brightness peaks about 2.3 s in, then falls to 56% of the peak 2.8 s later as the bore runs up the beach (measured; real-time playback assumed, unchecked).
- **Behind the bore** loose foam keeps a fading glow. The swash's edge leaves points on the sand, and wet sand mirrors the glow faintly (Kamakura photo).
- **On the sand,** footprints and the swash line sparkle as points ([glowing sand at Torrey Pines and Scripps, Feb 2024](https://thehill.com/changing-america/enrichment/science/4488523-watch-glowing-sand-spotted-at-san-diego-beach/), excerpt; the page refused me).
- **Bigger sets glow brighter:** the brightest waves came "with the biggest sets, once every 10-15 minutes" (a photographer quoted by [KGTV](https://www.10news.com/lifestyle/exploring-san-diego/bioluminescent-waves-captured-along-north-san-diego-county-coast), excerpt).
- **How long a bloom lasts:** in San Diego, from a week to over a month (FOX 5 citing Scripps, excerpt). In False Bay, three to five days, at least once a year (UCT's Emma Rocke in [Cape Town Etc](https://www.capetownetc.com/things-to-do-cape-town/outdoors/in-photos-beautiful-bioluminescence-at-muizenberg/), checked).

### Eye, video, long exposure
| | Shutter in the samples | What it shows |
|---|---|---|
| Video | 1/30 s per frame | One wave's glow at a time, cyan (hue 180 to 193°), on near-black: frame median 4 to 8 of 255 (measured, the 2020 video) |
| Short stills | 1/4 to 1/2 s, ISO 1,600 to 6,400 (EXIF: Seal Beach, Kamakura, Paraparaumu) | Thin lines on the break; *Noctiluca* as separate points |
| Long exposures | 2 to 30 s, one of 253 s (EXIF: Torrey Pines 8 s, Spiekeroog 30 s, Matsu 253 s) | Several waves stacked into one wide band. The sea smoothed to mist. A sky lit like twilight (Torrey Pines' is #597398). Stars, clouds and city glow. |

- **Exposure is chosen by the photographer, not set by nature.** Shutter × ISO ÷ f² runs from about 50 (Seal Beach) to 33,000 (Matsu), a 600-fold range across these photos (measured from EXIF). Phil Hart's famous Gippsland Lakes shot was a 1.5-hour exposure, with friends splashing to set off the glow ([PetaPixel](https://petapixel.com/2010/08/09/sea-and-star-sparkles-captured-together-in-a-long-exposure-photo/), excerpt).
- **To the eye:** Scripps says it "can be seen with the naked eye" and calls it "neon-blue" and "electric-blue" ([FAQ](https://scripps.ucsd.edu/news/red-tides-and-bioluminescence), checked). One guide says that in some years it shows only in photos (excerpt). Dim light weakens colour vision, so the eye likely sees it paler and bluer-white than photos do (general vision science, unchecked here).
- **What long exposures exaggerate:** brightness, the width and continuity of the band, the smoothness of the water, the sky's colour, and saturation (white balance alone moves the hue from cyan to violet-blue).

### Sky, sand and setting in the photos
- **Sky:** stars in most; the Milky Way at Spiekeroog; clouds lit by the Moon or the town; city lights along the shore (Kamakura, Manasquan, Seal Beach's oil platforms) and their warm reflections (Scripps 2011).
- **Sand:** near-black, faintly warm or violet, #120e16 to #201d22 (measured, Kamakura and Torrey Pines).
- **Structures:** Torrey Pines' lifeguard tower, the glow seen between Scripps Pier's legs, Matsu's tetrapods and rocks.
- **The Moon:** tours schedule for new moon (Vieques pages, excerpt). Yet Fish Hoek's November 2023 glow was photographed under a full moon, and Cape Town's six recorded events ran from about 12% to 100% lit ([capetowndata](https://capetowndata.com/en/blog/when-does-the-sea-glow-blue-in-cape-town-bioluminescence-dates-and-data/), checked, secondary). So honestly the Moon lifts the sky, sand and sea while the glow stays as it is: the contrast drops, and the glow doesn't go out.

### Famous places, for reference (look only)
- **San Diego, 2020** (late March to May; 9.17 million cells/L at Scripps Pier on 27 April, from [SCCOOS's data](https://erddap.sccoos.org/erddap/tabledap/HABs-ScrippsPier.html), checked): [Scripps on red tides](https://scripps.ucsd.edu/news/everything-you-wanted-know-about-red-tides), [Latz lab](https://latzlab.ucsd.edu/2020/04/29/its-a-bioluminescent-red-tide/), [surf video, T. R. Fallon](https://commons.wikimedia.org/wiki/File:Surfing_on_bioluminescent_wave.webm), [Scripps Pier, R. Robertson](https://commons.wikimedia.org/wiki/File:Bioluminescence_at_Scripps_Pier.jpg).
- **San Diego, since then.** In 2023, FOX 5 reported glowing waves ([FOX 5](https://fox5sandiego.com/news/local-news/bioluminescence-has-rolled-back-into-san-diego-heres-what-to-know/), excerpt; I couldn't confirm the date). In 2024 there were displays in February, May ([Axios](https://www.axios.com/local/san-diego/2024/05/15/bioluminescent-surfing-la-jolla-uc-san-diego), excerpt) and November ([SCCOOS](https://sccoos.org/observing-bioluminescence-at-scripps-pier/), checked). Earlier references are from 2019 ([Torrey Pines](https://commons.wikimedia.org/wiki/File:Bioluminescence_in_San_Diego.jpg); the pier counted 60,703 cells/L that week, checked), 2011 ([Olson](https://commons.wikimedia.org/wiki/File:Lingulodinium_polyedrum_bioluminescing_in_surf.jpg)) and 2005 ([Carlsbad](https://commons.wikimedia.org/wiki/File:Dinoflagellate_bioluminescence_3.jpg)).
- **Vaadhoo, Maldives** ("sea of stars"): made famous by Will Ho's photos. Sources disagree on whether it was *Lingulodinium* or *Noctiluca* ([Wikipedia](https://en.wikipedia.org/wiki/Vaadhoo_(Raa_Atoll)), excerpt).
- **Jervis Bay:** *Noctiluca*; Jordan Robins' prints ([his site](https://www.jordanrobins.com.au/collections/bioluminescence), excerpt, all rights reserved). **Tasmania** (Preservation Bay): no source found this pass, unchecked. **Gippsland Lakes 2008–09:** Phil Hart (above).
- **Hong Kong, January 2015:** *Noctiluca* at Tai Po and Sam Mun Tsai, fed by sewage ([CNN](https://www.cnn.com/2015/01/26/asia/hong-kong-blue-algae), excerpt).
- **Mosquito Bay, Vieques:** *Pyrodinium*, held in by a narrow mouth. Calm water lit by paddles and fish rather than surf; no swimming ([Wikipedia](https://en.wikipedia.org/wiki/Puerto_Mosquito), excerpt). Its Guinness "brightest" year is given as both 2006 and 2008 (excerpt).
- **Matsu's "blue tears"** ([Commons](https://commons.wikimedia.org/wiki/File:%E7%99%BC%E5%85%89%E7%9A%84%E8%97%8D%E7%9C%BC%E6%B7%9A.jpg)), **Paraparaumu 2025** ([Commons](https://commons.wikimedia.org/wiki/File:Bioluminescence_at_Paraparaumu_Beach_1.jpg)), the **Wadden Sea** ([Spiekeroog](https://commons.wikimedia.org/wiki/File:Meeresleuchten_am_Strand_von_Spiekeroog_01.jpg), [Norderney](https://commons.wikimedia.org/wiki/File:Meeresleuchten_auf_Norderney_01.jpg)).
- **Toyama's firefly squid** (*Watasenia*, March to May; [Atlas Obscura](https://www.atlasobscura.com/places/firefly-squid-toyama-bay), excerpt): beached, dying squid dotting the shore blue. It's a different animal and a grim picture. **Leave it out.**

## 2. Colours

### The emission, and how cameras render it
- **473 nm and 30 nm wide works out to #0082ff** in sRGB at full value, and #004a96 at a top channel of 150 (derived: Wyman, Sloan and Shirley's 2013 CIE fit, gamut-mapped by adding white, as Jellyfish's research did). This is purer than Jellyfish's 470 nm band, which it took as 89 nm wide.
- **Cameras push it toward cyan.** Every glow core in 19 photos falls between 188° and 225° of hue, median about 199°. The video's is 182° to 193°. Only the Wadden Sea photos go teal (168° to 171°) (measured). Where the light is brightest, the photos run toward pale aqua or white: #7dd7ff, #48ffff, #50c4f2 (measured).
- **On the method report's "no palette":** it is right that the light has one colour. But no photo shows that colour; each shows a white balance. So the options below are honest renderings of the one emission, not invented palettes.

### Candidate palettes
Sampled from the photos, then scaled in linear light so each lands on its level. Levels are the brightest of R, G and B, out of 255.

| Palette | From | Sky | Sea | Sand | Glow edge | Body | Core | Brightest foam / sparkle |
|---|---|---|---|---|---|---|---|---|
| **Cyan** (default) | the 2020 video; Olson 2011, Carlsbad 2005, Seal Beach 2011 at daylight balance | #050d1c | #05070e | #141216 | #0c2d37 | #145f69 | #137596 | #378daf / #33bebe |
| **Azure** | tungsten-balanced: Paraparaumu 2025, Scripps 2011, Matsu 2016 | #0d111a | #04060c | #100c14 | #020732 | #042564 | #064891 | #257faf / #3c98be |
| **Teal** | *Noctiluca* in the Wadden Sea and Grundsund | #13131a | #06030c | #141210 | #033734 | #015464 | #008c71 | #01b99d |

- **Cyan** is the default. It's how footage shows the glow, and it stays clear of Jellyfish.
- **Azure** is nearest the true emission and the eye's "electric blue", but it sits where Jellyfish's Sapphire sits: offer it, don't default to it.
- **Teal** is real, but it puts a green glow under a blue sky, which edges toward the green-in-blue Dave disliked in Lava Lamp. Mock it up before keeping it.
- **Moonlight is not a palette.** It is the Moon setting lifting sky, sea and sand while the glow stays put. Measured from Torrey Pines 2019 and scaled: sky #202c3c, sea #171a22, sand #262228.
- **City lights** (warm points along the shore, in many photos) break the one family. Keep them few and dim (60 to 90), or behind a switch.
- **The daytime red tide** measures olive-tan, #7d6e4f, in Ifremer's [Baie de Vilaine](https://commons.wikimedia.org/wiki/File:Prolif%C3%A9ration_de_Noctiluca_scintillans_en_Baie_de_Vilaine_(Ifremer_00673-78544).jpg) photo. San Diego's is "reddish-brown". It reads as dirty water and clashes with cyan. **Leave it out**, Light Mode included: the scene stays dark, as Nebula does.

### How it stays apart from Jellyfish
Jellyfish's light is Sapphire (470 nm, #005e96 at its cap), pinpoints and slow waves on a single animal, on black. This wallpaper's light sits about 10° to 15° of hue greener, and it goes pale toward white in the brightest foam, as photos show and Jellyfish's points don't. It falls in horizontal bands and lace, not in spots, on a scene that isn't black: stars, a horizon, sand, sometimes the Moon. If Jellyfish keeps its sapphire and this keeps cyan, they won't read as one wallpaper. Agree that split with Jellyfish before either ships.

### Brightness
| Scene | median | 90th | 99th | 99.9th |
|---|---|---|---|---|
| Fireflies (blue hour) | 64 | 82 | 90 | 171 |
| Live Sky | 10 | 30 | 48 | 65 |
| Aurora | 61 | 138 | 185 | 197 |
| Nebula | 30 | 110 | 150 | 168 |
| the 2020 video, peak frame | 6 | 134 | 242 | 255 |
| Seal Beach, 1/4 s | 12 | 55 | 196 | 255 |

(Measured from the app's Settings previews and from the downloads.) The glow covers 2% to 7% of a wide frame (measured: Manasquan, Sea sparkles 2013, Seal Beach, Olson), so it decides the 99th percentile. Proposed, with Jellyfish's caps where they apply:

| Part | Brightest |
|---|---|
| Sky, moonless | 10 to 30 |
| Sky, full moon | up to 60 |
| Sea between breaks | 3 to 15 |
| Sand | 10 to 25 (moonlit, 30 to 45) |
| Fading foam, glow edges | 30 to 60 |
| Glow body | 80 to 110 |
| The breaking line, broad | 150 (Jellyfish's cap) |
| Sparkles, foam peaks (a few pixels) | 190 (Jellyfish's cap) |

That gives a frame median of about 8 to 20 and a 99th percentile under 150. Nothing reaches 255. Whether this reads on a lit desk is unchecked; the method report's risk 5 says the same.

## 3. Looks and settings for variety

- **Place** (a menu; "Changing" by default, so each load brings a new one):
  - **Fish Hoek:** a long sandy beach, spilling breakers, a headland each side, a town on the hill. CC0, and its glow is documented. The default.
  - **La Jolla Cove:** sandstone rocks, a small cove, the coast running away north. CC BY 4.0 (§4).
  - **Scripps Pier:** the glow between the pier's legs, as in Robertson's 2020 photo. Its CC0 photos wait on Unsplash review (§4).
  - **A still bay:** Mosquito Bay's kind. Flat water lit only by a passing fish or a falling drop, and mangroves as a dark silhouette. No free photo was found, so it would be drawn. The calmest look of all, and the most honest about flashing: nothing stirs it but slow causes.
- **Bloom:** how dense it is, from a few scattered points to a full sheet. With it, **Kind**: Sheets (*Lingulodinium*, San Diego) or Sparkles (*Noctiluca*, everywhere else). Both are real; they look different.
- **Swell:** Live (the place's real height, period and direction, §4), or held at Calm, Moderate or Big. Sets should come and go, since bigger sets glow brighter.
- **Moon:** Tonight's (real phase and place over the beach), None, or Full. It lifts the scene's levels, as §1 says, and keeps the glow as it is.
- **Time of night:** follow the clock (the glow comes on about an hour after sunset), or held at Late night. Real stars at the place's latitude, with the Milky Way on moonless nights.
- **Palette:** Cyan, Azure, Teal, Random.
- **Sparkle on the sand:** a low slider, standard low, after the method report.
- **Not offered:** the daytime red tide, a Light Mode, and the firefly squid.

## 4. Photos and data that could go in

### Backdrops, to relight for night as Fireflies' meadow was
| Photo | Licence | Fit |
|---|---|---|
| [Fish Hoek Beach](https://polyhaven.com/a/fish_hoek_beach), Poly Haven: an HDRI and 27 backplates at 5432×3621, plus DNG raws (Greg Zaal, Rico Cilliers), taken 29 May 2016 at sunrise or sunset under cloud (API, checked) | CC0, **checked** ([licence](https://polyhaven.com/license): "all licensed as CC0"; the page doesn't name backplates, so for those partly checked). Rain on Glass and Campfire already use Poly Haven. | The best fit. Backplates IMG_0016, 0028, 0032 and 0046 face the bay and the breakers. The town (0020, 0042) could carry lit windows. |
| [La Jolla Cove April 2024](https://commons.wikimedia.org/wiki/File:La_Jolla_Cove_April_2024.jpg), Zongxianglee, 3008×2000 | CC BY 4.0, **checked** (Commons field) | The rocky cove, overcast, looking along the coast |
| [La Jolla Cove 2020](https://commons.wikimedia.org/wiki/File:La_Jolla_Cove_2020.jpg), Mollymcc | CC0, **checked** (Commons field) | The cove from above. It has buildings and bathers that would need painting out. |
| [Ellen Browning Scripps Memorial Pier](https://commons.wikimedia.org/wiki/File:Ellen_Browning_Scripps_Memorial_Pier,_La_Jolla_,_United_States_(Unsplash).jpg) (D. deLeon) and [Pier](https://commons.wikimedia.org/wiki/File:Pier_(Unsplash_Wr79EN6_R3Y).jpg) (F. McKenna), via Unsplash | CC0 only if Unsplash published them before 5 June 2017. Commons flags both "review needed", and the first was taken on 4 June 2017. **Unchecked.** | The pier with surf under it |
| [Scrippspier.jpg](https://commons.wikimedia.org/wiki/File:Scrippspier.jpg), Stickpen | Public domain, **checked** (Commons field) | The pier from a height, with palms |
| [Torrey Pines State Beach 2014](https://commons.wikimedia.org/wiki/File:Torrey_Pines_State_Beach_-_2014_(11808743154).jpg), Andrew Yau | CC BY 2.0, **checked** (Commons field) | Cliffs and beach |
| [Sandy Beach in Tomales Bay](https://commons.wikimedia.org/wiki/File:Sandy_Beach_in_Tomales_Bay.jpg), Ana Vila-Concejo | CC BY-SA 4.0, **checked** (Commons field). An adapted copy stays CC BY-SA. | A still bay. That Tomales Bay glows is unchecked. |
| Poly Haven [Damp Beach Sand](https://polyhaven.com/a/damp_beach_sand) and [02](https://polyhaven.com/a/damp_beach_sand_02) | CC0, **checked** (licence page) | Wet sand up close, for the sparkle |

Mosquito Bay itself has no usable free photo: Commons has only a National Guard landing craft (PD) and a flash-lit night shot (CC BY 3.0). Already in the app, for the sky: the Yale stars (PD), ESO's Milky Way (CC BY 4.0, Black Hole's) and NASA's Moon (PD) (checked in `Settings.swift`).

**References, not backdrops** (licences checked as Commons fields): all the Commons links in §1, plus [Manasquan 2008](https://commons.wikimedia.org/wiki/File:Bioluminescent_dinoflagellates.jpg) (CC BY 2.0), [Kamakura 2017](https://commons.wikimedia.org/wiki/File:Sea_sparkle_at_Kamakura_Yuigahama_Beach,_Japan_on_March_2017.jpg) (CC BY-SA 4.0), [Seal Beach 2011](https://commons.wikimedia.org/wiki/File:Dinoflagellate_luminescence.jpg) (CC BY 2.0), [Grundsund 2019](https://commons.wikimedia.org/wiki/File:Mareel_-_Bioluminescence_in_Norra_Grundsund_harbor_1.jpg) (CC0), [Sea sparkles 2013](https://commons.wikimedia.org/wiki/File:Sea_sparkles_(11538049406).jpg) (CC BY-SA 2.0), [Blue Tide 2007](https://commons.wikimedia.org/wiki/File:Blue_Tide-_Noctiluca.jpeg) (CC BY 2.0), [YingZheng 2011](https://commons.wikimedia.org/wiki/File:L_Polyedrum_Bioluminescing_at_La_Jolla_beach.JPG) (PD). The 2020 surf video is CC BY-SA 4.0.

### Feeds
- **Open-Meteo Marine API**: **checked** ([docs](https://open-meteo.com/en/docs/marine-weather-api), [terms](https://open-meteo.com/en/terms), [licence](https://open-meteo.com/en/licence)).
  - **What it gives:** wave, swell and wind-wave height, period and direction; sea surface temperature; currents; sea level with tides.
  - **Models:** MeteoFrance MFWAM at 8 km, ECMWF WAM at 9 km, DWD EWAM at 5 km over Europe.
  - **Coasts:** "Accuracy at coastal areas is limited" for tides and currents.
  - **Terms:** free for non-commercial use under 10,000 calls a day. Data is CC BY 4.0, with a link to Open-Meteo wherever it's shown, which Settings already gives. Model makers' licences are listed: DWD and ECMWF are CC BY; NOAA, Météo-France and Copernicus have their own.
  - **Tested** (current conditions): Fish Hoek 2.1 m at 8.9 s from 185°, sea at 13.6 °C. Scripps Pier 1.0 m at 12 s. Torrey Pines 1.0 m. Mosquito Bay 0.6 m, open sea outside the sheltered bay. Each answer snaps to a sea cell 2 to 4 km out.
- **SCCOOS / CalHABMAP, Scripps Pier** ([ERDDAP `HABs-ScrippsPier`](https://erddap.sccoos.org/erddap/tabledap/HABs-ScrippsPier.html)): weekly *Lingulodinium* counts since 2008, the latest sample 14 Sep 2026. Licence: "may be used and redistributed for free", **checked** (dataset attributes).
  - **It misses displays.** The well-reported May 2018 glow never topped 7,510 cells/L in the weekly samples. Spring 2023 peaked at 21,184 for one week. Torrey Pines' May 2019 photo coincides with 60,703 (measured from the data).
  - **Verdict:** one pier, weekly, with false negatives. At most a status line ("Scripps Pier counted N cells/L on Monday"), never a switch.
- **iNaturalist,** *Noctiluca*: 605 observations ever, and 14 in the last 30 days, some inland (Berkeley; Lancaster, New Hampshire). Observation licences are mixed (CC BY, CC BY-NC, none) (checked). Its API terms weren't read (unchecked). **Not usable.**
- **Ocean colour** (NASA, Copernicus chlorophyll): not checked, and chlorophyll can't tell a glowing bloom from any other.

## 5. Names

### Look-alikes to steer clear of
- Stock and AI "bioluminescent beach" live wallpapers: neon blue and green, glow "pulsing in sync with the rhythm of the ocean", bloom halos ([MoeWalls](https://moewalls.com/landscape/bioluminescent-ocean-live-wallpaper/), [DesktopHut](https://www.desktophut.com/search/bioluminescent), excerpt).
- [whitescreen.tv's "Glowing Tide"](https://whitescreen.tv/screensavers/glowing-tide/), a browser screensaver of the same subject, "small waves lighting up electric blue" (checked).
- Apple's aerials have no bioluminescence. They do include **"Sea Stars"** (underwater), "Tahiti Waves" and several "Coast" and "Night" names ([zhongzachary's list](https://github.com/zhongzachary/sonoma-screen-savers), checked).

### Names checked
None of these clash with an existing or in-progress Atrium wallpaper (checked against the list in the brief and `docs/README.md`).

| Name | For | Against | Checked where |
|---|---|---|---|
| **Sea Sparkle** (recommended) | The common name news uses for it (NBC on Hong Kong, 2015). Plain, like Fireflies. The working slug already. | Strictly it names *Noctiluca*, not San Diego's *Lingulodinium*, which is tolerable, as Jellyfish covering comb jellies is. An iPad app, "Sea Sparkle: Bioluminescence" (a sightings tracker, App Store id6754467492), uses it. | App Store via search (excerpt); no SEA SPARKLE mark in third-party USPTO mirrors (excerpt, not USPTO itself: unchecked) |
| **Glowing Surf** (fallback) | Says what it is. | Doesn't fit the still-bay look; plainer. | No app or mark found (search, excerpt) |
| **Bioluminescence** | A phenomenon name, like Aurora. | Jellyfish's subject too, so the two would blur. Crowded with stock wallpapers. | Search (excerpt) |
| **Mareel** | Shetland's own word for it. | Obscure. Also the name of Lerwick's arts centre and cinema. | [Shetland.org](https://www.shetland.org/blog/mareel-a-sparkling-addition-to-shetland-life), excerpt |
| **Phosphorescence** | Sailors' word. | Chemically wrong (it isn't phosphorescence). Long. | none needed |

**Avoid:**
- **Sea of Stars:** Sabotage Studio's 2023 game, Vaadhoo's tourism slogan, and next to Apple's "Sea Stars". The game is checked by search excerpt; its trademark is unchecked.
- **Glowing Tide:** the screensaver above.
- **Blue Tide:** "Tide" is P&G's detergent. BLOO TIDE ("blue tide") is registered for surfboards and kayaks (Reg. 5581591, [Justia](https://trademarks.justia.com/873/83/bloo-87383453.html), excerpt). Several businesses use the name.
- **Night Surf:** Stephen King's 1969 story of plague survivors burning a man on a beach ([Wikipedia](https://en.wikipedia.org/wiki/Night_Surf), excerpt).
- **Red Tide:** a harmful bloom; San Diego's in 2020 killed fish (UCSD, excerpt).
- **Blue Tears:** Matsu's tourism name.
- **Glow Waves:** a Backdrop (Cindori) wallpaper (excerpt).

## Not verified
- How long whitewater glows in real time. The video's playback speed wasn't confirmed; measure it from more footage.
- Whether moonlight dims the glow itself (no source either way). The Moon's effect on contrast is real.
- The 2023 San Diego date, Tasmania's events, Vaadhoo's organism, Mosquito Bay's Guinness year.
- Trademarks: only third-party mirrors and search, no USPTO, EU or UK search.
- Whether Poly Haven's CC0 statement covers backplates by name. The two Unsplash pier photos' publication dates.
- Whether the 150 and 190 caps read on a lit desk.

## Sources
Science: [Latz, Deheyn and Sprecher 2026, PMC13103706](https://pmc.ncbi.nlm.nih.gov/articles/PMC13103706/); [Latz lab](https://latzlab.ucsd.edu/bioluminescence/dinoflagellates/dinoflagellate-bioluminescence/); [Scripps FAQ](https://scripps.ucsd.edu/news/red-tides-and-bioluminescence); [Scripps 2020](https://scripps.ucsd.edu/news/everything-you-wanted-know-about-red-tides); [PMC4298066](https://pmc.ncbi.nlm.nih.gov/articles/PMC4298066/); Wikipedia on [*Noctiluca*](https://en.wikipedia.org/wiki/Noctiluca_scintillans) and [*Lingulodinium*](https://en.wikipedia.org/wiki/Lingulodinium_polyedra); Wyman, Sloan and Shirley 2013, *JCGT* 2(2).
Places and events: the links in §1; [Cape Town Etc](https://www.capetownetc.com/things-to-do-cape-town/outdoors/in-photos-beautiful-bioluminescence-at-muizenberg/); [capetowndata](https://capetowndata.com/en/blog/when-does-the-sea-glow-blue-in-cape-town-bioluminescence-dates-and-data/); [SCCOOS](https://sccoos.org/observing-bioluminescence-at-scripps-pier/).
Photos and data: the links in §4; [Poly Haven API](https://api.polyhaven.com/info/fish_hoek_beach); [Open-Meteo](https://open-meteo.com/en/licence); [SCCOOS ERDDAP](https://erddap.sccoos.org/erddap/info/HABs-ScrippsPier/index.html); [iNaturalist API](https://api.inaturalist.org/v1/observations?taxon_name=Noctiluca%20scintillans).
