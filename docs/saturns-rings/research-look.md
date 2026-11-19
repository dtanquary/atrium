# Saturn's Rings: the look research

The look agent's report of 2026-11-18, for the idea on the ideas page of 2026-11-14: "Drifting just above the ring plane: thousands of fine bands, the planet's shadow lying across them, and a moon's ripple passing through." A second agent covers the method (geometry, shader, aliasing, cost and the radial profile's format) in `research-method.md`. This report covers what the real thing looks like, its colours, palettes, brightness caps, licences, how to stay clear of Black Hole, and the name.

How it was done: 25 Cassini images were downloaded from the Photojournal as 1600-px JPEGs and read with `python3 -I` (PIL and numpy). Colours are means of 8-bit sRGB pixels. "L" means Rec. 709 luma of those sRGB values, 0–255, the same measure Space Tour's Soften uses. The downloads, scripts and contact sheets are in the session's scratchpad, which is temporary: `/private/tmp/claude-501/-Users-dave-Development-atrium/75eefa28-284c-41b6-be45-8a1ded042fde/scratchpad/look/` holds the images and `.../scratchpad/lookscripts/` the scripts (`luma.py`, `boxes.py`, `ramp.py`, `prof2.py`, `sheet.py`). Every image is listed below by PIA number, so any of it can be fetched again.

## The short of it
1. **The real view from just above the ring plane is a quiet one.** Cassini's natural-colour pictures from 3 to 5° above the rings (PIA09860, PIA08282) show wide, soft bands of cream, tan and mauve-brown running off the edges of the frame. Their contrast within a ring is small (±8–20%). The jumps between rings are large (3 to 6 times). The sky is black. It already looks calm. The work is to keep it that way.
2. **The colours are pale and barely saturated.** On the lit face the B ring is cream to tan: hue 26–51°, saturation 0.15–0.3. The A ring is greyer (0.08). The Cassini Division and the C ring are a dark, cool grey with a hint of blue. Black Hole's orange is hue 29° at saturation 0.57. So the lit face is the look furthest from Black Hole, and I'd default to it (**Sunlit**, below).
3. **Lit face and unlit face swap which ring is bright.** From the sunlit side the B ring is the brightest (L 203 against the A ring's 141 and the C ring's 59, PIA06485). From the unlit side it is the darkest (L 18 against the A ring's 76–98 and the C ring's 51, PIA08388). That makes a real, free variation for each load.
4. **The planet's shadow is pure black (L 0–4 in every exposure) with a sharp edge.** The ring particles slide through it while it stays still, since it points away from the Sun. When the planet is in the frame, its lit face is 1.7–1.8 times as bright as the B ring. It would be the brightest thing on screen, so it sets the cap.
5. **The best "moon's ripple" is Daphnis in the Keeler gap.** Its waves on both edges of the gap are 0.5–1.5 km tall, lead and trail the moon, and cast shadows hundreds of km long near equinox (PIA11571, PIA21056). Second best is Pan's wakes on the Encke gap (PIA07528, PIA21060). A propeller (PIA21447) is a smaller third.
6. **Licences.** The ring data is NASA mission data. NASA's science data policy, SPD-41a, says "Mission data are released into the public domain" and that SMD data "should be released with a Creative Commons Zero license". The PDS Ring-Moon Systems Node's own pages state no licence, so cite the dataset. Cassini images are public domain by CICLOPS's statement. Björn Jónsson's ring and planet maps aren't usable: they name no licence and ask not to be re-hosted. Solar System Scope's textures are CC BY 4.0 and usable.

## What the real thing looks like, from just above the ring plane

All of these are Cassini ISS pictures on the NASA Photojournal. Each page is `https://photojournal.jpl.nasa.gov/catalog/PIAnnnnn`, which now redirects to `science.nasa.gov/photojournal/...`. The JPEGs are at `https://assets.science.nasa.gov/dynamicimage/assets/science/psd/photojournal/pia/piaNN/piaNNNNN/PIANNNNN.jpg?w=1600&h=1600&fit=clip`. Each one's credit line is "NASA/JPL/Space Science Institute" (or "NASA/JPL-Caltech/Space Science Institute" from 2010). Elevations and phase angles are from the captions.

**Low elevation, the view the idea describes (these matter most)**
- **PIA09860, "Rings Aglow"** (2008). Natural colour, the unlit side from 5° above, phase 114°, 34 km per pixel. It is the reference for this wallpaper. Wide soft bands in peach-cream and mauve-brown fill the frame and curve away. One band glows (#c39d77, peak #f2cfa2). The caption says the B ring's near and far arms differ in brightness, possibly from wakes, and I measured the near arm at about half the far arm's brightness (L 44 against 87). Sky L 4.
- **PIA08282, "The Color of Darkness"** (2006). Natural colour, 3° above the unlit side, phase 154°. At 3° the rings close to a thin sliver beside the planet's night side, which ringshine lights. It shows how little ring there is to see from exactly in the plane, so the camera should sit higher, about 4–15°.
- **PIA08304, "Golden Night on Saturn"** (2006). Natural colour, unlit side, phase 151°. The rings and planet turn golden. The caption gives the reason: "increased scattering ... brought about by the high phase angle and the view being toward rings' the unlit side." The night side is lit amber by ringshine (#372110). This is the warmest real look, and the one closest to Black Hole.

**Lit face and unlit face**
- **PIA06485, "Musical Rings"** (2004). Natural colour, the sunlit face from below the ring plane, 54 km per pixel. The caption names the C ring, the "multi-hued B ring", the Cassini Division (4,800 km), the A ring with the Encke (325 km) and Keeler (35 km) gaps, and the F ring. It is my source for the lit-face colour of each ring.
- **PIA11478, "Pastel Rings"** (2009). Natural colour, the sunlit side from 48° below. The translucent C ring against the planet, with the B ring above. Shows the C ring's plateaus and the ring shadows on the planet.
- **PIA21628, "Colorful Structure at Fine Scales"** (2017). The highest-resolution natural-colour picture of the rings: the B ring between 98,600 and 105,500 km. Its caption: "The pale tan color is generally not perceptible with the naked eye in telescope views", ringlets about 40 km wide and bands of 300–500 km, and "Cassini radio occultations of the rings have shown that these features have extremely sharp boundaries on even smaller scales ... than the camera can resolve here".
- **PIA08388, "On the Final Frontier"**, and its labelled narrow-angle twin **PIA08389, "Expanse of Ice"** (2007). Natural colour, 39° above the unlit side. The B ring goes nearly black and the C ring and Cassini Division show bright. The planet's shadow cuts a black wedge across every ring. PIA08389 labels the gaps and ring edges, so it is a good check on the radial profile.
- **PIA08361, "Ring World"** (2007). Natural colour, unlit side, 60°. The caption calls it a "copper-colored ring world". The shadow reaches across the whole ring system.
- **PIA09906, "Revealing Saturn's Colors"** (17°, unlit) and **PIA08838, "Greetings from Saturn"** (19°, unlit). The planet seen through the dark rings, with the rings' shadows on it.

**The planet's shadow across the rings**
- PIA08388 and PIA08361 show it from the unlit side, PIA06193 ("The Greatest Saturn Portrait ...Yet", 2004) and PIA21345 ("So Far from Home", 2016, sunlit side from 25°) from the lit side. In all four it is black (L 0–4) with a crisp edge. Its length changes with Saturn's season: short behind the planet near solstice, long enough to cross all the rings near equinox. A different Sun elevation on each load is real variety.
- My calculation for its edge: the Sun is about 3.4 arcminutes across at Saturn (32′ over 9.5 AU), so the shadow's penumbra is about a thousandth of the distance behind the limb, roughly 60–130 km across the main rings (the rings' distances from the planet, about 67,000 to 137,000 km, are from memory). That is one or two of the profile's samples: a sharp edge, softened only by antialiasing.

**Equinox (August 2009): vertical structure casting shadows**
- **PIA11667, "The Rite of Spring"**: the rings a day after equinox, lit edge-on and dim (#4c3d23, L 62).
- **PIA11668, "The Tallest Peaks"**: structures at the B ring's outer edge "as high as 2.5 kilometers" cast long shadows. The caption puts the rings' own thickness at "generally only about 10 meters".
- **PIA11571, "Complex Edge Waves"**, **PIA11655, "Wave Shadows in Motion"** (a movie) and **PIA12622, "Shadows from the Waves"**: Daphnis's waves on the Keeler gap, 0.5 to 1.5 km tall from their shadows.
- **PIA12601, "Pan's Effects"**: Pan's shadow on the A ring, with its dark wakes inside the Encke gap's edge.

**Moons and their ripples**
- **Daphnis** in the Keeler gap: PIA21056 ("Daphnis Up Close", 2017; the app already has it in Space Tour), PIA11571, PIA11655. Waves on the inner edge lead the moon and those on the outer edge trail it, as both captions explain.
- **Pan** in the Encke gap: PIA07528 ("Revealing Pan's Influence", 2005), PIA09883 ("Waking the A Ring", 2008), PIA21060 ("Moon Waves and Moon Wakes", 2016: a Janus–Epimetheus density wave beside the wakes of "a recent pass of the ring moon Pan").
- **Propellers**: PIA21447 ("Bleriot Propeller Close-up", 2017), PIA21059 ("The Propeller Belts in Saturn's A Ring"), PIA12792 ("Propeller Churns the A Ring", a movie). A moonlet too small to see makes a short two-armed disturbance.
- **Which one is "a moon's ripple passing through"?** Daphnis is the best. The moon itself can be shown, the ripple belongs to it and moves with it, its size is measured, and the gap's edge visibly undulates even when not at equinox. Pan's wakes are the alternative: a longer, fainter pattern that runs out behind it. Propellers are too small to read on a desktop unless the camera is very close. Density and bending waves (PIA21060) are real ripples too, but they stand still in the moon's frame and don't pass through.

**Spokes**
- **PIA07731** (2005: the first Cassini spokes, about 3,500 km long, phase about 145°), **PIA07807** (the first seen on the sunlit side: bright at high phase), **PIA11144** ("'Tis the Season for Spokes", movies: dark at low phase), **PIA10450** ("Like Spokes of Old", 2008, wedge-shaped). They are faint radial smudges over the B ring that form and fade over hours, and were common near equinox. As a rare, faint event they are calm and real. They aren't a moon's doing.

**Backlit**
- **PIA17172, "The Day the Earth Smiled"** (2013). Natural colour, the unlit side 17° below, with Saturn eclipsing the Sun. The rings are olive-grey (#464133 to #746f5e), the F ring a near-white thread, and the E ring a blue haze (#606d99). Earth is a dot.
- **PIA08329, "In Saturn's Shadow"** (2006). Its caption says the colour was made from ultraviolet, infrared and clear filters "and was then adjusted to resemble natural color". **PIA14934, "A Splendor Seldom Seen"** (2012) is "enhanced-color" from infrared, red and violet: its rings are green-gold, so it is not a colour source.

**Close-ups (ring-grazing orbits, December 2016 to 2017)**
- PIA21058 ("Saturn's B Ring, Finer Than Ever", 360 m per pixel), PIA21057 ("Straw in the B Ring's Edge"), PIA21627 ("Staggering Structure") and PIA21628 (above). NASA's release is at https://science.nasa.gov/missions/cassini/close-views-show-saturns-rings-in-unprecedented-detail. They show what "thousands of fine bands" means at the finest scale: bands within bands, with no end of detail.

**The F ring**: a thin, braided thread just outside the A ring. It is bluish-grey on the lit face (#9191a1, PIA06485) and near-white when backlit (PIA17172). A single faint thread at the outer edge is real and cheap.

## What is seen, in numbers

**Colour by ring, lit face** (means of 40 × 30 to 200 × 220 px boxes; PIA06485 is stretched for the press, PIA21345 as shot):

| Ring | PIA06485 (2004) | PIA21345 (2016) | Other | Brightness relative to B |
|---|---|---|---|---|
| B | #dac8b9, L 203 | #5e5843, L 88 | PIA21628 #8b866b to #bdbca5; PIA11478 #807262 | 1 |
| A | #948b88, L 141 | #3a3327, L 52 | | 0.6–0.7 |
| Cassini Division | #2e2e35, L 46 | #0d0c08, L 12 | | 0.14–0.23 |
| C | #3d3a41, L 59 | #443e2d, L 62 (C and inner B) | PIA11478 #232021, L 33 | 0.25–0.3 |
| F | #9191a1 (thread) | | PIA17172 backlit #7a797e | |

- Range of the lit B ring across four pictures: hue 26–51°, saturation 0.15–0.3. The images disagree on hue (pinkish cream in 2004, olive-tan in 2016 and 2017) because each was processed differently. Treat 26–51° as the true range and pick within it.
- The C ring and Cassini Division are the one cool note: blue just above red (#2e2e35, hue 257°, saturation 0.19) but very dark (value 0.14). It reads as cool grey, not as a second colour, as long as it stays dark.

**Unlit face**
- From 39° (PIA08388): A ring #514c46 to #65625d (L 76–98), B ring #131210 (L 18), C ring #38322d (L 51). PIA09906 (17°) agrees: rings L 19.
- From 5° at phase 114° (PIA09860): mid bands #624f43 (L 82), far arm #69543f (L 87), near arm #352a23 (L 44), glowing band #c39d77 (L 162), peak #f2cfa2. Warmer than the lit face: hue 28–34°, saturation 0.33–0.37.
- At phase 151° (PIA08304): #553e2c, with a range from #1d0a03 to #ddbd84. Saturation is 0.57 and more in the darks.

**Rings against the planet**: in the same exposure, the B ring is 0.55–0.6 of the planet's lit face (PIA21345: 88–92 against 158; PIA11478: 116 against 201). The lit planet is buttercream: #d1bb97 (PIA06193), #a89671 (PIA11141), #a89964 (PIA17474), #a69f82 (PIA21345), with the southern hemisphere a paler gold (#e1c981, PIA11478). The night side lit by ringshine is a deep amber (#372110, PIA08304). In 2004–2009 the northern hemisphere looked blue-grey (PIA11478, PIA09906); that is a second colour family, so leave it out.

**Contrast between bands**: within one ring, the 10th to 90th percentile of luma spans ±8% (PIA06485's B ring, 186–222; PIA21345's B ring, 82–96) to ±20% (PIA11478's B ring, 91–138), and ±28% on the unlit side from 5° (56–99). Between rings, brightness jumps 3 to 6 times (B to the Cassini Division). So the picture is broad plateaus, each finely and gently banded, with a few sharp steps. It is not evenly striped.

**How sharp the gap edges are**: at every scale the camera can resolve, they are as sharp as a pixel. The B ring's outer edge in PIA06485 goes from L 203 to 50 within two 12-px samples. PIA21628 says the occultations show the boundaries are sharper still. In the 5° view the steps survive while fine banding blurs, so steps should stay crisp (antialiased) and ringlets soft.

**The sky**: L 0–5 in every exposure (PIA06193 0, PIA06485 0, PIA21345 3, PIA09860 4, PIA17172 4 with a blue cast). No stars register in exposures set for the rings, apart from the occasional planet or moon. Real stars would be a liberty, so if they are added (Black Hole's catalogue stars), they should be sparse and faint, at L 30 or less. The black should be a near-black, L 4–8, like Galaxy's.

## Palettes, each in one family
Each palette is five stops from dark to light, sampled from one photograph's ring pixels at their 5th, 25th, 50th, 75th and 95th or 99.5th luma percentile (`ramp.py`). The shader would take hue from the palette and brightness from the data, scaled down to the caps below. All are cream, tan and taupe, with a cool grey only in the darkest stop.

1. **Sunlit** (lit face, from PIA06485 "Musical Rings"): `#1f1d24` `#8a827f` `#968e8d` `#cebdb0` `#e3d3c8`. Cool grey gaps, a grey A ring, a cream B ring. Saturation 0.06–0.19. It suits the lit face, and the planet's shadow shows best on it. **My default**: it is the most recognisable, calmest and least like Black Hole. The press stretch puts the B ring at L 203, so show it at about 0.55–0.65 of these values.
2. **Butterscotch** (lit face, from PIA21628, the finest natural-colour picture of the B ring): `#3a3a36` `#6f6d5e` `#8b866b` `#9b967a` `#bdbca5`. Olive-tan, hue about 50°, saturation 0.2. PIA21345's as-shot rings (`#3a3428` `#59523e` `#625b46`) are the same hue. Suits a close, low view of the B ring.
3. **Ringlight** (unlit face from 5°, from PIA09860 "Rings Aglow"): `#140c0a` `#503f31` `#695442` `#9a7d67` `#f2cfa2`. Mauve-brown with a peach-cream glow, saturation 0.33–0.39 (0.5 in the darkest stop). The truest picture of "just above the ring plane". It is the warmest of the four I'd offer, so cap its peak (the glowing band) at about L 170.
4. **Backlit** (from PIA17172 "The Day the Earth Smiled"): `#171517` `#39352c` `#514c41` `#746f5e` `#d5d5d6`. Olive-grey with a near-white F ring. Suits a backlit or eclipse view. It leaves out the E ring's blue (#606d99), which would be a second family.
5. **Golden night** (unlit face, high phase, from PIA08304): `#1d0a03` `#362217` `#533d29` `#a48860` `#ddbd84`. Amber, saturation 0.4–0.6 in the middle stops and 0.9 in the darkest: real, and the closest to Black Hole's orange (hue 21–35°). Mock it up beside the others so Dave can see the problem, but I wouldn't offer it.

For **equinox**, use a lighting mode rather than a palette. The rings dim to L 40–70 (PIA11667: `#332919` `#514227`) in whichever palette is chosen, and the shadows of the Keeler gap's waves and the B ring's peaks show.

The planet, in every palette: lit face `#a89671` to `#d1bb97`, night side lit by ringshine `#372110`, all in the same warm family.

A new look each load could pick among 1 to 4, the side (lit or unlit), the Sun's elevation (the shadow's length) and the camera's elevation. Two that I'd recommend Dave sees side by side: Sunlit and Ringlight.

## Brightness caps
Measured on the app's own stills in `docs/images` (1600 px, luma as above). Space Tour's Saturn photos were measured on 1600-px conversions of the HEICs in `Resources`, before its Brightness slider and Soften.

| Still | Median | 99th | 99.9th | Max |
|---|---|---|---|---|
| Black Hole (default) | 23 | 196 | 254 | 255 |
| Black Hole wide / close / blue-white | 17 / 61 / 34 | 227 / 255 / 255 | 255 | 255 |
| Galaxy (Andromeda, Barred, Milky Way, Whirlpool) | 9–12 | 163–178 | 202–222 | 255 |
| Nebula (Hubble, Oxygen, Planetary, Reflection) | 15–80 | 175–225 | 190–241 | 255 |
| Space Tour's Saturn (portrait, equinox, shadows, rings, far, eclipse) | 0 | 142–212 | 193–235 | 207–254 |
| Cassini, PIA09860 (5°, unlit) | 18 | 168 | 232 | 247 |
| Cassini, PIA21628 (the B ring filling the frame) | 134 | 211 | 221 | 232 |

Unlike Black Hole and Galaxy, the rings fill half the screen or more, so the median is set by the rings, not the sky. Proposed caps for this wallpaper, measured the same way on a desktop-size still:
- **Sky**: L 4–8.
- **Median of the frame**: 30–45 (Nebula's Hubble still is 42; Black Hole's close-up, at 61, is too bright).
- **99th percentile**: 170 or less (Galaxy's range).
- **99.9th percentile**: 195 or less. This is the number that keeps it from being "bright and sharp": thin bright ringlets are what reach it. Black Hole's 254 is the thing not to repeat.
- **Max**: 215, with no clipped pixel. The planet's lit limb, if it is in frame, is the brightest thing (1.7–1.8 times the B ring), so it sets the max, and the lit B ring then averages about L 100–120.
- **Shadow**: L 2–5, dithered (8-bit banding shows in near-black gradients, as on Galaxy).
- **Within a ring**: keep Cassini's ±8–20%. Between rings: keep the 3–6× steps. Lower contrast inside the rings, not between them.

## Data and image licences
Only public domain or permissive licences (CC0, CC BY, CC BY-SA and similar) are usable. **Checked** means the licence page was read on 2026-11-18, quoted, with its URL. **Unchecked** means it wasn't.

| Source | Status | What it says | Verdict |
|---|---|---|---|
| NASA SMD Scientific Information Policy, SPD-41a (applies to Cassini's ring occultation data at the PDS) | **checked**: https://science.nasa.gov/spd-41/ (the PDF), linked from https://science.nasa.gov/researchers/science-data/science-information-policy/ | "Publicly available SMD-funded data shall be reusable with a clear, open, and accessible data license. If there are no other restrictions, SMD scientific data should be released with a Creative Commons Zero license." And, footnote 29: "Mission data are released into the public domain". | **Usable.** Credit the instrument team and the PDS as the PDS asks. |
| PDS Ring-Moon Systems Node (rings.seti.org / pds-rings.seti.org: UVIS, VIMS and RSS occultation profiles) | **checked: no terms stated**. https://pds-rings.seti.org/ and https://pds-rings.seti.org/about/ (an unfilled template) | No licence or usage terms on the node's pages. | Usable on SPD-41a's strength. Name the dataset (volume ID or DOI) and its team in the data file's header and in About. |
| NASA PDS, citing data | **checked: no licence named**. https://pds.nasa.gov/datastandards/citing/ | Asks users to "give credit to those who prepared, curated, and archived the data." | Credit, as above. |
| Cassini imaging (all the PIA images above) | **checked**: https://ciclops.org/webcredits.php.html | "Cassini image products — images, mosaics, movie clips — and their associated graphics, captions and press releases are public domain." | **Public domain.** Credit "NASA/JPL-Caltech/Space Science Institute", as Space Tour already does. |
| JPL Image Use Policy | **checked**: https://www.jpl.nasa.gov/jpl-image-use-policy | JPL images "may be used for any purpose without prior permission, subject to the special cases noted below"; credit "Courtesy NASA/JPL-Caltech." Exceptions: logos, identifiable people, third-party images. | Usable for colour sampling and reference. |
| NASA Photojournal | **checked: no terms stated**. https://science.nasa.gov/photojournal/ and https://science.nasa.gov/photojournal/about-photojournal/ | No usage statement; each page carries only its credit line. | CICLOPS and JPL above cover its Cassini images. |
| NASA images and media guidelines | **checked**: https://www.nasa.gov/nasa-brand-center/images-and-media/ | "NASA content – images, ... texture maps and polygon data in any format – generally are not subject to copyright in the United States", "NASA should be acknowledged as the source", no endorsement implied. The page's banner also says "The NASA Insignia, Logotype, identifiers, and imagery are not in the public domain", which contradicts it. | Usable with credit, no logos, no implied endorsement. |
| Solar System Scope textures (Saturn 2k/8k, ring 2k/8k alpha) | **checked**: https://www.solarsystemscope.com/textures/ | "Distributed under Attribution 4.0 International license: You may use, adapt, and share these textures for any purpose, even commercially." "Textures in this pack are based on NASA elevation and imagery data." | **CC BY 4.0, usable** with credit, for the planet's face. The ring strip is artwork and not as true as the PDS profile. |
| Björn Jónsson's Saturn map and ring model | **checked**: http://bjj.mmedia.is/data/planetary_maps.html and http://bjj.mmedia.is/data/s_rings/index.html | "publicly available. You do not need a special permission to use them but ... please mention their origin", and "please do not place a copy of the maps on your website." The ring model is built from Voyager images and Voyager stellar occultation data, coloured from one Cassini image. His "legal stuff" page is a 404. | **Not usable**: no licence is named and redistribution is restricted. Shipping a copy inside an app is redistribution. |
| Celestia's bundled Saturn and ring textures | **unchecked** per file. https://github.com/CelestiaProject/CelestiaContent (LICENSE.md: the software is GPL-2.0-or-later, and data is licensed per file) | Its README credits the Saturn texture to Jónsson's map "improved and recolored by Askaniy" and the ring texture to "data found on Björn Jónsson's site". | Not usable: it is Jónsson's terms underneath. |
| NOAA Science On a Sphere, Saturn | **checked**: https://sos.noaa.gov/catalog/datasets/saturn/ and https://sos.noaa.gov/copyright/ | Data source "Bjorn Jonsson". No licence on the page. | Not usable (Jónsson's terms). |
| Steve Albers' SOS maps | **checked**: https://stevealbers.net/albers/sos/sos.html | "intended for personal non-commercial use only"; the Saturn map is from Jónsson's site. | Not usable. |
| NASA's Saturn 3D model (VTAD, 2019) | **checked: terms only**. https://science.nasa.gov/resource/saturn-3d-model/ | No texture source or licence on the page; NASA's media guidelines (above) name texture maps as generally not under copyright. | Probably usable. The `.glb` wasn't opened, so where its texture comes from is unknown. |
| A Cassini global cylindrical map of Saturn's cloud tops | **unchecked: not found** | No Photojournal entry was found in the time available. | Not needed: near the ring plane the planet shows as a limb or a crescent, and zonal bands in the measured buttercream colours (above) would do. |
| Celestia Motherlode | **unchecked**: https://celestiamotherlode.net/ failed (TLS certificate error) | | |

So the ring data's licence comes from NASA policy, not from a licence page on the dataset. That is the same footing as the NASA imagery the app already ships, and the strongest available. Two things before shipping: name the exact datasets in the data file's header (the method agent picks them), and check the dataset's own label or DOI landing page for any extra terms. I didn't open one.

## How it differs from Black Hole at a glance

| | Black Hole | Saturn's Rings |
|---|---|---|
| Light | glows by itself, with a bloom | sunlight reflected or scattered; no glow anywhere |
| Colour | orange, hue 29° at saturation 0.57 (`#df9c5f` at L 166, measured on `black-hole.jpg`) | cream, tan and cool grey, saturation 0.08–0.3 |
| Composition | a centred ellipse round a black hole, on black | the ring plane running off both edges of the screen like a ground plane, receding to a thin horizon; the planet's limb or shadow to one side, never centred |
| Structure | sheared streaks that fork and fade | broad plateaus, finely banded, with a few sharp steps (gaps); straight bands at the scale of the screen |
| Dark shape | a round shadow at the centre | the planet's straight-edged shadow cutting across the bands |
| Motion | a disc turning round a centre | bands sliding sideways past a shadow that stays still, and a moon's ripple travelling along a gap |

What would make it read as Black Hole again: orange or amber (Golden night), any glow or bloom, a full ellipse of rings seen edge-on round a centred planet, and Keplerian streaks. So keep the planet off-centre or partly off-screen, keep it soft rather than glowing, and keep the rings filling the frame as a surface rather than circling an object.

## Names and look-alikes
- **"Saturn's Rings"** is plain and descriptive, in the same style as Black Hole, Galaxy and Nebula, and clashes with nothing in the app's table. "Saturn" alone is a brand in several fields (a German electronics retailer, a defunct car maker, a games console), but "Saturn's Rings" is the astronomical phrase, and the menu shows the whole name. It is close to the film title *In Saturn's Rings* (2018) and the novel *The Rings of Saturn* (Sebald, 1995). As a description of the subject it's fine.
- **Alternatives**: **Ring Plane** (my pick if a name of its own is wanted: it's the technical term, it says where the camera is, and nothing else in the app uses it), or **Ringlight**, though that is also a photographer's lamp.
- **Famous views not to copy**: the film *In Saturn's Rings* (2018, made from real photographs: swooping fly-throughs); *Interstellar* (2014), where a small ship passes over the ring plane with the planet huge behind; *The Expanse*, with ships and ice haulers in Saturn's rings; Sagan's *Cosmos* and its 2014 successor, where the ship of the imagination flies through the rings; Chesley Bonestell's Saturn paintings (1944 on, from its moons); space-simulation games' ring fields, with chunky tumbling boulders. To stay clear: no ship or spacecraft, no fly-through or swoop, no boulders (the particles are centimetres to metres and read as a continuous sheet from any desktop distance), no lens flare or sunburst behind the planet, and a slow drift at a fixed height. The look comes from Cassini's data and natural-colour frames, not from any film.

## What to avoid, from the brief
- **Bright and sharp**: the 99.9th percentile and max caps above. Fine bright ringlets are the risk, so soften the banding within a ring before touching the steps between rings.
- **Flicker**: thousands of bands, foreshortened toward the horizon, will alias and shimmer as they move unless the far field averages to a smooth tone. Cassini's own 5° view shows exactly that: the far arm is smooth (PIA09860). Spokes and a moon's shadow must fade in and out, never pop.
- **Two colour families**: no blue E ring, no blue northern hemisphere, no enhanced or false colour (PIA14934, PIA08329's processing, UVIS's blue and red maps). The cool grey of the C ring and Cassini Division stays dark.
- **Static for long**: sideways drift is slow by nature, so give each load its own Sun elevation (shadow length), side (lit or unlit), camera height and palette, a moon or spokes coming round every few minutes, and an optional slow radial drift across the rings (C ring, B ring, Cassini Division, A ring, Encke gap, Keeler gap, F ring) so the structure under the camera changes over tens of minutes. Never let the shadow or an empty plane fill the frame: rings must always be in view.
- **Nothing religious; no brand names**: none of the above needs any.

## Not done, or from memory
- The ring orbital periods and Saturn's obliquity (26.7°, which sets how far the Sun's elevation ranges with the seasons) are from memory and should come from NASA's Saturn fact sheet. Speed is the method agent's to set.
- The search engine's summaries say that inner A ring is redder and outer A more turquoise. I didn't read the caption that says so.
- I didn't open the PDS dataset labels or DOI pages for the occultation profiles, or NASA's Saturn `.glb`.
- The colour hexes are from press JPEGs at 1600 px. The TIFFs would give cleaner darks, but the hues and ratios won't change much.
