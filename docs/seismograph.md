# Seismograph

A day of the ground's motion, drawn by a pen line by line on paper: one line each half hour, a day to a sheet, from the nearest open seismic station. Mostly a fine, even tremble (the ocean's microseism, which every station on Earth feels), and now and then a quake's train of waves tangling a few lines for an hour or two.

It was on the "Atrium Wallpaper Ideas" page of 2026-11-14 (a review of the catalogue by the session atrium-37), as "My pick · New wallpaper · Part new", in these words: "A paper drum with a pen crawling across it, one line each half hour and a day to a sheet. Mostly a faint tremble, and now and then a quake's train of waves." What is real: "Today's ground motion from the nearest open seismic station. A big quake anywhere on Earth first arrives within about twenty minutes." Builds on: "Etching. Etching's paper and ink. The same drum could chart the barometer, the tide or the solar wind." Risk, low: "The data service and its terms are unchecked, and a quiet day is very quiet." Dave ran `/new-wallpaper` on it on 2026-11-18. Earthquakes were under "Left out on purpose" in [ideas.md](ideas.md) as "too sparse to be lively"; running it was his overruling, and a continuous trace of the ground isn't sparse (the quiet day is below).

- **Research:** [seismograph/research-method.md](seismograph/research-method.md) (the data services and their terms, the nearest station, which band and channel, a week of real days measured, the clock and gaps, rendering and cost) and [seismograph/research-look.md](seismograph/research-look.md) (real drum records with references, their numbers, palettes, annotations, names and brands).
- **Data:** the mock-ups draw NL.HGN (the Netherlands, from ORFEUS, CC BY 4.0 declared by the NL network's DOI record) on 2026-11-15 and 16. The app would stream the nearest station by SeedLink (research-method.md §1).
- **Scripts:** `docs/seismograph/traces.py` (fetches the records once and filters them as the app would, causally, scaled to the station's own noise), `mseed.py` (the research's miniSEED reader), `mock.swift` (SKRenderer on Etching's own ground: its tooth shader and `LineRoute.grain()`), `variants.py` and `sheet.py`. Redraw a round with `python3 -I traces.py fetch <new dir>`, `python3 -I traces.py make <dir>`, then `SEISMO_DATA=<dir> python3 -I sheet.py <sheet>`.
- **Where it stands (2026-11-21):** step (a), a real day on the sheet with its settings, is in the app, hidden. Live data is next.

## Names and look-alikes
From research-look.md §5 (trademarks partly checked, through third-party mirrors: the USPTO's own pages refused automated reads). **Seismograph** is a generic word for the instrument, with no live mark found for it alone; the fallback is *Seismogram*, which names the record as Etching names the print. Kept out of the app, its settings and its keywords: **Helicorder** (Teledyne/Geotech, registrations shown as expired, but the USGS still prints it with ®), **Webicorder**, **Raspberry Shake** and its slogan "Watch the Earth Move" (live marks), and every maker's name and badge (Geotech, Teledyne, Kinemetrics, Sprengnether, Lennartz). Naming a station's network in About as the data's source is fine.

## Dave's decisions (2026-11-21)

Shown the five sheets and five films with a recommendation beside each question, he said: "lets go ahead and build this out, a light and dark version with settings to manually choose or lock to system or lock to day night cycle". He named no letters, so the build takes the recommendations as they stood:

- **View: A, the flat sheet**, today written over yesterday's faint line. Not the roll, not the drums.
- **Paper and ink: two looks, light and dark.** Light is A, Chart (dimmed cream, black-brown ink); dark is E, Smoked (soot with a pale scratch). Paper, Parchment, Blueprint and Paper Dark are not offered.
- **Which is shown: a setting**, in his words "manually choose or lock to system or lock to day night cycle": Light, Dark, Match System, or Follow Day and Night by the real Sun where the Mac is, as Etching's Screen does. Match System is the standard.
- **The line: A, long period** (10 to 50 s, 1 sample a second). Short period isn't built.
- **Minutes a row: B, 30**, with 15 and 60 as a setting, not a Speed slider.
- **The gain:** a Sensitivity slider, standard 1×, which is what every tile showed. Sheet 3's D is 0.5×.
- **Round 2 was skipped**, so its questions are answered by the mock-ups as they were: the pen a tip, hour numbers in the margin, the minute and hour marks at 0.12 of a row. A stamped label, quake notes from the USGS feed, the carriage and the Station menu are not built.
- **Still his to decide:** the Sensitivity's standard, once he has seen a real day on his desktop, and whether to write to EarthScope before any release (Still open).

## What the real thing looks like
Cut from the two reports.
- **The record:** a sheet wrapped round a drum that turns once a line while the pen moves along it on a screw, so the record is a helix: laid flat, each line falls one spacing along its length and runs on into the next (USGS, checked). Seen face on, the drum's lines run round it, up and over (the Napier drum, N1 in research-look.md).
- **The marks:** the pen steps aside 1 s each minute, 2 s each hour and 10 s at noon and midnight (Sprengnether MEQ-800 manual, checked); down the sheet the steps stack into columns, the only grid a real record has. Hours are written in the margin.
- **Real speeds:** USGS web records draw 15 minutes a line, NCEDC's 60; the old long-period drums ran at 15 or 30 mm a minute (checked). The MEQ-800's sheet is 343 × 600 mm, about a display's shape.
- **The ink:** black or black-brown on cream; a fast stroke is thinner and paler than a slow one (Weston's Tōhoku record). Smoked paper is soot with a fine pale scratch. The USGS's web plots cycle four shades of one blue by line.
- **What a day holds** (research-method.md §3, measured): drawn raw, the ocean's microseism fills the line and none of 2026-11-18's five M5.8 to 6.1 quakes rose above 2.1 times it; in the long-period band (10 to 50 s) they came through at 7 to 28 times, for 33 to 49 minutes. A week at quiet NL.HGN: six days had one or two trains of 5 to 46 times the background, lasting 17 to 140 minutes; one had none, only the microseism swelling for hours. Worldwide, an M6 or more comes every 2.6 days and an M7 every 24 (USGS count, checked).
- **The gain:** real records are scaled to their own station's noise (checked), so every line keeps its tremble: a row's spacing is 13 times the band's median minute RMS, so the quiet line swings about a fifth of a row either way.

## How it works

The plan, after research-method.md's build order, in steps, each hidden behind `unfinished`:

- **(a) A real day, still and moving.** `Seismograph.swift`, one shader on Etching's ground (its tooth, `LineRoute.grain()`, its `Surface` tones and `nightfall`), and `SeismicFeed.swift`'s miniSEED decoder (Steim1 and 2), filter (two biquads each way, Butterworth, 0.02 to 0.1 Hz, run causally over the whole buffer at each stamp, restarted at its own steady state after every gap) and gain (a row is 13 × the median minute RMS of the last 24 hours, times Sensitivity). The day is stamped off the main thread into one texture at the display's pixels: today's coverage and the row that covered it, yesterday's the same. The shader compares each texel's time (its row and its column) with the pen's, as Etching's compares with its clock, so a frame costs the same at any hour. Until live data comes, the sheet is a bundled real day, `Resources/seismograph-sample.mseed`: NL.HGN's own records of 15 and 16 November 2026 (US Central days), the pen at the Mac's time of day over the 16th.
- **(b) Settings:** Appearance, Sensitivity, Minutes a row.
- **(c) Live:** the nearest station from a baked list, searched on the Mac; SeedLink to EarthScope's ring (one connection, LHZ); one archive request for the day so far; the last three days of counts on disk (about 1 MB, one station); the status line saying which station, how far, and how far behind the pen is.

## Mock-ups, round 1 (2026-11-18)
Every tile is the same real afternoon: NL.HGN on 2026-11-16, the sheet's day in US Central time, the pen at 16:50, eighty minutes into the train of an M6.6 in the Banda Sea (21:11 UTC, 117° away), with the 15th's line faint ahead of the pen. Drawn by `mock.swift` at 3024 × 1964 on Etching's own ground; each tile's GPU time and brightness (the brightest of R, G and B at desktop size, out of 255) are under it.

1. **The view** ([sheet1-view.jpg](seismograph/sheet1-view.jpg)). A the flat sheet: the day as a page, midnight at the top, the pen writing today over yesterday's faint line, so the sheet is always full. B the last 24 hours, the newest row at the bottom, the rows moving up a row each half hour. C the drum upright: the rows run round it, the pen still at the front, the paper turning past (5.4 device pixels a second, [film2-drum.mp4](seismograph/film2-drum.mp4)). D the drum as recorders stand, its axis across: the rows run up and over it. **Recommended: A,** as both reports recommend: "a day to a sheet" reads at a glance, and a drum hides half of each row and the day's earlier rows behind it. C is grander and the one to keep if he wants the drum.
2. **The paper and ink** ([sheet2-surface.jpg](seismograph/sheet2-surface.jpg)). A Chart, new: a dimmed cream (208, 200, 184) under black-brown ink, the look research's Light pick; B Etching's Paper; C Etching's Parchment, sepia; D blue ink, four blues by row, on Etching's Blueprint; E Smoked, new: soot with a pale scratch; F Etching's Paper Dark, chalk on charcoal. **Recommended: A for Light Mode and E for Dark,** following the system as Etching's Screen does, with the rest as picks. Chart's median is 207 where Paper's is 235: this is a sheet that is nearly all ground, with no picture to break it, so it is the dimmer cream. E is the dimmest of all (median 34).
3. **What the line shows** ([sheet3-band.jpg](seismograph/sheet3-band.jpg)). A long period, 15 to 50 s: quakes from anywhere on Earth; B short period, 0.5 to 8 Hz: a hairy line that thickens by day in a city and catches local quakes; C raw, as the station records it: the microseism fills it and the M6.6 is lost; D long period at half the gain, calmer. **Recommended: A,** with B as a pick. C is here to show why not. Whether D's calmer gain is better is his eye's call.
4. **Minutes a row** ([sheet4-rows.jpg](seismograph/sheet4-rows.jpg)). A 15 (96 rows, the USGS's look), B 30 (48, the idea's), C 60 (24, big swings, the wiggle crowded). **Recommended: B,** offered with the others as a setting instead of a Speed slider: a faster pen would no longer be the ground's own time.
5. **At the app's scale** ([sheet5-desk.jpg](seismograph/sheet5-desk.jpg)): A, Chart, long period, 30 minutes, under a menu bar and folders. **Films at the real pace:** [film1-pen.mp4](seismograph/film1-pen.mp4) (the whole screen, 12 s), [film3-pen-close.mp4](seismograph/film3-pen-close.mp4) (the same 12 s at 1:1 round the pen) and [film2-drum.mp4](seismograph/film2-drum.mp4) (C). **Time-lapses** (2026-11-21, for showing only, not a proposed speed): [film4-quake-timelapse.mp4](seismograph/film4-quake-timelapse.mp4) (15:20 to 16:50 at 450 times: the M6.6's train written row by row) and [film5-day-timelapse.mp4](seismograph/film5-day-timelapse.mp4) (the whole 16th at 7,200 times: today's dark line laid over yesterday's faint one, a row each quarter second).

**What the mock-ups showed.** The quiet line is a texture, not a blank: 48 strands of fine, even tremble, as the look research said real long-period records are. The M6.6 is a dense band across three rows, crossing its neighbours, its fast strokes paler: it reads as an event without being loud. Yesterday's line ahead of the pen keeps the bottom of the sheet full (no tile has bare paper), and a grey line turning dark under the pen is the one place the day's progress shows. The pen moves 1.7 device pixels a second: in the whole-screen film it is all but still, and only the 1:1 film shows it crawl; the wallpaper is calm to the point of stillness between quakes, which is the honest pace. The drum's paper slides 5.4 px a second, the whole screen moving. Every tile costs 0.3 to 0.6 ms of GPU in the mock's harness (Etching's ground and one or two texture reads; the drums read four taps each). A mock-up bug caught on the way: between samples the line was held flat instead of running straight from one to the next, which the drums showed as a dashed staircase (fixed before these sheets).

**For round 2, whatever is picked:** the pen itself (a tip as now, or a thin arm and its carriage); annotations (hour numbers as now, a stamped label with the real station and date, a pencilled note beside a big quake from the USGS feed); how the minute marks look at the chosen size; a quiet day (the 17th) and a great quake (the M7.7 of 2026-10-09) at the chosen look.

## The build so far

- **(a) A real day on the sheet, with its settings (2026-11-21, 0.130.23).** `Seismograph.swift` and `SeismicFeed.swift`, as the plan says, from the bundled sample day: the pen at the Mac's time of day over NL.HGN's 16 November, the M6.6's train across three rows from 15:30, the 15th faint ahead of the pen. The sheet is stamped in one texture (red and green today's coverage and row, blue and alpha yesterday's), 24 MB at 3024 × 1964; the stamp takes the CPU off the main thread when a setting or the day changes, never a frame. Two departures from the mock-ups: a fast stroke fades by 0.4 in both looks (the mock-ups used 0.5 on Chart and 0.3 on Smoked; one value means the stamp doesn't change with the look), and the hours are pencilled in a fixed grey. Settings (the plan's step (b)) came with it, since each is one line. Snapshots matched sheet5-desk by eye in both looks.

## Settings

Under **Sheet**:
- **Appearance** (`seismograph.look`): Match System (standard), Follow Day and Night, Light, Dark; stored by place as Light 0, Dark 1, Match System 2, Follow Day and Night 3, as Etching's Screen. Follow Day and Night asks where the Mac is (Etching's `nightfall`: light from 6° of Sun above the horizon, dark from 6° below, an hour's dusk), and every change eases over two seconds.
- **Sensitivity** (`seismograph.sensitivity`): 0.25× to 2×, standard 1×, which is a row's spacing at 13 times the median minute RMS of the last day.
- **Minutes a row** (`seismograph.minutes`): 15, 30 (standard), 60; stored by place.

## Cost

From the render test at 3024 × 1964 (2026-11-21): 0.41 ms of CPU and 0.34 to 0.40 ms of GPU a frame. `batteryRate` 10 (the pen moves 1.7 device pixels a second). Memory: the sheet's texture, 24 MB at 3024 × 1964 (a texel to two each way above 6.5 million pixels, as Etching's).

## Checking it

```sh
SNAPSHOT_SCENE="Seismograph" SNAPSHOT_DEFAULTS="seismograph.hour=16.8333" swift test --filter everySceneRenders   # the pen at 16:50
SNAPSHOT_APPEARANCE=light SNAPSHOT_SCENE="Seismograph" SNAPSHOT_DEFAULTS="seismograph.hour=16.8333" swift test --filter everySceneRenders
swift test --filter seismograph   # the decoder against the research's reader, and the M6.6 in the band
```
`seismograph.hour` pins the pen (hours after the sheet's midnight) and `seismograph.sun` the Sun's altitude in degrees for Follow Day and Night. On the desktop: `defaults write com.dtanquary.atrium unfinished -bool true`, relaunch, and pick Seismograph.

## Shortcuts

- `Ground.add`: one sample a second (LHZ) only. Short period's 40 a second would want its own buffer or decimating, if it's built.

## Still open
- **EarthScope's leave (risk 1 of the method report).** EarthScope forbids polling its web services for live data (it cut off the Swarm app for it in 2017) and points apps to SeedLink, a stream, one connection per Mac: within its stated limits (5 connections, a heartbeat no more than every 4 minutes), but it asks users to keep connections few and reserves the right to enforce limits. Whether thousands of Macs each holding one is acceptable is unknown; if not, the fallback is a relay server, which the project doesn't have. The report's advice is to write to EarthScope before any release, describing the load (one 1-sample-a-second channel per Mac, about 210 KB a day). That is Dave's to send, or to say to send. It doesn't hold up the mock-ups or a hidden build from archived days.
- **EarthScope's archive service** failed or took 44 to 108 s for 6 of 9 requests while the research tested it; the European, Californian and New Zealand centres answered in 0.5 to 9 s.
- **Coverage:** India, northern China, West Africa and Argentina are 660 to 1,560 km from the nearest live station in EarthScope's ring.
- **The pen runs 6 to 8 minutes behind the clock** on the 1-sample-a-second channel (its records hold about 4 minutes each), true and to be said in its status line.
- **Licences by network:** most networks' DOI records declare none, so the app relies on EarthScope's CC BY 4.0 default and the European networks' declared CC BY; the baked station list must hold only networks checked one by one.

## Sources
- The two research reports above, each with its sources and what was checked.
- NL.HGN waveforms: ORFEUS EIDA (https://www.orfeus-eu.org/fdsnws/dataselect/1/), Netherlands Seismic and Acoustic Network (KNMI), DOI 10.21944/e970fd34-23b9-3411-b366-e4f72877d2c5, CC BY 4.0.
- Quake list: USGS (https://earthquake.usgs.gov/fdsnws/event/1/), public domain.
