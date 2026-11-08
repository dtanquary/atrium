"""The mock-up sheets: each a list of (caption, settings for mock.swift). Sizes are points, drawn at 2x."""
TILE = {"width": 640, "height": 400}  # a piece of the screen, two fifths of a 14-inch display's width
DESK = {"width": 1512, "height": 982}  # a 14-inch desktop, scaled down to the tile
DEEP = ["periphylla", "atolla", "periphylla", "comb", "atolla", "periphylla"]

SHEETS = {
    "tune": [(k, {"look": "deep", "species": [k], "single": True, "size": 0.32, "tilt": 0.35, "heading": 0.0, "t": 7.0,
                  "width": 320, "height": 200}) for k in ("moon", "nettle", "crystal", "atolla", "periphylla", "comb")],
    # Round 1, question 1: what light shows them.
    "sheet1-light": [
        ("A  Into the Deep: a dim lamp on deep red jellies", {"look": "deep", "species": DEEP, "count": 10, "seed": 7, "t": 8.0, **DESK}),
        ("B  An ROV's lights: far ones fade to black", {"look": "rov", "species": DEEP, "count": 10, "seed": 7, "t": 8.0, **DESK}),
        ("C  Lights off: their own light, only when touched", {"look": "dark", "species": DEEP, "count": 10, "seed": 7, "glow": [0, 1], "t": 8.0, **DESK}),
        ("D  Crystal jellies under blue light: their green ring", {"look": "fluor", "species": ["crystal"], "count": 9, "seed": 4, "t": 8.0, **DESK}),
        ("E  The jelly gallery: moon jellies, lit blue tank", {"look": "gallery", "species": ["moon"], "count": 11, "seed": 5, "t": 8.0, **DESK}),
        ("F  A steady blue glow (made up: none do this)", {"look": "glow", "species": ["moon"], "count": 11, "seed": 5, "t": 8.0, **DESK}),
    ],
    # Question 2: which animals.
    "sheet2-species": [
        (f"{l}", {"look": "deep", "species": [k], "single": True, "size": z, "tilt": 0.45, "heading": 0.0, "t": 7.0, **TILE})
        for l, k, z in (("A  Moon jelly (Aurelia)", "moon", 0.28), ("B  Pacific sea nettle (Chrysaora)", "nettle", 0.2),
                        ("C  Crystal jelly (Aequorea)", "crystal", 0.24), ("D  Crown jelly (Atolla)", "atolla", 0.2),
                        ("E  Helmet jelly (Periphylla)", "periphylla", 0.2), ("F  Lobed comb jelly (Bolinopsis)", "comb", 0.17))
    ],
    # Question 3: how many, and how near.
    "sheet3-crowd": [
        ("A  Four, none near", {"look": "deep", "species": DEEP, "count": 4, "seed": 11, "t": 8.0, **DESK}),
        ("B  Ten, near, middle and far", {"look": "deep", "species": DEEP, "count": 10, "seed": 7, "t": 8.0, **DESK}),
        ("C  One up close, the rest far off", {"look": "deep", "species": DEEP, "count": 9, "seed": 12, "near": True, "t": 8.0, **DESK}),
        ("D  A bloom of helmet jellies, as in Lurefjorden", {"look": "deep", "species": ["periphylla"], "count": 30, "seed": 9, "t": 8.0, **DESK}),
    ],
    # Question 4: the motion, frame by frame.
    "sheet4-motion": [
        ("A  A moon jelly's pulse: a quick squeeze, a slow re-opening, a coast",
         {"look": "deep", "species": ["moon"], "single": True, "size": 0.5, "tilt": 0.3, "heading": 0.0, "width": 260, "height": 200,
          "times": [1.0, 1.15, 1.3, 1.45, 1.7, 2.1, 2.6, 3.4, 4.4, 5.6]}),
        ("B  A sea nettle turning: its tentacles carry the old heading down",
         {"look": "deep", "species": ["nettle"], "single": True, "size": 0.22, "tilt": 0.3, "heading": 0.0, "turn": 0.8,
          "width": 260, "height": 340, "times": [1.0, 1.6, 2.2, 2.8, 3.4, 4.0, 4.6, 5.2, 5.8, 6.4]}),
    ],
    "sheet5-desk": [("A dim lamp on deep red jellies, at a 14-inch display's size", {"look": "deep", "species": DEEP, "count": 10, "seed": 7, "t": 8.0, **DESK})],
    "film1-deep": [("", {"look": "deep", "species": DEEP, "count": 10, "seed": 7, "width": 756, "height": 491, "t": 6.0, "frames": 360, "fps": 30})],
    "film2-pulse": [("", {"look": "deep", "species": ["moon"], "single": True, "size": 0.32, "tilt": 0.35, "heading": 0.0,
                          "width": 640, "height": 400, "t": 2.0, "frames": 360, "fps": 30})],
}
