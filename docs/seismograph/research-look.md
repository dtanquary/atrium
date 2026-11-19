# Seismograph: the look research

A research agent's report on what a drum seismogram looks like, for the wallpaper Dave picked from the ideas page of 2026-11-14 ("a paper drum with a pen crawling across it, one line each half hour and a day to a sheet"). Written 2026-11-18. How to fetch and draw the data is the method report's job. Every claim is marked **checked** (the page that says so was read on 2026-11-18), **partly checked** (seen only in a search engine's excerpt or a third-party mirror) or **unchecked**. A Commons licence marked checked is Commons' own licence field for the file, read through its API, which is only as good as the uploader's claim. Colours and widths are my own samples, measured by small Python scripts on downloaded copies (1,000–1,400 px); photos of paper under room light read darker and greyer than the paper is. The copies are in the session's scratchpad, not in the repo.

## Recommendation in ten lines

1. **Draw the flat sheet, not the drum:** a full screen of 48 half-hour lines, read like a book, the pen writing the current line. Every real record shown to people (USGS, observatories, web plots) is the sheet; the drum is a later, optional view.
2. **Make the sheet a clock, so it is never empty:** line *n* is half-hour *n* of the day (00:00 at the top, as real records are labelled), and the pen writes today over yesterday's line just ahead of it. Lines above the pen are today's, lines below are yesterday's in older ink. A sheet changed once a day would be blank each morning, which Dave has ruled out.
3. **Copy what makes a real quiet record beautiful:** the gain is set to the station's own noise (checked: "magnified according to the level of background … noise"), so every line carries a fine, even tremble of ocean microseism, a fabric of 48 strands. Never a ruled flat line.
4. **The time marks are the record's own grid:** a small square step in the line each minute (1 s long on the MEQ-800, checked), a longer one each hour (2 s), longer still at 00:00 and 12:00 (10 s). Over 48 lines they stack into faint columns, 30 across. Draw no ruled grid.
5. **A quake is rare and big:** a distant M7 is a train of waves that swings two to five line spacings and tangles 4–12 lines for one to three hours. Let swings cross neighbouring lines, as real ones do; on ink, the fast strokes are thinner and paler than the slow ones.
6. **Default surface, Light Mode: "Chart"**, a dimmed cream (208, 200, 184) with a black-brown ink (46, 40, 36), a page mean of about 193. That is softer than Etching's Paper (230) and close to its Parchment (192). Etching's Paper and Parchment can be shared as they are.
7. **Default surface, Dark Mode: "Smoked"**, the real dark record: soot with a fine pale scratch. Etching's Paper Dark (58, 56, 53 with 228, 224, 214, "chalk on charcoal") is already very close; a deeper soot (34, 33, 31) with the scratch held to 196 is truer and calmer.
8. **A blue-ink option in one family:** the USGS's own web records cycle each 15-minute line through four shades of one blue (checked by sampling a public-domain USGS plot), and Geotech's ink drums wrote blue. On a white ground that is Etching's Blueprint Light, which can be shared.
9. **Annotate as the observatories did, sparingly:** hour numbers in the left margin, a rubber-stamped label box in one corner holding the real station, component and date, and a pencilled note beside a big quake only ("Japan M7.1 13:42"). Two or three notes a sheet at most.
10. **Name: Seismograph is clear;** it is a generic word, and no live mark for it turned up (partly checked). Keep out of the app Helicorder (a Teledyne/Geotech mark, now expired, but the USGS still prints it ®), the slogan "Watch the Earth Move" (a live mark of Raspberry Shake, S.A.), and every maker's name and badge. Fallback: *Seismogram*.

## 1. What real records look like

### Ink on paper (the observatory drum)

- **The machine.** A sheet "wrapped around a slowly revolving drum … As the drum revolves, the pen shifts across it, making a big spiral or helical record that eventually fills the entire page. When the paper is removed and laid flat, the record appears to be many horizontal lines, like lines in a book" (USGS, checked, https://earthquake.usgs.gov/monitoring/seismograms/about.php). The pen and its motor ride a lead screw driven by a translation motor, and "record line spacing is a product of pen translation rate and drum speed" (Sprengnether MEQ-800 manual, 1975, checked, https://www.eas.slu.edu/eqc/eqc_history/SprengnetherInstruments/MEQ800manual.pdf).
- **Because the pen moves on continuously, the lines are a helix.** On the flat sheet each line falls by one line spacing across its length (a slope of about 1 in 180 on a 900 mm sheet with 5 mm lines; my arithmetic). The right end of each line carries on at the left end of the next one down (checked, USGS page above).
- **The seam.** The sheet's two ends overlap on the drum, joined with "a 13 inch strip of ½ inch double sided tape" (MEQ-800 manual, checked). Laid flat, there is a blank strip at one edge where the pen crossed the join.
- **What a photo shows.** Weston Observatory's drum (W1, W2 below): white or cream paper, a black-brown pen line, lines about 1/20 of their spacing thick on the long-period drum; Hawaii's short-period record (H1): dense black lines whose quiet fuzz is a quarter of the spacing. The Kinemetrics drum at Napier (N1) and Geotech's RV-301 (R1) show the drum face-on: from the front the lines run up and down the drum, the hour steps forming a ladder.
- **Ink colours.** Black or black-brown on most (W1, H1, N1); a blue-green ink on the RV-301 (R1, sampled 64, 74, 88 at its darkest, against a ground of 224, 230, 235). Some multi-pen drums used one colour per channel (unchecked). Ink pools darker where lines cross, and a fast stroke is thinner and paler than a slow one: in W2, the steep upswings of the Tōhoku waves are visibly lighter than the slow parts of the same line.

### Smoked paper (a natural dark tone)

- Hawaii's first records were made by "a stylus that etched its squiggly trace into a layer of kerosene soot that coated glossy paper" (USGS Volcano Watch, checked, https://www.usgs.gov/news/volcano-watch-hvo-transforms-stacks-paper-earthquake-records-digital-squiggles). The MEQ-800 still offered it in 1975: 80 lb heavy enamel paper, taped round the drum and spun "through the smoke until it is uniformly blackened" over a wick of furnace or diesel fuel; afterwards the sheet is drawn through shellac diluted 1 to 30 in alcohol and hung to dry (checked, manual above). A 1924 Library of Congress photo shows a sheet being dipped in that fixing tray (S1).
- **The look:** a deep, slightly uneven soot with a fine pale line scratched to the paper beneath, and notes scratched in by hand, so the handwriting is pale too (S2, the 1915 New Orleans hurricane record, where a whole band of lines is thick with storm microseism). S2 is an old, faded print: it samples at a ground of 124 and a line of 206, so its true soot is much darker than the photo. Smoked records are where the dark tone comes from honestly.

### Photographic records (WWSSN)

- The World-Wide Standardized Seismograph Network's 135 identical six-sensor stations (1961–1996) recorded with a light beam on "photo paper on 6 rotating drums," changed daily (USGS, checked, https://www.usgs.gov/programs/earthquake-hazards/science/preserving-historic-earthquake-records-and-photos-instruments). The paper is 300 × 900 mm (checked, https://legacy-seismic-data.github.io/organizations/wwssn); the drums ran at 60 mm/min for short period and 15 or 30 mm/min for long period (partly checked: a National Academies report seen in a search excerpt, https://www.nap.edu/read/18566/chapter/5).
- **The look:** the developed paper is a dark line on a pale grey ground (K1: 222 ground, 90 line). The archive's film copies are negatives, a white line on black. On a photographic record the faster the beam moves, the fainter its line, so the biggest swings can all but vanish (unchecked as a general rule; K1's calibration pulse has a paler rising edge). K1's hour numbers are pencilled in a slanting column down the middle of the sheet, and a stamp box sits at the lower left.

### Thermal paper and today's web plots

- Teledyne's 1976 HELICORDER mark covered "seismic recorders for producing traces of analog data on heat-sensitized paper" (partly checked, Justia excerpt): a heated stylus darkening coated paper, a grey-black line on white. The close-up from the Czech Academy (C1) shows that look: white paper (242, 241, 238), very fine grey lines (103 at the darkest), lines packed tight, a quake a faint thickening of a few.
- **Web plots ("webicorders", "heli plots")** draw the same 24-hour sheet. The USGS: "Each line represents 15 minutes of data; four lines per hour," and "the colors of the horizontal lines have no particular significance" (checked, USGS page above). Its Lassen plot (U1, public domain, checked, https://www.usgs.gov/media/images/lsib-helicorder-trace-lassen-volcanic-center-june-24-2024) cycles each line through four blues, sampled at exactly (0, 0, 105), (0, 0, 155), (0, 0, 205), (0, 0, 255), with clipped swings in red (255, 0, 0) ("Red colors indicate maxed-out amplitudes"). Other networks: Thessaloniki alternates blue (0, 0, 252) and crimson (252, 0, 64) on 30-minute lines (G1); Berkeley's long-period BKS plot is black with every hour's line in red, on 15-minute lines (B1); the Northern California data centre draws 60-minute lines (checked, https://ncedc.org/waveformDisplayFAQ.html), Alaska's volcano observatory 20-minute lines (partly checked). Calibration pulses come every 12 hours on Alaska's stations and are always clipped (partly checked).
- **The traditional cycle black, red, blue, green** I could not find stated on any page (unchecked). Only one-colour, two-colour and one-hue-four-shade schemes were seen. The four blues are the scheme that fits "colours in one family".

### The parts and marks

- **Minute and hour marks.** The MEQ-800's clock pulses the pen "for each minute mark, a pulse of 1 second duration … for each hour mark … 2 seconds … and a pulse of 10 seconds for 12 hours and 24 hours" (checked, manual above). On the sheet the pen steps aside by a fixed amount and back, leaving a small square notch; on 30 mm/min paper a 1 s step is 0.5 mm long, an hour's 1 mm, the noon and midnight steps 5 mm (my arithmetic). Southern California's records: "Hour tick marks are larger than minute tick marks and appear every fourth horizontal line," and "the onset of each tick mark … represents each minute" (checked, https://local.scedc.caltech.edu/data/drum-info.html). Because the lines are whole multiples of a minute, the marks line up in columns down the sheet (H1, N1): the only grid a real record has.
- **Labels.** Hand-written hour numbers, "usually … two integers, such as 12, 06 or 18"; a clock correction written on the record "in the form +2.4 or -1.2"; on some, a radio time code (WWVB) at set hours (checked, SCEDC page). Weston's sheet has a rubber stamp in the margin: STATION WES, COMP LP Z, MAG, TO, TG, DATE ON, TIME ON, CORR … MS @ GMT, DATE OFF, TIME OFF, and a GRND MOT arrow (W2). Napier's has "2nd March 1987, Wellington" and "HIGH GAIN" written up the margin (N1). Web plots label every line with its start time on the left (local) and on the right (UTC) (U1).
- **The sheet as an object.** Records were folded for storage (H1 has a crease down its middle); HVO collected "nearly half-a-million paper seismograms" from 1912 to 2013, at a peak of 30 a day (checked, Volcano Watch above).

### What a quake, the noise and a quiet line look like

My readings of the reference records (in line spacings, the gap between two lines), then arrival times (unchecked: IASP91 travel times as I remember them; the method report should confirm).

- **A quiet line.** Never flat. A short-period record carries a fuzz about ¼ of a spacing tall, with minute steps (H1, C1). A long-period one carries the ocean microseism as a steady, even wiggle about ⅓ of a spacing tall and some 6–10 s per wave (B1, in July). Secondary microseisms run at 6–11 s, "probably associated with winter storms" (partly checked, search excerpts), so a winter page trembles more than a summer one, and a storm at sea can thicken a whole band of lines for hours (S2).
- **Cultural noise.** Traffic, machinery and footsteps are short-period and follow the clock: the daytime lines are fuzzier than the night's (partly checked, search excerpt: "strong diurnal variations"). On a sheet that shows as a broad, soft band of thicker lines from morning to evening, quieter at night and on Sundays.
- **A local quake** (within a few hundred km): a sharp spike, then a spindle a few minutes long, often clipped. U1 shows dozens a day near a volcano, each a twentieth to a fifth of a line long, the biggest clipped across 2–4 spacings. In G1 one nearby quake's swing runs up and down the whole sheet in a single column, and its aftershocks clip across 2–6 spacings for hours.
- **A distant quake** (a teleseism): P, then S several minutes later, then the long surface-wave train. On B1 the Nicobar Islands quake of 24 July 2005 (about M7, unchecked), some 13,000 km away, swings ±2 spacings and tangles about 12 fifteen-minute lines (three hours). Tōhoku (M9.0) at Weston, about 10,400 km away (unchecked), swings 5–8 spacings and crosses lines for hours (W2); in Hawaii, 4,000 miles away by the photo's caption, it is a solid black block two spacings each side of its line for most of a line and a half (H1). The 1906 San Francisco quake at Göttingen (about 9,000 km): P at about 740 s, S at 1,350 s, surface waves for many minutes after (D1, public domain).
- **Arrival times** (unchecked): P at 30° (3,300 km) after about 6 min, at 60° about 10 min, at 90° about 13 min; at the far side of the Earth (PKP) about 19–20 min, which is the idea page's "within about twenty minutes". S about 11, 18 and 24 min at the same distances. Surface waves travel at about 3.5–4 km/s, so 45 min or so to 90°.

### Reference images

Kept for the look, not to ship unless noted in section 6. Licences are checked unless marked.

| # | Image | Licence | Shows |
|---|---|---|---|
| W1 | [Seismogram at Weston Observatory](https://commons.wikimedia.org/wiki/File:Seismogram_at_Weston_Observatory.JPG), Z22 | CC BY-SA 3.0 | **the classic drum**: white paper, black-brown ink, a quake crossing many lines, the pen arm and the seam |
| W2 | [A seismogram of 2011 Tōhoku earthquake and tsunami](https://commons.wikimedia.org/wiki/File:A_seismogram_of_2011_T%C5%8Dhoku_earthquake_and_tsunami.jpg), Z22 | CC BY-SA 3.0 | Weston's long-period sheet: surface waves tangling lines, paler fast strokes, the rubber-stamped label |
| H1 | [Tōhoku Seismogram](https://commons.wikimedia.org/wiki/File:T%C5%8Dhoku_Seismogram_-_Flickr_-_Joe_Parks.jpg), Joe Parks (Hawaii Volcanoes NP) | CC BY 2.0 | short-period sheet: minute steps in columns, a fold, "JAPAN EARTHQUAKE" in blue pen, "LOCAL 4.6 16:58" in pencil |
| N1 | [Seismograph with record of Bay of Plenty earthquake](https://commons.wikimedia.org/wiki/File:Seismograph_with_record_of_Bay_of_Plenty_earthquake,_March_2,_1987_-_Faraday_Museum_of_Technology_-_Napier,_NZ_-_DSC05509.jpg), Daderot | CC0 | a Kinemetrics drum face-on: lines running up the drum, hour steps as a ladder, the seam, margin notes |
| R1 | [Historischer Seismograph](https://commons.wikimedia.org/wiki/File:Historischer_Seismograph.jpg), Ilyacadiz (Kandilli) | CC BY-SA 4.0 | a Helicorder RV-301 with blue-green ink: the object, and a maker's badge to keep out |
| C1 | [Seismogram on historical seismometer … (15)](https://commons.wikimedia.org/wiki/File:Seismogram_on_historical_seismometer_at_Institute_of_Geophysis_of_the_Czech_Academy_of_Science_(15).jpg), Petr Brož | CC BY-SA 4.0 | close-up of a drum: very fine lines packed tight, the stylus arm, a quake as a faint thickening |
| C2 | [… (7)](https://commons.wikimedia.org/wiki/File:Seismogram_on_historical_seismometer_at_Institute_of_Geophysis_of_the_Czech_Academy_of_Science_(7).jpg), same | CC BY-SA 4.0 | the two-pen recorder in its rack, the sheet being changed |
| S1 | [Man preparing a "smoked paper"](https://commons.wikimedia.org/wiki/File:Man_preparing_a_%22smoked_paper%22_to_be_used_in_a_seismograph,_probably_at_Georgetown_University.jpg), Harris & Ewing, 1924 | No restrictions (LoC) | fixing a smoked sheet; a drum recorder in the corner |
| S2 | [New Orleans 1915 Hurricane Seismograph](https://commons.wikimedia.org/wiki/File:New_Orleans_1915_Hurricane_Seismograph.jpeg), Loyola University | Public domain | **the smoked look**: pale scratches on soot, a band of storm microseism, scratched handwriting |
| K1 | [Long-period vertical seismogram on paper](https://www.usgs.gov/media/images/long-period-vertical-seismogram-paper), USGS (KEV, Finland, 1971) | Public domain | a WWSSN sheet: dark line on pale grey, a slanting column of pencilled hours, a stamp box |
| U1 | [LSIB helicorder trace](https://www.usgs.gov/media/images/lsib-helicorder-trace-lassen-volcanic-center-june-24-2024), USGS CalVO | Public domain | **the four-blue cycle**, red for clipped, 15-minute lines, times both sides |
| G1 | [KNT.20161118](https://commons.wikimedia.org/wiki/File:KNT.20161118.gif), AUTH network | Public domain | 30-minute lines alternating blue and crimson; a local quake clipping a band down the sheet |
| B1 | [Seismogram nicobar 20050724](https://commons.wikimedia.org/wiki/File:Seismogram_nicobar_20050724_2114_amp5_day.jpg), Peter H. Rassmann (BKS LHZ) | Public domain | a long-period day: microseism on every line, hour lines in red, a teleseism over 12 lines |
| D1 | [1906 San Francisco earthquake seismograph](https://commons.wikimedia.org/wiki/File:1906_San_Francisco_earthquake_seismograph.png) | Public domain | P, S and surface waves at Göttingen, with times |
| Y1 | [NY State Museum report (1908) plate](https://commons.wikimedia.org/wiki/File:Annual_report_of_the_Regents_-_New_York_State_Museum._(1908)_(19178575730).jpg) | No restrictions | a 1907 quake on a single line, "Beginning 9:04 A.M." lettered with an arrow; cream paper (245, 226, 201) |

## 2. Real numbers

| Figure | Value | Model and source |
|---|---|---|
| Sheet | 343 × 600 mm (13.5 × 24 in): 1.75 to 1, about a 16 : 9 display | Sprengnether MEQ-800, checked (manual above) |
| Sheet | 300 × 900 mm: 3 to 1 | WWSSN photographic, checked (legacy-seismic-data) |
| Sheet | 90 cm round, about 30 cm wide | Helicorder and other ink drums, **unchecked** (often quoted; not found in a manual) |
| Drum speed | 15, 30, 60, 120, 240 mm/min | MEQ-800, checked |
| Drum speed | 60 mm/min short period; 15 or 30 long period | WWSSN, partly checked |
| Drum speed | 10 cm/min | Wiechert horizontal, partly checked (Saint Louis University history, search excerpt) |
| Drum speed | 1 mm/s (60 mm/min) | Wood-Anderson, per the caption of a Bureau of Reclamation photo on Commons (CC BY-SA 2.0), partly checked |
| Drum speed | 30 and 60 mm/min standard | Sprengnether Autocorder 6100, partly checked (search excerpt of its manual) |
| Line spacing | 0.5, 1, 2 or 4 mm, set by pulleys; a sheet lasts ¼ day to 16 days | MEQ-800, checked (Table 1-3) |
| Minutes per line | 15 (USGS, SCEDC, Maryland), 20 (Alaska), 30 (G1 and the idea), 60 (NCEDC) | checked except Alaska and Maryland, partly checked |
| Lines per sheet | 96 at 15 min, 48 at 30 min, 24 at 60 min | arithmetic |
| Time marks | 1 s each minute, 2 s each hour, 10 s at 12 and 24 h | MEQ-800, checked |
| Stylus | 12.5 cm long | MEQ-800, checked |
| Pen line | ¼ to 1/20 of the line spacing in the photos (H1: 3 px in 12.5; W2: 2 px in 39.5) | my measure |
| Ink | black, black-brown; blue-green (RV-301); film negative white on black | photos |

**For the wallpaper:** 48 lines on a 1512 × 982-point screen, leaving margins, is a spacing of about 18 points; 30 minute marks a line are 50 points apart; the pen crawls at about 0.8 points a second (1.7 Retina pixels). That is about twice as tall a spacing, against the line's length, as a real 900 mm sheet with 5 mm lines; the MEQ-800's 1.75-to-1 sheet at 7 mm lines is near it. A finer option (96 lines of 15 minutes, 9 points apart) is the denser, more textured real look of C1 and B1.

## 3. Palettes

Brightness in sRGB levels of 255: ground and line as R, G, B; then luminance (Rec. 709 weights on the sRGB values), and a quiet page's mean, assuming 5% of it is line. On a quiet sheet the median and the 99th percentile are both the ground; on a dark one the 99th is the line, once lines cover more than 1% of the screen.

| Palette | Ground | Trace (minute marks the same) | Hour numbers, stamp, notes | Ground L / page mean | Etching's? |
|---|---|---|---|---|---|
| **Chart** (Light default) | 208, 200, 184 (W2 sampled 194, 189, 181 under room light) | 46, 40, 36, black-brown (W2's darkest 23, 14, 8) | pencil 128, 120, 108; stamp faded 96, 90, 84 | 201 / 193 | new; a dimmed Paper |
| Paper | 236, 230, 216 | 36, 33, 31 | pencil 120, 116, 110 | 230 / 220 | **shared** (Paper Light) |
| Parchment (sepia chart) | 216, 199, 165 | 62, 42, 27 | pencil 130, 112, 88 | 200 / 192 | **shared** (Parchment Light) |
| **Blue ink** | 226, 232, 238, or dimmed 200, 206, 212 | four blues by line, darkest to lightest: 30, 52, 104; 38, 72, 138; 54, 90, 158; 72, 110, 172 | slate 96, 108, 128 | 231 or 205 / 223 or 198 | ground **shared** (Blueprint Light); the four-blue cycle is new |
| **Smoked** (Dark default) | 34, 33, 31 soot, ±4 blotches | 196, 192, 184 scratch | scratched notes 170, 166, 158 | 33 / 41 | new; a deeper Paper Dark |
| Paper Dark as smoked | 58, 56, 53 | 228, 224, 214 | 180, 176, 168 | 56 / 65 | **shared** (Paper Dark, "chalk on charcoal") |
| Night chart | 74, 58, 42 | 232, 216, 184 | 170, 150, 120 | 60 / 68 | **shared** (Parchment Dark) |

- **Soft and dim.** A paper sheet is a bright, flat page by nature: its median is its ground, 190–230 in Light Mode, far above the 90–140 that the photo scenes aim for. Etching has drawn on Paper at 230 by default since 0.112.0, so a bright sheet is already on desktops; but this one is nearly all ground, with no picture to break it up, so I'd default to Chart at about 200. Line contrast is 136–197 levels; Chart's 160 is a little under Paper's, like ink that has dried brown.
- **What clashes:** the web plots' saturated red for clipped swings beside blue (U1) and blue beside crimson (G1); black lines with red hour lines (B1). Use one hue. Clipped swings can be shown as the real ink drum shows them: the pen hits its stop and the line runs flat along the limit.
- **What a seismogram needs that Etching's surfaces lack:** a second, weaker ink for pencil and stamps; a "drawn fast" line (thinner, paler where the pen moves quickly); ink pooling where lines cross; soot with blotches and a fixed, slightly glossy look for Smoked; and the paper's helix and seam strip. Etching's tooth (the ground's grain) fits all of them unchanged.
- **Blueprint Dark** (white on Prussian blue) has no seismogram behind it: the nearest real thing is a film negative, which is white on black. Leave it out.

## 4. Annotations

- **What the staff wrote** (section 1): hour numbers down the margin or the middle, a stamped label box (station, component, gain, date and time on and off, clock correction), clock corrections, and on a big quake a note with an arrow: "JAPAN EARTHQUAKE", "LOCAL 4.6 16:58" (H1), "Beginning 9:04 A.M." with an arrow (Y1). On smoked paper, scratched in.
- **Recommended:** hour numbers every two lines in the left margin in pencil grey, small (UTC or local, by setting; real web plots give both); one stamp box in the lower left with the real station code, component, date and gain, as honest as the trace; a pencilled note beside a quake only when one is big enough to see (say M6 or over, or felt nearby), giving the region, magnitude and time from the event catalogue, with a short arrow to the first swing. At most two or three on a sheet; older notes age with their lines.
- **Would it look busy?** H1 is the warning: big blue capitals across the record are the busiest thing on it. Keep notes in pencil grey, a third of the line spacing tall, and away from the menu bar and the right-hand icon column.
- **Handwriting needs a font with an open licence,** or letters drawn as strokes (Etching's way). Not checked here.

## 5. Names and brands

Not a lawyer's advice. USPTO's own pages (TSDR) refused automated reads, so these are from third-party mirrors.

- **Seismograph:** no live US mark for the word alone turned up; marks near it (SEISMO, SEISMOCON, SEISALERT, SEISWARE) are for other goods, and a dead SEISVIEWER belonged to a "Seismograph Service Corporation" (partly checked, search excerpts of Justia and Markinton). It's a generic word for the instrument, as Etching is for a print. **Clear to use.**
- **Helicorder:** registered to Teledyne Industries in 1976 (reg. 1047598) for seismic recorders on heat-sensitive paper, and again in 1998 (reg. 2165644, serial 75280670, listed under Geotech Instruments); both shown as expired, the second since 2019-01-18 (partly checked, Justia excerpts). The USGS still writes "Helicorders® made by Geotech Instruments, LLC" (checked, USGS page above). **Keep it out** of names, settings and keywords.
- **Webicorder:** a term used by USGS and volcano observatories; no mark found (unchecked). It reads as a borrowed product name: avoid.
- **Raspberry Shake:** live marks of Raspberry Shake, S.A.: RASPBERRY SHAKE (reg. 6422910, for seismographs), SHAKENET (reg. 6431912, 6431913), and **WATCH THE EARTH MOVE** (reg. 6876969–71) (partly checked, https://gleanmark.com/owner/raspberryshakesa). Don't use the name, and don't use that phrase as a tagline. Naming a real Raspberry Shake station as a data source in About is fine.
- **Makers:** Geotech, Teledyne, Kinemetrics, Sprengnether, Lennartz are company names; none belongs in the app. If a drum is drawn later: no badge, no Teledyne logo (R1), no yellow Kinemetrics panel (N1).
- **"Drum recorder"** is a plain description, clear.
- **Fallback name: *Seismogram*,** which names the record rather than the machine, as Etching names the print.

## 6. Images or textures to ship

- **Draw everything.** The sheet is lines, notches, letters and paper grain, all of which Etching already draws. No photo is needed for the flat sheet.
- **For a drum view later**, the candidates and their catch: N1 (CC0, the cleanest licence, but a Kinemetrics with a badge and a museum card, so only the drum would be cut out); W1 and C1 (CC BY-SA 3.0 and 4.0: credit, and any image made from them is share-alike; check that suits the app); R1 (CC BY-SA 4.0, a Teledyne logo in frame). Better to model the drum (a cylinder, its end flanges and a thin pen arm) and draw the same sheet on it.
- **A smoked-soot texture** can be noise; S2 is public domain but faded and blotched by its age as a photo, not by the soot.
- **Not shippable:** the Exploratorium's smoked-paper Coalinga record is © Exploratorium (partly checked, search excerpt); the legacy-seismic-data pages are "Copyright University of California Regents" (checked).

## 7. The quiet day, from the look side

A quiet sheet is still a full one, if it is drawn as observatories set theirs:

1. **Gain set to the noise.** Real plots are scaled to their station's background (checked, NCEDC), so the microseism always shows. Auto-gain on a day's noise floor keeps every line trembling about ¼ to ⅓ of a spacing, whatever the station.
2. **48 strands of texture.** Lines whose fuzz varies slowly through the day (busier by day, calmer at night, swelling with a storm at sea) read as woven cloth, not ruled paper: B1 and C1 are beautiful with no quake at all.
3. **Minute and hour notches** in columns, and the longer noon and midnight steps, give a quiet sheet its rhythm.
4. **Yesterday under the pen.** With the sheet as a clock (recommendation 2) the half below the pen is yesterday's ink, a shade paler, with its own notes; it can hold yesterday's quake while today is quiet.
5. **Ink that varies.** Pen pressure and ink flow: a slightly denser start to each line after the seam, ink pooling at crossings, and the pen leaving a darker dot where it stands at the line's end.
6. **The pen itself.** The one moving thing: a thin arm and its tip at the current line, moving 0.8 points a second. It is always somewhere, so there is always something to see.

Left for the method report: which station, the data's terms, how to pick gain and filter, and the real day-night and seasonal noise at a chosen station.
