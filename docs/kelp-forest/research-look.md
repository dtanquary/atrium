# Kelp Forest: the look research

A research agent's report on what a kelp forest wallpaper should look like, written 2026-11-08. How to draw and move it is researched separately. Every claim is marked **checked** (the page that says so was read on 2026-11-08), **partly checked** (seen only in a search engine's excerpt of the page) or **unchecked**. A Commons licence marked checked means Commons' own licence field for that file, which is only as good as the uploader's claim. Hex values and brightness figures are my own samples of the photos below, measured by small Python scripts; those and the downloaded photos were kept in `$TMPDIR/kelp/` and aren't in the repo.

## Summary and recommendation

1. **The view:** level through the stipes into haze, the calmest view in every photo and the safest under desktop icons, with a Tilt setting up to looking into the canopy. Looking up is the most dramatic and the brightest: Snell's window puts a big bright disc under the menu bar.
2. **The light is the subject.** Kelp's own pigment is amber; lit from above under water it reads olive, backlit it glows gold, and with distance it takes the water's colour. Stipes fading into the water's colour by distance is what makes the photos read as real.
3. **Colour family:** gold kelp on blue water is a complementary pair, the same risk as Lava Lamp's green in blue. Real water fixes it: only the nearest, sunlit blades keep their gold, and everything beyond a few metres turns the water's colour. So the gold is held to near blades, about a tenth of the screen.
4. **Four palettes, from real photos:** *Channel Islands* (sunlit teal and olive-gold), *Bull Kelp* (overcast grey-teal, the calmest), *Golden* (backlit amber, one family) and *Seaforest Blue* (deep blue with navy silhouettes, one family). Light Mode: Channel Islands. Dark Mode: Seaforest Blue at dusk.
5. **Gold doesn't survive dimming.** Scaled to a dark look's caps, the golden palette turns mud-brown, the olive that sank Crystals. Dark looks have to be blue.
6. **Brightness:** in Light Mode a median of 90 to 140, the 99th percentile no higher than 210, the 99.9th no higher than 230, and 240 only at the Sun's spot. That's Weather's level, below Fish Tank's. Dark Mode follows Jellyfish's caps: silhouettes 0 to 8, a median of 25 to 45, broad light up to 150 and pinpoints up to 190. Keep it soft too: under 3% of pixels on a hard edge, as the shader scenes have, where Fish Tank has 18%.
7. **Fish as the water colours them:** blacksmith, kelp bass and sardine schools, mostly silhouettes. The garibaldi is the only hot colour (#ED8F01 under a strobe), and only south of Point Conception. Off by default.
8. **Real data:** the Sun where the user is sets the rays' slant and the day's light; Open-Meteo's marine swell sets the surge, at a real forest's coordinates (both already in the app's toolkit, the licence checked). Water clarity from NOAA's Kd490 is CC0 but its server failed today. Sea temperature: no.
9. **Night is honestly black.** Moonlight is about 1/400,000 of sunlight. Dusk's deep blue is the Dark Mode look. Torches and plankton glow are real but flashy, and Sea Sparkle was just cut for the plankton.
10. **Name:** Kelp Forest. It's the habitat's plain name and Monterey Bay Aquarium's exhibit name, and no trademark turned up. But Apple ships *California Kelp Forest* and *Kelp Dark* aerials, which are the two obvious looks on film. This one has to be what film can't: never repeating, the real Sun and swell, Light and Dark Mode, tunable.

## 1. What a real kelp forest looks like

### The plants
- **Giant kelp (*Macrocystis pyrifera*)**, California, Patagonia and Tasmania: many stipes from one holdfast, a blade at intervals along each, and "a single pneumatocyst (gas bladder) at the base of each blade". Plants reach more than 45 m and grow up to 60 cm a day (Wikipedia, *Macrocystis*, partly checked). Up close, a column of rippled, lance-shaped blades on bead-like floats. At the top it spreads into a canopy at the surface.
- **Bull kelp (*Nereocystis luetkeana*)**, Southern California to the Aleutians: one whip-thin stipe 10 to 36 m long, ending in "a single, gas-filled pneumatocyst" with 30 to 64 blades streaming from it (Wikipedia, checked). It looks like a balloon on a string, and it's the most legible silhouette of the four.
- **Sea bamboo (*Ecklonia maxima*)**, the "Great African Seaforest" of the Cape: a hollow stipe up to 15 m (17 m in unpublished records) ending in a gas bulb that holds strap-like fronds at the surface (*The African seaforest: a review*, partly checked; Two Oceans Aquarium says 12 m, partly checked). The forest runs about 1,000 km of coast (Sea Change Project, partly checked). It looks like straight dark poles, more like a forest of trees than giant kelp does.
- **Tasmania and New Zealand:** Tasmania's giant kelp grows in green, nutrient-rich water (the Commons photo's caption credits a sewage outflow). New Zealand's common kelp (*Ecklonia radiata*) is short and bushy, and lime green in the one photo found: garish, leave it out.

### What the eye sees
- **The kelp's colour is the light's colour.** The pigment is fucoxanthin (Smithsonian, via search: partly checked). A blade photographed in air on sand samples #60400E–#7A5213–#92691B, amber at a hue of about 37°. Lit from above under blue water it shifts to olive at 49–64° (#5F531A, #988C29), because the light reaching it has lost its red. Backlit, light through the blade glows warmer: amber-gold #855203, #B67D04, #CE9E31, at 35–42°. In shadow it's near-black olive, #191A0C. In blue water a stipe a few metres off is a navy silhouette (#01040F), and a far one is just a darker band of the water's own colour.
- **Why distance turns everything blue-green:** pure water absorbs red fast. Pope and Fry 1997 give 0.34 m⁻¹ at 650 nm, 0.22 at 600, 0.057 at 550, 0.020 at 500 and 0.0092 at 450 (the OMLC table, checked). So over a 10 m path, 3% of the red light is left, 11% of the orange, 57% of the green and 91% of the blue (my arithmetic). Plankton absorbs blue on top of that, which is why coastal water like Monterey's is green.
- **Haze and visibility:** contrast falls with distance until a stipe is the water's colour. Visibility in the Channel Islands is 18–30 m in summer and fall and 12–18 m in winter and spring (Scuba Diver Life, partly checked); at Catalina 9–12 m (two dive sites, partly checked). In Monterey it's lower and greener (unchecked).
- **Sun rays:** shafts that converge toward the Sun's refracted direction and shimmer as surface waves focus the light. They're clearest in particle-laden water and shallow, as in the Monterey tank (CC0 photo below). Refraction holds them within 48.6° of vertical: at a Sun elevation of 10° they slant 47.6° from vertical, at 45° 32°, at 70° 15° (Snell's law with n = 1.333, my arithmetic).
- **The surface from below and Snell's window:** the whole sky is squeezed into a circle about 97° across, about 48.6° from vertical (Wikipedia, partly checked). Outside it the surface is a dark mirror of the water below. Waves blur the window's edge and widen it to about 122°, and toward 180° when they break (Lynch 2015, *Applied Optics*, partly checked). At 5 m depth the window spans about 11 m of surface. In the bull kelp photo the underside is a rippled grey-silver ceiling with the floats hanging under it.
- **The floor:** sand and rock crusted pink with coralline algae, purple and red urchins, bat stars and white anemones (Commons floor photo). Urchins matter to the forest (NPS Channel Islands kelp page, checked).
- **Fish:** Monterey's exhibit names sardines, northern anchovy, leopard sharks, wolf-eels, California sheephead, garibaldi, rockfish, giant kelpfish, kelp bass, giant sea bass, señorita, and horn and swell sharks (its page, checked). In the photos, blacksmith are dark blue-grey fish schooling in mid-water, señoritas are thin yellow cigars, and sardine schools are silver sheets. The garibaldi is the California state marine fish (NPS, partly checked) and rare north of Point Conception (CDFW and SIMoN, partly checked). In the NPS photo it samples #ED8F01 to #F3A201 under a strobe, the only hot colour in the forest.
- **Particles:** marine snow and suspended specks everywhere, thicker in green water. They give the rays their body.

### Reference photos
Licences are Commons' own fields, read 2026-11-08 (checked). NOAA's Flickr uploads carry both a public-domain tag and CC BY 2.0. NOAA says its images are public domain "unless otherwise noted in the credit or caption" (noaa.gov's photo library page via search: partly checked, since the page itself refused the fetch).

| Photo | Place | Licence | Shows |
|---|---|---|---|
| [Kelp forest, Channel Islands NMS](https://commons.wikimedia.org/wiki/File:Kelp_forest,_Channel_Islands_NMS.jpg) | Channel Islands | Public domain (NOAA) | looking up: Sun, canopy silhouettes |
| [Cojo Anchorage](https://commons.wikimedia.org/wiki/File:Macrocystis_pyrifera_kelp_forest_Cojo_Anchorage.jpg) | near Point Conception | Public domain (NOAA, R. Schwemmer) | sunlit canopy blades on blue |
| [Garibaldi](https://commons.wikimedia.org/wiki/File:Protected_by_state_law,_the_intensely_curious_and_territorial_garibaldi_has_become_quite_common_again_in_the_kelp_forests_of_(ef3d6128-155d-4519-3e32-3ffd7c3939cf).jpg) | Channel Islands NP | Public domain (NPS) | deep blue, stipes fading, garibaldi and señorita |
| [Kelp forest and sardines](https://commons.wikimedia.org/wiki/File:Kelp_forest_and_sardines,_San_Clemente_Island,_Channel_Islands,_California.jpg) | San Clemente Island | CC BY-SA 2.5 | looking up, teal, a sardine school |
| [Anacapa Island](https://commons.wikimedia.org/wiki/File:Kelp_Forest_off_of_Anacapa_Island_California.jpg) | Anacapa | CC BY-SA 3.0 | backlit canopy |
| [Scuba diver in kelp forest](https://commons.wikimedia.org/wiki/File:Scuba_diver_in_kelp_forest.jpg) | Point Lobos, Monterey | CC BY-SA 2.5 | green-teal Monterey water |
| [Nereocystis luetkeana1](https://commons.wikimedia.org/wiki/File:Nereocystis_luetkeana1.jpg) | Caspar Point, Mendocino | CC BY 4.0 | bull kelp under an overcast surface |
| [Strawberry Rocks](https://commons.wikimedia.org/wiki/File:Kelp_forest_at_Strawberry_Rocks_PC013138.jpg) | Oudekraal, Cape Town | CC BY-SA 3.0 | sea bamboo, deep blue, poles into haze |
| [A-Frame](https://commons.wikimedia.org/wiki/File:Kelp_forest_at_A-Frame_DSC06023.JPG) | Simon's Town | CC BY-SA 3.0 | dark green water |
| [Bosque de macroalgas submarino](https://commons.wikimedia.org/wiki/File:Bosque_de_macroalgas_submarino.jpg) | Patagonia | CC BY-SA 4.0 | golden backlit blades and floats |
| [Bosque de macroalgas gigantes](https://commons.wikimedia.org/wiki/File:Bosque_de_macroalgas_gigantes_(Macrocystis_pyrifera).jpg) | Patagonia | CC BY-SA 4.0 | golden-green fog |
| [Bastard trumpeter](https://commons.wikimedia.org/wiki/File:Tasmania-bastard-trumpeter-chris-brown.jpg) | Tasmania | CC BY-SA 4.0 | green Tasmanian water |
| [Kelp Forest - MBA - DSC06954](https://commons.wikimedia.org/wiki/File:Kelp_Forest_-_MBA_-_DSC06954.JPG) | Monterey Bay Aquarium | CC0 | the tank's sun rays |
| [Main viewing window](https://commons.wikimedia.org/wiki/File:Kelp_Forest_exhibit_full_main_viewing_window_at_Monterey_Bay_Aquarium.jpg) | Monterey Bay Aquarium | CC BY-SA 4.0 | the window, mullions, visitors in silhouette |
| [Birch Aquarium kelp tank](https://commons.wikimedia.org/wiki/File:Kelp_tank_(Birch_Aquarium_at_Scripps,_2007).JPG) | La Jolla | Public domain | a smaller tank window |
| [Giant kelp blade](https://commons.wikimedia.org/wiki/File:Giant_Kelp_-_Macrocystis_pyrifera_(43168362051).jpg) | (beach) | CC BY-SA 2.0 | a blade's true colour and ripples, in air |
| [Anemone and seastar](https://commons.wikimedia.org/wiki/File:Anemone_and_seastar_in_kelp_forest.jpg) | California | CC BY-SA 2.5 | the floor |
| [Blacksmiths in kelpforest](https://commons.wikimedia.org/wiki/File:Blacksmiths_in_kelpforest.JPG) | California | CC BY-SA 2.5 | a blacksmith school in blue |
| [Snell's window](https://commons.wikimedia.org/wiki/File:Snell%27s_window.jpg) | a pool | CC BY-SA 2.0 | the window's edge and mirror |

For anything that ships (a texture rather than a reference), prefer the public-domain, CC0 and CC BY ones, which need only a credit in About.

## 2. The views

- **Level through the stipes into haze** (Strawberry Rocks, Point Lobos, the aquarium's window). The calmest in every photo: vertical lines fading into one colour, light from the top edge, and the floor and fish low down. Desktop icons sit over plain water. **Recommended default.** The surge sways the whole column (section 5).
- **Looking up into the canopy** (the NOAA "gazing upward" photo, San Clemente). The most dramatic: Snell's window, rays fanning from it, the canopy in silhouette. Also the brightest. Scaled so its 99.9th percentile is 230, the NOAA photo still has its 90th percentile at 230, so a tenth of the frame is white. As a **Tilt** setting from level to about 40° up, with the window capped and its edge soft. Not the default.
- **The canopy just under the surface** (Cojo Anchorage, Caspar Point). Blades and floats hang from a moving silver ceiling. Bull kelp's floats read best here. The surface's motion is the show, which risks busy.
- **An aquarium kelp tank through acrylic:** Monterey Bay Aquarium's Kelp Forest is 28 ft tall, "one of the tallest aquarium exhibits in the world". A "specially designed surge machine" keeps the water moving, and pumps push 2,000 gallons a minute (its page, checked; its builder says 33 ft, partly checked). It's lit by the Sun through an open tank top (the builder, Rudolph and Sletten, partly checked; the aquarium's caption, "as sunlight pours in", checked). Visitors stand in a darkened gallery (sensory guide, partly checked) before a window of mullions, in silhouette. After hours, "the cathedral-like canopy of the Kelp Forest creates layered silhouettes" (its events page, checked). An honest, gentle look, but Fish Tank is already a tank: a frame is worth a mock-up, not a default.
- **Dusk and night, and what's real:** after sunset the forest goes deep blue, then black, and the day fish shelter while crabs, lobsters and octopus come out (dive blogs, partly checked). The full Moon is about 1/400,000 of the Sun (Wikipedia, apparent magnitude, partly checked), so by moonlight there's only a faint window overhead with the Moon's glitter in it, and black elsewhere. That's true, but nearly empty, like Jellyfish's lights-off look: an option at most. Divers' torches are real but a moving beam is flashy. Plankton glowing when disturbed is real too (PADI, partly checked), and is what Sea Sparkle was cut for. **Dark Mode is dusk:** the forest in its last deep-blue light, the stipes as silhouettes against a dim window.

## 3. Palettes

Sampled by hue: water at 150–240° and kelp at 15–100°, at the 10th to 98th percentiles of each one's brightness, then scaled in linear light to the caps in section 4. Hues are in brackets.

| Palette | From | Water, dark to bright | Kelp, shadow to lit | One family? |
|---|---|---|---|---|
| **Channel Islands** (Light Mode) | Cojo Anchorage, NOAA, PD; scaled ×0.81 | #016372 #18717E #3F96A9 #59AABE #6EB4C4 (188–191°) | #16170A #242410 #383214 #564B17 #8A7F24, glints #B4A632 (49–64°) | **No**: teal and olive-gold. Keep the gold to near, sunlit blades, about a tenth of the screen, and let distance turn the rest teal. |
| Channel Islands, teal | San Clemente, CC BY-SA 2.5; ×0.79 | #14312A #1D4640 #296A64 #479691 #7AC3C2 (166–179°) | kelp has taken the water's colour | Yes. The fallback if the gold reads as a clash. |
| **Bull Kelp** (overcast) | Caspar Point, CC BY 4.0; as shot | #2D5754 #3A7273 #598E97 #789FB8 #A6C0D4 (175–207°) | #413F2B #5A5134 #6F6140 #867151 #9B865B (36–54°) | Nearly: both are low in chroma, so the pair reads as one muted scene. The calmest photo of all. |
| **Golden** (backlit) | Patagonia, CC BY-SA 4.0; ×0.64 | none: the water itself is gold | #190C03 #221503 #392202 #4D2E02 #6C4202 #956503 #A88126 (35–42°) | Yes. Light Mode only (see below). |
| **Seaforest Blue** (Dark Mode) | Strawberry Rocks, CC BY-SA 3.0; ×0.30 | #00040B #001029 #001E3E #00426A #01587C, window #046489 (196–227°) | silhouettes #000105 | Yes. Cross-checked against the NPS garibaldi photo (PD) at the same cap: #040A0D #06152C #041B35 #002042 #002655. |
| Monterey green | Point Lobos, CC BY-SA 2.5; as shot | #3C4C47 #4F6862 #538A84 #47ABA7 #74D5D6 (161–181°) | dark olive | Yes, but green. Mock it up; Dave disliked green *in* blue, not green itself. |
| Aquarium | MBA main window, CC BY-SA 4.0; ×0.58 | #0F1E1D #1C3A39 #275357 #497583 | #171A0F #363A21 #6C6842 #AB9767; mullions #030505 | Nearly: muted teal and khaki. |

- **Gold doesn't survive dimming.** At the dark cap of 150, Golden becomes #170D01 #281701 #382001 #4F2F01 #6F4A01 #7E5F1A: mud. Crystals was cut for exactly this ("dimmed for calm the first-order palette read olive"). Blue keeps its colour when dimmed, so the Dark Mode looks are blue.
- **Recommended:** Channel Islands in Light Mode and Seaforest Blue in Dark Mode, which is also the sunlit day at dusk: one forest whose light changes, as Jellyfish's E and F share their animals. Bull Kelp and Golden go in a Look menu. Mock up the teal fallback beside Channel Islands to settle the gold question.
- **The garibaldi** dims to #8B5200 at the dark cap and stays the hottest thing on screen. One fish, off by default, and only in the southern looks.

## 4. Brightness

The brightest of R, G and B out of 255, measured on the app's Settings previews (1200 × 779) and on the photos at about 1,200 px. The hard-edge share is the share of pixels that differ by more than 24 from a neighbour 2 px away, a rough measure of "sharp".

| Picture | median | 90th | 99th | 99.9th | max | hard edges |
|---|---|---|---|---|---|---|
| Fish Tank | 180 | 241 | 255 | 255 | 255 | 18.3% |
| Weather | 182 | 222 | 231 | 237 | 244 | 2.7% |
| Jellyfish, lit tank | 147 | 208 | 251 | 255 | 255 | 1.2% |
| Aurora | 61 | 138 | 185 | 197 | 212 | 1.2% |
| Nebula | 30 | 110 | 150 | 168 | 255 | 1.6% |
| Jellyfish, glow | 0 | 15 | 62 | 96 | 180 | 0.7% |
| Sea Sparkle (cut) | 33 | 56 | 104 | 126 | 143 | 0.9% |
| Apple's California Kelp Forest (214 px thumbnail) | 86 | 170 | 184 | 192 | 204 | |
| Apple's Kelp Dark (214 px thumbnail) | 45 | 113 | 219 | 235 | 236 | |
| Photo: bull kelp, Caspar Point, as shot | 136 | 207 | 220 | 222 | 225 | 0.9% |
| Photo: Cojo Anchorage, ×0.81 | 95 | 190 | 203 | 230 | | 9.5% |
| Photo: looking up, NOAA, ×0.79 | 62 | 230 | 230 | 230 | | 9.6% |
| Photo: Strawberry Rocks, ×0.30 | 62 | 124 | 147 | 150 | | 2.8% |
| Photo: Strawberry Rocks, ×0.16 | 43 | 90 | 108 | 110 | | |

So:

| Part | Light Mode (sunlit) | Dark Mode (dusk) |
|---|---|---|
| Silhouettes, far water | from 20 | 0 to 8 |
| Median | 90 to 140 | 25 to 45 |
| Broad light: the window, rays, a backlit blade | 99th ≤ 210, 99.9th ≤ 230 | ≤ 150 (110 is calmer) |
| Pinpoints: the Sun's spot, glints, a fish's flank | ≤ 240 | ≤ 190 |
| Hard edges | under 3% | under 3% |

A sunlit forest is a mid-tone scene. Its photos sit at medians of 90 to 140 untouched, and it's a Light Mode look like Weather or Jellyfish's lit tank, so it can be that bright and stay calm, *if* the bright parts are broad and soft. The calmest real photo, the overcast bull kelp, needs no scaling at all: its 99th percentile and maximum are within 5 of each other. What breaks calm is a small, sharp, white Sun and hard-edged god rays. The caps are my reading of the app's own scenes, not yet tried under desktop icons (unchecked).

## 5. Data, images and feeds

- **Photos:** reference only (section 1). Nothing needs shipping. If a texture does, prefer the public-domain and CC0 ones.
- **Sand:** Poly Haven's *sand_02* and *sand_03* show ripples. "Our assets are all licensed as CC0" (Poly Haven's licence page, checked). Dappled Light already ships a Poly Haven texture.
- **The Sun, where the user is: yes.** The app has it (`SkyMath.swift`, `Location.swift`, used by Dappled Light and Jellyfish). It sets the rays' slant (above), the day's brightness and the dusk into Dark Mode's blue. The Sun's colour through the air is `Atmosphere` in WeatherSky.swift, for the window.
- **Swell, for the surge: yes.** Open-Meteo's marine API gives wave, wind-wave and swell height, period and direction, sea level with tides, sea surface temperature and currents. It warns the tides and currents are "not suitable for coastal navigation" (docs page, checked). Its data is CC BY 4.0, with "a link next to any location Open-Meteo data are displayed" (licence page, checked). The free API is non-commercial (docs/app-store.md; the pricing page wasn't read). The app already calls Open-Meteo. A live call for Monterey on 2026-11-08 worked: swell 2.44 m at 9.4 s from 294°, waves 2.84 m at 13.3 s. Use a real forest's coordinates, one per look (Monterey, the Channel Islands, Oudekraal, Patagonia), not the user's own, which is mostly inland. What it does, by linear wave theory at 15 m depth (my arithmetic): a 1 m swell at 8 s sways the water at the floor ±0.35 m, at 12 s ±0.66 m, at 16 s ±0.95 m; a 2 m swell twice that. So the forest leans back and forth every 8 to 16 s, which is slow and calm by nature.
- **Water clarity: maybe later.** NOAA CoastWatch's daily Kd490 (light attenuation at 490 nm), gap-filled at 9 km, is "CC0-1.0" (the dataset's own metadata, checked). It could set the haze distance and the green. Its server failed twice on 2026-11-08 (a proxy error, then a 404), and coastal pixels are often missing: unchecked as a feed.
- **Sea temperature and kelp health: no.** The 2014–16 marine heatwave left Northern California with 2.7% of its historical canopy (the Kelpwatch paper, *PLOS ONE* 2023, checked). That's real, but a dying forest isn't a calm wallpaper. Open-Meteo also gave Monterey 19.5 °C today, which looks high for November (unchecked), so model sea temperature near the coast isn't to be trusted. Kelpwatch's canopy data is quarterly and its licence wasn't confirmed (unchecked).
- **Tide: no.** Too slow to see and not trusted near the coast (above).

## 6. Names and look-alikes

- **Apple's aerials:** the Underwater set includes **California Kelp Forest** and **Kelp Dark** (under "Kelp") (zhongzachary's list of the aerials, checked). California Kelp Forest came to Apple TV in January 2020 (9to5Mac, partly checked). Its preview shows blue water, golden kelp and a school of fish. Kelp Dark shows dark teal fog with stipes and fish. So both obvious looks are already on film on every Mac. Fixed clips can't follow the Sun or the swell, change with Light and Dark Mode, or never repeat.
- **Kelp Forest** (recommended): plain like Fish Tank and Jellyfish, and the habitat's common name. It's also Monterey Bay Aquarium's exhibit name (checked) and a biome in the game *Subnautica*, both descriptive uses. No US trademark for KELP FOREST turned up, only KELP SKINCARE, KELP COIN and similar (third-party mirrors via search, partly checked). It sits inside Apple's "California Kelp Forest", as Jellyfish sits beside "Palau Jellies"; tolerable.
- **Alternatives:** *Kelp* is Apple's own subcategory. *Seaforest* is Sea Change Project's coinage for the Cape ("carefully embedded the name 'Great African Seaforest' in all our media work"). No trademark was found (partly checked), but it's their campaign: avoid. *Under the Kelp*: wordy.
- **What exists:** YouTube re-uploads of Apple's aerial as a "live wallpaper", and DesktopHut's "PC Kelp Forest Live Wallpaper", a 1080p video (both checked as listings).
- **What looks cheap**, in stock art and games: lime or neon-green kelp (the real lime of New Zealand's *Ecklonia radiata* looks garish too), hard-edged god rays, bubbles, kelp swaying in step, an orange fish as the only colour, and the glowing, saturated *Subnautica* look.

## Not verified
- Monterey's visibility; the builder's open-top account (its page was gone) and the tank's night lighting.
- Giant kelp's size and growth, fucoxanthin, sea bamboo's length, the garibaldi's range, Snell's window figures and the Moon's ratio: each seen only in search excerpts, though the sources agree.
- Kd490 as a working coastal feed; Kelpwatch's data licence; Open-Meteo's free-tier terms.
- Trademarks beyond US third-party mirrors.
- Whether these caps keep desktop icons readable: to try on a real desktop.

## Sources

Plants and place:
- Monterey Bay Aquarium, Kelp Forest: https://www.montereybayaquarium.org/visit/exhibits/kelp-forest ; events: https://www.montereybayaquarium.org/visit/host-a-corporate-event ; sensory guide: https://www.montereybayaquarium.org/visit/exhibits/exhibit-sensory-guides
- Wikipedia: https://en.wikipedia.org/wiki/Nereocystis , https://en.wikipedia.org/wiki/Macrocystis , https://en.wikipedia.org/wiki/Snell%27s_window , https://en.wikipedia.org/wiki/Apparent_magnitude
- NPS, Channel Islands kelp forests: https://www.nps.gov/chis/learn/nature/kelp-forests.htm
- Sea Change Project: https://seachangeproject.com/stories/explore-the-kelp-species-of-the-great-african-seaforest/ ; Two Oceans Aquarium: https://www.aquarium.co.za/animals/sea-bamboo ; *The African seaforest: a review*: https://www.researchgate.net/publication/380188724_The_African_seaforest_a_review
- Smithsonian Ocean: https://ocean.si.edu/kelp-and-kelp-forests (refused the fetch)
- Garibaldi: CDFW https://nrm.dfg.ca.gov/FileHandler.ashx?DocumentID=65557 , SIMoN https://sanctuarysimon.org/dbtools/species-database/species-info-ajax.php?sID=441 , NPS https://www.nps.gov/places/garibaldi.htm
- Visibility: https://scubadiverlife.com/diving-southern-channel-islands-kelp-forests/ , https://www.bluewaterdivetravel.com/destination/catalina-island-scuba-diving
- Night: https://blog.padi.com/night-diving-in-cape-town-south-africa/

Light:
- Pope and Fry 1997, pure water absorption: https://omlc.org/spectra/water/data/pope97.txt
- Lynch 2015, Snell's window in wavy water: http://www.thulescientific.sanandreasfault.org/Snell's%20Window_AO%202015.pdf

Data and licences:
- Open-Meteo marine: https://open-meteo.com/en/docs/marine-weather-api ; licence: https://open-meteo.com/en/licence
- NOAA CoastWatch Kd490: https://coastwatch.pfeg.noaa.gov/erddap/info/nesdisNPPN20S3AkdSCIDINEOFDaily/index.html
- Kelpwatch paper: https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0271477
- NOAA photo library terms: https://www.noaa.gov/noaa-collections/photo-library
- Poly Haven: https://polyhaven.com/license , https://polyhaven.com/a/sand_02 , https://polyhaven.com/a/sand_03

Names and look-alikes:
- Apple aerials: https://github.com/zhongzachary/sonoma-screen-savers ; 9to5Mac: https://9to5mac.com/2020/01/31/apple-tv-adds-another-eleven-stunning-underwater-video-screensavers/
- Trademarks: https://uspto.report/TM/99395528 , https://trademarks.justia.com/884/04/kelp-88404794.html
- DesktopHut: https://www.desktophut.com/PC-Kelp-Forest-Live-Wallpaper-Free ; Subnautica: https://subnautica.fandom.com/wiki/Kelp_Forest

Reference photos: the Commons links in section 1, each licence read from Commons' own field on 2026-11-08.
