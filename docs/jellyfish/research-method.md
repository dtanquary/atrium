# Jellyfish: the method research

A research agent's report, 2026-11-07, on how to build a jellyfish wallpaper: drawn by shaders, on black, dim and bioluminescent. Motion first, since the Fish Tank's big animals failed on it (fish-tank.md, 2026-10-07). Nothing here is built.

**How to read the marks.** A key in brackets, like [G13], means the figure was checked against that source (list at the end). "[key, abstract]" means checked against an abstract or a search summary of the paper, not its full text. "Unchecked" means I could not find it stated by a source. "Derived" means my arithmetic on checked figures.

## Recommendation in ten lines

1. **Motion:** simulate each jelly on the CPU in metres with a *prescribed* pulse, not a fluid model: a quick squeeze (about 0.4 s), a slow re-opening (about 1.4 s), then a coast. It surges in the squeeze, stalls or slips back while re-opening, and creeps on in the coast. It turns only during a squeeze, never between, and sinks or drifts slowly while resting. Integrate in fixed 60 Hz substeps so 15 to 120 fps look the same.
2. **Drawing:** one sprite per jelly sharing one SKShader (Fireflies' pattern), drawn additively on black. The bell is a closed-form thin shell, and its bright rim comes from the light's longer path through tissue seen edge-on, not from a painted Fresnel ring. A contraction wave runs round it, and the outer 17% of the bell flaps behind.
3. **Tentacles and oral arms** are drawn in the same shader. Each point repeats where the margin was a moment ago (a "delayed follow"), so a squeeze travels down them as a wave. Each pixel looks up only its nearest tentacles, so 100 cost no more than 16.
4. **Cost, measured on this Mac** (M3 Max, 3024×1964; Nebula reads 1.50 ms here, near the README's 1.6): 0.45–0.75 ms of GPU for ten jellies covering 43–125% of the screen, plus 0.15 ms for marine snow. CPU stays at SpriteKit's own 0.35–0.45 ms.
5. **Glow, honestly:** jellies that are *lit* (an aquarium lamp or an ROV's lights) or Aequorea's *fluorescent* green ring under blue light can glow all the time and be true. A steady self-glow would be made up. Real bioluminescence happens only when an animal is disturbed, so it belongs as a rare, slow event, off by default.
6. **Biggest risks:** the motion still reading fake; a real squeeze (0.4 s) feeling twitchy against "calm"; and Dave's "bioluminescent" meaning a glow that no real jelly has.
7. **Build order:** one moon jelly pulsing in place, judged from frame strips beside real footage, before anything else.

## 1. Swimming kinematics

### Two ways to swim
- **Rowers** are oblate (bell height/diameter under 0.5): Aurelia, Chrysaora, Aequorea. The margin works like a paddle. They swim almost all the time with tentacles out, 74–92% of the time on average [C03]. Their swimming is efficient rather than fast [C03, F97].
- **Jetters** are prolate (taller than wide): Sarsia, Aglantha. A fast whole-bell squeeze and a velum push out a jet. They drift most of the time, swimming 19.5–47% of the time, and pull their tentacles in while they swim [C03]. A 1 cm Aglantha peaks above 5 cm/s, about 5 diameters/s, and accelerates above 40 cm/s² [F97]. That is a dart, which Dave's "nothing that bounces" rules out as a default. Jetters suit drifting-and-hanging scenes, with rare short darts.
- **Swim and sink.** Many hydromedusae are slightly heavier than water. They sink slowly, often upside down with tentacles fishing, then pulse back up [M81]:

  | Species (size) | Sinking | Swimming up |
  |---|---|---|
  | Phialidium, 20 mm bell | about 20 cm/min (3.3 mm/s), 1–2 min upside down | about 180 cm/min |
  | Stomotoca atra, 25 mm | about 65 cm/min (11 mm/s) | 40–90 cm/min, at about 30° |
  | Polyorchis, 25–50 mm | 15–20 cm/min, tentacles out; 35 cm/min with them pulled in | 100–180 cm/min |

### The pulse cycle (moon jelly, *Aurelia aurita*, the best measured)
| | Small (3–4 cm) | Large (12–19 cm) |
|---|---|---|
| Pulse rate | 0.78 Hz [G15] | 0.16–0.24 Hz when left alone [XD20, YD26] |
| Contraction | 0.43 s [G21] | 0.4 s, a model input [XD20] |
| Relaxation | longer than contraction [K09, abstract]; about twice as long [box-jelly paper citing Costello & Colin 1994, unchecked] | 1.4 s, a model input [XD20] |
| Pause before the next pulse | about 0.5 s, half the cycle [G21, G13] | the rest of a 4–6 s cycle (derived) |
| Muscle working | about 20% of the cycle [G13] | |
| Distance per pulse | 12.7 mm, 0.32 bell diameters [G21] | about 0.3–0.45 diameters (derived from [XD20]) |
| Mean speed | 12 mm/s, 0.3–0.4 diameters/s [G15] | about 1–3 cm/s [X21]; 0.06–0.1 diameters/s (derived from [XD20]) |
| Peak speed | 25.7 mm/s [G21], about 2× the mean | unchecked |
| Margin tip speed | 56–59 mm/s, about 1.4 diameters/s [G21] | unchecked; likely similar in diameters/s, since motion range grows with size [MJ03, abstract] |

- **Bell shape:** a relaxed large Aurelia is flat, height/diameter 0.2–0.3 [XD20]. A 4 cm one at peak contraction is 0.55 [G21]. Contraction shrinks the diameter and raises the height [S19].
- **The flexible margin:** the outer 17% of the bell's arc, beyond a flexion point at 83% of the way from the apex, is a passive flap [V14]. It bends out as the bell contracts and folds in as it relaxes [S19]. The margin traces an outer path on the squeeze and an inner one on the return, a hysteresis loop [V14]. A bell that just scales is the commonest fake.
- **The contraction is a wave, not a scale.** Pacemakers on the margin fire, and the muscle activation runs round the bell at 0.47 m/s (0.32–0.67) [H21]. In straight swimming, opposite sides of a 3–4 cm jelly start within 30 ms (±14). In a turn, the side the jelly pivots on leads by 97 ms (±25) [G15]. Round a 15 cm bell, one pacemaker's wave would take about 0.3 s to cross (derived), as long as the squeeze itself.
- **Passive energy recapture:** a stopping vortex forms under the bell as it re-opens, and it pushes the jelly on during the pause. Over a cycle the jelly goes 30% further [G13], and 32% of each pulse's distance comes after relaxation [G13]. In a 4 cm jelly, recapture adds 10.1 mm per pulse to 12.7 mm of active travel [G13]. This is the second, softer surge after each squeeze.
- **Sea nettle (Chrysaora):** a 5.45 cm *C. quinquecirrha* moves forward only while contracting. As the bell re-opens it stalls or slips back a little; its peak speed is 1.68 cm/s and it swims almost continuously [F97]. Semaeostomes at 6 cm pulse at about 0.6 Hz and take about 1.5 s per pulse, of which about 0.4 s is contraction. They average about 1.5 cm/s, going about 1.5 cm per pulse in the Pelagiidae, Chrysaora's family [vM23]. Wild *C. fuscescens* are 19–35 cm across, with 24 tentacles and four oral arms up to 6 bell diameters long [AZA]. The pulse rate of large sea nettles is unchecked: measure it from footage.
- **Crystal jelly (*Aequorea victoria*):** a rower. A 5.0 cm one peaks at 1.91 cm/s and accelerates at up to 4.9 cm/s² [F97]. It swims nearly continuously with tentacles out [C03]. It has up to 100 radial canals and up to 150 tentacles [Wikipedia, uncited: unchecked]. Pulse rate unchecked.
- **Deep sea:**
  - *Atolla* is up to 15 cm, with a red bell (red looks black at depth) and one trailing tentacle up to 6 bell diameters long [MBARI]. It has about 20 ordinary marginal tentacles [Wikipedia citing Boltovskoy 1999: unchecked]. I found no measured pulse rate or speed (unchecked).
  - *Periphylla* "swims slowly with its tentacles first", holding them above the bell [K15]. It climbs at under 2 cm/s, with bursts over 10 cm/s [Wikipedia citing Klevjer 2009: unchecked]. Abrupt climbs toward another jelly run at about 10 cm/s, 5–10 times its usual vertical speed [K15].
- **Turning:**
  - A turn is an uneven squeeze: the margins of a pulse start at different times, and that difference roughly predicts the turn's size. Moon jellies "skid" through turns, and turns are frequent in the wild [Co24, abstract].
  - Six measured turns were 13–53° each, on bells 1.8–5.4 cm across [D20, search summary]. A review gives up to about 400°/s at peak (unchecked).
  - So the heading changes inside a squeeze, by tens of degrees, and holds still between pulses. Steering smoothly like a fish is wrong.
- **Size sets the rate:** bigger jellies pulse more slowly [MJ03, abstract]. Across scyphozoans, the pulse rate falls, and pulse time, relaxation time and distance covered while relaxing all rise, with bell diameter [vM23]. So no two sizes should share a beat.

### Tentacles and oral arms
- **Rowers keep them out** while swimming and drifting. **Jetters pull them in** to swim [C03].
- **What drives the trailing:** each squeeze sheds a ring vortex at the margin. Particles caught in one keep turning further down the oral arms and tentacles for at least two more cycles [F97]. The wake and the arms' lag come from the same rings.
  - Rings in a 3–4 cm moon jelly's wake sit about 26 mm apart [G15].
  - Derived, unchecked: a disturbance runs down the trailing parts at roughly 1–2 bell diameters a second, if a ring takes two or more cycles of about 1.5 s to go 3–6 diameters.
- **Bunching and streaming (inferred):** the tentacle roots sit on the margin. When the margin draws in on a squeeze, the roots crowd together and the jet pushes the tentacles back. As the bell re-opens, the roots spread again, and the change runs down each tentacle. This is inferred from the margin's motion [S19, V14] and the wake [F97]. I found no paper measuring it (unchecked).
- **A fringe, not streamers:** Aurelia has a fringe of short tentacles round the margin, short oral arms and four semicircular gonads that show through the bell [AZA, MBA]. Long streamers belong to Chrysaora, Atolla and Pelagia, not to moon jellies.
- **The body sets the lengths:** tentacle length is under the jelly's control and changes with how fed it is. Starved jellies in tanks extend theirs further than is seen in the field [M81].

### A tank versus open water
- **Kreisels:** Wolf Greve designed the kreisel, a round tank whose slow circular current keeps animals off the walls [GR68, abstract; AZA]. Water leaves through a large screen, and the inflow is aimed across that screen to keep jellies off it [AZA]. Aquarists set the flow as low as will keep the jellies in view [AZA]: "how low can you go". The flow speed is unchecked; one review lists 10 L/min for one design.
  - A kreisel holds jellies in a slow circle in front of you, swimming against the flow. Nothing ever leaves.
- **Open water:** jellies drift with the current as they swim. Some sink and climb [M81]. Periphylla gathers in small, short-lived groups [K15]. In open water, individuals come and go, which suits "variety without repetition".
- **Recommendation:** open water as the default, with the kreisel's gyre as an option if Dave wants a tank.

## 2. Bioluminescence, physically

| Animal | Glows? | Where | Colour | When and how long |
|---|---|---|---|---|
| Moon jelly, sea nettles | no (unchecked) | | | |
| Crystal jelly (Aequorea victoria) | yes, when stimulated | spots round the bell margin, from masses of photocytes [PN96, S08] | 508 nm green-blue, aequorin's blue passed through GFP [PN96] | Only when stimulated [S08]. Rare in the wild [VH, unchecked]. In aquaria it needs wild food that carries the luciferin [AZA citing Haddock 2001]. |
| Crystal jelly, fluorescence | yes, while lit | the same margin; avGFP sits there [L20] | GFP absorbs 400 and 475 nm and emits 509 nm [ZE] | As long as a blue or UV lamp shines. This is the "green ring" in photos [VH]. |
| Atolla | yes, when attacked | flashes and waves in the outer skin; few points on the dome [HW04, abstract] | 470 nm, 98 nm wide [LT24] | A "pinwheel" of blue light round the bell, the "burglar alarm" [MBARI, W07]. Waves run 5–50 cm/s in circles [Wikipedia citing HW04: unchecked]. After a frenzy it stops answering for a while [HW04, abstract]. |
| Periphylla | yes, when disturbed | photocytes on the dome and lappets [SF98]; sparkling particles shed from the lappets [HW04, abstract] | 470–475 nm [SF98]; 470 nm, 89 nm wide [LT24] | "Undisturbed medusae ... do not emit light" [J02, snippet]. A flash rises in 0.43 s and lasts 11.4 s [LT24, from Widder 1991]. A 70 mm one's main wave takes about 1 s from dome to lappets [figure caption, unchecked]. |
| Pelagia noctiluca | yes, when disturbed | the bell; it leaves glowing mucus [ADW] | 469 nm, 94 nm wide [LT24] | On disturbance [ADW]. Duration unchecked. |
| Other hydromedusae | yes | | about 500 nm (Obelia 502–509) [LT24] | Flashes last 0.6 s (Solmaris), 3.5 s (Phialidium) and 7.1 s (Octophialucium) [LT24] |
| Comb jellies | the rainbow is not light | The colours run down the comb rows. They are structural, reflection off the beating cilia, and need outside light [AN, PS]. | Real luminescence comes from the canals: 486 nm on average, 458–501 across 41 species [LT24 citing Haddock & Case 1999] | When stimulated [LT24] |

"Most of the described species have a flash duration of several seconds and rise times in the order of hundreds of milliseconds" [LT24].

**Colours, worked out (derived).** The colours below come from a Gaussian spectrum at each peak and width, through Wyman, Sloan and Shirley's 2013 fit of the CIE 1931 curves, into sRGB. All three are outside sRGB and were whitened to fit. On screen they would be shown dim, not at full value.

| Emission | sRGB at full value |
|---|---|
| 470 nm (Atolla, Periphylla, Pelagia) | `#00adff` |
| 486 nm (comb jellies' mean) | `#00dfff` |
| 508 nm (Aequorea) | `#00ffc1` |

From azure to aquamarine, it is one colour family, as Dave asks.

**What an honest "always gently glowing" scene could be:**
- **Lit, not glowing.** This is how aquarium and ROV footage shows them. Jellies are thin and clear, so a lamp's light scatters most where the line of sight grazes the tissue: the rim, the margin, the gonads and the oral arms. On black, that reads as a glow, and it is always on.
  - In an aquarium the lamp's colour is a free choice: the AZA manual says lighting is mostly chosen for looks [AZA].
  - With an ROV's lights, brightness falls off with distance, so far jellies fade into black and come out of it as they near. That is a natural way in and out.
- **Fluorescent.** Crystal jellies under a blue lamp: a faint blue body from scattered lamp light, and a steady green ring of points round each margin. It is true and photographed, and it falls in the colour family above.
- **Real bioluminescence, made calm.**
  - It must be rare and must have a cause. The real cause is touch: two jellies brushing, or a tentacle snagged.
  - Use the long-lived kinds: Periphylla's 11 s glow spreading over about 1 s, or its shed sparks drifting off and fading. Not Solmaris's half-second flash.
  - Even so, a real rise is about 0.4 s, which is a flash. Slowing it would be made up. So offer it as a switch, off by default.

**What would be made up:** a steady self-glow, a glow that pulses in time with the bell, luminous moon jellies or sea nettles, rainbow comb rows in the dark, and green Aequorea without a blue lamp. If Dave wants any of these, the doc should say it is a choice, not biology.

## 3. How to draw it within budget

### Measured
I built a throwaway probe in `$TMPDIR/jelly/bench`, not app code. It drives SpriteKit's SKRenderer the way the render test does: 3024×1964, GPU time from the command buffer, the median of 60 frames.
- **Calibration:** Nebula reads 1.50 ms of GPU and Fireflies 0.47 here, close to the README's 1.6 and 0.52.
- **The ten probe jellies** are 80–520 px across with tentacles 4 radii long. Their boxes add up to 43% of the screen before overlap.
- **The probe's jelly** is close to the recommended shader: a half-ellipsoid shell by closed form, with radial canals, gonads and a rim, tentacles and four oral arms with noise.

| Variant | GPU ms | CPU ms |
|---|---|---|
| An empty scene (SpriteKit's own cost) | 0.06–0.08 | 0.35 |
| Marine snow, three layers of hash cells over the full screen | 0.22–0.32 | 0.35 |
| **One sprite per jelly, 16 tentacles each, looped** | 0.62 | 0.37 |
| The same with 32 tentacles | 0.98 | 0.44 |
| **The same with 96 tentacles, nearest four only** | **0.45** | 0.43 |
| One 1,400 px close-up and nine small ones (boxes 125% of the screen) | 0.72 | 0.44 |
| Sprites plus snow | 0.75 | 0.37 |
| One full-screen pass looping over all ten (uniforms) | 0.79 | 0.36 |
| A 24-step volume march, bell only, per jelly | 0.23 for bells alone | 0.35 |
| Tentacles as CPU chains: 160 chains of 12 points, each a warped sprite | 0.05 | 0.56–0.59 |

What the measurements show:
- **Area decides the cost.** One sprite per jelly costs what it covers. That beats one full-screen loop (0.79 against 0.62 ms), and the loop's uniforms run out near 14 jellies (the 30-uniform limit).
- **Tentacle count is free** if each pixel looks up only its nearest few.
- **Unmeasured on lesser hardware.** A smaller Apple GPU will be slower; how much is unchecked. A 6K display has 3.4 times the pixels. Every wallpaper faces the same scaling, so the cost should be judged as the render test prints it, as the app's budget already is.

### The options compared
1. **One sprite per jelly, all of it in one shared shader. Recommended.**
   - **The pattern:** Fireflies' pool of sprites sharing one SKShader, with per-sprite `SKAttribute`s.
   - **Attributes:** about three vec4s per jelly: pulse phase and period, tilt and seed, the last two turns' times and angles, and the species.
   - **Pose:** the node's position, rotation and size carry it. Blend `.add`, so translucent jellies need no sorting. Order doesn't matter, which is right for nearly clear animals on black.
2. **One full-screen shader for every jelly.** It costs more, caps the count, and can't skip what isn't drawn.
3. **A volume march through the bell per pixel** (24 steps, density from the shell's distance).
   - It gives a true 3D interior: gonads seen through the bell, the far side of the rim, oral arms behind the bell.
   - The bell alone cost 0.23 ms in small boxes. Keep it in reserve for a close-up look if the closed form looks flat.
4. **A baked atlas of bell phases.** About 16 phases by 8 tilts at 512² is about 128 MB, by arithmetic.
   - Slow motion would step between phases.
   - It can't carry the wave running round the bell, or a turn's uneven squeeze. Not recommended.
5. **Tentacles as CPU chains (Verlet) drawn as warped sprites.** Measured cheap: +0.2 ms of CPU for 160 chains.
   - But chains step differently at different frame rates unless substepped.
   - A sprite strip is hard to keep 1–2 px wide and soft.
   - Use it only if the delayed follow fails in turns.

### The recommended shader, piece by piece
- **The bell.** An orthographic ray through the jelly's frame, tilted by its pitch, meets an outer and an inner half-ellipsoid. The light is the length of the ray inside the shell (two quadratics, clipped at the margin plane).
  - That alone makes the rim bright, with no painted Fresnel. Seen edge-on, the ray runs through tissue the longest. The probe's first render showed it.
  - Fine detail on the outer surface's hit point: radial canals (Aequorea's hundred, Aurelia's branching ones), Aurelia's four gonads, Chrysaora's star pattern [AZA], all from the azimuth and a little noise.
- **The squeeze.** The bell's semi-axes follow the pulse curve: diameter down, height up, fineness from about 0.25 to 0.55.
  - The phase is shifted round the bell by the travelling activation: about 30 ms across in straight swimming, about 0.1 s or more in a turn.
  - The flap is a short cone frustum at the margin, about 17% of the arc, whose angle lags the bell's: out on the squeeze, in on the return.
- **Tentacles and oral arms (the delayed follow).**
  - A point at arc length *s* takes the margin's state from *s/c* seconds earlier: its ring radius, its offset along the axis, its heading.
  - Here *c* is the trailing speed, about 1–2 diameters/s (derived).
  - The pulse is periodic and a turn is a step, so each delayed state is closed form from the attributes. No history texture, no CPU chains, and every frame rate draws the same picture.
- **Many tentacles cheaply.**
  - Tentacles on the front and back halves of the ring project to *x = a·cos φ*. Each pixel inverts that to the nearest index on each half and draws the two either side.
  - Line coverage is worked out by hand with `fwidth`, in Metal's spelling, so 1–2 px strands stay soft without shimmering.
  - Oral arms are a few wide ribbons with frilled noise edges.
- **Depth.** Simulate in metres and project with a camera, as Murmuration and Fireflies do.
  - Near jellies are large and a little soft (a wider line profile, not a blur pass).
  - Far ones are small and dim. That is either fog or, in the ROV look, light falling off with distance.
- **Marine snow.** Reuse the Fish Tank's `SKEmitterNode` of `softDot`s, or a three-layer hash-cell shader (0.15–0.25 ms). In the ROV look, near flakes are brightest, as in real footage.

### What is reused and what is new
- **Reused:**
  - the Fireflies sprite pool and per-sprite attributes, with `frameTime` and `rgb`;
  - `shaderCommon`'s `hash42` and `noise`, and `u_now` wrapped hourly for any animated noise;
  - Murmuration's simulate-in-metres-then-project;
  - the Fish Tank's marine snow, and its burst-and-coast idea, which a pulse resembles;
  - `gradeKnobs` for the Look sliders, and `PaletteChoice` for lamp colours.
- **New:**
  - the pulse model;
  - the shell-and-flap bell in closed form;
  - the delayed-follow tentacles with nearest-index lookup;
  - species tables;
  - the glow options.

## 4. Variety and pace

**How many.** Take 8–14 jellies at density 1×, in three depth bands: 1–2 near, 3–5 mid, and 4–8 far. A density knob runs from 0.5× to 2×. These are unchecked choices, but within the measured cost.
- **Real scale:** with a camera about 50° across, the view is about 0.93 m wide at 1 m (derived).
- A 15 cm moon jelly then spans about 490 px at 1 m and about 160 px at 3 m, on a 3024 px screen (derived).
- So real sizes give a natural spread of sizes with no tricks.

**A new arrangement each load.** Each load rolls a new seed for:
- positions and depths;
- sizes, from the species' range;
- each jelly's own pulse period, about ±10% around the rate for its size;
- phases, so no two jellies beat together;
- headings, the current's direction, and the next turn times.

The species could come from a menu (Moon jellies, Sea nettles, Crystal jellies, Deep sea) with Random as the default. "Mixed" should only mix species that really live together:
- moon jellies with sea nettles in Monterey Bay (unchecked);
- crystal jellies with *Mitrocoma* at Friday Harbor [C03];
- Atolla with Periphylla (unchecked).

**Left running.** In open water, the current and their own swimming carry jellies across the view slowly. At about 2 cm/s, crossing a 1 m view takes about 50 s (derived).
- One that leaves is respawned upstream, just off screen, or far off in the dark, brightening as it nears. Nothing appears in view.
- A gentle push apart keeps them from passing through each other, without bounces.

**Speed knob.** Use 0.25×–1.5×, standard 1×, the real pace. It scales the scene's clock, as in Fireflies, so pulses, coasts and drift all keep their proportions. At 0.5× a squeeze takes 0.8 s.

**`batteryRate`.**
- **Drift and coasting are slow.** A large jelly's mean is about 0.1 diameters/s. At 500 px that is about 50 px/s, or 2.5 px a frame at 20 fps (derived).
- **The squeeze is not.**
  - The margin tip of a 4 cm moon jelly peaks at about 1.4 diameters/s [G21].
  - If the big ones match in diameters/s (unchecked), a 500 px bell's margin peaks near 700 px/s. That is about 23 px a frame at 30 fps, during 0.4 s of every pulse.
  - With ten jellies out of step, one or another is squeezing about 80% of the time (derived).
- So no cap at first, and show 20 fps side by side with Dave before setting one. A `BatteryPaced` cap only during rests won't work with many jellies, since some jelly is nearly always mid-squeeze.

## 5. What makes procedural jellyfish look fake

From the biology above, and from public procedural jellyfish. I describe techniques only, and copy no code.
- **A bell that scales evenly with a sine.** This is what many shader and WebGPU demos do: "a hemisphere bell mesh contracts sinusoidally" (the WebGPU *Aurelia* showcase), and Houdini exercises use a bend deformer with a 2.8 s period. Real bells have:
  - a quick squeeze, a slow return and a coast;
  - a wave round the margin;
  - a lagging flap [G13, G21, V14, H21].
- **A body at constant speed.** Real ones surge, stall or slip back, surge softly again and coast [F97, G13].
- **Everyone beating together, or at one rate.** Rate falls with size [MJ03, vM23].
- **Steering smoothly between pulses like a fish.** Real turns happen within squeezes, and the jelly skids [Co24, D20]. The Fish Tank's whale sharks failed on the same kind of thing: they slid sideways and swam tail first.
- **Tentacles as stiff sine waves, or waves that run up them.** Disturbances run from root to tip, carried by the shed rings [F97]. The roots should crowd in on each squeeze. One WebGL demo has each squeeze shed a ring that catches and flicks the tentacles (`MiguelCarino/Jellyfish` on GitHub, licence unchecked).
- **Wrong anatomy:**
  - long streamers on a moon jelly;
  - evenly spaced, equal tentacles;
  - perfectly symmetric bells;
  - no inner structure, just a ring.

  Pixar's jellyfish were painted with "an inner surface and then another surface" for translucency (AWN, Finding Nemo). Infinigen's procedural jellyfish mixes clear and more opaque materials by Fresnel, with more opaque inner bells and long tentacles ([IF23], code licence unchecked).
- **Too bright and too saturated.** Neon outlines, and additive overlaps blowing out to white. Keep each sprite's light low, with a soft knee in the shader.
- **Glows that pulse in time with the bell, or never stop.** See §2.
- **Too fast.** Big jellies cover about 0.1 diameters/s. Most demos run them several times faster.
- **Code licences:** Shadertoy code is CC BY-NC-SA 3.0 unless its author says otherwise [ST]. That can't ship in an MIT app, so describe and re-derive, never paste.

## Risks, worst first
1. **The motion still reads fake.** Even with the right numbers, a bell from a formula may look rubbery. The test is a frame strip of one jelly beside real footage at the same size, before anything else is built (Ant Colony: "judge motion from strips"). Footage can be watched and measured without reusing it: Monterey Bay Aquarium's Jelly Cam, and MBARI and NOAA ROV clips (their licences unchecked).
2. **"Bioluminescent" versus true.** The scene Dave pictures may be a steady self-glow, which no real jelly does. Settle it with mock-ups of the lit, fluorescent and touch-glow looks.
3. **The real squeeze may feel twitchy.** A 0.4 s snap every few seconds is true and "calm" is the brief. The Speed knob and big, slow species (0.16–0.24 Hz) soften it, but Dave should judge it in motion.
4. **Close-ups and many jellies cost more.** Cost scales with covered area. Cap the near band's size, and keep tentacle boxes tight to where the delayed follow can reach.
5. **Additive overlaps clip to white.** Where jellies cross, or where tentacles bundle, they blow out. A per-sprite soft knee helps; a full-screen tone map needs an `SKEffectNode` (unmeasured).
6. **Thin tentacles shimmer as they move.** Keep them at least about 1.5 px with hand-made antialiasing, and fade by distance.
7. **Shader gotchas from `Sources/CLAUDE.md`:**
   - per-jelly data goes in attributes, not uniforms (the 30 limit);
   - `fwidth` and `dfdx` only;
   - no early return;
   - don't name a uniform `u_texture`;
   - wrap any shader time hourly.

## Sources
- [ADW] Animal Diversity Web, *Pelagia noctiluca*. https://animaldiversity.org/accounts/Pelagia_noctiluca/
- [AN] AskNature, "Moving cilia create iridescence" (quoting a paper: a 2-D photonic crystal, not luminescence). https://asknature.org/strategy/moving-cilia-create-iridescence/
- [AZA] AZA *Jellyfish (Cnidaria & Ctenophora) Care Manual*, 3rd ed. Used for kreisels, lighting, crystal jellies' diet, and the moon jelly and sea nettle species sheets. https://assets.speakcdn.com/assets/2332/aza_jellyfish_care_manual.pdf
- [C03] Colin, Costello & Klos 2003, *MEPS* 253:305, in situ swimming of eight hydromedusae. https://www.int-res.com/articles/meps2003/253/m253p305.pdf
- [Co24] Costello et al. 2024, "Turning kinematics of the scyphomedusa *Aurelia aurita*" (abstract). https://pubmed.ncbi.nlm.nih.gov/38211351/
- [D20] Dabiri et al. 2020, *Fluids* 5:106, "Jellyfish and fish solve the challenges of turning dynamics similarly" (search summary). https://doi.org/10.3390/fluids5030106
- [F97] Ford, Costello, Heidelberg & Purcell 1997, *Mar Biol* 129:355, *Chrysaora quinquecirrha* (it also quotes Colin & Costello 1996 on Aequorea and Aglantha). https://dornsife.usc.edu/heidelberg/wp-content/uploads/sites/282/2023/12/1997_Ford_et_al_Chrysaorrha.pdf
- [G13] Gemmell et al. 2013, *PNAS* 110:17904, passive energy recapture. https://pmc.ncbi.nlm.nih.gov/articles/PMC3816424/
- [G15] Gemmell et al. 2015, *J R Soc Interface* 12:20150389, vortex rings in turning. https://pmc.ncbi.nlm.nih.gov/articles/PMC4528605/
- [G21] Gemmell et al. 2021, "The most efficient metazoan swimmer creates a 'virtual wall'". https://pmc.ncbi.nlm.nih.gov/articles/PMC7892422/
- [GR68] Greve 1968, *Mar Biol* 1:201, the planktonkreisel (abstract via search). https://www.researchgate.net/publication/226533848
- [H21] Hoover et al. 2021, *PNAS* 118:e2020025118, neuromechanical wave resonance (live Aurelia muscle wave 0.474 ± 0.132 m/s). https://dabiri.squarespace.com/s/Ho_etal_PNAS2021.pdf
- [HW04] Herring & Widder 2004, *Mar Biol* 146:39, bioluminescence of deep-sea coronates (abstract). https://ui.adsabs.harvard.edu/abs/2004MarBi.146...39H/abstract
- [IF23] Raistrick et al. 2023, Infinigen. https://arxiv.org/abs/2306.09310
- [J02] Jarms et al. 2002, *Mar Biol*, *Periphylla* in a Norwegian fjord (quoted line via search). https://link.springer.com/article/10.1007/s00227-002-0858-x
- [K09] "Kinematic properties of the jellyfish *Aurelia* sp." (Hydrobiologia, 2009; search summary). https://link.springer.com/chapter/10.1007/978-1-4020-9749-2_20
- [K15] Kaartvedt et al. 2015, *Sci Rep* 5:11310, social behaviour in *Periphylla* (CC BY 4.0). https://pmc.ncbi.nlm.nih.gov/articles/PMC4464149/
- [L20] Lambert et al. 2020, *PLOS Biology*, "Aequorea's secrets revealed" (avGFP at the bell margin, via search). https://journals.plos.org/plosbiology/article?id=10.1371/journal.pbio.3000936
- [LT24] Letendre, Twardowski, Blackburn, Poulin & Latz 2024, *Front Mar Sci* 10:1299602, review of mechanically stimulated bioluminescence (Tables 2 and 3). Its licence wasn't on the fetched page; Frontiers is usually CC BY (unchecked). https://www.frontiersin.org/journals/marine-science/articles/10.3389/fmars.2023.1299602/full
- [M81] Mills 1981, *Mar Biol* 64:185, swimming and feeding in hydromedusae. https://faculty.washington.edu/cemills/Mills1981MarBiol.pdf
- [MBA] Monterey Bay Aquarium, moon jelly. https://www.montereybayaquarium.org/animals/animals-a-to-z/moon-jelly
- [MBARI] MBARI, deep-sea crown jelly (*Atolla*). https://www.mbari.org/animal/deep-sea-crown-jelly/
- [MJ03] McHenry & Jed 2003, *J Exp Biol* 206:4125, ontogenetic scaling in Aurelia (abstract; the full text is paywalled). https://doi.org/10.1242/jeb.00649
- [PN96] Shimomura et al. 1996, *PNAS* 93:13617, the light emitter of Aequorea GFP (via search: 508 nm, spots at the margin). https://www.pnas.org/doi/10.1073/pnas.93.24.13617
- [PS] Puget Sound Museum of Natural History, comb jelly. https://www.pugetsound.edu/puget-sound-museum-natural-history/exhibits/marine-panel/comb-jelly
- [S08] Shimomura, "Early history, discovery and expression of Aequorea GFP" (via search: 508 nm, photocytes along the margin, light when stimulated). https://doi.org/10.1002/jemt.20821
- [S19] "From single neurons to behavior in the jellyfish *Aurelia aurita*" (via search: diameter shrinks and height rises; the margin bends out on contraction and folds in on relaxation). https://pmc.ncbi.nlm.nih.gov/articles/PMC6999044/
- [SF98] Shimomura & Flood 1998, Periphylla luciferase (via search: photocytes on the dome and lappets; live spectrum peak 470–475 nm). https://www.researchgate.net/publication/242235093
- [ST] Shadertoy terms (via search: an unlicensed shader is CC BY-NC-SA 3.0 Unported). https://www.shadertoy.com/terms
- [V14] Villanueva, Vlachos & Priya 2014, *PLoS ONE* 9:e98310, the flexible margin (flexion point at 83% of the arc). https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0098310
- [VH] Vic High Marine Biology, *Aequorea victoria* (rarely luminescent in the wild; green ring under UV; not peer reviewed). https://vichighmarine.ca/aequorea-victoria/
- [vM23] von Montfort et al. 2023, *Sci Rep* 13:9760, scyphozoan swimming across 17 species (CC BY 4.0). https://pmc.ncbi.nlm.nih.gov/articles/PMC10276012/
- [W07] Widder, "Living lights in the sea" (Atolla's pinwheel display). https://www.aft.org/ae/winter2007-2008/widder
- [X21] "From wake dynamics to energy consumption in free-swimming biohybrid robotic jellyfish" (arXiv 2604.25257: unstimulated Aurelia 0.16 Hz; "typically swims at 1–3 cm s⁻¹"). https://arxiv.org/html/2604.25257
- [XD20] Xu & Dabiri 2020, *Sci Adv* 6:eaaz3194 (CC BY-NC 4.0). https://pmc.ncbi.nlm.nih.gov/articles/PMC6989144/
- [YD26] Yoder & Dabiri 2026, arXiv 2604.14491, speed against stroke frequency (natural Aurelia 0.24 ± 0.11 Hz). https://arxiv.org/abs/2604.14491
- [ZE] ZEISS Microscopy Online Campus, jellyfish fluorescent proteins (GFP absorbs at 400 and 475 nm and emits at 509 nm, via search). https://zeiss-campus.magnet.fsu.edu/articles/probes/jellyfishfps.html
- Also used for the "fake" list:
  - AWN on Finding Nemo: https://www.awn.com/animationworld/finding-right-cg-water-and-fish-nemo
  - the WebGPU *Aurelia* showcase: https://webgpu.com/showcase/aurelia-fully-procedural-jellyfish-with-webgpu/
  - `MiguelCarino/Jellyfish`: https://github.com/MiguelCarino/Jellyfish

  None of their code was read or copied, and their licences are unchecked.
- **Colour conversion:** Wyman, Sloan & Shirley 2013, "Simple analytic approximations to the CIE XYZ color matching functions", *JCGT* 2(2). The coefficients are from memory and were not re-checked against the paper (unchecked).
