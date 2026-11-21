"""Beehive's mock-up sheets: each a list of (caption, settings for mock.swift). Sizes are points, drawn at 2x."""
import os, tempfile

PHOTO_DIR = os.environ.get("BEEHIVE_PHOTO_DIR", os.path.join(tempfile.gettempdir(), "beehive-photo"))
PHOTO = os.path.join(PHOTO_DIR, "light.jpg")  # USGS BIML, Apis mellifera, light body, back (Public Domain Mark 1.0)
WOOD = os.path.join(PHOTO_DIR, "wood.jpg")    # Poly Haven, coated_pine_02, 2k diffuse (CC0)

DESK = {"width": 1512, "height": 982}                 # a 14-inch desktop, scaled down to the tile
CROP = {"width": 320, "height": 200, "full": True}    # a piece at 1:1 device pixels: the tile is the screen's own pixels
FILM = {**DESK, "frames": 360, "fps": 30, "down": 4}  # 12 s in real time, at half the desktop's size
BASE = {"look": "amber", "seed": 7, "hour": 9, "bees": 1, "size": 1, "temp": 22, "holds": "honey", "frame": "none",
        "atlas": "photo", "photo": PHOTO}


def drawn(h):
    """The share of the comb drawn out h hours into the farm (research-method.md §3)."""
    return 0.25 + 0.75 * (1 - (1 - min(h, 24) / 24) ** 2)


def clock(h):
    m = round(((6 + h) % 24) * 60)
    return f"{m // 60:02d}:{m % 60:02d}"


SHEETS = {
    # Round 1, question 1: the light and the comb's age.
    "sheet1-look": [
        ("A  Amber: mid-age comb, a warm lamp, a dark room", {**BASE, **DESK}),
        ("B  Old Comb: dark comb, honey glowing in it", {**BASE, "look": "old", **DESK}),
        ("C  New Comb: pale fresh wax in daylight (Light Mode)", {**BASE, "look": "new", **DESK}),
        ("D  Red Lamp: the hive at night under red light", {**BASE, "look": "red", **DESK}),
        ("E  Amber lit through from behind", {**BASE, "look": "backlit", **DESK}),
    ],
    # Question 2: what the comb holds (trypophobia is why it is asked).
    "sheet2-holds": [
        ("A  Honey only (the method's pick)", {**BASE, "hour": 14, **DESK}),
        ("B  Honey, with a narrow band of bee bread", {**BASE, "hour": 14, "holds": "pollen", **DESK}),
        ("C  A brood frame: capped brood, pollen, a honey arch", {**BASE, "hour": 14, "holds": "brood", **DESK}),
    ],
    # Question 3: how many bees, and how big.
    "sheet3-bees": [
        ("A  Small bees, 1x (about 980)", {**BASE, "size": 0, **DESK}),
        ("B  Medium, 0.5x (about 250)", {**BASE, "bees": 0.5, **DESK}),
        ("C  Medium, 1x (about 500, the standard)", {**BASE, **DESK}),
        ("D  Medium, 2x (about 1,000)", {**BASE, "bees": 2, **DESK}),
        ("E  Large bees, 1x (about 245)", {**BASE, "size": 2, **DESK}),
    ],
    # Question 4: how a bee is drawn, at its real size on the screen.
    "sheet4-bee": [
        ("A  Photo cut-out, on capped honey", {**BASE, "hour": 16, "seed": 11, **CROP}),
        ("B  Painted, on capped honey", {**BASE, "hour": 16, "seed": 11, "atlas": "painted", **CROP}),
        ("C  Photo cut-out, at the building edge", {**BASE, "hour": 4, "seed": 12, **CROP}),
        ("D  Painted, at the building edge", {**BASE, "hour": 4, "seed": 12, "atlas": "painted", **CROP}),
    ],
    # Question 5: how much of the hive shows.
    "sheet5-frame": [
        ("A  Edge to edge: the screen is the glass", {**BASE, **DESK}),
        ("B  The frame's top bar and sides", {**BASE, "frame": "bar", **DESK}),
        ("C  The case, its shutter lifted", {**BASE, "frame": "case", **DESK}),
    ],
    # Question 6: one comb through its day.
    "sheet6-day": [(f"{'ABCDE'[n]}  {clock(h)}, {round(100 * drawn(h))}% drawn", {**BASE, "hour": h, **DESK})
                   for n, h in enumerate((0, 3, 6, 12, 18))]
                  + [("F  06:00 next day: the new comb dissolving in, half way", {**BASE, "mix": 0.5, **DESK})],
    # Question 7: the cold, at the same hour.
    "sheet7-cold": [(f"{'ABCD'[n]}  {t} °C outside", {**BASE, "hour": 12, "temp": t, **DESK}) for n, t in enumerate((20, 14, 8, -5))],
    "sheet8-desk": [("The standard: Amber, Medium bees, 1x, honey, 15:00", {**BASE, **DESK})],
    # The motion, frame by frame, two seconds apart, at 1:1 device pixels.
    "sheet9-motion": [
        ("A  A walking bee, two seconds a frame (1:1 device pixels)", {**BASE, "focus": "walk", "width": 200, "height": 110, "seed": 13,
                                                   "hour": 14, "full": True, "times": [180.0 + 2 * k for k in range(6)]}),
        ("B  A bee storing nectar, then leaving", {**BASE, "focus": "cell", "width": 200, "height": 110, "seed": 13, "hour": 6,
                                                   "full": True, "times": [180.0 + 2 * k for k in range(6)]}),
    ],
    "film1-hive": [("", {**BASE, **FILM})],
    "film2-morning": [("", {**BASE, "hour": 0.5, **FILM})],
}

# Round 2: Dave's picks ("1 A/C/B/E, 2 A, 3 C, 4 photo, 5 A, 6 stacked, 7 yes, 8 its ok, 9 yes ok"), in a stack of frames.
# A tile's clock is shown three minutes on from `hour` (the colony runs 180 s before it is drawn), so 06:30 is 0.45.
STACK = {**BASE, **DESK, "stack": "deep", "wood": WOOD}
DEPTH = "medium" # round 2's recommendation from sheet 10 (the screen stays mostly comb after the change), used by the sheets after it
REC = {**STACK, "stack": DEPTH}


def change(kind, dur, f, depth=DEPTH):
    """The stack moving on, f of the way through: it starts at 22:00, when the next comb's first cells appear."""
    return {**STACK, "stack": depth, "change": kind, "dur": dur, "f": f, "hour": 16 + f * dur / 3600 - 0.05}


def at(f, dur):
    m = round(22 * 60 + f * dur / 60)
    return f"{m // 60:02d}:{m % 60:02d}"


SHEETS.update({
    # Question 1 of round 2: how deep a frame; the morning is the point.
    # The darkest hour is now just after the stack moves on at 22:00, when the new comb has only its first cells.
    "sheet10-stack": [
        ("A  Deep frames, 06:30", {**STACK, "hour": 0.45}),
        ("B  Deep frames, 15:00", {**STACK, "hour": 8.95}),
        ("C  Deep frames, 23:00, just after the change", change("slide", 1800, 1, "deep") | {"hour": 16.95}),
        ("D  Medium frames, 06:30", {**STACK, "stack": "medium", "hour": 0.45}),
        ("E  Medium frames, 15:00", {**STACK, "stack": "medium", "hour": 8.95}),
        ("F  Medium frames, 23:00, just after the change", change("slide", 1800, 1, "medium") | {"hour": 16.95}),
    ],
    # Question 2: how the stack moves on when the next comb starts; five moments of each.
    "sheet11-change": [
        (label, [(at(f, dur), change(kind, dur, f)) for f in (0, 0.25, 0.5, 0.75, 1)])
        for label, kind, dur in (("A  The stack slides up one frame over 30 minutes", "slide", 1800),
                                 ("B  The same slide over 5 minutes", "slide", 300),
                                 ("C  Nothing moves: each comb dissolves into the one below's, in patches, over 30 minutes", "dissolve", 1800))
    ],
    # Question 3: the four looks he chose, in the stack.
    "sheet12-looks": [
        ("A  Amber (the standard)", {**REC, "hour": 8.95}),
        ("B  New Comb (Light Mode)", {**REC, "look": "new", "hour": 8.95}),
        ("C  Old Comb", {**REC, "look": "old", "hour": 8.95}),
        ("D  Amber lit through from behind", {**REC, "look": "backlit", "hour": 8.95}),
    ],
    "sheet13-desk": [("The standard in the stack at 06:30, the hour round 1 failed", {**REC, "hour": 0.45, "clock": "Fri 20 Nov  06:30"})],
    "film3-morning": [("", {**REC, "hour": 0.45, **FILM})],
    "film4-change": [("", {**change("slide", 1800, 0.5), **FILM})],
    "film4-change-60x": [("", {**change("slide", 1800, 0.25), **FILM, "rate": 60, "label": "60\u00d7"})],
})

