# Jellyfish: the look research

A research agent's report on the look of a jellyfish wallpaper drawn by shaders, written 2026-11-07. How to draw and move them is researched separately. Every claim is marked **checked** (the page that says so was read on 2026-11-07) or **unchecked**. A Commons licence marked checked means Commons' own licence field for that file, which is only as good as the uploader's claim. Downloaded references and scripts were kept in `$TMPDIR/jelly/` and aren't in the repo. Their URLs are below.

## Summary and recommendation

1. **Species:** seven in two sets. The deep set is Atolla, Periphylla, Halitrephes and a lobate comb jelly. The aquarium set is the moon jelly, Pacific sea nettle and crystal jelly. Pelagia is a spare. Deepstaria is left out: it reads only when huge, and no free photo of it turned up.
2. **Backdrop:** true black, after Monterey Bay Aquarium's Into the Deep gallery, which shows helmet jellies and mauve stingers on black (checked). Light Mode is the same aquarium's jelly gallery: moon jellies in a lit blue tank.
3. **Two kinds of light, never mixed up:** bodies as a dim lamp shows them (garnet, nettle gold, moon-jelly mauve), and the animals' own light. That light is 465 to 475 nm blue for the deep ones and 509 nm green for the crystal jelly alone.
4. **Default palette:** Garnet bodies with Sapphire light on black, the red that "looks black in the deep" and the blue it glows. Five more palettes, each one family.
5. **Brightness:** backdrop 0 to 8 of 255, bodies mostly 20 to 60, nothing wider than a few pixels above 150, pinpoints to 190 at most. Nebula's own 99th percentile is 150.
6. **No flashing:** every real display here is a flash when disturbed. Draw them as rare, slow, dim waves, one animal at a time.
7. **One tank, one species,** as aquariums do; the deep view is a sparse mix. A Species menu with Changing as the default gives a new one each load, as Nebula does.
8. **Real data:** one honest hook, the Sun where the user is. By day a faint blue from above and Periphylla at the view's depth; by night dark, with fewer as they rise (Lurefjorden's measured depths). Moon phase: no.
9. **Name:** Jellyfish. It is plain like Fireflies. "Jellies" sits next to Apple's own Palau Jellies and Alaskan Jellies aerials, and "Deep Sea" is too near Space Tour's deep space.
10. **Avoid:** the neon pink-and-cyan glowing jellies of Wallpaper Engine and stock art (no jelly's light is pink), bloom halos and jellies pulsing in step.

## 1. Species

Ranked by how well each reads small and in silhouette, past windows: sea nettle (bell and long trails), moon jelly (four rings), Periphylla (a cone), Atolla (a red disc with one long tentacle), comb jelly (an oval, and only where its rows catch light), Halitrephes (a starburst that needs about 150 px), crystal jelly (a ring of points, otherwise invisible), Deepstaria (needs most of the screen).

**A rule for all of them:** red, gold and violet are pigment seen under a lamp. In the dark the deep ones are invisible except for their own light, which is blue. Monterey Bay Aquarium's Into the Deep page says "Red light doesn't reach the deep sea, so red animals like these look black and are invisible to most predators" (checked). Comb-row rainbows are outside light bent by the combs, so they need a lamp too.

### Moon jelly (*Aurelia aurita*; Monterey's may be *A. labiata*, unchecked)
- **Look:** a translucent flattened saucer, usually 25 cm and up to 40 (MarLIN, checked); Monterey Bay Aquarium says up to 60 cm (checked). Four horseshoe gonads in the middle, a fringe of hundreds of short fine tentacles, four frilly oral arms.
- **Colours:** bell colourless; MarLIN: "the radial canals, oral arms and gonads are typically mauve, violet, reddish, pink or yellowish" (checked). Under aquarium blue the bell reads pale cyan, #23A1FD to #76EDFE on a #0167FE tank, and gonads #D0B5DC (my samples from two Commons photos below). In the dark: nothing.
- **Light:** none known. Haddock et al. 2010 name the luminous semaeostomes (Pelagia, Phacellophora, Poralia) and leave Aurelia out (checked). I found no source that says it glows.
- **Depth:** coastal surface water; the aquarium says "open ocean", "common in Monterey Bay" (checked). A depth range: unchecked.
- **Small:** the best of all from above or at a tilt, where the four rings read at 30 px. Side-on it's a plain dome.
- **References:** [Aurelia-aurita-3.jpg](https://commons.wikimedia.org/wiki/File:Aurelia-aurita-3.jpg) (CC0, aquarium on blue), [San Sebastián Aquarium](https://commons.wikimedia.org/wiki/File:Common_jellyfish_(Aurelia_aurita)_in_The_San_Sebasti%C3%A1n_Aquarium,_Spain.jpg) (CC BY 4.0), [Monterey Bay Aquarium](https://www.montereybayaquarium.org/animals/animals-a-to-z/moon-jelly) (all rights reserved).

### Pacific sea nettle (*Chrysaora fuscescens*), and the black sea nettle (*C. achlyos*)
- **Look:** a bell to 45 cm with mouth-arms 3.6 to 4.6 m long (Monterey Bay Aquarium, checked); 24 maroon marginal tentacles (a Commons caption, unchecked). The bell is ribbed by dark radial stripes; the oral arms are long white frilled ribbons.
- **Colours:** "golden-brown bell with a reddish tint" (Wikipedia, checked, secondary). Sampled on a dark navy tank (#070B14): bell #5F3C1E to #977241, oral arms #AFB3C8. The black sea nettle's bell is nearly black maroon, #13090E, its arms #B72B2A to #F17265 (samples).
- **Light:** none known; not among Haddock's luminous scyphozoans (checked).
- **Depth:** coastal, Alaska to California and Japan (Monterey Bay Aquarium, checked).
- **Small:** the strongest silhouette here: a bell with trails four to ten times its height.
- **References:** [Pacific sea nettles](https://commons.wikimedia.org/wiki/File:Pacific_Sea_Nettles_(Chrysaora_fuscescens).jpg) (CC BY 2.0, Monterey on dark), [Sea nettle 2](https://commons.wikimedia.org/wiki/File:Sea_nettle_(Chrysaora_fuscescens)_2.jpg) (CC BY 2.0), [black sea nettle](https://commons.wikimedia.org/wiki/File:DSC26402,_Black_Sea_Nettle_(%22Chrysaora_Achlyos%22),_Monterey_Bay_Aquarium,_Monterey,_California,_USA_(5513975178).jpg) (CC BY 2.0), [Monterey Bay Aquarium](https://www.montereybayaquarium.org/animals/animals-a-to-z/sea-nettle).

### Crystal jelly (*Aequorea victoria*)
- **Look:** up to 25 cm, "nearly transparent", long delicate tentacles (Monterey Bay Aquarium, checked). A shallow clear dome ribbed by many fine straight radial canals: a glass wheel.
- **Light:** "more than 100 tiny, light-producing organs surrounding its outer bell", a green-blue glow "when disturbed" (Monterey Bay Aquarium, checked). The reaction itself gives blue at about 470 nm, but GFP beside it re-emits the energy as green (Haddock et al. 2010, checked). Live animals peak at about 508 to 509 nm (several sources via search, consistent; aequorin alone 470 nm per a 2025 *Scientific Reports* paper, PMC12374965, checked).
- **Depth:** "the shallow-living hydromedusa" (Haddock et al. 2010, checked).
- **Small:** invisible but for its ring of green points, which reads well even small on black. It is the only green animal in the set.
- **References:** [Monterey Bay Aquarium photo](https://commons.wikimedia.org/wiki/File:DSC26476,_Crystal_Jelly_(%22Aequorea_Victoria%22),_Monterey_Bay_Aquarium,_Monterey,_California,_USA_(5084797073).jpg) (CC BY 2.0), [Aequorea victoria.jpg](https://commons.wikimedia.org/wiki/File:Aequorea_victoria.jpg) (CC BY-SA 3.0), [Monterey Bay Aquarium](https://www.montereybayaquarium.org/animals/animals-a-to-z/crystal-jelly). No free photo of its glow was found.

### Deep-sea crown jelly (*Atolla wyvillei*)
- **Look:** a flat disc to 15 cm, its rim and centre parted by a deep groove and edged with lappets (seen in the photos), with about 20 marginal tentacles. Most have one "elongated tentacle that can be up to six times the diameter of the jelly's bell" (MBARI, checked; the count is Wikipedia citing Boltovskoy 1999, checked, secondary). From above: a red sun with a darker centre.
- **Colours:** "bright red bell"; "in the deep sea, red appears black" (MBARI, checked). Under a strobe it samples #54150C, #911D0A, #CD390F and #DB7641 (both Commons Deep Scope photos).
- **Light:** "pinwheels of brilliant blue bioluminescence" when threatened (MBARI, checked). Herring and Widder 2004: "localised flashes and propagated waves of light in the surface epithelium", with point sources "generally absent from the dome" (abstract, checked). Waves travel 5 to 50 cm/s (Wikipedia citing them: unchecked). Peak wavelength: unchecked; a popular site says 474 nm, and Haddock's 470 nm centre fits.
- **Depth:** 500 to 5,000 m (MBARI, checked).
- **Small:** a red dot alone, but the one long tentacle makes it unmistakable at 60 px and up.
- **References:** [Operation Deep Scope 2004](https://commons.wikimedia.org/wiki/File:Atolla_wyvillei_(Operation_Deep_Scope_2004).jpg) (Commons says CC BY-SA 2.0, from NOAA's Flickr; a NOAA work is probably public domain, but treat it as tagged), [NOAA Puerto Rico 2015](https://commons.wikimedia.org/wiki/File:Coronate_of_the_genus_Atolla_Puerto_Rico_28_April_2015.png) (public domain, NOAA), [MBARI](https://www.mbari.org/animal/deep-sea-crown-jelly/) (educational use only).

### Helmet jelly (*Periphylla periphylla*)
- **Look:** a tall cone, a helmet, with a scalloped skirt of lappets and twelve thick tentacles; to about 30 cm (Wikipedia, checked, secondary). Wikipedia puts the purple pigment in the mouth and stomach; the photos show a red cone throughout.
- **Colours:** deep red to purple; samples #863733 and #221319 (Choy, Haddock and Robison's ROV frame), and #B37085 seen through blue fjord water (iNaturalist photo).
- **Light:** luminous (Haddock et al. 2010, checked). Point sources over the dome, and "scintillating particles released from the lappet margins" (Herring and Widder 2004 abstract, checked). Monterey Bay Aquarium shows it "lit up with blue bioluminescent spots on a black background" and calls it a "bright-blue strobe" against danger (Into the Deep page, checked). Live light peaks at 470 to 475 nm (Shimomura and Flood 1998, citing Herring 1983 and Widder 1983; seen in excerpts only, so partly checked). Wikipedia's "red flashes" has no source and contradicts the measurements: ignore it.
- **Depth and migration:** worldwide at depth. In Norway's Lurefjorden, the population's median depth was 155 m by day and 36 m by night, with about 20% above 25 m at night (a 2018 *J. Plankton Res.* study, PMC5914403, checked; its authors weren't confirmed).
- **Small:** the cone reads at any size; the best deep silhouette.
- **References:** [in a fjord](https://commons.wikimedia.org/wiki/File:Periphylla_periphylla_231613661.jpg) (CC BY 4.0), [ROV frame](https://commons.wikimedia.org/wiki/File:Helmet_jellyfish_feeding_on_gonatid_squid.jpg) (CC BY-SA 4.0), [Into the Deep, the midwater](https://www.montereybayaquarium.org/visit/exhibits/into-the-deep/the-midwater) (all rights reserved).

### Fireworks jelly (*Halitrephes maasi*)
- **Look:** a clear shallow bell whose radial canals "form a starburst pattern that reflects the lights of ROV Hercules with bright splashes of yellow and pink"; without the lights it "drifts unseen in the dark" (Ocean Exploration Trust, checked). Filmed at 1,225 m off Baja California (checked). A fringe of many fine tentacles (NOAA photo). Bell size: unchecked. The count of 28 canals: unchecked.
- **Colours:** yellow and pink canals under ROV lights (checked as words). No free photo shows them, so no hex. NOAA's public-domain photo shows it blue-lit: #2C4282 to #A7B7DF on #010152.
- **Light:** unknown. Haddock et al. 2010 say trachymedusae, its order, are "almost entirely luminous" (checked); no source says this one glows.
- **Small:** a starburst only from above and only large. As one rare, large visitor it would be the set's most beautiful moment.
- **References:** [NOAA Okeanos Explorer](https://commons.wikimedia.org/wiki/File:Halitrephes_Maasi.jpg) (public domain, NOAA), [Nautilus video](https://nautiluslive.org/video/2017/12/31/burst-deep-sea-fireworks-halitrephes-jelly) (© Ocean Exploration Trust).

### Comb jellies (*Bolinopsis infundibulum*, the lobed comb jelly; *Lampocteis*, the bloody-belly)
- **Look:** an oval body with two lobes and eight rows of beating comb plates. *Bolinopsis* is clear; the bloody-belly is deep red to violet with a crimson stomach, to 16 cm, at 250 to 1,500 m (MBARI, checked).
- **The rainbow is not light they make:** "as they swim, the comb rows diffract light to produce a shimmering, rainbow effect" (Monterey Bay Aquarium post, via a search excerpt: partly checked). A cited paper calls it reflection from a photonic crystal (AskNature, unchecked). Either way it needs outside light, so it belongs to the lamp-lit looks only.
- **Their own light:** more than 90% of planktonic comb jelly genera glow, *Pleurobrachia* doesn't (Haddock et al. 2010, checked); *Beroe forskalii* glows "in cascading waves" (same, checked). *Bolinopsis* and *Mnemiopsis* proteins peak at 500 and 490 nm (the same 2025 paper, checked): bluer-green than the jellyfish. The bloody-belly's red stomach hides its glowing prey (MBARI, checked); whether it glows itself: unchecked.
- **Colours on black:** a violet sheen, #2F1E3A, #4F355E, #735383, #A480AB, #EFC1D0, with spectral glints along the rows (samples, Jurvetson's Monterey photo).
- **Small:** a soft oval whose rows sparkle; reads only where the rows catch light.
- **References:** [comb jellies on black](https://commons.wikimedia.org/wiki/File:Comb_jellies-mba.jpg) (CC BY 2.0), [Bolinopsis, NOAA](https://commons.wikimedia.org/wiki/File:Ctenophore_-_Bolinopsis_infundibulum.jpg) (public domain), [Bolinopsis at Monterey](https://commons.wikimedia.org/wiki/File:J20161104-0058%E2%80%94Bolinopsis_infundibulum%E2%80%94Monterey_Bay_Aquarium_(30547378630).jpg) (CC BY 2.0), [Beroe, NOAA](https://commons.wikimedia.org/wiki/File:Beroe_sp.jpg) (public domain), [MBARI bloody-belly](https://www.mbari.org/animal/bloody-belly-comb-jelly/).

### Spare: mauve stinger (*Pelagia noctiluca*)
A mushroom bell with warts, mauve to pink to brown, with long oral arms. It is luminous (Haddock et al. 2010, checked) and flashes when disturbed (Marine Conservation Society, via a search excerpt: partly checked). Its light colour is unchecked. It is in Into the Deep (checked). [Sardinia](https://commons.wikimedia.org/wiki/File:Pelagia_noctiluca_(Sardinia).jpg) (CC BY-SA 4.0).

### Left out: *Deepstaria*
A thin sheet of a bell with a net of canals and no tentacles, "like a plastic bag". Its size is given as 60 cm to a metre or more, at 829 to 1,830 m (secondary sources that disagree: unchecked). It reads only when it fills the screen, and the one Commons image is CC BY-SA from a news site. Not worth it.

## 2. Looks it could offer

Each is a real place.

- **Into the Deep** (Monterey Bay Aquarium, opened April 2022): deep jellies in darkened tanks against a black backdrop. Its midwater page lists the helmet jelly, mauve stinger, bloody-belly comb jelly and red paper lantern jelly among others (checked). In the wallpaper the bodies would be dimly lit and the glow occasional. **The recommended default.** Dark only.
- **Lights off:** the same animals with no lamp at all, so only their own light shows: blue pinwheels and spots, the crystal jelly's green ring. This is the truest picture of the deep and the emptiest, mostly black. Good as a choice, not the default.
- **The jelly gallery:** moon jellies and sea nettles in blue tanks, the aquarium's permanent gallery in its Open Sea wing (its Open Sea page, via a search excerpt). The cerulean "Infinite Blue" backdrop is standard in jelly exhibits (Atlas Obscura, citing the New England Aquarium; the page blocked me, so unchecked). **This is the honest Light Mode:** the tank with its lamps on. Dark Mode is the same tank with its lamps low, after Fish Tank's Lighting menu (Match macOS, lit, lamps low).
- **A fjord at night:** Periphylla alone, many, rising and sinking with the Sun (section 4).
- **One species or a mix:** jelly tanks show one species each (unchecked, but true of every photo found). So the gallery look should hold one species a load. The deep look can mix sparsely. A Species menu: Changing (the default), each species by name, and a Midwater mix.
- **Marine snow:** real at every depth here. Fish Tank already has the switch.

Only the gallery can follow Light Mode honestly. Into the Deep keeps its deep animals in dark tanks, so the deep looks stay dark whatever the appearance, as Nebula does.

## 3. Palettes

Each palette is one family. The deep ones are given at shipping brightness, scaled in linear light so the brightest colour's top channel is 150. Bioluminescence was converted from the emission peak with the CIE 1931 observer (Wyman, Sloan and Shirley's 2013 fit). Each emission was taken as a band 80 nm wide; that width is my assumption (unchecked). Out-of-gamut blues and greens were brought into sRGB by adding the least white.

| Palette | From | Colours, dark to bright |
|---|---|---|
| **Garnet** (default bodies) | Atolla and Periphylla under a lamp: my samples of the Deep Scope and ROV photos | #090406 #14090D #370B05 #621004 #8C2407 #964F2A |
| **Sapphire** (default light) | 470 nm, "centered around 470 nm" (Haddock et al. 2010, checked); Periphylla 470 to 475 | #001121 #00233C #00375C #005E96 (at full: #00A3FF) |
| **Nettle gold** | Pacific sea nettle at Monterey, on #070B14 | #462B14 #70542F #838696 |
| **Moon** | moon jelly bodies and MarLIN's mauve gonads, on the tank blue | bodies #146AA9 #2881AA #4D9EAA, gonads #8A7893 #4E4F9A; tank lit #175ADB, lamps low #021643 |
| **Comb** | lobate comb jelly on black (Jurvetson); spectral glints on the rows as pinpoints only | #1A0F21 #2E1D38 #463150 #654E6A #967882 |
| **Emerald** | crystal jelly's GFP, 509 nm | #002118 #003C2F #005C49 #009678 (at full: #00FFCE) |

- **Garnet with Sapphire** is two hues. On black at these levels the reds are near-black shapes and the blue is the only colour that reads, which is the deep as it is. Mock up both alone and together.
- **Emerald never goes on a blue backdrop:** that is the green-in-blue Dave called ugly. Use it on black with the crystal jelly alone.
- **Moon's colours are for the lit tank** (top 170). In Dark Mode they go under the same 150 cap as the rest.
- **Halitrephes's yellow and pink** have no free source to sample, so no palette is given for them.

**Dim levels**, measured on the app's own Settings previews (the brightest of R, G and B, out of 255):

| Scene | median | 90th pct | 99th | 99.9th |
|---|---|---|---|---|
| Nebula | 30 | 110 | 150 | 168 |
| Galaxy | 21 | 116 | 171 | 203 |
| Flowing Gradient, dark | 105 | 126 | 137 | 138 |
| Live Sky | 10 | 30 | 48 | 65 |

So, on black:

| Part | Brightest |
|---|---|
| Backdrop | 0 to 8 |
| Bodies, most of them | 20 to 60 |
| Anything broad: a lit rim, a glowing bell | 150 |
| Pinpoints of a few pixels: photocytes, comb glints | 190 |

Nothing should reach 255. The 150 and 190 caps are my reading of Nebula and Galaxy, not tested against desktop icons (unchecked).

**The glow, calmly:** every real display here is a flash when disturbed. As my judgement, so that it doesn't flash: one animal at a time, every 30 to 90 s; rise over 1 to 2 s, fade over 4 to 6. Atolla's ring should travel round the bell at about one turn in 2 s, which for a bell about 10 cm across is inside the 5 to 50 cm/s reported; Periphylla's spots should twinkle out of step.

## 4. Real data hooks

- **The Sun, through the daily migration: true, and the only one worth it.** NOAA calls the daily vertical migration "the greatest migration on Earth", jellies among the migrants (via a search excerpt). Lurefjorden's helmet jellies are measured: median 155 m by day, 36 m by night (checked). A view held at about 150 m would show them by day, with the faintest blue from above. After dusk the view goes black and they thin out as they rise; they return at dawn. The Sun's times come from the location the app already has. A view near the surface would be empty all working day, so hold the view deep.
- **Moon phase: no.** Hawaiian box jellies come ashore 8 to 10 days after the full moon (Waikiki Aquarium's calendar as several travel sites report it; the aquarium's page wasn't opened, so unchecked). But box jellies don't glow (Haddock et al. 2010: Cubozoa "totally nonluminous", checked), and it's true only off Oʻahu.
- **The user's own sea: no.** The ranges are real (sea nettle in the northeast Pacific, Pelagia in the Mediterranean and Atlantic), but nothing about them is live. At most a default.
- **Live feeds: none usable.** Monterey Bay Aquarium's jelly cams are its own footage.

## 5. What exists already

- **Apple's own aerials:** macOS has shipped Palau Jellies (Dark, Light, Blue) and Alaskan Jellies (Light, Dark) since Sonoma, though some may have come later: real footage (zhongzachary's list of the aerials, checked; no Apple page found). The golden jellies were filmed in Palau by Roger Munns, the moon jellies off Alaska by Roger Horrocks (Munns's page, checked). Every Mac already has filmed jellies a click away. This one has to be what film can't be: deep species, their own light, never repeating, tunable.
- **Wallpaper Engine and stock art:** "Glowing Bioluminescent Jellyfish in Deep Blue Ocean - Neon Pink Sea Creatures" is typical. What looks cheap:
  - pink and magenta glow (pink is pigment under a lamp, not light the animal makes)
  - every edge glowing, under heavy bloom
  - god rays and bubbles
  - jellies pulsing in step, with identical sine-wave tentacles
  - straight-line drift, and jellies in space
- **Screensavers:** JellyfishSaver by Eskils (MIT, checked) draws abstract jellies of curves, pulsed by a sinc, in SwiftUI shaders. 3D Jellyfish is shareware, stylised jellies on deep blue.
- **WebGL:** Aleksandar Rodic's Jellyfish (Chrome Experiments, 2011: a Houdini mesh moved by a vertex shader) and Chrysaora (spring-chain skeletons, volumetric light, SIGGRAPH 2011). The repository shows no licence (checked on GitHub's page): look only.
- **Shadertoy:** about 43 shaders tagged jellyfish. The best liked is BigWings' Luminescence (2017), whose header says CC BY-NC-SA 3.0. That header was seen only in a reproduction of the code; Shadertoy blocked me (unchecked). Shadertoy's default licence is CC BY-NC-SA 3.0 Unported (its terms page as quoted by search; the page blocked me: partly checked). Technique only, no code.

## 6. The name

The app's names are plain: Fireflies, Murmuration, Ant Colony, Black Hole, Fish Tank.

| Name | For | Against |
|---|---|---|
| **Jellyfish** (recommended) | Plain, the word people use, like Fireflies. | Comb jellies aren't jellyfish; tolerable. JELLYFISH is registered for unrelated things: Orthogonal Networks (class 42), Phil Vischer IP (children's DVDs), Jellyfish Digital (education software, class 9). None for wallpapers or screensavers found (uspto.report and Justia via search, not USPTO's own search: partly checked). |
| Jellies | The aquarium word; covers comb jellies. | Apple's own aerials are Palau Jellies and Alaskan Jellies. Monterey Bay Aquarium used it for "Jellies: Living Art" (2002 to 2008) and "The Jellies Experience" (2012 to 2015); Vancouver Aquarium's jelly pages are headed "Wondrous Jellies" (all via search excerpts). |
| Deep Sea | Evocative. | Too near Space Tour's deep space; promises fish too; the gallery look isn't deep. |
| Midwater | MBARI's word for it. | Obscure. |
| Bioluminescence | Says what's new. | A phenomenon, not a subject; wrong for the gallery look. |

No Mac App Store app named Jellyfish was found (checked, search). Jellyfish Heaven is an iPhone app that also runs on Apple silicon Macs.

## Not verified
- Atolla's and Pelagia's emission peaks; Halitrephes's size, canal count and whether it glows; whether the bloody-belly glows.
- The 80 nm emission width used for the hex values.
- The Atlas Obscura "Infinite Blue" story, the Waikiki Aquarium's calendar, Shadertoy's terms page and the BigWings header, each seen only in excerpts.
- Trademarks beyond the US third-party mirrors; no EU or UK search.
- Whether 150 and 190 keep desktop icons readable: to try on a real desktop.

## Sources

Biology and light:
- Haddock, Moline and Case 2010, Bioluminescence in the Sea, *Annu. Rev. Mar. Sci.* 2:443–493: https://www.mare-incognitum.no/files/downloads_mnight/curriculum%20ab334%202014/Haddock%20et%20al%202010.pdf (read in full)
- Herring and Widder 2004, Bioluminescence of deep-sea coronate medusae, *Mar. Biol.* 146:39–51: https://nora.nerc.ac.uk/id/eprint/114887/
- 2025 *Scientific Reports* paper on ctenophore photoproteins (authors not noted): https://pmc.ncbi.nlm.nih.gov/articles/PMC12374965/
- Jellyfish distribute vertically according to irradiance, *J. Plankton Res.* 2018: https://pmc.ncbi.nlm.nih.gov/articles/PMC5914403/
- Shimomura and Flood 1998, Luciferase of *Periphylla* (excerpts only): https://www.researchgate.net/publication/242235093_Luciferase_of_the_Scyphozoan_Medusa_Periphylla_periphylla
- MBARI: https://www.mbari.org/animal/deep-sea-crown-jelly/ , https://www.mbari.org/animal/bloody-belly-comb-jelly/ ; terms: https://www.mbari.org/legal/ (non-commercial education only)
- Monterey Bay Aquarium: https://www.montereybayaquarium.org/animals/animals-a-to-z/moon-jelly , https://www.montereybayaquarium.org/animals/animals-a-to-z/sea-nettle , https://www.montereybayaquarium.org/animals/animals-a-to-z/crystal-jelly , https://www.montereybayaquarium.org/visit/exhibits/into-the-deep/the-midwater , https://www.montereybayaquarium.org/visit/exhibits/open-sea
- MarLIN, moon jellyfish: https://www.marlin.ac.uk/species/detail/2089
- Ocean Exploration Trust, Halitrephes: https://nautiluslive.org/video/2017/12/31/burst-deep-sea-fireworks-halitrephes-jelly
- NOAA, vertical migration: https://oceanexplorer.noaa.gov/ocean-fact/vertical-migration/
- Wikipedia (secondary): https://en.wikipedia.org/wiki/Atolla_jellyfish , https://en.wikipedia.org/wiki/Helmet_jellyfish , https://en.wikipedia.org/wiki/Chrysaora_fuscescens , https://en.wikipedia.org/wiki/Deepstaria_enigmatica
- Colour: Wyman, Sloan and Shirley 2013, Simple Analytic Approximations to the CIE XYZ Color Matching Functions, *JCGT* 2(2).

Existing work and names:
- Apple aerials list: https://github.com/zhongzachary/sonoma-screen-savers ; Roger Munns: https://www.roger-munns.com/filming-the-underwater-apple-tv-screensavers/
- JellyfishSaver: https://github.com/Eskils/JellyfishSaver ; Rodic: https://experiments.withgoogle.com/jellyfish , https://github.com/arodic/Chrysaora
- Shadertoy tag: https://www.shadertoy.com/results?query=tag%3Djellyfish ; terms: https://www.shadertoy.com/terms
- Wallpaper Engine: https://steamcommunity.com/workshop/browse/?appid=431960&searchtext=Ocean
- Monterey Bay Aquarium exhibits: http://storage.montereybayaquarium.org/storage/pressroom/presskit/pdf/the_jellies_experience_press_kit.pdf , https://zoolex.org/gallery/show/771/
- Trademarks: https://uspto.report/TM/88233466 , https://uspto.report/TM/99439942 , https://trademarks.justia.com/787/00/jellyfish-78700328.html

Reference photos: the Commons links in section 1. Each licence was read from Commons' own licence field on 2026-11-07.
