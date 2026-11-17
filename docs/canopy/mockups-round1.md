# Canopy: mock-ups, round 1 (the big choices)

Drawn 2026-11-16 by `mock.swift` (SpriteKit's `SKRenderer`, as the app draws a wallpaper) from `variants.py`, laid out by `sheet.py`. Every tile is the build's shader at 3024 × 1964, written at desktop size (1512 × 982) and scaled to a 640 × 400 tile. Its second caption line is measured: GPU and CPU time a frame at 3024 × 1964 (medians of 50 frames, as the method probe timed; Nebula reads about 1.7 ms of GPU on this M3 Max), and brightness, the brightest of R, G and B at desktop size, out of 255.

**To redraw a round:** `CANOPY_HDRI=<a new empty folder> python3 -I sheet.py fetch` downloads the HDRIs, one folder each. Then `python3 -I sheet.py <sheet name> [out dir]` draws a sheet (`sheet1-make`, `sheet1-reference`, `sheet2-view`, `sheet3-light`, `sheet4-desk`, `sheet4-desk-autumn`, `film1-autumn`) and prints its table.

## What every tile shares
- **Camera:** a pinhole pointed at the zenith, 90° across the long side (110° on sheet 2's B), head to the north. 42°N.
- **Sky:** the app's own `Atmosphere`, copied in from `WeatherSky.swift`, marched through that camera for the date and solar hour. The Sun's place comes from Cooper's declination formula, good to about half a degree; the build would use `Sky.sun`. No clouds except sheet 3's overcast. No night tiles in this round, so there are no stars.
- **Leaves:** grown in (b) and (c) at load. There are three depth layers of sprays, 5,000 to 9,000 a layer, of 9–13 leaves each, cut from the app's scanned leaf atlas `dappled-leaves.png` (ambientCG, CC0). Each spray has an id that decides when it turns and when it falls. Colours are the look research's palettes, which were sampled from photos: Summer glow `#99AE44`–`#B6C06D`, Beech bronze `#736230`–`#9F894D` with `#9D9F40` and a little sugar maple `#D29143`, and Aspen gold for sheet 2's B.
- **Light:** each leaf passes 8% of the light on its top side. The light reaching it is the Sun's beam through the layers above, read along the Sun's direction, plus the sky's light through the layers straight above. The exposure holds the zenith at 175. A contrast power of 0.6 on luminance lifts the leaves toward the sky. The tone curve is Weather's (`sqrt(1 − e^−x)`), and the output is capped at 240.
- **Sway:** each crown sways as a body about its own trunk. A tree-id map is flooded from each trunk's entry at the screen's edge along the wood, in four sway groups at 0.17–0.29 Hz under a gust envelope, 6 px at 2x in a 4 m/s breeze. Only the film shows it.
- **Dates:** midsummer is 15 July at 4:30 pm solar time (the Sun 31° up, out of frame). Late autumn is 1 November at 2 pm (the Sun 26° up), with every remaining spray turned and half of them down.

## Caps
From research-look.md §3:
- **Light Mode median:** 90–140.
- **Percentiles:** 99th ≤ 210, 99.9th ≤ 230.
- **Sun core:** ≤ 240.
- **Hard edges:** under 3%. That is the share of pixels more than 24 from the pixel 2 px away, at 1,200 px across.

**No tile meets the hard-edge cap**, and the real photos miss it too (26–65%). Every tile meets the 99th and 99.9th caps, which the photos miss (they clip at 255). The tables mark where the median misses.

## Sheet 1: how the crowns are made (`sheet1-make.jpg`, reference `sheet1-reference.jpg`)
Top row midsummer, bottom row late autumn, same date and light in each row.

| Tile | Median | 99th | 99.9th | Max | Edges | GPU ms | CPU ms | Bake ms | Sky |
|---|---|---|---|---|---|---|---|---|---|
| A (a) photo crowns, midsummer | **65** | 176 | 180 | 184 | 27.5% | 0.57 | 0.35 | 104 | 6% |
| B (b) all built | **146** | 194 | 195 | 196 | 17.4% | 0.52 | 0.37 | 861 | 48% |
| C (c) real bare stand, leaves grown on it | 98 | 179 | 184 | 193 | 44.3% | 0.53 | 0.37 | 652 | 13% |
| D (a) late autumn: recoloured, half dissolved | 136 | 191 | 195 | 197 | 59.0% | 0.54 | 0.36 | 103 | 55% |
| E (b) late autumn | **174** | 194 | 196 | 197 | 27.4% | 0.42 | 0.40 | 880 | 60% |
| F (c) late autumn | 117 | 181 | 184 | 196 | 50.4% | 0.43 | 0.41 | 641 | 20% |

**How each tile is made:**
- **A and D, (a):** Epping Forest's zenith (Poly Haven, 8k), its sky keyed out by unmixing each pixel between the local sky and the dark wood, with green kept by its hue. The leaves keep the photo's own light. A is dark (median 65) because Epping's canopy is nearly closed, so it misses the median cap. D shows honestly what (a) can do in autumn: the leaves recoloured into bronze, and half dissolved a leaf-sized blob at a time. Behind every fallen leaf is sky, never a limb, because the photo has nothing behind its leaves. The result is a pepper of holes. A bare winter would need a different photo, so the stand changes identity at each season's swap.
- **B and E, (b):** 18 trees laid out by code in a ring round a 6.5 m gap. They are 20–26 m tall, with crowns from 60% of their height, and their limbs split six times into twigs. The leaves are grown on those twigs as in (c). The crowns read as spiky stars of straight limbs: the "drawn" risk that cut A Tree for the Year. They come out too open (48–60% sky), so their median sits at the sky's brightness and misses the cap.
- **C and F, (c):** Poly Haven's `autumn_forest_04` at 8k, a late-autumn beech stand near Stuttgart with nearly every leaf down. Its keyed zenith is the wood. Its bark is relit as grey bark (#4C4B46) in the canopy's shade, since the photo's low Sun lit it orange. Sprays are grown in clumps where its matte is a thin haze of twigs, and the trunks, the limbs and solid masses grow none. In late autumn, F thins to the photo's own real limbs.

**What (c) lacks:**
- The leaves are flat tinted silhouettes, with one hue and brightness for each spray and its light through it. At desktop size they read as cut-outs pasted on a real stand, not as a real canopy. Compare the reference sheet's Autumn Forest 01.
- The thickest twig masses still grow thinner leaves than a real crown.
- The bark keeps the photo's own shading.
- There is no snow, no marcescent leaves kept through winter, and no per-species calendar yet (one turn date for all).

## Sheet 2: where you lie (`sheet2-view.jpg`)
All in (c), midsummer. Sky is the share of the screen less than half covered, by the bake. It counts the photo's haze of fine twigs as cover, so more sky shows through than it says.

| Tile | Median | 99th | 99.9th | Max | Edges | GPU | CPU | Bake | Sky |
|---|---|---|---|---|---|---|---|---|---|
| A ring of crowns round a channel, 90° | 98 | 179 | 184 | 193 | 44.3% | 0.43 | 0.34 | 676 | 13% |
| B ultra-wide 110°, aspen leaves, beech wood recoloured | 107 | 183 | 189 | 201 | 46.3% | 0.51 | 0.36 | 615 | 12% |
| C evergreen rim, broadleaves inside | 107 | 188 | 193 | 195 | 34.1% | 0.49 | 0.41 | 638 | 21% |
| D a forest edge, crowns on one side | 108 | 183 | 184 | 194 | 24.9% | 0.53 | 0.35 | 600 | 37% |
| E closed canopy, sky in flecks | **59** | 160 | 179 | 191 | 24.2% | 0.42 | 0.43 | 1092 | 2% |

- **A:** the sheet 1 stand.
- **B:** the same stand through a 110° lens, with smaller, rounder leaves (the atlas's beech shapes) in the Aspen gold palette's greens, and its trunks recoloured to birch's shade-side grey (#C6C3BC). **No CC0 or public-domain straight-up photo of a bare birch or aspen stand was found**, so the white trunks are paint on beech. They read as flat grey, not as bark.
- **C:** Poly Haven's `schachen_forest` (4k): real conifers at the rim stay dark all year, with leaves grown on its bare broadleaves.
- **D:** sheet 1's stand with the trees whose trunks enter from one side removed (their tree ids). The cut is ragged only by a wander of the ids, and parts of it still run straight.
- **E:** the same stand with twice the sprays, larger and spread across the channels. It is dark (median 59, which misses the cap), as a closed canopy is.

## Sheet 3: softening the day, summer (`sheet3-light.jpg`)

| Tile | Median | 99th | 99.9th | Max | Edges | GPU | CPU |
|---|---|---|---|---|---|---|---|
| A a camera's exposure, scaled to the caps | 98 | 208 | 209 | 209 | 55.7% | 0.46 | 0.34 |
| B leaves glowing, deep zenith-blue gaps | 98 | 179 | 184 | 193 | 44.3% | 0.45 | 0.34 |
| C the same, gaps veiled pale at the leaves | 101 | 172 | 178 | 183 | 36.3% | 0.53 | 0.36 |
| D the Sun behind a crown, its halo | 103 | 167 | 177 | 179 | 32.8% | 0.54 | 0.34 |
| E overcast silver | **87** | 171 | 174 | 175 | 49.9% | 0.45 | 0.42 |
| F golden hour | 115 | 178 | 187 | 192 | 33.9% | 0.47 | 0.39 |

- **A:** metered on the frame's mean at 18% grey, clipped as a sensor clips, then scaled in linear light by 0.64. Its sky is the flat plateau at 208 the look research warned of, and its edges are the hardest.
- **B:** the default light.
- **C:** a veil of 0.5: where sky meets leaf, a few pixels' mix of the two, and the blue paled toward silver (#B2B9CB). A veil of 1.0 read as fog.
- **D:** the hour picked automatically near noon where the Sun stands behind the thick of a crown: 1:09 pm, the Sun 65° up, 5% of it showing through. The disc shows only where the canopy is open, and the glare is a soft halo with no starburst.
- **E:** a uniform deck in the look research's overcast silver (#ACB4C6), no direct Sun. It is dull sage on grey, and just under the median cap.
- **F:** 6:40 pm, the Sun 7° up, its light reddened by the `Atmosphere`, with a veil of 0.5.

## Sheet 4: at a desktop's size (`sheet4-desk.jpg`, `sheet4-desk-autumn.jpg`)

| Tile | Median | 99th | 99.9th | Max | Edges | GPU | CPU | Bake | Sky |
|---|---|---|---|---|---|---|---|---|---|
| Recommended, midsummer | 105 | 170 | 178 | 182 | 19.3% | 0.47 | 0.41 | 647 | 8% |
| Recommended, late autumn | 120 | 172 | 180 | 183 | 23.3% | 0.47 | 0.37 | 652 | 16% |

The recommended look is (c), the ring at 90°, with a veil of 0.5 and a soft focus: the leaf layers and the wood blurred by 2 px at 2x (`soft: 2`). That is the softest of the round, and it is still 19% hard edges, against 3%. Getting under 3% needs about 5 device pixels of blur, which the look research measured. That is a soft focus on the whole canopy, and it is round 2's question.

## The film (`film1-autumn.mp4`)
- **What it is:** 12 s at 30 fps of the late-autumn recommended look, at half size (1512 × 982 px), H.264, 728 KB. The frames were piped straight to ffmpeg and never written to disk.
- **Wind:** a 4 m/s breeze. The crowns sway as bodies about their own trunks, about 6 px at 2x (3 px in the film), and the trunks near the edge hardly move.
- **Falling leaves:** a scanned leaf about 9 cm across, let go 15–19 m up. It falls at about 0.9 m/s with a 60% swing in speed as it tumbles, drifts with the wind, flips, and fades out between 8 and 5.5 m. That is about one in view at a time, a new one every 13 s.
- **How it was checked:** from a contact sheet of a frame every 0.5 s with a map of what changed, and by stills with the wind off to find the leaves.

At the real rate and size, a falling leaf is 4–12 px across in the film and the canopy's own bronze. **It is nearly invisible unless you look for it.**

## Recommendations
- **Sheet 1: C (c).** Its wood is the only one that reads real, and it is the only one whose autumn thins to its own limbs. (a)'s autumn is a pepper of sky holes, and (b) reads drawn.
- **Sheet 2: A, the ring at 90°, or C, the evergreen rim.** C's real conifers frame the view all year, which is what Dave asked for in winter. B needs a real birch stand photo, D's cut runs straight in places, and E is too dark.
- **Sheet 3: C, the veiled gaps, with D's Sun behind a crown at summer middays.** A looks livelier, but it is the clipped-sky control and the hardest-edged.
- **Sheet 4:** as above, with a veil of 0.5 and a soft focus.

## Worse than the research expected
1. **The leaves read as cut-outs at desktop size.** The method research put the risk in the limbs, saying "the leaves themselves are not the weak part". With a real stand under them, the flat, evenly lit sprays are now the weak part: compare `sheet1-reference.jpg`'s Autumn Forest 01. Round 2 should try per-leaf light (overlaps darker, single leaves glowing) and a translucency map.
2. **Hard edges are 17–59% everywhere, and 19% at the softest.** The cap of 3% means soft focus over the whole canopy.
3. **The sky share is lower than the brief's quarter to a third**, because the photo's twig haze darkens the gaps. Visually the channels are wider than the number says.
4. **Falling leaves at the real rate are nearly invisible** (above).
5. **There is no CC0 bare birch or aspen stand photographed straight up**, so the grove (sheet 2 B) has no honest wood yet. The CC BY 2.0 silver birch worm's-eye view (C1) exists but is outside the brief's CC0/PD rule.
6. **Cost is as the probe measured:**
   - **Every frame:** 0.42–0.57 ms of GPU and 0.33–0.43 of CPU, a quarter of the 2 ms budget.
   - **The bake:** 0.6–0.9 s here in Core Graphics, against the probe's 0.2 s on the GPU.

## Assets
All are CC0 or public domain. The downloads were deleted after rendering.

| Asset | Used for | Licence | URL |
|---|---|---|---|
| Poly Haven `autumn_forest_04`, 8k HDR | (c)'s wood, every (c) tile and the film | CC0 | https://polyhaven.com/a/autumn_forest_04 |
| Poly Haven `epping_forest_01`, 8k HDR | (a), sheet 1 A and D; the reference | CC0 | https://polyhaven.com/a/epping_forest_01 |
| Poly Haven `schachen_forest`, 4k HDR | sheet 2 C; the reference | CC0 | https://polyhaven.com/a/schachen_forest |
| Poly Haven `autumn_forest_01`, 4k HDR | the reference sheet only | CC0 | https://polyhaven.com/a/autumn_forest_01 |
| Poly Haven `river_walk_1`, `forest_grove`, `snowy_forest_path_01`, `niederwihl_forest`, `snowy_forest`, 4k | looked at to choose stands, not in any sheet | CC0 | https://polyhaven.com/license |
| `dappled-leaves.png` (in the app), cut from ambientCG LeafSet010, 015, 016, 024, 027 | every grown leaf and the falling ones | CC0 | https://ambientcg.com/a/LeafSet010 (and /LeafSet015, /LeafSet016, /LeafSet024, /LeafSet027); https://docs.ambientcg.com/license/ |
| The app's `Atmosphere` (Hillaire 2020) | every sky | the app's code | `Sources/Atrium/WeatherSky.swift` |
| Palettes | every leaf, bark and overcast colour | the look research's own samples | `research-look.md` §2 |
