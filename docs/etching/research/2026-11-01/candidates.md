# Etching: the research round of 2026-11-01

Dave, of the wallpaper his testers liked best: "lets add more etchings, like old public domain maps, not just from US but from Europe too, old blueprints, anything you can think of". Then, of maps: "The actual text on the map is not the important part, just etching out detectable land masses and river pathways on larger scale would be fine. and yes I do not want you drawing churches or anything religious"; and "how about like old world war 2 airplane and ship designs, again from US and Europe". He asked that the ones not used be kept here for later: "dont throw away the ones we dont use, store the images in our git history so we can review them in the future".

Four researchers (art and natural history, blueprints and engineering, WWII aircraft and ships, maps) each baked their best at both widths. The contact sheets show every candidate as the route draws it on Paper, standard on the left and fine on the right: `art.jpg` (4 across: A1 to A10 then R1 to R4), `blueprints.jpg`, `wwii.jpg` and `maps.jpg`. `candidates.py` has every one's bake entry; the source files were downloads and are not kept, but each entry gives its address. Minutes are at speed 1, standard / fine, fitted.

**Dave's picks** (2026-11-01) are marked ✓. The rest wait here.

## Art and natural history

| | Picture | Source and licence | Minutes | Notes |
|---|---|---|---|---|
| ✓ A1 | Venus Comb: Hollar, "Schelp, murex pecten", 1644–52 | Rijksmuseum RP-P-1992-16, Public Domain Mark | 51 / 98 | |
| A2 | Penman's Ship: Jan van de Velde I, *Spieghel der Schrijfkonste*, 1605, a ship in pen flourishes | The Met 358328, CC0 | 30 / 43 | |
| A3 | Unicorn: woodcut after Gessner, *Historiae animalium*, 1551 | Wellcome V0021193, PDM | 50 / 90 | |
| A4 | The Gorgon: Topsell, *Historie of Foure-footed Beastes*, 1607 | Wellcome L0028396, PDM | 66 / 119 | |
| ✓ A5 | Sea Serpent: woodcut after Gessner, 1613 | Wellcome V0021194, PDM | 62 / 123 | |
| A6 | Fujimigahara: Hokusai, c. 1830–32 | The Met 36500, CC0 | 64 / 118 | |
| ✓ A7 | Labyrinth Garden: after Le Rouge, *Jardins anglo-chinois*, 1776 | Rijksmuseum RP-P-1964-1839, PDM | 95 / 184 | longest in the set |
| ✓ A8 | Nautilus: Hollar, "Schelp, nautilus pompilius" | Rijksmuseum RP-P-OB-11.659, PDM | 48 / 99 | |
| ✓ A9 | Horse Skeleton: Stubbs, *The Anatomy of the Horse*, Tab. I, 1766 | The Met 359031, CC0 | 30 / 52 | rough at standard |
| A10 | Megatherium: Mutlow, 1809 | Wellcome V0016986, PDM | 38 / 68 | |
| ✓ R1 | Giant Clams: Hollar, "Schelp, hippopus hippopus" | Rijksmuseum RP-P-1920-2772, PDM | 82 / 167 | |
| ✓ R2 | Elephant: after Gessner, 1551 | Wellcome V0021192, PDM | 51 / 116 | 1.28 : 1, kept whole |
| ✓ R3 | Fuji from the Sea: Hokusai, *One Hundred Views of Mount Fuji* vol. 2 | The Met 57793, CC0 | fine only, 99 | |
| R4 | Sawyers, Tōtomi: Hokusai, *In the Mountains of Tōtomi Province* | The Met 36505, CC0 | fine only, 146 | |

Licences as read: The Met's object API, `"isPublicDomain": true`; the Rijksmuseum's `id.rijksmuseum.nl/<id>` (as JSON-LD), the image "Public Domain" → creativecommons.org/publicdomain/mark/1.0/; Wellcome's catalogue API, "Public Domain Mark", credit "Wellcome Collection".

Dropped: Hiroshige's *Shōno* and Canaletto's *Malghera* (baked: muddles; Malghera also has bell towers); Piranesi's *Colosseum* (a cross in the arena), *Carceri*, *Pyramid of Cestius* and *Ponte Lugano* (dense tone); Rembrandt's *Omval* and *Canal with a Large Boat* (sparse, church spires); 35 more Hollar shells (fewer fill the plate); Gessner's ox and otter, Topsell's Sagoin and Simivulpa (weaker); Hawkins's *Plesiosaurus* (tonal); the Hokusai *Manga* (many small figures). Not reached: an Asian holder, Haüy, guilloché, Jules Verne, *Scientific American*, Doré.

Found: `flatten="paper"` takes a colour print's graded sky to bare paper and keeps its lines (Fujimigahara, Tōtomi).

## Blueprints and engineering

| | Picture | Source and licence | Minutes | Notes |
|---|---|---|---|---|
| ✓ B1 | Garabit Viaduct: Eiffel, *Notice sur le viaduc de Garabit*, 1888 | Internet Archive TA624282EIF leaf 0034 (uploaded by the University of Seville's library), `licenseurl` Public Domain Mark | 29 / 46 | fine has stray lines in the sky |
| ✓ B2 | Harbour Crane: "Mr. Kier's Moveable Crane … Ramsgate", Mutlow, 1802 | Wellcome V0024542, PDM | 31 / 59 | |
| ✓ B3 | Locomotive: Armengaud, *Moteurs à vapeur*, Pl. 38, Buddicom's locomotive-tender, 1862 | Internet Archive CHEPFL_LIPR_AXB233_03 leaf 0082 (EPFL), PDM | 68 / 117 | |
| ✓ B4 | Steam Plough: Usher's patent, C. J. Light, 1852 | Wellcome V0024680, PDM | 29 / 52 | |
| ✓ B5 | Schooner: HAER MA-168 sheet 2, the *Ernestina* (1894), drawn 2009 | Library of Congress, HAER: federal; the sheet asks for credit to "Historic American Engineering Record, National Park Service, name of delineator, date of drawing" | 21 / 28 | 1.28 : 1, kept whole; a modern drawing |
| ✓ B6 | Lake House: H. L. Gay, house for S. W. Allerton, Lake Geneva, c. 1884 | Art Institute of Chicago 215760, "CC0 Public Domain Designation" | 61 / 94 | finial and weathervane painted out |
| ✓ B7 | Neuilly Machine: Perronet, Pl. XVI, 1782 | Internet Archive chepfl-lipr-axd-20-01 leaf 0117 (EPFL), PDM | 90 / 167 | |
| ✓ B8 | Sawmill: van Zyl, *Theatrum machinarum universale*, Pl. LI, 1734 | Internet Archive chepfl-lipr-axd-19 leaf 0182 (EPFL), PDM | fine only, 104 | |
| ✓ B9 | Crawler Tractor: B. Holt, US patent 874,008, 1907 | US Patent and Trademark Office | 27 / 54 | noisy scan; a "12" to paint out |

Reserves, not baked: Sully's wheel-cutting engine (*Encyclopédie*, Wellcome V0023819, PDM); the *Ernestina*'s hull framing, HAER sheets 15 to 17. Dropped: a Cooper Hewitt locomotive (a watercolour: blobs); the Brooklyn Bridge's one HAER sheet (a thin strip); patents of Sholes, Singer, Otis, Hoe, Hallidie, Ericsson (small, crowded or upright); Wellcome's railway bridges and aqueduct (very wide strips) and windmills (upright); Adler & Sullivan's station (dimension lettering); van Zyl's wheel plans at leaves 113 and 125 (star-like polygons). Not reached: Harrison, Middendorf, Telford, Belidor, Leupold (no licence field), the Deutsches Museum, TU Berlin, SMK, Nationalmuseum, NARA's cyanotypes (needs an API key).

## WWII aircraft and ships

| | Picture | Source and licence | Minutes | Notes |
|---|---|---|---|---|
| ✓ W1 | Bombing Airplane: Boeing, design patent D97,355, 1935, plan view (the B-17) | US Patent and Trademark Office | 21 / 34 | |
| ✓ W2 | Elliptical Wing: NACA Wartime Report L-334, 1942, plan view (the Spitfire) | NASA's report server, "Work of the US Gov. Public Use Permitted." | 12 / 21 | |
| ✓ W3 | Jet Fighter: Lockheed, D143,822, 1944 (the P-80) | USPTO | 17 / 27 | |
| ✓ W4 | Attack Bomber: Douglas, D128,027, 1939 (the A-20) | USPTO | 25 / 47 | |
| W5 | Pursuit Airplane: McDonnell, D134,426, 1942 (the XP-67) | USPTO | 31 / 54 | |
| ✓ W6 | Torpedo Boat: Föreningen Sveriges Flotta's model drawing of a 20 m Swedish motor torpedo boat, 1946 | Sjöhistoriska museet; CC BY-SA 4.0 as read at Europeana's copy of the record (916109/smm_sm_object_2003_23_2_1), **to be read at DigitaltMuseum 011024769716 before it ships** | 34 / 51 | |
| ✓ W7 | Airliner: Lockheed, D92,654, 1934 (the Electra) | USPTO | 16 / 27 | |
| ✓ W8 | Twin-Tail Bomber: Consolidated, D129,529, 1940, plan view (the B-24) | USPTO | 16 / 23 | |
| W9 | Liberty Ship: HAER VA-132 sheet 19, the lines of the *Arthur M. Huddell* | Library of Congress, HAER: federal | 27 / 32 | 2.39 : 1, kept whole |

Names: Dave chose plain names over the aircraft's own (some are trademarks). Dropped: the P-47 (stippled), the P-61 (overlapping figures), Lockheed D116,094 (2.1 : 1), the Liberty ship's outboard profile (dashed interior lines), USS *Missouri* (6 : 1), NACA's Hurricane and Mosquito (crowded with dimensions), the Focke helicopter (photographs only), Swedish destroyer sheets (faint, or 7 : 1). British wartime drawings are mostly Crown copyright until 2039; the National Archives' Open Government Licence is not on the list.

## Maps

| | Picture | Source and licence | Minutes | Notes |
|---|---|---|---|---|
| ✓ M1 | Crater Lake: J. H. Renshawe, USGS, *Panoramic view of the Crater Lake National Park*, [1914?] | Leventhal Map & Education Center (commonwealth:4m90fc93t), "No known copyright restrictions." / "No known restrictions on use." | 74 / 140 | |
| M2 | Romsdal Fjords: *Kart over Romsdals Amt (sv)*, 1884 | Kartverket (mapId 123): "Historical maps older than 100 years are considered public domain. We still request that the users make the appropriate credit…" | 93 / 171 | tiny church crosses on the sheet, painted out by `specks` |
| M3 | Toroweap: W. H. Holmes, Dutton's *Atlas … Grand Cañon District*, Sheet V, 1882 | Internet Archive atlasaccompanym00dutt, "Public domain. The BHL considers that this work is no longer under copyright protection."; USGS | 73 / 103 | |
| M4 | Marble Canyon: Holmes, the same atlas, Sheet XIX | as M3 | 64 / 91 | |
| ✓ M5 | Sognefjord: *Kart over Nordre Bergenhus Amt (sø)*, 1874 | Kartverket (mapId 93), as M2 | 87 / 168 | church crosses as M2; check fine at 1:1 |
| ✓ M6 | Iceland: Þorvaldur Thoroddsen, *Geological map of Iceland*, 1901 | Leventhal (commonwealth:ht250b06s), as M1 | 57 / 96 | 1.43 : 1 |
| ✓ M7 | Mississippi Meanders: H. N. Fisk, plate 22 sheet 6, Mississippi River Commission, 1944 | LSU's scan, no rights line; US government work. Dave: ship, credited | 66 / 122 | church symbols on the base map; check at 1:1 |
| ✓ M8 | Yosemite Valley: attributed to Clarence King, c. 1870–72 | Leventhal (commonwealth:4m90fc56p), as M1 | 48 / 89 | |
| R1 | Mount Desert Island: Des Barres, *The Atlantic Neptune*, 1776 | Leventhal (commonwealth:3f462w459), as M1 | 46 / 82 | count the compass rose's points |

Dave on the holders whose words are not "public domain" (Leventhal, Kartverket, Fisk's host): "Ship, credited". Dropped: Holmes's Sheets VI (tonal) and IX (thin strips); Holmes on Commons as "IA dr_…" (David Rumsey's scans, NC); the Gulf Stream chart (CC BY-NC-SA at Leventhal); the USGS relief map of 1911 (a grid of squiggles); the Sierra Nevada of 1870; Mount Rainier of 1914 (colour bands); the Bright Angel quadrangle (lettering tangles the contours); Keller's *Schweiz*. Not reached, the hosts blocking scripts: the Dufour map (swisstopo's own licence, not on the list), the National Library of Scotland, the Library of Congress (the Lewis and Clark map), NYPL; moon and Mars maps had no allowed holder found.
