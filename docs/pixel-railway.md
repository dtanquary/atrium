# Pixel Railway

A model railway seen from above in pixel art: one to three trains of one era running on loops of track through open countryside, with a station and its town, a road over the line at a level crossing, a pond, trees, and a hill the line tunnels through. Where two loops cross they meet at a diamond, where one train waits for the other, or one rides over the other on a bridge. It follows the real Sun where you are, and lays snow when there's snow on the ground there. A new layout fades in every few hours, then just runs.

Dave asked for it on 2026-10-15: "a top down procedurally generate model train track and train layout, I loved playing with model trains when I was little ... in the pixel style we have been doing ... relatively simple procedural loop layouts that fill the screen and have 1-3 trains able to run along them in various well know styles, santa fe, etc". It was researched by five agents, mocked up in Python as geometry ([Mock-ups](#mock-ups)), and on seeing the sheets he said "yes to everything you are showing me, it looks awesome". It was built the same day behind the `unfinished` switch.

- **Source:** `Sources/Atrium/PixelRailway.swift` (the scene: its canvas, the clock, the weather, Settings and the fade to a new layout) and `Sources/RailLayout/`, its own module built with `-O`: `Art.swift` (materials, every vehicle as slices, the trains, and what each era puts by the line), `Season.swift` (the time of year), `Render.swift` (the view, the voxel ray march, the canvas, the scenery models), `Layout.swift` (the loops and their crossings), `Scenery.swift` (everything round the track), `Static.swift` (the picture under the trains), `Sim.swift` (the trains, signals and the road), `Railway.swift` (the whole, and drawing the moving things each frame).
- **Data:** none. Every layout is made from the clock; every vehicle and building is a few strings of slices.
- **Tests:** `Tests/AtriumTests/RailwayTests.swift` writes one layout in each era, by day, at night and in snow, to `$TMPDIR/atrium-railway/` (`RAILWAY_SEED=` picks another).
- **Pictures of it:** `docs/images/pixel-railway.jpg`.

## Dave's decisions (2026-10-15)

| Question | His pick |
|---|---|
| Name | Pixel Railway |
| View | "I am not sure on view yet, can we plan for both top down and isometric pixel and we can cut one if its not working out later": a View setting. Of the four views mocked up, 3/4 top-down and isometric on the world's axes ("true diamonds") were built; straight overhead (only roofs show, so the paint schemes vanish) and isometric in a frame turned 45° (it can't fit its long 2:1 cuts at these radii, and reads as a squashed 3/4) were dropped |
| Track | loops first, one to a train (crossing, nested or bridged); switches, sidings and signals as a second step. Asked "is there no way to make a smaller inner loop or have multiple trains on the same track that dont collide?": yes to both, so two trains may share a loop under block signals, and a short train may run on a tight inner loop |
| Scenery | all four offered: trees, grass and a pond; towns and stations; tunnels, bridges and level crossings; day and night on the real clock |
| Trains | all four offered: diesel streamliners, steam, freight with a caboose, modern and international |
| Over time | "New layout, then just runs": a new layout fades in every few hours (a setting), with no building animation |
| Names | real names, no logos; after the research on trademarks, "Settings only, disclaimer" ([Rights](#rights)) |
| Board | countryside to the edges, no board edge |
| Scale | "Medium, with a Size setting" |
| Eras | each layout keeps to one era (trains, buildings, crossings), with a checklist in Settings |
| Stations | passenger trains stop about 30 s; freight runs through |
| Seasons | follow the real season (green, autumn colours, snow lying where he is), with a preview; no falling rain or snow |
| First eras | US streamliners and US steam; the others come after |
| The mock-ups | "yes to everything you are showing me, it looks awesome" |
| Which view stays (later the same day, from sheets of three layouts in each) | "Both, top-down standard" |
| The standard view and size, that evening, after living with it | "lets default to isometric view its nicer looking, also default to small view (able to see more)" |
| The next two eras (from their sheets: transition freight 1945–57, and today's US) | "Build both as drawn" |
| Long freights, which in isometric never fit three to a layout | "Shorten to fit": a train a layout can't take at full length drops cars, down to about five |
| The N&W class A, first drawn on the Big Boy's slices | "Give it its own shape" (a 2-6-6-4, 36 + 20 px at the Big Boy's compression) |
| The international groups (from their sheets: Britain's age of steam and InterCity, Germany and the Alps, European high speed, the Shinkansen) | "Build all five", Britain first |
| The Deltic, drawn in its 1960s green beside the 1976–96 HST | "BR blue" |
| Newer trains outside the US, after the second round of rights research | "Swap for older trains": the ICE 3, Vectron, N700, E5/E6 and Amtrak ALC-42 dropped, the ICE 1, DB 103, Re 460 and P42 kept, the 200 series drawn beside the 0 series; every train kept from outside the US is 30 or more years old |
| The Shinkansen group, whose railways license their trains' likeness at any age | "Keep it, older trains only": the 0 and 200 series and JR Freight, named in Settings with no lettering, looked at again before the App Store |
| Top-down, after the international round | "lets cut the top down view entirely and go with just isometric, it will allow us to focus our effort where we get the most": isometric only, with no View setting |
| The L, T and stepped loops only top-down had | "yes, port the L and T shaped loops to isometric" |

The lead's calls, not ruled on: model-railway compression (locomotives 25–38 px, cars 16–30, three to five cars to a passenger train and eight and a caboose to the freight); Size changes the art pixel (3, 4 or 5 points on a 982-point-high screen), not the drawings; every vehicle baked at 64 headings from its slices as first drawn; the simulation stepped at a fixed 1/60 s; "Great Northern streamliner", not "Empire Builder" (an Amtrak mark); the disclaimer's wording.

## Mock-ups

`docs/pixel-railway/` doesn't hold them: they were a Python script (`railway.py` with the slices in `art.py`) in the session's scratchpad, drawing four views of one layout, each era by day, at night and in snow, every train at four headings, 8 s films of the trains running, and a car rounding a curve every 0.2 s. The Swift build is a port of that script, line for line where it could be, so the app draws the pixels the sheets showed; the geometry it was written to is in [How it works](#how-it-works). Two things the port changed on purpose: the hill is shaded as smooth ground (the mock-up's looked smooth only because its width came out even, which made the ray's steps up the hill land as tops; an odd width showed every step as a dark terrace), and the layout's random numbers come from SplitMix64 rather than Python's, so a seed gives a different layout from the mock-up's.

## How it works

**Units and the view.** One world unit is 2 ft at model-railway compression (an F7 is 25 by 5), z up. Isometric 2:1 puts a point at (x − y + W/2, (x + y)/2 + H/2 − z), the layout on the world's axes so its straights run on the screen's diagonals. Depth (larger is nearer) is x + y + z; anything flat takes the depth where its pixel's ray meets its plane, so coplanar layers never fight. A 3/4 top-down view was built beside it and cut on Dave's word; the code is in git up to 8f01628.

**Layout** (`Layout.swift`). The trains go largest radius first, each needing max(32, 1.6 × its longest vehicle). A plan is drawn first: twice-around (twice as likely), loop in a loop, or two side by side. A loop is a rectangle on the world's axes whose diamond fits the screen 12 in from its edges, or (three times in four, in a layout's first three tries) one with notches out of its corners: one makes an L, two on one side a T, two at opposite corners steps, all four a cross. A notch is at least 2R + 4 each way and leaves that much beside it, so every step can be rounded, which a train whose curves need R over about 58 never gets at the Small size (US steam's big engines). (Top-down's loops were unions of overlapping rectangles; in iso their edges nearly always came out a few units apart, too short to round, and snapped together they mostly made plain rectangles.) Then 35% of its corners are cut at 45° by 0.8–1.4 R, and every corner is rounded by the largest arc up to 1.15 R that fits; it's thrown away if any curve is under 0.98 R or the loop is shorter than 2.2 trains. A twice-around's second loop is built across one of the first's straights at right angles. A long freight that a loop is too short for drops cars, keeping its locomotives and caboose, down to five; it is offered a shorter loop only after half the tries at full length, so trains run long where there's room. Wherever two loops come within 14 units they must cross cleanly, at 40° or more and straight for 12 either side. Of a pair that cross twice, one crossing becomes a bridge, the upper loop ramping up 1:6 to a deck 7 high. Diamonds closer than the longest train and 40 along any loop are reserved together. A train that gets no loop of its own runs on the longest one with room behind another, if blocks can be laid on it that the two can never hold all of ([Layout.planBlocks](../Sources/RailLayout/Layout.swift): the fewest, four or more and more than the trains, each train spanning at most its length over the shortest block and one more, and reserving one ahead), so they never lock, with no block beginning from 40 before a diamond to a train-length past it.

**Fitting everything** (`Railway.swift`). A layout often can't place every train, or a station. So each is grown from up to nine seeds drawn from the period's, every third with a short train in place of the third big one (it takes the tightest curve, 32, and prefers a loop inside another: a rectangle 2R + 4 to 4R a side, every point of its edge inside the bigger loop and at least 22 from its track), and the first with every train and a station is kept, else the first with most, a station and its town counting as much as a train (a layout without its town looks bare). Only the first three may have notched loops: a notched loop takes room a long freight needs, and with them in all six tries three trains fitted on only 14 of 20 transition layouts. Over 20 periods on Dave's laptop canvas at the Small size (504 by 328 art pixels): three trains on 17 to 20 in every era (today's US 17, transition 19, steam 19), a station on 18 to 20, and an L, T, steps or cross in 11 or 12 of the British and German layouts, 3 to 6 of the US ones and none of US steam's. (At the Medium size it was 9 to 11 of 20 with three trains, and 3 or 4 with the long freights.)

**Scenery** (`Scenery.swift`), all from the seed. The station goes on the clearest straight of 76 units or more, passenger loops first: a platform 4 wide, 4–8 off the centreline; for steam a Southern Pacific style wooden depot and a water tank, for streamliners a brick station with a canopy over 60% of the platform. The main road crosses the track at right angles just past the platform's far end, so a train standing at the platform never blocks it, with crossbucks and a wigwag (steam) or flasher masts and short gates (streamliners), and a pole line. The main road is 7 wide with a gravel shoulder. Off it the town is a small grid of streets 5 wide with kerbs: parallel to the track at 22 and 50 either side (the 50s only beyond a 22), each running up to 70 each way while there's room, joined by cross streets at 34 and 66 along, with up to 28 gabled houses along them. A pond takes the largest clear disc, inside a loop if it can; a hill with a cutting, a stone headwall and a dark bore sits on a long curve; about 230 trees are thrown as darts, thicker in clumps, more conifers for steam. A broadleaf is a dark trunk (#3E3630) forking into three or four branches up to a light, ragged crown of fine twigs (#948A80), which is what shows when it's bare, with whatever leaves are out on the day laid over it. Signals: one past the platform on a lone train's loop, a home signal at each diamond, and on a loop two trains share one at each block's entrance, never from a diamond's approach to a train-length past it, and where it can be helped not where a train held at it would stand on the road, at the platform or in the tunnel. A long train on a short loop needs 9 to 17 blocks, most of whose signals would only ever show clear, so the trains are run for ten minutes as the layout is built and only the signals one of them stops at are drawn, with the starting signal past the platform: two or three to a loop. Trains at different speeds close up at different places, but over two hours on 35 layouts with a shared loop no train was ever held at a signal not drawn (a test, `railwayDrawsEverySignalATrainWaitsAt`, runs an hour of 15 of them). Semaphores for steam, searchlights for streamliners. A station where a standing train would hold a diamond gets no stop.

**Eras** (`Art.swift`'s `EraLook`). Each layout keeps to one era. Steam: cinders, a wooden depot and water tank, a wigwag, semaphores, incandescent lamps, more conifers. Streamliners: granite, a brick station with a canopy, flashers and short gates, searchlights, mercury lamps. Transition freight, 1945–57: trap rock, a freight house and timber dock where the New York Central's way freight stops (every other train is a freight), flashers and gates, searchlights, a stake-bed truck on the road, and where there's room a concrete coaling tower with a water tank, a grain elevator, and an interlocking tower beside a diamond. Today: granite and pale concrete ties, a low platform with a glass shelter, longer gate arms with three red lamps over concrete crossing panels, colour-light signals, LED lamps, no pole line, concrete silos, and cars mostly white. Britain, both eras: a small brick station with a slate hip and a canopy whose valance is in the GWR's light stone, a signal box by the level crossing, hedgerows round fields of 40 to 64 (about a third of their edges left open, a tree in some, fewer trees elsewhere), brick, stone and thatch, low-pressure sodium lamps, small cars (an Austin 7 or Morris Minor; a 1970s or 80s saloon). In the age of steam, white timber gates with a red disc that swing across the road while a train comes, and semaphores with a distant signal 36 before each stop signal drawn, its yellow arm at caution while that one is at danger; in the InterCity era, automatic half barriers with a steady amber and then two reds flashing in turn, and colour lights. Germany and the Alps: the TEE Rheingold behind a DB 103, a V 200 and a class 01 with green coaches, and an SBB Crocodile with goods wagons; a rendered station with a steep hipped tile roof, half barriers under a red and white St Andrew's cross with one lamp over it (yellow, then a steady red), colour lights, mercury lamps, no pole line, more conifers, and overhead wire. The wire is a mast every 70 along each loop, 4.5 off the track on the side away from the platform, leaving out the hill, the roads, other loops and 14 either side of a bridge, and a contact wire 8.3 over the rail head (just over a raised pantograph) drawn at 42% over the trains, a point every half unit, left out in the tunnel and under a bridge's deck. The international trains' slices were written out from the mock-up's `art.py` into `ArtWorld.swift` by a script, so they match it row for row; there are more than 255 materials now, so voxels hold 16-bit indices. Tall buildings are squashed to fit (a real coaling tower or elevator stands 100 ft, 50 px), and stand on the side of the track further up the screen so they don't hide it.

**Seasons** (`Season.swift`). The scene works out the time of year where you are from A Tree for the Year's calendar (`Phenology`: a white oak's dates at 42°N, spring 4 days later and autumn 3 days sooner a degree further from the equator, latitude held to 28–50°, half a year on south of the equator) and its grass greenness, a whole day at a time, and passes it in. The grass runs from straw (#9A8C5E) to summer green (#5A9636) with the greenness, through autumn's olive (#7E8A44); the pond, conifers, hill and banks have their own colours each season. Every leaf turns, browns and falls on its own day, the tops and some trees first, in wine, orange or yellow by tree; new leaves are lime; a quarter of the oaks hold a few buff leaves through winter. Snow lies when the weather says a centimetre or more does (or while previewing it), over whatever the season is.

**Drawing.** Everything that stands up, trains and houses and the hill alike, is a box of voxels drawn by marching each sprite pixel's view ray down through it, top first: the first filled cell shows, and which of its indices changed from the step before says whether it's a top, a side or an end. Faces are shaded by the Sun from the left, (−0.30, 0.60, 0.74). Shadows are every voxel dropped along the Sun's rays onto the ground, and fall on the ground only. Within a pixel the track's nearest surface wins and on it the rail over the tie over the bed, so the rails show on a ramp; the bank under a ramp is one smooth heightfield just under the track, sloping 1:1 at the sides and shaded flat. The picture under the trains (`Static.swift`) is drawn once a layout, by day and by night, with each pixel's depth: by day with shadows, by night with the colours multiplied by (0.25, 0.26, 0.36) and lifted by (18, 15, 34), windows lit, and pools of lamplight in three rings. Each frame (`Railway.swift`) copies the mix of the two for how dark it is now, adds the headlights' cones on the ground at night, and draws each vehicle at the nearest of 64 headings (and its ramp's slope) against the depths, so tunnels, bridges and trees need no special cases. A vehicle's sprite is baked the first time it's needed and kept, coloured both ways, with four rays a pixel: a pixel shows what most of them hit, and on a tie the thing rarer in the whole sprite, so a stripe one voxel high holds together. Measured on four cars at 32 headings, that shows 20–100% more of their stripes and changes them 10–35% less, for their size, from one heading to the next. The canvas goes up to a `SKMutableTexture` drawn with nearest filtering.

**Running** (`Sim.swift`), in fixed steps of 1/60 s. Trains cruise at 13–18 px/s and brake and pull away at 8 px/s². Each sits on two bogies at ±0.375 of its length (±0.35 for steam engines). A train asks for a diamond when its front is within braking distance and 6 of it, stops 4 short if it's held, and lets it go once its tail is clear. Where diamonds share a reservation, the stretches a loop's train needs it for can join up all the way round that loop, so it never lets go and the other loop's train waits for ever: the mock-up agent found one at the Small size, and a search of 480 layouts found six. Such a layout is passed over (`Layout.starves`); the search then found none. On a loop with blocks it enters one only when no other train holds it. The mock-ups found two deadlocks before blocks were kept clear of the diamonds (a train held at a block signal with its tail on a diamond the other loop's train waited for, and a train needing a block to clear a diamond that the train behind it held); with no block beginning near a diamond neither can happen. Passenger trains stop at the platform for 30 s, standing in their blocks; freight (the Big Boy, the GP9 local, the switcher) runs through. The car on the road stops 10.5 short of the crossing while a train is within 40 or over it.

**The clock.** A layout is the period of New Layout Every since 1970, so every display and Settings' copy agree; its era is picked from the ticked ones by the period's number, and its trains from the era. A new period, a new day (the leaves), a setting that changes the layout, or snow arriving or melting builds the next layout off the main thread and fades to it over 2 s. How dark it is follows the Sun's height where you are, from 4° above the horizon to 8° below, checked every 30 s. The season takes your latitude to the nearest degree: location fixes come back a few metres apart, and at full precision each new scene's fix moved the oak's dates by a fraction of a day, which counted as a new season and rebuilt the scene, over and over (Dave saw the isometric view rebuild every few seconds until macOS began handing back the same fix).

## Rights

The trains are drawn after real railroads' paint schemes, with no heralds, numbers or lettering. Their names appear only in Settings, under which the page says: "Names say which real train each is drawn after. Atrium isn't affiliated with or endorsed by any railroad." The longer disclaimer, for About and NOTICE: "Pixel Railway's trains are drawn after the paint schemes of real railroads, without their logos or lettering. Railroad and train names, and train designs, such as Santa Fe, Union Pacific, BNSF, Amtrak, ICE, TGV and Shinkansen, are trademarks or designs of their owners, used only to say which train a picture shows. Atrium isn't affiliated with, sponsored by or endorsed by any of them." The README, the site and the App Store say "paint schemes of real railroads", with no railroad names in headings, keywords or captions. If an App Store reviewer objects under guideline 5.2.1, that build uses descriptive names.

Why (the research, not legal advice): Union Pacific sued model makers in 2004 over its marks; UP and Amtrak hold registrations for model trains; BNSF owns the Santa Fe, Great Northern and Burlington names and in 2023 made an airline drop the Northern Pacific name; Santa Fe's Warbonnet (Reg. 2000826) and UP's colours (Reg. 2148551) are registered for rail services only. The research reads a plain name that says which train a picture shows as US nominative fair use, which a logo or lettering would not be; no railroad's terms ask for a licence just to name one. Not checked then: the British, European and Japanese registers, and designs on recent train shapes.

A second round looked at the trains outside the US. A registered design on a train's shape can reach a picture of it: in 2011 Germany's top court treated an ICE 3 in a trade-fair catalogue as use of Deutsche Bahn's design (DB asked €750), and since May 2025 EU designs needn't be physical products. But design rights last at most 25 years (EU, UK, Germany, Japan) or 15 (US), so a train first built before about 1999 is past them; every train kept from outside the US was first built between 1919 and 1996. The ICE 3 (DB still credits its design in 2025), the Vectron (Siemens EU designs to about 2035), the E5 and E6 (Japanese designs to about 2029–33), the N700 (licensed jointly by JR Central and JR West) and the ALC-42 (CHARGER is Siemens' US mark for locomotives; Amtrak licenses its likeness) were dropped on Dave's word. Japan differs: JR Central and JR East license their trains' likeness at any age, the 0 series too, by contract and custom rather than a right in pictures, hence revisiting the Shinkansen before the App Store. No train shape or livery was found registered as a trademark (DB's grey and red was refused as an EU mark), and no action was found against a game, app or pixel picture. Names are class names where a train's own name is a mark: "LNER A3", since "Flying Scotsman" is the Science Museum Group's registered mark, licensed to Hornby and Train Sim World; "HST", not the InterCity 125 brand. The EU, UK, Japanese and WIPO registers couldn't be searched directly (scripted connections were refused), so no Japanese registration was confirmed.

## Settings

| Setting | Does |
|---|---|
| Size | Small (the standard: 3 points on a 982-point-high screen), Medium (Pixel City's pixel, 4) or Large: the art pixel, so more room for track when smaller |
| Trains | One, up to two, or up to three (the standard): two may share a loop under block signals, or the third be a short train on a tight inner loop; a train that still doesn't fit is left off |
| New layout every | Hour, 3 hours (standard), 6 hours, or Day |
| Eras | US streamliners (Santa Fe F7 warbonnet with Hi-Levels; Union Pacific E9 with an Astra Dome; Great Northern F7 streamliner; for an inner loop, a Budd RDC pair or a Union Pacific GP9 local), US steam (Union Pacific Big Boy with mixed freight and a caboose; Southern Pacific GS-4 Daylight; Milwaukee Road Hiawatha; for an inner loop, an 0-6-0 switcher with short cars), Germany and the Alps (DB 103 with the TEE Rheingold, DB V 200 and DB class 01 with green coaches, SBB Crocodile with goods wagons), Britain's age of steam (LNER A3 and A4 with teak coaches, GWR Castle with chocolate and cream, LMS Princess Coronation with crimson coaches, LMS 8F with mineral wagons), British InterCity (the HST with Mark 3 coaches, a Deltic in BR blue, a Class 47 with mineral wagons), US transition freight (Union Pacific F3 with PFE reefers; Santa Fe F7 freight; Pennsylvania GP9 with coal hoppers; New York Central F7 way freight; Norfolk and Western class A with a hopper drag) and US today (BNSF ES44AC Heritage III with double-stacks; Union Pacific SD70ACe with coal gondolas; CSX ES44AH with autoracks and tank cars; Amtrak P42 Phase V with Amfleet I); none ticked counts as all |
| Seasons | The real time of year where you are, always; snow on the ground when Open-Meteo says there's a centimetre or more where you are (the request every weather wallpaper shares) |
| Preview | A day of the year; snow; a time of day |

## Cost

0.71 ms of CPU and 0.55 of GPU a frame at 2x Retina on a 1512 × 982-point screen (the render test's debug build, the module at `-O`, 2026-10-15); a German layout, wire and all, 0.87 and 0.08. A railway takes 0.3–0.6 s to build with its retries, off the main thread for a new layout (a scene built from scratch, when it's picked or its Settings page opens, builds on the main thread). `batteryRate` is 20: the trains step whole art pixels at up to 18 a second.

## Shortcuts

- The hill's shading ignores which face a step shows: its grass is lit by slope instead.
- No leaves on the ground in autumn.
- A layout with no station (none of the 120 tested at the Small size, but it can happen) has its passenger trains run through.
- The pools of lamplight and the headlights light only the ground.

## Still open

From the mock-ups' review: stripes still thin out at some headings (better with four rays a pixel, not gone); three diamonds near each other are reserved together, so a train can wait up to 7 s for a train on another diamond; headlight pools are faint on grass; a train held behind one standing at the station waits up to 30 s. European high speed and the Shinkansen are to come, and switches and sidings after them. The long disclaimer goes into About and NOTICE when Pixel Railway is shown to everyone.

## Next ideas

- European high speed and the Shinkansen, under the same wire as Germany, with road bridges over the high-speed loops.
- Switches and sidings, after Dave has lived with loops.

## Sources

The research behind it, by the agent that found it: rail-us (American trains, paint and scale), rail-intl (the other countries' eras), rail-scenery (lineside, stations, crossings, seasons and lights), rail-names (trademarks) and rail-craft (track plans, how pixel rail games draw, turning sprites, following track). Photos sampled for colour were looked at only, never copied into the app; game code read for technique only, never pasted.

### Lineside, stations, crossings, seasons and lights (rail-scenery)
- https://legacy.njweather.org/node/276
- https://open-meteo.com/en/docs/historical-weather-api
- https://open-meteo.com/
- https://metoffice.gov.uk/learning/precipitation/snow/snow-in-the-uk
- https://mailmate.jp/blog/does-it-snow-in-japan
- https://bsbi.org/atlas/2cd4p9h.xcv
- https://globalvoices.org/2016/04/25/japan-gets-ready-to-plant-rice-during-golden-week/
- https://www.tkgje.jp/entries/22500/22734_taue.html
- https://imaginatorium.org/sano/tanbo.htm
- https://www.jonroma.net/media/signaling/railway-signaling/1951/A%20History%20of%20Flashing-Light%20Crossing%20Signals-%20What%20They%20Are%20and%20Why.pdf
- https://american-rails.com/wigwag.html
- https://american-rails.com/crossbuck.html
- https://mutcd.fhwa.dot.gov/htm/2003/part8/part8d.htm
- https://trid.trb.org/View/135657
- https://www.rtands.com/?p=55161
- https://www.law.cornell.edu/cfr/text/49/392.10
- https://en.wikipedia.org/wiki/Level_crossings_in_the_United_Kingdom
- https://der-kleine-ice.de/wp-content/uploads/Infografik_Bahnuebergang_DKICE.pdf
- https://www.gesetze-im-internet.de/ebo/__11.html
- https://ja.wikipedia.org/wiki/踏切
- https://ja.wikipedia.org/wiki/踏切警報機
- https://trafficnews.jp/post/116357
- https://japan-crc.com/en/articles/blog/rule/
- https://american-rails.com/railroad-signals.html
- https://railroadsignals.us/signals/searchlights/
- https://jonroma.net/media/signaling/railway-signaling/1937/Color%20Light%20Signals%20Replace%20Semaphores%20on%20Union%20Pacific.pdf
- https://en.wikipedia.org/wiki/UK_railway_signalling
- https://www.railsigns.uk/sect2page4.html
- https://m.ipernity.com/doc/314471/29364387
- https://www.railforums.co.uk/threads/telegraph-poles.243515/
- https://www.txdot.gov/manuals/rrd/rho/exhibit_a_and_pse_design/track_design-i1005639.html
- https://lner.info/forums/viewtopic.php?p=6288
- https://forum.trains.com/t/difference-in-types-of-ballast/205874
- https://nippon.zaidan.info/seikabutsu/1996/00501/contents/057.htm
- https://en.wikipedia.org/wiki/Coaling_tower
- https://www.hoosiervalley.org/explore/grasselli-tower/about-interlocking-towers
- https://heritage.dorsetcouncil.gov.uk/Monument/MDO47638
- https://distinctlymontana.com/montanas-grain-elevators
- https://www.wisconsinhistory.org/Records/NationalRegister/NR2521
- https://en.wikipedia.org/wiki/Wall_Lake_Depot
- https://scvhistory.com/scvhistory/lw3786.htm
- https://utahrails.net/up/UPHS-Q&A-All-2024.htm
- https://www.rmweb.co.uk/forums/topic/1944-gwr-light-dark-stone/page/2/
- https://www.iko.com/blog/the-history-of-asphalt-shingles/
- https://sas-space.sas.ac.uk/6429/1/SBT-combined1.pdf
- https://archaeologydataservice.ac.uk/catalogue/adsdata/arch-501-1/dissemination/pdf/east_midlands/HFPC_east_midlands_21-40.pdf
- https://www.newforestnpa.gov.uk/document/tile-and-slate-roofing/
- https://www.hyogo-tourism.jp/world/review/detail_221.html
- https://en.thebecos.com/blogs/column/sekishu-gawara-tiles-guide
- https://www.2020games.metro.tokyo.lg.jp/02%20Promotion%20of%20the%20removal%20of%20utility%20poles.pdf
- https://www.bobvila.com/articles/solved-why-are-barns-painted-red/
- https://en.wikipedia.org/wiki/1949_Ford
- https://en.wikipedia.org/wiki/Ford_F-Series_(first_generation
- https://www.ppg.com/autocoatings/color/history-of-color
- https://en.wikipedia.org/wiki/Ford_F-Series_(fourteenth_generation
- https://www.mychesco.com/a/news/regional/white-gray-black-still-rule-as-car-color-choices-shift-only-at-the-edges/
- https://en.wikipedia.org/wiki/Austin_7
- https://en.wikipedia.org/wiki/Morris_Minor
- https://en.wikipedia.org/wiki/Volkswagen_Golf_Mk8
- https://en.wikipedia.org/wiki/Kei_car
- https://en.wikipedia.org/wiki/Kei_truck
- https://vintagestreetlights.com/history/lps.html
- https://www.vintagestreetlights.com/bio/page2.html
- https://trid.trb.org/View/300405
- https://www.npr.org/sections/thetwo-way/2016/06/21/482936520/bright-bluish-white-led-streetlamps-bad-for-our-health-ama-says
- https://cityoftacoma.org/government/city_departments/public_works/engineering/signal_and_streetlights/streetlight_replacement_project
- http://www.vendian.org/mncharity/dir3/blackbody/UnstableURLs/bbr_color.html

### Trademarks (rail-names)
- https://www.redorbit.com/news/business/727287/up_drops_model_train_royalty_fees/
- https://www.uprr.com/aboutup/licensing/up_licensee_model.pdf
- https://ttabvue.uspto.gov/ttabvue/v?pnam=Model+Railroad+Manufacturers+Association
- https://ttabvue.uspto.gov/ttabvue/v?pno=91163638
- https://www.mthtrains.com/news/mth-electric-trains-settle-trademark-dispute
- https://www.trains.com/mrr/news-reviews/news/no-news-ok-for-bnsf-model-railroading-licensing-agreement/
- https://tsdr.uspto.gov/statusview/rn3398854
- https://www.up.com/about-us/licensing
- https://www.walthers.com/trademarks
- https://www.mylargescale.com/threads/here-we-go-again-bnsf-licensing-royalties.6927/
- https://freightwaves.com/news/bnsf-railway-compels-new-airline-to-change-name-in-trademark-dispute
- https://tsdr.uspto.gov/statusview/rn2148551
- https://tsdr.uspto.gov/statusview/rn2000826
- https://tsdr.uspto.gov/statusview/rn3697116
- https://www.worldipreview.com/trademark/model-train-company-v-ny-transport-appeal-heads-to-fourth-circuit-12730
- https://www.amtrak.com/web-notices-terms-of-use
- https://store.epicgames.com/p/train-sim-world-6--bnsf-gp60m-gp60b
- https://store.epicgames.com/p/train-sim-world-5--union-pacific-heritage-livery-collection
- https://collection.sciencemuseumgroup.org.uk/objects/co8052657/flying-scotsman-steam-locomotive
- https://uk.hornby.com/products/flying-scotsman-train-set-r1255m
- https://www.licensingsource.net/tag/flying-scotsman/
- https://www.lner.co.uk/about-us/who-runs-lner/
- https://ipkitten.blogspot.com/2011/05/deutsche-bahn-appeals-red-and-grey-to.html
- https://www.ice-treff.de/index.php?id=77439
- https://www.ippt.eu/sites/default/files/2007/IPPT20070125_ECJ_Opel.pdf
- https://www.dyoung.com/en/knowledgebank/articles/trademarks-replica-toys-german-supreme-court
- https://tsdr.uspto.gov/statusview/rn2014739
- https://www.actugaming.net/?p=19367
- https://koubo.jp/press-release/prtimes/c80758_r102
- https://bananas.openttd.org/manager/tos
- https://github.com/BRTrains/BRTrains2
- https://www.tt-wiki.net/wiki/Korean_Train_Set_by_Wankotul
- https://developer.apple.com/app-store/review/guidelines/
- https://www.courtlistener.com/opinion/587692/the-new-kids-on-the-block-a-massachusetts-general-partnership-consisting/
- https://www.finnegan.com/en/insights/blogs/incontestable/in-legal-warfare-over-humvee-trademarks-the-first-amendment-goes-beyond-the-call-of-duty-in-dismissing-am-generals-claims.html
- https://dwt.com/insights/2023/06/scotus-jack-daniels-trademark-rogers-test

### Trademarks and designs outside the US (rail-names, round 2)
- https://www.prh.fi/en/intellectualpropertyrights/mallioikeudet/for_applicants/registration_abroad/community_designs.html
- https://www.gesetze-im-internet.de/geschmmg_2004/__27.html
- https://www.legislation.gov.uk/ukpga/Geo6/12-13-14/88/section/8
- https://www.legislation.gov.uk/ukpga/1988/48/section/226
- https://www.jpo.go.jp/system/process/tesuryo/kaisei/2020_ishoryokinkaisei.html
- https://www.law.cornell.edu/uscode/text/35/173
- https://urteile-gesetze.de/rechtsprechung/i-zr-56-09
- https://www.cliffordchance.com/insights/resources/blogs/ip-insights/2025/01/unlocking-innovation-key-changes-in-the-eu-design-protection-system-reform.html
- https://www.jpaa.or.jp/en/ip-information/design-others/
- https://www.courtlistener.com/opinion/4660380/curver-luxembourg-sarl-v-home-expressions-inc/
- https://store.steampowered.com/app/3663150/
- https://en.wikipedia.org/wiki/ICE_3
- https://patents.google.com/patent/EM08119220001S/en
- https://en.wikipedia.org/wiki/Siemens_Vectron
- https://patents.google.com/patent/USD758244S1/en
- https://en.wikipedia.org/wiki/Siemens_Charger
- https://www.jpo.go.jp/system/laws/rule/guideline/trademark/binran/document/index/49_02.pdf
- https://monoist.itmedia.co.jp/mn/spv/1405/26/news057.html
- https://store.steampowered.com/app/3663180/
- https://store.steampowered.com/app/3879900/
- https://store.steampowered.com/app/3663160/
- https://nrwe.justiz.nrw.de/lgs/koeln/lg_koeln/j2009/31_O_537_08urteil20090129.html
- https://supconcours.com/actualite/marque-tgv/
- https://www.jeki.co.jp/field/property/
- https://www.jrta.co.jp/addiv/property-license-case.php
- https://www.jrta.co.jp/addiv/property-license-agreement.php
- https://digital.sbb.ch/de/foundation/brand/copyrights/
- https://www.marklin.com/products/details/article/36190

### Trains outside the US (rail-intl)
- https://de.wikipedia.org/wiki/Oberleitung
- https://en.wikipedia.org/wiki/Overhead_line
- https://www.w3schools.com/colors/colors_ral.asp
- https://www.w3schools.com/colors/colors_british.asp
- https://ja.wikipedia.org/wiki/国鉄色
- https://en.wikipedia.org/wiki/List_of_RAL_colours
- https://lner.info/article/liveries/livery.php
- https://en.wikipedia.org/wiki/British_Rail_corporate_liveries
- https://en.wikipedia.org/wiki/LNER_Class_A3_4472_Flying_Scotsman
- https://en.wikipedia.org/wiki/LNER_Class_A4_4468_Mallard
- https://www.rmweb.co.uk/forums/topic/180467-what-might-be-the-real-lner-garter-blue-answer-humbrol-enamel-no-221continues-as-the-paint-job/
- https://en.wikipedia.org/wiki/GWR_4073_Class
- https://en.wikipedia.org/wiki/Great_Western_Railway
- https://en.wikipedia.org/wiki/Brunswick_green
- https://en.wikipedia.org/wiki/LMS_Princess_Coronation_Class
- https://en.wikipedia.org/wiki/LMS_Stanier_Class_8F
- https://accurascale.com/products/br-16t-mineral-1-109-br-freight-grey-original-text-on-black-panels-pack-j
- https://alextrack.co.uk/model_railways/2mm_finescale/freight_wagons/brake_vans_br_standard.html
- https://en.wikipedia.org/wiki/Brake_van
- https://en.wikipedia.org/wiki/British_Rail_Class_43_(HST
- https://en.wikipedia.org/wiki/British_Rail_Mark_3
- https://en.wikipedia.org/wiki/InterCity_(British_Rail
- https://www.e-paint.co.uk/uk-organisations-colours.asp?cOrg=BR
- https://en.wikipedia.org/wiki/British_Rail_Class_55
- https://en.wikipedia.org/wiki/British_Rail_Mark_1
- https://en.wikipedia.org/wiki/British_Rail_Class_47
- https://de.wikipedia.org/wiki/DB-Baureihe_103
- https://de.wikipedia.org/wiki/Trans-Europ-Express
- https://www.marklin-users.net/forum/posts/m596660-Does-Anyone-Know-a-Close-Match-For-TEE-Colors-in-US-Hobby-Paints
- https://de.wikipedia.org/wiki/Rheingold_(Zug
- https://de.wikipedia.org/wiki/DB-Baureihe_V_200.0
- https://de.wikipedia.org/wiki/DR-Baureihe_01
- https://cs.finescale.com/fsm/modeling_subjects/f/3/t/181041.aspx
- https://en.wikipedia.org/wiki/SBB-CFF-FFS_Ce_6/8_II
- https://fr.wikipedia.org/wiki/TGV_Sud-Est
- https://en.wikipedia.org/wiki/TGV_Sud-Est
- https://franco.wiki/fr/TGV_Sud-Est.html
- https://en.wikipedia.org/wiki/TGV_Atlantique
- https://en.wikipedia.org/wiki/ICE_1
- https://de.wikipedia.org/wiki/ICE_1
- https://de.wikipedia.org/wiki/ICE_3
- https://en.wikipedia.org/wiki/SBB_Re_460
- https://en.wikipedia.org/wiki/Siemens_Vectron
- https://en.wikipedia.org/wiki/Intermodal_container
- https://en.wikipedia.org/wiki/0_Series_Shinkansen
- https://ja.wikipedia.org/wiki/新幹線0系電車
- https://en.wikipedia.org/wiki/N700_Series_Shinkansen
- https://trafficnews.jp/post/89011/2
- https://en.wikipedia.org/wiki/E5_Series_Shinkansen
- https://www.jreast.co.jp/train/shinkan/e5.html
- https://en.wikipedia.org/wiki/E6_Series_Shinkansen
- https://en.wikipedia.org/wiki/JR_Freight_Class_EF210
- https://ja.wikipedia.org/wiki/JR貨物EF210形電気機関車
- https://ja.wikipedia.org/wiki/JR貨物19D形コンテナ
- https://en.wikipedia.org/wiki/JNR_Class_D51
- https://en.wikipedia.org/wiki/JNR_Class_C62

### American trains, paint and scale (rail-us)
- https://utahrails.net/up/up-paint-html.php
- https://en.wikipedia.org/wiki/Union_Pacific_Big_Boy
- https://www.up.com/heritage/steam/4014/index.htm
- https://en.wikipedia.org/wiki/Southern_Pacific_class_GS-4
- https://en.wikipedia.org/wiki/Southern_Pacific_4449
- https://en.wikipedia.org/wiki/Coast_Daylight
- https://en.wikipedia.org/wiki/San_Joaquin_Daylight
- https://en.wikipedia.org/wiki/Southern_Pacific_GS-5_class
- https://www.flickr.com/photos/trainplanepro/9060893142
- https://ogrforum.com/topic/sp-daylight-orange-formula
- https://en.wikipedia.org/wiki/NYC_Hudson
- https://www.trains.com/?p=38625
- https://en.wikipedia.org/wiki/20th_Century_Limited
- https://forum.trains.com/t/nyc-20th-century-limited-question/244975
- https://www.mthtrains.com/news/check-out-details-and-see-it-action-ho-20th-century-limited-passenger-sets-ship
- https://www.flickr.com/photos/99819826@N08/13155524554
- https://www.flickr.com/photos/alcomike/6827142174
- https://en.wikipedia.org/wiki/Norfolk_and_Western_Class_J_(1941
- https://en.wikipedia.org/wiki/Powhatan_Arrow
- https://wataugavalleynrhs.org/powhatan.php
- https://www.flickr.com/photos/alcomike/15531950664
- https://en.wikipedia.org/wiki/Milwaukee_Road_class_F7
- https://en.wikipedia.org/wiki/Milwaukee_Road_class_A
- https://en.wikipedia.org/wiki/Twin_Cities_Hiawatha
- https://forum.trains.com/t/milwaukee-s-hiawatha-paint-schemes/141228
- https://www.flickr.com/photos/14488898@N02/40798414423
- https://en.wikipedia.org/wiki/PRR_K4s
- https://forum.trains.com/t/dgle/292843
- https://en.wikipedia.org/wiki/Broadway_Limited
- https://www.trovestar.com/generic/zoom.php?id=181619
- https://en.wikipedia.org/wiki/Tuscan_red
- https://en.wikipedia.org/wiki/PRR_T1
- https://en.wikipedia.org/wiki/Santa_Fe_3751
- https://en.wikipedia.org/wiki/Budd_Company
- https://en.wikipedia.org/wiki/Dome_car
- https://en.wikipedia.org/wiki/EMD_F7
- https://en.wikipedia.org/wiki/Super_Chief
- https://en.wikipedia.org/wiki/El_Capitan_(train
- https://en.wikipedia.org/wiki/Hi-Level
- https://sfrhms.org/files/funits/mnotes.htm
- https://www.flickr.com/photos/sp8254/16297799665
- https://www.flickr.com/photos/airport/16232386318
- https://www.flickr.com/photos/captain_railroad/6010189322/
- https://en.wikipedia.org/wiki/EMD_E8
- https://en.wikipedia.org/wiki/City_of_Los_Angeles_(train
- https://utahrails.net/up/armour-yellow.php
- https://utahrails.net/pass/pass-paint.php
- https://utahrails.net/up/up-diesel-paint-classic-era.php
- https://gnrhs.org/empire_builder.php
- https://www.gnrhs.org/gn_paint_schemes.php
- https://ogrforum.com/topic/new-great-northern-f-3s-simplified-scheme
- https://www.tcatrains.org/?p=8693
- https://en.wikipedia.org/wiki/California_Zephyr_(1949%E2%80%931970
- https://en.wikipedia.org/wiki/EMD_E5
- https://en.wikipedia.org/wiki/Shasta_Daylight
- https://en.wikipedia.org/wiki/ALCO_PA
- https://en.wikipedia.org/wiki/EMD_E7
- https://en.wikipedia.org/wiki/Pioneer_Zephyr
- https://en.wikipedia.org/wiki/Olympian_Hiawatha
- https://en.wikipedia.org/wiki/Skytop_Lounge
- https://en.wikipedia.org/wiki/PRR_GG1
- https://forum.trains.com/t/difference-between-f3-f7-f9-locos/131707
- https://sfrhms.org/files/funits/f7notes.htm
- https://sfrhms.org/files/funits/ftnotes.htm
- https://forum.trains.com/t/gp7-nyc/180736
- https://en.wikipedia.org/wiki/EMD_GP7
- https://en.wikipedia.org/wiki/EMD_GP9
- https://forum.trains.com/t/gp7-gp9/179408
- https://en.wikipedia.org/wiki/ALCO_FA
- https://en.wikipedia.org/wiki/ALCO_RS-3
- https://en.wikipedia.org/wiki/Norfolk_and_Western_class_A
- https://en.wikipedia.org/wiki/Caboose
- https://ogrforum.com/topic/train-length-in-the-1940s
- https://rapidotrains.com/ho-scale/freight-car/1937-aar-40-boxcar.html?cat=1226
- https://www.nasg.org/Gallery/reports/BoxCars/ByManufacturerID/indexTrain_Stuff24925.php
- https://utahrails.net/up/up-freight-paint.php
- https://ogrforum.com/topic/real-model-paint-color-question-prr
- https://sfrhms.org/files/KJordan/SFRHMS%20Painting%20Guide.pdf
- https://oklahomarailwaymuseum.org/exhibits/conx-50020-sante-fe-6919-boxcar/
- https://www.nscalesupply.com/MTL/MTL-55080.html
- https://rrmodelcraftsman.com/utlx-x-3-tank-cars-arrive-from-rapido-trains/
- https://bbcrc.org/pfe-reefer-home.html
- https://forum.trains.com/t/roof-colors/248184
- https://forum.trains.com/t/prototype-pfe-reefer-paint-color/77385
- https://www.psrm.org/?p=382
- https://sfrhms.org/rebuilding-santa-fe/gallery/atsf-refrigerator-cars/
- https://rgvrrm.org/about/railroad/prr477822/
- https://www.trains.com/?p=42221
- https://utahrails.net/caboose/caboose-steel.html
- https://utahrails.net/caboose/caboose-paint.php
- https://en.wikipedia.org/wiki/GE_Evolution_Series
- https://en.wikipedia.org/wiki/GE_Dash_9-44CW
- https://en.wikipedia.org/wiki/BNSF_Railway
- https://academickids.com/encyclopedia/index.php/BNSF
- https://www.railpictures.net/photo/678898/
- https://en.wikipedia.org/wiki/EMD_SD70_series
- https://en.wikipedia.org/wiki/Union_Pacific_Railroad
- https://www.brandcolorcode.com/csx-transportation
- https://forum.trains.com/t/csx-yn3-paint/140001
- https://en.wikipedia.org/wiki/GE_Genesis
- https://en.wikipedia.org/wiki/Amtrak_paint_schemes
- https://en.wikipedia.org/wiki/Siemens_Charger
- https://en.wikipedia.org/wiki/Northeast_Regional
- https://en.wikipedia.org/wiki/Amfleet
- https://en.wikipedia.org/wiki/Empire_Builder
- https://en.wikipedia.org/wiki/Superliner_(railcar
- https://www.progressiverailroading.com/rail_industry_trends/news/Johnstown-America-delivers-aluminum-coal-cars-to-southern-utility--5826
- https://freightcaramerica.com/coal-bethgon-ii/
- https://trovestar.com/generic/zoom.php?id=134563
- https://freightcaramerica.com/wp-content/uploads/2023/09/DOWNLOAD-VERSAFLOOD-II-SHEET.pdf
- https://www.trainz.com/products/atlas-20002815-ho-somerset-railroad-trainman-aluminum-coal-gondola-831
- https://www.gbrx.com/?p=1020
- https://en.wikipedia.org/wiki/Well_car
- https://trains.com/?p=221179
- https://en.wikipedia.org/wiki/Intermodal_container
- https://www.freightcourse.com/?p=3424
- https://www.marineinsight.com/shipping-giant-maersk-gives-its-boxes-a-blue-makeover-after-5-decades/
- https://www.trovestar.com/catalog/item/147300
- https://freightcaramerica.com/wp-content/uploads/2021/04/Flat-Car_AutoRack_Product-Sheet.pdf
- https://gatx.com/products/auto-carriers
- https://en.wikipedia.org/wiki/Autorack

### Track plans, pixel rail games, turning sprites, following track (rail-craft)
- https://en.wikipedia.org/wiki/Model_railroad_layout
- https://www.zealotmodels.com/threads/twice-around-plans.103563/
- https://forum.trains.com/t/twice-around-new-definition-may-2018-mr/301744
- https://www.marklin.com/products/details/article/24130
- https://ajckids.com/products/marklin-24130
- https://www.marklin-users.net/forum/posts/t243-Geometry-of-C-track
- https://railsofsheffield.com/products/kato-2-210-kato-2-210-curved-track-radius-550mm-225-deg4
- https://lombardhobby.com/kato-n-20-120-unitrack-curved-track-315mm-12-3-8-radius-45-degrees/
- https://railsofsheffield.com/products/kato-20-101-kato-20-101-ground-level-radius-249mm-curved-track-15-deg4
- https://forum.trains.com/t/atlas-track-full-curve-not-a-full-curve/109463
- https://www.bricklink.com/v2/catalog/catalogitem.page?P=2867c01
- https://nmra.com/sites/default/files/standards/sandrp/General/RP/rp-11_2018.03.03r.pdf
- https://nmra.com/sites/default/files/standards/sandrp/General/TN/tn-11_2017.04.09.pdf
- https://forum.trains.com/t/picking-the-right-turn-radius-for-n-scale/237543
- https://www.cn.ca/-/media/files/our-business/equipment/fp-centerbeam-car-en.pdf
- https://en.wikipedia.org/wiki/Sagitta_(geometry
- https://github.com/OpenTTD/OpenGFX
- https://docs.openttd.org/source/d0/ddf/tile__type_8h_source
- https://www.tt-forums.net/viewtopic.php?p=936508
- https://github.com/OpenTTD/OpenTTD/blob/master/src/vehicle_type.h
- https://docs.openttd.org/source/d7/d7a/viewport__sprite__sorter_8h_source.html
- https://github.com/OpenLoco/OpenLoco
- https://github.com/OpenRCT2/OpenRCT2/blob/develop/src/openrct2/entity/Yaw.hpp
- https://forums.openrct2.org/topic/1446-rct1-vehicles
- https://excaliburjs.com/docs/pixel-art
- https://casual-effects.com/research/McGuire2021PixelArt/McGuire2021PixelArt.pdf
- https://en.wikipedia.org/wiki/Pixel-art_scaling_algorithms
- https://azuzota.itch.io/sprite-stacking-with-perspective
- https://jamespoole.itch.io/wee-boats/devlog/685630/using-sprite-stacking-for-pseudo-3d-in-wee-boats
- https://gamefromscratch.com/spritestack-3d-pixel-art-tool/
- https://github.com/OpenLoco/OpenLoco/blob/master/src/OpenLoco/src/Vehicles/VehicleBody.cpp
- https://community.aseprite.org/t/line-tool-makes-irregular-lines/6306
- https://gafferongames.com/post/fix_your_timestep/
- https://en.wikipedia.org/wiki/Level_junction
- https://wiki.openttd.org/es/Archive/Manual/YAPP
- https://liamappelbe.medium.com/how-to-generate-slither-link-puzzles-6c65510b2ba1
- https://www.gamedeveloper.com/programming/generating-procedural-racetracks
- https://forum.trains.com/t/whats-your-max-grade/199019

### Transition freight and today (rail-craft, round 5)
- https://utahrails.net/up/up-diesel-paint-classic-era.php
- https://bbcrc.org/pfe-reefer-home.html
- https://forum.trains.com/t/roof-colors/248184
- https://utahrails.net/caboose/caboose-paint.php
- https://sfrhms.org/files/funits/f7notes.htm
- https://sfrhms.org/files/funits/ftnotes.htm
- https://sfrhms.org/files/KJordan/SFRHMS%20Painting%20Guide.pdf
- https://oklahomarailwaymuseum.org/exhibits/conx-50020-sante-fe-6919-boxcar/
- https://www.psrm.org/?p=382
- https://forum.trains.com/t/dgle/292843
- https://en.wikipedia.org/wiki/EMD_GP9
- https://rgvrrm.org/about/railroad/prr477822/
- https://www.trains.com/?p=42221
- https://forum.trains.com/t/gp7-nyc/180736
- https://utahrails.net/up/up-freight-paint.php
- https://rrmodelcraftsman.com/utlx-x-3-tank-cars-arrive-from-rapido-trains/
- https://en.wikipedia.org/wiki/Norfolk_and_Western_class_A
- https://www.railpictures.net/photo/678898/
- https://en.wikipedia.org/wiki/BNSF_Railway
- https://utahrails.net/up/up-paint-html.php
- https://en.wikipedia.org/wiki/Union_Pacific_Railroad
- https://www.brandcolorcode.com/csx-transportation
- https://forum.trains.com/t/csx-yn3-paint/140001
- https://en.wikipedia.org/wiki/Siemens_Charger
- https://en.wikipedia.org/wiki/Amtrak_paint_schemes
- https://en.wikipedia.org/wiki/Superliner_(railcar
- https://en.wikipedia.org/wiki/Amfleet
- https://www.freightcourse.com/?p=3424
- https://www.marineinsight.com/shipping-giant-maersk-gives-its-boxes-a-blue-makeover-after-5-decades/
- https://freightcaramerica.com/coal-bethgon-ii/
- https://www.trainz.com/products/atlas-20002815-ho-somerset-railroad-trainman-aluminum-coal-gondola-831
- https://freightcaramerica.com/wp-content/uploads/2021/04/Flat-Car_AutoRack_Product-Sheet.pdf
- https://en.wikipedia.org/wiki/Autorack
- https://forum.trains.com/t/difference-in-types-of-ballast/205874
- https://www.vintagestreetlights.com/bio/page2.html
- https://www.jonroma.net/media/signaling/railway-signaling/1951/A%20History%20of%20Flashing-Light%20Crossing%20Signals-%20What%20They%20Are%20and%20Why.pdf
- https://railroadsignals.us/signals/searchlights/
- https://en.wikipedia.org/wiki/Coaling_tower
- https://distinctlymontana.com/montanas-grain-elevators
- https://www.hoosiervalley.org/explore/grasselli-tower/about-interlocking-towers
- https://en.wikipedia.org/wiki/Ford_F-Series_(first_generation
- https://www.rtands.com/?p=55161
- https://mutcd.fhwa.dot.gov/htm/2003/part8/part8d.htm
- https://www.npr.org/sections/thetwo-way/2016/06/21/482936520/bright-bluish-white-led-streetlamps-bad-for-our-health-ama-says
- https://www.mychesco.com/a/news/regional/white-gray-black-still-rule-as-car-color-choices-shift-only-at-the-edges/

### Britain (rail-craft, international round)
- https://www.w3schools.com/colors/colors_british.asp
- https://lner.info/article/liveries/livery.php
- https://en.wikipedia.org/wiki/British_Rail_corporate_liveries
- https://en.wikipedia.org/wiki/LNER_Class_A3_4472_Flying_Scotsman
- https://www.rmweb.co.uk/forums/topic/180467-what-might-be-the-real-lner-garter-blue-answer-humbrol-enamel-no-221continues-as-the-paint-job/
- https://en.wikipedia.org/wiki/LNER_Class_A4_4468_Mallard
- https://en.wikipedia.org/wiki/Great_Western_Railway
- https://en.wikipedia.org/wiki/GWR_4073_Class
- https://en.wikipedia.org/wiki/LMS_Princess_Coronation_Class
- https://en.wikipedia.org/wiki/LMS_Stanier_Class_8F
- https://accurascale.com/products/br-16t-mineral-1-109-br-freight-grey-original-text-on-black-panels-pack-j
- https://alextrack.co.uk/model_railways/2mm_finescale/freight_wagons/brake_vans_br_standard.html
- https://en.wikipedia.org/wiki/Brake_van
- https://www.e-paint.co.uk/uk-organisations-colours.asp?cOrg=BR
- https://en.wikipedia.org/wiki/British_Rail_Class_43_(HST
- https://en.wikipedia.org/wiki/British_Rail_Mark_3
- https://en.wikipedia.org/wiki/InterCity_(British_Rail
- https://en.wikipedia.org/wiki/Brunswick_green
- https://en.wikipedia.org/wiki/British_Rail_Class_55
- https://en.wikipedia.org/wiki/British_Rail_Mark_1
- https://en.wikipedia.org/wiki/British_Rail_Class_47
- https://en.wikipedia.org/wiki/Level_crossings_in_the_United_Kingdom
- https://en.wikipedia.org/wiki/UK_railway_signalling
- https://www.railsigns.uk/sect2page4.html
- https://heritage.dorsetcouncil.gov.uk/Monument/MDO47638
- https://www.rmweb.co.uk/forums/topic/1944-gwr-light-dark-stone/page/2/
- https://sas-space.sas.ac.uk/6429/1/SBT-combined1.pdf
- https://www.newforestnpa.gov.uk/document/tile-and-slate-roofing/
- https://vintagestreetlights.com/history/lps.html
- https://en.wikipedia.org/wiki/Austin_7
- https://en.wikipedia.org/wiki/Morris_Minor
