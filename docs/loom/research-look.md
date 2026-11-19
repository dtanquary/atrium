# Loom: the look research

A research agent's report, written 2026-11-18, on what cloth being woven should look like on the desktop: the real cloth and the loom, palettes in one dye family with their brightness, the public-domain drafts and what their names say, the scale that reads at 1512 × 982 points and at the menu's 89 × 58-point tile, the name, and the risks to the look. How to draw and move it is in [research-method.md](research-method.md). Nothing is built.

**How to read the marks.** **Checked** means the page named (or its API record) was read on 2026-11-18 and says so. **Partly checked** means only a search engine's excerpt of the page was seen. **Unchecked** means no page was read that says it. A Commons licence marked checked is the file's own licence field, read through Commons' API, and is only as good as the uploader's claim. Hex values, brightness and edge figures are **my samples**, measured by small Python scripts on copies downloaded to the session's scratch folder (`$TMPDIR`-style, outside the repo, with a licence note beside them; nothing is in the repo). Brightness is the brightest of R, G and B out of 255, as in [kelp-forest/research-look.md](../kelp-forest/research-look.md). "Hard edges" is that report's measure (the share of pixels differing by more than 24 from a neighbour 2 px away, at 1,200 px wide); "busy" is `docs/meander/measure/busy.py` (at 1,920 px), the measure Peg Board's doc used.

## Summary and recommendation

1. **The cloth to copy is the American overshot coverlet and its calmer cousins.** A fine cream cotton ground in plain weave, with a thick soft wool pattern weft floating over it in blocks: three tones (solid, half-tone, ground), so a motif's edge is feathered by the weave itself. Summer-and-winter is the calm one: Atwater (1928, checked) writes that it gives "a softened and subdued effect ... There is no sharp contrast between ground and figure." Double weave in two blues (the Met's 1836 coverlet 13644) is the calmest real piece found.
2. **What makes it read as cloth:** round threads shaded across their width, wool floats that bulge and are hairy at the edges, a fine ground showing between them, irregular spacing and thickness, colour that varies thread to thread. Without those it reads as a drawdown, which is pixel art.
3. **Brightness is not the problem; contrast and edges are.** A cream ground at 215 to 225 is in line with what Dave already runs in Light Mode (Etching's paper, measured median 234; Flowing Gradient's light look, 230). But real coverlets are the busiest pictures measured for this app: overshot at a desktop-like 80 cm across scores 37 to 66% on `busy.py`, against 11.1% for Game of Life's Classic look ("so crazy on the eyes") and 16.9% for Etching. That is the Zen Garden risk, "bright and sharp", and it comes from dark navy on white at full contrast.
4. **Palettes, one dye each, sampled from museum pieces (section 2):** *Indigo* (cream ground, pale to deep blue), *Blue on Blue* (Dark Mode: the Met's double weave as photographed sits at a median of 35 and a 99th percentile of 118, inside Nebula's caps unscaled), *Madder* (cream, rose, brick, deep red, held short of Turkey red), *Madder Dark*, *Walnut* (cream, tan, umber), *Weld* (cream, gold, olive; Light Mode only, as gold dims to mud), *Undyed* (cream, oatmeal, grey, black-brown). Red and blue on white, the classic coverlet, is two families: offer it as a choice to judge, never the default.
5. **Caps:** Light Mode ground at most 225, the 99th percentile at most 230, nothing at 255, a median of 150 to 190; Dark Mode a median of 25 to 45, broad pattern at most 120 to 150, nothing above 190.
6. **Drafts:** the best source is Mary Meigs Atwater's *Shuttle-Craft Book of American Hand-Weaving* (Macmillan, 1928): about 300 numbered historic drafts, public domain in the US (HathiTrust marks its 1940 printing "pd", checked), and everywhere life + 70 applies from 1 January 2027, six weeks from now (she died 5 September 1956, checked). Eliza Calvert Hall's *A Book of Hand-Woven Coverlets* (1912) is public domain everywhere (checked) and holds the richest list of pattern names. Bronson (1817) is public domain by age. Hargrove (1792) has no open scan. handweaving.net's transcriptions sit behind a subscription with no terms page found: transcribe our own from the scans.
7. **Names:** of the pattern names, many are religious (Rose of Sharon, Star of Bethlehem, Church Windows, Job's Trouble, Walls of Jericho, Saint Ann's Robe) or political and military (Whig Rose, Lee's Surrender, Confederate Flag, Indian War, Braddock's Defeat). Plenty are safe and lovely (Sunrise on the Walls of Troy, Lover's Knot, Snail Trail, Cat's Paw, Pine Bloom, Four Snowballs). Show only a screened list, or none.
8. **Scale:** a warp end of about 1.5 points (3 px on Retina) shows about 85 cm of cloth across a 14-inch screen, 2.4 to 14 repeats at real repeat sizes (6 to 36 cm), and reads like the Art Institute's close-up of real wool. At the menu tile the pattern still reads if the threads are averaged, and breaks into moiré if they are sampled.
9. **The name:** "Loom" is an ordinary word and probably safe in law here, but it is the name of Atlassian's screen recorder, which runs on Macs. **Weaving** is the plain, safe choice for every look; **Coverlet** if the looks stay with coverlets. Avoid Diné (Navajo) designs, kente, tartans and ritual ikats as patterns.
10. **Worst risk:** busy, sharp, high-contrast cloth over the whole desktop, with a regular thread lattice that shimmers as it rolls and when reduced. Mock up contrast and thread size first.

## 1. What the real thing looks like

### The coverlets

- **Overshot** is the American coverlet most woven at home: a plain-weave (tabby) ground of fine cotton or linen, and a second, thick wool weft that floats over the ground in blocks, tied down where the threading changes block (AIC records describe them as "plain weave with supplementary patterning wefts (overshot)", checked). Where a block is up the wool shows solid; where it is down, the wool passes under; along the block's edges it crosses the ground in short dashes, the **half-tone**. So every motif is three tones, and its edge is soft by structure. Coverlets were woven in two strips about 42 inches wide, three yards long, seamed up the middle, with borders 10 to 14 inches wide, the warp of 24/3 cotton "set at 30 threads to the inch" (Atwater 1928, pp. 75 and 129, checked in the Internet Archive's text): 11.8 ends a centimetre.
- **Repeat sizes** read from the Art Institute of Chicago's records (checked): 7.5 × 5.8 cm (a small snowball pattern, 66024), 14 × 13.4 (84218), 17.5 × 16 (72026), 21.6 × 16.9 (150608), 23.4 × 18.4 (150611), and 35.7 × 33.3 cm for a summer-and-winter (150700). So a repeat is 6 to 36 cm.
- **Summer-and-winter** binds its pattern weft every fourth end ("over three threads and under the fourth", Atwater p. 207, checked), so there are no long floats and no sharp contrast (her words, above). The usual story is that its two faces are each other's negatives, light for summer and dark for winter (unchecked). If true, the Light and Dark Mode looks could be the two faces of one cloth: real, and a neat fit.
- **Double weave** (doublecloth) is two layers that trade places to make the figure, each solid. The Met's 1836 coverlet from New York, [13644](https://www.metmuseum.org/art/collection/search/13644), is two blues of indigo, deep navy and a lighter dip, one family by nature. Welsh *carthenni* are double cloth too, often navy and cream ([Commons: Manylyn gwely carthen Gymreig](https://commons.wikimedia.org/wiki/File:Manylyn_gwely_carthen_Gymreig.jpg), CC BY-SA 4.0, checked).
- **Jacquard figured coverlets** (1820s on) are pictures, not drafts: roses, eagles, houses, lions, and corner blocks with the weaver's and owner's names and the year ("Mary Ann Wood", "Marvett S. Dickerson 1841" on Met 13641 and 17714). They are beautiful and stark, white on navy. Out as patterns: the eagles and "Liberty" borders are patriotic, the inscriptions name real people, and they don't come from drafts. Their palettes are fair to sample.
- **Twills and the Scandinavian weaves** (rosepath, goose-eye, herringbone, *drall*): small, all-over, calm, and at desktop scale nearly a texture. A plant-dyed Swedish rosepath ([Commons: Väv, Rosengång vepa växtfärgad](https://commons.wikimedia.org/wiki/File:V%C3%A4v,_Roseng%C3%A5ng_vepa_v%C3%A4xtf%C3%A4rgad.jpg), CC BY-SA 3.0, checked) is all browns and madder-browns; a Danish *drall* on the loom ([Commons: Vav drall Hans Jorgen Gregersen](https://commons.wikimedia.org/wiki/File:Vav_drall_Hans_Jorgen_Gregersen.jpg), CC BY-SA 3.0, checked) is grey and white blocks: the undyed look.
- **Kasuri (Japanese ikat)**: the pattern is dyed into the threads before weaving, so it arrives with feathered, slipping edges, the softest pattern edge of any weave ([Commons: Kasuri detail 1](https://commons.wikimedia.org/wiki/File:Kasuri_detail_1.jpg), CC BY-SA 4.0, checked). Folk cotton in indigo, not a sacred cloth, but see section 5 for other ikats.

### Thread scale

- **The Art Institute's close-up of an overshot coverlet**, New Hampshire, c. 1840, cotton, linen and wool, in gold and olive ([66024](https://www.artic.edu/artworks/66024), CC0, checked), is the reference for thread scale. Measured: about 31 to 33 px a centimetre (its 7.5 × 5.8 cm repeat is 230 × 192 px), a pattern pick and its tabby pick together about 8.5 px. At that scale: the wool floats bulge like small pillows, their ends round and hairy, packed so tight the blocks look embossed; a stray fibre crosses into the ground; the white ground shows between floats as fine straight lines; the half-tone is a row of thin brown dashes between white picks; no two floats are the same length or the same shade. Hall (1912, checked) says of indigo coverlets that "the blue designs 'stand out' from the background of dazzling white and the coverlet becomes apparently a square of embossed velvet".
- **At about 14 px a centimetre** (the Met's full-size photograph of [13635](https://www.metmuseum.org/art/collection/search/13635): 3,564 px for 259 cm), a warp end is about a pixel. The floats still read as dashes and the cloth still reads as woven, but the ground is mottle. This is where cloth starts to turn into pattern.
- **A whole coverlet at web size** (about 1.5 px a centimetre) is pattern only: it reads as a printed or pixel design.
- So, my reading: cloth reads as cloth while a ground thread is at least about 2 to 3 px and a pattern pick at least about 4 px on screen, with shading across each. Below about 1.5 px a regular thread lattice turns to mottle or moiré; below about 0.5 px it averages to flat colour.

### What makes it soft cloth and not a pixel grid

From the close-ups (my description):

1. **Threads are round.** Each is lit on its crown and darker at its sides; each float darkens where it dives under. Cells of flat colour are what reads as pixels.
2. **Wool is hairy.** A halo of fibre softens every float's edge and partly bridges the gaps. Cotton and linen ground is smoother and slightly lustrous; wool is matte.
3. **Nothing is regular.** Handspun is thick and thin (slubs); the beat varies, so pick spacing drifts and leaves faint horizontal bands; the reed leaves warp ends in faint pairs; floats push their neighbours aside so the half-tone dashes bow; an indigo dip is uneven, so the blue varies thread to thread.
4. **Pattern edges are stepped at the thread's own size, never finer.** In overshot the half-tone feathers them; in kasuri the dye bleeds along the thread.
5. **The edges of the cloth:** selvedges slightly wavy and drawn in narrower than the warp in the reed, a centre seam where two strips can be a pick or two out, a border, fringe.
6. **No pure white and no pure black.** Natural cotton and linen are cream to oatmeal; indigo's darkest is a deep blue, not black.

### The loom in progress

- **The weaver's view** ([Commons: Loom with a view of Skye](https://commons.wikimedia.org/wiki/File:Loom_with_a_view_of_Skye.jpg), Melissa Highton, CC BY-SA 4.0, checked, a small 480 × 640 photo): the cloth nearest you, wound toward the front beam; the boat shuttle resting on the cloth; the fell, the edge of the last pick beaten in; then the reed in its beater, a bar of fine wires that spaces the warp; then the warp running away to the shafts and back beam, the threads parallel, taut, slightly paler and more open than the cloth.
- **A fell close up** ([Commons: Warp in Progress](https://commons.wikimedia.org/wiki/File:Warp_in_Progress.jpg), John Hritz, CC BY 2.0, checked; its rug's design is Southwestern and is *not* one to copy): the cloth is dense below the fell, the bare warp above it a field of evenly spaced lines you can see through.
- **A wooden floor loom whole** ([Commons: Loom - Ethnographic center, Torzhok](https://commons.wikimedia.org/wiki/File:Loom_-_Ethnographic_center,_Torzhok.jpg), CC0, checked).
- **Overshot alternates two shuttles:** a fine cotton tabby pick, then a thick wool pattern pick (Atwater, as above). So the pattern really does grow a row at a time, and a motif appears half-made at the fell before it closes, most drafts being woven symmetric ("as drawn in").
- **Real speed**: a hand-thrown shuttle manages roughly 20 to 40 picks a minute (unchecked; the method report has the numbers). At about 12 picks a centimetre that is 2 to 3 cm a minute: a 15 cm repeat in five to seven minutes. Calm by nature.
- **Rolling on is a real event:** the weaver weaves a hand's length, then releases the warp and winds the cloth forward, and the fell comes back toward her. Many pieces were woven on one long warp, one after another. So the screen never needs to be empty: the next cloth begins on the same warp, directly after the last ([Always something to see](../README.md#daves-direction-so-far)).

### Reference images

Licences checked as noted. Kept for the look, not to ship.

| # | Piece | Licence | Shows |
|---|---|---|---|
| M1 | [Met 13644](https://www.metmuseum.org/art/collection/search/13644), coverlet, New York, 1836, wool | CC0 (`isPublicDomain` in the Met's API, checked; the Met's Open Access README, [github.com/metmuseum/openaccess](https://github.com/metmuseum/openaccess), says such works carry CC0, checked) | **blue on blue**, two indigos, the calmest piece |
| M2 | [Met 14195](https://www.metmuseum.org/art/collection/search/14195), Southport, NY, 1833, jacquard | CC0, as M1 | indigo on white: the stark case |
| M3 | [Met 13639](https://www.metmuseum.org/art/collection/search/13639), *Wheel of Fortune* variation, c. 1820, overshot | CC0, as M1 | dark brown on cream, the busiest piece |
| M4 | [Met 13635](https://www.metmuseum.org/art/collection/search/13635), c. 1825, overshot | CC0, as M1 | rust and navy on tan; floats at 14 px/cm |
| M5 | [Met 13636](https://www.metmuseum.org/art/collection/search/13636), Peter Leisey, c. 1838–40, Biederwand | CC0, as M1 | Turkey red, saturated: what's too hot |
| M6 | [Met 13640](https://www.metmuseum.org/art/collection/search/13640), c. 1840–50, wool | CC0, as M1 | deep madder on near-black: Madder Dark |
| M7 | [Met 13602](https://www.metmuseum.org/art/collection/search/13602), 1844 | CC0, as M1 | madder red on a warm cream |
| M8 | [Met 13601](https://www.metmuseum.org/art/collection/search/13601), *Four Snowballs* with pine-tree border, c. 1830 | CC0, as M1 | a named overshot, a border (black and white photo) |
| A1 | [AIC 66024](https://www.artic.edu/artworks/66024), New Hampshire, c. 1840, overshot | CC0 ([AIC Open Access](https://www.artic.edu/open-access/open-access-images): "available under Creative Commons Zero (CC0)", checked) | **thread scale**: gold and olive wool on cream |
| A2 | [AIC 72026](https://www.artic.edu/artworks/72026), 1820/30, overshot | CC0, as A1 | navy and cream close-up |
| A3 | [AIC 150611](https://www.artic.edu/artworks/150611), 1820/25, overshot | CC0, as A1 | indigo overshot, window-sash blocks |
| A4 | [AIC 150608](https://www.artic.edu/artworks/150608), 1820s/30s, overshot | CC0, as A1 | red and blue on white: two families |
| A5 | [AIC 4649](https://www.artic.edu/artworks/4649), *Book of Woven Coverlet Designs (Draft)*, c. 1839, owned by Daniel Stephenson | CC0, as A1 | a real draft book page, sepia ink ("The Quaker fancy" among its titles) |
| C1–C6 | Commons files linked above (carthen, rosepath, drall, kasuri, Skye loom, Warp in Progress, Torzhok) | as given | Welsh, Scandinavian, Japanese, the loom |

## 2. Palettes

Colour ramps are the median colour of the pixels at each brightness percentile of a piece (3rd to 97th), from the museum's own photograph. Museum lighting is neutral but each photo's white balance is its own (the Met's 13602 ground comes out peach; the drall's greys a little violet), so treat hexes as within a few levels. "Held" values are my proposals for the caps in section 3.

| Palette | From | Light Mode: ground → half-tone → pattern, light to deep | Dark Mode | One family? |
|---|---|---|---|---|
| **Indigo** | M2 ground #E8E6DB–#F3F0E7; A3 half-tone #898A90, navy #1D2035; M1 light dip #143152–#28496C; Met 13642 pale blue #878FA0–#BFCADC | held: ground #DCD8CB, half-tone #9A9EA8, pale #A9B5C8, mid #4F6A8C, deep #28496C, darkest #1D2035 in thin lines only | **Blue on Blue** (M1 as photographed): ground #010520–#020623, pattern #143152–#28496C. Held: ground #060C28, pattern #1E3A5E–#2E4E72, brightest #3E5F86 | yes (blue 210–237°) |
| **Madder** | A4 ground #E1D7CC–#F5F2EB, rose #B79181, red #88331F–#9A4331; M6 #5E1F1E–#7C2E28 | held: ground #DDD3C6, rose #B79181, brick #9A4331, deep #7C2E28, darkest #491316 | **Madder Dark** (M6): ground #30050C–#491316, pattern #7C2E28–#963F34; plum-black #1B011A at the bottom. Held: ground #2A0A0E, pattern #6A2622–#8A3A33 | yes (red 0–18°), if Turkey red is kept out |
| *Turkey red* (not offered) | M5: #9D2311–#C02E19, saturation 0.9 | | | the garish end: Lava Lamp territory |
| **Walnut** | M3 ground #CBB5A0–#F7DBC5, #695652, #34252A, #1C0D19 (dyes not given: unchecked as walnut); M4 tan cotton #C2A186–#DEB595, rust-brown #904C21–#A16D47; the Swedish rosepath #623D1D–#AD8252 | held: ground #E0D2BF, tan #C2A186, umber #8A6A55, deep #4A3328, darkest #2A1C18 | **Walnut Dark**: ground #1E1512, pattern #5A4A44–#7E685C | yes (24–34°; M3's darkest leans aubergine) |
| **Weld** | A1 ground #D3CFC7–#ECE7DF, gold #846F46–#9F8D6C, olive #2C2C19–#594E2D (olive is indigo over weld: two dyes, one hue family) | held: ground #DDD8CC, gold #9F8D6C, ochre #846F46, olive #594E2D | none: gold dims to mud (Kelp Forest's finding, section 3 there) | yes (38–60°) |
| **Undyed** | drall greys #958888–#E7E6EB; carthen cream #E7D2B2–#F3E4C8 with black-brown #1C181B–#2D2B32 | held: ground #E2D8C6, oatmeal #C9BFAE, grey #958F88, moorit #6B5444, black-brown #2D2826 | **Black Sheep**: ground #252329–#2D2B32, pattern #6F6A66–#958888 | yes (near-neutral, warm) |
| *Red and Blue* (to judge) | A4: white #E1D7CC, red #9A4331, navy #2F343F; M4: rust #904C21, navy #060813 on tan | as sampled, held to the caps | none | **no**: red at 10° and blue at 220° are two families |

- **Red and blue on white breaks "one family".** It is the classic coverlet (Hall, 1912: "a field of white and azure, — the azure made with indigo", and her madder recipes, checked), and it is real, but it is two hues near opposite each other, which is what Dave called ugly in Lava Lamp. Offer it on a sheet to judge, beside the one-dye versions, never as the default. The one-family way to keep both dyes is Madder Dark: the Met's 13640 is red on a navy so deep it reads as plum-black.
- **Real dye notes from Hall (1912, checked):** her informants' recipes are indigo with wheat bran and madder in the vat; madder for red; white walnut bark with copperas for brown; and a plate's yellow "made from peach leaves". Weld (*Reseda luteola*) is the classic European yellow; that it was used on these pieces is unchecked.
- **Gold and rust go muddy dimmed.** At Dark Mode's levels only blue keeps its colour (Kelp Forest's finding). Walnut Dark and Madder Dark should be mocked up against Blue on Blue before they are promised.

## 3. Brightness, contrast and edges

Measured on the app's own Settings previews (1,200 × 779) and on the coverlets (a central crop of each, or an 80 cm-across crop of the Met's full-size photos, which is about what a 14-inch screen would show).

| Picture | median | 90th | 99th | 99.9th | hard edges | busy | luma spread (rms) |
|---|---|---|---|---|---|---|---|
| Etching (preview) | 234 | 239 | 243 | 248 | 24.1% | 16.9% | 0.19 |
| Flowing Gradient, light | 230 | 239 | 241 | 242 | 0.0% | 0.0% | 0.09 |
| Turing Patterns, light | 198 | 228 | 230 | 237 | 9.1% | 5.8% | 0.33 |
| Turing Patterns, dark | 28 | 128 | 153 | 179 | 7.9% | | |
| Nebula | 48 | 197 | 229 | 236 | 0.5% | 0.2% | 0.25 |
| M1 Blue on Blue | 35 | 91 | 118 | 135 | 25.9% | 9.4% at 80 cm | 0.08 |
| M2 indigo on white, jacquard | 89 | 245 | 252 | 255 | 30.0% | 14.2% at 80 cm | 0.36 |
| M4 overshot, rust and navy | 144 | 203 | 234 | 252 | 63.6% | 37.4% at 80 cm | 0.23 |
| M3 overshot, *Wheel of Fortune* | 53 | 222 | 255 | 255 | 86.6% | 66.3% at 80 cm | 0.29 |
| A1 overshot close-up, weld | 159 | 220 | 245 | 255 | 74.2% | 30.9% | 0.22 |
| A3 overshot, indigo (web size) | 67 | 219 | 248 | 255 | 41.3% | | |
| M5 Turkey red Biederwand (web size) | 157 | 182 | 200 | 218 | 39.7% | | |
| M6 madder on plum-black (web size) | 73 | 133 | 160 | 175 | 73.8% | | |
| Welsh carthen detail | 51 | 247 | 255 | 255 | 42.0% | | |

For comparison from Peg Board's doc: the wallpapers Dave has kept scored 0 to 3.3% busy (Fish Tank 8.5%), Game of Life's Classic 11.1%. Earlier reports measured Nebula's preview at a median of 30 and a 99th of 150; the preview has changed since or was measured differently, so the caps below lean on both.

**What this says:**

- **Brightness alone isn't the trouble in Light Mode.** Dave runs Etching on its light paper by default (median 234) and Flowing Gradient's light look (230). A cream ground at 215 to 225 sits just under them. In Dark Mode, the real Blue on Blue already sits at Nebula's levels as photographed.
- **Contrast and edges are.** Every two-tone coverlet swings from about 20 to 250, and at desktop scale overshot is 2 to 6 times as busy as Etching and 3 to 6 times Game of Life's Classic. That is "bright and sharp" over the whole desktop. Only Blue on Blue (9.4%) and the indigo jacquard at 80 cm (14.2%) come in under Etching. The calm in real cloth comes from one family *and* close values, not from smoothness: every real cloth has thread texture.
- **Thread texture must not count as edges.** Shade neighbouring threads within about 20 levels of each other inside an area (under `busy.py`'s 0.08 step), so that only the pattern's edges register.
- **The menu bar:** macOS draws black menu-bar text once the strip under the bar averages about 155 (CLAUDE.md). A Light Mode cloth at a median of 150 to 190 lands on the black side, Blue on Blue on the white side: both fine, but a coverlet whose border runs along the top could flip it. Desktop icon labels read worst over high-contrast small pattern, another reason to keep contrast down.

**Proposed caps** (my reading of the app's scenes, not yet tried under desktop icons: unchecked):

| Part | Light Mode | Dark Mode |
|---|---|---|
| Ground (cream cotton, or the deep dye) | at most 225 (Etching's paper is 236) | 5 to 30 |
| Median | 150 to 190 | 25 to 45 (Nebula, Kelp Forest's dusk) |
| Pattern, broad | down to about 40 (deep indigo #28496C is 108; #1D2035 is 53) | at most 120 (M1's own 99th is 118); 150 the ceiling |
| Highlights on floats, a few pixels | at most 230 | at most 150; nothing above 190 |
| Value swing, ground to pattern | about 120 to 170 by default, against 200+ in real pieces; a Contrast setting can restore the real swing | 60 to 100 |
| Busy (`busy.py`) | aim under 10%, Etching's 16.9% the ceiling | under 10% |

## 4. The drafts

| Source | Public domain? | Copy | Notes |
|---|---|---|---|
| **Atwater, *The Shuttle-Craft Book of American Hand-Weaving*** (Macmillan, 1928) | **US: yes**, published 1928 (US works of 1928 entered the public domain on 1 January 2024: the rule, unchecked here, but HathiTrust's rights code for its 1940 printing "c1928" is `pd`, Full view, [Record 006215725](https://catalog.hathitrust.org/Record/006215725), checked). **Life + 70 countries: from 1 January 2027**: Atwater died 5 September 1956 ([Wikipedia](https://en.wikipedia.org/wiki/Mary_Meigs_Atwater), checked). The **1951 revised edition is in copyright** (HathiTrust `ic`, [Record 001045695](https://catalog.hathitrust.org/Record/001045695), checked): use 1928 only | HathiTrust; Internet Archive [shuttlecraftbook028554mbp](https://archive.org/details/shuttlecraftbook028554mbp) (1928, its record names no licence) | **The best source.** Its index runs to draft 297 (checked): overshot, summer-and-winter, twills, Bronson's and John Landes's drafts, each named, many from coverlets in named museums. Its drafts are mostly historic ones she collected; her drawing of them is hers |
| **Hall, *A Book of Hand-Woven Coverlets*** (Little, Brown, 1912) | **Yes, everywhere**: HathiTrust `pd` for both copies ([Record 006127065](https://catalog.hathitrust.org/Record/006127065), checked); the Internet Archive's [bookofhandwovenc00hall](https://archive.org/details/bookofhandwovenc00hall) says NOT_IN_COPYRIGHT (checked); Hall (Eliza Calvert Obenchain) died 1935 (unchecked) | full text and colour plates | The names: chapter IV lists well over 200 pattern names by kind (checked, section 4 below). A handful of drafts; recipes for indigo, madder and walnut |
| **Bronson, *The Domestic Manufacturer's Assistant*** (Utica, 1817) | Yes, by age | Internet Archive [domesticmanufact009135mbp](https://archive.org/details/domesticmanufact009135mbp); its publisher field names Chas. T. Branford, so it may be Branford's reprint: any added matter unchecked | Diapers, "No Name" and diamond drafts; Atwater reprints several (264 to 271) |
| **Hargrove, *The Weaver's Draft Book and Clothier's Assistant*** (Baltimore, 1792) | Yes, by age | **No open scan found.** The only digital copy is in the subscription *Evans Digital Edition* (Texas A&M's catalogue, partly checked); a 1979 American Antiquarian Society facsimile has a copyrighted introduction. "52 drafts in the figured line of weaving" (a Maryland State Archives page on 1792 imprints, partly checked) | The first American-printed draft book, 28 engraved pages. Not reachable now |
| **John Landes** (Pennsylvania weaver, drawings in the Frishmuth Collection, Philadelphia) | The drawings, by age (unchecked). The printed *A Book of Patterns for Hand-Weaving* with Atwater's threading drafts: HathiTrust `pdus`, public domain in the US only ([Record 009151739](https://catalog.hathitrust.org/Record/009151739), checked; the record's date, 1977, is odd) | HathiTrust (Cornell) | Several Landes drafts are already in Atwater 1928 (drafts 46, 148, 174, 215) |
| **Goodrich, *Mountain Homespun*** (Yale, 1931) | The Archive's record: "Copyright either not claimed or not renewed; item is in the public domain" ([mountainhomespun00good](https://archive.org/details/mountainhomespun00good), checked as its claim); Goodrich died 1944 (checked) | Internet Archive | About the weavers; few drafts. Her draft notebooks (the "Brown Book") are published only as Miller and Schillo's 2014 book (in copyright); a few drafts on [Western Carolina University's Craft Revival site](https://www.wcu.edu/library/DigitalCollections/CraftRevival/crafts/draftindex/DoubleBowknot.html), terms unchecked |
| **Griswold's On-Line Digital Archive of Documents on Weaving** ([cs.arizona.edu](https://www2.cs.arizona.edu/patterns/weaving/)) | Per document. The front page states no licence (checked). Handweaving.net's history of it says Griswold took "great care that every document was either out of copyright or shared with the permission of its author" (checked) | PDFs of Hall and much else ([coverlets page](https://www2.cs.arizona.edu/patterns/weaving/topic_coverlets.html)) | Its own pattern collection: individual patterns "may be used freely", but not "all or substantial parts" (partly checked). Use it to find scans; credit the book |
| **handweaving.net** (Kris Bruland) | The transcriptions: **no terms of use found** (the site is a script-run app; its About page read, checked). Over 60,000 drafts were made by his own software from scans of old works, "many of these ... now in the public domain"; "full drafts" need a subscription (partly checked) | WIF downloads, behind a subscription | A database of someone's work, possibly with database rights in Europe (unchecked). Don't take WIFs from it to ship; it is fine for checking our own transcriptions by eye |
| **AIC's *Book of Woven Coverlet Designs (Draft)***, c. 1839 ([4649](https://www.artic.edu/artworks/4649)) | CC0 image (checked) | one page photographed | A real draft book; a picture to show Dave, not a source of many drafts |

- **Are drafts copyrightable at all? Unchecked.** Handwoven's "Copyright 101 for Weavers" (Anita Osterhaug, [handwovenmagazine.com](https://handwovenmagazine.com/copyright-101-for-weavers/), checked) says basic structures such as twills and summer-and-winter are "common knowledge and are not subject to copyright", while a written pattern is protected as written; it cites no law. A draft is close to a method, which US copyright excludes (17 U.S.C. § 102(b): not read today). The Copyright Office has refused fabric patterns of common geometric shapes for lack of authorship (titles of Review Board decisions seen in a search only, partly checked). Don't rely on any of it: transcribe from the public-domain books, store the drafts as our own data with the book and page credited, as Etching credits its plates.
- **Ship from Atwater 1928 after 1 January 2027**, or before then from Hall, Bronson and the drafts Atwater credits to older sources, if the build lands earlier.

### The names, screened

From Hall's chapter IV and Atwater's index (both checked). States in brackets are Hall's.

- **Religious (out as names):** Rose of Sharon, Star of Bethlehem, Star of the East, Isle of Patmos, Walls of Jericho (Atwater spells it Jerico), Job's Trouble, Job's Perplexity, Solomon's Delight, Church Windows (also called Double Chariot Wheels: Hall says its "four 'chariot wheels' separated by the arms of a cross suggest a rose window"), Methodist Wheel, Saint Ann's Robe (the Met's 13634), Flowers of Canaan, Parson's Beauty, Maid of Orleans, The Quaker fancy (AIC's draft book), Monk's Belt (a religious order in the name: borderline, call it by its structure), Freemason's Walk (fraternal).
- **Political, military or loaded (out as names):** Whig Rose (a party), Democrat Victory, Federal Knot, Polk and Dallas, Lee's Surrender, Confederate Flag, Indian War, Indian Warfare, Indian March, Indian Camp, Braddock's Defeat, Battle of Richmond, Bonaparte's March and Retreat, Cornwallis' Victory, Washington's Victory, Perry's Victory, Jackson's Army, Mexican Banner, Downfall of Paris, Flag of Our Union, Old Glory, Forty-Niners. Missouri Trouble and Tennessee Trouble are in Hall's political list too.
- **Dated or about people:** Dutchman's Fancy, Frenchman's Fancy, the "Fancies" of named men and women. Harmless but best left out.
- **Safe, and lovely:** Sunrise; Sunrise on the Walls of Troy (classical, which Dave allows); Rising Sun; Lover's Knot; True Lover's Knot; Double Bow Knot; Snail Trail; Cat's Paw; Cat Track; Dog Tracks; Pine Bloom; Pine Burr; Pine Top; Four, Nine and Sixteen Snowballs; Snowball and Dewdrop; Orange Peel; Honeysuckle; Dogwood Blossom; Catalpa Flower; Pomegranate; Morning Glory; Sunflower; Pond Lily; Maple Leaf; Rose in the Wilderness; Rose in the Valley; Wandering Vine; Winding Vine; Flower of the Mountain; Wonder of the Forest; World's Wonder; Path of the Sunbeam; Islands of the Sea; Ocean Wave; Sea Star; Seven Stars; Star of Venus; Chariot Wheels; Wheel of Fortune; Wheels of Time; Doors and Windows; Window Sash; Bricks and Blocks; Philadelphia Pavement; Honeycomb; Goose-Eye; Bird's Eye; Herringbone; Summer and Winter; Governor's Garden; Granny's Garden; Lasting Beauty; Virginia Beauty; Sweetbriar Beauty; Weaver's Choice; Work Complete; Old Roads; Four O'Clock; Turkey-Foot. "Snail's Trail and Cat's Paw" as one name wasn't found in either book; each half is. Rosepath (Swedish *rosengång*) is in neither book and is safe too.
- **The motifs, not only the names.** Overshot's four-block "tables" often make crosses between them, and some drafts are named for it (Maltese Cross, Cross and Table, Sunrise with Small Crosses). Most read as a checkerboard; a lone plain cross would read as a religious mark, as Ramelli's finials did for Etching. Look at each chosen draft finished for a standalone cross. Four-block drafts on a square grid have four- and eight-fold symmetry, so no six-pointed star arises; jacquard figures (out anyway) can have them.

## 5. What reads at desktop scale

My arithmetic, at 11.8 ends a centimetre (Atwater's coverlet sett) on a 14-inch screen, 1512 × 982 points, and the menu tile, 89 × 58 points (a 0.059 reduction of the whole screen, as the tile is the preview loop made small):

| A warp end on screen | Points a cm | Cloth across | A 15 cm repeat | Repeats across | The repeat in the tile |
|---|---|---|---|---|---|
| 1 pt (2 px) | 11.8 | 128 cm, half a coverlet | 177 pt | 8.5 | 10 pt |
| **1.5 pt (3 px)** | 17.7 | 85 cm | 266 pt | 5.7 | 16 pt |
| 2.5 pt (5 px) | 29.5 | 51 cm | 443 pt | 3.4 | 26 pt |

- **1.5 points a warp end is the recommendation:** nearest the Art Institute's close-up (about 2.7 px an end at 31 to 33 px a cm), and between 2.4 repeats (a 36 cm summer-and-winter) and 14 (a 6 cm snowball) across the screen. On a non-Retina display that is 1.5 px an end, the shimmer edge: draw coarser there or filter.
- **1 point** shows the most pattern and is where cloth turns to pattern (the Met's 14 px a cm). **2.5 points** is the close-up, three repeats or fewer: wool you can almost touch, but less pattern to watch emerge.
- **At the tile, block patterns read and twills don't.** The coverlets reduced to 178 × 116 px with a proper filter (looked at): Blue on Blue reads as a calm damask, the snowballs and the *Wheel of Fortune* clearly. Sampled without a filter, the *Wheel of Fortune*'s fine half-tone lines break into moiré and the weld close-up goes to grain. A twill or rosepath at 1 to 2 mm a step averages to a flat tone with a faint diagonal. So the default look needs blocks of a few centimetres, and the tile and the site's loop must be drawn or filtered at their own size, as Peg Board's stills were.
- **What the screen holds:** at 1.5 points, 982 points is 55 cm of cloth top to bottom; at 2 to 3 cm a minute, the whole screen is new cloth every 20 to 30 minutes, and a pick goes in every couple of seconds right across the width. Something is always happening, slowly.

## 6. Names and look-alikes

- **Loom.** Loom, Inc. holds LOOM for video-communication and screen-recording software: registration 5274612 in class 9 (2017) and newer filings (third-party trademark aggregators, partly checked; not read on the USPTO's own pages). Atlassian bought Loom, Inc. for about $975 million, completed 30 November 2023, and its desktop recorder has run on Macs since 2018 ([Wikipedia: Loom, Inc.](https://en.wikipedia.org/wiki/Loom,_Inc.), partly checked). That its Mac app sits in the menu bar is unchecked. A wallpaper is different goods and "loom" an ordinary word, so a legal problem is unlikely (not a lawyer's advice); the trouble is confusion in exactly the place Atrium lives, a Mac menu bar, with the word alone. Also: Lucasfilm's 1990 adventure game *Loom*, about a guild of weavers (unchecked as a live mark); Fruit of the Loom (a different mark, no conflict).
- **Weaving** (recommended): plain like Etching and Canopy, names the act on screen, fits every look (overshot, twill, kasuri, Welsh), and no brand of that name turned up (one search, partly checked). Con: generic.
- **Coverlet:** names the cloth, quiet and historic; no app or mark of the name found (one search, partly checked; "acoverlet" is an iOS cover-letter app). Con: an uncommon word, and wrong for kasuri or a twill.
- **Handloom:** in India the "Handloom Mark" is a certification scheme of the Ministry of Textiles, said to be registered as a certification mark (partly checked, [Textiles Committee](https://www.textilescommittee.nic.in/node/1643)): avoid.
- *Woven* (Woven by Toyota is a company), *Shuttle* (a macOS menu-bar SSH launcher of that name, unchecked), *Warp and Weft* (shops): weaker.
- **Traditions not to use as patterns:** Diné (Navajo) weavings: a Diné weaver writes that the designs belong to the Navajo people and should not be sold ([Weave a Real Peace](https://weavearealpeace.org/lynda-teller-pete/), partly checked), and Yei figures are ceremonial; Zapotec rugs that follow Navajo designs (the Warp in Progress photo); Asante kente (royal and clan patterns; Ghana's law on folklore, unchecked); ritual ikats such as Sumba's *hinggi* and Tenganan's *geringsing* double ikat (unchecked); Māori *tāniko* and Sámi patterns (unchecked); and tartans (a register of named, sometimes restricted or trademarked setts, unchecked). Japanese kasuri in geometric patterns (well-curbs, arrow feathers, splashes) is folk cloth and fine; leave out *e-gasuri* pictures with gods or temple motifs. American coverlets, Welsh blankets and Scandinavian twills are folk weaving with no such claim found.

## 7. Risks to the look, worst first

1. **Busy and sharp over the whole desktop.** Real overshot measures 37 to 66% busy at desktop scale, cream to navy at full swing: Zen Garden's "so bright and sharp" and Game of Life's "crazy on the eyes". Keep one family, a held value swing, the pattern large, and summer-and-winter or double weave as the calm kinds. Show Dave a true-contrast and a held version side by side.
2. **Shimmer.** Cloth is a regular lattice, and the app has seen a lattice turn into a weave when reduced three times: Peg Board's sheet in reduced stills, Ant Colony's sand on a square lattice ("on a non-Retina display, Settings' preview, a README picture"), Lava Lamp's repeating hash. Here it also moves: rolling on slides a 3 px lattice by fractions of a pixel. Real irregularity (spacing, thickness), threads drawn with their own filtering, and rendering the tile and loop at their own size are the defences; measure on renders (the method report has a probe).
3. **It reads as pixel art.** A drawdown is literally a grid of coloured cells. Without round, hairy, irregular threads it is a pixel picture of a coverlet, and Dave has cut the drawn subject in a photoreal frame before (A Tree for the Year). Judge a crop at 1:1 beside the Art Institute's close-up.
4. **Two families by default.** Red and blue on white is the iconic coverlet and not one family; Turkey red is hot; gold and rust go muddy in the dark.
5. **It looks like Peg Board or Etching's act.** A picture built from nothing, held, then cleared was the act Dave tired of. Here nothing is cleared: the cloth is continuous, the screen always full, and one cloth runs on into the next on the same warp. Don't hold-and-wipe.
6. **The loom drawn.** A drawn wooden loom risks the fault that cut Campfire and the Tree (the main thing not passing beside something real). Full-bleed cloth with only the fell and a band of open warp is safer; a loom, if any, from a photograph.
7. **Names and motifs.** The religious and political names above, and lone crosses in some drafts.

## 8. Questions for the mock-up sheets

1. **The view:** (A) cloth full-bleed, the fell rising, a narrow band of open warp and the reed's dark bar above it; (B) the weaver's view, the reed and the shuttle across the top quarter in slight perspective; (C) the cloth seen from further off with a border and selvedge, a dark floor beside it.
2. **The palette:** Indigo, Blue on Blue, Madder, Madder Dark, Walnut, Weld, Undyed, and Red and Blue to judge as the two-family exception. Which follow Light and Dark Mode, and is summer-and-winter's two faces the pair?
3. **Contrast:** the real swing (navy on white) beside the held one.
4. **The thread size:** 1, 1.5 and 2.5 points an end, each at 1:1 and at the tile.
5. **The kind of pattern:** overshot, summer-and-winter, double weave, a twill or rosepath, kasuri; one kind or a mix on each load.
6. **What lies around the cloth:** nothing, a selvedge and floor, or the loom's wood.
7. **Names:** show a screened name in Settings or a caption, or none.
8. **The name:** Weaving, Coverlet, or Loom.
