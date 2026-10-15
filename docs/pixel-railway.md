# Pixel Railway

A model railway seen from above in pixel art: one to three trains of one era running on loops of track through open countryside, with a station and its town, a road over the line at a level crossing, a pond, trees, and a hill the line tunnels through. Where two loops cross they meet at a diamond, where one train waits for the other, or one rides over the other on a bridge. It follows the real Sun where you are, and lays snow when there's snow on the ground there. A new layout fades in every few hours, then just runs.

Dave asked for it on 2026-10-15: "a top down procedurally generate model train track and train layout, I loved playing with model trains when I was little ... in the pixel style we have been doing ... relatively simple procedural loop layouts that fill the screen and have 1-3 trains able to run along them in various well know styles, santa fe, etc". It was researched by five agents, mocked up in Python as geometry ([Mock-ups](#mock-ups)), and on seeing the sheets he said "yes to everything you are showing me, it looks awesome". It was built the same day behind the `unfinished` switch.

- **Source:** `Sources/Atrium/PixelRailway.swift` (the scene: its canvas, the clock, the weather, Settings and the fade to a new layout) and `Sources/RailLayout/`, its own module built with `-O`: `Art.swift` (materials, every vehicle as slices, the trains), `Render.swift` (the views, the voxel ray march, the canvas, the scenery models), `Layout.swift` (the loops and their crossings), `Scenery.swift` (everything round the track), `Static.swift` (the picture under the trains), `Sim.swift` (the trains, signals and the road), `Railway.swift` (the whole, and drawing the moving things each frame).
- **Data:** none. Every layout is made from the clock; every vehicle and building is a few strings of slices.
- **Tests:** `Tests/AtriumTests/RailwayTests.swift` writes one layout in each view and era, by day, at night and in snow, to `$TMPDIR/atrium-railway/` (`RAILWAY_SEED=` picks another).
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

The lead's calls, not ruled on: model-railway compression (locomotives 25–38 px, cars 16–30, three to five cars to a passenger train and eight and a caboose to the freight); Size changes the art pixel (3, 4 or 5 points on a 982-point-high screen), not the drawings; every vehicle baked at 64 headings from its slices as first drawn; the simulation stepped at a fixed 1/60 s; "Great Northern streamliner", not "Empire Builder" (an Amtrak mark); the disclaimer's wording.

## Mock-ups

`docs/pixel-railway/` doesn't hold them: they were a Python script (`railway.py` with the slices in `art.py`) in the session's scratchpad, drawing four views of one layout, each era by day, at night and in snow, every train at four headings, 8 s films of the trains running, and a car rounding a curve every 0.2 s. The Swift build is a port of that script, line for line where it could be, so the app draws the pixels the sheets showed; the geometry it was written to is in [How it works](#how-it-works). Two things the port changed on purpose: the hill is shaded as smooth ground in every view (the mock-up's looked smooth only because its width came out even, which made the ray's steps up the hill land as tops; an odd width showed every step as a dark terrace), and the layout's random numbers come from SplitMix64 rather than Python's, so a seed gives a different layout from the mock-up's.

## How it works

**Units and views.** One world unit is one top-down art pixel, 2 ft at model-railway compression (an F7 is 25 by 5). y runs down the screen, z up. The 3/4 view puts a point at (x, y − z): each unit of height shows one pixel up the screen. Isometric puts it at (x − y + W/2, (x + y)/2 + H/2 − z), the layout on the world's axes so its straights run on the 2:1 diagonals. Depth (larger is nearer) is y + z, or x + y + z in iso; anything flat takes the depth where its pixel's ray meets its plane, so coplanar layers never fight. In 3/4, track centrelines sit on pixel centres.

**Layout** (`Layout.swift`). The trains go largest radius first, each needing max(32, 1.6 × its longest vehicle). A plan is drawn first: twice-around (twice as likely), loop in a loop, or two side by side. A loop is the outline of a union of one to three random rectangles on a 2-unit raster, 40% of its corners cut at 45° by 0.8–1.6 R, every corner rounded by the largest arc up to 1.15 R that fits; it's thrown away if any curve is under 0.98 R or the loop is shorter than 2.2 trains. A twice-around's second loop is built across one of the first's straights at right angles. Wherever two loops come within 14 units they must cross cleanly, at 40° or more and straight for 12 either side. Of a pair that cross twice, one crossing becomes a bridge, the upper loop ramping up 1:6 to a deck 7 high. Diamonds closer than the longest train and 40 along any loop are reserved together. A train that gets no loop of its own runs on one behind another, if the loop takes enough blocks that the two can never hold them all ([Layout.blockCount](../Sources/RailLayout/Layout.swift)), so they never deadlock. In iso each loop is one rectangle on the world's axes, kept on the screen.

**Scenery** (`Scenery.swift`), all from the seed. The station goes on the clearest straight of 76 units or more, passenger loops first: a platform 4 wide, 4–8 off the centreline; for steam a Southern Pacific style wooden depot and a water tank, for streamliners a brick station with a canopy over 60% of the platform. The main road crosses the track at right angles just past the platform's end, with crossbucks and a wigwag (steam) or flasher masts and short gates (streamliners), and a pole line. Side streets run parallel to the track at 22 and 48, with up to 18 gabled houses. A pond takes the largest clear disc, inside a loop if it can; a hill with a cutting, a stone headwall and a dark bore sits on a long curve; about 230 trees are thrown as darts, thicker in clumps, more conifers for steam. Signals: one past the platform on a lone train's loop, a home signal at each diamond, and on a loop two trains share, one at each block's entrance, never where a train held at it would stand on a diamond, the road, the platform or in the tunnel. Semaphores for steam, searchlights for streamliners.

**Drawing.** Everything that stands up, trains and houses and the hill alike, is a box of voxels drawn by marching each sprite pixel's view ray down through it, top first: the first filled cell shows, and which of its indices changed from the step before says whether it's a top, a side or an end. Faces are shaded by the Sun, (−0.55, −0.45, 0.70) in top-down and (−0.30, 0.60, 0.74) in iso. Shadows are every voxel dropped along the Sun's rays onto the ground. The picture under the trains (`Static.swift`) is drawn once a layout, by day and by night, with each pixel's depth: by day with shadows, by night with the colours multiplied by (0.25, 0.26, 0.36) and lifted by (18, 15, 34), windows lit, and pools of lamplight in three rings. Each frame (`Railway.swift`) copies the mix of the two for how dark it is now, adds the headlights' cones on the ground at night, and draws each vehicle at the nearest of 64 headings (and its ramp's slope) against the depths, so tunnels, bridges and trees need no special cases. A vehicle's sprite is baked the first time it's needed and kept, coloured both ways. The canvas goes up to a `SKMutableTexture` drawn with nearest filtering.

**Running** (`Sim.swift`), in fixed steps of 1/60 s. Trains cruise at 13–18 px/s and brake and pull away at 8 px/s². Each sits on two bogies at ±0.375 of its length (±0.35 for steam engines). A train asks for a diamond when its front is within braking distance and 6 of it, stops 4 short if it's held, and lets it go once its tail is clear. On a loop with blocks it enters one only when no other train holds it; it takes a diamond only with every block it needs to clear it. Passenger trains stop at the platform for 30 s. The car on the road stops 10.5 short of the crossing while a train is within 40 or over it.

**The clock.** A layout is the period of New Layout Every since 1970, so every display and Settings' copy agree; its era is picked from the ticked ones by the period's number, and its trains from the era. A new period, a setting that changes the layout, or snow arriving or melting builds the next layout off the main thread and fades to it over 2 s. How dark it is follows the Sun's height where you are, from 4° above the horizon to 8° below, checked every 30 s.

## Rights

The trains are drawn after real railroads' paint schemes, with no heralds, numbers or lettering. Their names appear only in Settings, under which the page says: "Names say which real train each is drawn after. Atrium isn't affiliated with or endorsed by any railroad." The longer disclaimer, for About and NOTICE: "Pixel Railway's trains are drawn after the paint schemes of real railroads, without their logos or lettering. Railroad and train names, such as Santa Fe, Union Pacific, BNSF, Amtrak, Flying Scotsman, ICE, TGV and Shinkansen, are trademarks of their owners, used only to say which train a picture shows. Atrium isn't affiliated with, sponsored by or endorsed by any of them." The README, the site and the App Store say "paint schemes of real railroads", with no railroad names in headings, keywords or captions. If an App Store reviewer objects under guideline 5.2.1, that build uses descriptive names.

Why (the research, not legal advice): Union Pacific sued model makers in 2004 over its marks; UP and Amtrak hold registrations for model trains; BNSF owns the Santa Fe, Great Northern and Burlington names and in 2023 made an airline drop the Northern Pacific name; Santa Fe's Warbonnet (Reg. 2000826) and UP's colours (Reg. 2148551) are registered for rail services only. The research reads a plain name that says which train a picture shows as US nominative fair use, which a logo or lettering would not be; no railroad's terms ask for a licence just to name one. Not checked: the British, European and Japanese registers, and designs on recent train shapes.

## Settings

| Setting | Does |
|---|---|
| View | Top-down (3/4) or Isometric |
| Size | Small, Medium (Pixel City's pixel: 4 points on a 982-point-high screen) or Large: the art pixel, so more room for track when smaller |
| Trains | One, up to two, or up to three: a train that doesn't fit is left off |
| New layout every | Hour, 3 hours (standard), 6 hours, or Day |
| Eras | US streamliners (Santa Fe F7 warbonnet with Hi-Levels; Union Pacific E9 with an Astra Dome; Great Northern F7 streamliner) and US steam (Union Pacific Big Boy with mixed freight and a caboose; Southern Pacific GS-4 Daylight; Milwaukee Road Hiawatha); none ticked counts as both |
| Seasons | Snow on the ground when Open-Meteo says there's a centimetre or more where you are (the request every weather wallpaper shares) |
| Preview | Snow; a time of day |

## Cost

0.71 ms of CPU and 0.55 of GPU a frame at 2x Retina on a 1512 × 982-point screen (the render test's debug build, the module at `-O`, 2026-10-15). A layout builds in 0.07–0.4 s off the main thread. `batteryRate` is 20: the trains step whole art pixels at up to 18 a second.

## Shortcuts

- The hill's shading ignores which face a step shows: its grass is lit by slope instead.
- Autumn colours, and winter without snow, aren't drawn yet: it's summer unless there's snow.
- A station fits on about half of all layouts; the rest have none, and their passenger trains run through.
- The pools of lamplight and the headlights light only the ground.

## Still open

From the mock-ups' review: one-pixel side bands (windows, UP's yellow, GN's orange) break into dots at some headings, worst at 30° and in iso, and flicker round curves (sampling each pixel four times in the bake should fix it); rails vanish on the ramps in 3/4 and the bank under them is stepped; town streets can run long and read as asphalt; three diamonds near each other are reserved together, so a train can wait up to 7 s for a train on another diamond; headlight pools are faint on grass. The short trains for inner loops, Settings' checklist of trains, the autumn and winter-without-snow colours, and the other eras (transition freight, modern US, Britain, Germany and the Alps, European high speed, the Shinkansen) are to come, and switches and sidings after them. The long disclaimer goes into About and NOTICE when Pixel Railway is shown to everyone.

## Next ideas

- A short local (a GP9 with 18 px cars, a Budd rail diesel car or doodlebug, or a small steam switcher) on a tight inner loop.
- The other eras the research shortlisted, with overhead wire for the electric ones (a 1-pixel line at 35–45% over the track, T-masts every 80–100 px).
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
