# Beehive: the look research

A research agent's report on what an observation hive behind glass looks like and how to draw it soft and dim, written 2026-11-18. How to build and time it (the clock, the cell map, the bees' paths, the cost) is in [research-method.md](research-method.md). Every claim is marked **checked** (the page that says so was read on 2026-11-18), **partly checked** (seen only in a search engine's excerpt of the page) or **unchecked**. A Commons licence marked checked is Commons' own licence field for that file, read through its API, which is only as good as the uploader's claim. Colours and brightness are my own samples, measured by [measure_photos.py](measure_photos.py) on Commons' 1,280 px copies; the downloads were kept in `$TMPDIR` and deleted afterwards, and nothing is in the repo. Brightness is the brightest of R, G and B out of 255, as in [canopy/research-look.md](../canopy/research-look.md).

## Summary and recommendation

1. **The real thing is a pane of comb seen face-on**, a frame or two stood on edge between two sheets of glass with room for the bees on each side, in a wooden case with covers that are lifted to look. Bees walk on the comb (their backs to you) and on the glass (their undersides to you). Through glass, in a lit room, the bees are dark brown shapes about a third as bright as the comb (photo R1: comb (177,164,138), bees (51,44,36)–(70,61,52)).
2. **A real observation hive is already as dim as the app.** The museum hive in R2, as shot, measures median 57, 99th percentile 141, 99.9th 162, inside its window; Ant Colony's Sand and Earth looks measure 82/125/136 and 97/132/143 the same way. Close-ups of comb in daylight are far brighter (median 160–195, up to 2% of the frame clipped white) and need their light cut to a third.
3. **Standard look: Amber.** Mid-age comb under a warm lamp from the upper left in a dark room: wax walls (132,109,67), capped honey (145,109,69), capped brood (134,84,47), nectar (116,76,35) with glints no brighter than (184,164,132), bees amber and dark-banded. Caps: **median 75–95, 99th ≤ 150, 99.9th ≤ 175, glints ≤ 200**, the same band as Ant Colony's sand and earth. The lamp matters: pale wax dimmed under white light goes olive-khaki, the fault that cut Crystals.
4. **Three more looks** in the same family, honey through amber to garnet: *Old Comb* (near-black brood comb with honey and bee bread glowing, median 40–60), *New Comb* (pale fresh comb in daylight, the Light Mode look, median 140–175, 99th ≤ 215), and *Red Lamp* (the hive at night under the red light bee researchers watch by, median 25–40; chosen, not measured, and the riskiest).
5. **Trypophobia is the main risk of this wallpaper, and blur doesn't fix it.** The standard questionnaire for it uses exactly two pictures, a lotus seed head and a honeycomb (checked, second-hand). Discomfort survives keeping only the low or middle spatial frequencies (checked), so softening or distance keeps the trigger; what lowers it is taking the holes away. So draw the comb mostly **capped** (cap against gap 1.2–2.1×, measured), fill each state in large smooth-edged patches, light cell floors so no hole goes black (an empty cell in pale comb is 6.4× darker than its rim; bee bread in old comb is 180×), and never show larvae. Leave it out of Shuffle until picked, as Ant Colony's open item 14 asks for insects; Dave's call.
6. **What can ship:** the USGS Bee Inventory and Monitoring Lab's honey bee photographs, top-down on black, are marked **Public Domain Mark 1.0** on their Flickr pages (checked), the best source for bee cut-outs; Alabama Extension's *Honey Bees on Comb* 1–3 on Commons are **CC0** (checked, Commons' field). No CC0 comb, wax or honey texture exists on Poly Haven or ambientCG (checked by search); the comb is drawn, which it must be anyway since each cell changes with the clock. Poly Haven's CC0 woods do for the frame.
7. **Feeds:** none needed beyond the Open-Meteo temperature the app already fetches (CC BY 4.0, checked). NASA's HoneyBeeNet scale-hive network, the one nectar-flow feed of its kind, ended in 2011 (checked).
8. **Name: Beehive.** It pairs with Ant Colony and clashes with nothing in the menu (Night Sky's "Beehive Cluster" is only a label on the sky). *Honeycomb* is crowded in software and is the name of the trigger picture; *Hive* is crowded; *Observation Hive* is the safe descriptive fallback. No skep (the domed straw hive): it is the emblem of the LDS Church and Utah, and a Masonic symbol.

## 1. What a real observation hive looks like

- **The hive.** One to four frames in a single layer, stood on edge between two panes, in a wooden case; museum and nature-centre hives have a tube through the wall for the bees (R2's, at its lower right). Bees prefer the dark, light seems to hold back wax-making, and the glass is kept covered by panels when no one is looking (American Bee Journal, partly checked). So "the cover lifted" is real: a wooden shutter's edge in frame is an honest way to say what this is.
- **Through the glass.** In R1 the comb sits a little behind the pane (the gap is research-method.md's), and some bees are sharp on the glass while others, on the comb, are a touch softer. Reflections of the room are strong in every museum photo (R2, R3: a window, a lamp, the photographer). The pane is the screen; a faint, even sheen at most, no hard reflections. Propolis smears at the glass's edges and condensation in the cold are common (unchecked).
- **How it is lit.** Museums light the room, not the hive: R2 is a dim gallery (median 57), R1 a bright one (125). Outdoors, a frame held up in daylight (R7) is 137 with clipped highlights. Light from one side rakes across the cells and puts a highlight on the near wall of each and in each nectar meniscus, one glint a cell. Back-lit, new comb glows (R8's pale cell floors).
- **Comb by age** (partly checked: Bees for Development and beekeeping guides in search excerpts). New wax is nearly white and translucent (R9, a swarm's comb, (225,233,242) in shade); it yellows within days from pollen oils and propolis (R8, (200,180,72)); brood comb browns and then blackens over years as each generation leaves a cocoon in its cell (R6, walls (54,21,2)), and the cells get smaller as the walls thicken. Comb used only for honey stays light. One frame can show all three: pale at a growing edge, brown in the brood nest.
- **How comb grows.** From the top bar down, as a tongue with a pale, thin, translucent edge (R10's wild comb, its lower rim near white against the yellowed comb above), the bees hanging off it in chains, "festooning" (partly checked: festoons are seen around new comb; whether they make the wax is unsettled, Muller and Hepburn 1992). The building face is where the bees are thickest, which suits Ant Colony's way of sending them to the working faces.
- **The cells, by state** (colours measured, section 2):
  - *Empty, new comb:* pale walls, pale floor, hardly a hole at all (wall to cell 1.2×).
  - *Empty, pale comb in daylight:* black holes in a cream lattice (6.4×). The worst state for trypophobia.
  - *Uncapped nectar:* a clear amber pool with a bright meniscus, darker than the wall in daylight (R4, (116,85,48) against (220,208,180), 2.3×), the glint near white.
  - *Capped honey:* flat, white to cream wax caps, slightly bumpy, the cells barely readable (R4, (202,202,202) against shadows of (175,166,159), 1.2×). The calmest state.
  - *Capped worker brood:* domed caps, tan on new comb (R5, (219,203,169)) and orange-brown on mid-age comb (R7, (174,122,84)), porous-looking, with dark gaps between (2.1×). Drone brood is the same, taller and bigger, in patches at the edges (unchecked here).
  - *Open brood:* glistening floors with white, C-curled larvae (R8). The second-worst state; never shown close.
  - *Pollen, "bee bread":* cells packed with pellets in single colours, cell by cell: orange (187,139,85) the commonest, then yellow (231,184,81) and red-brown (160,120,99), and a few grey-violet (164,149,161) (R6, its brightest fifth of pixels by hue). On old dark comb this is the most trypophobic picture in the set.
- **The layout of a brood frame** (partly checked, several beekeeping guides agree): brood in a central ellipse, a band of pollen round it, an arch of capped honey across the top and down the upper corners. R7 shows it: brood caps in the middle, honey arch in the top corners, scattered dark empty cells in the brood. A healthy pattern is compact; a "shotgun" pattern of empty cells among the caps is a sign of trouble, and to the eye it is a cluster of holes.
- **The bees.** Workers are amber with dark bands and pale hair (the USGS photograph R12: bands (71,39,5), amber (175,137,89), hair to near white). They walk with their wings folded flat over the abdomen, as in R12's light-bodied worker. From below, on the glass, they show legs, the pale underside of the abdomen and the tongue (unchecked; no measured photo from below). Through glass they read as dark brown-grey shapes (R1). How big, how many and how fast are research-method.md's.
- **The cluster.** In the cold the colony draws into a dense, still mat over the brood (R10's photos 2 and 3 show a mat of bees over wild comb): a texture of bees with no cells showing, which, usefully, hides the comb. The threshold and how tight are research-method.md's; the partly checked figure is that clustering starts near 14 °C (57 °F).
- **At night.** Bees see little or nothing of red (partly checked: trained bees treat red as black; a 1997 review disputes how far that goes), so researchers and keepers watch observation colonies under red light. A dim red-lit hive is real.

### Reference photos

All on Wikimedia Commons; licences are Commons' field, read through its API (checked). Kept for the look, not to ship unless section 5 says so.

| # | Photo | Licence | Shows | Measured as |
|---|---|---|---|---|
| R1 | [Display Hive, Cumberland House](https://commons.wikimedia.org/wiki/File:Display_Hive,_Cumberland_House_-_55465763241.jpg), Tim Sheerman-Chase | CC BY 4.0 | **the composition**: pale comb face-on through glass, bees on glass and comb, a wooden bar | glass |
| R2 | [Rock Creek Park Nature Center](https://commons.wikimedia.org/wiki/File:Nature_Center_and_Planetarium_in_Rock_Creek_Park_05.JPG), Abraham | CC BY-SA 3.0 | **the brightness**: a museum hive, two frames of old dark comb, a dim gallery | museum |
| R3 | [FL Bee exhibit](https://commons.wikimedia.org/wiki/File:FL_Bee_exhibit_(6198350762).jpg), Virginia State Parks staff | CC BY 2.0 | a carry-out demo hive with a cluster, reflections; its comb is yellow plastic foundation, so not its colours | – |
| R4 | [Honey comb with capped honey](https://commons.wikimedia.org/wiki/File:Honey_comb_with_capped_honey.jpg), Einebillion | CC BY 4.0 | caps and uncapped nectar side by side | honey |
| R5 | [Capped worker brood](https://commons.wikimedia.org/wiki/File:Capped_worker_brood.jpg), Einebillion | CC BY 4.0 | capped brood, empty cells, honey cells, bees | brood |
| R6 | [CSIRO ScienceImage 6628](https://commons.wikimedia.org/wiki/File:CSIRO_ScienceImage_6628_Honey_bee_comb_showing_cells_filled_with_different_coloured_pollen_collected_from_different_plants.jpg), Nick Pitsas, CSIRO | CC BY 3.0 | old dark comb with bee bread of many colours; the worst case for trypophobia | pollen |
| R7 | [Italian honeybee brood frame](https://commons.wikimedia.org/wiki/File:Italian_honeybee_brood_frame_from_Langstroth_hive.jpg), Benlisquare | CC BY-SA 4.0 | **the layout**: a whole frame, brood middle, honey arch, bees all over | frame |
| R8 | [Newly created brood comb](https://commons.wikimedia.org/wiki/File:Newly_Created_Brood_Comb_with_Capped_Brood_and_Larva.JPG), Chris Severn | CC BY-SA 3.0 | new yellow comb, fresh caps, larvae | fresh |
| R9 | [Wax comb made by swarming bees](https://commons.wikimedia.org/wiki/File:Wax_comb_made_by_swarming_bees_(30933182370).jpg), Lukas from London | CC BY-SA 2.0 | white new wax | white |
| R10 | [Honey Bees on Comb 1](https://commons.wikimedia.org/wiki/File:Honey_Bees_on_Comb_1.jpg), [2](https://commons.wikimedia.org/wiki/File:Honey_Bees_on_Comb_2.jpg), [3](https://commons.wikimedia.org/wiki/File:Honey_Bees_on_Comb_3.jpg), Alabama Extension | **CC0** | wild comb, its new pale edge, a cluster mat | cc0 (1) |
| R11 | [Honey Bees on Comb](https://commons.wikimedia.org/wiki/File:Honey_Bees_on_Comb.jpg), Killerlimpet | **Public domain** | a frame of capped honey, bees | – |
| R12 | [Apis mellifera, light body, back](https://commons.wikimedia.org/wiki/File:Apis_mellifera,_light_body,_back,_beltsville,_md_2017-05-26-15.12_(34886290922).jpg) and [dark body, back](https://commons.wikimedia.org/wiki/File:Apis_mellifera,_dark_body,_back,_beltsville,_md_2017-05-26-15.01_(34240025053).jpg), USGS Bee Inventory and Monitoring Lab | **Public Domain Mark 1.0** (section 5) | workers from above on black; the light one with wings folded, as a bee walks | bee |

Also looked at: [Cliffe Castle Museum's hive](https://commons.wikimedia.org/wiki/File:Cliffecastlemus_060.jpg) (CC BY 3.0), [Ooty Honey & Bee Museum's](https://commons.wikimedia.org/wiki/File:Observation_Bee_Hive_from_Ooty_Honey_%26_Bee_Museum.JPG) (CC BY-SA 3.0, the case closed), Einebillion's [Frame of capped honey](https://commons.wikimedia.org/wiki/File:Frame_of_capped_honey.jpg), [Bees on capped brood](https://commons.wikimedia.org/wiki/File:Bees_on_capped_brood.jpg) and [A slice of the brood nest](https://commons.wikimedia.org/wiki/File:A_slice_of_the_brood_nest.jpg) (CC BY 4.0).

## 2. Measured

`python3 -I docs/beehive/measure_photos.py <empty folder>` fetches the photos and prints all of this. Boxes were picked by eye over a 10 × 10 grid; inside a box the parts are told apart by brightness percentiles, as Ant Colony's script does.

### Colours

| Part | Photo | RGB | |
|---|---|---|---|
| Comb behind glass, wall / cell | R1 | (177,164,138) / (119,106,94) | pale comb, lit room |
| Bees on the glass, dark / amber | R1 | (51,44,36) / (70,61,52) | |
| Old comb, wall / cell | R2 | (63,63,52) / (27,29,26) | museum, dim |
| Caps of honey, cap / shadow / highlight | R4 | (202,202,202) / (175,166,159) / (252,251,247) | daylight, neutral white |
| Uncapped nectar, cell / wall | R4 | (116,85,48) / (220,208,180) | |
| Capped brood on new comb, cap / gap | R5 | (219,203,169) / (109,94,86) | |
| Empty cells in pale comb, cell / rim | R5 | (25,31,49) / (212,196,167) | the cell is blue only from daylight in shade |
| Capped brood on mid-age comb | R7 | (174,122,84), lit (212,166,130) | |
| Honey arch, cap / open cell | R7 | (203,170,132) / (31,9,0) | |
| Wooden frame, sunlit pine | R7 | (228,178,104) | |
| Old brood comb, wall / empty cell | R6 | (54,21,2) / (1,0,0) | |
| Bee bread: yellow, orange, red-brown, grey-violet | R6 | (231,184,81), (187,139,85), (160,120,99), (164,149,161) | 22%, 57%, 19%, 2% of the brightest fifth |
| New comb, wall / lit / cell | R8 | (200,180,72) / (213,199,110) / (181,151,34) | |
| White swarm wax, lit / shadow | R9 | (225,233,242) / (114,94,78) | in shade |
| Wild comb, wax / cell | R10 | (248,229,173) / (121,85,34) | CC0 |
| Worker, band / amber / hair | R12 | (71,39,5) / (175,137,89) / (255,249,207) | studio-lit specimen |

Beside Ant Colony's measured photos (its doc's "Reference photographs"): toy sand (211,201,183), fine soil (185,143,95), voids (105,83,52), a harvester ant (148,73,23) to (171,108,49). Bees, honey and mid-age comb sit in the same warm band as its earth and ants, a little more saturated and yellower; old brood comb is darker and redder than anything in Ant Colony.

### Brightness

Median / 90th / 99th / 99.9th / max, and that photo scaled in linear light until its 99th percentile is 150 (the standard's cap) or 200 (Light Mode's):

| Photo | As shot | Clipped (≥ 250) | 99th to 150 | 99th to 200 |
|---|---|---|---|---|
| R1, through glass, lit room (window only) | 125 / 169 / 193 / 217 / 224 | 0% | ×0.57: median 97 | ×1.08: median 130 |
| R2, museum hive, dim (window only) | 57 / 104 / 141 / 162 / 231 | 0% | ×1.15: median 61 | – |
| R4, honey caps and nectar | 172 / 231 / 253 / 255 / 255 | 1.9% | ×0.32: median 102 | ×0.60: median 136 |
| R5, capped brood | 161 / 230 / 255 / 255 / 255 | 2.3% | ×0.31: median 95 | ×0.59: median 126 |
| R6, old comb and pollen | 86 / 191 / 255 / 255 / 255 | 2.0% | ×0.31: median 51 | – |
| R7, a whole frame (frame only) | 137 / 202 / 245 / 255 / 255 | 0.7% | ×0.34: median 84 | ×0.64: median 112 |
| R8, new comb | 195 / 214 / 231 / 242 / 255 | 0% | ×0.39: median 127 | ×0.73: median 169 |
| R10, wild comb (CC0) | 127 / 232 / 255 / 255 / 255 | 2.2% | ×0.31: median 75 | ×0.59: median 100 |

The app's own stills, measured the same way: Ant Colony Sand 82 / 108 / 125 / 136, Earth 97 / 117 / 132 / 143, Gel 109 / 200 / 255 / 255; Kelp Forest 132 / 162 / 174 / 180; Nebula 48 / 197 / 229 / 237. The two hives seen through glass need no more than the light changed; the close-ups need it cut to a third, and their medians then land at 85–125, the band of Ant Colony's sand and earth.

### Contrast of a cell against its wall

The trypophobia question in numbers (luminance of the bright part over the dark):

| State | Ratio |
|---|---|
| Capped honey, cap / its shadow | 1.2× |
| New comb, empty, wall / cell | 1.2× |
| Capped brood, cap / gap | 2.1× |
| Old comb, empty, wall / cell (dim museum) | 2.2× |
| Uncapped nectar, wall / cell | 2.3× |
| Empty cells in pale comb, rim / cell | 6.4× |
| Old comb with bee bread, pollen / empty cell | 180× |

### Hard edges

The share of pixels more than 24 from the pixel 2 px away at 1,200 px, Canopy's measure (Weather 2.7%, Fish Tank 18% by its report): new comb 3%, honey caps 5%, R1 through glass 10%, R2 museum 14%, capped brood with bees 28%, old comb with pollen 43%, a whole frame covered in bees 46%. The comb is a lattice of edges and the bees add more; the calm states (caps, new comb, glass between) are the soft ones.

## 3. Palettes

Each swatch is a measured colour above, scaled in linear light, and for the lamp-lit looks multiplied by a warm lamp (linear 1, 0.78, 0.5; chosen). The script's last section prints them with their sources. All four looks are one family, honey through amber to garnet, with no blue or green in them anywhere: the daylight blue in R5's shadows is the camera's and is dropped. The room around the hive is a warm near-black, (14,10,7).

**Amber**, the standard (Dark Mode, and the default when following neither): mid-age comb under a warm lamp from the upper left, in a dark room.

| Part | RGB | from |
|---|---|---|
| Comb wall, lit / shade | (132,109,67) / (76,63,39) | R10 wax |
| Cell depth | (46,30,14) | R4 nectar, dark |
| Nectar / its glint | (116,76,35) / (184,164,132) | R4 |
| Capped honey | (145,109,69) | R7 honey arch |
| Capped brood | (134,84,47) | R7 brood caps |
| Bee bread: yellow / orange / red-brown | (149,106,38) / (136,91,45) / (110,74,50) | R6 |
| Frame wood | (90,63,30) | R7 pine |
| Bee: band / amber / hair | (62,31,3) / (128,89,47) / (143,125,85) | R12 |

Caps: median 75–95, 90th ≤ 125, 99th ≤ 150, 99.9th ≤ 175, glints alone up to 200. Hard edges under 10%.

**Old Comb** (a darker choice): years-old brood comb, near-black-brown, the honey and bee bread glowing in it.

| Part | RGB |
|---|---|
| Comb wall / cell depth | (67,23,2) / (29,10,1) |
| Nectar / glint | (89,58,27) / (162,144,116) |
| Capped honey / capped brood | (114,85,54) / (102,64,36) |
| Bee bread: yellow / orange | (130,92,33) / (116,77,38) |
| Frame wood | (70,49,23) |
| Bee: amber / band | (113,79,42) / (57,28,3) |

Caps: median 40–60, 99th ≤ 140, 99.9th ≤ 160. Bee bread on this comb is the 180× case: show it only in a band round the brood, a few cells deep, each cell's floor and wall lit so no empty cell beside it goes black.

**New Comb**, the Light Mode look: fresh pale comb in daylight, as the nature centre's lit room in R1.

| Part | RGB |
|---|---|
| Comb wall, lit / new yellow | (200,184,139) / (175,158,63) |
| Growing edge, white wax | (192,191,188) |
| Cell depth | (132,119,47) |
| Nectar | (116,85,48) |
| Capped honey / capped brood | (177,177,177) / (167,155,129) |
| Bee bread, yellow | (183,146,64) |
| Frame wood | (166,130,76) |
| Bee on the glass / amber | (60,52,44) / (154,120,78) |

Caps: median 140–175, 99th ≤ 215, 99.9th ≤ 230. R1 as shot (125 / 193 / 217) is already nearly there. Bees are the darkest things on it, about a third of the comb's brightness, which is how they look through glass and is the contrast to watch (section 4). Capped honey here is a neutral white from R4; warm it a little if it reads grey beside the yellow comb.

**Red Lamp** (night, a choice for Dark Mode or for following day and night): the same hive under the red light researchers use. Amber's luminances put on one deep red ramp, from (10,3,2) for cell depths through (95,26,10) for the comb to (150,40,16) for glints; bees near-black red. Caps: median 25–40, 99th ≤ 110. Chosen, not measured: no photograph of a hive under red light was found to sample. It is in the family (garnet beside amber) and calm, but may read as a darkroom or a warning; it needs a mock-up before anyone believes it.

A *Winter* look isn't needed: the cluster changes what is on the comb, not its colours.

## 4. Trypophobia and insects on screen

**What is known.**
- About 16% of participants in Cole and Wilkins's study reported trypophobic reactions, and the trigger images "had relatively high contrast energy at midrange spatial frequencies" (APS news release for *Fear of Holes*, Psychological Science 2013, checked: https://www.psychologicalscience.org/news/releases/fear-of-holes-may-stem-from-evolutionary-survival-response.html).
- The Trypophobia Questionnaire (Le, Cole and Wilkins 2015) uses two pictures to define the reaction, **a lotus seed head and a honeycomb** (checked as reported by Sasaki et al. 2017, https://pmc.ncbi.nlm.nih.gov/articles/PMC5636197/, and Pipitone and DiMattina 2020, https://pmc.ncbi.nlm.nih.gov/articles/PMC7393229/; the 2015 paper itself not read). Honeycomb is not a borderline case: it is the reference picture.
- **Blur does not help.** Sasaki et al.: removing any one band of spatial frequencies left discomfort intact, and images with "only low or midrange spatial frequencies induced as much trypophobic discomfort as did the original images"; only high-frequency-only images did not (checked, the page above). So softening the comb, or making it smaller and farther, keeps it.
- **Taking the holes away does.** Pipitone and DiMattina: the phase spectrum, which carries where the holes and bumps are, "plays a much larger role than the amplitude spectrum", and phase-scrambled images were rated more comfortable (checked, abstract).
- The reaction is mostly disgust, an overgeneralised avoidance of disease, worst for clusters on skin (Kupfer and Le, Cognition and Emotion 2017/2018, partly checked through press coverage). Wikipedia: not a recognised diagnosis; triggers include "holes made by insects" (checked, https://en.wikipedia.org/wiki/Trypophobia).

**Which states trigger most** (my reading of the above with the contrasts in section 2): an irregular cluster of dark holes in a pale field (empty cells among caps, 6.4×; the "shotgun" brood pattern); larvae in open cells (holes with soft white bodies in them, the disease association); old dark comb speckled with coloured bee bread (180×, R6). Least: capped honey (1.2×, a surface rather than holes), new comb (1.2×), and comb covered by bees or by a cluster.

**What to do,** most effective first:
1. **Mostly capped.** A comb drawn through the day ends with the capped states covering most of it: honey caps and brood caps, cap against gap 2.1× at most. The research-method clock decides the proportions; this says to weigh them toward caps whenever a choice is free.
2. **States in patches, not salt and pepper.** Real comb fills in contiguous areas (the brood ellipse, the honey arch). Fill and cap cells in growing patches with smooth fronts, and keep stray empty cells inside the brood rare, where real comb has a few.
3. **No black holes.** Light each cell's floor and far wall from the lamp, so an empty cell is a shallow cup at most 2× darker than its rim, as new comb (1.2×) and old comb in dim light (2.2×) already are in the photos.
4. **No larvae.** Open brood is a glistening floor at most, or shown under nurse bees with their heads in the cells, which is real and hides it.
5. **Bee bread in a narrow band**, a few cells deep round the brood, in the two or three commonest colours at low contrast to the wall, never a field.
6. **Don't rely on blur, scale or distance** (above). They are still worth having for calm, but not as the fix.
7. **Shuffle.** Leave it out of Shuffle until a user picks it, with Ant Colony, or say so in its description; this is Ant Colony's open item 14, and with honeycomb the case is stronger. Dave's call.

**Bees at the edge of vision.** A dark, insect-sized shape moving at the screen's edge reads as a real insect on the display (Ant Colony's item 14, unchecked as a finding). Bees should be amber with dark bands rather than black shapes, no darker against the comb than the 3× measured through glass in R1, kept inside the frame (none crossing the screen's edge or walking under the menu bar), and moving slowly enough that peripheral vision doesn't flag them (research-method.md's pace). A Bees slider with a low setting gives the squeamish a way down. Nothing flies: an observation hive's bees fly only outside it.

## 5. Assets and data

**Can ship:**

| Asset | Licence | Status | Use |
|---|---|---|---|
| USGS Bee Inventory and Monitoring Lab, *Apis mellifera, light body, back* (Flickr 34886290922) and *dark body, back* (34240025053) | Public Domain Mark 1.0 | **checked**: each Flickr page (https://www.flickr.com/photos/usgsbiml/34886290922/, …/34240025053/) carries license 10 and links creativecommons.org/publicdomain/mark/1.0; all 25 photos on the stream's first page carry the same | bee cut-outs, top-down on black: easy masks. The light one has its wings folded as a walking bee does; the dark one's are spread. The lab has more *A. mellifera* (drones, a queen, side views) on Commons under the same name |
| Alabama Extension, *Honey Bees on Comb* 1–3 (R10) | CC0 | **checked** (Commons' field) | bees on comb, a cluster mat, the pale growing edge; reference or cut-outs |
| Killerlimpet, *Honey Bees on Comb* (R11) | Public domain | **checked** (Commons' field) | reference |
| Poly Haven woods (138 in its API, e.g. pine and oak veneers) | CC0 | **checked**: https://polyhaven.com/license | the frame |
| ambientCG | CC0 | **checked**: https://docs.ambientcg.com/license/ | nothing useful: searched honeycomb, honey, wax, beeswax, bee, hexagon; only hexagonal tiles and an onyx |
| CC BY photos (R1, R4, R5, R6) | CC BY 2.0–4.0 | checked (Commons' field) | could ship with credit in About; not needed if the comb is drawn |

**Don't ship:** CC BY-SA (R2, R7, R8, R9: share-alike would bind the derived texture) and anything NC.

**The comb is drawn, not photographed.** Each cell changes state on the clock, no CC0 comb texture exists, and a photo of comb is a fixed pattern of holes. The colours above are what it should be drawn in.

**Feeds:**
- **Temperature**: Open-Meteo, already fetched by the app; its API data are CC BY 4.0 with a link required where shown (checked: https://open-meteo.com/en/licence). This drives the cluster.
- **Sunrise and sunset**: worked out in the app already (Flowing Gradient, Night Sky, Weather); no feed. Foragers leave in daylight, which matters for how many bees are on the comb.
- **Nectar flow**: NASA's HoneyBeeNet, a network of scale hives that showed nectar flows, ended with its funding in 2011, and its National Forage Map rests on a dated survey (checked: https://honeybeenet.gsfc.nasa.gov/ says so). No live feed replaces it. The season can come from the date, the latitude and the temperature; for spring's start by latitude, Harvard Forest's HF003 leaf-out data (CC0, checked in [canopy/research-look.md](../canopy/research-look.md)) is the nearest openly licensed source, and USA-NPN's (CC BY 4.0 per the same report, unchecked here). Recommend no new feed.

## 6. Names and look-alikes

- **In the app:** no wallpaper is called anything like it. Night Sky labels the "Beehive Cluster" on the sky (`NightSky.swift:38`), a label, not a menu name; Turing Patterns' doc comment says "honeycomb" internally. No clash.
- **Beehive** (recommended). Searched through trademark aggregators (search excerpts only, partly checked; the USPTO's own search could not be run from a script and TSDR was not read): no live *registered* BEEHIVE mark in classes 9 or 42 turned up; pending applications exist (Beehive Pros, serial 98581065, classes 9/35/37/42; COFRA AG, 79394912, class 9; Beehive Software, 99564346, class 42), and Beehive.com, Inc. holds a live registration (4716757) in classes 35, 42 and 45 whose goods were not seen. *beehiiv*, the newsletter service, is a different spelling. No wallpaper or screen saver of the name was found on the App Store or the web (search, partly checked). As the name of one scene inside an app it is a plain word for what the picture shows; the same caveat as Ant Colony's Rights: a record search, not a clearance, to be checked by a trademark lawyer before the Mac App Store.
- **Observation Hive**: descriptive, the safest, but long for a menu tile and jargon to most people. Use it in the description: "An observation hive behind glass."
- **Honeycomb**: avoid. Crowded in software (Hound Technology's HONEYCOMB, the observability service; Lucera's reg. 4774651; HONEYCOMB SOFTWARE; a 2026 class 9 application; partly checked through aggregators), Post's Honey-Comb cereal (unchecked), and it names the comb alone, the one picture the trypophobia questionnaire uses.
- **Hive**: avoid. Crowded (a smart-home brand, Apache Hive, a social network: unchecked, not searched) and vague.
- **Nothing religious:** the beehive is a symbol of the Church of Jesus Christ of Latter-day Saints and of Utah, from the State of Deseret (1848), and appears in Freemasonry's Third Degree (partly checked: BYU Religious Studies Center and Utah Folk Arts, search excerpts). The emblem is the skep, the domed straw hive. Keep it out of the picture, the menu tile, the site card and the app icon's sheet; a frame hive's comb seen face-on carries none of it.

## 7. Questions for the mock-up sheets

1. Amber, Old Comb, New Comb and Red Lamp side by side, at desktop size under icons, each against its caps.
2. How much frame and case to show: comb edge to edge (the screen as the glass), or the frame's wood and the case's edge in view, or a shutter's edge as if the cover were lifted.
3. A comb at three times of day: the morning's new tongue, midday half drawn and filling, evening mostly capped; with a trypophobia check on each (count the black holes).
4. Bees: R12 cut-outs against a drawn bee, both through glass, at two sizes; bees on the glass (undersides) as an option.
5. The cold cluster: a mat of bees over the brood at three temperatures.
6. Hard edges and the 1.2–2.1× contrast rule measured on every mock-up, as Canopy's were.

## Not verified

- The 2015 Trypophobia Questionnaire paper itself (its two images are reported by two later papers).
- Kupfer and Le's findings beyond press coverage; the 57 °F cluster threshold (beekeeping pages, search excerpts).
- How bees look from below on the glass: no measured photograph.
- Any photograph of a hive under red light; the Red Lamp ramp is chosen.
- Trademark records at the USPTO itself; App Store names beyond a web search; Post's cereal mark.
- Whether bees on the screen's edge read as real insects: Ant Colony's concern, not a measured finding.

## Sources

- Commons file pages and licences: the table in section 1 (read through the Commons API, 2026-11-18).
- USGS BIML on Flickr: https://www.flickr.com/photos/usgsbiml/, https://www.flickr.com/photos/usgsbiml/34886290922/, https://www.flickr.com/photos/usgsbiml/34240025053/ (checked).
- Trypophobia: https://www.psychologicalscience.org/news/releases/fear-of-holes-may-stem-from-evolutionary-survival-response.html, https://pmc.ncbi.nlm.nih.gov/articles/PMC5636197/, https://pmc.ncbi.nlm.nih.gov/articles/PMC7393229/, https://en.wikipedia.org/wiki/Trypophobia (checked); https://www.psypost.org/trypophobia-triggers-stronger-disgust-than-fear-new-study-shows/ (partly checked).
- Comb and hive: https://americanbeejournal.com/?p=6076 (covers), https://beekeepinginsider.com/what-makes-honeycomb-dark/, https://issuu.com/beesfd/docs/120_bfdj_sep2016/7 (comb colour), https://www.honeybeesuite.com/brood-pattern/, https://beebuilt.com/blogs/backyard-beekeeping-blog/brood-frame-basics (layout), https://carolinahoneybees.com/festooning-bees/ (festooning), https://canr.udel.edu/maarec/honey-bee-biology/seasonal-cycles-of-activities-in-colonies/ (cluster), https://beeculture.com/?p=27688 (red light) (all partly checked).
- Licences and feeds: https://polyhaven.com/license, https://docs.ambientcg.com/license/, https://open-meteo.com/en/licence, https://honeybeenet.gsfc.nasa.gov/ (checked).
- Names: https://markinton.com/trademark/beehive-98581065, https://gleanmark.com/trademark/uspto-99564346, https://trademarks.justia.com/872/34/honeycomb-87234045.html, https://en.wikipedia.org/wiki/Honeycomb_(company), https://rsc.byu.edu/salt-lake-city-place-which-god-prepared/beehive-deseret, https://utahfolkarts.omeka.net/exhibits/show/thegrandbeehive/buzzonbeehives/beereifhistory (partly checked).
