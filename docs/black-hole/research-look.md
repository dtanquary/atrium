# Black Hole: the look research

A research agent's report as it was sent on 2026-10-10, unedited, kept so its detail and sources aren't lost. The plan beside it is the summary and has Dave's decisions; where the two differ, the plan is later. `scratch/` was the session's temporary folder: the scripts and pictures worth keeping were copied into this folder, the rest (downloaded references, video clips) is gone and its source URLs are below.

Black Hole look research 1 of 8: what I found, the default I recommend and the choices for Dave.

Everything is under scratch/blackhole/ : 50 reference images in refs/ (403 MB), my scripts in scripts/, sheets in scripts/out/. Look first at scripts/out/acceptance_85deg.png and scripts/out/acceptance_angles.png. The repo is untouched.

Findings, most important first:
1. NASA's 2019 visualisation can be matched by number. Its frames are 3840 px, 8-bit palette BMPs: one brightness value per pixel through a 256-colour ramp. I fitted the photon ring (radius 250.1 px, rms 0.34 px) and measured every edge in shadow radii. A 40-line ray integrator for a non-spinning hole (scripts/schwarz.py) reproduces the edges at four viewing angles to within about 0.05 shadow radii for a disc from 6M to 30M. So acceptance is geometry, not taste.
2. NASA's orange is not a real colour. It is a heat ramp applied to brightness. To the eye every bright thin disc near a horizon (Cygnus X-1 to a quasar) is the same pale blue-white, about rgb(150,178,255), because all are hotter than 30,000 K (my calculation, scripts/realholes.py). M87* and Sgr A* barely shine in visible light; the EHT's orange is radio brightness in false colour.
3. Mass does not change the picture, only its speed and temperature. Inclination, spin (is there a dark gap inside the disc), the kind of flow and colour do. The real holes give four distinct pictures, not ten.
4. NASA's motion is fast: the inner edge laps every 2.6 s (measured). Calm needs about 1/60 of that.

Recommended default: a thin disc round a non-spinning hole, 6M to 30M, seen from about 75 to 80 degrees (the hump, with more disc surface showing than NASA's 85). Ember-amber ramp sampled from the EHT and NASA images but dimmer, with NASA's soft outer taper. Approaching side 1.6 times the receding in display values. Hairline photon ring, shadow and inner gap pure black, no bloom. A dim real star field behind (sky about 7/255, as in NASA's 2024 version and Galaxy's 8,9,11). Closest real object: LMC X-3 (thin disc almost always, 69 degrees, spin 0.25).

Choices worth mocking up for Dave:
A. Viewing angle: 85 degrees (the NASA and Interstellar hump), 65 degrees (an "eye", calmer, shows the turning better), or 20 to 27 degrees (a ring; true for M87*, Sgr A*, Cygnus X-1).
B. Colour: ember (the convention), true blue-white, or the TON 618 gradient (blue-white core through gold to an ember rim: the one real case with colour across the frame). Possibly sapphire, NASA's own blue ramp.
C. Framing: hole large with the disc 60 to 70% of the screen width, or a small hole low in a wide lensed sky (NASA's 2024 opening frame: disc 20 degrees wide). Background: catalogue stars only (120 to 280 on screen, sparse) or with a Milky Way band.

Later kinds, each needing its own render path: the hot thick flow (M87*, Sgr A*) and a dormant hole with stars only (A0620-00 has Orion and Sirius behind it).

Not done: I did not check MAXI's data terms or the per-figure licence of the Interstellar paper's Figure 4. Coordinates and a few values marked "from memory" in message 5 need a check before they go in a doc.

---

Black Hole look research 2 of 8: acceptance numbers for geometry, all measured by me on NASA SVS 13326 frames (https://svs.gsfc.nasa.gov/13326).

Unit: one shadow radius (Rs) = the photon ring's radius = sqrt(27) M = 250.1 px in the 3840 px frames (centre 1919.5, 1919.6; scripts/ring.py). The frame is 15.4 Rs across. NASA calls the hole "spherical" (https://www.nasa.gov/universe/nasa-visualization-shows-a-black-holes-warped-world); my fit agrees, the disc's inner edge is the 6M orbit.

Viewing angles are my estimates from fitting scripts/schwarz.py, plus or minus 1.5 degrees. Distances are from the centre along the vertical, threshold 10 of 255 (scripts/cuts.py).

Frame 0390, about 10 degrees (face-on): disc inner edge 1.31 to 1.37, outer 5.92; half-width 5.95 to 6.03.
Frame 0330, about 56 degrees: far side 1.42 to 4.17 above; near side 0.68 to 3.32 below; half-width 6.14 left, 5.77 right.
Frames 0450 and 0630, about 65 degrees: far side 1.37 to 3.62-3.70; near side 0.50 to 2.38-2.42; half-width 5.7 to 6.0.
Frame 0000, about 85 degrees: far side (the hump) 1.27 to 2.55 above; near side 0.11 to 0.48 below; half-width 5.97 left, 5.72 right.

Predicted for a 6M to 30M disc (schwarz.py): face-on 1.33 to 5.96. 56 degrees: far 1.37 to 4.19, near 0.66 to 3.24. 65 degrees: far 1.34 to 3.67, near 0.49 to 2.44. 85 degrees: far 1.27 to 2.62, near 0.10 to 0.50.

So the hump's top is 2.55 Rs over the centre at 85 degrees, 3.7 at 65, 4.2 at 56, and the disc is 11.7 to 12 Rs wide at every angle.

At 85 degrees only:
- The under-arc (the disc's underside, lensed round below the hole) runs from 1.24 to 2.16 Rs below the centre (predicted 1.23 to 2.21).
- It is cut off flat at 0.66 Rs below the centre by the near side of the disc, which stays opaque beyond where its light ends (0.48). That dark strip between the bright band and the under-arc is a signature of the real thing.
- The dark gap between the photon ring (1.00) and the disc's inner edge (1.27) is 0.27 Rs wide and exactly black.

Photon ring:
- The hairline (light that went round twice or more) sits at 0.998 Rs and is 1 px wide at 3840 px, so at most 0.004 Rs. It is the same circle from every angle.
- The next ring out (one extra half-turn, an image of the disc's other face) is 1.05 to 1.15 Rs face-on, 0.09 wide (predicted 1.054 to 1.145). At 85 degrees it thins to 1.010-1.022 over the top (predicted 1.012 to 1.028) and opens into the under-arc below.
- Inside 0.98 Rs the value is exactly 0.

Glow: none. Face-on, the last light is at 6.2 to 6.7 Rs; beyond 6.8 Rs every pixel is 0. In the 85 degree frame 89.9% of pixels are exactly 0.

Background: pure black in 2019. In the 2024 version (https://svs.gsfc.nasa.gov/14576) the disc sits on an all-sky Milky Way panorama. Measured on refs/nasa14576_FlyBy_Rect_frame_00383.jpg: sky median 7 of 255, the band 90 to 125, cream-brown rgb(126,101,87), disc peak 227. The lensed sky shows as a grey ring between the photon ring and the disc's inner edge (scripts/out/flyby_00383_centre.png).

Mapping of the 360 set: frames 0 to 300 hold near 85 degrees, then the camera goes over the pole (face-on at 360-390, from below at 540) and returns to 85 at 720. It is not half a degree per frame.

---

Black Hole look research 3 of 8: acceptance numbers for brightness, colour and motion, measured on the same NASA frames.

Colour ramp. The palette is exact, with i the brightness 0 to 255: R = min(255, 1.449 i); G = 1.889 (i - 120) from i = 121; B = 3.92 (i - 190) from i = 191. Samples: 32 (46,0,0), 64 (92,0,0), 96 (139,0,0), 128 (185,15,0), 160 (231,75,0), 176 (255,105,0), 192 (255,136,7), 208 (255,166,70), 224 (255,196,133), 240 (255,226,196), 255 white. It matches what I remember of IDL's "Red Temperature" table (not verified). Colour encodes brightness only.

Face-on radial profile (frame 0390, mean round each circle; radius in Rs, brightness, mean RGB; scripts/faceon.py):
1.4: 69 (99,0,0). 1.5: 92 (132,14,0). 1.75: 141 (202,50,0). 2.0: 157 (221,74,4). 2.5: 174 (242,102,6), the peak. 3.0: 167 (237,89,3). 3.5: 158 (228,71,0). 4.0: 136 (196,30,0). 4.5: 104 (149,1,0). 5.0: 72 (103,0,0). 5.5: 41 (59,0,0). 6.0: 9 (12,0,0).
Half of peak at 4.8 Rs, a tenth at 5.8, 2% at 6.2. The outer edge is a soft taper from 4 to 6.2 Rs. It fades faster than a thin disc's flux would (still about 15% of peak at 30M by my calculation), so NASA fades it by hand.
Streaks: the 5th to 95th percentile at one radius spans 100 to 200 at 2 Rs, 134 to 197 at 3 Rs, 116 to 154 at 4 Rs. Only 0.1% of pixels pass 200; frame maxima are 222 to 249. The mean lit pixel is 104, rgb(150,0,0): the picture is mostly deep red, with orange only in the streaks.

Approaching to receding (left to right, mirrored boxes 1.3 to 5.7 Rs out along the disc; scripts/doppler.py):
- 85 degrees: 1.59, 1.63 and 1.62 in display values on three frames, 3.2 to 3.4 in linear light if the ramp is sRGB.
- 65 degrees: 1.63 (3.7 linear). 56 degrees: 1.77 (4.4 linear). Face-on: 0.93, so none.
- The brightest pixel is always on the approaching side, 1.8 to 2.2 Rs from the centre.
For comparison (scripts/realholes.py, my calculation): counting all light the ratio is 18 at 10M and 62 at 6M; for a hot disc seen in visible light it is only 2.1 and 2.8. NASA's 3.3 is near the second. The Interstellar paper found the full effect "exceedingly lopsided" and "obviously unacceptable" (https://arxiv.org/abs/1502.03808, section 4, as read by a fetch tool).

Motion (scripts/motion.py: rings of the pattern cross-correlated between face-on frames 0389 and 0391):
- The pattern shears as Kepler says: 4.35 degrees a frame at 1.5 Rs, 2.6 at 2 Rs, 1.2 at 3 Rs, 0.8 at 4 Rs, 0.3 at 5.5 Rs.
- That is 1.2 plus or minus 0.2 M of black hole time per frame, 36 M a second at 30 fps: the inner edge laps in 2.6 s, the 10M orbit in 5.5 s, the outer edge in 29 s. For a hole of Sgr A*'s mass that is about 760 times real time.
- Knots are born and fade: the picture's correlation with itself is 0.99 after 1 frame, 0.93 after 5, 0.58 after 30 (this run includes some camera motion).
- Camera: about 1.2 degrees a frame over the pole, 36 degrees a second.

EHT images for comparison (scripts/eht.py, display values): M87* ring is as wide as its own radius (blur), centre at 0.23 of the ring's peak, brightest sector 4.3 times the dimmest. Sgr A*: width 0.86, centre 0.16, sectors 2.5. Their ramp: (16,5,3), (89,8,2), (161,39,2), (205,79,2), (238,121,8), (248,167,36), (253,213,89), (254,244,189): more amber-gold than NASA's red.

---

Black Hole look research 4 of 8: the reference list. All files are in scratch/blackhole/refs/ . They are for side-by-side comparison only; several cannot be shipped (marked).

NASA, public domain. NASA's terms, as read by a fetch tool: content "generally are not subject to copyright in the United States", credit NASA, no endorsement (https://www.nasa.gov/nasa-brand-center/images-and-media/).
- nasa13326_360_frame_NNNN.bmp, 20 frames, 3840 x 3840: 0000 0090 0180 0210 0240 0270 0300 0720 (about 85 degrees), 0330 (56), 0360 and 0386-0394 (face-on), 0450 0630 (65), 0540 (face-on from below). nasa13326_long_frame_0700/0701/0705/0730.bmp. nasa13326_BH_labeled.jpg (3851 x 2166, NASA's own labels). "Black Hole Accretion Disk Visualization", 2019. Credit: NASA's Goddard Space Flight Center/Jeremy Schnittman. https://svs.gsfc.nasa.gov/13326
- nasa14576_FlyBy_Rect_frame_00383.jpg (8192 x 4096 all-sky; the disc in front of the lensed sky, the best reference for our framing), _frame_01000.jpg, FlyBy_Rectilinear_01787.jpg, FlyBy_Zoom_Still_01650.jpg, Plunge_Zoom_Still_03607.jpg, 14576_BHPlunge_Explain_Still.jpg, labels_4_BH_Viz_45rg_062c.jpg. "NASA Black Hole Visualization Takes Viewers Beyond the Brink", 2024. Credit: NASA's Goddard Space Flight Center/J. Schnittman and B. Powell. https://svs.gsfc.nasa.gov/14576
- nasa13831_BlackHole_Binary_MainSequence.jpg (4096 x 4096), nasa13831_Binary_Lensing_8k.jpg (8192 x 8192). The binary, 2021; source of the blue ramp. Credit: NASA's Goddard Space Flight Center/Jeremy Schnittman and Brian P. Powell. https://svs.gsfc.nasa.gov/13831
- nasa13043_sub-warped-gaia-000000.png (4096 x 2048): two bare holes lensing the Gaia sky; the best "dormant" reference. Credit: NASA's Goddard Space Flight Center/Scott Noble; background ESA/Gaia/DPAC. The Gaia sky is ESA's, not NASA's: its licence was not checked, so do not ship. https://svs.gsfc.nasa.gov/13043

Event Horizon Telescope, CC BY 4.0, credit "EHT Collaboration" (the same sources Deep Space Tour already uses, docs/deep-space.md):
- eht_eso1907a.jpg, M87*, 7416 x 4320, https://www.eso.org/public/images/eso1907a/
- eht_eso2208-eht-mwa.jpg, Sgr A*, 4076 x 4076, https://www.eso.org/public/images/eso2208-eht-mwa/
- eht_eso2105a.jpg, M87* in polarised light, https://www.eso.org/public/images/eso2105a/
- eht_eso2406a.jpg, Sgr A* in polarised light, https://www.eso.org/public/images/eso2406a/

ESO, CC BY 4.0 under ESO's standard terms (I read the credit lines on each page, not the terms page today):
- eso_eso1907f.jpg and eso_eso1907g.jpg, "Simulation of a Supermassive Black Hole", 4096 x 2560. Credit: Jordy Davelaar et al./Radboud University/BlackHoleCam. The hot thick flow with its jet. https://www.eso.org/public/images/eso1907f/ and /eso1907g/
- eso_eso1907c.jpg, artist's impression of M87's hole. Credit: ESO/M. Kornmesser. Kept as an example of what to avoid (whirlpool spiral, lightsaber jet). https://www.eso.org/public/images/eso1907c/

Continued in 5 of 8.

---

Black Hole look research 5 of 8: reference list, continued, and the sheets I made.

Interstellar paper: James, von Tunzelmann, Franklin and Thorne 2015, "Gravitational lensing by spinning black holes in astrophysics, and in the movie Interstellar", Class. Quantum Grav. 32 065001. The article is CC BY 3.0 ("Content from this work may be used under the terms of the Creative Commons Attribution 3.0 licence", https://iopscience.iop.org/article/10.1088/0264-9381/32/6/065001), but two figures carry their own terms (captions read at https://ar5iv.labs.arxiv.org/html/1502.03808 by a fetch tool):
- interstellar_cqg2015_fig14.jpg (a=0.999) and interstellar_cqg2015_fig15.jpg (1275 x 1802; a: natural, b: with the Doppler colour shift, c: with the brightness shift too). No separate credit in their captions, so CC BY 3.0. Fig 15 is the best reference for a physically honest cool disc.
- interstellar_cqg2015_fig13.jpg and interstellar_cqg2015_fig16.jpg (the lens flare): "TM & (c) Warner Bros. Entertainment Inc.", CC BY-NC-ND 3.0. Look only. Never into the repo, docs or site.
- interstellar_cqg2015_fig4.jpg (lensed stars round a spinning hole): per-figure terms not checked; treat as look only.
Facts from that paper (fetch tool's reading): the artists' disc is at a uniform 4500 K; camera at 74.1M, 86.56 degrees from the axis; the film slowed the spin from about 1 to 0.6 and left out the Doppler shifts; speeds about 0.55c, frequency factors about 1.5 and 0.4.

Wikimedia Commons (licences read from the Commons API, scripts/commons.py):
- luminet1979_BH-JPL-AA1979.jpg, 700 x 346. Jean-Pierre Luminet's 1979 image. CC BY-SA 4.0. https://commons.wikimedia.org/wiki/File:BH-JPL-A%26A1979.jpg
- riazuelo_BH_LMC.png, 2560 x 2048. A bare hole in front of the Large Magellanic Cloud with its Einstein ring: the best reference for lensed stars. Alain Riazuelo (User:Alain r). CC BY-SA 2.5. https://commons.wikimedia.org/wiki/File:BH_LMC.png
- kraus_Black_Hole_Milkyway.jpg, 2560 x 2048. Ute Kraus, background Axel Mellinger. CC BY-SA 2.5. https://commons.wikimedia.org/wiki/File:Black_Hole_Milkyway.jpg

If sampled colours go into the app, cite NASA SVS 13326 and the EHT images; both are safe. Nothing share-alike or non-commercial should be copied into the repo.

Sheets and crops I made, in scripts/out/:
- acceptance_85deg.png: the 85 degree frame with every measured mark.
- acceptance_angles.png: face-on, 56, 65 and 85 degrees, 16:10 crops at one scale.
- flyby_00383_centre.png: NASA 2024, disc against the sky. sheet_inter.png: Interstellar figs 14, 15, 16. sheet_eht.png, sheet_lens.png (Luminet, Riazuelo, Kraus), sheet_eso.png, sheet_bin.png.

Scripts, in scripts/ (run with python3 -I, paths as arguments): ring.py (photon ring fit), cuts.py (edges), faceon.py (radial profile and colours), doppler.py (side ratio), motion.py (pattern speed), schwarz.py (predicted edges for any angle and radius; has a self-check), realholes.py (periods, disc temperatures, blackbody colours; has a self-check), eht.py, starcount.py, commons.py, sheet.py, thumb.py, bbox.py.

What I could not get: nothing was blocked. I did not download the 4K movies or more than 24 of NASA's 1,922 frames, to stay polite; any frame is at https://svs.gsfc.nasa.gov/vis/a010000/a013300/a013326/frames/3840x3840_1x1_30p/360/frame_NNNN.bmp .

---

Black Hole look research 6 of 8: real black holes to model after. Periods, temperatures and colours are my calculations (scripts/realholes.py, textbook formulas). "Stars" = how many of the app's catalogue stars (Resources/stars.txt, Yale to V 5.5, 2,887 in all) lie within 30 degrees (scripts/starcount.py). Coordinates are J2000 from memory: check against SIMBAD before use.

Sgr A*. 4.3 million Suns; ring 51.8 microarcsec; the EHT disfavours inclinations over 50 degrees, no spin and backwards discs (https://doi.org/10.3847/2041-8213/ac6674). Flares circle clockwise at about 9 M in about an hour (https://www.aanda.org/10.1051/0004-6361/202347416). Hot thick flow, radio and infrared, nearly dark to the eye. Inner orbit 33 min (no spin) or 20 min (spin 0.5); 10M 1.2 h; 30M 6 h. RA 17h45m40.0s, Dec -29d00m28s. Stars 250 (Scorpius, Sagittarius).

M87*. 6.5 billion Suns, ring 42 microarcsec, viewed 17 degrees from its jet, spin pointing away from us if aligned with the jet; spin size unmeasured (https://alphaxiv.org/abs/1906.11242, https://arxiv.org/pdf/1906.11241). Hot thick flow plus a jet. Inner orbit 10 to 34 days. RA 12h30m49.4s, Dec +12d23m28s. Stars 123.

Cygnus X-1. 21.2 Suns, 2.22 kpc, 27.5 degrees (https://arxiv.org/abs/2102.09091); spin over 0.9985 (https://www.doi.org/10.3847/1538-4357/abbcd6). Thin disc at about 5 million K in its soft state, a hot corona in its hard state. Blue-white. Inner orbit 1.6 ms. RA 19h58m21.7s, Dec +35d12m06s. Stars 231, with Vega, Altair and Deneb.

GRS 1915+105. 12.4 Suns, 8.6 kpc, jet at 60 degrees (https://dspace.mit.edu/handle/1721.1/93111); spin 0.86 to 0.99 depending on the data (https://arxiv.org/abs/2101.11655). Thin disc near 10 million K, blue-white, jets. Dim since 2018 (from memory); Swift reads zero this week. Inner orbit 1.2 ms. RA 19h15m11.6s, Dec +10d56m45s. Stars 212.

LMC X-3. 6.98 Suns, 69.2 degrees (https://arxiv.org/abs/1402.0085); spin 0.25, almost always a thin disc (https://arxiv.org/abs/1402.0148). About 7 million K, blue-white. Inner orbit 2.6 ms. RA 05h38m56s, Dec -64d05m03s. Stars 229, with Canopus and Achernar. This is NASA's picture in a real object.

TON 618. 40.7 billion Suns (or 66 billion by another line) (https://en.wikipedia.org/wiki/TON_618). Angle and spin unknown. Thin disc: 38,000 K at its hottest, 14,000 K at 30M, 5,900 K at 100M, about 2,600 K at 300M (at half the Eddington rate). Inner orbit 100 to 214 days; 30M 6.6 years. RA 12h28m25s, Dec +31d28m38s. Stars 136.

A0620-00. 6.61 Suns, 51.0 degrees, 1.06 kpc (https://arxiv.org/abs/1001.0261); spin 0.12 (https://arxiv.org/abs/1002.2211; value from memory). Quiet since 1975. RA 06h22m44.5s, Dec -00d20m45s. Stars 276, with Sirius, Rigel and Procyon: Orion bends round it.

Gaia BH1. About 10 Suns at 477 pc, the nearest known; dormant, no disc (https://arxiv.org/abs/2209.06833). RA 17h28m41s, Dec -00d34m52s. Stars 184.

M31's: 140 million Suns (from memory), nearly dark, nothing to draw. Skip. Also unverified, from memory: 3C 273 (12 degrees) and NGC 4258 (a thin disc at 82 degrees, seen in masers).

Four different pictures: (1) steep thin disc: LMC X-3 with the dark gap, GRS 1915+105 without it (high spin pulls the disc in to the shadow). (2) Shallow thin disc: Cygnus X-1 and TON 618, the same shape, different colour and width. (3) Hot thick flow: Sgr A* and M87* look alike; M87* adds a jet. (4) Dormant: A0620-00 and Gaia BH1, alike but for their stars.

Caveat on "the real stars behind it": the stars are our sky in that direction, not the sky from there, and the hole is drawn tens of degrees wide. At the Interstellar camera distance (74M) the screen spans about 65 degrees, which is where the 120 to 280 stars come from.

---

Black Hole look research 7 of 9 (one more than I said): true colour against convention, and palettes.

What is true (my calculation, scripts/realholes.py: Planck spectrum through the CIE 1931 fit of Wyman, Sloan and Shirley 2013, to sRGB; it reproduces the usual blackbody colours, e.g. 3000 K as (255,185,110)):
- Blackbody colours by temperature: 1000 K (255,47,0). 1500 K (255,106,0). 2000 K (255,141,21). 3000 K (255,185,110). 4500 K (255,222,188). 6000 K (255,244,241). 8000 K (227,231,255). 10,000 K (205,217,255). 15,000 K (181,201,255). 30,000 K (162,187,255). 100,000 K and hotter (150,178,255).
- A Doppler or gravity shift of a blackbody is exactly a blackbody at the shifted temperature. So colour only ever slides along that one line, white-blue to orange. Never green, never magenta.
- Real thin discs near the horizon are far too hot to show any of it: Cygnus X-1 about 5 million K, GRS 1915+105 about 10 million, a quasar like TON 618 38,000 K. All are the same pale blue-white, and the two sides differ only in brightness, by 2 to 2.8 times (message 3).
- NASA's deep red to orange is the colour of a 1000 to 2500 K surface. No real disc near a horizon is that cool; it is a brightness ramp. Interstellar chose a uniform 4500 K "anemic" disc, cream.
- A 4500 K disc drawn honestly would be near-white (255,241,233) on the approaching side and orange (255,178,96) on the receding at 10M, and 112 times brighter on the bright side: the receding side all but vanishes (compare interstellar_cqg2015_fig15.jpg panel c, where I sampled (194,216,234) left and (76,70,62) right).
- Sgr A* and M87*: no visible-light picture. The EHT's orange maps radio brightness.

Palettes, each in one family:
1. Ember (the convention, my default). Stops from the EHT image, more amber-gold than NASA's red: (16,5,3), (89,8,2), (161,39,2), (205,79,2), (238,121,8), (248,167,36), (253,213,89), (254,244,189). NASA's own, if a redder ruby is wanted: (46,0,0), (139,0,0), (231,75,0), (255,136,7), (255,196,133). Honest label: "as radio telescopes show it".
2. True colour (honest for Cygnus X-1, GRS 1915+105, LMC X-3). One hue, (150,178,255), from navy shadow tones up to ice; brightness alone carries the structure. Calm and cool beside Nebula. Risk: reads less like "a black hole" than orange does.
3. TON 618 (honest for a giant quasar disc drawn out to 300M): the blackbody line itself, (159,185,255) core, (185,204,255) at 30M, (255,242,236) at 100M, then (255,222,188), (255,185,110), (255,141,21), with an ember (255,106,0) rim. It crosses blue and orange, but only along the line star colours follow, the same pairing as Galaxy's cream bulge and blue arms. This is the showpiece to mock up. It needs a wider frame (disc to 300M, hole small).
4. Sapphire (NASA's blue ramp, sampled from refs/nasa13831_BlackHole_Binary_MainSequence.jpg): (1,2,40), (1,2,90), (2,14,140), (3,67,190), (8,116,230), (52,169,253). False colour, as the orange is. Honest label: "X-ray".

Naming palettes by waveband (Radio, Visible, X-ray) keeps each one honest and gives Dave a reason for jewel tones.

For calm and dim: NASA's mean lit pixel is already only 104 of 255, deep red. What makes it loud is the streaks (5th to 95th percentile 100 to 200) and pure orange on pure black. I would keep the mean, cut streak contrast by about a third, cap the peak near 230, and apply Galaxy's asinh stretch and dither (docs/galaxy.md step 11); the deep red outer taper is where 8-bit banding will show.

---

Black Hole look research 8 of 9: what can move calmly, and live data.

What NASA moves (measured, message 3): the disc turns with Kepler shear at 36 M a second (inner edge every 2.6 s, outer every 29 s); knots form and fade; the camera swings over the pole at 36 degrees a second. The 2024 version adds a camera flying in. All too fast for a desktop.

What I would move:
- The disc, sheared, at about 0.6 M a second, 1/60 of NASA's. Inner edge laps in 2.6 minutes, the 10M orbit in 5.5, the outer edge in 29. With a 90 pt shadow that is 2 to 5 pt a second across the disc, matching Galaxy's and Nebula's 3 to 4 pt a second (docs/galaxy.md, Rotation). For a hole of Sgr A*'s mass it is 13 times real time.
- A speed slider with a marked "real time for Sgr A*" stop (inner edge 33 minutes, outer edge 6 hours) would be honest, but nearly still: per the lively-over-realistic rule it should be a stop, not the default. No other real hole works in real time: M87* takes 10 to 34 days a lap, the stellar ones lap 400 to 900 times a second.
- Shear is the look here, unlike Galaxy, which turns rigidly because a sheared texture winds up for ever (docs/galaxy.md, Rigid rotation). So the knots must be reborn. NASA's pattern has half-forgotten itself after about 36 M.
- A faint hot spot. Sgr A*'s real flares circle at about 9 M in about an hour (https://www.aanda.org/10.1051/0004-6361/202347416). One dim spot, with its fainter lensed twins on the photon ring, is real and calm if its brightness is capped. An activity slider can set how often.
- The viewing angle, as a slow nod, for example 70 to 85 degrees over 10 to 20 minutes. Every angle is a correct picture, so this is free variety.
- Stars. As the camera drifts round the hole the field slides past. Each star has a second, faint image on the far side of the shadow moving the other way; near alignment both stretch into arcs on the Einstein ring and brighten. Calm at 1 to 2 pt a second with the brightening capped; uncapped, a bright star passing dead behind would flash.
- A new roll each load, like Galaxy: kind, angle, which side approaches, star field.

Live data. Both of these answered on 2026-10-10:
- Swift/BAT daily light curve, plain text: https://swift.gsfc.nasa.gov/results/transients/CygX-1.lc.txt (last row MJD 61323, file made 2026-10-11 01:20 UTC).
- MAXI daily, plain text, four bands: http://maxi.riken.jp/star_data/J1958+352/J1958+352_g_lc_1day_all.dat (last row MJD 61321.5).
Soft against hard X-rays gives Cygnus X-1's state: soft means the thin disc reaches the inner orbit, hard means a hot corona has replaced the inner disc. It flips over weeks, a few times a year (from memory).
My view: not for the first version. It is real, but it is an X-ray change that visible light would not show; it serves one kind only; MAXI is plain http, I did not check its terms, and both instruments are old (2009 and 2004). GRS 1915+105 reads zero. For Sgr A* I know of no machine-readable flare feed: flares last under an hour and monitoring is daily at best. If Dave wants a live touch later, "Cygnus X-1 today" as a switch that nudges the disc's inner edge and brightness is the honest one. The "real" in this wallpaper is the geometry, the real stars and the real-hole kinds.

---

Black Hole look research 9 of 9: pitfalls, each with the number or reference that guards against it, then what is still open.

1. Bloom and lens flare. NASA has none: every pixel is 0 beyond 6.8 Rs, inside 0.98 Rs, and in the 0.27 Rs gap between ring and disc. The Interstellar flare (refs/interstellar_cqg2015_fig16.jpg) fills the shadow with haze. A soft edge is right (NASA tapers from 4 to 6.2 Rs); glow that lifts the shadow or the gap off black is not.
2. Both sides equally bright. Interstellar left the Doppler effect out. The opposite mistake is the full effect (18 to 62 times), which deletes one side. Target 1.6 in display values, on the side turning toward us, and none face-on.
3. Rainbow Doppler: blue one side, red the other at full saturation. The shift only slides along the blackbody line, and for a hot disc there is no colour change at all.
4. Neon. NASA's mean lit pixel is deep red (150,0,0); only 0.1% of pixels pass 200 of 255.
5. A fat glowing photon ring. The real one is a hairline, at most 0.004 Rs; the ring beside it is 0.01 Rs wide at 85 degrees and 0.09 face-on.
6. Wrong shapes: the hump drawn as half an ellipse, the under-arc missing, the disc touching the shadow on a non-spinning hole, the flat cut under the near side missing. Message 2 has each number.
7. A vinyl record: even concentric bands with hard edges. NASA's streaks are sheared arcs of uneven width that fork and fade (scripts/out/f0000_centre.png).
8. A whirlpool: galaxy-style spiral arms and a lightsaber jet (refs/eso_eso1907c.jpg). Discs have no grand spiral.
9. Stars: drawn inside the shadow; not bent; no second images; a visible lattice (Dave spotted hash tiling in Galaxy, docs/galaxy.md Gotchas); too bright or too coloured. refs/riazuelo_BH_LMC.png and refs/nasa13043_sub-warped-gaia-000000.png show it done right.
10. Speed: time-lapse spin and swooping cameras (message 8).
11. A hard-edged shape on pure black, which read as CG on Galaxy until it got a stretch, soft edges and a dim sky.
12. Banding in the dark red taper without dither.
13. Zen Garden's and Crystals' lesson (docs/README.md): this image's beauty is fine bright streaks on black, which fights "soft and dim". Compare a softened render with NASA's side by side before going far; if softening kills it, the 65 degree view and the TON 618 gradient depend less on streak detail.

Open or unverified:
- The viewing angles of NASA's frames are my fits (plus or minus 1.5 degrees); NASA publishes none.
- NASA's disc radii (6M to 30M) are my fit too. bh-physics should confirm with their tracer.
- "Linear light" ratios assume the frames are sRGB.
- IDL "Red Temperature": from memory.
- From memory, not checked today: all coordinates; M31*, 3C 273, NGC 4258; A0620-00's spin value; Gaia BH1's exact mass; M87*'s and Sgr A*'s masses (search results confirmed 6.5 billion and "about 4 million" only loosely); GRS 1915+105 dim since 2018; how often Cygnus X-1 changes state.
- Licences not checked: MAXI data; the Gaia background in NASA 13043; Interstellar Fig 4; ESO's terms page (relied on docs/deep-space.md).
- The shipped catalogue stops at V 5.5 (2,887 stars). A dense lensed field needs more: the full Yale catalogue is 9,110 stars (from memory), or a Milky Way band as NASA used.
- The hot thick flow (M87*, Sgr A*) has no acceptance numbers beyond message 3's EHT measures; refs/eso_eso1907f.jpg is the only unblurred reference I found.

That is the whole report. I am idle unless you want more frames measured, a palette strip rendered, or the unverified items chased.

---

Measured geometry of NASA's 2019 black hole frames, for checking your tracer (from the look-research agent; full report went to main).

Files: scratch/blackhole/refs/nasa13326_360_frame_NNNN.bmp (3840 px, 8-bit palette, index = brightness). Marked-up sheet: .../blackhole/scripts/out/acceptance_85deg.png. My check code: .../blackhole/scripts/schwarz.py (u'' + u = 3u^2, bisect on impact parameter; has a self-check).

Unit: shadow radius Rs = sqrt(27) M = 250.1 px, centre (1919.5, 1919.6). The hole is non-spinning; the disc fits 6M to about 30M (threshold 10 of 255). Angles are my fits, plus or minus 1.5 degrees. Distances from the centre along the vertical:

- Frame 0390, about 10 degrees: disc 1.31-1.37 to 5.92; ring from one extra half-turn at 1.05 to 1.15; hairline photon ring at 0.998, 1 px wide.
- Frame 0330, about 56 degrees: far side 1.42 to 4.17 above; near side 0.68 to 3.32 below.
- Frames 0450 and 0630, about 65 degrees: far side 1.37 to 3.62-3.70; near side 0.50 to 2.38-2.42.
- Frame 0000, about 85 degrees: far side 1.27 to 2.55 above; near side 0.11 to 0.48 below; under-arc 1.24 to 2.16 below, cut off flat at 0.66 below by the near side of the disc (opaque beyond where it stops shining); half-width 5.97 left, 5.72 right; top ring 1.010 to 1.022.

schwarz.py predicts for 6M to 30M: 0 degrees 1.334 to 5.963; 56 degrees far 1.367 to 4.194, near 0.656 to 3.239; 65 degrees far 1.338 to 3.673, near 0.492 to 2.444; 85 degrees far 1.265 to 2.617, near 0.101 to 0.503, underside 1.230 to 2.214, top ring 1.012 to 1.028.

Brightness: approaching to receding is 1.6 in display values at 85 degrees (about 3.3 in linear light if sRGB), none face-on. The pattern shears as Kepler, 1.2 M of time per frame. No bloom anywhere: exactly 0 beyond 6.8 Rs and inside 0.98 Rs.

If your tracer disagrees with any of these by more than about 0.05 Rs, tell main: either my angle estimates or the 30M outer edge would be the first things to doubt.
