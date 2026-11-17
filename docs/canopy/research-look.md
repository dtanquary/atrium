# Canopy: the look research

A research agent's report on what lying on the forest floor and looking straight up should look like, written 2026-11-16. How to draw and move it is in [research-method.md](research-method.md). Every claim is marked **checked** (the page that says so was read on 2026-11-16), **partly checked** (seen only in a search engine's excerpt) or **unchecked**. A Commons licence marked checked is Commons' own licence field for that file, read through its API, which is only as good as the uploader's claim. Hex values and brightness figures are my own samples, measured by small Python scripts on downloaded copies (1,200 px photos; Poly Haven's linear HDRs reprojected to a straight-up view 100° across at 1,440 × 900); the downloads were deleted afterwards and nothing is in the repo. Brightness is the brightest of R, G and B out of 255, as in [kelp-forest/research-look.md](../kelp-forest/research-look.md).

## Summary and recommendation

1. **The view is real and well photographed:** a ring of crowns from the edges, trunks running in toward the middle, sky in channels. The classic shot is an ultra-wide lens, about 100° across (Aspen Sky's EXIF: 15 mm full-frame equivalent). By day a closed broadleaf canopy shows 1–20% sky straight up, a photographer's chosen gap 20–45%; winter 55–80%. The author's "a quarter to a third" is the open end of real: a tall grove, not a closed beech wood.
2. **The glow is physics, not a cheat.** A leaf with the Sun directly behind it passes about 5% of sunlight, which puts it in the same range as the blue sky at the zenith. Shade leaves sit 6–44× darker than the sky. So by day most of the visible canopy should be directly backlit: yellow-green glow, darker inner layers, near-black branches.
3. **A camera's picture fails the caps; the eye's doesn't.** As shot, nearly every reference has its 99th percentile at 239–255, with 1–30% of the frame clipped white sky. Scaled to the caps (×0.64), that sky becomes a flat grey plateau at 210, Kelp Forest's greyed window. The sky must be held to a mid-to-deep blue (150–190) while the backlit leaves are lifted to 150–190 beside it.
4. **It is the sharpest subject yet.** At 1,200 px, canopy photos have 20–67% of pixels on a hard edge, against under 3% for the calm shader scenes and 18% for Fish Tank. A 2 px blur brings that to 2–9%, and a blur plus half the contrast at the sky's edge (the veiling glow) brings it under 1%. Leaves should read as clumps, not as single leaves.
5. **The colour families clash in most seasons.** Summer's yellow-green (64–105°) on blue gaps (210–220°) is Lava Lamp's green-in-blue. Autumn gold (27–45°) on deep blue is complementary. Winter (pale blue, violet-grey lace, white snow, black-green evergreens) is the only season that is one family by nature. The fix is the same each time: gaps small, held, and veiled pale near the leaves, and keep a polarised, saturated blue out.
6. **Palettes (section 2), one per season and light:** *Summer glow* and *Spring beech* (Light Mode, green with silvered gaps), *Beech bronze* (autumn default: olive-gold, one family with the greens), *Aspen gold* (the birch and aspen grove, gaps held pale), *Winter lace* and *Snow* (cool, one family), *Overcast silver* (the calmest), *Blue hour* (Dark Mode) and *Night* (stars in the gaps, darker than Dark Mode's median). Scarlet red maple is the garibaldi of this scene: a few crowns at most.
7. **Assets that can ship, licences checked:** the zeniths of Poly Haven's forest HDRIs (CC0, 16–21K, linear) are real looking-up canopies in every season, including a ring of conifers, snow on conifers beside bare broadleaves, and autumn beech. Also CC0 and public-domain looking-up photos on Commons, ambientCG's CC0 leaf sets (birch-like, a scale-leaf conifer spray, autumn maple), and W.carter's CC0 silver birch bark from below. No CC0 birch bark *scan* (a tiling PBR set) turned up.
8. **Seasons by species, checked:** Harvard Forest's HF003 (CC0) gives medians from 2005 on at 42.5°N for both maples, three oaks, beech, four birches and aspen. Leaves are out in May; red maple and the birches colour first (half coloured 28 Sep–5 Oct), sugar maple on 6 Oct, the oaks 9–20 Oct and beech on 22 Oct, with half its leaves still up until 4 Nov. USA-NPN's data is CC BY 4.0.
9. **Night:** the crowns go black against a sky that is brighter than they are, and stars show only in the gaps. Long-exposure photos are much bluer and brighter than the eye sees. The Dark Mode look is blue hour: deep blue gaps and navy-black crowns lifted just enough (15–30) to reach a median of about 25.
10. **Name:** *Canopy* is safe for a scene in the menu. No wallpaper or screen saver app of that name turned up; the App Store's Canopys are an accounting suite, a health app, a safety app and the like. The most prominent brand of the name is a cannabis company. Fallbacks: *Forest Canopy*, *Treetops*.

## 1. What the real thing looks like

- **Gaps and channels.** Crown shyness ("channel-like gaps" between crowns that don't touch) is documented mostly for *Dryobalanops*, eucalypts, lodgepole pine and black mangrove, explained by wind abrasion and shade avoidance (Wikipedia, checked). It isn't named for birch, beech, oak or maple. In temperate photos the channels come from tall, evenly spaced trees whose crowns don't quite meet: the Shenandoah and aspen shots show it plainly (photos A1, A2, C2). In a closed beech wood (Greenwich Park's HDRI) the sky is only flecks, 1–5%. Gaps run between crowns, so they are long and branching, widest where three crowns meet, and their edges are ragged with single leaves and twigs, never smooth.
- **Trunks.** With a view about 100° across, the trunks are straight lines converging on the middle of the frame. They are dark when the light is behind them (A1, A2) and white when birch or aspen bark catches the Sun (B5, C2). Narrower, about 60°, you see only the upper boles and the crowns. Near branches cross the frame as big dark arms (A5, Epping); watch these, as Kelp Forest's blade did.
- **Backlit and shade leaves.** Chlorophyll absorbs blue and red and least near 550 nm, and a leaf transmits about 5% of the light that reaches it (search excerpts of leaf-optics reviews, partly checked). Light through a leaf comes out yellow-green, sampled at #99AE44–#B6C06D (67–71°) and at #DFE683 at its brightest. Leaves in the crown's own shade are deep olive (#2D3610–#3C521A, 74–83°). Only leaves seen against bright sky near the Sun, or near enough that the camera clips, go to silhouette. Fresh spring beech is paler and yellower and thinner (A4), and the canopy is more open.
- **How bright the parts are** (linear, from Poly Haven's HDRs straight up). The sky in the gaps is 1.5–16× the brightest tenth of the leaves and 6–44× the darkest fifth (table in section 3); under an overcast ring of conifers, 30× and 54×. A leaf passing 5% of direct sunlight of about 100,000 lux shines at about 1,600 cd/m², and a clear zenith sky is a few thousand cd/m² (my arithmetic on textbook figures, unchecked). That is why directly backlit leaves can sit near the sky's brightness while shade leaves can't.
- **The sky straight up.** A clear sky is darkest and bluest about 90° from the Sun (textbook, unchecked). With the Sun 30–60° up (morning, afternoon, autumn and winter), the zenith is the deepest blue in the sky: "small gaps of deep zenith blue" is right then. At a summer noon at 40°N the Sun stands about 73° up and the zenith sits inside its bright aureole, so the gaps go pale. Weather's `Atmosphere` already works out sky colour by direction, so the gaps can follow it.
- **The Sun.** The starburst in Fall Sky (B5) is the lens's aperture, not what the eye sees. The eye sees glare and a bright rim on the leaves round the Sun. Through haze or thin cloud it is a soft white disc (N4). Behind a crown it lights the leaves round it brightest of all, which is the softest way to show it.
- **Overcast.** A flat silver sky (#A1A8BA–#B2B9CB, 221–223°, low chroma) with the leaves dull sage and no glow. It is the highest contrast between sky and leaf but the lowest chroma: calm in colour, harsh in brightness.
- **Autumn.** Aspen and birch go clear gold (#A5882C–#D1B158, 44°; to #C88B3F–#EBB653 sunlit). Sugar maple and the oaks go orange and russet (#703F19–#D29143, 26–32°). Red maple goes scarlet (#8F300A–#CA5114, 17–20°). Beech goes bronze through olive-gold (#736230–#9F894D, 43–45°, with green lingering at 58–61°). The canopy thins from the top and the edges, the sky share rising from about a fifth toward 70% (Autumn Forest 01 at 28–32%, Autumn Forest 04 at 71–74%). Young beech and oak keep dead tan leaves into winter (marcescence, D1's #8D6D1B–#AD8A39; unchecked as a general rule).
- **Winter.** Bare crowns read as lace near the edge of the frame and as a violet-brown haze toward the middle, where twigs thinner than a pixel average with the sky (C1: twigs #121012–#23222E on #59698E–#7D97C4). Beech trunks are violet-grey (#767177–#B0ACB1) with green algae. Evergreens stay as black-green masses (#1C211A–#2B2F25) at the rim (A3, D3, Snowy Forest Path).
- **Snow.** Seen from straight below, snow on top of a branch is mostly hidden. It shows as white edging on branches tipped toward you, and as heavy clumps on conifers (Snowy Forest Path, D2). Lit snow goes to white, and snow in shade to #A6BFD1.
- **Birch and aspen bark from below.** Sunlit it is warm white (#EDE5D9–#F8F2E9), its shade side grey (#5C5A5B–#A3A29B), with black diamonds and rough black at the base (#2D2C2C–#373532) (K1, K2). It is the brightest broad thing in the frame after the sky, so hold it to 200 or less, with the shade side doing most of the work.
- **Aspen leaves tremble** in the lightest wind on their flattened stalks (well known; unchecked here): a shimmer of light and dark faces, a motion of its own for the grove.

### Reference photos
Kept for the look, not to ship unless noted in section 4. Licences are checked unless marked.

| # | Photo | Licence | Shows |
|---|---|---|---|
| A1, A2 | [Crown Shyness 55590114559](https://commons.wikimedia.org/wiki/File:Crown_Shyness_(55590114559).jpg), [55590118744](https://commons.wikimedia.org/wiki/File:Crown_Shyness_(55590118744).jpg), Shenandoah NPS, 8256 px | Public domain | tall eastern broadleaves (species not given) converging, yellow-green crowns, white gaps |
| A3 | [Gullmarsskogen ravine](https://commons.wikimedia.org/wiki/File:Looking_up_at_tree_canopies_in_Gullmarsskogen_ravine.jpg), W.carter | CC0 | **the composition**: conifers dark at the rim, broadleaf inside, one channel of blue with cloud |
| A4 | [Frühling Buchen](https://commons.wikimedia.org/wiki/File:Fr%C3%BChling_Buchen.jpg), Christian Pulfrich | CC BY-SA 4.0 | spring beech, yellow-green glow, blue gaps |
| A5 | [Maple, inside canopy](https://commons.wikimedia.org/wiki/File:Maple_-_Inside_Canopy_-_Cylburn_Arboretum1.jpg), Malcolm Gin | CC BY-SA 3.0 | backlit maple leaves, dark limbs, small white gaps |
| A8 | [Trees from below a](https://commons.wikimedia.org/wiki/File:Trees_from_below_a.jpg) | Public domain | bare crowns on overcast: the high-contrast case |
| B1 | [California black oak, autumn](https://commons.wikimedia.org/wiki/File:Looking_up_through_the_colorful_canopy_of_autumn_foliage_of_the_California_Black_Oak_Tree.jpg) | CC0 | backlit oak leaves, the Sun behind the crown |
| B2 | [Maple trees in autumn, look up](https://commons.wikimedia.org/wiki/File:Maple_trees_in_autumn_-_Look_Up_(68244153).jpg), Vladimir Kostka | CC BY 3.0 | scarlet-orange maple, no sky: what's garish |
| B3 | [Leesylvania SP tree canopy](https://commons.wikimedia.org/wiki/File:Leesylvania_SP_11-9-21_Tree_canopy_-_51670173806.jpg), Virginia State Parks | CC BY 2.0 | November oaks and maples, orange on blue |
| B4 | [Yellow Canopy, Grand Teton](https://commons.wikimedia.org/wiki/File:Yellow_Canopy_-_Grand_Teton_National_Park.jpg), Eric Kilby | CC BY-SA 2.0 | aspen gold, white trunks |
| B5 | [Fall Sky](https://commons.wikimedia.org/wiki/File:Fall_Sky_(4458257342).jpg), Kaibab NF | CC BY-SA 2.0 | aspen on polarised blue, a lens starburst |
| C1 | [Silver birch forest, worm's eye](https://commons.wikimedia.org/wiki/File:Worm%27s_eye_view_in_a_silver_birch_forest.jpg), Forbes Johnston | CC BY 2.0 | bare birch converging, lace into haze |
| C2 | [Aspen Sky](https://commons.wikimedia.org/wiki/File:Aspen_Sky_(4446695252).jpg), Kaibab NF | CC BY-SA 2.0 | **the classic grove**: white trunks from the edges, a gold ring, a pale sky with cloud (15 mm) |
| C3 | [Birches in sky](https://commons.wikimedia.org/wiki/File:170927-FS-Superior-SAR-_birches_in_sky_(37307640736).jpg), Superior NF | Public domain | paper birch, autumn gold |
| C5 | [Sky through birch wood canopy](https://commons.wikimedia.org/wiki/File:Sky_seen_through_the_birch_wood_canopy_-_geograph.org.uk_-_5547810.jpg), Graham Hogg | CC BY-SA 2.0 | summer birch as dark lace on blue |
| D1 | [Beech in winter, Conduit Wood](https://commons.wikimedia.org/wiki/File:Beech_trees_in_winter,_Conduit_Wood,_looking_up_into_the_canopy_-_geograph.org.uk_-_2764240.jpg), Stefan Czapski | CC BY-SA 2.0 | bare beech, algae-green trunks, kept tan leaves |
| D2 | [Looking up at snow on trees](https://commons.wikimedia.org/wiki/File:Looking_up_at_snow_on_trees.jpg) | CC0 | snow on branches, blue sky |
| D3 | [Crowns of broadleaf and conifer](https://commons.wikimedia.org/wiki/File:Koruny_listnat%C3%BDch_a_jehli%C4%8Dnat%C3%BDch_strom%C5%AF.jpg), Jaroslav Mašek | CC BY-SA 4.0 | pine and oak round a channel of cirrocumulus |
| K2 | [Birch trunk in Norrkila 1](https://commons.wikimedia.org/wiki/File:Birch_trunk_in_Norrkila_1.jpg), W.carter | CC0 | silver birch bark from below into bare branches |
| N3 | [Blue hour oak in Rogalin](https://commons.wikimedia.org/wiki/File:Blue_hour_oak_in_Rogalin.jpg), Jakub T. Jankiewicz | CC BY-SA 4.0 | twilight sky behind a silhouette |
| N1 | [Star trails with fig leaves](https://commons.wikimedia.org/wiki/File:Star_trails_in_the_night_sky_with_fig_tree_leaves.jpg), Ale Eyestar | CC BY 4.0 | leaves on a night sky (a long exposure, far bluer than the eye) |
| N4 | [Looking up at trees](https://commons.wikimedia.org/wiki/File:Looking_up_at_trees_-_Flickr_-_alankaplan2.jpg), Alan Kaplan | Public domain | the Sun as a soft disc through haze, crowns in silhouette |

Poly Haven HDRIs, all CC0 (checked, below), each seen straight up. Species are guessed from where they were shot (unchecked):

| HDRI | Where, light | Straight up |
|---|---|---|
| [epping_forest_01](https://polyhaven.com/a/epping_forest_01) (16K) | Epping Forest, England; midday, partly cloudy | beech, oak and hornbeam backlit, the Sun's glow at a gap |
| [green_sanctuary](https://polyhaven.com/a/green_sanctuary) (19K) | Stuttgart; afternoon | a broadleaf crown overhead, a pale trunk, the sky white through it |
| [greenwich_park_02](https://polyhaven.com/a/greenwich_park_02) (21K) | London; afternoon | one big crown, closed: what the author warned against |
| [autumn_forest_01](https://polyhaven.com/a/autumn_forest_01) (16K) | Swabian Alb; autumn | beech turning, trunks converging |
| [autumn_forest_04](https://polyhaven.com/a/autumn_forest_04) (22K) | near Stuttgart; clear, low Sun | late autumn, mostly bare, brown leaves on blue |
| [forest_slope](https://polyhaven.com/a/forest_slope) (20K) | Saxon Switzerland | conifers converging, a few broadleaves |
| [niederwihl_forest](https://polyhaven.com/a/niederwihl_forest) (18K) | southern Germany (from its name; unchecked); overcast | **a ring of spruce or fir round a white sky** |
| [snowy_forest_path_01](https://polyhaven.com/a/snowy_forest_path_01) (17K) | (not given); clear winter | **snow-laden conifers beside bare broadleaves on blue** |
| [snowy_forest](https://polyhaven.com/a/snowy_forest) (16K) | (not given); overcast, snow | conifers converging |
| [forest_grove](https://polyhaven.com/a/forest_grove) (20K) | South Africa; clear, low Sun | bare broadleaf lace on pale blue (light only; not our species) |

## 2. Palettes

Sampled by class (sky, green leaf, warm leaf, bark) at the 10th to 98th percentile of brightness; then, where needed, given as they'd be held to the caps. Hues are in brackets.

| Palette | From | Sky gaps | Leaves, shade to glow | Branches, bark | One family? |
|---|---|---|---|---|---|
| **Summer glow** (Light Mode default) | A4, A5, Epping, River Walk | #6E8BB8 #839CC5, veiled to pale silver near leaves (216°) | #2D3610 #3C521A #4F6726 #5F6B2F #99AE44 #B6C06D, glints #DFE683 (64–83°) | #1A160B #21150D | **No**: yellow-green on blue. Gaps 10–20% of the screen, the veil pale where they meet leaves. |
| Spring beech | A4 | #839CC5 #A5BBE0 | #45501B #5F6B2F #818D49 #B6C06D (64–72°) | #21150D | As above; paler, more sky (23%). |
| **Beech bronze** (autumn default) | Autumn Forest 01, D1 | #9F9FB5 #B1B2CE (pale lavender at the cap) | #645527 #736230 #88743E #9F894D, greens #9D9F40 #B6B461 (43–61°) | #33302C #4C4B46 | **Yes**, with summer's greens and gold. |
| Sugar maple and oak | B3 | #75B3DF (deep, clashes) | #583011 #703F19 #955928 #D29143, glints #F2BD4B (26–40°) | #231713 | No: orange on blue, complementary. Pale gaps or golden hour. |
| Red maple | B2 | — | #5A2707 #722C08 #8F300A #CA5114 (17–20°) | #261506 | The hottest thing in the picture: a few crowns at most. |
| **Aspen gold** (the grove) | C2, B4, C3 | #93B4D3 #B2C7DC, pale, with cloud | #917722 #A5882C #BE9C42 #D1B158 (44°); sunlit #C88B3F #EBB653 | trunks #96948C (shade) #C6C3BC (lit), held ≤ 200 | Yes, if the sky stays pale. B5's polarised #0B64AD is the postcard and the clash. |
| **Winter lace** | C1, forest_grove, D1 | #59698E #6C81AA #7D97C4 (216°) | kept tan beech #8D6D1B #AD8A39 (sparse) | twigs #121012 #23222E lifting to violet-grey in the haze; beech #767177 #979399 | **Yes**: cool, violet-blue. |
| **Snow** | D2, Snowy Forest Path | #7288A9 #7596C0 #85A5CC (212–216°) | conifers #1C211A #21261F #2B2F25 | snow shade #A6BFD1, lit ≤ 210 | **Yes**: blue, white, black-green. |
| Overcast silver | Niederwihl at the cap | #A1A8BA #ACB4C6 #B2B9CB (221–223°) | lift to sage, #4F5A40–#6E7A55 (my target, not a sample) | #181911 #2C2B1A | Yes, and the calmest; not the default (the author: caps from the start, not an overcast default). |
| **Blue hour** (Dark Mode) | N3 ×0.12–0.25 linear | #011A3E #01264C #022859 #02396C (208–228°) | crowns navy-black, #0E1A22–#142530 (my target, so the median reaches 25) | silhouettes #05080C | **Yes**: blue. |
| Night | the app's Night Sky | #050B1A–#0A1530 | black, #020406–#060A0E | — | Yes. The median falls to 10–15, darker than Dark Mode's 25–45, like Jellyfish's glow. An option, not the Dark Mode default. |

- **What clashes:** scarlet maple next to blue gaps; aspen gold on deep polarised blue; summer green on a saturated blue; sunlit white birch bark at full white (a hard bright line). All four are what stock wallpapers do.
- **What dims well:** blue and the olive-gold of beech. The Kelp report found gold turns to mud at the dark caps. Here autumn gold is only for Light Mode; Dark Mode is blue at every season, the crowns' colour gone at dusk as it is to the eye.

## 3. Brightness

Photos as shot, then scaled in linear light until the 99th percentile is 210 and the 99.9th 230 (median / 90th / 99th / 99.9th):

| Picture | As shot | Clipped (≥ 250) | Scaled to the caps |
|---|---|---|---|
| A2, Shenandoah crowns | 76 / 219 / 255 / 255 | 3.4% | ×0.64: 61 / 180 / 210 / 210 |
| A4, spring beech | 124 / 223 / 255 / 255 | 2.7% | ×0.64: 101 / 183 / 210 / 210 |
| A5, maple | 77 / 187 / 255 / 255 | 4.8% | ×0.64: 62 / 153 / 210 / 210 |
| C2, Aspen Sky | 161 / 231 / 254 / 255 | 2.7% | ×0.65: 132 / 191 / 210 / 211 |
| C1, bare birch | 139 / 215 / 239 / 251 | 0.1% | ×0.75: 121 / 189 / 210 / 221 |
| D2, snow on branches | 153 / 241 / 255 / 255 | 7.6% | ×0.64: 125 / 198 / 210 / 210 |
| Epping (Poly Haven's own tone map) | 139 / 233 / 255 / 255 | 5.7% | ×0.64: 113 / 192 / 210 / 210 |
| Autumn Forest 01 (tone-mapped) | 178 / 253 / 255 / 255 | 14.7% | ×0.64: 146 / 208 / 210 / 210 |
| Niederwihl (tone-mapped) | 159 / 255 / 255 / 255 | 30.0% | ×0.64: 130 / 210 / 210 / 210 |

Nearly every reference needs ×0.64–0.75 to meet the caps, and what that does to their clipped sky is a flat 210 grey over 1–30% of the frame. Medians land at 60–150, so the leaves are bright enough in a tone-mapped picture. The sky is the problem.

Linear light from the HDRs, straight up, with the sky's median held at 185:

| HDRI | Sky ÷ lit leaves | Sky ÷ shade leaves | Median with the sky at 185 | Sky share |
|---|---|---|---|---|
| Epping (summer) | 4.8× | 9.3× | 31 | 12% |
| Green Sanctuary | 2.3× | 9.8× | 25 | 10% |
| Greenwich Park (closed crown) | 16× | 44× | 10 | 1% |
| Autumn Forest 01 | 8.0× | 22× | 61 | 28% |
| Autumn Forest 04 (late, low Sun) | 1.5× | 5.6× | 151 | 74% |
| Snowy Forest Path (winter) | 4.3× | 8.4× | 169 | 82% |
| Niederwihl (overcast, conifers) | 30× | 54× | 45 | 42% |

So a faithful exposure with a calm sky puts a summer canopy's median at 10–31, against Light Mode's 90–140: the dark-leaves-on-bright-sky risk, in numbers. A held look needs the lit leaves within about 1.2–1.5× of the sky (backlit at 150–190 beside gaps at 160–190) while the shade leaves keep roughly their real tenth (50–90). Winter is the reverse: mostly sky, so its median is already in range, but its edges are the hardest.

**Hard edges** (the share of pixels more than 24 from the pixel 2 px away, at 1,200 px): canopy photos come to 20–67% (A4 67%, B3 58%, C1 58%, Epping 43%, Greenwich 21%), against 2.7% for Weather and 18% for Fish Tank. A Gaussian blur of 1 px leaves 9–34%, and of 2 px 2–9%; 2 px plus half the contrast leaves 0–0.5%. On a Retina screen, 2 px at 1,200 is about 5 device pixels: a soft focus, which a near branch earns honestly (out of focus) and a far crown needs as clumps rather than leaves.

**What softens it without going grey**, most effective first:
1. **The glow:** most of the canopy directly backlit (the Sun behind the crowns), lit leaves at 150–190 in yellow-green, which brings the sky-to-leaf ratio from 5–45× down to under 2× where it matters.
2. **Gaps held to the zenith's blue,** 150–190 and never white: real when the Sun is below about 60°, so let the Sun's height set how pale the gaps go, as Weather's `Atmosphere` would.
3. **A veiling glow** where sky meets leaf, a few pixels wide, mixing the two: it halves the contrast at the edge, which is what takes hard edges below 1%, and it pales the blue next to the green, which eases the clash.
4. **The Sun behind a crown** by default: a bright patch of glowing leaves round it, a core of 240 at most, and no starburst or flare.
5. **Scale and softness:** leaves read as clumps; the near crowns soft (out of focus), the far ones fine but low in contrast.

Caps, as Kelp Forest's (mine to try under icons, unchecked): Light Mode, a median of 90–140, the 99th percentile ≤ 210, the 99.9th ≤ 230, the Sun's core ≤ 240, hard edges under 3%. Dark Mode (blue hour), crowns at 15–30, a median of 25–45, gaps ≤ 150 (110 calmer), stars ≤ 190.

## 4. Assets and feeds

| What | Source | Licence | Notes |
|---|---|---|---|
| **Looking-up canopies, every season** | Poly Haven HDRIs (section 1) | CC0, "You do not need to give credit" (polyhaven.com/license, **checked**) | 16–21K equirectangular, so a view 100° across straight up gets about 4,500–6,000 px of source: enough for Retina. Linear light, so the sky keys cleanly from the leaves (it is 5–50× brighter). Each is one place in one season: seasons would mean swapping HDRIs, or using them only for the far canopy. No seams or tripod at the zenith in the sixteen I reprojected. |
| Cut-out crowns from photos | A3, A1/A2, B1, D2, C3, K2 (CC0 / public domain); CC BY and BY-SA in section 1 | Commons fields, **checked** | Keying the sky out is practical (it's blue or bright; Weather keyed its cumulus on blueness). Cutting *individual crowns* is not: crowns merge, except across clear shyness channels. Cut the canopy as one layer, or sectors of the rim. BY-SA would make the cut-out BY-SA too, which is allowed but adds a credit. |
| Leaf scans for birch and aspen | ambientCG [LeafSet001](https://ambientcg.com/a/LeafSet001) (small, ovate, toothed: birch-like), [LeafSet006](https://ambientcg.com/a/LeafSet006) and [LeafSet007](https://ambientcg.com/a/LeafSet007) (yellowing toothed ovals: birch or elm), [LeafSet009](https://ambientcg.com/a/LeafSet009) (round, yellow-green: nearest to aspen) | CC0, "All ambientCG assets are provided under the Creative Commons CC0 1.0 Universal License" (docs.ambientcg.com/license, **checked**) | ambientCG names no species: these are **my identifications by eye, unchecked**. [LeafSet004](https://ambientcg.com/a/LeafSet004) is heart-shaped with smooth edges, more lilac than aspen. At canopy distance a leaf is a few pixels, so shape matters less than colour and clumping. |
| Autumn leaves | [LeafSet021](https://ambientcg.com/a/LeafSet021) (small yellow maple), [LeafSet028](https://ambientcg.com/a/LeafSet028) (maple in red, orange and yellow), [LeafSet012](https://ambientcg.com/a/LeafSet012) and [LeafSet030](https://ambientcg.com/a/LeafSet030) (dry brown oak) | CC0, checked | For falling leaves, where a leaf is near and large. |
| Evergreen sprays and crowns | [LeafSet019](https://ambientcg.com/a/LeafSet019) (a scale-leaf spray, cypress or thuja, not pine), [PineNeedles001](https://ambientcg.com/a/PineNeedles001); Poly Haven models [fir_tree_01](https://polyhaven.com/a/fir_tree_01), [pine_tree_01](https://polyhaven.com/a/pine_tree_01) | CC0, checked | No spruce or fir spray scan turned up. A CC0 fir model rendered from directly below would give a true conifer silhouette for the rim; Niederwihl's and Snowy Forest Path's zeniths are real ones. |
| Birch bark | Commons [Bark on birch in Norrkila](https://commons.wikimedia.org/wiki/File:Bark_on_birch_in_Norrkila.jpg) and [Birch trunk in Norrkila 1](https://commons.wikimedia.org/wiki/File:Birch_trunk_in_Norrkila_1.jpg) (W.carter, CC0), [SNF Tofte peeling birch bark](https://commons.wikimedia.org/wiki/File:SNF_Tofte_Peeling_birch_bark_FC102315_(22484092442).jpg) (USFS, public domain) | Commons fields, checked | Photos, not tiling scans: a strip would need its seam painted out (as Dappled Light's siding had). No CC0 birch set on Poly Haven or ambientCG (both catalogues searched through their APIs, checked). ShareTextures says it is CC0 but showed no birch (partly checked). AITextured's birch sets are AI-made and not CC0: avoid. |
| Other bark | Poly Haven [pine_bark](https://polyhaven.com/a/pine_bark), [jolcham_oak_bark_01](https://polyhaven.com/a/jolcham_oak_bark_01), [bark_brown_01](https://polyhaven.com/a/bark_brown_01); ambientCG [Bark005](https://ambientcg.com/a/Bark005) (smooth, grey-green: beech-like by eye, unchecked) | CC0, checked | Looking up, bark is mostly in silhouette. Texture shows only on near trunks and white birch. |
| Seasons by species | Harvard Forest [HF003](https://harvardforest1.fas.harvard.edu/exist/apps/datasets/showData.html?id=HF003), O'Keefe and VanScoy | **CC0-1.0, checked** | One site at 42.5°N; medians 2005–2023 from its species means (my arithmetic). Bud break and half the leaves coloured and fallen: red maple 8 May, 28 Sep, 9 Oct; sugar maple 2 May, 6 Oct, 19 Oct; white oak 14 May, 9 Oct, 22 Oct; red oak 8 May, 20 Oct, 3 Nov; beech 8 May, 22 Oct, 4 Nov; paper birch 7 May, 4 Oct, 12 Oct; yellow birch 10 May, 1 Oct, 11 Oct; aspen 6 May (no autumn record). White pine and hemlock are evergreen. `Phenology.moved` can carry these to other latitudes as it does the white oak. |
| | USA-NPN | **CC BY 4.0**, "as long as appropriate credit is given" (usanpn.org/about/terms, checked) | Many sites and latitudes. `Phenology.whiteOak` already comes from NPN records. |
| | PhenoCam | CC BY 4.0 now; version 1.0 was CC0 (search excerpt, partly checked) | Canopy greenness from cameras, if colour timing is wanted. |
| Wind, sky, cloud, stars | Open-Meteo (CC BY 4.0, checked in the Kelp report); Weather's `Atmosphere` and clouds; Night Sky's catalogue | already in the app | |

## 5. Names and look-alikes

- **Canopy:** no wallpaper or screen saver of that name turned up on the App Store or the web (searches, partly checked). The App Store has an accounting suite (Canopy Tax), Canopy Care, Canopy Protect, a community app and a church app (listings via search, partly checked), and the University of New Hampshire's CanopyApp, a densiometer. The best-known brand of the name is Canopy Growth, a cannabis company (unchecked). As a scene's name in a list beside Kelp Forest and Night Sky, it reads as the plain noun. **Safe** for the menu; trademarks not searched (unchecked).
- **Fallbacks:** *Forest Canopy* (plainest, unambiguous) and *Treetops* (unchecked). *Crown Shyness* is apt but obscure, and the phenomenon is mostly tropical and pine.
- **Look-alikes:** Apple's aerials include Redwoods and Sequoia sets but nothing named forest or canopy (zhongzachary's list, checked; camera angles not stated). Android's *Forest Live Wallpaper* follows weather and time, side-on, not looking up (listings, partly checked). Looking up at a live canopy with real seasons, wind and stars looks unoccupied. **What looks cheap:** saturated red maple, polarised navy sky, lens starbursts and flares, every leaf crisp, trees swaying in step, green on a saturated blue.

## 6. Proposed questions for the mock-up sheets

One question a sheet, each at desktop size under icons, held to the caps:

1. **The view:** A, a ring of broadleaf crowns about 90° across, a branching channel through the middle; B, ultra-wide (100–110°) with trunks converging from the edges, as Aspen Sky; C, an evergreen rim with broadleaves inside, as Gullmarsskogen; D, a forest edge, crowns on two sides with a band of sky; E, one crown overhead, the control the author warned against.
2. **The day's light (summer):** A, a camera's exposure scaled to the caps (the grey-sky control); B, glow with deep zenith-blue gaps; C, glow with gaps veiled pale; D, the Sun behind a crown with its halo; E, overcast silver; F, golden hour.
3. **The forest:** maple, oak and beech mixed; a birch grove; an aspen grove: the same light and season, to choose one or both.
4. **Autumn:** beech bronze, sugar maple orange, aspen gold, and a mix with a few red maples, each with its sky held pale.
5. **Winter:** bare lace as haze or as crisp lines; two, four or six evergreens in the ring; with snow on the branches.
6. **Dark Mode and night:** blue hour silhouettes; crowns lifted to navy-green; a night of stars in the gaps under a dark sky, and under suburban orange skyglow (the honest sky for most users).

## Not verified
- Species in the Shenandoah photos and the Poly Haven HDRIs; the identities of ambientCG's leaf sets.
- Leaf transmission of about 5%, chlorophyll's window near 550 nm (search excerpts); direct sunlight of about 100,000 lux and a zenith sky of a few thousand cd/m²; the sky darkest 90° from the Sun; marcescence as a rule; aspen's trembling (textbook, not read).
- Gap fractions: mine, by a colour classifier on photos and HDRs, not from hemispherical-photo literature (whose search found no general leaf-on/leaf-off figure).
- Trademarks for CANOPY; *Treetops* as a fallback.
- Whether these caps keep icons readable over a canopy: to try on a real desktop.

## Sources
- Crown shyness: https://en.wikipedia.org/wiki/Crown_shyness ; Putz et al. 1984: https://repository.si.edu/bitstream/handle/10088/17792/serc_Putz_etal_1984_AmMidlNat_112_24_28.pdf
- Leaf optics (search excerpts): https://sites.bu.edu/cliveg/files/2023/10/leaf-optics-jacquemoud-ustin.pdf , https://research.utu.fi/converis/portal/detail/Publication/50850548?lang=en_US
- Licences: https://polyhaven.com/license , https://docs.ambientcg.com/license/ , http://www.usanpn.org/about/terms , https://harvardforest1.fas.harvard.edu/exist/apps/datasets/showData.html?id=HF003 , https://phenocam.nau.edu/webcam/fairuse_statement
- Harvard Forest data: https://harvardforest1.fas.harvard.edu/data/p00/hf003/hf003-06-spring-mean-spp.csv , https://harvardforest1.fas.harvard.edu/data/p00/hf003/hf003-08-fall-mean-spp.csv
- APIs searched: https://api.polyhaven.com/assets , https://ambientcg.com/api/v2/full_json , https://commons.wikimedia.org/w/api.php (Commons' Worm's-eye view of trees category and searches)
- Names: https://apps.apple.com/us/app/canopy/id1444764477 , https://apps.apple.com/us/app/id1368449357 , https://apps.apple.com/us/app/canopy-protect/id6478836828 , https://apps.apple.com/us/app/canopyapp/id926943048 , https://github.com/zhongzachary/sonoma-screen-savers , https://alternativeto.net/software/forest-live-wallpaper/about
- Birch textures: https://www.sharetextures.com/blog/8-free-wood-bark-pbr-textures , https://aitextured.com/textures/bark/seamless-birch-bark-texture-seamless.html
- Reference photos and HDRIs: the links in section 1, each licence read from Commons' own field or Poly Haven's licence page on 2026-11-16.
