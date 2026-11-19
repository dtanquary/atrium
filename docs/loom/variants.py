"""The mock-up sheets: each a list of (caption, settings for mock.swift). Sizes are points, drawn at 2x.
A tile with "photo" is a crop of a reference photo instead, scaled as given."""
DESK = {"width": 1512, "height": 982}  # a 14-inch desktop, scaled down to the tile
CLOSE = {**DESK, "crop": [1200, 600, 640, 400]}  # a piece of it at 1:1, device pixels
FILM = {"width": 1512, "height": 984}  # two points taller, so a frame at half the points is even for H.264
STILL = {"rows": 2000.0}  # the fell part way through a pick: 2000 rows woven, the next not begun
OS = {"draft": "honeysuckle", "palette": "indigo", "pitch": 8, **STILL}

# The Art Institute of Chicago's 66024 (CC0, research-look.md A1): 2.7 px an end as photographed, 8 at life size here.
REF = {"photo": "aic-66024.jpg", "box": [300, 140, 513, 273]}

SHEETS = {
    # Round 1, question 1: which kinds of cloth.
    "sheet1-kind": [
        ("A  Overshot: Honeysuckle, Atwater's No. 6", {**OS, **DESK}),
        ("B  Summer and winter, on Honeysuckle's blocks", {**OS, "draft": "summer-winter", **DESK}),
        ("C  Double weave, on Honeysuckle's blocks", {**OS, "draft": "double-weave", **DESK}),
        ("D  Twill: Goose-Eye, Atwater's No. 291", {**OS, "draft": "goose-eye", **DESK}),
    ],
    # Question 2: does it read as cloth? Close up at 1:1, life size, beside a real coverlet.
    "sheet2-close": [
        ("A  A real overshot coverlet, c. 1840 (AIC, CC0)", REF),
        ("B  Overshot, soft, in its colours", {**OS, "palette": "weld", **CLOSE}),
        ("C  Overshot, crisp, in its colours", {**OS, "palette": "weld", "look": "crisp", **CLOSE}),
        ("D  Summer and winter, soft", {**OS, "draft": "summer-winter", **CLOSE}),
        ("E  Double weave", {**OS, "draft": "double-weave", **CLOSE}),
        ("F  Goose-Eye twill", {**OS, "draft": "goose-eye", **CLOSE}),
    ],
    # Question 3: thread size, the whole desktop.
    "sheet3-size": [
        ("A  3 px an end: 2.7 times life size's cloth", {**OS, "pitch": 3, **DESK}),
        ("B  5 px an end", {**OS, "pitch": 5, **DESK}),
        ("C  8 px an end: life size on a 14-inch screen", {**OS, **DESK}),
        ("D  12 px an end: half as big again", {**OS, "pitch": 12, **DESK}),
    ],
    # Question 4: the colours, Light Mode.
    "sheet4-colour": [
        ("A  Indigo, held", {**OS, **DESK}),
        ("B  Indigo, at a real coverlet's contrast", {**OS, "contrast": "real", **DESK}),
        ("C  Madder", {**OS, "palette": "madder", **DESK}),
        ("D  Walnut", {**OS, "palette": "walnut", **DESK}),
        ("E  Undyed", {**OS, "palette": "undyed", **DESK}),
        ("F  Red and blue (two families, to judge)", {**OS, "palette": "red-blue", **DESK}),
    ],
    # Question 5: the colours, Dark Mode.
    "sheet5-dark": [
        ("A  Blue on Blue", {**OS, "palette": "blue-on-blue", **DESK}),
        ("B  Madder Dark", {**OS, "palette": "madder-dark", **DESK}),
        ("C  Walnut Dark", {**OS, "palette": "walnut-dark", **DESK}),
        ("D  Black Sheep", {**OS, "palette": "black-sheep", **DESK}),
    ],
    # Question 6: the view.
    "sheet6-view": [
        ("A  Cloth to the edges, a finger of open warp", {**OS, "band": 40, **DESK}),
        ("B  A wider band of warp, and the reed", {**OS, "view": "reed", "band": 300, **DESK}),
        ("C  The cloth's selvedges, the floor beside it", {**OS, "view": "selvedge", **DESK}),
        ("D  From the weaver's bench", {**OS, "view": "bench", "band": 40, **DESK}),
    ],
    "sheet7-desk": [("Overshot in indigo, life size, at a 14-inch display's size", {**OS, **DESK})],
    # The motion, 12 s at half size: the standard pace, steady; and a weaver's own pace, sped up six times so a
    # winding on falls inside the film.
    "film1-standard": [("", {**OS, "draft": "summer-winter", **FILM, "rows": 2000.55, "pace": 0.2, "frames": 360, "fps": 30})],
    "film2-weaver": [("", {**OS, **FILM, "rows": 2000.0, "pace": 2.4, "wind": "weaver", "t": 1.0, "frames": 360, "fps": 30})],
}
