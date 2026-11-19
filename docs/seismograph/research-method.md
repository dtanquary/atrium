# Seismograph: the method research

A research agent's report, 2026-11-19, on how to build Seismograph: a day's ground motion from the nearest open seismic station, drawn by a pen line by line on Etching's paper. The data was the biggest risk, so most of this is about the data. Nothing here is built.

**How to read the marks.** *Checked* means a page says so, and its address is given. *Measured* means I fetched or computed it from this Mac on 2026-11-19 between 04:12 and 04:35 UTC, with the scripts in the scratch folder (a miniSEED decoder, a SeedLink probe, a day analyser). *Derived* is my arithmetic on those. *Unchecked* means no source was found or read.

## Recommendation in ten lines

1. **Live data by SeedLink, not by polling.** EarthScope forbids "polling for real-time continuous time series data" through its web services and blocked the Swarm app in 2017 for exactly that; it points apps to SeedLink, a streaming TCP protocol (checked). One connection per Mac, one channel, a record every 13 s to 4 min.
2. **The source:** EarthScope's ring, `rtserve.earthscope.org` (port 18000, or WebSocket on 443): 2,834 stations with a live vertical broadband channel from 143 networks, records arriving 3 to 5 s after their last sample (measured). GEOFON's ring adds Europe. Licence: CC BY 4.0, EarthScope's default for any network that declares none, and declared by GE, NL, G and IV (checked).
3. **Nearest station without sending where the Mac is:** bake the list (about 120 KB) into the app and search it locally. Nearest is 4 to 100 km for 20 of 30 big cities tried (most of the US, Western Europe, Japan, Korea, Australia, islands with a GSN station), 150 to 370 km for five, and 660 to 1,560 km in India, northern China, West Africa and Argentina (measured on the ring's list). Connecting to a station does tell its server the Mac's region; say so.
4. **Draw the long-period band (10 to 50 s), not the raw broadband trace.** Raw, the ocean's microseism fills the line, and on 2026-11-18 not one of five M5.8 to 6.1 quakes rose above 2.1 times the background at three stations. In the 10 to 50 s band the same quakes came through at 7 to 28 times it, for 33 to 49 minutes (measured). Offer Short period (0.5 to 8 Hz) as an option for local quakes and the day-and-night hum.
5. **Channel LHZ (1 sample a second) for the long-period look:** 210 KB a day, one sample to 1.7 pixels at 30 minutes a line. The pen then runs 6 to 8 minutes behind the clock (the ring's LHZ records hold about 4 minutes each). BHZ (40 a second, 3.4 to 5 MB a day) only when Short period is picked.
6. **Quiet days are honest but not empty:** in a week at a quiet Dutch station, six days had one or two quake trains at 5 to 46 times the background, lasting a quarter of an hour to over two hours, and one had none, only the microseism swelling for hours (a storm at sea, presumably). The pen always moves, the sheet always fills.
7. **Never empty:** the sheet always holds 24 hours. Yesterday's line stays faint on each row until the pen reaches it. First launch draws the last 24 hours at once (one archive request, about 210 KB); the app keeps the last two days on disk (under 0.4 MB), so a relaunch or wake needs nothing but the gap.
8. **Rendering reuses Etching's ground, tones and day-and-night, not its route.** On a helicorder time is position, so no texture of draw times is needed: one small texture of each pixel column's lowest and highest pen position per row (3024 × 48, about 0.6 MB), redrawn as data lands, and a shader that reads up to seven rows round each pixel. Estimate 0.35 to 0.55 ms of GPU (not timed), CPU near nothing.
9. **Pace:** 30 minutes a line is 1.7 device pixels a second on a 14-inch screen, so `batteryRate` 10. USGS webicorders use 15 minutes a line and NCEDC's 60 (checked); offer 15, 30, 60.
10. **Risks, worst first:** EarthScope's tolerance of many SeedLink connections from one app (ask them before release); EarthScope's archive service was failing as I tested; and one quiet day in seven.

## 1. The data services

### What each one is and does

| Service | Address | Formats | Response (measured) | Newest sample behind the request (measured) |
|---|---|---|---|---|
| EarthScope FDSN dataselect | `service.earthscope.org/fdsnws/dataselect/1/query` (the old `service.iris.edu` answers with a 307 to it) | miniSEED; GeoCSV listed, but every GeoCSV request gave 502, the docs' own 2018 example too; "SAC and text" are "not yet supported" (checked, service page) | 44 to 108 s when it answered; 6 of 9 requests failed (502 or a 180 s timeout) | 0.0 to 0.4 min |
| EarthScope `irisws/timeseries` (plain text out) | `service.iris.edu/irisws/timeseries/1/` | — | "This service has been retired" | — |
| EarthScope `fdsnws/availability` | — | — | "This service has been retired" | — |
| EarthScope SeedLink ring | `rtserve.earthscope.org:18000`, TLS on 18500, WebSocket `wss://rtserve.earthscope.org/seedlink` (checked, https://docs.earthscope.org/service/seedlink) | 512-byte miniSEED records, 8-byte header each | connects in under a second | records arrive 3.3 to 5.0 s after their last sample (IU.ANMO BHZ) |
| GEOFON (GFZ) dataselect and SeedLink | `geofon.gfz.de/fdsnws/...`, `geofon.gfz.de:18000` | miniSEED | 0.6 to 1.1 s | 4.7 min (GE.WLF) |
| ORFEUS (EIDA, Netherlands) | `www.orfeus-eu.org/fdsnws/...` | miniSEED | 0.6 to 2.0 s | 2.3 min (NL.HGN) |
| INGV, ETH (EIDA) | `webservices.ingv.it`, `eida.ethz.ch` | miniSEED | 8.8 s, 2.0 s | 3.3 min, 1.5 min |
| NCEDC, SCEDC (California) | `service.ncedc.org`, `service.scedc.caltech.edu` | miniSEED | 1.1 s, 0.5 s | 0.0 min, 0.2 min |
| GeoNet near-real-time (New Zealand) | `service-nrt.geonet.org.nz` | miniSEED | 1.9 s | 0.3 min |
| AusPass (Australia) | `auspass.edu.au` | miniSEED | 0.8 s | 5.8 min |
| Raspberry Shake | `data.raspberryshake.org` | miniSEED | answered 204 (no data) for the one station tried | — |

Every record seen was miniSEED 2, Steim2-compressed, 512 bytes, big-endian. There is no plain-text route left at EarthScope, so the app needs a miniSEED decoder: Steim1/2 is about 60 lines (mine, in Python, matched every record's own check value: 0 of 346 records wrong, measured). It is a small, well specified format; no dependency is needed.

### Terms of use

- **EarthScope web services:** "polling for real-time continuous time series data is not allowed"; "no more than 5 concurrent connections to any combination of web services"; "no more than 10 connections per second"; past the limits the network "will deny connections (via a TCP RESET)". For near-real-time data: "please use our streaming service" (checked, https://ds.iris.edu/ds/nodes/dmc/services/usage/).
- **The Swarm precedent:** in 2017 the DMC stopped serving the Swarm app, which made about 75% of all dataselect hits (8 to 10 million a day) by polling for near-real-time data, while shipping under half a percent of the data; it pointed Swarm to SeedLink (checked, https://ds.iris.edu/ds/nodes/dmc/news/2017/10/disallowing-usage-by-swarm-application-to-access-time-series-data-via-web-services/). A wallpaper that polled dataselect from every Mac would be the same thing. Fetching a past span once (the day so far, at first launch) is an archive request, not polling, and stays allowed.
- **EarthScope SeedLink:** "no more than 5 concurrent connections"; heartbeats "no more frequently than once every 4 minutes"; "Data stream history should not be expected to exceed 1 hour"; users should "minimize the number of connections"; "We reserve the right to enforce connection limits" (checked, https://docs.earthscope.org/service/seedlink). One connection per Mac is within the letter. Thousands of Macs, each with its own, is the open question: ask EarthScope (risk 1).
- **EarthScope's site terms:** automated clients are "restricted from taxing the resources of the Website beyond what would be typical of a human visitor", and EarthScope may "curtail or prevent access ... for any reason"; users "must acknowledge EarthScope Consortium and our sponsors" (checked, https://www.earthscope.org/terms-of-service/).
- **SCEDC:** three concurrent sessions (unchecked: a search summary of its service page).
- **EIDA/ORFEUS:** its web services page states no rate rule and no polling ban (checked that it says none, https://www.orfeus-eu.org/data/eida/webservices/). Not a licence to poll: the same courtesy applies.
- **Raspberry Shake:** its FDSN server answers 429 (too many requests) with no published limit; a staff member suggests "a slight delay between your queries (I use 5 seconds, for example)" (checked, https://community.raspberryshake.org/t/fdsn-dataselect-server-rate-limiting-too-strict/4049). Data licence unchecked. Leave it out.
- **User-Agent:** none of the pages asks for one. Send a generic one (Atrium's name, no contact).

### Licences, network by network

- **EarthScope's default:** "When no license has been declared by the owner, the facility distributes the data with a license of" CC BY 4.0; cite "both the network owners, identified by network code," and the facility (checked, https://docs.earthscope.org/sponsored-open-data). EarthScope announced this on 2025-06-12 (unchecked: a search summary).
- **Declared CC BY 4.0** in the DOI's own record (checked, DataCite, `https://api.datacite.org/dois/<doi>`): GE GEOFON (10.14470/TR560404), NL Netherlands (10.21944/e970fd34-23b9-3411-b366-e4f72877d2c5), G GEOSCOPE (10.18715/GEOSCOPE.G), IV Italy (10.13127/SD/X0FXNH7QFY).
- **No licence in the DOI record** (checked, same API): IU and II (the Global Seismograph Network), US, BK, CI, AM (Raspberry Shake), CH, CU, IC, and New Zealand's NZ. The FDSN's network pages have no licence field either (checked, https://www.fdsn.org/networks/detail/IU/, `/GE/`, `/II/`). For these, served by EarthScope, its CC BY 4.0 default applies (derived from the rule above). IU and US are run with the USGS, and "USGS-authored or produced data and information are considered to be in the U.S. Public Domain" (checked, https://www.usgs.gov/information-policies-and-instructions/copyrights-and-credits); whether IU's waveforms count as USGS-produced is unchecked, and CC BY covers it either way.
- **GeoNet (New Zealand):** "licensed under a Creative Commons Attribution 3.0 New Zealand License", with the sponsors acknowledged (checked, https://www.geonet.org.nz/policy).
- **Restricted stations exist:** GE.JAGI answered 403 (measured). The baked list must hold only stations the ring actually serves, from networks whose licence is checked, one by one, when the list is made.
- **The credit:** a line in Settings ("Seismic data: <network name> (<code>), via EarthScope / GEOFON, CC BY 4.0"), naming the station drawn.

### What the USGS earthquake feed adds

The summary feeds (`earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_day.geojson` and others) are "Updated every minute" and "intended to be used as a programatic interface for applications" (checked, https://earthquake.usgs.gov/earthquakes/feed/v1.0/geojson.php); USGS data are public domain (checked, above). A day of M4+ was 19 KB (measured). This is the honest way to name a train of waves: "M6.6, Banda Sea, 13,000 km", pencilled beside it.

## 2. The nearest station, without sending where the Mac is

- **The ring lists itself.** `https://rtserve.earthscope.org/streams` returns every stream with its oldest and newest sample, 3.7 MB (measured). Joined with the station service's coordinates (one request for every station with BHZ or HHZ, 447 KB, 0.5 s, measured): **2,834 stations with a live vertical broadband stream** (newest sample under 15 minutes old) **from 143 networks**, and 57 stale streams, 2% (measured). By channel: 2,164 live HHZ, 1,136 BHZ, 998 LHZ, 362 EHZ, 117 SHZ (measured).
- **Bake it, search it locally.** A row of network, station, location, channel, latitude, longitude and server is about 35 bytes, so 3,000 to 3,500 stations is about 120 KB (derived). A script remakes the list at each release, from the ring's list and the licence check. Nothing about the Mac goes anywhere until it connects, and then only the station's code.
- **What the connection says:** the station's server learns the Mac's IP address and which station it wants, so roughly where it is, to within the stations' spacing (5 to 100 km in a dense network). That is coarser than the 0.01° Open-Meteo already gets for the weather.

**Nearest live vertical broadband station in EarthScope's ring** (measured, three nearest kept in the scratch output):

| Place | Nearest | Place | Nearest |
|---|---|---|---|
| New York | LD.CUNY, 16 km | London | GB.HMNX, 77 km |
| Chicago | NW.L44A, 40 km | Berlin | CZ.HSKC, 210 km (GEOFON's ring has nearer, unchecked) |
| Los Angeles | CI.USC, 5 km | Madrid | WM.UCM, 40 km |
| Denver | US.ISCO, 54 km | Moscow | II.OBN, 96 km |
| Miami | N4.061Z, 71 km | Nairobi | IU.KMBO, 54 km |
| Toronto | WU.TORO2, 20 km | Lagos | GT.DBIC, 912 km |
| Mexico City | G.UNM, 11 km | Johannesburg | GT.LBTB, 275 km |
| São Paulo | BL.VABB, 71 km | Cairo | GE.EIL, 364 km |
| Buenos Aires | RI.LPCA, 669 km | Dubai | II.UOSS, 95 km |
| Tokyo | JP.JYT, 74 km | Mumbai | II.PALK, 1,562 km |
| Seoul | IU.INCN, 36 km | Delhi | II.NIL, 675 km |
| Beijing | IU.INCN, 927 km | Singapore | MS.UBIN, 19 km |
| Sydney | AU.SYDS, 4 km | Perth | AU.CARL, 4 km |
| Auckland | NZ.HIZ, 185 km (GeoNet has nearer) | Honolulu | PT.KHLH, 154 km |
| Reykjavik | II.BORG, 77 km | Suva | II.MSVF, 54 km |

- **Down or gappy:** keep the three nearest. If the chosen stream sends nothing for 10 minutes past its usual record interval, move to the next, and back to the nearest an hour later. Real records have gaps; leave them bare, as a real drum would show a flat or missing stretch, never a made-up line.
- **A Station menu:** Nearest, then a short list of famous GSN stations (ANMO, Albuquerque; HRV, Harvard; KIP, Hawaii; CTAO, Australia; MAJO, Japan; KMBO, Kenya), which also answers "the nearest is 1,500 km away".

## 3. Which channel, and how to draw it

### What a day really looks like (measured, 2026-11-18, three stations)

BK.BKS (Berkeley), GE.WLF (Luxembourg), NL.HGN (Netherlands), whole-day BHZ, filtered by FFT into bands; "×" is a minute's RMS over the day's median minute. 2026-11-18 was a busy day: 26 M4+ worldwide, five of M5.8 to 6.1 (USGS). Over the past year there were 474 M5.5+ (1.3 a day), 140 M6+ (one every 2.6 days) and 15 M7+ (one every 24 days) (checked, USGS count API, `earthquake.usgs.gov/fdsnws/event/1/count`).

| Band | What it shows | Quakes of the day |
|---|---|---|
| Raw broadband, high-passed at 0.05 Hz | the secondary microseism (periods of a few seconds, the ocean's waves pressing on the sea floor) fills it: 99.9% of the day within 3.4 to 4.2 × | none above 2.1 × at any station |
| Long period, 0.02 to 0.1 Hz (10 to 50 s) | a slow, fine wiggle; surface waves of distant quakes | M5.8 to 6.1 at 68 to 98°: 7 to 28 × at BKS for 33 to 49 min; M5.9 Peru 12 × for 36 min at WLF and HGN. 99 to 187 minutes of the day above 3 × |
| Short period, 0.5 to 8 Hz | traffic and machines, wind, local quakes | teleseisms 1.0 to 1.8 × in Europe; at BKS the same quakes are no clearer than its afternoon hum (that hour's own mean is 1.5 to 2.0 ×); a regional M5.3 (Romania, 130 km deep, 14° away) 2.6 to 3.2 × for 2 min in Europe at night; an M4.2 off Oregon (820 km) no clearer than BKS's afternoon |

- **The day-and-night rhythm** (hourly mean over the median): short period at BKS from 0.5 (00 to 02 UTC) to 2.0 (18 UTC), four to one; at WLF 0.8 to 1.3, at HGN 0.9 to 1.2. The microseism band changes by 0.7 to 1.4 at BKS and 0.9 to 1.2 in Europe. So the day's hum shows at a city station, and hardly at a quiet one.
- **A week at one quiet station** (NL.HGN, LHZ, 11 to 17 November, long-period band; measured): trains peaking at 5 × or more on each day: 2, 1, 2, 1, 1, 1, 0. Peaks 5 to 46 × the median minute, single swings 7 to 92 ×; each lasting 17 to 140 minutes; rows of 30 minutes touched by anything over 3 ×: 3, 10, 13, 2, 3, 6 and 0 of 48. The biggest was an M6.6 in the Banda Sea, 117° away: 46 × for 140 minutes. On the seventh day nothing in the long-period band, but in 0.02 to 0.4 Hz fifteen spells of 3 to 4 × lasting up to 83 minutes: the microseism swelling (a storm at sea, presumably; unchecked).
- **A great quake** (M7.7, Panama, 2026-10-09, at NL.HGN, 82° away; measured): first arrival about 15 minutes after the origin; long-period peak 1,282 × the hour before's RMS, over 10 × for 178 minutes and over 3 × for 240 (eight 30-minute rows); unfiltered, 433 × at the peak, over 3 × for 193 minutes.
- **An M5 at 1,000 to 1,500 km** is two or three times the background for a few minutes in short period, and lost in a city's daytime hum (the Romania and Oregon quakes above); an M6.5 at 5,000 km is between the day's M6.1 (28 ×) and the Panama M7.7 by about a factor of 3 a magnitude unit (derived, rough: surface waves scale about tenfold per magnitude, unchecked here): roughly 50 to 150 ×, an hour or two.

### Recommendation: long period by default

- **Look: Long period** (as the long-period drums of the old WWSSN network, which ran at 15 or 30 mm a minute beside a 60 mm a minute short-period drum (checked, National Academies, https://www.nap.edu/read/18566/chapter/5)): band-pass 0.02 to 0.1 Hz. Quakes from anywhere on Earth come through as trains of slow waves, the thing the idea promised; the quiet line is a fine, slow wiggle with periods of 17 to 85 pixels at 30 minutes a row (derived). **Short period** as the other pick: 0.5 to 8 Hz, a hairier line that thickens by day in a city and catches local quakes, with distant ones rare.
- **Channel:** LHZ for Long period (1 sample a second: 1,800 a row, one to 1.7 pixels, enough for periods of 10 s and more; 210 KB a day, measured on a week of NL.HGN). Where the nearest station has no LHZ, decimate its BHZ to 1 a second on the Mac (Accelerate's `vDSP.Biquad`, native). BHZ for Short period: 40 a second, 3.4 MB a day at EarthScope, 4.0 at BKS, 5.0 at HGN; 20 a second 2.7 MB (GE.WLF) (measured). Avoid HHZ (100 to 200 a second: 9 to 14 MB a day, derived from 93 to 147 KB per 15 minutes, measured).
- **Filter on the Mac** with two biquad sections each way, run as each record lands; the first minutes after a gap ring, so start the filter on the minute before.
- **Per pixel column, the lowest and highest pen position** (a helicorder's envelope), with each column's range stretched to meet its neighbours so the line never breaks. At 30 minutes a row a column is 0.6 s: one LHZ sample, or 24 of BHZ.
- **Gain from the noise, as the webicorders do** ("magnified according to background noise", checked, https://earthquake.usgs.gov/monitoring/seismograms/about.php): row spacing about 12 to 15 times the band's median RMS over the last 24 hours, so the quiet line swings about a fifth of a row either way (derived: 3 × RMS ÷ 13), an M5.8 at 70 to 100° over one to three rows, and the week's M6.6 to the clip. Recompute hourly and ease it, never jump.
- **Clip like a real pen:** a soft limit at 2.5 rows either way. An M7+ then lays a dense band over five or six rows for an hour or two, which is what a drum record of one looks like; it comes once every three or four weeks.

## 4. The quiet day

**Is it "very quiet"?** In the long-period band, at one quiet station, one day in seven had no quake train at all, and six had one or two (measured, above). In short period at a quiet station, most days have nothing but a hum that changes by a third over the day. So: long period by default, and the quiet day is quiet, not empty. What keeps the screen alive, all of it real:

- **The pen always moves**, 1.7 pixels a second at 30 minutes a row, and lifts and falls with the slow wiggle under it.
- **The sheet fills** through the day; the rows already drawn are the day so far.
- **Minute marks**, as real recorders made: a small tick each minute and a longer one each hour (the timing pulse). Hour labels pencilled in the margin, local and UTC, as the USGS's pages do (checked, the USGS page above).
- **The weather at sea shows:** the microseism swells over hours with distant storms (the seventh day above).
- **Yesterday under today** (recommended, and the answer to the never-empty rule): each row keeps yesterday's line, faint, until the pen reaches it; at midnight nothing clears. The sheet always holds the last 24 hours.
- **A quake's name, pencilled beside its train** (switch, on by default): from the USGS 4.5_day feed, fetched once every 15 minutes while the scene shows (public domain, checked). Match a train to an event by its predicted first arrival (first-arrival time from the distance, roughly 8 min at 40°, 13 at 90°, 17 at 140°, from a 12-point table I wrote from memory of the standard tables, unchecked; good enough to match a train that lasts half an hour). Honest: it labels only what the catalogue lists, and only once the waves are on the paper.
- **Not recommended:** a replay of famous quakes in the live sheet (it would read as today's). As a separate Station pick ("Tōhoku 2011 at ANMO", dated in pencil) it is honest, and archive data is fine to fetch once; later, if wanted.

## 5. Clock, latency, gaps

- **The pen is at the clock minus the station's delay, shown honestly.** It draws at `now − d`, with `d` just over the channel's record length plus its latency: LHZ about 6 to 8 minutes (EarthScope's LHZ records for IU.ANMO held 237 to 256 s each, and the newest one's last sample was 1.4 minutes old as it arrived, measured), BHZ about 30 s (records of 13 to 18 s, then 3 to 5 s, measured). The status line says "Pen 7 min behind the ground at IU.ANMO, 54 km away". No estimate is drawn ahead of the data.
- **Late data fills in behind the pen**, a short fade, never a made-up line.
- **First launch:** connect to SeedLink with `TIME` set to 24 hours ago; the ring gives what it holds (median 1.7 hours, 0.1 to 17.9 by stream, measured; 15 minutes was all it had for IU.ANMO at 04:20 UTC, 4.1 hours at GEOFON for GE.WLF, measured) at once. In parallel, one archive request for the rest of the day from the station's FDSN service (LHZ: 210 KB). Rows ink in as each lands.
- **Wake from sleep or a relaunch:** the last two days are on disk (1 sample a second as half floats, 173 KB a day, under 0.4 MB, derived; bounded, as the no-unbounded-disk rule asks). Ask the ring for the gap; past its depth, one archive request.
- **Offline, or every server failing:** keep showing the last sheet from disk, with "Offline since 14:20" in the status line and the pen stopped where its data ends. On a first launch with no network at all, show a bundled real day (one station, one notable day, about 200 KB, dated and named in pencil) until data arrives: real, labelled, and never a blank sheet.
- **No location permission:** `Location`'s time-zone guess picks the station; Follow Day and Night works as in Etching.
- **Firewalls** that block port 18000: EarthScope offers SeedLink over WebSocket on 443 (checked), which `URLSessionWebSocketTask` speaks natively. Try TCP first, then that.
- **Which code is new:** a SeedLink client (`NWConnection`, about 100 lines: `HELLO`, `STATION`, `SELECT`, `TIME`, `END`, then 520-byte packets; tested by hand here against both rings, measured) and a Steim2 decoder (about 60). The app has no Network.framework code yet.

## 6. Rendering within budget

### What is shared with Etching and what is new

- **Shared:** the four surfaces with their light and dark tones and line colours, the tooth recipe (`LineRoute.grain()`'s tile, the hashes, the fibres, the light from the upper left), `shade` and `inked` easing, Follow Day and Night by the real Sun, every read at a texel's centre, and the knobs for Surface and Screen as data. Probably a shared helper, moved out of `Etching.swift`, so both read the same surfaces table.
- **Not shared:** the route, its stamp, and the textures of draw times. Etching needs a time per texel because its line wanders; on a helicorder **time is position** (row, then column), so whether a column is drawn is one comparison of its own time with the pen's, worked out in the shader from `u_now`. No 24-bit times, no restamping.
- **New:** an envelope texture, a texel per column per row holding the pen's lowest and highest position in that column (two half floats, RG16F): 3024 × 48 × 4 bytes = 0.58 MB at 30 minutes a row (derived), twice that for yesterday's sheet. It is rebuilt on the CPU and sent whole when a record lands (once every 4 minutes for LHZ, every 13 s for BHZ): 0.6 MB, trivial. At 5K and 6K, a column to two pixels.

### The shader

For a pixel: its row from y; for each row within the clip range (±3 rows, so seven reads at most, fewer in the common case if rows beyond ±1 are only read where the envelope's own maximum says they reach), read that row's column, offset by its distance in rows, and take the coverage of the pixel's y against the column's range widened by the pen's half-width (about 0.7 px, antialiased). A column counts only if its time is before the pen's; yesterday's texture fills the rest of the row at about a fifth of the ink. Then the tick marks (a function of the column's time), the tooth, and the drum's shading. A small sprite for the pen carriage, moved each frame.

**Cost, estimated, not timed:** Etching's shader, with the same tooth (two reads of its tile) and one read of each of its two route textures, measures 0.30 to 0.36 ms of GPU at 3024 × 1964 (checked, `docs/etching.md`, Cost). Seven reads of a 0.6 MB texture that sits in cache, and no time decoding: 0.35 to 0.55 ms (derived guess). CPU: decoding a record, filtering and rebuilding one row's envelope is well under a millisecond, once every few minutes; per frame only `u_now` and the pen sprite. Well inside 2 ms and 2 ms. Time it in the first build with the render test; I did not build a probe.

### The view: flat sheet or drum

- **A flat sheet** (the webicorder): the whole day visible, the pen crawling across, the rows filling down the screen. Dave's "a day to a sheet" reads at a glance. 48 rows at 30 minutes in 1,964 pixels leave about 36 pixels a row inside margins (derived).
- **A drum seen from the front:** on a real drum recorder the paper turns under a pen that only shifts sideways, "making a big spiral or helical record" (checked, the USGS page above); the line runs round the drum. So the pen stays put, the paper slides under it, and only the front of each turn shows, curving away at the edges; the day's earlier rows are on the far side. Grander, but half of each row is hidden and "a day to a sheet" is lost. Which way the lines run on screen depends on how the drum is turned; with the axis upright the rows run left and right and foreshorten at the sides. The shader is the same either way: screen position maps to paper by an arcsine, plus a rotation by the clock, and shading by the cosine.
- **Recommendation:** mock up both. My pick is the flat sheet by default with a View pick for the drum, since the drum hides what makes a quiet day worth looking at.

## 7. The pace

- **30 minutes a row** on a 14-inch Retina screen (3,024 device pixels across): 1.68 px a second (derived). 15 minutes: 3.4; 60 minutes: 0.84. On the drum, at 30 minutes a turn, the paper at the front moves π × width ÷ 1,800 s, 5.3 px a second (derived).
- **`batteryRate` 10:** 0.17 px a frame on the sheet, 0.5 on the drum. Nothing else moves but the pen's rise and fall, which follows the trace's slow wiggle.
- **What the real ones do:** USGS webicorders draw 15 minutes a line, four an hour (checked, https://earthquake.usgs.gov/monitoring/seismograms/about.php); NCEDC's draw 60 minutes a line, a day to 24 lines (checked, https://ncedc.org/waveformDisplayFAQ.html). WWSSN's photographic drums ran at 60 mm a minute (short period) and 15 or 30 mm a minute (long period) (checked, the National Academies page above); a 15-minute turn at 60 mm a minute and a 90 cm sheet are what I recall, unchecked.
- **Which looks better:** 30 minutes (48 rows of about 36 px) is the middle. 15 minutes (96 rows of 18 px) is the USGS's look and denser, with the long-period wiggle twice as wide; 60 minutes (24 rows of 75 px) gives room for big swings but crowds the wiggle (a 15 s period would be 13 px). Offer "Minutes a row: 15, 30, 60" in place of a Speed slider: a faster pen would no longer be the ground's own time.

## 8. The same drum for other data (low priority)

- **Barometer:** Open-Meteo already serves the app (CC BY 4.0, as the app's own `LiveWeather.swift` says); `pressure_msl` would be one more field on the call it makes (derived; the app does not fetch pressure now). Its values are hourly or 15-minute model output, and pressure moves a few hPa a day, so a 30-minute row would be nearly straight. It wants a barograph's week to a turn (unchecked), not this pace.
- **Tide:** NOAA CO-OPS water levels every 6 minutes (`api.tidesandcurrents.noaa.gov/api/prod/datagetter`), US stations only; at San Francisco 44 readings so far today, 1.51 to 1.73 m over 4.4 hours (measured). Licence as a US government work, unchecked. Smooth, and slow for 30-minute rows: a day to a turn.
- **Solar wind:** NOAA SWPC's real-time 1-minute data (`services.swpc.noaa.gov/json/rtsw/rtsw_wind_1m.json`, the old `products/solar-wind/plasma-1-day.json` answered 404), 4,193 rows, 3.1 MB a fetch, speed 333 to 465 km/s over the last day (measured). Too big to fetch often (smaller products may exist, unchecked); licence unchecked. It moves more than the other two, with storms now and then, but much less than the ground.

## 9. Risks, worst first

1. **EarthScope's tolerance of the app.** SeedLink is the sanctioned route and one connection per Mac is within the stated limits, but EarthScope asks users to minimise connections, reserves the right to enforce limits, and once blocked an app outright. Before release, write to EarthScope describing the load (one 1 sample-a-second channel per Mac, about 210 KB a day) and ask. If they say no, the fallback is a relay (one connection per station, fanned out by Atrium's own server), which is infrastructure the project does not have.
2. **EarthScope's archive service was failing as I tested:** 44 to 108 s a request when it answered, and 502s or a timeout for 6 of 9 (measured; the data-select move to `service.earthscope.org` is recent). The first-launch fill must not depend on it: ring first, archive in the background, the bundled day as the last resort.
3. **The filter decides whether any quake shows at all.** Drawn raw, the five M5.8+ quakes of 2026-11-18 did not show. Get the band right in the first mock-up, from real data, before any polish.
4. **Quiet days:** one in seven with no train at a quiet station; Short period at a quiet station is quieter still. Yesterday's faint rows, the minute ticks and the labels carry those days; whether that is enough is Dave's call on the mock-ups.
5. **Coverage:** India, northern China, West Africa and Argentina are 660 to 1,560 km from the nearest station in EarthScope's ring. Still real ground motion, and teleseisms look the same, but local quakes and the hum are not local.
6. **Licences per network:** most DOI records state none; the app relies on EarthScope's CC BY 4.0 default and the declared CC BY of the European networks. Check each network baked into the list, and keep the list to those.
7. **Great quakes:** an M7+ is 400 to 1,300 times the background (measured) and needs a hard pen limit. A dense dark band over several rows for hours is true but loud; a softer ink for clipped swings keeps it calm.
8. **Location:** the station chosen tells its server the Mac's region; say so in the setting's help.
9. **Bandwidth** if Short period is picked: 3.4 to 5 MB a day (about 100 to 150 MB a month), against 6 MB a month for the default.
10. **The pen runs 6 to 8 minutes behind** on LHZ. True and stated, but a quake felt in the room appears minutes later.

## Build order

1. A flat sheet drawn from a bundled real day (NL.HGN or IU.ANMO, long-period band, envelope texture, Etching's Paper), judged beside the USGS's webicorder pages. No network.
2. The SeedLink client, the Steim2 decoder and the filter, filling today's rows live; the station list baked by a script; the archive fill.
3. Yesterday's faint rows, the minute and hour marks, the USGS labels.
4. Short period, the drum view, the Station menu.

## Scratch files

`/private/tmp/claude-501/-Users-dave-Development-atrium/b725d565-5f39-416e-be8a-e1bcb23a55c6/scratchpad/seismo-method/`: `scripts/mseed.py` (miniSEED 2 reader, Steim1/2), `scripts/sl.py` (SeedLink probe), `scripts/probe.py` (FDSN latency), `scripts/day.py` and `scripts/week.py` (band analysis against the USGS catalogue), `scripts/near.py` (nearest stations), and the downloads they read (the large day files deleted).
