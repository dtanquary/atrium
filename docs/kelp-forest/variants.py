"""The mock-up sheets: each a list of (caption, settings for mock.swift). Sizes are points, drawn at 2x."""
DESK = {"width": 1512, "height": 982}  # a 14-inch desktop, scaled down to the tile
FILM = {"width": 756, "height": 491, "frames": 600, "fps": 30}  # 20 s at half a 14-inch display's pixels

# The views (research-method.md §4): metres, degrees.
LEVEL = {"pitch": 12, "camY": 3, "depth": 12, "near": 6, "plants": 10, "fronds": 16}
TIPPED = {"expo": 0.6, "pitch": 30, "camY": 2, "depth": 12, "near": 5, "plants": 10, "fronds": 16}
UP = {"expo": 0.42, "pitch": 58, "camY": 2, "depth": 10, "near": 4, "plants": 12}
CANOPY = {"pitch": 12, "camY": 8.3, "depth": 10, "near": 2.5, "far": 26, "plants": 18}
TANK = {"pitch": 8, "camY": 3, "depth": 8.5, "near": 3, "far": 7.5, "plants": 9, "fronds": 10, "tank": 8.5}
LOW = {"pitch": 6, "camY": 0.6, "depth": 12, "near": 3, "plants": 12}
SHALLOW_UP = {"expo": 0.55, "pitch": 40, "camY": 1.5, "depth": 9, "near": 3, "plants": 14}

SHEETS = {
    # Round 2: Dave's two views (round 1's films 1 and 2), giant kelp only (docs/kelp-forest.md, Dave's feedback).
    "round2-light": [
        ("A  Level, Channel Islands (Light Mode)", {"look": "channel", "seed": 5, "t": 20, **LEVEL, "pitch": 20, "camY": 2.5, "expo": 0.8, **DESK}),
        ("B  Level, golden", {"look": "golden", "seed": 5, "t": 20, **LEVEL, "pitch": 20, "camY": 2.5, "expo": 0.9, **DESK}),
        ("C  Level, dusk (Dark Mode)", {"look": "dusk", "seed": 5, "t": 20, **LEVEL, "pitch": 20, "camY": 2.5, "expo": 0.5, **DESK}),
        ("D  Looking up, Channel Islands (Light Mode)", {"look": "channel", "seed": 5, "t": 20, **UP, **DESK}),
        ("E  Looking up, golden", {"look": "golden", "seed": 5, "t": 20, **UP, "expo": 0.45, **DESK}),
        ("F  Looking up, dusk (Dark Mode)", {"look": "dusk", "seed": 5, "t": 20, **UP, "expo": 0.3, **DESK}),
    ],
    # Measured, not committed: no calmer than film2-up (docs/kelp-forest.md, round 2).
    "film4-up-carried": [("", {"look": "channel", "seed": 5, "t": 20, **UP, "carry": 0.8, **FILM})],
    "film5-level-dusk": [("", {"look": "dusk", "seed": 5, "t": 20, **LEVEL, "pitch": 20, "camY": 2.5, "expo": 0.5, **FILM})],
    # Round 1, question 1: where we look from.
    "sheet1-view": [
        ("A  Level through the forest, into the haze", {"look": "channel", "seed": 5, "t": 20, **LEVEL, **DESK}),
        ("B  Tipped up 30°, toward the light", {"look": "channel", "seed": 5, "t": 20, **TIPPED, **DESK}),
        ("C  Looking up into the canopy and the Sun", {"look": "channel", "seed": 5, "t": 20, **UP, **DESK}),
        ("D  Just under the canopy", {"look": "channel", "seed": 5, "t": 20, **CANOPY, **DESK}),
        ("E  An aquarium's kelp tank, through its window", {"look": "channel", "seed": 7, "t": 20, **TANK, **DESK}),
        ("F  Low among the holdfasts", {"look": "channel", "seed": 5, "t": 20, **LOW, **DESK}),
    ],
    # Question 2: the water and the light, each sampled from a real photo (research-look.md §3).
    "sheet2-water": [
        ("A  Channel Islands: sunlit teal", {"look": "channel", "seed": 5, "t": 20, **LEVEL, **DESK}),
        ("B  The same, all teal: the kelp takes the water's colour", {"look": "teal", "seed": 5, "t": 20, **LEVEL, **DESK}),
        ("C  Overcast, after a photo of bull kelp", {"look": "bull", "seed": 5, "t": 20, **LEVEL, **DESK}),
        ("D  Golden, backlit (Patagonia)", {"look": "golden", "seed": 5, "t": 20, **LEVEL, **DESK}),
        ("E  Monterey green", {"look": "monterey", "seed": 5, "t": 20, **LEVEL, **DESK}),
        ("F  Dusk: deep blue (Cape Town)", {"look": "dusk", "seed": 5, "t": 20, **LEVEL, **DESK}),
    ],
    # Question 3: which kelp.
    "sheet3-kelp": [
        ("A  Giant kelp: many fronds from one holdfast", {"look": "channel", "kelp": "giant", "seed": 5, "t": 20, **SHALLOW_UP, **DESK}),
        ("B  Bull kelp: one stipe to a float and its blades", {"look": "channel", "kelp": "bull", "seed": 5, "t": 20, **SHALLOW_UP, **DESK}),
        ("C  A forest's edge: bull kelp among giant kelp", {"look": "channel", "kelp": "mixed", "seed": 5, "t": 20, **SHALLOW_UP, **DESK}),
        ("D  Bull kelp, looking up", {"look": "channel", "kelp": "bull", "seed": 6, "t": 20, **UP, **DESK}),
    ],
    # The recommended design at a desktop's size: tipped up 20°, between A and B, Channel Islands.
    "sheet5-desk": [("Recommended: tipped up 20°, Channel Islands, at a 14-inch display's size",
                     {"look": "channel", "seed": 5, "t": 20, **LEVEL, "pitch": 20, "camY": 2.5, "expo": 0.8, **DESK})],
    # Question 4: the motion, at the real pace: a 1 m swell at 12 s, a slow surge under it and a weak current.
    "film1-level": [("", {"look": "channel", "seed": 5, "t": 20, **LEVEL, **FILM})],
    "film2-up": [("", {"look": "channel", "seed": 5, "t": 20, **UP, **FILM})],
    "film3-bull": [("", {"look": "channel", "kelp": "bull", "seed": 6, "t": 20, **SHALLOW_UP, **FILM})],
}
