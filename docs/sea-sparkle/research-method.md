# Sea Sparkle: the method research

A research agent's report, 2026-11-07, on how to draw a bioluminescent night shore ("sea sparkle") within the battery budget: breaking waves that light blue along their crests, whitewater that glows as it runs up the beach, wet sand that sparkles. It is the night-shore look parked under Open Sea in [ideas.md](../ideas.md). Nothing here is built. The look (photos, colours, framing) is the other researcher's.

**How to read the marks.** **Checked** means I or the fact-checking agent read it on the page whose URL is given (list at the end, keys in brackets). **Abstract** means checked against an abstract or search summary only. **Unchecked** means nobody found a source saying it. **Derived** means arithmetic on checked figures. **Measured** means timed on this Mac by the probe in §4.

## The answer, in short

1. **Method:** one full-screen perspective shader, as Murmuration's water already does: each pixel below the horizon is a point on the sea or the beach, metres from the camera. Breaking waves are *analytic*: a tiny CPU wave model hands the shader the last few waves (break time, height, angle) as vec4 uniforms, and because a bore runs in at √(g·h) over a known beach slope, the moment it passes any point is closed form. The glow there is the turbulence it left, fading; then the swash runs up and back ballistically. No simulation state, so every frame rate draws the same picture.
2. **Engines reused:** Murmuration's water plane and its slow ripples on Weather's baked `CloudNoise`; Campfire's and Live Sky's real stars (`LiveSky.catalogue`); the real Moon's place and phase (`SkyMath`, `Sky.moonPhase`, Weather's `moonPower`); `LiveWeather`'s way of calling Open-Meteo, pointed at its Marine API; `TrimNode` for the soft layer.
3. **Measured cost** (M3 Max, 3024×1964, Nebula's shader reads 1.48 ms here against the README's 1.6): **0.49 ms GPU** at full resolution with four waves and baked-noise foam; **0.33 ms** with the soft part at half resolution and stars and sparkle at full; **0.18 ms** all at half. CPU stays at SpriteKit's own 0.35–0.42 ms; the wave model costs 0.0002 ms.
4. **What breaks the budget:** a real heightfield ocean. 24 Gerstner waves for the water's normals cost 2.0 ms of GPU on their own terms, 8 cost 1.15. Foam from five-octave fbm instead of a baked texture costs +0.3 ms. Each extra wave in the loop costs about 0.03 ms once waves are skipped where they can't reach.
5. **Battery levers it can pull:** `batteryScale` 0.5 on the soft layer (sky gradient, water, glow body), keeping stars and sparkle sharp; a `batteryRate` of 20 *only* if the view is from a bluff over a gentle beach (the bores move 1–1.8 device px a frame at 20 fps; the swash about 4, and a break running along a crest more). From beach level nothing can be capped. A mostly black picture may also save backlight power on mini-LED MacBook Pros: see §5.
6. **True but soft:** a single cell's flash is about a tenth of a second, but what the eye sees in surf is millions of cells flashing as the turbulence reaches them, so the glow follows the water's stirring, which rises over the second a section takes to break and fades over seconds. Draw that envelope, never single flashes; keep sparkle sparse, sub-pixel-soft and dim.
7. **Real data:** swell height, period and direction, and the tide, from Open-Meteo's Marine API for a named real bloom beach (inland points return nothing, so "nearest coast" would need the app to find the coast), and the real Moon (moonlight drowns the glow, so a bright Moon should dim it, honestly).
8. **Biggest risks:** waves that read as lines painted on a plane (they need faces and a lip); the glow reading as flashing or neon; the swash near the camera pinning the frame rate.
9. **First build step:** one wave breaking and running up a beach, judged from a frame strip beside real footage, before anything else.

## 1. The surf, in numbers

| Quantity | Value | Mark |
|---|---|---|
| Wave speed | √(g h) in shallow water (h under a twentieth of the wavelength); gT/2π in deep water | checked [DW] |
| Where a wave breaks | when its height reaches γ·h: γ ≈ 0.78 (solitary-wave theory), about 0.8 on average; 0.6–0.8 for spilling breakers, 0.8–1.2 for plunging | checked [BS], [UH] |
| Spilling or plunging | Iribarren ξ₀ = tan β / √(H₀/L₀): spilling under 0.5, plunging 0.5–3.3, surging over 3.3. Spilling is "usually found along flat beaches" and breaks over 6–7 wavelengths | checked [IR], [BS] |
| ...for a 1 m, 10 s swell (L₀ = 156 m) | 1:50 beach ξ ≈ 0.25, spilling; 1:20 0.63 and 1:10 1.25, plunging | derived |
| Periods | wind waves 9–12 s; ground swell 13–15 s; strong ground swell 16–25 s or more | checked [SS] |
| Sets | about 3 waves to a group (3–15 or more); groups of the biggest third every 3 ± 2 min, of the biggest tenth every 9 ± 6 min, of the biggest 1% every 75 ± 30 min; groups of groups over 30 min to hours | checked [UH], [SS] |
| Surf beat | 6–8 times the mean wave period; infragravity waves 30 s to 5 min | checked [CW] |
| Swash | run-up and backwash 2–5 m/s in the field; uprush shorter than backwash; it follows the incident period, and on dissipative beaches is mostly infragravity | checked [CWS] |
| | field uprush peaks 2.05–2.35 m/s; backwash 20–40% longer; uprush lasts about V/(gβ) | search summary |
| Run-up (Stockdon 2006) | R2 = 1.1(0.35β√(H₀L₀) + ½√(H₀L₀(0.563β² + 0.004))); on dissipative beaches (ξ under 0.3) R2 = 0.043√(H₀L₀) | checked [PW] |
| ...1 m, 10 s, tan β 0.05 | 0.75 m up, about 15 m along the beach | derived |
| Foam | open-ocean whitecaps fade in 0.2–10.4 s, typically 1.4–4.8 s; leftover foam lasts 3–30 s; surf-zone foam unchecked | abstract [CA12], [PO15] |
| Breaker height on a calm night | 0.5–1.5 m is my guess; the feed gives the real one | unchecked |

**What the model takes from it (derived).** On a plane beach the bore runs in at √(g x tan β), so it reaches the shoreline from x_b in t = 2√(x_b / (g tan β)):
- **A gentle beach (tan β 0.03), spilling:** a 1 m wave breaks about 43 m out and takes about 24 s to come in, so two or three glowing bores are in the surf zone at once. The long-lasting glowing whitewater look.
- **A steeper beach (tan β 0.08), plunging:** it breaks 16 m out and comes in within 9 s, one at a time, with a lip that throws forward and folds. The brightest real light is there: "the brightest glow is in the turbulence, right where the wave folds and tumbles" [BA].
- Set waves break further out and brighter; small ones only at the shoreline. That is the variety the eye reads as real surf.

## 2. The light, in numbers

| Quantity | Value | Mark |
|---|---|---|
| Who | *Lingulodinium polyedra* (San Diego's red tides); *Noctiluca scintillans* (red form widespread, green form tropical; Taiwan's Matsu "blue tears"); *Pyrocystis* | checked [SCC], [WN], [TT] |
| What sets it off | shear stress of 0.02–0.3 N/m² for four species; 0.1–0.32 N/m² for L. polyedra | checked [LT24] |
| One cell's flash, L. polyedra | 15 ms after the stimulus (12 ms at least); 40 ± 27 to 71 ± 19 ms long in flow; up to 4 flashes in about 1 s, but typically once and then a refractory period | checked [L08], [BO25] |
| | rise 34 ms, flash 148 ms (a different instrument) | checked [LT24, Table 3] |
| One cell's flash, Noctiluca | rise 44 ms, flash 568 ms [LT24]; but "lasts 80 ms" [WN, citing Britannica]. They disagree | checked, conflicting |
| Light per flash | L. polyedra 1.17 × 10⁸ photons; Noctiluca 2.5 × 10¹¹ | checked [LT24] |
| Colour | L. polyedra 474 nm, 35 nm wide at half height; Noctiluca 470 nm; dinoflagellates 471–480 nm, 35–38 nm wide | checked [LT24] |
| ...as sRGB | 474/35 nm `#008bff`; 470/35 `#0070ff`; 480/38 `#00b3ff`, all outside sRGB and whitened to fit, shown dim | derived with the jellyfish report's colour fit (its coefficients unchecked) |
| ...as people see it | "neon blue" [SC], "electric blue" [LZ] | checked |
| Fatigue | "subsequent flashes are typically of lesser intensity"; "a few hours" between measurements of the same cell | checked [LT24] |
| Rhythm | stimulable light peaks about 2 h into the dark (P. noctiluca); light at night inhibits it; best seen "at least two hours after sunset" | checked [LT24], [SC] |
| Blooms | San Diego 2020: 9 million cells/L, light shows for weeks; most Californian red tides last 1–2 weeks; reddish-brown by day | checked [SCC], [SC] |
| | Noctiluca turns water pink or orange above about 1.5 million cells/L; its cells are 0.4–1.5 mm, big enough to see one by one; Matsu's season April–August, an event usually 1–2 days | checked [WN], [TT], [USF] |
| Where in the surf | it "outlines" breaking waves; brightest where the wave folds and tumbles | checked [LZ], [BA, a blog] |
| Wet sand and footprints | cells washed ashore glow in damp sand near the water's edge "as you compress the sand" | checked [UCSB, an unsigned Q&A] |
| | how long a footprint glows; how long drained sand keeps flashing; the glow fading as the foam spreads | unchecked, no source found |
| How bright | "much fainter than photos suggest"; photographed at f/1.4–2.8, ISO 1600–6400, 2–8 s | checked [BA, a guide] |
| Moon and stars | full Moon 0.05–0.3 lux; quarter Moon 0.01; clear moonless night 0.002; overcast starlight 0.0001 | checked [LX] |
| ...so | a full Moon lights the water and foam 25–150 times more than a moonless sky, while the glow stays as it was: its contrast falls by that much | derived |
| ...that moonlight drowns it | reports and guides only | unchecked |
| The eye at night | rods work from 10⁻⁶ to 10⁻³ cd/m², rods and cones together up to about 3; rods peak at 498 nm and cones fail in dim light | checked [SV] |
| | rods sum light over up to 100 ms, cones over 10–15 ms, and summation is longer in dim light | checked [WV] |
| | people report blue, so surf glow probably reaches the level where cones work | inference, unchecked |

## 3. How to draw it: the candidates

| | Method | Engine it reuses | Verdict |
|---|---|---|---|
| A | **One full-screen perspective shader; analytic waves fed by a CPU wave model as uniforms; foam and ripples from a baked noise texture** | Murmuration's water plane and ripples, Weather's `CloudNoise`, `shaderCommon`, `TrimNode` | **Recommended.** 0.49 ms, stateless, frame-rate proof |
| B | A photo of a real night beach (sky and sea cut away) with A drawn under it | Aurora's, Fireflies' and Murmuration's photo grounds | An add-on to A, not instead of it: the photo can only give the headland, pier or dunes; its own surf is frozen, so the water has to be A anyway. Same cost (0.46–0.49 ms) |
| C | A heightfield ocean: many Gerstner (or FFT) waves for the water's normals | none (new) | Too dear for what it buys: 1.15 ms for 8 waves, 2.0 ms for 24, before any glow. Gerstner waves also don't break. A baked FFT normal map sampled like A's ripples would cost what A's texture reads cost (unmeasured) |
| D | A world-space glow map on the CPU (512×256, decayed and stirred each frame, uploaded) | Game of Life's and Murmuration's per-frame textures | Works, +0.25 ms CPU (measured 0.64 against 0.39). Only needed for memory A can't express (footprints left by a walker, a patch exhausted by the last wave). Hold in reserve |
| E | A pre-rendered video loop | AVFoundation, as the menu's grown tile | Cheapest to play, but a loop is a loop: it breaks "no visible loop", and live swell or tide can't drive it |
| F | Schlieren's fluid solver for the foam | `Schlieren.swift` | Wrong tool: surf foam rides the bore, which the analytic model already moves; the solver is 1.9–2.1 ms of CPU by itself |

### A, piece by piece
- **The view.** A level camera; a pixel at angle θ below the horizon meets the ground at distance d = eye/tan θ, and along the shore at X = x·d/f. This is Murmuration's projection ("found for each pixel from its angle below the horizon with the eye 2 m up"). The **viewpoint is the main design choice**, because from standing height the surf zone is a thin strip near the horizon: with the eye at 1.7 m, breakers 60 m out are 2° below it. Two views work:
  - **From a bluff or a pier** (eye about 12 m, a normal lens): the surf zone fills the lower half, and everything moves slowly on screen (§5). Real bloom photos are often taken from cliffs and piers (unchecked).
  - **From the beach with a long lens** (eye 1.7 m, focal about 3 screen heights): the stacked, compressed lines of glowing crests that many bloom photos show, but the near swash crosses the screen fast.
- **The beach.** A plane of slope tan β (0.02–0.1), with one or two bars and rip channels as a 1D along-shore profile baked on each load, so each load is a new beach and some waves break on the bar and reform (§1).
- **Each wave** (one vec4: break time, breaker height, seed, obliquity in s/m along the shore):
  - It breaks where its height reaches γ·h (γ ≈ 0.78), so on a plane beach at x_b = H_b/(γ tan β) off the shoreline; set waves break further out.
  - The bore then runs in at c = √(g h). With h = x tan β, the time from the break to any point x is closed form: t(x) = 2(√x_b − √x)/√(g tan β). So for every pixel, `since` = now − (break time + t(x)) says how long ago the bore passed it, with nothing stored.
  - Glow there = (turbulence it left) × e^(−since/τ), τ of order a second or two, times the foam lace texture. A narrow bright band at since ≈ 0 is the bore's front, and a bright line at the break point while it breaks is the lip.
  - At the shoreline the swash runs up ballistically, x_r(t) = u₀t − ½ g sin β t², and back down; its edge glows, its sheet faintly; the sand it wetted keeps a sparkle that fades.
  - **Height.** The probe draws the bore flat on the water, and its picture shows the risk: lines painted on a plane. Real surf has a face, a lip and a curl, and from a bluff they stand up from the sea. Each wave's crest can be raised on screen by its height (its screen y is f·(H − eye)/d instead of −f·eye/d), drawing a dark face below a glowing lip, at a few operations a wave. Not measured; the whole loop measured 0.03–0.06 ms a wave.
- **The water between bores.** Two layers of baked noise drifting on the water plane, bending the sky's reflection and the Moon's glitter path, as Murmuration's ripples do. A coherent glitter path needs the normals to agree over a few metres; Gerstner waves gave the better path in the probe at 2–4 times the cost.
- **The sky.** A night gradient, the real stars as Campfire draws them (catalogue sprites to V 5.5 for the viewer's place and time, refreshed every 10 s), and the real Moon when it's up. Stars and Moon are sprites, so the shader's sky is only a gradient, cheap enough to leave in the soft layer.
- **Sparkle.** Points on a 1.5-point grid of `hash42` cells (never `hash21`, which tiles), switched on by how recently the swash covered them and fading over seconds.

## 4. Measured cost

A throwaway probe, not app code: `$TMPDIR/seasparkle/main.swift`, compiled with `swiftc -O`, after the jellyfish probe (`docs/jellyfish/mock.swift`, `$TMPDIR/jelly/bench`). It drives SpriteKit's `SKRenderer` at 3024×1964 as the render test does; GPU time is the command buffer's, CPU is the wall clock less the GPU; median of 60 frames after 30 to warm up, run twice (the second run is quoted; the two agreed within 0.03 ms except where noted). Nebula's shader was copied from `Shaders.swift` with a typical roll, as the reference. The probe's shore is a plausible full shader (stars, ripples, glitter, swell bands, four waves with bores, lips and swash, foam, sparkle, tone map, dither), its constants untuned.

| Variant | GPU ms | CPU ms |
|---|---|---|
| Empty scene (SpriteKit's own cost) | 0.007 | 0.35 |
| **Nebula, the reference** | **1.48** | 0.43 |
| A: shore, foam from five-octave fbm | 0.79 | 0.42 |
| **A2: shore, foam and ripples from a baked 256² noise texture** | **0.49** | 0.39 |
| A2 with 8 waves in the loop | 0.72 | 0.35 |
| A2 with 12 waves | 0.98 | 0.37 |
| A2, each wave skipped where it can't reach the pixel (a branch on its distance and age): 4 waves | 0.43 | 0.38 |
| The same with 8 waves | 0.55 | 0.37 |
| A2 drawn at 0.75 in a `TrimNode`-like effect node | 0.27–0.43 (unsteady) | 0.38 |
| A2 drawn at 0.5 | 0.18 | 0.37 |
| A2 with 12 waves, drawn at 0.5 | 0.31 | 0.36 |
| **A2 split: soft layer at 0.5, stars and sparkle at full resolution** | **0.33** | 0.39 |
| The sharp layer alone | 0.19 | 0.37 |
| B: a 4096×2048 photo backdrop, A2 below the horizon only | 0.46–0.49 | 0.41 |
| The photo alone | 0.13–0.24 | 0.36 |
| C: 24 Gerstner waves for the water's normals (fbm foam) | 2.03 | 0.42 |
| C with 8 Gerstner waves | 1.15 | 0.42 |
| D: a CPU glow map 512×256, decayed, stirred and uploaded each frame, + A2 | 0.49 | 0.64 |
| The CPU wave model (16 spectral components, 4 uniforms written) | | 0.0002 |

What it shows:
- **The analytic shore costs a third of Nebula**, and a fifth with the soft layer at half resolution. There is room for faces on the waves, a reflection of the lip in wet sand, and a photo headland.
- **Texture reads beat noise math**: baked foam saves 0.3 ms over fbm, as Murmuration and Weather already found with `CloudNoise`.
- **Wave count is the main dial**: about 0.06 ms a wave a frame when every pixel below the horizon runs every wave, and 0.03 ms with a branch that skips a wave where it can't reach the pixel (beyond its break, or long after its bore passed). Four to six waves cover a surf zone (two or three bores in at once on a gentle beach, plus the swash).
- **Unmeasured:** smaller Apple GPUs (every wallpaper scales alike, so judge by the render test as the budget does); a 6K display (3.4 times the pixels); on-desktop cost with WindowServer (`liveCost`); the real stars as sprites (Campfire's figures would apply).

## 5. The battery: which levers this scene can pull

**The fastest thing on screen decides `batteryRate`.** Derived device pixels a frame (2x, 1964 px tall), for a 1 m swell; bore speed √(g h); swash starting at about 2 m/s, √(g·0.4 H) (the 0.4 is my assumption of the bore's height at the shoreline, unchecked; 2 m/s is the low end of the field's 2–5 m/s [CWS], and a faster swash moves proportionally further); a break running along the crest at 5 m/s (unchecked, an assumed peel):

| Feature | Bluff, eye 12 m, gentle beach (tan β 0.03) | Bluff, steeper beach (0.08) | Beach level, long lens (eye 1.7 m, 0.08) |
|---|---|---|---|
| Bore at the break | 0.7 / 1.0 / 1.3 px at 30 / 20 / 15 fps | 1.8 / 2.7 / 3.6 | 2.1 / 3.1 / 4.1 |
| Bore at 0.3 m depth | 1.2 / 1.8 / 2.4 | 1.8 / 2.7 / 3.6 | 4.1 / 6.2 / 8.3 |
| Swash leaving the shoreline | 2.7 / 4.1 / 5.5 | 2.7 / 4.1 / 5.5 | 10.3 / 15.5 / 20.7 |
| A break running along the crest | 5.3 / 8.0 / 10.6 | 8.8 / 13.2 / 17.6 | 41 / 61 / 82 |

- So **from a bluff over a gentle beach, a cap of 20 is plausible** for everything but the swash and the along-crest run, and those are soft-edged brightness fronts rather than objects. Offer 20 only after a side-by-side with Dave, as the app does. **From beach level, no cap.**
- **`BatteryPaced` doesn't fit**: waves arrive every 8–16 s and something is always moving.
- **`batteryScale` 0.5 fits well**: the sky gradient, the water, the glow's body and the foam are soft; stars, sparkle and the thinnest lips stay in a full-resolution layer (measured 0.49 → 0.33 ms). The lip seen from 70 m is a pixel or two wide, so check it side by side at 0.5.
- **Baked once per load:** the beach's profile (a 1D texture), the wave train's seed and spectrum, the noise (Weather's `CloudNoise`, shared); a photo headland if there is one (`sharedTexture`). Nothing per frame but four to eight vec4 uniforms.
- **Paused when covered, thermal caps, Low Power Mode freeze:** apply as to every wallpaper; nothing in the scene depends on frames being drawn (the wave model is a function of the scene's clock, not a step, and the shader is stateless).
- **A mostly black picture and the display.** Not measured, and no source measures it.
  - This Mac's display, a 14-inch MacBook Pro's, is mini-LED, whose backlight is split into zones that dim under dark content. Apple gives no zone count for the MacBook Pro ("thousands of mini-LEDs arranged into individually controlled local dimming zones", quoted in [MR]). The "over 2,500 zones" often quoted is Apple's figure for the **iPad Pro** [AP]. The 2,010 and 2,554 zones quoted for the 14- and 16-inch models come from an unsourced forum post (unchecked).
  - Notebookcheck measured the backlight's size on a 14-inch M1 Pro: going from its lowest to its highest SDR brightness (500 nits) costs "slightly more than 8 W" [NB14]. It ran no black-against-white test. So the backlight is a large share of the Mac's draw, and a picture that is mostly black *should* let most zones idle. How much is **unchecked**.
  - Apple also sells OLED MacBook Pros now [NBO]. There each black pixel draws nothing, which suits a black shore more (unchecked in watts). A MacBook Air's LCD has one backlight for the whole panel, so black should save nothing there (unchecked).
  - **How to measure it** (not done: Dave is running Atrium on this display): the README's battery-gauge method, with brightness fixed, comparing a full-screen black window, this scene, and a mid-grey window, on battery, a few minutes each.

## 6. Data and feeds

- **Open-Meteo Marine API**, `https://marine-api.open-meteo.com/v1/marine`, checked on its page [OMM] and by request on 2026-11-08:
  - Hourly or `current`: `wave_height`, `wave_direction`, `wave_period`, `wave_peak_period`; the same for `wind_wave_*`, `swell_wave_*`, and second and third swells; `sea_level_height_msl` (the tide), `sea_surface_temperature`, `ocean_current_velocity` and `_direction`.
  - Models: Météo-France MFWAM (0.08°, 3-hourly), ECMWF WAM (9 km), NCEP GFS Wave, DWD EWAM and GWAM, ERA5-Ocean; sea level and currents from Météo-France SMOC. The page warns "Accuracy at coastal areas is limited".
  - **By request:** Scripps Pier (32.87° N, 117.26° W) gave waves 1.04 m at 12.0 s from 267°, swell 0.60 m at 8.8 s from 279°, sea level 0.75 m. An inland point in Illinois gave nulls for everything, **even with `cell_selection=sea`** (it snapped to a cell 4 km away and still found no sea). The Chicago lakefront gave Lake Michigan's 0.28 m, 4 s waves but no sea level. So "the nearest coast" can't be left to the API: the app would have to find the coast itself. Named beaches avoid that.
  - **Terms:** data CC BY 4.0, with "Weather data by Open-Meteo.com" and a link wherever it's shown [OML]; Copernicus data must also say "generated using E.U. Copernicus Marine Service Information" [OMM], which applies to SMOC's tide (checked that the rule exists; that SMOC is Copernicus's is my reading, unchecked). The free tier is for non-commercial use, under 10,000 calls a day, by IP and application; apps "that do not have subscriptions or advertising" count as non-commercial [OMT]. The app already uses the free tier for Weather, so this adds nothing new; a paid App Store copy would raise it for every feed (my reading, unchecked).
  - **Cost:** one call an hour, shared by every display as `LiveWeather` is: 24 a day.
- **The real Moon:** `Sky.moon(jd, latitude:longitude:)` and `Sky.moonPhase` (SkyMath.swift), Weather's moonlight (`moonPower`, about 1/400,000 of sunlight at full, after Krisciunas & Schaefer, as its code cites) and its LRO Moon. Already in the app.
- **The real stars:** `LiveSky.catalogue` (the Yale Bright Star Catalogue), placed as Campfire's `StarField` does. Already in the app and credited.
- **A bloom feed:** California has SCCOOS's harmful-algal-bloom bulletins [SCC], but I found no machine-readable feed of where water is glowing tonight (unchecked). How dense the bloom is stays a setting.
- **Time of night:** always deep night, as Fireflies is always blue hour; real blooms are best "at least two hours after sunset" [SC]. Following the beach's own clock would show daytime half the time.

## 7. Keeping it true but soft

Dave's "nothing that flashes" meets a subject that *is* flashes. The physics gives a way to keep both:
- **One cell's flash is short:** 40–150 ms for L. polyedra, starting 15 ms after it is stirred (§2). But nobody watching surf sees one cell. A litre at the 2020 peak held 9 million of them (9 × 10⁹ a cubic metre, derived). What the eye sees is the **envelope**: millions of cells each flashing once as the shear front reaches them.
- **So the light follows the water's stirring.** A section lights as the lip falls and the bore's front sweeps over new water, and it fades as the turbulence dies behind it. Whitecap foam fades over 1.4–4.8 s [CA12, abstract], and cells that have flashed are spent for hours [LT24]. That gives a glow that rises over a fraction of a second as each part of a wave breaks, travels in with the bore, and fades over a second or a few. It moves the way the wave moves, not the way a strobe does. (Derived from the checked figures; no source measures the fade behind a bore. Tune it against footage.)
- **The eye blurs it too:** at night rods sum light over up to 100 ms [WV], about the length of one cell's flash.
- **Where single flashes are real and visible:** Noctiluca's big cells (0.4–1.5 mm, 2.5 × 10¹¹ photons a flash) in the swash and the damp sand. Keep them few, a pixel or less, and dim, with Noctiluca's slower flash (568 ms in [LT24]; [WN] says 80 ms, so this is a choice between sources). A Sparkle slider, low by default. The rule from Fireflies: Dave chose a 3 s pulse over the real 0.5 s flash there, so offer the real pace and judge it in motion.
- **Dim, not neon:** real surf glow is "much fainter than photos suggest" [BA] and photographed over seconds. Draw it as a long exposure shows it, as Aurora does, but keep the peak well below white, through a soft tone curve like Weather's `sqrt(1 − exp(−x))`, with the colour at 470–480 nm's whitened blue, shown dim.
- **Moonlight, honestly:** the glow stays the same and the Moon lights everything else. With a full Moon up the glow's contrast falls 25–150 times (derived from [LX]). So a Moon setting: None (the moonless night one would go out on, standard) or Tonight's (the real phase and place, which some nights will drown the glow, as it does at the beach).

## 8. Variety without repetition
- **Waves from a real spectrum, not a cycle.** The CPU model sums 16–32 components of a JONSWAP-shaped spectrum at the feed's peak period and height, with random phases rolled each load. Successive crests then vary in height and come in sets (groups), as real swell does, and nothing repeats. Its cost is nothing (measured 0.0002 ms).
- **The beach rolls on each load:** slope, bars and rip channels (where waves don't break and the glowing line has a dark gap), so the surf breaks in different places.
- **Slow change while it runs:** the swell from the feed every hour; the tide (if the feed carries sea level) moving the shoreline and the break over hours; the bloom's patchiness drifting along the shore on a slow noise; the Moon rising, setting and changing phase.
- **Never a hard cut:** a new beach comes in with the app's crossfade, at most on Nebula's pattern (a slow change every so many minutes, off by default).

## 9. Settings, as data
A sketch for the mock-ups, not a decision: **Beach** (a menu of real bloom beaches; Nearest coast only if the app learns where the coast is, §6), **Swell** (Live, or held at Calm, Moderate or Big), **Glow** (how dense the bloom is), **Sparkle** (the wet sand's, low by default), **Moon** (Tonight's, or None), **Speed** (0.5×–1.5×, standard the real pace: arguable for surf), and the **Look** sliders (`gradeKnobs`). No palette: the colour is the light's own (§1); a palette would be made up.

## Risks, worst first
1. **Waves that read as lines on a plane.** The probe's own picture does. Surf needs faces, a lip that throws or spills, foam that thins into lace behind the bore, and a reflection in wet sand. Judge one wave's frame strip against real footage first.
2. **The glow reading as flashing or neon.** Real light *is* flashes; drawn as the envelope (§7) it isn't, but too bright or too saturated it will read as a screen saver. Keep peaks dim through a soft tone curve and judge in a dark room and a lit one.
3. **The swash pins the frame rate.** Near the camera it moves 3–10 px a frame at 30 fps, so the view that is best for the battery (a bluff) may not be the one Dave likes best (the long lens at beach level). Settle the view in mock-ups with the battery figure beside each.
4. **Repetition.** Any periodic wave train shows; the spectrum and sets fix it, but bores that all look alike would still read as stamped. Vary foam texture offsets and lip shape by seed.
5. **Too dark to see on a desk.** Real bioluminescence is near the edge of night vision (§2); a laptop by day shows reflections over a black picture. It will have to be drawn as a long exposure shows it (as Aurora is), and said so.
6. **The feed's coverage.** Inland, the Marine API may have nothing (§6); the fallback is a named real beach, which suits "real" anyway.
7. **Cost creep from foam detail.** fbm foam (+0.3 ms) and every extra wave (+0.03 ms, skipped where it can't reach) add up; keep foam in textures and waves to six.
8. **Shader gotchas** (`Sources/CLAUDE.md`): waves as vec4 uniforms stay well under 30; the CPU hands each wave its *age* in seconds, worked out in Double each frame, so no float clock grows in the shader; the ripples drift on `u_now` (or `u_clock` with a Speed knob); `dfdx`/`fwidth` spellings; no early return.

## Sources
- [AP] Apple, About the Liquid Retina XDR display on iPad Pro ("over 2,500 individually controlled local dimming zones", iPad Pro only). https://support.apple.com/en-us/HT212527
- [BA] Bala Art Studio, "How to photograph bioluminescent waves" (a blog: exposure settings, "much fainter than photos suggest", brightest where the wave folds). https://balaartstudio.com/blogs/news/how-to-photograph-bioluminescent-waves
- [BO25] "Linking peak intensity of mechanically stimulated bioluminescence...", *Biology Open* 14(9) bio062190, 2025 (L. polyedra typically flashes once, then refractory). https://journals.biologists.com/bio/article/14/9/bio062190/369242/Linking-peak-intensity-of-mechanically-stimulated
- [BS] Bosboom & Stive, *Coastal Dynamics*, §5.2.5 Wave breaking (LibreTexts). https://geo.libretexts.org/Bookshelves/Oceanography/Coastal_Dynamics_(Bosboom_and_Stive)/05:_Coastal_hydrodynamics/5.02:_Wave_transformation/5.2.5:_Wave_breaking
- [CA12] Callaghan et al. 2012, *JGR Oceans*, whitecap decay (abstract only; the page blocked fetching). https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2012JC008147
- [CW] Coastal Wiki, Waves (surf beat, infragravity periods). https://www.coastalwiki.org/wiki/Waves
- [CWS] Coastal Wiki, Swash zone dynamics. https://www.coastalwiki.org/wiki/Swash_zone_dynamics
- [DW] Wikipedia, Dispersion (water waves). https://en.wikipedia.org/wiki/Dispersion_(water_waves)
- [IR] Wikipedia, Iribarren number (Battjes 1974's thresholds). https://en.wikipedia.org/wiki/Iribarren_number
- [L08] Latz et al. 2008, *J Exp Biol* 211:2865, bioluminescent response of individual L. polyedra cells. https://journals.biologists.com/jeb/article/211/17/2865/17745/Bioluminescent-response-of-individual
- [LT24] Letendre et al. 2024, *Front Mar Sci* 10:1299602, review of mechanically stimulated bioluminescence (Tables 1–3). https://www.frontiersin.org/journals/marine-science/articles/10.3389/fmars.2023.1299602/full
- [LX] Wikipedia, Lux (illuminance table, citing Kyba 2017 for moonlight). https://en.wikipedia.org/wiki/Lux
- [LZ] Latz lab, UC San Diego, "Biological light in the ocean darkness". https://latzlab.ucsd.edu/bioluminescence/biological-light-in-the-ocean-darkness/
- [MR] MacRumors forums, on local dimming in M1 Pro/Max MacBook Pros (quotes Apple's keynote; anecdotes only). https://forums.macrumors.com/threads/does-m1-pro-max-macbook-pro-use-local-dimming-zones-when-not-playing-back-hdr-content.2326870/
- [NB14] Notebookcheck, MacBook Pro 14 2021 M1 Pro review (power by brightness). https://www.notebookcheck.net/Apple-MacBook-Pro-14-2021-M1-Pro-Laptop-in-Review-How-much-Pro-do-you-get-with-the-base-model.576665.0.html
- [NBO] Notebookcheck, OLED MacBook Pro 14 review (sold beside the mini-LED models). https://www.notebookcheck.net/Amazing-OLED-panel-Apple-MacBook-Pro-14-PROLED-XDR-Review.1438048.0.html
- [OML] Open-Meteo licence (CC BY 4.0, attribution and link). https://open-meteo.com/en/licence
- [OMM] Open-Meteo Marine Weather API docs (variables, models, `cell_selection`, coastal accuracy, Copernicus credit). https://open-meteo.com/en/docs/marine-weather-api
- [OMT] Open-Meteo terms (free tier non-commercial, 10,000 calls a day). https://open-meteo.com/en/terms
- [PO15] Potter et al. 2015, *JGR Oceans*, residual foam (abstract only). https://agupubs.onlinelibrary.wiley.com/doi/full/10.1002/2015jc011276
- [PW] py-wave-runup documentation, Stockdon 2006 (bracketing confirmed against its worked value, R2 = 2.542 m for H 4 m, T 11 s, β 0.1). https://py-wave-runup.readthedocs.io/en/latest/models.html
- [SC] Scripps Institution of Oceanography, "Everything you wanted to know about red tides". https://scripps.ucsd.edu/news/everything-you-wanted-know-about-red-tides
- [SCC] SCCOOS, California HAB bulletin: red tide (the 2020 bloom). https://sccoos.org/california-hab-bulletin/red-tide/
- [SS] Stormsurf, wave basics (periods, sets). https://www.stormsurf.com/page2/tutorials/wavebasics.shtml
- [SV] Wikipedia, Scotopic vision. https://en.wikipedia.org/wiki/Scotopic_vision
- [TT] Taipei Times, 2021-12-26, Matsu's "blue tears". https://www.taipeitimes.com/News/taiwan/archives/2021/12/26/2003770212
- [UCSB] UCSB bioluminescence web page, reader answers (footprints in damp sand; unsigned). https://biolum.eemb.ucsb.edu/answers.html
- [UH] University of Hawaii Sea Level Center, "Why surf varies" (γ about 0.8, set statistics). https://uhslc.soest.hawaii.edu/outreach/vary/why_surf_varies.html
- [USF] University of South Florida, 2019, China's bioluminescent seas (Matsu's 2017 bloom). https://www.usf.edu/marine-science/news/2019/chinas-sparkling-bioluminescent-seas-are-glowing-brighter.aspx
- [WN] Wikipedia, *Noctiluca scintillans*. https://en.wikipedia.org/wiki/Noctiluca_scintillans
- [WV] Kalloniatis & Luu, *Webvision*, Temporal resolution ("up to 0.1 seconds or 100 ms (for rods) and 10 to 15 ms for cones"). https://www.webvision.pitt.edu/book/part-viii-psychophysics-of-vision/temporal-resolution/
- **Not used, and why:** no Shadertoy or other ocean-shader code was read or copied (Shadertoy's default licence, CC BY-NC-SA 3.0, can't ship in an MIT app; the jellyfish report checked that). The probe's shaders were written for this report.
