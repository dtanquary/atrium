"""The mock-up sheets: each a list of (caption, settings for mock.swift). Sizes are points, drawn at 2x."""
DESK = {"width": 1512, "height": 982}  # a 14-inch desktop, scaled down to the tile
FILM = {"width": 756, "height": 491, "at": -2.0, "frames": 360, "fps": 30}  # 12 s at half a 14-inch display's pixels
STRIP = {"width": 400, "height": 260, "times": [-1.0, 0.0, 0.6, 1.2, 2.0, 3.5, 6.0, 10.0], "at": 0.0}
BASE = {"seed": 3, "swell": 1.3, "at": 3.0}  # the moment: 3 s after the biggest wave of the first minute breaks

SHEETS = {
    # Round 1, question 1: where we stand. The fastest motion on screen decides the frame rate on battery.
    "sheet1-view": [
        ("A  From a bluff, 12 m up", {**BASE, "view": "bluff", **DESK}),
        ("B  At the water's edge", {**BASE, "view": "beach", **DESK}),
        ("C  From the beach, a long lens", {**BASE, "view": "long", **DESK}),
        ("D  Along the beach", {**BASE, "view": "along", **DESK}),
    ],
    # Question 2: how the light shows.
    "sheet2-light": [
        ("A  As video shows it: sheets of cyan", {**BASE, "view": "long", **DESK}),
        ("B  As the eye sees it: paler, dimmer", {**BASE, "view": "long", "palette": "eye", "look": "eye", **DESK}),
        ("C  As a long exposure: waves blur to mist", {**BASE, "view": "long", "look": "long", **DESK}),
        ("D  Noctiluca: the light in points", {**BASE, "view": "long", "look": "points", **DESK}),
    ],
    # Question 3: the surf.
    "sheet3-surf": [
        ("A  Small, spilling: 0.6 m", {**BASE, "view": "long", "swell": 0.6, **DESK}),
        ("B  Moderate, spilling: 1.3 m", {**BASE, "view": "long", **DESK}),
        ("C  Big sets: 2.2 m", {**BASE, "view": "long", "swell": 2.2, "at": 4.5, **DESK}),
        ("D  Plunging, on a steeper beach: 1.3 m", {**BASE, "view": "long", "beach": "steep", "at": 1.0, **DESK}),
    ],
    # Question 4: the colour, as three cameras' white balance shows the one light.
    "sheet4-colour": [
        ("A  Cyan, as footage shows it", {**BASE, "view": "long", **DESK}),
        ("B  Azure, nearest the eye's electric blue", {**BASE, "view": "long", "palette": "azure", **DESK}),
        ("C  Teal, as the Wadden Sea photos show it", {**BASE, "view": "long", "palette": "teal", **DESK}),
    ],
    # Question 5: the sky. The Moon lifts the sky, sea and sand; the glow stays as it is.
    "sheet5-sky": [
        ("A  No Moon", {**BASE, "view": "beach", **DESK}),
        ("B  A half Moon", {**BASE, "view": "beach", "moon": 0.5, **DESK}),
        ("C  A full Moon", {**BASE, "view": "beach", "moon": 1.0, **DESK}),
        ("D  A headland with a town's lights", {**BASE, "view": "beach", "land": True, "lights": True, **DESK}),
    ],
    # The motion: one wave from the long lens and the bluff, frame by frame.
    "sheet6-motion": [
        ("A  From the beach, a long lens: one wave, its break, its bore and the swash", {**BASE, "view": "long", **STRIP}),
        ("B  From a bluff: the same wave", {**BASE, "view": "bluff", **STRIP}),
    ],
    "sheet7-desk": [("From the beach, a long lens, cyan, no Moon, at a 14-inch display's size", {**BASE, "view": "long", **DESK})],
    "film1-long": [("", {**BASE, "view": "long", **FILM})],
    "film2-bluff": [("", {**BASE, "view": "bluff", **FILM})],
}
