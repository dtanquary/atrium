# Hourglass: the method research

A research agent's report, 2026-11-18, on how a wallpaper of an hourglass would be drawn within the app's budget: the real thing in numbers, which view, how long a fill takes and how it starts over without an empty screen, what is baked and what runs live, a probe of the pile, what it costs, and the risks. Nothing here is built. The look (the glass's shape, colours, reference photos, palettes, names) is the other report, `research-look.md`.

**How to read the marks.** **Checked** means read on the page whose URL follows (or in the source list at the end); "abstract" or "snippet" where only that was seen. A second agent gathered the papers for this report and marked them as it read them. **Unchecked** means no page was read that states it. **Derived** is my arithmetic on the figures named. **Measured** means the probe below, run on this Mac (M3 Max). **App** means read in this repo's code or docs.

## The recommendation
Draw **the whole glass, flat**: two bulbs between two panes, filling the screen, with the neck at its centre (view b, a thin cell). The upper bulb's crater sinks while the lower bulb's pile grows. Both are seen in profile, as in the lab's flat "half hourglass" and Makse's layered cells. The sand is never off the screen, because what leaves one bulb is in the other. The pile grows by **slides**, not by a smooth rise. Fed grains build a steeper cap under the stream until the flank gives way 2–3° past its angle of repose. Then a sheet about 15 grains thick runs down at about 10 cm/s, and the deposit freezes back up from the foot. A whole fill is worked out **once, off the main thread**, by a 2D model of the pile and the crater with these slides (0.2 s for the lower bulb on a 14-inch display, measured; about twice that for both bulbs). What it leaves is two things. One is a few hundred rows of surface profiles, one pair for each slide. The other is a map of when each grain was laid, so the layers show as nested chevrons. **One shader compares them with the clock**, Etching's engine, in a texture kept between changes as in Ant Colony's tank. It is drawn again only when a slide runs or the cap or crater moves a pixel. Only the thin falling stream and a slide's moving sheet change every frame. **The fill follows the wall clock.** Its length is a menu (5, 10, 15, 20, 30 or 60 minutes, standard 15) that divides the hour, so every display, Settings' copy and a relaunch agree with nothing saved, and the glass starts over on the quarter hour. **It starts over by fading into the turned glass.** The full lower bulb becomes the full upper one over about ten seconds, so the screen always holds a bulb of sand. A real turn is the second option, best with a taller glass; film both for Dave. **Physics sets the details.** Beverloo's law sets the neck and stream for the fill picked. Slides come around a steady mean, not in bursts.

## 1. The real thing in numbers

### Discharge: Beverloo's law
- **The rate:** Q = C ρ_b √g (D − k d)^(5/2) through a round hole of diameter D for grains of diameter d. C ≈ 0.58 "for virtually any material tested", and k is about 1.4, varying "up to a factor of 2" with the grains (checked, [ARX16], Eq. 1). Its theory gives C = π√2/8 ≈ 0.56.
- **It doesn't depend on how full the bulb is.** The rate "does not depend on the height h" (checked, [ARX16]). The usual explanation is the free-fall arch: just over the hole, grains drop freely from an arch about one hole-radius high, so only D sets the speed of what leaves.
  - Janda et al. measured that arch as a parabola 1.07 ± 0.015 R high. Grains leave at v(x) = √(2gR)·√(1 − (x/R)²) (checked, [JAN], p. 2, Eq. 3).
  - The weight of the sand above is carried by the walls (Janssen), but [ARX16] warns that a draining silo's pressure keeps changing, so that is not the whole story (checked).
  - Sack & Pöschel separate the two: height independence is Beverloo's law, pressure independence Janssen's (checked, [SAC], §II).
- **In 2D** (a slot, or a cell one grain thick) the power is 3/2: W = C ρ_b √g (D − k d)^(3/2) (checked, [JAN], Eq. 1, n = 1). No measured 2D constant was found. Integrating Janda's exit profile with their packing of 0.83 gives about C ≈ 0.8 for the bulk area through the slot (derived).
- **Jamming:** 3D flow never jams above a hole 4.94 grains across for glass beads (checked, [ZUR], §III.2). In 2D, the chance of a jam falls from 1 to 0 as the opening goes from 2 to 5 grain diameters (abstract, [TO]). Janda's monolayer jammed often below a slot 8 grains across (checked, [JAN]).

### Real glasses
- **Materials:** sand, fine glass beads, ground eggshell (checked, [MUI], p. 3415). Also powdered marble, tin and lead oxides, and burnt eggshell (checked, secondary: Wikipedia citing Mills, Day & Parkes 1996, which wasn't read). Marble dust, rock flour and round river sand flow well; angular quartz doesn't (checked, [MH]).
- **Sizes:** ballotini (glass beads) are 40–160 µm, and glasses run from cufflink size to about a metre (checked, [MH]).
  - Royal Museums Greenwich's 18th-century four-hour watch glass is 320 × 85 × 85 mm (checked, [RMG]).
  - A 16th-century half-hour glass at the Met is 8.3 cm high (checked, secondary).
  - The Nima Sand Museum's year-long glass is 5.2 m tall and runs 1 ton of 0.13 mm sand at 0.032 g/s (checked, [MUI]).
- **Neck to grain:** smooth flow when the grain is between 1/12 and 1/2 of the neck. Outside that range the flow is intermittent, from the air (checked, [SN], p. 167; Wikipedia's citation of the same).
- **Bulb walls:** no hourglass source says how steep. In hopper design, funnel flow leaves "stagnant material" at shallow edges, and the wall angle needed depends on wall friction (checked, [HOP]). That a bulb must taper into the neck more steeply than the angle of repose, so it drains clean, is my inference (unchecked). The probe uses 38°.

### The stream
- **Speed:** grains leave a neck at about √(gD), 0.07–0.14 m/s for 0.5–2 mm (derived from [JAN]). After that it is free fall. From the neck at mid-screen to a 14-inch display's bottom is 98 mm: 141 ms, reaching 1.39 m/s (derived).
- **Shape: a straight thread that thins as it speeds up.** A granular stream stretches as it accelerates (checked, [ROY], [ULR]). Royer's 107 µm glass stream showed ripples only by 20 cm of fall and clusters by 55 cm, from nanonewton cohesion (checked, [ROY], Fig. 1). Möbius saw no drops at 2 cm (checked, [MOB]). A fall of 10–20 cm is well short of that, so an hourglass's stream is a smooth thread with no beads (derived). How much its width changes over the fall: not found (unchecked). For a jet that stays dense, the width goes as v^(−1/2), so it would narrow about four times from the neck to the pile (derived).
- **Ticking:** sealed glasses flow on and off when the grains are very fine: 40–115 µm through about 2 mm, 16 < D/d < 49 (checked, [MUI], p. 3416 on Wu et al.). The pressure difference is about 10⁻⁴ atm. Opening the cap makes it continuous, and a warm hand can stop it (checked, [SN]).
  - The period is "remarkably insensitive to the grain size" (abstract, [WU]).
  - A plug forms at the neck with a low-density bubble under it (abstract, [LEP]).
  - How long a tick lasts: not found. The glass recommended here has D/d of 5–12, so it doesn't tick.

### Where it lands
- **Splash:** in tests on 150 µm basalt hit at about 0.83 m/s, each impact threw out 0–5 grains. They rose less than one grain diameter, and the grain that hit bounced back at 5–20% of its speed (checked, [IMP]).
- At 1.39 m/s that bounce is 0.07–0.28 m/s, a hop of 0.25–4 mm: 2–40 device pixels at life size, lasting 14–57 ms (derived). **At life size the impact is a faint fizz a few millimetres across, not a splash.**

### The pile: angles and slides
- **Two angles.** A surface flows once it passes the **angle of maximum stability** and stops at the **angle of repose**, a few degrees lower.
  - Glass beads in a drum: 28.6° and 25.8°, so Δθ ≈ 2.8° (checked, [CDP], Fig. 2).
  - Jaeger, Liu & Nagel: 27.8° and 25.6° (snippet, quoted in [CDP]'s field).
  - Repose angles: sand 35°, glass beads 26°, sugar 39° (checked, [MAK97]); glass beads 24.2–24.7° (checked, [SAM], Table I) and 20.2° (checked, [LD]).
- **A thin cell raises both angles and widens the gap between them** as the gap narrows (checked, [CDP], Fig. 3, Eq. 6). Earlier fits found the effect fading over b* ≈ 9 mm for 0.1–0.5 mm beads (checked, [CDP] citing Grasselli & Herrmann). So a 3 mm cell's sand stands steeper than in a jar, by an amount to fit to photographs (unchecked).
- **Slides, not a smooth rise** (Lemieux & Durian, a quasi-2D heap fed at a constant rate; checked, [LD]):
  - The setup was a 9.5 mm channel between 30 cm walls, 0.33 mm glass beads.
  - Below 0.36 g/s the surface moves only in **intermittent avalanches** that "always start at the top". Above that it flows continuously, a sharp change with no hysteresis.
  - Their flowing layer is 5 mm thick, "about 15 grain diameters or about half the width of the channel".
  - The time between avalanches goes as 1/Q, and how long one lasts tends to a constant. The gaps cluster round a mean: **not** self-organised criticality.
  - Converted, their threshold is about 28 mm² of picture a second (derived). The glass below feeds 7 mm²/s at a 15-minute fill, so it slides. At a 5-minute fill it is near continuous flow.
- **Drums agree:** avalanches are system-wide and evenly spaced. Held et al.'s critical-looking spread of sizes appeared only on piles under about 30 beads in radius (checked, [JN92], p. 1527, Fig. 6).
- **How a slide runs** (Douady, Andreotti, Daerr & Cladé; checked, [DOU], p. 184, Fig. 10):
  - On a fed pile, a front starts at the top and runs down. The flow spreads at the foot.
  - Then **"a stopping front moving upward"** lays the deposit from the toe back up the slope. When it reaches the top, sand builds up again.
  - All the fronts move at constant speed. Fronts that start flow are sharp; fronts that stop it are diffuse.
  - Their "Half Flat Hourglass" shows the same in an upper bulb: the foot drains and a start-up front climbs.
  - Makse's kink, the deposit's edge climbing from the foot, is the same thing (below).
- **Speeds:** grains in the rolling layer move at 7.1–16.6 cm/s and the kink climbs at 6.7–17.8 cm/s, in a layer 3–7 mm thick (checked, [MAK98], Table I). At 0.5 g/s, Lemieux & Durian's surface ran at about 1 cm/s, falling off with depth as e^(−z/1.5 mm) (checked, [LD]). Over a 110 mm flank, the start front takes 0.6–1.6 s and the stopping front as long again (derived). **A slide is a sheet that takes a second or two.**
- **How often:** each slide moves about a layer δ_c deep down the flank, so one comes for every δ_c × L of sand fed (derived from [LD]'s "ρwLδ_c/Q").
  - For the probe's glass at life size (a 3 mm cell, δ_c ≈ 1.5 mm, a 110 mm flank, slides taking turns on the two flanks), that is a slide every 23 s at a 15-minute fill and about 40 slides, so 40 layers, per fill (derived).
  - The probe's own model gives a visible one every 12–25 s at mid-fill (§5).

### The upper bulb
- **A dip, then a V** (Samadani, Pradhan & Kudrolli; a silo 89 × 45 cm and 1.27 cm thick; checked, [SAM], §III):
  - The surface first sinks in a Gaussian dip over the hole. Then a V forms at the angle of repose and keeps that angle for the whole ~500 s discharge.
  - The flow is in "a few layers" at the surface, thickening down the slope. Grains by the walls don't move.
- **Inside**, the speed follows a kinematic model: v = Q/(ρ√(4πBy))·exp(−x²/4By), with B ≈ 3.5 grain diameters there (checked, [SAM], Eqs. 1–3, Table II). Others measured 1.3–2.3 d, rising with height (checked, [CKB]).
  - So the sand moves only in a narrow chimney over the neck and in the thin layer sliding down the crater's walls. The rest of the upper bulb stands still until the crater reaches it.
- **Start-up fronts** climb the crater walls as their foot drains, the mirror image of the pile's slides (checked, [DOU], Fig. 10).

### Layers
- **Stratification** (Makse, Havlin, King & Stanley; a 5 mm gap between 300 × 200 mm plates, fed at one edge; checked, [MAK97]):
  - Glass 0.27 mm at 26° mixed with sugar 0.8 mm at 39° lays itself in pairs of layers about 1.2 cm thick, fine under coarse. The pairs appear only if the larger grains have the higher angle of repose; size ratios 1.66–6.66 all worked.
  - A kink forms at the foot and climbs, the small grains stopping first.
  - Later work gives layer pairs of 0.63–1.25 cm. It fails at high flux, when grains ride over the kink, and below a size ratio of 1.5 (checked, [MAK98], Table I, §VII). Pairs appear only within a range of gap and flow rate (abstract, [KOE]).
- **Coloured sand:** no source was found on coloured-sand hourglasses or sand-art bottles making nested chevrons (unchecked). The physics gives them directly. Each slide lays a layer along a flank, so sand that changes colour over a fill lays a nested set of Λs, as the probe's picture shows (measured).

### At the screen's scale
| | 14-inch MacBook Pro | Pro Display XDR (6K) |
|---|---|---|
| Pixels and density | 3024 × 1964 at 254 ppi (checked, [AP14]) | 6016 × 3384 at 218 ppi (checked, [APX]) |
| A device pixel | 0.100 mm | 0.117 mm |
| The screen | 302 × 196 mm | 701 × 394 mm |
| A grain of 40–160 µm | 0.4–1.6 px | 0.3–1.4 px |
| A 0.5–1.2 mm neck (below) | 5–12 px | 4–10 px |
| Falling from the neck at mid-screen to the bottom | 98 mm, 141 ms, 1.39 m/s | 197 mm, 200 ms, 1.97 m/s |
| A grain's move per frame at the bottom of its fall, 60 / 30 / 15 fps | 231 / 463 / 925 px | 281 / 563 / 1,125 px |
| A slide's front, 7–18 cm/s, per frame at 60 / 30 / 15 fps | 12–30 / 23–60 / 47–120 px | 10–26 / 20–51 / 40–103 px |

(All derived from the specs.) The XDR's own address now shows a different 27-inch display, and a mirror says it was discontinued in March 2026 (snippet); its spec page is still up (checked, [APX]).

**What that means:** at life size a grain is a pixel or less, so the sand reads as a fine tone with a pixel's grit, not as beads. The stream's grains cross a quarter of the screen in a frame, so nobody can follow one: what shows is a still thread with a shimmer. What can be followed is the pile's slides (a front a second or two down a flank) and, slowly, the rise.

### A flat glass the size of the screen
- **The probe's glass:** the screen's lower half holds a bulb of about 10,400 mm², of which the sand fills 6,430 mm² (62%).
  - For a 3 mm deep cell with a round neck in it, the 3D law over the cell's depth gives the picture's area flow, Q_area = 0.58 √g (D − 1.4 d)^(5/2) / b.
  - With 0.1 mm sand that empties in **5 minutes through a 1.2 mm neck, 15 through 0.8 mm, and an hour through 0.53 mm** (D/d = 5.3, just clear of jamming). All derived.
  - A day would need about 0.16 mm with the finest sand that still flows, 40 µm, which is 4 grains: it would jam (derived).
- **A full-width slot** (the 2D law) is faster: the same glass empties in about 5 to 20 minutes even with 50 µm sand and a slot 5 to 10 grains wide (derived, C ≈ 0.8).
- **So:** a screen-sized flat glass at life size is honestly a **5-to-60-minute** glass with a round neck half a millimetre to a millimetre across. A day isn't a real glass of this size. The stream is **5–12 px wide at the neck** (8 at 15 minutes), thinning about four times toward the pile, to 1–3 px (derived). It is a fine bright line, as in real glasses.

## 2. The views

**(a) The screen is the lower chamber**, life size, the stream entering at the top centre. The cost is the same as (b) for one bulb. **It fails the rule against an empty spell.** Every fill starts with an empty screen and a thread, and the start is the emptiest-looking part: in the first minute the cone is a hundred pixels high at 15 minutes and 25 at an hour (measured). No honest reset avoids that, since a chamber that fills has to have been empty. A drain through the floor would be a made-up three-bulb glass. Not recommended, except as a closer view of (b) (below).

**(b) The whole glass on screen.** The upper bulb drains its crater in the top half, the neck is mid-screen, and the pile grows in the bottom half. The same sand is always on the screen, split between the two bulbs. At the start the upper bulb is full and the lower nearly empty; at the end the reverse. **Recommended.**
- Its cost is two bulbs' bakes and one shader over the screen.
- A **Glass size** setting can show it at life size or closer. Closer means the screen holds the neck and the near halves of both bulbs (the neck at 25–50% of the height). That is (a) with the upper bulb's last sand always in view.

**(c) Flat or round.**
- **A flat cell between two panes** (Ant Colony's tank, the display as its glass):
  - Every slide, crater wall and layer lies in the plane, seen whole and true.
  - The pile is just its profile, so the bake is a 1D surface over time plus one map.
  - It is the object the physics was measured in: Makse's, Lemieux's and Samadani's cells, Douady's "Half Flat Hourglass".
  - Real flat sand objects are sold too: Klaus Bosch's moving sand pictures, coloured sand in water and air between glass panes, turned over by hand, take 20 minutes to 5 hours a picture (checked, [KB]). That is a different wallpaper (sand settling through water), noted for ideas.md.
- **A round glass** (a cone seen through curved glass) costs more on every count:
  - It needs per-pixel ray casting of the bulb and the cone, with refraction and highlights, and lit cone shading. Estimate: +0.3–0.6 ms of GPU at 14 inches and three times that at 6K (unchecked).
  - The layers show only where they meet the glass, as curves.
  - On a cone, avalanches run as narrow tongues at random places round it, not round the whole cone, so the bake becomes 2D (radius × angle): about a hundred times the work of the flat model (estimate).
  - A smooth lit cone is also the "drawn in a 3D program" look that photoreal judgement has turned down before.
  - **Flat first.** Round is a later look if Dave asks for it.

## 3. The period and the reset

### What a period looks like
The model's slides are set by the pile's geometry, not by time: the same fill run at 15 minutes and at an hour had the same 149 slides in the same order (measured). So the period only stretches time, and how lively the glass looks scales with 1/period.

| Fill | Feed (14-inch, mm²/s) | Neck (3 mm cell, 0.1 mm sand) | Pile's top, mid-fill | A visible slide (probe) | Cap at the top grows |
|---|---|---|---|---|---|
| 5 min | 21 | 1.2 mm | ~95 px a minute | every 4–8 s; near continuous flow ([LD]) | ~10 px/s |
| 15 min | 7.1 | 0.8 mm | 32 px a minute (measured) | every 12–25 s (measured) | 3.1 px/s median (measured) |
| 1 hour | 1.8 | 0.53 mm | 8 px a minute (measured) | every 50–100 s | 0.8 px/s (measured) |
| a day | 0.07 | none that flows | 0.3 px a minute | every half hour | 0.03 px/s |

(5 minutes and a day are derived by scaling; the measured rows are the probe.) A day is out: the glass would look still, and no real glass of that size runs that long. **The standard should be 15 minutes.** Something visibly slides every quarter to half a minute, the stream always runs, and the rise is plain over a minute. Five minutes is busy, near continuous flow. An hour is calm, with a minute or more between slides; Dave decides from films.

### On the wall clock
- **What it is:** the fill's phase is the local time of day mod the period, and the fill's number, which seeds it, is how many periods have passed. The local time is the wall clock plus `secondsFromGMT`, so a 60-minute glass turns on the hour even at UTC+5:30.
- **Every period divides the hour,** so the glass turns at :00, :15, :30 and :45, and it can be read as time.
- **Nothing is kept in the defaults.** Every display, Settings' copy and a relaunch work out the same fill and moment from the clock. That is simpler than Etching's `Cycle` or Ant Colony's, which keep a moment so a Speed slider can't jump the picture.
- **Changing the period** moves the phase. Let the app's crossfade rebuild cover it, since it is a change made in Settings, not something that happens unwatched (`ponytail:` if that jump is noticed, keep a moment as Etching does).
- **A daylight-saving change** shifts the clock by a whole hour, a whole number of periods, so nothing jumps (Lord Howe's half-hour shift would, for 60 minutes; ignore it).
- A Speed slider in the usual sense would break the turn on the clock, so the Period menu is the speed control.

### Starting over with no empty spell
Real glasses start over by being turned, and the sand is never anywhere but in the glass. That is what every option below keeps. The lower bulb is full at the end, and the upper bulb is full at the start of the next fill: the same sand, turned.
1. **Fade into the turned glass (recommended standard).**
   - Before it: the drain ends about ten seconds before the period does. The last grains slide down the funnel walls (the probe shows that thin band), and the stream thins and stops.
   - The fade: the glass as it ends fades over about 10 s into the next fill's first moment. That is the same sand turned over: the upper bulb full, its surface the old pile's floor settled, and a new stream starting.
   - Sand fills one bulb or the other throughout. Nothing moves fast, and no big shape sweeps across the screen. It works for a glass as wide as the screen.
   - It is honest about what happened (the glass was turned) without showing a hand.
   - It needs both fills' textures for the fade, double the memory for ten seconds (the cost below). Ant Colony's farms cut through black instead (its `ponytail:` note). Here a fade is needed, since a blink is a hard cut.
2. **The glass turns.**
   - A half turn about the neck in the screen's plane, over 6–10 s with eased ends. The sand stays put in the glass while it turns, since a turned bulb's packed sand holds as a body.
   - Then the upper bulb's sand settles onto the funnel in half a second, the old pile's surface collapsing column by column. The bake works that out as the new fill's first slide, from the last fill's final surface.
   - The stream starts as the neck comes under the sand.
   - **Cost to draw:** nothing. The glass is one kept texture, turned as a sprite.
   - **Cost to design:**
     - A glass as wide as the screen sweeps two thirds of itself off the screen as it turns. So this wants a **taller glass** whose diagonal fits the screen's height, with background either side, a different picture.
     - A turn is the one big motion the scene would have, once a quarter hour.
     - A real slow turn spills sand through the neck while the glass is still tilted; that would need simulating in the turning frame, which this doesn't do.
   - **Film it before choosing.**
3. **Not:**
   - (a)'s empty start.
   - A drain through the floor, a made-up device.
   - A fade to a new, empty glass, an empty spell in disguise.
   - A turn about a horizontal axis, which shows a flat glass edge-on, a line, halfway through.

## 4. How it would be drawn

### Baked, once a fill, off the main thread
- **The model** (`pile.py`, `bake.swift` in this folder):
  - A 2D surface h(x) over the bulb's floor, under its ceiling, at device-pixel columns.
  - Each step, the fed sand settles as a cap at the angle of maximum stability under the stream (bucket filling).
  - When a flank lags far enough behind a line at the angle of repose from the top, it slides. The cap's sand runs down that flank and lays a layer, keeping the sand's area.
  - **The upper bulb is the same code, turned 180°.** The air above the draining sand grows from the round top as a pile does from the floor, its peak the crater's bottom, its slides the crater walls'. The probe starts it level. In the build its first surface should be the last fill's pile, turned and settled column by column. So that a relaunch doesn't need every fill before it, that last fill is baked from a level start: one extra bake.
  - **Calibration for the build:** a slide when the cap is about 15 grains thick (Lemieux & Durian), the two angles 2–3° apart, and fronts at about 10 cm/s.
- **What it keeps:**
  - **Profile rows:** for each slide, the surface just before and just after, as 16-bit heights in two channels of an RGBA8 texture. With the slide's start time, apex, side and run length in a small table.
    - About 150 slides a fill in the probe, 40 calibrated (§1), so 80–300 rows of the display's width a bulb: 1–4 MB on a 14-inch display (derived).
    - Ant Colony's spoil heap is the same kind of texture (`u_heap`, heights per column at 257 shares; app).
  - **The cap's height** at each step, a small table on the CPU: between slides the surface is max(after-row, the cap's cone).
  - **A deposit map**, one RGBA8 texel a pixel: the time each pixel was first made sand and the time it was last made sand (16 bits each). In the probe 31% of the pile's pixels were sand, eroded by a slide and sand again (measured), so one time a pixel can't say whether a pixel is sand now. **Whether a pixel is sand comes from the rows; the map gives only its layer, so its colour.** That is the change from the brief's guess of a single deposit-time map, and from Etching's two "drawn" times. The time a slide's deposit lands is the stopping front's arrival at that column, so a layer's colour arrives from the foot up, as it does in the cell.
- **Bake time, measured** (one thread, `bake.swift`, 1,800 steps a fill):
  - Lower bulb: 0.22 s and 13 ms for its map on a 14-inch display; 0.43 s and 26 ms on a 6K display.
  - Both bulbs: about 0.45 and 0.9 s (derived).
  - Most of that is a bisection for the cap at every step. A closed form for the cap's area would cut it several times (unchecked).
  - **The step count should be set by sand, not by time,** so a step of a fixed area of sand costs the same at any period. With 0.5 s steps, an hour's fill (7,200 steps) took 0.85 s for the lower bulb alone.
- **When:**
  - At launch, a rebuild and a Shuffle, behind Ant Colony's 0.4 s fade-up (`Landing`, `u_show`; app).
  - The next fill's bake starts a minute before the turn.
  - `sharedTexture`, keyed by fill, glass and size, lets two displays of one size and Settings' copy share one bake (app).

### Run live
- **The glass and sand: one shader on one sprite** in an `SKEffectNode` with `shouldRasterize`, as Ant Colony's tank (app).
  - Its uniforms: the current slide's row and the cap's height, and, during a slide, its start, apex, side and run. They are set only when they change, since SpriteKit draws the node afresh on any set, even to the same value (app, Ant Colony).
  - Between slides the cap and crater move a pixel every 0.3–1 s at 15 minutes, so the sand is drawn again one to three times a second, and every frame for the 2–3 s of a slide.
  - Each pixel:
    - reads its column's two rows, and four texels at 6K (Etching's texel per 2 × 2 pixels; app);
    - compares them with the moment;
    - reads its map for its layer;
    - adds a pixel's grit from a hash.
    - The glass's panes and rims are a few gradients.
  - The reads are at texel centres, because SpriteKit smooths any texture a shader reads, and a time smoothed between two moments is a moment nothing happened (Etching's finding; app).
- **A slide as a slide, not a flash** (after [DOU]): the shader takes a slide's start time, apex, side and length, and two speeds.
  - **The start front** runs down from the apex at v_down. Above it, the surface is the after-row (the cap gone) with a moving sheet on it. Below it, the before-row.
  - When it reaches the foot, **the stopping front** climbs at v_up. Above it the sheet still runs; below it the after-row stands, newly laid.
  - **The sheet** is a band δ_c thick (about 15 grains, 10–20 px) of grit streaming downhill. It is drawn by the same hash with time in it, so its grains move and the band thins where the stopping front has passed.
  - The start front is drawn sharp and the stopping front soft over 30–60 px, as Douady saw them. A front's step between frames, 23–60 px at 30 fps, hides in its own softness.
  - The new layer's colour comes from the map, arriving from the foot up. Nothing appears in a frame.
- **The stream:** a thin sprite from the neck to the top of the pile, its length from the cap's table.
  - **Its shape:** a soft line 5–12 px wide at the neck thinning to 1–3 px, with brightness kept as width falls (the same sand, faster).
  - **Its life:** a faint grit from a hash of the pixel and of the time **rounded to fifteenths of a second at every frame rate.** A grain is never followed anyway (231 px a frame at 60 fps), so the stream is in effect a camera with a fixed 1/15 s shutter. It looks the same at 15, 30, 60 and 120 fps, as the app requires.
  - **Glints** are a few brighter streaks of that grit, no more than 10% above the thread. Anything stronger flickers.
  - Not ticking: this glass is outside the range that ticks (§1).
- **Where it lands:** a soft fizz a few pixels across at the top, from the same 1/15 s grit, or nothing. At life size it is barely there ([IMP]), and anything brighter would be a sparkle.
- **The upper bulb's moving sand:** the narrow chimney over the neck (B ≈ 3.5 grains, a few pixels) and the thin layer sliding down the crater walls ([SAM]) are drawn by the same 1/15 s grit in a band a few grains deep along the crater's surface. The bulk is still, as it really is.

### What it reuses, and what is new
- **Reused:**
  - Ant Colony's kept tank: the effect node, uniforms set only on change, `Landing` for the off-thread bake, and the fade-up.
  - Etching's engine: times compared with a clock, reads at texel centres, a texel per 2 × 2 pixels on large displays.
  - `BatteryPaced`, as Night Sky's meteors use it.
  - `sharedTexture` for the bake.
  - Ant Colony's sand look (lit grains, the `Nest.scatter` tile) only if a setting magnifies grains to 4 px or more; at life size they are a pixel's grit.
- **New:**
  - The bake, as a module optimised in debug like `AntNest` and `LineRoute`.
  - The slide's fronts in the shader.
  - The stream sprite.
  - The fill on the wall clock.
  - The reset's fade.

### Settings, as the method sees them
- **Period** (a menu, 5–60 minutes, standard 15).
- **Reset** (Fade, Turn), if the turn is built.
- **Glass size** (life size or closer).
- **Sand** (palettes from the look report), and **Layers** (a switch: coloured strata).
- The neck and the stream's width follow the period by Beverloo's law, so they are not settings.

### Battery
`BatteryPaced`, set from the slide table:
- **10 fps between slides.** The cap and crater move 0.8–4 px a second, under half a pixel a frame. The stream and fizz are a fixed 1/15 s exposure, alike at any rate.
- **30 fps from a slide's start until its stopping front reaches the top** (1–2 s), and through the reset's fade or turn.
- At 15 minutes that is 30 fps for a tenth to a fifth of the time (derived from the probe's cadence).

There is no `batteryScale`: the sand's grit is a pixel's detail, and the kept texture already makes the quiet frames cheap.

## 5. The probe and what it showed
**What it is:** `pile.py` (Python with numpy) runs the model above in the lower bulb of a flat glass at a 14-inch display's device pixels: 3024 × 982, 0.1 mm a pixel, a 15-minute fill, repose 32°, maximum stability 35°. It prints the slides' sizes and gaps and how much was eroded and laid again, bakes the deposit map, and saves quarter-size JPEGs. `bake.swift` is the same model in Swift, to time the bake as the app would run it.

```sh
python3 docs/hourglass/pile.py --out $TMPDIR/hg                    # lower bulb, 15 minutes, slides when the whole flank lags (window 1.0)
python3 docs/hourglass/pile.py --out $TMPDIR/hg --bands 8          # with eight bands of coloured sand
python3 docs/hourglass/pile.py --out $TMPDIR/hg --upper            # the upper bulb's crater (the same model, turned)
python3 docs/hourglass/pile.py --out $TMPDIR/hg --period 3600 --dt 0.4   # an hour
python3 docs/hourglass/pile.py --out $TMPDIR/hg --layer 30         # slide once the cap is 30 px thick (Lemieux's rule)
swiftc -O docs/hourglass/bake.swift -o $TMPDIR/bake && $TMPDIR/bake 3024 982 900 0.5   # width height period step
```

Each Python run takes about 4 s and writes four JPEGs of 20 KB or less. Delete them after.

**The pictures:**
- `probe-glass.jpg` is the whole glass 60% of the way through a 15-minute fill. The two bulbs come from two runs (`--upper`, and `--bands 8` for the lower), stacked.
- `probe-layers.jpg` is the lower bulb's deposit times at the end of the fill, coloured round a hue circle nine times a fill so the layers show. The colours are for diagnosis only.

**What it showed:**
- **Nested chevrons come out of the physics, with nothing drawn by hand.** Each slide lays a layer along one flank, the flanks take turns irregularly (at most 2 in a row on one side in the standard run, 4 with the angles 2° apart), and the layers vary in thickness. Coloured sand laid this way looks like a sand-art bottle (`probe-glass.jpg`, lower half).
- **The upper bulb behaves like the papers' silos.**
  - First a V-shaped crater at the steeper angle with the level surface on its shoulders.
  - Then, once the crater reaches the glass, a band of sand on the 38° funnel walls that thins to nothing, so the bulb drains clean.
  - Only 9 slides in the crater walls in a fill, since the glass holds them.
- **But it looks drawn.**
  - Two straight-sided triangles, an X on the screen, are physically right for a flat cell and still read as vector art.
  - The look needs the details the physics also gives: a rounded, slightly steeper top under the stream; the stopping fronts' small steps; the foot's concave curve; the funnel's curved glass; grit and light.
  - This is the top risk below.
- **Slides:**
  - 149 a fill in the default run: one every 6 s on average but bunched early. 120 in the first five minutes, when the pile is small and its flanks short, then 19, then 10.
  - The visible ones, moving over 2,000 px² of sand: 36 a fill, one every 25 s. Mid-fill they lay 3–6 px a slide.
  - Gaps cluster round a mean rather than coming in bursts, as [LD] found.
  - Calibrated to Lemieux's 15-grain layer, real slides would be fewer and thicker: about 40 a fill, 10–20 px each (§1).
  - **The count per fill is set by the geometry.** An hour's fill gave the same 149 slides, 4 times further apart.
- **31% of the pile's pixels are eroded and laid again,** up to five times each, near the top of the flanks (measured). Hence the rows, not a fill-time map, decide what is sand (§4).
- **The top's cap grows** at 3.1 px/s median (16 px/s at the 99th percentile, early) at 15 minutes, and 0.8 px/s at an hour.
- **Bake:**
  - Measured, one thread: 0.22 s for the lower bulb on a 14-inch display and 0.43 s on a 6K one, with 13–26 ms for the map.
  - The probe keeps every step's profile for its map, 22–87 MB. The app wouldn't: it lays the map as it goes and keeps only the slide rows.
  - Python's numpy run takes 3 s.
- **Not settled by the probe:**
  - The shader's cost: no SKRenderer harness was built. The estimates below lean on Etching's and Ant Colony's measured costs for shaders of the same kind.
  - How the slides look moving: no film was made. The first mock-up should be a film of one slide at 1×.
  - The turn.

## 6. Cost
| | 14-inch, 3024 × 1964 | 6K, 6016 × 3384 |
|---|---|---|
| Bake, lower bulb, one thread | 0.22 s (measured) | 0.43 s (measured) |
| Bake, both bulbs | ~0.45 s (derived) | ~0.9 s (derived), behind the fade-up |
| Deposit map texture (RGBA8, the screen) | 24 MB | 81 MB, or 20 MB at a texel per 2 × 2 pixels (Etching's way; derived) |
| Profile rows, both bulbs | 2–7 MB | 4–14 MB (derived) |
| Kept texture (effect node) | about 50 MB (Ant Colony's, measured there; app) | about 160 MB (Ant Colony's estimate; app) |
| Through a reset's fade | the fill's textures twice for ~10 s | the same |
| GPU, a frame that draws the sand again (about once a second, and every frame of a slide) | ~0.3–0.5 ms, like Etching's 0.30–0.36 (app) | ~0.8–1.5 ms, from Etching's standalone 0.79 at 6K (app) |
| GPU, a kept frame (most frames) | ~0.15 ms, as Ant Colony's 0.13–0.16 (app) | unmeasured, perhaps 0.4 |
| CPU a frame | a table lookup and a few uniforms, under 0.05 ms, on SpriteKit's own floor of about 0.4 ms (Canopy's empty scene; app) | the same |

All the GPU figures are estimates from shaders of the same kind; none is measured for this one. Without the effect node, the sand drawn every frame would still be under 2 ms at 6K by these estimates, so the kept texture is for battery and heat, not the budget. Measure both with `LIVE_COST` once built.

## 7. Risks, worst first
1. **Looks drawn: two triangles.** The probe's own picture is an X of straight-sided triangles. That is the physics of a flat cell, and also the risk the brief names: a pile that looks drawn in a paint program. Photoreal has been the bar (Galaxy, Fish Tank; cut: Sea Sparkle, Crystals). The method gives what softens it:
   - a rounded top with its steeper cap;
   - the stopping fronts' steps;
   - the concave foot;
   - layers;
   - the curved bulb and its rims;
   - grit and light.
   Judge against photos of real flat sand cells (Makse's, Douady's) and a real glass, at 100% as well as desktop size.
2. **Too slow to see, or busy.** At an hour the top rises 8 px a minute and a visible slide comes every minute or two, so the screen looks still between them. At five minutes the flanks are near continuous flow. 15 minutes is the guess. The stream and the crater's surface always move, so it is never still, but Dave should choose from films at 5, 15 and 60 minutes.
3. **The reset.** A fade may read as a trick, and a turn is the one big motion and wants a narrower glass. Neither shows the screen empty. Film both.
4. **The stream is a still line, or a flickering one.** Drawn honestly at life size it is a hairline whose grains can't be seen. Too faint and it disappears on a 6K display at arm's length; too much grit and it buzzes. It needs the fixed 1/15 s shutter and a faint grit.
5. **Bright sand on a desktop.** Pale sand over a third to half of the screen is the bright look that cut Zen Garden. It needs the look report's dim palette and the glass's own shade. The method doesn't care which.
6. **Memory on a 6K display.** About 160 MB for the kept texture plus the maps, and twice the map through a fade, and as much again while Settings' page is open. The fallbacks:
   - a texel per 2 × 2 pixels for the map;
   - no effect node (0.8–1.5 ms of GPU per frame, estimated).
   And about a second's bake behind the fade-up at launch.
7. **The calibration is borrowed.** The slides' size, fronts and angles come from glass beads in cells 3–10 mm deep. The slide rule in the probe is a model, not a measured one. How steep a 3 mm cell's sand stands, and how its slides look, should be judged against a photo or film of the real thing; a film of a lab's half hourglass would settle it.
8. **A turn is not modelled.** The sand held still and then settled is a simplification. A slow real turn spills through the neck on the way round. Fine for 6–10 s, not for a slow one.
9. **Shapes the papers don't cover.** Whether the bulb's funnel must be steeper than the repose angle is my inference, and the 2D Beverloo constant is derived, not measured. Neither changes the drawing, only the numbers quoted for neck and period.
10. **Changing the period jumps the fill.** Covered by the app's rebuild crossfade; a `ponytail:` until it's noticed.

## Sources
- [ARX16] On Beverloo's law and its constants (arXiv 1611.05277): https://arxiv.org/pdf/1611.05277 (checked)
- [SAC] Sack & Pöschel 2017, Am. J. Phys. 85, the hourglass: https://people.math.harvard.edu/~knill/pedagogy/hourglass/paper.pdf (checked)
- [JAN] Janda, Zuriguel & Maza 2012, PRL 108, 248001: https://www.unav.edu/documents/14434042/14611288/2012_PRL108_248001_Janda.pdf/efa70593-a794-c11c-78ad-5982051a42a4 (checked)
- [ZUR] Zuriguel et al. 2005, PRE 71, 051303: https://ar5iv.labs.arxiv.org/html/cond-mat/0407761 (checked)
- [TO] To, Lai & Pak 2001, PRL 86, 71: https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.86.71 (abstract)
- [MUI] Muite, Hunt & Joseph 2004, Phys. Fluids 16, 3415: https://authors.library.caltech.edu/records/6987c-a2j49/files/MUIpof04.pdf (checked)
- [MH] How Products Are Made, Hourglass: http://www.madehow.com/Volume-5/Hourglass.html (checked)
- [RMG] Royal Museums Greenwich, AST0090: https://www.rmg.co.uk/collections/objects/rmgc-object-10252 (checked)
- Wikipedia, Hourglass (Material section; the Met's half-hour glass): https://en.wikipedia.org/wiki/Hourglass (checked, secondary)
- [SN] Science News, 11 September 1993, p. 167 (I. Peterson): https://www.sciencenews.org/wp-content/uploads/sites/2/1993/09/00368423.ap070974.07a00100.pdf (checked)
- [WU] Wu, Måløy, Hansen, Ammi & Bideau 1993, PRL 71, 1363: https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.71.1363 (abstract)
- [LEP] Le Pennec et al. 1996, PRE 53, 2257: https://journals.aps.org/pre/abstract/10.1103/PhysRevE.53.2257 (abstract)
- [HOP] Hopper design principles, Chemical Engineering: https://www.chemengonline.com/hopper-design-principles (checked)
- [ROY] Royer et al. 2009, Nature 459, 1110: https://jfi.uchicago.edu/~jaeger/group/JaegerGroupPapers/granular/2009RoyerGranStreams.pdf (checked)
- [MOB] Möbius 2006: https://arxiv.org/pdf/cond-mat/0604039 (checked)
- [ULR] Ulrich & Zippelius 2012: https://arxiv.org/pdf/1203.1532 (checked)
- [IMP] Grain impacts at about 1 m/s (arXiv 2007.01130): https://arxiv.org/pdf/2007.01130 (checked)
- [CDP] Courrech du Pont et al. 2003, EPL 61, 492: https://arxiv.org/pdf/cond-mat/0209040 (checked)
- [JN92] Jaeger & Nagel 1992, Science 255: https://pdodds.w3.uvm.edu/teaching/courses/2009-08UVM-300/docs/others/1992/jaeger1992a.pdf (checked); Jaeger, Nagel & Behringer 1996, Rev. Mod. Phys.: https://jfi.uchicago.edu/~jaeger/group/JaegerGroupPapers/granular/Granular_RMP.pdf (checked)
- [LD] Lemieux & Durian 2000, PRL 85, 4273: https://arxiv.org/pdf/cond-mat/0005388 (checked)
- [DOU] Douady, Andreotti, Daerr & Cladé 2002, C. R. Physique 3, 177: https://comptes-rendus.academie-sciences.fr/physique/item/10.1016/S1631-0705(02)01310-5.pdf (checked)
- [SAM] Samadani, Pradhan & Kudrolli 1999, PRE 60, 7203: https://arxiv.org/pdf/cond-mat/9905303 (checked)
- [CKB] Choi, Kudrolli & Bazant 2005: https://arxiv.org/pdf/cond-mat/0501568 (checked)
- [MAK97] Makse, Havlin, King & Stanley 1997, Nature 386, 379: https://arxiv.org/pdf/cond-mat/9809432 (checked)
- [MAK98] Makse, Ball, Stanley & Warr 1998, PRE 58, 3357: https://hmakse.ccny.cuny.edu/wp-content/uploads/2015/07/1998_Dynamics.pdf (checked)
- [KOE] Koeppe, Enz & Kakalios 1998, PRE 58, R4104: https://journals.aps.org/pre/abstract/10.1103/PhysRevE.58.R4104 (abstract)
- [KB] Klaus Bosch's moving sand pictures: https://movingsandart.com/pages/the-science-of-sandpictures , https://movingsandart.com/products/black-beauty-sand-art-by-klaus-bosch , https://movingsandart.com/products/aurora-borealis-movie-sand-art-by-klaus-bosch (checked)
- [AP14] Apple, MacBook Pro tech specs: https://www.apple.com/macbook-pro/specs/ (checked); [APX] Pro Display XDR tech specs: https://support.apple.com/kb/SP800 (checked)
- Not read: Beverloo, Leniger & van de Velde 1961; Held et al. 1990 (only as quoted in [JN92]); Jaeger, Liu & Nagel 1989 (snippet); Mills, Day & Parkes 1996 (the publisher's server failed); Daerr & Douady 1999 and Rajchenbach 1990 (snippets); Beladjine et al. 2007 (refused; at tens of m/s, not this regime).
- In this repo: `docs/ant-colony.md` (How it works, The picture, Cost), `docs/etching.md` (How it works, Cost), `Sources/Atrium/AntColony.swift` (the kept tank, `u_heap`, `Landing`), `Sources/Atrium/Etching.swift` (`Cycle`), `Sources/Atrium/Scenes.swift` (`BatteryPaced`, `HeadStart`, `sharedTexture`), `docs/canopy/research-method.md` (house style, SpriteKit's CPU floor).
- The probe: `pile.py` and `bake.swift` here; its frames were deleted after `probe-glass.jpg` and `probe-layers.jpg` were kept.
