# Canopy

Lying on the forest floor, looking straight up: crowns sway against the sky with channels of light between them, stars show through the gaps at night, and the leaves turn and thin in autumn.

It was pick #3 of the "Atrium Wallpaper Ideas" page of 2026-11-14 (a review of the catalogue by the session atrium-37), in these words: "Lying on the forest floor, looking straight up. Crowns sway against the sky with channels of light between them. Stars show through the gaps at night, and the leaves turn and thin in autumn." What is real: "Live wind, Weather's sky and cloud, the real star catalogue, and your season from the date and latitude." Builds on: "Dappled Light's scanned leaves, Weather's sky and Live Sky's stars, in the looking-up view that worked for Kelp Forest. It could use A Tree for the Year's bark and branches." Risk, medium: "Dark leaves on a bright sky are high contrast, so the daytime look needs softening." Dave ran `/new-wallpaper` on it on 2026-11-16.

- **Research:** [canopy/research-method.md](canopy/research-method.md) (camera, numbers, three ways to draw the crowns, measured cost) and [canopy/research-look.md](canopy/research-look.md) (references, palettes, brightness, CC0 assets, the name).
- **Scripts:** `docs/canopy/mock.swift` (SKRenderer, the app's `Atmosphere` through a zenith camera), `variants.py`, `sheet.py`; [canopy/mockups-round1.md](canopy/mockups-round1.md) has every tile's measurements, assets and licences, and how to redraw a round.
- **Where it stands (2026-11-16):** step (a), the still picture, and the first part of step (d), the night and the light kept current (d1), built and hidden behind `unfinished` (`Sources/Atrium/Canopy.swift`); steps (b), (c), the rest of (d) and (e) to come.

## What the idea's author meant (atrium-37, 2026-11-16)
Asked on Dave's word, the session that wrote the ideas page said:
- **The view:** a ring of crowns closing in from the screen's edges, with channels of sky between them (as crown shyness leaves), not one tree overhead: one tree as the subject is what sank A Tree for the Year. Sky about a quarter to a third of the screen by day, more in winter as the broadleaves thin. A birch or aspen grove gives the classic shot of pale trunks running in from the edges toward the zenith; evergreens stay as dark masses at the rim, so winter keeps a frame.
- **The leaves backlit and translucent:** looking up at a sunlit crown, leaves glow yellow-green by the light through them, shade leaves deeper green, and only those against bright sky near the Sun go dark. From Dappled Light, only the leaf shapes (the maple, oak and beech atlas) and its clumps carry over; its shading is shadows on a wall.
- **Not A Tree for the Year's code** (cut in ed079db, so at `ed079db^`): its leaves read as paper cards beside photos, and would here. Reuse `Phenology` (still in the app) for the seasons. Photos over procedural: trunks as bark scans on tapered, foreshortened columns, crowns as cut-outs of openly licensed looking-up photos swayed by displacement (licences unchecked).
- **Softening the day**, most effective first: the light through the leaves, so they glow rather than go black; small gaps of sky held to the deep blue of the zenith; a soft veiling glow where sky meets leaf; the Sun behind a crown by default. Held to brightness caps from the start, not an overcast default.
- **From Kelp Forest's doc:** its looking-up view came out too bright (median 192) and took an exposure of 0.42, which greyed its window; it was its costliest view; a uniform set marks every sprite using the shader (set them only when they change); per-sprite shader attributes crashed the lock screen's still (ride data in the sprite's colour); pose nothing off the screen; drawn blades read drawn up close, so photo cards for anything near; foliage came out paler than the light behind it until darkened; a branch snapped in across the view looking up (fixed in b805c6a), so watch near crowns entering the frame.

## Dave's decisions (2026-11-16, before research)
- **Its own wallpaper**, not a "Looking up" view in Dappled Light or a foreground on Weather. It borrows their code (Dappled Light's leaf scans, Weather's sky, Night Sky's stars), not a place in their Settings.
- **Forests:** broadleaf (maple, oak, beech, as Dappled Light's leaf scans already are) and a birch or aspen grove. Not redwood or pine as a forest of its own, and not tropical crown shyness.
- **Winter:** the real season from the date and latitude, with a few evergreens in the ring of crowns so it is never all bare: the broadleaf crowns go to lacy bare branches, with snow on them when it snows where you are, and a Season setting holds one season. Not strictly bare all winter, and not spring-to-autumn only. (A Tree for the Year was cut partly for being bare or brown five months of the year.)
- **What moves besides the sway:** falling leaves in autumn, more in a gust of the real wind. Not chosen: rain and snow falling toward the viewer, the Moon through the gaps, birds now and then.

## Dave's decisions (2026-11-16, round 1)
- **"A/C/F look the best, build from there."** Read as sheet 1's tiles, the deciding sheet: C and F, a real bare stand with scanned leaves grown on its twigs (the method recommended), and A, the real photo's crowns in summer, as the look its summer aims at: denser and darker, each leaf lit by its own light, no haze. Not B/E (trees laid out by code) and not D ((a) dissolved into autumn). Building started on his word, with no second round of mock-ups.
- **Still his to decide**, defaulted to the recommendations until he says otherwise: the view, sheet 2's C (an evergreen rim with broadleaves inside, Poly Haven's Schachen Forest); the day's light, sheet 3's C (leaves glowing, gaps veiled pale at the leaves) with D's Sun behind a crown at summer middays; and whether real photo crowns (A) should also be a pick for summer, once he has seen the grown leaves in the build.

## Mock-ups, round 1 (2026-11-16)
Drawn by `mock.swift` with SKRenderer at 3024 × 1964, 42°N, the sky from the app's `Atmosphere`, each tile's cost and brightness printed on it. Every tile is 0.42–0.57 ms of GPU and 0.33–0.43 of CPU; every tile meets the 99th and 99.9th percentile caps, where the real photos clip at 255.

1. **How the crowns are made** ([sheet1-make.jpg](canopy/sheet1-make.jpg), with the real photos as a camera sees them in [sheet1-reference.jpg](canopy/sheet1-reference.jpg)). A/D (a) a real looking-up photo's crowns cut out (Epping Forest), summer and late autumn; B/E (b) trees laid out by code with scanned leaves; C/F (c) a real bare beech stand (Poly Haven's Autumn Forest 04) with scanned leaves grown on its twigs. **Recommended: C/F (c).** Its wood reads real and its autumn thins to its own limbs. (a) can't: D is a pepper of holes with sky behind every fallen leaf, and a bare winter needs another stand. (b) reads drawn, spiky stars of straight limbs, as A Tree for the Year did.
2. **Where you lie** ([sheet2-view.jpg](canopy/sheet2-view.jpg)), all in (c): A a ring of crowns round a channel, 90° lens; B ultra-wide 110° with aspen leaves (on beech wood painted grey: no CC0 or public-domain bare birch or aspen stand photographed straight up was found); C an evergreen rim with broadleaves inside (Poly Haven's Schachen Forest, real conifers with bare broadleaves); D a forest edge; E closed canopy. **Recommended: C,** the most sky and depth, and the evergreens keep a frame in winter as Dave asked.
3. **Softening the day** ([sheet3-light.jpg](canopy/sheet3-light.jpg)), summer: A a camera's exposure scaled to the caps; B leaves glowing with deep zenith-blue gaps; C the same with the gaps veiled pale at the leaves; D the Sun behind a crown with its halo; E overcast silver; F golden hour. **Recommended: C,** with D's Sun at summer middays. E reads the most natural of the six, and would come with the live weather anyway.
4. **At the app's scale** ([sheet4-desk.jpg](canopy/sheet4-desk.jpg), [sheet4-desk-autumn.jpg](canopy/sheet4-desk-autumn.jpg)) and **a film** ([film1-autumn.mp4](canopy/film1-autumn.mp4), 12 s, late autumn in a 4 m/s breeze).

**What the mock-ups showed.** The real stand carries the picture; the leaves don't yet. Flat, evenly lit sprays from Dappled Light's 16-leaf atlas read as cut-outs pasted on the wood, and the contrast squeezed toward the sky (a power of 0.6) lays a blue haze over everything, so at desktop size summer reads as a faded photo; autumn, mostly wood, reads better. The real photos look better than any tile. Falling leaves at the real rate and size (4–12 px, the canopy's own bronze) are all but invisible in the film, and the sway, 6 px, is barely seen. Hard edges come to 17–59% of pixels on every tile and on the photos (the cap was 3%), so that cap is wrong for a canopy, not the tiles. The sky share is lower than the brief's quarter to a third (13% for the ring) because the photo's haze of fine twigs counts as cover. The bake took 0.6–0.9 s on the CPU; the probe's 0.2 s was on the GPU.

**For round 2, whatever is picked:** leaves lit one by one, with the scans' translucency, in bigger clumps that glow; less haze; honest wood for the birch or aspen grove (a CC BY or BY-SA photo, or a CC0 one still to be found); the year in one stand and the night; a film where the falling leaves can be judged.

## How it works (the plan, 2026-11-16)
One scene, `Canopy.swift`, three layers, the build in steps each a commit, hidden behind `unfinished: true` until Dave says otherwise.
- **The camera:** a pinhole at the zenith, 90° across the screen's long side, head to the north (research-method.md §1), so straight things stay straight and every trunk runs to the middle.
- **The sky:** the app's `Atmosphere` (WeatherSky.swift) through a new zenith camera, baked off the main thread about once a minute (about 20 ms) for the real Sun at the user's place, held to the look report's caps (gaps 150–190, never white). Clouds from Weather's procedural deck later; stars (the Yale catalogue in `stars.txt`, as sprites under the canopy) at night.
- **The wood:** a real bare stand photographed straight up, keyed from its sky and shipped as an image with alpha in `Resources/canopy-*` (Poly Haven, CC0): Schachen Forest first (conifers at the rim, bare broadleaves inside), Autumn Forest 04 as a second. Turned and mirrored at random each load, so one photo gives many groves. Its bark relit to the canopy's shade; its conifers dark all year.
- **The leaves:** sprays of scanned leaves (ambientCG, CC0; Dappled Light's atlas to start) grown on the stand's thin twigs at load, two or three depth layers, each spray with an id. Baked off the main thread (the mock-up took 0.6–0.9 s on the CPU), the sky showing first and the canopy fading in. Lit leaf by leaf by the light through them from above (the layers over each read toward the Sun), aimed at sheet 1's A: denser, darker, real variation, no haze.
- **The season:** each spray's id against its species' calendar (`Phenology`, with each species' offsets from Harvard Forest's HF003, CC0), so leaf-out, colour, fall, bare lace and snow on the branches are one continuous change. A Season setting holds one.
- **Motion:** each tree sways as a body about its own base (a tree-id map flooded from each trunk along the wood), 0.15–0.3 Hz, its amplitude from the live wind and gusts; falling leaves as a few sprites. `BatteryPaced`, 12–15 fps calm.

**Steps:**
- **(a) The still:** the entry (hidden), the sky, the wood, the leaves at the real date, the preview still. Judged against sheet 1's A and the real photos at the caps.
- **(b) Motion:** sway by tree, flutter, falling leaves, the battery rate.
- **(c) Settings:** Season (follow the date, or hold one), Sway, Speed, a time and date preview to pin a picture; Light and Dark Mode (blue hour).
- **(d) Live data:** the live wind and gusts, the weather (cloud deck, overcast), snow on the branches, night and its stars. **(d1), built first:** the night and its stars, and the light kept current while it runs.
- **(e) The birch or aspen grove,** once honest wood for it is found.

## The build so far

### (a) The still (2026-11-16)
![Midsummer, 15 July at 3:30 pm, 42°N](canopy/build-a-summer.jpg)

**What was built.** `Canopy.swift` (the scene, its sky and the season) and `Sources/CanopyBake/` (the bake), its entry (hidden, `unfinished: true`), the stand `Resources/canopy-schachen.heic` with `canopy-credits.tsv` and a line in About, and `Resources/preview-canopy.jpg`.
- **The sky:** the app's `Atmosphere` marched through the zenith camera (90° across the long side, head to the north, screen right west) for the real Sun at `Location`'s place and the hour, 128 × 96, as Weather bakes its own. The exposure holds the zenith's brightest channel at 0.62 before Weather's tone curve, about 175 of 255; by night Weather's partial auto-exposure takes over and lets it go dark (no stars yet). The Sun, when it is in frame, is a soft disc where the canopy is open and a glow, no starburst.
- **The wood:** Schachen Forest's 16K HDRI (417 MB, deleted after) straight up through the same lens by `docs/canopy/stand.swift`, at 1512 px to a unit of tan (a 14" MacBook Pro's 2x), spanning tan ±1.1 by ±0.75 so a 16:10 screen has 5% each side to sway into: 3326 × 2268. Its sky is keyed out against the sky right behind each pixel (the luminance closed over 13 px, or where that is dark the brightest of each 48 px block), so sub-pixel twigs come out as part cover; the blue between its clouds, as dark as a quarter of the clouds round it, is kept as sky by its colour. Only the wood's brightness is kept, grey over alpha. It is mirrored either way or both by the seed each load, and turned a quarter for a portrait screen.
- **The leaves:** 10,000 sprays a layer in three layers (62, 50 and 40 px sprays, nearest first), each of 9-13 leaves from `dappled-leaves.png`, grown in clumps where the stand is a haze of fine twigs (none on trunks, limbs or the conifers' masses), thinned by a patchy noise so sky shows through the crowns. **Each leaf** carries its own value and tilt, and each spray marks where two of its leaves overlap.
- **The light, leaf by leaf:** each leaf passes 8.5% of the light reaching it: the Sun's beam through the leaves of the layers above it (read along the Sun's direction, the layers about 3 m apart some 18 m up), then through the crown over them all (the canopy's cover, blurred at an eighth the size), the brightest where the leaf is square to the Sun; light already through other leaves, in the shade palette's deep olive (#3C521A); and the sky's, through the crown overhead. Overlaps pass half. Sun flecks come and go by a patchy noise at about 60 px. The wood is relit as dark bark (#2A2219) by the sky through the crown, and sits in front of all but the lowest layer of leaves, so limbs cross the crowns.
- **The season:** white oak's calendar (`Phenology`) moved to the latitude, from the real date: the share of leaves out and their size in spring, how pale they still are, and the shares turned and down in autumn. One order, each leaf's own value and its patch's, runs through all of it, so the leaves that come out first and turn first fall first. Turned leaves take Beech bronze's hues with a little sugar maple. Winter is the bare stand.
- **Pins** for pictures: `canopy.seed` (a whole number; unset or 0 for a new one each load), `canopy.date` (`yyyy-MM-dd`) and `canopy.hour` (the local clock, 15.5 for half past three).
- **Load:** the scene shows its sky at once and bakes the canopy off the main thread (`CanopyBake`, a target of its own built with -O, so a debug build isn't 40 times slower at it), which fades in over 1.2 s when it lands. The render tests have no view, so the scene waits for the bake on its first frame there, as Ant Colony and Meander do (`Landing.take(waiting: view == nil)`).
- **`batteryRate` 10:** nothing moves until step (b).

**As built**, differences from the plan:
- **As built:** the leaves are lit in the bake, not per frame in the shader as the mock-ups were: every leaf's light and the wood's are composited into one texture, which the shader lays over the sky. The frame is cheaper, and the light is fixed until the next bake.
- **As built:** the sky is baked once, with the scene, on the main thread, and neither it nor the canopy's light is refreshed while it runs: the app rebuilds it after 12 hours or as the displays sleep. A rebake every few minutes, with the same seed, is the plan's once a minute and comes with step (b) (`ponytail:` in `Canopy.init`). *Since (d1), every five minutes, below.*
- **As built:** the stand is decoded straight into the bake (`CGImageSource`, off the main thread), not through `sharedTexture`: the shader never reads the photo, only the canopy lit from it, which is the scene's own (its seed and light), so there is nothing to share between copies.
- **As built:** the stand is only mirrored (four ways), not turned at any angle, since the picture is a rectangle just larger than the screen.
- **As built:** no contrast power (the round's 0.6 on luminance, which laid the blue haze over everything) and no soft focus. The leaves' own light carries the picture to the caps.

**Measured** (M3 Max, 1512 × 982 at 2x):
- **Cost:** 0.38–0.46 ms of CPU and 0.12–0.30 ms of GPU a frame at 2x, by the render test's print over six pictures (midsummer, noon, spring, late autumn, night, today), against the budget of 2 and 2. The CPU is SpriteKit's own floor for one sprite; the frame is one full-screen shader reading three textures.
- **Load:** the main thread holds for 6 ms the first time and 3 ms after (the camera, the sky's 128 × 96 rays and the shader; `Atmosphere`'s tables, about 50 ms, are made once for any scene that uses them first). The bake off it takes 0.79 s in release (`CANOPY_LOAD=1 swift test -c release -Xswiftc -enable-testing --filter canopy`), the mock-ups' 0.6–0.9 s; the textures made as it lands, a 30 MB copy, weren't timed apart. The `CanopyBake` target is built with -O, as Meander's and Ant Colony's are, so a debug `swift test` bakes it in about a second too.
- **Brightness** at desktop size, the brightest of R, G and B (caps: median 90–140, 99th ≤ 210, 99.9th ≤ 230, the Sun's core ≤ 240), seed 3 at 42°N 88°W:

| Picture | Median | 99th | 99.9th | Max |
|---|---|---|---|---|
| Midsummer, 15 July 3:30 pm (the picture above, the preview still) | 101 | 199 | 202 | 204 |
| Midsummer noon, 1 pm (the Sun 69° up, its glow in at the foot of the frame) | 90 | 180 | 182 | 195 |
| Spring, 14 May 11 am (leaves half out, small and pale) | 131 | 196 | 198 | 200 |
| Late autumn, 16 November 2 pm (bare: white oak's calendar has every leaf down by then at 42°N) | **173** | 197 | 200 | 206 |
| Night, 15 July 10:30 pm | 11 | 41 | 42 | 42 |
- **Texture memory:** 30.7 MB: the canopy, 3326 × 2268 RGBA (30.2 MB), its cover an eighth the size (0.47 MB) and the sky (49 KB). The bake holds about 175 MB while it runs (the stand, three layers of leaves and the canopy at full size), let go when it lands.
- **Shipped:** `canopy-schachen.heic`, 4.5 MB (Adrian Kubasa, Poly Haven, CC0), and `preview-canopy.jpg`, 206 KB; the leaves are the app's own `dappled-leaves.png` (ambientCG, CC0). The stand's 16K source gives 45 px a degree against the 26 a 14" screen needs at its middle and 53 radially at its edges, so it is a little soft only at the far edges.

**What still looks wrong:**
- **Better than the round's tiles, short of sheet 1's A.** Close to, each leaf is a leaf, lit by its own light, darker where two overlap and greener in the crown's shade, with flecks of sun on whole clumps, and no haze. At desktop size the crowns are still fairly even masses: too little sky shows inside them, and the brightest leaves are one yellow-green.
- **The stand's own shape.** Schachen's middle is open sky, about 45% of the screen against the brief's quarter to a third, so the ring is crowns top and bottom, not round; and where the photo's twigs end in a line, the crowns end in one too (the bottom edge at midsummer reads a little like a hedge). Leaves also grow on the conifers' part-covered edges.
- **Bare is mostly sky,** so late autumn's median (173) misses the cap of 140. Holding the sky lower when the leaves are down would meet it, at the cost of the gaps' 150–190: Dave's call.
- **The conifers** are the bark's dark grey-brown with sky specks through them, not black-green.
- **Faint specks** of the photo's clouds are left in the open sky by the key, a few pixels each. *Dropped since (step (b)).*
- **Not yet:** the light refreshing as the day goes on, Light and Dark Mode (the night is a plain deep blue, no stars), the per-species calendar, snow. *(d1) brought the first two halves: the light kept current and the night's stars.*

### (d1) The night, and the light kept current (2026-11-16)
![16 November at 10:30 pm, 42°N 88°W: the Milky Way from Cygnus to Perseus, the Andromeda Galaxy right of the middle and the Pleiades low left, through the bare stand](canopy/build-d1-night.jpg)

Night was a black stand on a grey-blue sky with nothing in it (step (a): median 12, the gaps (24, 28, 40)), which breaks Dave's "Always something to see"; and the light was baked once, so a scene made in the afternoon kept its daylight into the night.

**What was built** (`Canopy.swift`; `CanopyBake` is unchanged):
- **The stars through the gaps,** at the real place and time: the Yale catalogue (`stars.txt`) to V 5.3 and Night Sky's HYG file (`blackhole-stars.lzfse`) from there to V 7, as Night Sky splits them, 14,500 stars, about 1,800 of them in the view at once. They are drawn by the shader, not as sprites (**As built**, below), from a grid (`Canopy.starGrid`, 720 × 360, 1 MB, shared by every copy as `canopy-stars`): a row every half degree in the frame of Night Sky's fainter stars, each with as many cells as keep them at least half a degree wide, one star to a cell. A pixel looks in the two cells nearest it in each of the two rows nearest it, so a star has a quarter of a degree (3.3 points at the middle of a 14" screen) to shine in, and each is drawn round on the screen where its own direction lands through the lens: a bell 0.45–1 point in radius by its magnitude, a faint halo on those brighter than V 3.5, tinted by its B−V as Night Sky's are, at most 190 of 255 (the look report's cap for stars). They twinkle as Weather's do, ±20% at 0.16–0.64 Hz on `u_now` wrapped hourly, which stays calm. The sky turns under them once a second (`u_toStars`, a twelfth of a pixel a second at the zenith at 42°N).
- **The Milky Way:** Night Sky's photograph (`sky-milky-way.heic`, ESO/S. Brunier, CC BY 4.0; its line in About now names Canopy too), turned by Night Sky's fitted `toPhoto`, through its film shoulder at half Night Sky's strength. It is the least of four reads 2.5 texels round each pixel, which takes out the few bright stars the photograph keeps: drawn a tenth of a degree from ours they read as tails. From 42°N it crosses the zenith on autumn evenings (above) and lies along the east on July evenings.
- **The night sky's colour:** the floor of airglow under the sky is now deep blue, (0.06, 0.25, 1.3) × 5e-8 where it was (0.6, 0.8, 1.6), so a moonless night's gaps are #081026, inside the look report's #050B1A–#0A1530, where they were a grey (24, 28, 40). It only shows with the Sun more than about 12° down.
- **Fading in:** the stars and the Milky Way come in with the Sun from 4° to 14.5° down, as Weather's stars do (`Light.starlight`), and the day's veil (the gaps paled toward silver at the leaves) goes out as they come.
- **The light kept current:** every five minutes by the moment shown (the wall clock, or the pinned date at the clock's hour), the scene bakes the sky, the canopy and its light again off the main thread (`Canopy.bake`, the same seed, so the same stand and leaves; the season too, from the date), into a second picture behind the first, and fades it in over 8 seconds (1.2 for the first, or for one more than 15 minutes behind after the view was covered). Two sprites, each with its own shader and textures, the one in front at alpha 1; the night's textures and the stars' turn are shared by both. In the dark of night (the Sun 18° down at the last bake and now) nothing but the stars changes, so it doesn't bake. With `canopy.hour` pinned the moment never moves, so a picture stays put.
- **Off the main thread:** the bake makes its textures too, and at dusk the night's: the stars' grid and the Milky Way (160 ms to decode its 6000 × 3000), handed over to Night Sky's shared copy if one is up. By day they are let go.
- **Two shaders:** by day the step (a) shader alone, so the day doesn't pay for the night; from the Sun 4° down, the same with the Milky Way and the stars. The Sun's place and light are uniforms now, not written into the source, so one shader serves every bake.
- **`batteryRate` stays 10:** the stars move a twelfth of a pixel a second, the twinkle is under 0.7 Hz and the fades last seconds.

**As built**, differences from the plan:
- **As built:** the stars are drawn in the canopy's own shader from a grid, as Night Sky draws its fainter ones, not as ~350 sprites between the sky and the canopy (research-method.md §1). The sky, the leaves and the tone curve are one shader, and a layer of sprites between would have meant splitting it, which changes the day's picture (the tone curve applies to the composite); and sprites wouldn't move with the sway of step (b), where stars in the shader are covered by whatever covers them.
- **As built:** no rim of sky glow on the crowns' edges. Tried two ways: lit by the blurred cover map, it laid a soft haze over the crowns' edges that put them out of focus; by four reads of the canopy round each pixel, it drew a crosshatch. Crisp black crowns against the #081026 sky read best, so the shapes read by the sky alone.
- **As built:** the sky is baked with the canopy every five minutes, not alone once a minute: in five minutes the Sun moves just over a degree, and a crossfade of 8 seconds hides the step.
- **As built:** every bake grows the whole canopy again, not only its light (`ponytail:` in `Canopy.bake`).

**Measured** (M3 Max, 1512 × 982 at 2x, seed 3 at 42°N 88°W):
- **Cost:** by day as step (a), 0.17–0.33 ms of GPU and 0.37–0.51 of CPU a frame (several runs; the GPU reads noisily here, once 0.65 throughout a run of day and night pictures alike). From the Sun 4° down, 0.65–0.66 ms of GPU and 0.45–0.54 of CPU, against Night Sky's 0.58 measured the same evening; while a new bake fades in, both pictures draw, for 8 seconds every five minutes.
- **Stars:** `canopyNightHasStars` counts 326 in the open sky at 11 pm on 15 September (leaves on), none under the leaves, none at 3:30 pm or noon.
- **Re-bakes** (`CANOPY_LOAD=1`): 0.77 s off the main thread, about 2.1 s of CPU across the cores; 0.9 s and 2.7 s at dusk with the night's textures (the grid is 2 ms of it, the Milky Way's decode about 160). At `.utility` priority in the app. **The main thread** on the frame a bake lands on: 8 ms for a regular one (the 30 MB canopy going up to the GPU, which SpriteKit does on first use whoever made the texture), 39 ms for the first (the second picture's first draw), 63 ms at dusk (the Milky Way's 72 MB going up) and 30 ms at dawn (letting the night's textures go); the building of the scene is 6 ms the first time and 3 after, as in step (a).
- **Memory:** at night the Milky Way (72 MB, shared with Night Sky) and the grid (1 MB) besides step (a)'s 31 MB; during a fade, two canopies.
- **Brightness** at desktop size, the brightest of R, G and B (night caps: median about 10–45, gaps #050B1A–#0A1530, stars ≤ 190):

| Picture | Median | 99th | 99.9th | Max |
|---|---|---|---|---|
| Midsummer, 15 July 3:30 pm (the same as step (a): 0.016% of pixels differ, by 1 or 2) | 102 | 199 | 202 | 217 |
| Dusk, 15 July 8:45 pm (the Sun 6° down) | 61 | 210 | 214 | 216 |
| Twilight, 15 July 9:15 pm (10° down: the stars coming in) | 54 | 167 | 171 | 173 |
| Twilight, 15 July 9:36 pm (13° down) | 30 | 76 | 78 | 148 |
| Night, 15 July 10:30 pm (leaves on, the Milky Way along the east) | 13 | 48 | 57 | 180 |
| Dusk, 16 November 5:15 pm (bare, the Sun 8° down) | 127 | 156 | 157 | 167 |
| Night, 16 November 10:30 pm (bare, the picture above) | 37 | 49 | 57 | 190 |

**What still looks wrong:**
- **Twilight is violet,** (153, 135, 188) at dusk, from the app's `Atmosphere` through the zenith lens (a-dusk in step (a) too): the real zenith in the blue hour is a deeper blue. Weather's sky has the same model; check whether it lacks the ozone that turns the twilight zenith blue before tuning it here. *Balanced to a deep blue since, below.*
- **The summer night is mostly a navy sky,** its Milky Way along the east edge until later in the night, and the faint stars are small: real at 2x, sparse at desktop size seen from across a room.
- **The conifers' part-covered masses** show the sky through them as soft, lighter patches at dusk and night (the stand's own key, as in step (a)). *Made solid since (step (b)).*
- **No Moon:** a moonlit night looks the same as a moonless one (Dave didn't choose the Moon through the gaps).

### (b) Motion, and the twilight and the matte put right (2026-11-17)

**The twilight's blue.** ![15 July 8:45 pm, the Sun 4° down](canopy/build-b-twilight.jpg)

`Atmosphere` has ozone (it is Hillaire's model), but with three wavelengths its ozone takes most from the green, so the twilight zenith went lavender at sunset and violet after: (139, 138, 173) with the Sun on the horizon, (107, 93, 151) at 6° down and (46, 40, 82) at 10°, against the look report's blue hour (#011A3E–#02396C, hues 208–228°, research-look.md §2) and the blue of every twilight photo it lists. As Murmuration does (`evenings`), a camera's white balance now follows the Sun's height (`Canopy.Light.balance`): none while the Sun is up, so the day's pictures are the same to the byte, and from the horizon to 4° down red is cut to 0.16 and green to 0.7. It is applied after the exposure is set, so only the hue changes, and to the sunlit sky and the light it gives the leaves, not to the night's floor of airglow (already #081026). The zenith now goes (139, 138, 173) at sunset, (55, 98, 173) at 4° down, (44, 78, 151) at 6° (hue 220°), (20, 36, 82) at 10° and the night's (8, 16, 38) from about 14°, as before. Medians: dusk at 8:45 pm 55 (was 61), twilight at 9:15 pm 44 (was 54); 16 November at 5:15 pm 127, as before.

**The matte put right.** ![The stand's cover in the open middle, stretched eight times so faint cover shows: as keyed (left) and as the bake now cleans it (right)](canopy/build-b-matte.jpg)

The key left a pepper of faint specks in the open sky (its clouds' edges, up to a third covered but mostly a few percent), which showed by day as dark specks over the clear sky and grew the odd stray leaf; and the evergreens' masses part-covered (85–95%), so the dusk showed through them as soft, lighter patches. Cleaned in the bake, as the stand is decoded (`CanopyBake.clean`), not in the shipped HEIC, so no new download or re-encode was needed: the wood is taken piece by piece (pixels 2% covered or more, 8-connected), and a piece is kept only if some of it is surely wood (a third covered) and it adds up to 150 pixels' worth; then inside an evergreen mass (where nearly every 4 px block round a point, over about 20 px, is 80% covered) part cover over 30% is made solid and the holes between needles are kept. 1.24 million faint pixels go (20,500 pixels' worth of cover), every twig at the crowns' edges stays (compared at full size), and about 22,000 pixels' worth is added inside the evergreens. 110–135 ms more a bake, off the main thread. The midsummer picture keeps its median (100) and caps; the stars counted in the open sky at 11 pm on 15 September went from 326 to 972, since the test counts only sky with no cover at all.

## Checking it
```sh
SNAPSHOT_SCENE="Canopy" SNAPSHOT_DEFAULTS="canopy.seed=3,canopy.date=2026-07-15,canopy.hour=15.5,latitude=42,longitude=-88" swift test -c release -Xswiftc -enable-testing --filter everySceneRenders
```
That is the picture above and the preview still (`$TMPDIR/atrium-snapshots/Canopy.png`; `sips -Z 1200 -s format jpeg -s formatOptions 70` makes the still). Leave out `canopy.date` and `canopy.hour` for now. `--filter canopy` runs its season check, the stars' rows and the night check (`canopyNightHasStars`, a scene moved from a September afternoon to 11 pm by its own re-bake); with `CANOPY_LOAD=1` it times the load, the re-bakes and their landings too.

The night (the picture above is `canopy.date=2026-11-16`, and 15 July for leaves on):
```sh
SNAPSHOT_SCENE="Canopy" SNAPSHOT_DEFAULTS="canopy.seed=3,canopy.date=2026-11-16,canopy.hour=22.5,latitude=42,longitude=-88" swift test -c release -Xswiftc -enable-testing --filter everySceneRenders
```

## Shortcuts
- `ponytail:` the canopy is at the stand's 1512 px to a unit of tan, softer on screens wider than about 1700 pt; and the bake holds about 175 MB while it runs (`CanopyBake.make`).
- `ponytail:` each bake every five minutes grows the whole canopy again when only its light has changed, about 2 s of CPU across the cores (`Canopy.bake`); keep the grown layers between bakes (about 120 MB) if that shows on the battery.
- `ponytail:` a star that shares a half-degree cell of the grid with a brighter one is dropped, a few in a hundred and nearly all faint (`Canopy.starGrid`).
- The Milky Way is Night Sky's full 6000 × 3000 photograph, 72 MB on the GPU while the stars show; a copy cut to the band of sky ever overhead would be a fraction of that.
