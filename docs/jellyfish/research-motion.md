# Jellyfish: how real groups move

A research agent's report, 2026-11-07, for round 2 (groups in natural motion, in lights D, E and F). It measures freely licensed footage of moon-jelly and crystal-jelly groups frame by frame, checks the literature, and sets both against the round-1 mock's motion (`velocityShape` and `advance` in mock.swift as committed in 1760d8a, the version that drew film1-deep.mp4 and film2-pulse.mp4). Nothing here is built.

**How to read the marks.** As in research-method.md: a figure marked **checked** was read in the source, with its page; **[abstract]** or **[search summary]** means only that; **unchecked** means no source was read for it. **Measured** figures are mine, from the footage, with their sample sizes. **By eye** means read from frames, not tracked.

## Summary: what makes a group look natural, ranked

Ranked by how much each gives a fake away on a desktop. Each line has the number to tune to.

1. **Every bell is always changing its attitude, in 3D.** Bells tilt toward and away from the camera, rock with each pulse and slowly roll. Their axis on screen turns at a median of 6.5°/s (quartiles 4–11°/s, 90th percentile 18°/s; 32 jellies, measured), with up to ±5–8° of rocking in step with each pulse. Bells also tumble 60–90° over about 3 s while not pulsing (seen in 2 jellies). The mock's axes turn at 0.4°/s at the median, and its tilt toward the camera never changes.
2. **Bells face every way, not just up.** Of side-on bells in tanks, 34% lie 45° or more from vertical (29 jellies, measured), and in a hand count of two frames, 10 of the 22 side-on bells whose dome I could read pointed down. Most bells are seen at an angle: 10% face-on, 49% oblique, 41% side-on (70 tracks). The mock: 11% lying over, none dome-down, 0% face-on, 75% side-on.
3. **They pulse fast and keep pulsing.** Display moon jellies pulse every 1.2–2.1 s, median 1.6 s, each at its own rate (16 jellies, coefficient of variation 19%, measured). Wild 15–25 cm moon jellies in a lab kreisel pulse every 2.4–2.6 s (checked, Rakow & Graham 2006). The mock gives 12–25 cm moon jellies 4.0–7.1 s, 2–4 times too slow.
4. **No coast between pulses.** The squeeze takes about 39% of the cycle (0.47–0.93 s, median 0.57 s; 9 jellies at 30 fps), and re-opening fills the rest. Motion reads as continuous. The mock squeezes in 0.4 s, re-opens over 1.4 s and then coasts for about 2.4 s each cycle, so it moves in spurts.
5. **A crowd, overlapping in depth.** In display tanks the median nearest-neighbour distance is about 1.0 bell diameter (a lower bound, because overlapping bells merge), and jellies cover 16–46% of the frame. Bells pass in front of and behind each other all the time. The mock: 1.75 diameters apart, covering 11%.
6. **Touching is gentle and slow.** When a moon jelly is touched by another, it pauses and then resumes what it was doing (checked, Albert 2011 p480, citing Hansson 1997). In footage, two bells stayed pressed together for at least 2 s; then the smaller one turned 45–90° over about 2 s and slid off sideways (1 encounter, by eye). Nothing bounces. The mock's jellies pass through each other.
7. **The group shares a slow circulation; the individuals don't share a heading.** A lab kreisel's flow is 3–10 cm/s at the wall, falling to near zero at the centre 25–30 cm in (checked, Rakow & Graham 2006 p1100–1101). Wild aggregations sometimes swim in vertical circles several metres across, rising at one end and sinking at the other (checked, Albert 2011 p479). The mock has one uniform drift and sink.
8. **They don't always travel along their axis.** Only about half of the jellies moving faster than 0.12 diameters/s relative to the group travelled within 30° of their bell's axis (9 of 17, measured). The rest slipped obliquely or sideways, carried by flow or turning. Their speed relative to the group is about 0.13 diameters/s, measured over each whole track. The mock: 88–100% along the axis, 0.06 diameters/s.
9. **Some stop for a while.** A pulsing jelly sometimes holds still, bell flat and relaxed, for 6–10 s (2 seen by eye, up to 8 of about 25 followed jellies in total, unverified). In the mock every jelly pulses on its fixed beat forever.
10. **Crystal jellies glide.** They often travel sideways, axis horizontal, with their fine tentacles streaming 3–4 bell diameters straight behind like a comet. They pulse in irregular bursts about 2–3 s apart (1 clip, 3 animals, low confidence). In the wild they swim "nearly continuously" with tentacles out, a median of 100% of the time (checked, Colin, Costello & Klos 2003 p307).

Already right in the mock, and to keep: neighbours never pulse in step, because their periods differ (up to 1.6 times within one clip). The spread of on-screen sizes matches too: the 90th over the 10th percentile is 4.9 in the footage and 4.5 in the mock.

### What to set
For the working mock's new parameters (`turnChance`, `turnAngle`, `wobble`, `restChance`, `rest`, `righting`, `current`), each from the evidence above:

| Parameter | Working value | Set to | From |
|---|---|---|---|
| Moon-jelly period at 15 cm | 5.0 s | 2.4 s (wild-size kreisel animals); for the look of a display tank, 1.2–2.1 s on screen, median 1.6 s | Rakow p1103; measured, 16 jellies |
| Period spread between jellies | ±10% | ±20% (CV 19%) | measured |
| Squeeze share of the cycle | 0.4 s of 5 s | about 39% of the cycle; no long coast after it | measured, 9 jellies |
| `wobble` (every pulse) | 0.05 rad | 0.10–0.14 rad (±5–8°) | measured, turn plots |
| `turnChance` × `turnAngle` | 0.4 × 0.2–0.7 rad | keep; turns of 13–53° are reported [search summary, D20 in research-method.md] | Costello 2024 [abstract]: frequent turns |
| Slow axis drift between turns | none | 4–11°/s, any direction in 3D, including toward or away from the camera | measured, 32 jellies |
| `righting` | 0.02 | weak enough that about a third of side-on bells lie 45° or more from vertical, and in the tank's downward flow about half point down | measured; hand count |
| `restChance`, `rest` | 0.06, 4–10 s | 0.01–0.05 per pulse, 6–10 s, bell flat and relaxed | by eye, weak |
| `current` at the rim | 0.012 m/s | 0.01–0.03 m/s is plausible for a display ("as low as will keep them", AZA); lab kreisels ran 3–10 cm/s | Rakow p1100 |
| Contact | none | on touching, pause about 1–2 s, then turn 45–90° away over about 2 s and resume | Albert p480; 1 encounter |

## 1. The footage

All from Wikimedia Commons, licences read from each file's page (sources at the end). Frames were extracted at 10 fps (960 px wide), and at 30 fps for the pulse shape. No NOAA or other government group footage was found in the time; I searched only Commons.

| Clip | What it shows | Used for |
|---|---|---|
| Aurelia sp. swimming, MBA (Polk 2023), 25 s, 60 fps | Monterey's lit blue moon-jelly tank, dense, camera looking up into it. **The reference for look E.** | 10 jellies followed; 4 periods, 4 pulse shapes |
| Jellyfish at Monterey Bay Aquarium 3, 8, 14, 15 (Fastily 2017), 6–14 s each, 59.94 fps | The same exhibit, side views of a dense school | 23 jellies followed; 12 periods, 5 pulse shapes; hand tally |
| Moon Jellies Swimming (Kilby 2009), 22 s, 24 fps | Moon jellies under blue light on black, packed and overlapping. **The nearest real thing to look F.** | spacing, by eye |
| Aurelia labiata swimming (Polk 2023), 22 s | Two moon jellies meeting | the encounter |
| Oorkwal in een school van duizenden (van Rodijnen 2012), 415 s, 25 fps | A wild bloom in green water, filmed by a diver | orientations and roll, by eye |
| Aequorea swimming (Polk 2023), 18 s | Three crystal jellies in Monterey's blue tank. **The reference for look D's motion.** | pulse and posture, weak |
| Crystal jelly (Jim G 2010), 6 s; Jellies Long Beach (Perry 2008), 122 s | Crystal jellies, a light blue tank and close-ups on black | posture, by eye |
| Monterey 9 (2024) | A huge distant moon-jelly group | viewed only |

**Method.** Bells were found in the red channel, which turns the blue tank into dark field (blur, threshold, fill holes), and linked frame to frame. Each jelly was then followed through overlaps by template matching. Its pulse came from the main mode of change in its high-passed patch, the period from that signal's autocorrelation, and the shape from folding the signal at its period. Speeds are relative to the per-frame median motion of all tracked bells. That removes the handheld camera but also any shared current, so **speeds here are relative to the group**. The axis is the short axis of the bell's silhouette. Every measured period was checked against its plot, and doubtful ones were dropped.

**Limits.** Every tank clip is handheld, so the tank's own current, time in view and absolute drift can't be measured. Display jellies have no scale, so speeds are in bell diameters per second. Turn rates include the rocking of each pulse, and any camera roll.

## 2. Measurements

### Pulse
- **Period** (16 jellies, 4 clips, measured): 1.19, 1.27, 1.28, 1.30, 1.30, 1.44, 1.47, 1.51, 1.71, 1.73, 1.85, 1.87, 1.90, 1.94, 2.01, 2.08 s. That is a median of 1.61 s, a mean of 1.62 s, a standard deviation of 0.30 s, and 0.48–0.84 Hz. Within one clip, the bigger-looking bells pulsed slower (99–105 px wide: 1.3–1.5 s; 154–218 px: 1.9–2.1 s). Nine 30 fps re-measurements agreed with the 10 fps values within 0.03 s; the two jellies whose values disagreed were dropped.
- **Shape** (9 jellies at 30 fps, measured): the squeeze edge is 0.47–0.93 s, median 0.57 s, which is 36–50% of the cycle (median 39%). Re-opening fills the rest, and the averaged waveform is a rounded sawtooth with no flat stretch. By eye at 30 fps the visible closing is shorter, about 0.3 s (strip `aurelia-j3-pulse-30fps.jpg`). The oral arms flick outward at full squeeze.
- **In step?** No. Periods differ by up to 1.6 times within a clip, so neighbours drift out of phase within a few cycles.
- **Wild:** one diver-filmed bloom jelly pulsed roughly every 1.5–2 s (by eye at 4 fps; tracking failed in the green water).

### Speed and direction (33 jellies, measured; 1 s smoothing)
- Speed relative to the group: median 0.14 diameters/s (quartiles 0.08–0.20). Net over each track: median 0.13, at most 0.39. At a 1.5 s period, that is about 0.2 diameters a pulse. Research-method.md has 0.32 for a lone 4 cm jelly (G21), and relative speeds understate when neighbours swim the same way.
- Travel against the bell's axis: 9 of 17 faster jellies (net above 0.12 diameters/s) moved within 30° of their axis line. Of the slower ones, 6 of 16 did.
- One upside-down jelly swam dome-first downward at 0.21 diameters/s relative to the group, pulsing every 1.3 s (strip `mba17-08-k12-pulse.jpg`).

### Attitude
- **Axis turn rate** (32 jellies): median 6.5°/s (quartiles 3.9–10.7), 90th percentiles at a median of 18°/s.
- **Rocking:** the axis wobbles ±5–8° in step with the pulse (turn plots: clearest in 1 of the 8 jellies plotted, partly in 2 more).
- **Turns:** a 20° turn over about 1 s, during a pulse (1 jelly). Slow drift of about 10° over 2 s, then holding (1 jelly).
- **Tumbling without pulsing:** steady rotation of about 18°/s for 4 s with no pulse (1 jelly), and a bell rotating from side-on to face-on, 60–90° over about 3 s (strip `turn-aurelia-j5-roll.jpg`).
- **Roll about its own axis:** a wild jelly's oral-arm cross turned 30–45° in 7 s while neighbours' gonad rings held still, so it isn't camera roll (by eye).

### Which way they face
- **View** (70 tracks over 5 clips): face-on (silhouette aspect over 0.75) 10%, oblique (0.55–0.75) 49%, side-on (under 0.55) 41%. In the 2023 clip, filmed looking up, by eye most bells are seen from below or at an angle, with their four gonads showing.
- **Axis of side-on bells from vertical** (29 bells): under 20°, 45%; 20–45°, 21%; 45° or more, 34%; median 26°.
- **Up or down** (hand count, two frames from the 2017 school): of 22 side-on bells whose dome I could read, 10 were dome-down (bowl-shaped, rim on top), 8 sideways or diagonal and 4 up. This school was probably on the tank's downward side. In the dark tank (Kilby), most point up or lean.
- **Wild bloom:** every attitude at once, many face-on with four gonad rings, others side-on or tilted (by eye).

### Rests
- A side-on, dome-up jelly held flat and relaxed with no visible pulse for about 10 s (strip `mba17-03-rest.jpg`). An edge-on one barely changed shape for 6 s, then pulsed (`mba17-15-rest.jpg`). Up to 6 more followed jellies had flat stretches of 5 s or more, but the follower may have slipped there. Whether a resting jelly sinks couldn't be told with a moving camera.

### Meeting
- Two moon jellies (labiata clip): the smaller one's bell was pressed against the larger one's margin for at least 2 s. Then it rotated about 45–90° and slid off, ending side-on about half a diameter away, with its oral arms trailing (strip `meet-labiata.jpg`). In the dense school bells constantly overlap in projection and pass in front of and behind each other.

### Crowding and size
| | Bells per frame (merged count) | Nearest neighbour, median (p25) | Share of frame covered |
|---|---|---|---|
| Monterey 2017, 4 clips | 22 | 1.03 D (0.80) | 16% |
| Monterey 2023 | 16 | 1.10 D (0.81) | 23% |
| Dark tank (Kilby) | 8 (about 25 by eye) | 0.99 D (0.68) | 46% |
| **Mock E (1760d8a)** | 13 | 1.75 D (1.12) | 11% |

D is the pair's mean bell length on screen. Real counts and distances are lower bounds, since overlapping bells merge into one blob. The on-screen size spread (90th over 10th percentile) is 4.9 in the footage and 4.5 in the mock.

### Tentacles and oral arms
- **Moon jelly:** the short marginal fringe barely shows at tank distance; it is visible as fine hairs only in the dark tank. The oral arms flick out at each squeeze and trail behind during a turn or slide. They hang below a bell that rests.
- **Crystal jelly:** tentacles stream 3–4 bell diameters behind, nearly straight and parallel, while it glides sideways. In close-ups on black they hang in loose curves. I saw no clear case of them lagging through a turn.
- Not seen: how tentacles behave in a sink. The footage never showed a clear sink.

### Not measurable from this footage
The tank's current, how long a jelly stays in view (every camera moves), absolute sinking speed, and a crystal jelly's steady pulse rate.

## 3. The literature

- **Pulse rate, size and flow (Rakow & Graham 2006):** wild-caught Aurelia "between 15 and 25 cm in diameter" (checked, p1098) pulsed with a period of 2.62–2.63 s in still water (n = 8) and 2.36–2.38 s at a shear of 0.34 s⁻¹ (n = 10) (checked, p1103, Table 3).
  - Kreisel flow: maximum velocity 3.02 cm/s in low flow to 10.21 cm/s in high flow (checked, p1100). Across the tank it falls from 3.02 cm/s at the wall to about 0.2 cm/s 25 cm in (checked, p1101, Table 1).
  - Bell contraction is "symmetrical in the no-flow treatment and increasingly asymmetrical as velocity shear increased" (checked, p1100).
  - In the field, near shear layers, medusae "oriented nonrandomly and swam horizontally, forming distinct layers" (checked, p1097), at a mean angle of 85° (checked, p1099). Elsewhere they swam downward (checked, p1099).
  - Turning: "First one side contracts, tilting the animal sideways. After a delay, the second side ... contracts" (checked, p1097, citing Gladfelter 1972).
- **Small moon jellies:** 3–4 cm Aurelia pulse at 0.78 Hz swimming straight and 0.76 Hz turning (checked, Gemmell et al. 2015, Results). No turn angles are given there.
- **Turns are frequent and stochastic:** "medusae typically swim circuitous, nonlinear paths involving frequent turns"; they "'skid' through turns"; asynchrony between the margins "inserts a stochastic rotational component" (Costello et al. 2024 [abstract]).
- **Gravity sense:** each of the eight rhopalia has a statolith, which "allows a medusa to orient with respect to gravity" (checked, Albert 2011 p476). No source gave how fast a moon jelly rights itself (unchecked). Tank footage and Rakow's field data both show the righting is weak or overridden.
- **Contact:** "Touch by a conspecific produced only a pause followed by a resumption of the previous swimming pattern" (checked, Albert 2011 p480, citing Hansson 1997). Moon jellies "did not swim upward following touch by a conspecific" (checked, p477). Touch by a predator's tentacles or an object sends them up at 1–1.5 m/min for 30 s or more (checked, p477).
- **Aggregations:** dense aggregations form several metres from rock walls (checked, p477). Some "swam in a vertical circle ... Medusae at one end of the aggregation swam up, and those at the other end swam down. These formations were several meters in diameter" (checked, p479). Horizontal directional swimming happened only on sunny days in Saanich Inlet (checked, p475, citing Hamner et al. 1994).
- **Current-oriented swimming:** tagged *Rhizostoma octopus* swam against tidal drift (Fossette et al. 2015 [search summary]). A mean speed of about 5 cm/s, range 3.2–7.8, is quoted by later papers (unchecked). Over 97% of 4,240 *Rhopilema nomadica* in drone footage swam in a consistent direction (Malul et al. 2024 [search summary]). Both are bigger, stronger swimmers than moon jellies.
- **Crystal jellies:** in situ, *Aequorea victoria* (n = 126) "swam nearly continuously (all medians = 100%, means ≥ 74.1%)" (checked, Colin, Costello & Klos 2003 p307), shown "swimming with their tentacles extended" (checked, p306, Fig. 1). Their pulse rate (Colin & Costello 2002) stayed unread: the publisher blocks it (unchecked).
- **Sinking of a resting moon jelly:** no measured rate found (unchecked). Hydromedusae's rates are in research-method.md (Mills 1981).

## 4. Ours against real, ranked

Measured on a 20 s, 10 fps render of the committed mock's look E (`gallery`, 14 moon jellies, seed 22), with the same scripts as the footage. Film1-deep shows the same model with deep species.

| # | What gives it away | Real | Mock (1760d8a) | Fix to hit |
|---|---|---|---|---|
| 1 | Poses frozen; turns only in the screen plane | axis turns 6.5°/s median (90th pct 18), ±5–8° rocking per pulse, 3D tilts and tumbles of 60–90° over about 3 s | 0.4°/s (90th pct 2); fixed tilt; 35% chance of a 10–35° turn per 5 s pulse | continuous 3D attitude drift at 4–11°/s plus ±5–8° rocking every pulse, and occasional 15–50° turns |
| 2 | Everyone upright, seen from one angle | 34% of side-on bells lie 45° or more over, many dome-down; 10/49/41% face-on/oblique/side-on | 11% over, none down (heading within ±57°, steered back to upright); 0/25/75% | draw attitudes from a near-uniform sphere, weakly biased up; let the tank's flow tip them |
| 3 | Pulse far too slow | 1.2–2.1 s on screen; 2.4–2.6 s for 15–25 cm | 4.0–7.1 s | period at 15 cm 2.4 s, or 1.6 s median for the display look, ±20% |
| 4 | Spurt then stop | squeeze about 39% of the cycle, then re-opening, no coast | 0.4 s squeeze, 1.4 s re-open, about 2.4 s with no propulsion each cycle | drop the coast; any long pause becomes a separate, rare rest |
| 5 | Sparse, evenly spaced, no depth crossing | neighbours about 1.0 D apart; 16–46% of the frame is jelly; constant overlap | 1.75 D; 11%; a jittered grid; the bottom third empty in film-E | more and closer, filling the whole frame, crossing in depth |
| 6 | No touching | touch: pause, turn away 45–90° over about 2 s, resume | pass through each other | a soft contact rule between near neighbours |
| 7 | One uniform drift | shared slow circulation, individuals facing every way; kreisel 3–10 cm/s at the wall (lab) | 4 mm/s sideways and 1.5 mm/s down, the same for all | a gyre whose speed falls toward its centre; the working copy already has one |
| 8 | Always moving along the axis | about half move off-axis | 88–100% along the axis | add the flow's and the turns' sideways slip; their swimming adds to the current, not replaces it |
| 9 | Metronomes | some rest 6–10 s, flat | every jelly pulses forever | rare rests (working `restChance` 0.06 is at the high end) |
| 10 | (D) Crystal jellies swim like moon jellies | glide sideways, tentacles streaming 3–4 D straight behind, irregular pulse bursts | the moon jellies' model, period 2.2 s | sideways-biased attitudes, streaming tentacles, bursts |

## 5. Strips and working files

All in `$TMPDIR/jelly-motion/` (here `/var/folders/df/pg92t2bd5gv78b8hk4dh5_jw0000gn/T/jelly-motion/`), not in the repo. Footage is in `dl/`, frames in `frames/` and `frames30/`, scripts in `scripts/`, and plots, overviews and data in `out/`.

| Strip (`strips/`) | Shows |
|---|---|
| `aurelia-j3-pulse-30fps.jpg` | one pulse every 0.1 s, oblique from below; oral arms flick at the squeeze |
| `mba17-08-j1-pulse-30fps.jpg` | a side-on pulse, every 0.1 s |
| `mba17-08-k12-pulse.jpg` | an upside-down jelly's pulse at 10 fps |
| `mba17-03-rest.jpg`, `mba17-15-rest.jpg` | a 10 s rest, and a 6 s near-still edge-on bell |
| `turn-aurelia-j5-roll.jpg` | a bell tumbling from side-on to face-on without pulsing |
| `turn-mba17-15-j6.jpg` | a bell rocking between views inside the school |
| `meet-labiata.jpg` | the encounter, every 0.3 s |
| `crystal-mba-pulse.jpg` | a crystal jelly gliding sideways, tentacles streaming |
| `mock-e-two-jellies.jpg` | two mock jellies over the same 6 s, for contrast |

Useful in `out/`: `ov-*.jpg` (a frame every 2 s of each clip), `pu-*.png` and `p30-*.png` (pulse signals), `fold-*.png` (pulse shapes), `turn-*.png` (axis angle against pulse), `turns-vs-mock.jpg`. `scripts/mock-1760d8a.swift` is the committed mock that was measured.

## 6. Not verified
- Absolute speeds, the tank's current, time in view and sinking: every tank clip is handheld.
- Whether a resting moon jelly sinks, and how fast (unchecked anywhere).
- The crystal jelly's pulse rate. The 2–3 s bursts are one clip's low-confidence signal; the paper with the rate was blocked.
- The share of dome-down bells: a hand count of 22 bells in two frames of one exhibit, probably on its downward flow.
- How quickly a moon jelly rights itself: no number found.
- Turn rates include each pulse's rocking and any camera roll; tumbling, rests and the encounter are 1–2 cases each.
- Fossette 2015's speeds and Malul 2024's figures are from search summaries, not the papers.

## Sources

**Footage** (Wikimedia Commons; licence as stated on each file page, checked 2026-11-07):
- Eric Polk, *Aurelia sp. swimming - MBA* (2023), CC BY-SA 4.0. https://commons.wikimedia.org/wiki/File:Aurelia_sp._swimming_-_MBA.webm
- Eric Polk, *Aurelia labiata swimming* (2023), CC BY-SA 4.0. https://commons.wikimedia.org/wiki/File:Aurelia_labiata_swimming.webm
- Eric Polk, *Aequorea swimming* (2023), CC BY-SA 4.0. https://commons.wikimedia.org/wiki/File:Aequorea_swimming.webm
- Fastily, *Jellyfish at Monterey Bay Aquarium 3, 8, 14, 15 2017-11-21* (2017), CC BY-SA 4.0. https://commons.wikimedia.org/wiki/File:Jellyfish_at_Monterey_Bay_Aquarium_8_2017-11-21.webm (and 3, 14, 15 likewise); *… 9 2024-01-11*, CC BY-SA 4.0, viewed only.
- Eric Kilby, *Moon Jellies Swimming* (2009), CC BY-SA 2.0. https://commons.wikimedia.org/wiki/File:Moon_Jellies_Swimming.ogv
- Peter van Rodijnen, *Oorkwal in een school van duizenden* (2012), CC BY-SA 3.0 NL. https://commons.wikimedia.org/wiki/File:Oorkwal_in_een_school_van_duizenden-4931717.webm
- Jim G, *Crystal jelly (Aequorea victoria)* (2010), CC BY 2.0. https://commons.wikimedia.org/wiki/File:Crystal_jelly_(Aequorea_victoria).webm
- Randy Perry, *Jellies Long beach, CA* (2008), CC BY 3.0. https://commons.wikimedia.org/wiki/File:Jellies_Long_beach,_CA.webm

None of the footage is in the repo; it was measured only. Copying any of it into the app or the site would carry the share-alike terms.

**Papers:**
- Albert DJ 2011, "What's on the mind of a jellyfish? A review of behavioural observations on *Aurelia* sp. jellyfish", *Neurosci Biobehav Rev* 35:474–482. https://www.rctn.org/bruno/animal-eyes/jellyfish-papers/Neuroscience%20and%20Biobehavioral%20Reviews%202011%20Albert.pdf
- Rakow KC, Graham WM 2006, "Orientation and swimming mechanics by the scyphomedusa *Aurelia* sp. in shear flow", *Limnol Oceanogr* 51:1097–1106. https://www.sutherlandlab.org/_files/ugd/52711e_0ba693e190084a9fb4f0090bcc767bd0.pdf
- Costello JH, Colin SP, Gemmell BJ, Dabiri JO, Kanso EA 2024, "Turning kinematics of the scyphomedusa *Aurelia aurita*", *Bioinspir Biomim* 19(2), abstract via PubMed 38211351.
- Gemmell BJ et al. 2015, *J R Soc Interface* 12:20150389. https://pmc.ncbi.nlm.nih.gov/articles/PMC4528605/
- Colin SP, Costello JH, Klos E 2003, *Mar Ecol Prog Ser* 253:305–309. https://www.int-res.com/articles/meps2003/253/m253p305.pdf
- Fossette S et al. 2015, "Current-oriented swimming by jellyfish and its role in bloom maintenance", *Curr Biol* 25:342–347 (search summary). https://doi.org/10.1016/j.cub.2014.11.050
- Malul D et al. 2024, "Directional swimming patterns in jellyfish aggregations", *Curr Biol* 34:4033–4038 (search summary). https://doi.org/10.1016/j.cub.2024.07.038
- Colin SP, Costello JH 2002, *J Exp Biol* 205:427–437: not read (blocked).
