"""The mock-up sheets: each a list of (caption, settings for mock.swift). Sizes are points, drawn at 2x."""
DESK = {"width": 1512, "height": 982}  # a 14-inch desktop, scaled down to the tile
TODAY = {"sunEl": -8.4}                # the Sun 8.4 degrees south of the ring plane, 2026-11-18 (JPL Horizons)
C = {"view": "C", "sunAz": 320}        # sheet 2's view: along the rings with the planet's limb
PAN = {"view": "E", "h": 2.5, "pitch": 35, "ripple": "pan", "moonAhead": 4, "sunAz": 250, **TODAY}
DAPHNIS = {"view": "E", "r": 136.2, "h": 0.6, "pitch": 20, "ripple": "daphnis", "moonAhead": 2.5, "sunAz": 250, **TODAY}

SHEETS = {
    # Round 1, question 1: where the camera is. All in today's real light, lit face.
    "sheet1-view": [
        ("A  Looking in, the planet rising", {"view": "A", "sunAz": 140, **TODAY, **DESK}),
        ("B  Along the rings to the horizon", {"view": "B", "yaw": 70, "sunAz": 234, **TODAY, **DESK}),
        ("C  Along the rings, the planet's edge rising", {**C, **TODAY, **DESK}),
        ("D  From above: the shadow behind a lit globe", {"view": "D", "sunAz": 70, **TODAY, **DESK}),
        ("E  Low and close over the Encke gap", {"view": "E", "sunAz": 250, **TODAY, **DESK}),
    ],
    # Question 2: which light, in view C.
    "sheet2-light": [
        ("A  Today's Sun (8.4 degrees), lit face", {**C, **TODAY, **DESK}),
        ("B  Today's Sun, unlit face: the B ring dark", {**C, **TODAY, "face": "unlit", **DESK}),
        ("C  Cassini's years (Sun 20 degrees), lit face", {**C, "sunEl": -20, **DESK}),
        ("D  Golden night, toward the Sun: closest to Black Hole", {**C, "sunAz": 142, "face": "unlit", "palette": "golden", **TODAY, **DESK}),
        ("E  Equinox (Sun half a degree): the rings dim", {**C, "sunEl": -0.5, **DESK}),
        ("F  Black Hole today, for comparison", {"image": "../images/black-hole.jpg"}),
    ],
    # Question 3: the moon's ripple.
    "sheet3-ripple": [
        ("A  Pan in the Encke gap, wakes at real size", {**PAN, **DESK}),
        ("B  Pan close, 300 km up: its wake at real size", {**PAN, "r": 133.85, "h": 0.3, "yaw": 90, "pitch": 25, "moonAhead": 1.5, **DESK}),
        ("C  Daphnis in the Keeler gap, waves at real size", {**DAPHNIS, **DESK}),
        ("D  Daphnis close, 120 km up: waves at real size", {**DAPHNIS, "r": 136.56, "h": 0.12, "yaw": 90, "pitch": 20, "moonAhead": 0.6, **DESK}),
        ("E  Spokes on the B ring (dark at low phase)", {"view": "A", "sunAz": 140, "spokes": 1, **TODAY, **DESK}),
        ("F  Pan's wake 40x, made up", {**PAN, "amp": 40, **DESK}),
    ],
    "sheet4-desk": [
        ("Along the rings in today's light, from the unlit face", {**C, **TODAY, "face": "unlit", **DESK}),
    ],
}
