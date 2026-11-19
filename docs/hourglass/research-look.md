# Hourglass: the look research

A research agent's report on what an hourglass wallpaper should look like, written 2026-11-18 for Dave's idea of that day: "a slow steady stream of sand is falling and building up in my background, eventually filling and starting over". How to simulate and draw it, and what it costs, is researched separately in `research-method.md`. Every claim is marked **checked** (the page that says so was read on 2026-11-18), **partly checked** (seen only in a search engine's excerpt of the page) or **unchecked**. A Commons licence marked checked is Commons' own licence field for that file, read through its API, which is only as good as the uploader's claim. Hex values and brightness figures are my own samples, measured by small Python scripts on Commons' 1,280-pixel copies (resized to 1,200 wide for brightness) and on frames of two Commons videos; brightness is the brightest of R, G and B out of 255, as in [kelp-forest/research-look.md](../kelp-forest/research-look.md) and [canopy/research-look.md](../canopy/research-look.md). The downloads were kept in the scratchpad and deleted afterwards; nothing is in the repo.

## Summary and recommendation

**Put forward the screen as the glass: a flat hourglass the size of the display, dry sand between two panes, its waist at the middle of the screen, the upper chamber draining into a V-shaped crater and the lower one building a cone at the angle of repose, with a fine thread of sand between them.** Both chambers are always in view, so about half the screen is sand at every moment of every cycle and there is never an empty spell (a wallpaper that showed only the lower chamber would start each cycle empty, the Murmuration fault). The start over is the real one, the glass turned over: preferably while the displays sleep, otherwise slowly, as Budapest's year-long Timewheel is turned over 45 minutes; never a crossfade. Behind the empty glass, a warm room out of focus in Dark Mode (the lamplit room of photo H1, which meets the app's dark caps with nothing but a dimming) and a pale plaster wall in Light Mode. Default palettes: **Lamplight** (H1's brown hourglass sand, warm on warm, for Dark Mode) and **Gypsum** (White Sands' grains, for Light Mode), with **Desert** (Gobi gold to Namib red, a shade per hour so the pile records the day), **Bermuda** (cream with pink grains) and **Basalt** (black sand) as picks. The second look to mock up is **Blown glass**, a close-up of a real hourglass's waist in the same lamplit room: the most photographic and the quickest to read as an hourglass, but it lives or dies on glass, the hardest material to fake. Name: **Hourglass**, with **Sandglass** as the fallback; avoid *Sand Timer*, *Sandfall*, *Falling Sand* and *Sands of Time*.

1. **The real thing is a dim, warm, soft picture.** The calmest reference, an hourglass in a lamplit room (H1), has a median of 54 and a 99th percentile of 209 as shot, and scaled in linear light by 0.48 it lands at 36 / 92 / 150 / 179 (median / 90th / 99th / 99.9th) with 0.6% hard edges: inside Jellyfish's and Kelp Forest's dark caps without any other change. The look is sepia: brown sand, a brown room, glass that is only thin rims and a few highlights.
2. **The thread is soft, not a laser line.** In H1 it is about 0.6% of the frame's width halfway down its fall and 0.9% just above the cone, dimming and widening as it falls (133 against a background of 72, then 98 against 60, as shot), and it ends in a faint haze of bouncing grains at a rounded tip. Glitter and "golden sand" sparkle (H7) are what stock footage does, not sand.
3. **The cone is the life of it.** Dry sand stands at about 34° (Wikipedia's table, checked); a dune's slip face fails at about 34° and comes to rest at about 32° (partly checked). H1's cone measures about 30° on its right flank. The surface grows by small avalanches that run down the flanks as tongues with raised edges (the Oregon slip face, S9), which is the motion to watch between the thread's steady fall.
4. **Coloured layers are the variety.** A pile builds in sloping layers, so sand laid down hour by hour shows as nested chevrons (Λ) in the lower chamber, and after the turn the same chevrons hang upside down in the upper chamber and are eaten from the middle by the crater. In a thin cell, a mix of two grain sizes even stripes itself with every avalanche (Makse et al. 1997, partly checked). That makes "a new look on each load" and "the pile records the day" one and the same thing.
5. **Warm sands are one family; keep them that way.** Real hourglass sand is brown, white, grey or black (marble dust, eggshell, black marble, glass beads). Real sands give a warm family from cream through gold to iron red (gypsum, Bermuda, Gobi, Namib), plus black basalt. Dyed blue sand in brown wood (V2) is Lava Lamp's two families; olivine is Crystals' olive; red reads as "time running out".
6. **Calm, not a countdown.** The hourglass is the old symbol of life running out (Wikipedia, checked; the extinction symbol uses it for exactly that), and most hourglass wallpapers lean on skulls, fantasy or drama. To stay calm: a long glass by default (a day, turned when the displays sleep), no numbers, ticks or chime, no red by default, no props, and the eye drawn to what has built up rather than what is left.
7. **Name:** *Hourglass* is the plainest and in the house style (Lava Lamp, Fish Tank, Ant Colony), but a free Mac wallpaper app of 2021 is called *HourGlass – Dynamic Desktop* (checked), a luxury cosmetics brand owned by Unilever is Hourglass (checked), and many timer apps use it. Inside the app as a scene's name it is descriptive; in App Store keywords it would collide. *Sandglass* is the old English word with fewer collisions.

## 1. The real thing

### The glass

- **One piece or two.** The first hourglasses were "two separate bulbs with a cord wrapped at their union that was then coated in wax"; later "both bulbs were blown together to keep moisture out" (Wikipedia, checked). Today a glass is blown from one tube: the neck is drawn first, then each bulb is blown, then one end sealed and the other left open for filling (Quill & Pad, checked). The ship's *ampolleta* (H10) is the two-bulb kind, bound at the waist.
- **How it reads as glass, from the photos** (my observations of H1, H2 and H3, checked by looking):
  - Thin bright rims along the silhouette where the glass is seen edge on, and a dark line just inside them.
  - Bright streaks where the curve catches the light: a vertical streak down the inside of the neck (H1), a long arc down each bulb.
  - Reflections of the room's bright things, small and curved: H2's bulb holds a sharp, curved window while the real window behind is a blur. A thin-walled hollow bulb should barely bend what is behind it, the bending showing at the thick neck and at the edges (my reasoning from optics, unchecked; H1 and H2 agree by eye).
  - The neck is the brightest, densest knot of glass: thick where the two halves meet.
  - Glass picks up the room's colour: in H1 it is amber, in H2 grey-green.
- **Wall thickness** of a blown hourglass, about 1 to 2 mm: unchecked (no source read). The Ikepod hourglass, Marc Newson's luxury design, is borosilicate (partly checked); it is filled with steel balls, so it is a look-alike to avoid, not a reference.
- **Frames.** Turned wood with three or four spindles between two discs (H1, H4: S Sepp's is 25 cm tall with an 11.5 cm disc, from its Commons description, checked); brass with twisted or scrolled posts (H3, H7); museum pieces in silver and gilt (H5, H6). H3's glass hangs on pivots between brass scrolls so it can be turned in its frame, as the ship's revolving glass does.

### The sand (what real hourglasses held)

- Hourglass fill was often not sand: "powdered [marble], [tin]/[lead] oxides, [or] pulverized, burnt eggshell" (Wikipedia, checked); "sand, powdered marble, or powdered eggshell" (Quill & Pad, checked). The household book *Le Ménagier de Paris* (1392–94) gives the oldest known recipe: dust from sawing black marble, boiled in wine, skimmed and dried in the sun, nine times (partly checked). A Renaissance French manuscript (BnF Ms. Fr. 640) gives one from lead and salt (Making and Knowing field notes, checked: the page has the recipe but not the result's colour).
- Modern glasses are mostly filled with tiny glass beads, *ballotini*, 40 to 160 µm, which flow evenly and are often dyed (search excerpts, partly checked).
- So the honest colours of an hourglass's fill are white to cream (marble, eggshell), grey to black (black marble, basalt, beads), and warm browns (H1's sand). Bright dyed colours are modern and novelty.
- Sampled, as photographed (10th to 98th percentile of brightness):

| Fill | Photo | Swatches |
|---|---|---|
| Brown sand by lamplight | H1 | #482A11 #653F23 #9E6D42 #D3A671 |
| White sand in daylight (a blue cast from the window) | H3 | #9E9C97 #B0C5CF #C1E1EF #D6FAFE |
| Grey-black beads | H2 | #222324 #353637 #414243 #4E4F4F #6B6C6B |
| Dyed pink-brown | V1 | #432418 #4D291C #613A2C #7D5040 |
| Dyed blue | V2 | #1E2D57 #293B67 #344B75 #3B5786 |
| Gold glitter (not sand) | H7 | #C78416 #DC9C11 #E6AA0E #EFB612 #FEDD5D |

### The thread

- The flow rate doesn't depend on how much sand is above: "The rate of flow of the sand is independent of the depth in the upper reservoir" (Wikipedia, checked). So the thread is the same from start to end: the steady thing in the picture.
- In H1 (measured): a soft column, brighter near the neck and fainter and wider lower down, 8 px of 1,280 wide halfway down and 11 px just above the cone, against a background that it brightens by 60 and then by 40 of 255. It is partly out of focus, as a thread always is in a close photo with a shallow depth of field. No grains are seen in it at a normal shutter speed.
- Over a long fall, a stream of fine grains thins as it speeds up and breaks into droplet-like clusters joined by bridges a few grains wide, from cohesion "100,000 times" weaker than water's surface tension (Royer et al., *Nature* 2009, filmed with a camera falling beside the stream; press excerpts, partly checked; the lab's own page was refused by the fetch tool). An hourglass's fall is a few centimetres, too short to show it; a screen-tall fall could show a slight beading low down, which is real.
- At the tip: a rounded top, not a point, with a faint haze of bouncing grains a little wider than the thread (H1's tip, by looking).

### The cone in the lower chamber

- Angle: dry sand 34°, wet sand 45° (Wikipedia's table, checked); "smooth, rounded sand grains cannot be piled as steeply as can rough, interlocking sands" (same, checked), so glass beads stand lower than angular sand (no figure found). H1's cone is about 30° on its right flank, measured from the photo (the camera is near level, so this is close to the true slope).
- How it grows: grains land at the tip, the top steepens past a critical angle, and a small avalanche runs down a flank and leaves it at the lower angle of repose (Pelletier et al. 2015 on dune slip faces, citing a critical angle of 34° and a repose of 32°, partly checked; an arXiv hourglass study describes "avalanches propagate down on the surface of the pile intermittently", partly checked).
- What an avalanche looks like, from a dune's slip face (S9, checked by looking): a long tongue down the slope with raised edges, the surface crinkled, the old tongues still showing beside the fresh one. On an hourglass's cone the same thing is a few millimetres wide.
- Once the cone meets the bulb's wall it rises as a column with a conical cap (V1, by looking).
- The cone's surface is a fine, even speckle of grains with soft shading: lit flank and shade flank, no hard edges (H1 at the tip).

### The crater in the upper chamber

- Sand drains from the middle: a dimple over the neck, widening into a funnel whose sides stand near the angle of repose; a crater is "a little steeper" than a pile of the same sand (Dartmouth text, partly checked).
- In a narrow glass (V1) the surface stays almost flat with a small dimple and sinks steadily. In H1's wider bulb the sand runs down the glass in a smooth funnel to the neck. In a wide flat cell it would be a clean V.
- Late in the run, the last sand clings in a ring on the steep glass just above the neck, then slides out.

### Footage

- **V1**, Alessandro Antonelli's three-minute glass on Commons (CC BY 3.0, checked): the whole run, the top sinking and the bottom rising, pink-brown sand in a wooden frame against a pale wall.
- **V2**, Nesnad's 16 s of a café's blue-sand glass (CC BY-SA 4.0, checked).
- Close slow-motion stock footage of hourglasses is plentiful (Uppbeat, Mixkit, Storyblocks: listings, partly checked) and mostly sand on black or dark red, with smoke, gold, and "dramatic" in the titles. Stock licences, not open: reference only. The scientific high-speed films (Royer et al.) were not seen.

### Reference photos

Licences are Commons' own fields, checked through its API on 2026-11-18.

| # | Photo | Licence | Shows |
|---|---|---|---|
| H1 | [Hourglass .jpg](https://commons.wikimedia.org/wiki/File:Hourglass_.jpg), Michael Himbeault (from [Flickr](https://www.flickr.com/photos/riebart/4653728769)), 2848 × 4288 | CC BY 2.0 | **the calm reference**: brown sand in a lamplit room, turned spindles in front, the thread, the cone, the funnel above |
| H2 | [Glass egg timer.jpg](https://commons.wikimedia.org/wiki/File:Glass_egg_timer.jpg), John Cummings, 3024 × 4032 | CC BY-SA 4.0 | one-piece blown glass on a windowsill, grey-black beads, a window reflected in the bulb |
| H3 | [Hourglass with sand.jpg](https://commons.wikimedia.org/wiki/File:Hourglass_with_sand.jpg), John Morgan, 1894 × 2800 | CC BY 2.0 | white sand, the glass on pivots in a brass scroll frame, low sun through blinds |
| H4 | [Wooden hourglass 2.jpg](https://commons.wikimedia.org/wiki/File:Wooden_hourglass_2.jpg) (and 3, 4), S Sepp | CC BY-SA 3.0 | a plain turned-wood frame, 25 cm tall |
| H4b | [Sanduhr2.jpg](https://commons.wikimedia.org/wiki/File:Sanduhr2.jpg), Wilhei | CC BY 3.0 | wooden frame, white sand, a white studio backdrop |
| H5 | [Half-hour sand glass MET 12102](https://commons.wikimedia.org/wiki/File:Half-hour_sand_glass_MET_12102.jpg), German, Metropolitan Museum | CC0 | a museum frame |
| H6 | [3 Hourglasses Wellcome L0011331](https://commons.wikimedia.org/wiki/File:3_Hourglasses_Wellcome_L0011331.jpg), [English hourglass L0011327](https://commons.wikimedia.org/wiki/File:English_hourglass_Wellcome_L0011327.jpg), [2 Brass hourglasses L0011325](https://commons.wikimedia.org/wiki/File:2_Brass_hourglasses_Wellcome_L0011325.jpg) | CC BY 4.0 | old frames in wood and brass |
| H7 | [Hourglass with flowing sand.jpg](https://commons.wikimedia.org/wiki/File:Hourglass_with_flowing_sand.jpg), Pauloleong2002 | CC BY-SA 4.0 | gold glitter, twisted brass posts, marble: what's garish (12.6% of the frame clipped white) |
| H8 | [Multiple hourglasses.jpg](https://commons.wikimedia.org/wiki/File:Multiple_hourglasses.jpg), Sauvagette | CC BY-SA 4.0 | tall thin glasses with coloured fills in low warm light |
| H9 | [Hourglass-MHS 1908 (black)](https://commons.wikimedia.org/wiki/File:Hourglass-MHS_1908-IMG_3768-black.jpg), Rama | CC BY-SA 3.0 FR | an object on black: median 0, what the wallpaper shouldn't be |
| H10 | [Revolving sandglass ampolleta 5.jpg](https://commons.wikimedia.org/wiki/File:Revolving_sandglass_ampolleta_5.jpg) | CC BY-SA 3.0 | a ship's glass that turns in its frame |
| V1 | [Hourglass measuring 3 minutes.ogv](https://commons.wikimedia.org/wiki/File:Hourglass_measuring_3_minutes.ogv), Alessandro Antonelli, 480 × 640, 180 s | CC BY 3.0 | the whole run |
| V2 | [Hourglass - tokyo - 2015 11 17.webm](https://commons.wikimedia.org/wiki/File:Hourglass_-_tokyo_-_2015_11_17.webm), Nesnad, 1920 × 1080, 16 s | CC BY-SA 4.0 | dyed blue sand |
| T | [Timewheel](https://en.wikipedia.org/wiki/Timewheel), Budapest | (article, checked) | a 60-ton hourglass of glass granules that runs for a year and is turned 180° on New Year's Eve by four people pulling cables, taking about 45 minutes |

## 2. Neighbouring looks

- **Layered sand: an hourglass of coloured layers, or a sand-art bottle.** Pour colours in turn and each lands as a layer on the pile's slopes, so flat bands in the top chamber come out as nested chevrons in the bottom (my reasoning from how a pile grows; a library's answer on triangles in an hourglass's lower bulb couldn't explain them, partly checked). Andrew Clemens of McGregor, Iowa, filled bottles in the 1870s to 1890s with naturally coloured sand from the bluffs near what is now Pikes Peak State Park, pressed in grain by grain without glue (Iowa Source and Smithsonian, partly checked); a [photo of one](https://commons.wikimedia.org/wiki/File:Sand_Art_Andrew_Clemens.jpg) is on Commons (CC BY-SA 4.0, checked; not downloaded). His sand is a real palette of one family.
- **Sand in a thin flat cell (a Hele-Shaw cell).** Two vertical panes 5 to 10 mm apart (partly checked). Pour a mix of small rounded and large angular grains in at one side and the pile stripes itself into thin alternating layers, a pair with each avalanche, parallel to the slope (Makse, Havlin, King and Stanley, *Nature* 386, 1997; abstract via the Bar-Ilan record, partly checked). No free photo of it was found. Ant Colony's sand tank is the same object without the falling stream.
- **Moving sand pictures.** Black and white (or coloured) sand with air bubbles in a liquid between two panes: turned over, the sand falls through the liquid in curtains and settles into layered "landscapes" (sellers' descriptions, partly checked; sold and reviewed as "relaxing", "meditative", partly checked). **Names to avoid:** *Exotic Sands* (a US trademark application for framed moving sand pictures, serial 87730711, William Tabar, who claims the original of 1985; partly checked) and Klaus Bösch's *KB Collection* and *Moving Sand Art* (movingsandart.com, partly checked); *Sandscapes* is used loosely by sellers (partly checked). It is a toy's picture, the Peg Board fault, and its settled "mountains" are a different subject: reference only.
- **A dune's slip face.** The lee of a dune stands at its angle of repose, and sand that piles past it at the brink pours down in grainflows (above). Close up (S9) it is a whole screen of pale sand with long soft tongues, 0.2% hard edges and a median of 168 as shot: as calm a texture as any measured for the app. But it has no hourglass, no filling and no restart: it is the material for the cone's flanks seen close, not a wallpaper of its own here.
- **Which reads best as a whole-screen wallpaper behind icons and windows:**
  1. **Flat glass** (the recommendation): the hourglass's own silhouette fills the screen, so it reads as an hourglass at a glance, yet most of the screen is fine sand texture, which is soft under icons. The glass is a pane with soft reflections, as in Ant Colony and Rain on Glass, so no refraction has to be faked. The layered bands show, which a round bulb hides. The risk is looking like a sand-art frame, a toy; real grains, real colours and a real room behind are what keep it a photograph.
  2. **Blown glass**, the waist close: a real glass's two funnels meet at a neck in the middle of the screen, the bulbs' walls running off the edges. H1 cropped to 16:10 at the waist measures 67 / 136 / 211 / 253 as shot and 45 / 95 / 150 / 180 at the dark caps, 0.9% hard edges. It is the most photographic, but glass is the main material in the frame, and if it reads as plastic it fails the way Campfire's fire and Sea Sparkle's surf did. The layers are hidden inside the bulbs except against the glass.
  3. A whole hourglass standing in a room, small in the middle: an object on a backdrop, Peg Board's fault (H9 is the extreme).
  4. Only the lower chamber, filling the screen from empty: it is literally "filling my background", but every cycle starts with an empty screen.
- **Shape of the flat glass on a 16:10 screen.** If its walls ran straight from the corners to a waist in the middle they would lie at 32° (atan of 0.625, my arithmetic): at the angle of repose, so sand would sit on them and never drain. A real glass's walls are steep near the neck. So the chambers' sides stand near the screen's edges and curve into a waist whose walls near the neck are steeper than about 40°, leaving two lens-shaped areas beside the neck where the room behind shows (or the frame).

## 3. Palettes and brightness

Each palette is one family. Sands are sampled at the 10th to 98th percentile of brightness from the photos in section 4, then, where given, scaled in linear light so the brightest swatch's brightest channel is 150 (dark: Jellyfish's broad-light cap) or 210 (light: Kelp Forest's 99th-percentile cap).

### Real sands, as photographed

| Sand | Photo | Swatches | Why it's that colour |
|---|---|---|---|
| Gypsum, White Sands, New Mexico | S1 (grains, scale bar 0.5 mm) | #767378 #8A8F94 #9CA1A8 #AAAEB6 #D2D2D2 | 98% gypsum (search excerpt, partly checked) |
| Gobi dune sand | S2, second sample | #63350A #96632A #B07E41 #C49353 #E6B474 | rounded quartz, a few red grains |
| Namib, Dune 45, lit face | S6 | #CF7F5A #DF8054 #E7885B; the shade face #312A33 #37323E #3C3947 | quartz with a thin iron-oxide coat, redder inland and yellow at the coast (NASA Earth Observatory; White, Walden and Gurney 2007; partly checked) |
| Namib, Sossusvlei in haze | S7 | #926961 #A48381 #B18881 | the same, at a distance |
| Bermuda pink | S3 | cream #9C816E #AA917D #B59E8B #C6B3A3; pink grains #763628 #905347 #A2665B #B77E76 | the red foraminifer *Homotrema rubrum* ground into coral sand (S3's description, checked; Wikipedia via excerpt, partly checked) |
| Pfeiffer Beach, Big Sur | S8 | #77606D #AA8088 #C29098 #D49CA4 | "garnet eroded from the hills" (S8's description, checked) |
| Garnet, Emerald Creek, Idaho | S2, eighth sample | #4B211C #6C3A33 #915A51 #E1B3A7 | "garnet sand" (the collage's description, checked) |
| Basalt, Punaluʻu, Hawaii | S5 | #3B3C3E #484949 #515252 #5F5F5E #8F8A82 | black volcanic sand |
| Olivine, Papakōlea, Hawaii | S4 | #323411 #575B28 #757B41 #949B5C #DDE0B5 | olivine, coral and basalt grains (S4's description, checked) |
| Coral Pink Sand Dunes, Utah | S2, sixth sample | #B23A05 #CC5916 #DC6C25 #EC8034 | too hot to dim |
| Oregon coastal quartz | S9 | #9A9694 #A29F9D #A8A5A3 #AEABAA #B5B2B1 | |

Grain photos (S1 to S4) are lit by a studio lamp at 1 cm across; a pile seen from a distance is the same colours softened and darker in its shade.

### Palettes to put forward

| Palette | From | Dark Mode (to 150) | Light Mode (to 210) | One family? |
|---|---|---|---|---|
| **Lamplight** (Dark default) | H1's sand and room | sand #311B09 #462A16 #6F4C2C #96754F; room #160903 #1C0C04 #211005, the lit wall behind #3A1907 #6D3C16; thread #4F290F to #694224 | (a dark look only) | **Yes**: sepia, warm on warm |
| **Gypsum** (Light default) | S1 | #535054 #616569 #6E7277 #797C81 #969696, under a cool light: the Dark alternative to Lamplight | #767378 #8A8F94 #9CA1A8 #AAAEB6 #D2D2D2 on a warm white plaster wall | **Yes**: grey-white |
| **Desert**, a shade an hour | S2's Gobi to S6's Namib | Gobi #603E18 #725027 #7F5E33 #967449, through to Namib #865038 #915134 #965638 | Gobi #895A25 #A0733B #B3864B #D2A469, through to Namib #BC7351 #CB744C #D27B52 | **Yes**: hue 19° to 33°, after the Namib's own gradient from a yellow coast to a red interior (Gobi's gold stands in for the coast, which wasn't sampled) |
| **Bermuda** | S3 | cream #766152 #806D5E #96877B, pink #58271C #7A4C43 | cream #9C816E #AA917D #C6B3A3, pink #905347 #A2665B | **Yes**: the share of pink grains can change by the hour |
| **Basalt** | S5, H2 | as sampled: #222324 #353637 #414243 #4E4F4F, lit grey on a near-black room | the same pile, dark on a pale wall (H2's look) | **Yes**: greys |
| Garnet (an option) | S2 | #2F120F #46231F #5F3933 #96766E | #451E19 #64352F #87534B #D2A79C | Yes, a jewel tone; not a default (below) |

- **What clashes or fails:** dyed blue in brown wood (V2: Lava Lamp's two families); olivine's olive (Crystals' colour at dim); Coral Pink's orange and gold glitter (too hot, too sparkly); Namib's violet shade beside its orange lit face is complementary, so keep the shade near black; blood red, since an hourglass of red sand is the "time running out" picture (my judgement; Commons even has a series titled *Bloodred Hourglass*, not looked at).
- **Warm sand at dark levels reads brown.** Kelp Forest's report found gold turns to mud at the dark caps, and that its dark looks had to be blue. Here H1 shows the other way out: it works because the whole picture, room and glass included, is one warm family lit by one warm lamp. Put warm sand in front of a cool grey or blue room and it will go muddy. Gypsum under a cool light is the blue-family dark look if Lamplight doesn't land.
- **A shade an hour.** Desert's whole range is about 15° of hue, so over a day the hours' bands would step under 1° of hue and 4 to 8 of 255 in brightness (my suggestion for "strata, not stripes"): Gobi's gold in the morning to Namib's red by night, or Bermuda's pink grains thickening, or Gypsum cream to grey. The bands are thick near the cone's middle and thin toward its flanks; each hour's equal volume makes a thinner layer as the pile grows wide and a thicker one again as it nears the narrowing neck (my geometry, unchecked).

### Brightness

Measured, as shot and scaled in linear light to the caps (median / 90th / 99th / 99.9th; hard edges are the share of pixels whose brightest channel differs by more than 24 from the pixel 2 px away, at 1,200 px wide):

| Picture | As shot | Hard edges | Scaled | Hard edges |
|---|---|---|---|---|
| H1, lamplit room, whole | 54 / 131 / 209 / 249 | 1.1% | ×0.48: 36 / 92 / 150 / 179 | 0.6% |
| H1 cropped 16:10 at the waist | 67 / 136 / 211 / 253 | 1.5% | ×0.47: 45 / 95 / 150 / 180 | 0.9% |
| H2, egg timer by a window | 128 / 205 / 233 / 255 | 3.5% | ×0.79: 114 / 184 / 210 / 229 | 3.2% |
| H3, white sand, sun through blinds | 38 / 250 / 255 / 255 (10.9% clipped) | 5.0% | ×0.30: 17 / 146 / 150 / 150 | 2.8% |
| H9, object on black | 0 / 61 / 254 / 255 | 2.4% | | |
| S1, gypsum grains | 168 / 201 / 228 / 255 | 1.0% | ×0.39: 109 / 131 / 150 / 168 | 0.2% |
| S9, Oregon slip face | 168 / 179 / 184 / 188 | 0.2% | already under the light caps | |

Targets, the app's existing caps (from Jellyfish, Kelp Forest and Canopy; not yet tried under icons, unchecked):

| | Dark Mode (Lamplight, Basalt, Gypsum cool) | Light Mode (Gypsum, Desert, Bermuda) |
|---|---|---|
| The room behind the glass | 10 to 30, warm, out of focus (H1's room is 22 to 33 after scaling) | 150 to 190, a pale plaster wall |
| Sand in shade | 25 to 50 | 90 to 130 |
| Sand lit, the cone's lit flank | up to 150 (110 is calmer) | up to 210 |
| The thread | up to 150, brighter than the room | darker than the wall: a line of grains |
| Glints: the neck, a highlight, the thread's sparkle | up to 190, a few pixels each | up to 230 |
| Whole screen | median 30 to 45, 99th ≤ 150, 99.9th ≤ 190 | median 90 to 140, 99th ≤ 210, 99.9th ≤ 230 |
| Hard edges | under 3% | under 3% |

- **Grain texture is a hard-edge risk.** Real hourglass sand is 0.1 to 0.3 mm, a pixel or two on a Retina display at life size (my arithmetic, 3,024 px across about 30 cm). Grains that differ by more than 24 of 255 from their neighbours would count every one as an edge. Keep grain-to-grain contrast to about 10 to 20 at dark levels, so the sand reads as a fine matte surface, as S1 does at 0.2%.
- **The amount of sand on screen is the same all through a cycle** in both looks put forward (what leaves the top arrives below), so the screen's brightness doesn't drift with the hour, except at the menu bar.
- **The menu bar.** The top strip starts a cycle as sand and ends it as the empty top of the glass. macOS turns the menu bar's text black once the strip under it averages about 155 (CLAUDE.md). Dark looks sit far below that throughout. In Light Mode, keep both the wall and the sand at the top above about 170, or both below about 140, so the bar's text doesn't flip mid-cycle.
- **Backdrops:** a warm room out of focus for Lamplight (the recommendation), a near-black room for Basalt, a dim desk only at the bottom edge if the frame's base shows (the Blown glass look), a pale plaster wall for Light Mode (Dappled Light already ships Poly Haven's White Stucco). No gradient: a studio sweep is the product shot, and H9's black is the object on black.

## 4. Images and textures that could ship

Only public domain, CC0, CC BY and CC BY-SA may ship (the app already ships CC BY-SA images, credited: `blackhole-credits.tsv`, `etching-credits.tsv`). Commons licences are Commons' own field, read through its API on 2026-11-18 (**checked** in that sense).

| What | Source | Licence | Use |
|---|---|---|---|
| Gypsum grains, close | S1 [WhiteSandsGypsum.jpg](https://commons.wikimedia.org/wiki/File:WhiteSandsGypsum.jpg), Mark A. Wilson, 2560 × 1920 | Public domain (Commons, checked) | a grain texture and Gypsum's colours |
| Nine sands, 1 cm each | S2 [00065 sand collage.jpg](https://commons.wikimedia.org/wiki/File:00065_sand_collage.jpg), Siim Sepp, 3000 × 3000: Kauai glass, Gobi, Estonian glauconite, Maui basalt, Molokai coral, Coral Pink Sand Dunes, California volcanic glass, Emerald Creek garnet, Papakōlea olivine (its description, checked) | CC BY-SA 3.0 (checked) | colours; grain textures |
| Bermuda coral sand | S3 [00290 IMG 6291 037 Bermuda coral sand 32 mm.jpg](https://commons.wikimedia.org/wiki/File:00290_IMG_6291_037_Bermuda_coral_sand_32_mm.jpg), Siim Sepp | CC BY-SA 3.0 (checked) | Bermuda's colours |
| Olivine sand | S4 [Olivine sand from Hawaii Island.jpg](https://commons.wikimedia.org/wiki/File:Olivine_sand_from_Hawaii_Island.jpg), Siim Sepp | CC BY-SA 3.0 (checked) | reference (olive is out) |
| Black sand beach | S5 [2020 Punaluu Black Sand Beach 02.jpg](https://commons.wikimedia.org/wiki/File:2020_Punaluu_Black_Sand_Beach_02.jpg), Farragutful | CC BY-SA 4.0 (checked) | Basalt's colours |
| Namib dunes | S6 [Dune 45 at sunrise](https://commons.wikimedia.org/wiki/File:006_Dune_45_in_Sossusvlei_at_sunrise_Photo_by_Giles_Laurent.jpg), Giles Laurent; S7 [Red dunes in the Sossusvlei region](https://commons.wikimedia.org/wiki/File:SOS_-_Red_dunes_in_the_Sossusvlei_region,_Namibia,_2007.jpg), Josep M. Gracia | CC BY-SA 4.0 (checked) | Desert's red end |
| Purple sand | S8 [Purple Sand patterns on Pfeiffer Beach](https://commons.wikimedia.org/wiki/File:Purple_Sand_patterns_on_Pfeiffer_Beach,_Big_Sur_CA_July_8th,_2016.jpg), Justin Dolske | CC BY-SA 2.0 (checked) | reference |
| Slip faces | S9 [Dune slip face (Oregon Dunes) 19](https://commons.wikimedia.org/wiki/File:Dune_slip_face_(Oregon_Dunes,_Florence,_Oregon,_USA)_19.jpg) and [28](https://commons.wikimedia.org/wiki/File:Dune_slip_face_(Oregon_Dunes,_Florence,_Oregon,_USA)_28.jpg), James St. John | CC BY 2.0 (checked) | how avalanches look |
| A Namib dune's slip face, on Mars | [PIA20281](https://commons.wikimedia.org/wiki/File:PIA20281_Slip_Face_on_Downwind_Side_of_Namib_Sand_Dune.jpg), NASA/JPL | Commons says public domain; JPL's own image-use terms not read: **unchecked** | reference only |
| Hourglass photos and footage | H1 to H10, V1, V2 (section 1) | as listed (checked) | references; H1 to match against side by side |
| Sand textures, ground scale | Poly Haven [dense_sand](https://polyhaven.com/a/dense_sand), [coast_sand_01](https://polyhaven.com/a/coast_sand_01) to 05, [gravelly_sand](https://polyhaven.com/a/gravelly_sand) and others (60 in its sand category, API checked) | CC0: "Our assets are all licensed as CC0" (polyhaven.com/license, checked) | a beach's scale, coarser than hourglass sand; maybe for normals |
| Wood for a frame | Poly Haven [american_walnut_veneer](https://polyhaven.com/a/american_walnut_veneer), [black_walnut_veneer_01](https://polyhaven.com/a/black_walnut_veneer_01) to 03, [european_walnut_veneer_04](https://polyhaven.com/a/european_walnut_veneer_04) (API checked) | CC0 (checked) | the frame, if any shows |
| A room to reflect in the glass | Poly Haven HDRIs [brown_photostudio_01](https://polyhaven.com/a/brown_photostudio_01) (Victorian, lamps), [combination_room](https://polyhaven.com/a/combination_room) (Victorian, lamp, curtains), [anniversary_lounge](https://polyhaven.com/a/anniversary_lounge) (API checked; their look not checked) | CC0 (checked) | the glass's highlights and reflections, and the room out of focus |
| The pale wall | Poly Haven White Stucco, already in the app for Dappled Light | CC0 | Light Mode's backdrop |
| Other textures | ambientCG | "All ambientCG assets are provided under the Creative Commons CC0 1.0 Universal License" (docs.ambientcg.com/license, checked) | |
| **Not free** | Sand Atlas (sandatlas.org), Siim Sepp's own site: "Images on Sandatlas.org are not free to use by default" (checked). His older uploads to Commons (S2 to S4) are CC BY-SA; the site's are not | reference only | |
| **Not free** | Stock footage (Uppbeat, Mixkit, Storyblocks, Getty) | stock licences (unchecked) | reference only |

## 5. Existing hourglass wallpapers, and calm against pressure

### What exists

- **HourGlass – Dynamic Desktop** (Mac, free, Haotian Zheng, 2021): despite the name, no hourglass: "rotating conical gradients that moves like a clock", with the time, the next event, the weather and what's playing in the corners. Two reviews, both asking for colour choices; not enough ratings to show (App Store and Product Hunt pages, checked). It matters for the name, not the look.
- **Sand Timer** ([and/sand-timer](https://github.com/and/sand-timer), MIT, macOS 13+): "A realistic hourglass ⏳ that floats on your Mac's desktop", above other windows, sand colours from purple to plain, glints, reflections and shadows, a base that shows the countdown; 4 stars on GitHub (checked). The nearest look-alike, and the opposite of this one: an object floating over the windows, and a timer.
- **Timer apps on the App Store** that run on Apple silicon Macs: *Hourglass – Physics Simulation* (kenji abe, a three-minute glass that tilts with the gyroscope; no ratings), *Real Hourglass* (ao-system, ads, 5.0 from one rating), *Sandglass3* (Keietsu Yasuhara, 1, 3 and 6 minutes, ads, 2.7 from 11 ratings) (pages checked); *Minimal Hourglass*, *Sandy Timer*, *SandMoro* (listings, partly checked). All are countdowns sold for focus or meditation.
- **Wallpaper Engine's workshop** has 95 items for "hourglass" (checked): game and anime scenes (Zelda's Phantom Hourglass, Outer Wilds' Hourglass Twins, Frieren), *God's Hourglass*, *Hourglass Skeleton*, *Hourglass Skulls*, *Simple Pixel Hourglass*, *Hourglass Clock*, *Interactive Hourglass*, *Timeless One | Hourglass*. Going by titles only (no ratings or descriptions were visible): memento mori, fantasy and pixel art. No calm, photographic one turned up.
- **Stock art and footage**: hourglasses in dark deserts, on black or dark red, with smoke, gold sand and "dramatic" in the title (listings, partly checked). That is the cliché.
- **Falling-sand games** ("a two-dimensional particle or cellular automaton based game engine", The Powder Toy, Noita; Wikipedia, checked) and the *Sandscape* screen saver on SourceForge (partly checked): pixel sand, a toy.
- No hourglass live wallpaper with reviews was found for Android or iPhone (searches, partly checked).
- **Mistakes to avoid**, from all of the above: a small object floating on black or over the windows; skulls, books, candles and other vanitas props; smoke, glitter, gold and neon; numbers, a countdown, a chime; pixel sand; anything a toy.

### Is an hourglass calming or a countdown?

- **The case for pressure.** It is the old symbol "that human existence is fleeting": on pirate flags "to evoke fear through imagery associated with death", placed in coffins, on gravestones, and in the extinction symbol "to represent time 'running out'" (Wikipedia, checked). In Dutch vanitas still lifes it sits with skulls and bubbles (the National Gallery's Treck of 1648, an overturned hourglass beside a skull; partly checked). Vanitas takes its name from Ecclesiastes (partly checked), and pulpit glasses timed sermons (Commons' *Pulpit hourglasses* category and a Wellcome "sermon glass", checked as titles): both are reasons, beyond calm, to keep any such reference out ("nothing religious"). A child psychologist warns that counting down to the end of something good raises anxiety (partly checked).
- **The case for calm.** Sand pouring through a glass is sold as sleep and meditation audio (partly checked); moving sand pictures are reviewed as "peaceful", "grounding" and "meditative" (partly checked); a watch writer found sand "cascading through an hourglass ... relaxing and enjoyable" (Quill & Pad, checked). The evidence on both sides is anecdote and marketing; the one study found (visual timers lowering maths-test anxiety) is a preprint and about a different object (partly checked).
- **So the design decides it.** What I'd do:
  - **A long glass.** A day by default, so the sand's level never maps onto minutes left. An hour (the real "hour glass") or a working day as options. The Timewheel runs for a year.
  - **Turn it unseen.** The turn waits for the displays to sleep or the screen to lock once the glass is nearly out (the app already rebuilds stale wallpapers at sleep: `refreshIfStale`); if they never sleep, a slow turn, a minute or more. No moment of "time's up": the last trickle is never the point.
  - **Never at a deadline.** No turn at five o'clock, no alignment with the working day's end.
  - **No numbers, marks, scale, chime or sound.** Nothing that reads the time off it.
  - **Accumulation, not depletion.** The day's bands building in the lower chamber are the record of time spent, the thing to look at; the upper chamber is yesterday's, turned over.
  - **No red by default, no props**, no skull, no candle, no book.

## 6. Names

Checked against the App Store, Google Play, GitHub and the web (no trademark database: Justia's search refused the fetch tool), and against the other wallpapers' names in `docs/README.md`'s table.

- **Hourglass** (recommended). Plain and in the house style: the thing's own name, like Lava Lamp, Fish Tank and Ant Colony. It sorts between Galaxy and Jellyfish and looks like no other wallpaper's name. Collisions: *HourGlass – Dynamic Desktop*, a free Mac desktop-wallpaper app (checked), the closest that matters; *Hourglass*, the luxury cosmetics brand founded by Carisa Janes in 2004 and bought by Unilever in 2017 (Cosmetics Business, checked), a different field; *Hourglass*, Chris Dziemborowicz's free Windows timer, now forked by Ivan Ivon under MIT (download listings, partly checked); and many timer apps. As a scene's name inside Atrium it describes what is shown; it should not go in the App Store keywords or the app's own name. Trademark registrations not searched: **unchecked**.
- **Sandglass** (fallback). The older English word, and the sailor's (Commons files the ship's glasses as *Marine sandglass*, checked as titles; the Met calls its pieces "sand glass", checked as Commons titles). Collisions: *Sandglass3*, an iPhone timer (checked), and *Sandglass for Paddlers*, a GPS app (partly checked). Less familiar to most people, and it would sit beside Rain on Glass as a second "glass" in the list.
- **Sand Timer**: avoid. A kitchen or classroom countdown by name, the opposite of calm, and the name of the MIT Mac app that floats a realistic hourglass over the windows (checked) and of several timer apps.
- **Also avoid:** *Sandfall* (Sandfall Interactive, the studio behind *Clair Obscur: Expedition 33*, Game of the Year at The Game Awards 2025, partly checked; and an Android hourglass timer, *Hourglass Timer 'Sandfall'*, name checked); *Falling Sand* (a game genre, checked); *Sands of Time* (a cliché, and Ubisoft's *Prince of Persia: The Sands of Time*, unchecked); *Exotic Sands*, *KB Collection*, *Moving Sand Art* (brands of sand pictures, above).
- **Inside the app:** Ant Colony already has looks named *Sand* and *White Sand*, so this one's palettes are named by place or material (Gypsum, Desert, Bermuda, Basalt, Lamplight), not "White Sand".

## Not verified

- Hourglass glass thickness; ballotini sizes and their angle of repose; how layers thin and thicken in a cone (my geometry).
- Royer et al.'s films, Makse et al.'s cell, the Ménagier's recipe, the dune angles and the Namib's gradient: each seen only in search excerpts, though the sources agree.
- The look of the three Poly Haven HDRIs named, and whether their lamps make good highlights in glass.
- JPL's image terms for PIA20281; the stock sites' licences.
- Trademarks for HOURGLASS and SANDGLASS in software classes; any state or foreign marks.
- Whether these caps keep icons readable over a screen half full of sand: to try on a real desktop.

## Sources

- The hourglass: https://en.wikipedia.org/wiki/Hourglass ; https://quillandpad.com/2014/09/01/glass-nostalgia-and-the-ikepod-hourglass/ ; https://en.wikipedia.org/wiki/Timewheel ; https://fieldnotes.makingandknowing.org/pre-2018-Fall/SP15_PopeandMarrisFieldNotespowderforhourglasses.html ; the Ménagier (search excerpts): https://makingandknowing-prototype.cul.columbia.edu/index.html%3Fp=1463.html ; Ikepod: https://www.dezeen.com/2011/03/24/the-hourglass-by-marc-newson-for-ikepod/ , https://watchesbysjx.com/2011/04/the-ikepod-hourglass-by-marc-newson.html
- Granular physics: https://en.wikipedia.org/wiki/Angle_of_repose ; Royer et al. 2009 (excerpts): https://news.uchicago.edu/story/streaming-sand-grains-help-define-essence-liquid , https://physicsworld.com/?p=20833 ; Fan et al. 2024: https://arxiv.org/abs/2407.21685 ; Pelletier et al. 2015: https://openaccess.city.ac.uk/id/eprint/12538/ ; Makse et al. 1997: https://cris.biu.ac.il/en/publications/spontaneous-stratification-in-granular-mixtures/ , https://arxiv.org/pdf/cond-mat/9809428 ; Dartmouth text on craters: https://cushman.host.dartmouth.edu/books/PracticalFM/Chap16.pdf ; https://ebrpl.libanswers.com/faq/15795
- Sands: https://en.wikipedia.org/wiki/Homotrema_rubrum ; https://bios.asu.edu/currents/our-unique-pink-sand ; https://earthobservatory.nasa.gov/images/146138/sandscapes-of-the-namib-desert ; https://centaur.reading.ac.uk/4224/ ; https://www.sandatlas.org/about/
- Sand art: https://www.iowasource.com/2022/06/03/sand-paintings/ ; https://www.smithsonianmag.com/blogs/smithsonian-american-art-museum/2023/04/06/the-wonder-and-precision-of-sand-art/ ; https://trademark.justia.com/owners/tabar-william-3728114 ; https://movingsandart.com/pages/faq
- Look-alikes: https://apps.apple.com/cn/app/id1577295106 ; https://www.producthunt.com/products/hourglass-4/reviews ; https://github.com/and/sand-timer ; https://apps.apple.com/us/app/-/id6670490622 ; https://apps.apple.com/us/app/id6758259094 ; https://apps.apple.com/us/app/sandglass3/id386488183 ; https://play.google.com/store/apps/details?id=com.psyk.sandfall ; https://steamcommunity.com/workshop/browse/?appid=431960&searchtext=hourglass ; https://en.wikipedia.org/wiki/Falling-sand_game ; https://sourceforge.net/projects/sands/ ; https://uppbeat.io/stock-video/asset/close-up-of-sand-pouring-in-hourglass-23663 ; https://mixkit.co/free-stock-video/hourglass
- Calm and pressure: https://nationalgallery.org.uk/paintings/NG6533 ; https://learnwithdremily.substack.com/p/but-timers-make-my-kid-anxious ; https://www.timetimer.com/blogs/news/how-to-help-kids-manage-time-without-causing-more-anxiety ; https://www.audioscrape.com/podcast/deep-sleep-white-noise-soundscapes/episode/sand-pouring-through-an-hourglass-the-slow-passage-of-time-for-relaxation-45200 ; https://ca.trustpilot.com/review/sandarthome.com
- Names: https://cosmeticsbusiness.com/unilever-to-acquire-hourglass-in-first-cosmetics-deal--130677 ; https://github.com/i2van/hourglass ; https://majorgeeks.com/files/details/hourglass.html ; https://www.cnc.fr/web/en/news/the-story-behind-clair-obscur-expedition-33_2419300
- Licences: https://polyhaven.com/license ; https://docs.ambientcg.com/license/ ; APIs searched: https://commons.wikimedia.org/w/api.php (Category:Hourglasses and searches), https://api.polyhaven.com/assets
- Reference photos and footage: the links in sections 1 and 4, each licence read from Commons' own field on 2026-11-18.
