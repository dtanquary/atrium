"""Canopy's mock-up sheets: each a list of (caption, settings for mock.swift). Sizes are points, drawn at 2x.

HDRIs are Poly Haven's (CC0), downloaded by sheet.py's `fetch` into HDRI_DIR, each in its own directory.
"""
import os

HDRI_DIR = os.environ.get("CANOPY_HDRI", os.path.join(os.environ.get("TMPDIR", "/tmp"), "canopy-hdri"))


def hdri(name, res="8k"):
    return os.path.join(HDRI_DIR, name, f"{name}_{res}.hdr")


# Every HDRI a sheet uses: name, resolution.
HDRIS = [("autumn_forest_04", "8k"), ("epping_forest_01", "8k"), ("autumn_forest_01", "4k"), ("schachen_forest", "4k")]

DESK = {"width": 1512, "height": 982}                     # a 14-inch desktop, at 2x
SUMMER = {"day": 196, "hour": 16.5}                         # 15 July, 4:30 pm solar time, 42°N: the Sun 31° up, out of frame
LATE = {"day": 305, "hour": 14.0, "turn": 1.0, "fallen": 0.5, "palette": "bronze"}  # 1 November, 2 pm: half the leaves down
STAND = {"method": "grown", "hdri": hdri("autumn_forest_04"), "sprays": 5000}  # (c): a beech stand, bare, near Stuttgart
PHOTO = {"method": "photo", "hdri": hdri("epping_forest_01")}                  # (a): Epping Forest in leaf
BUILT = {"method": "built", "sprays": 9000, "trees": 18}                       # (b)
REC = {"veil": 0.5, "soft": 2}                                                 # the recommended look's softening
FILM = {"frames": 360, "fps": 30, "raw": True}                                 # 12 s, written at half size

SHEETS = {
    # 1. How the crowns are made: the deciding sheet. Same place, date and light; summer above, late autumn below.
    "sheet1-make": [
        ("A  (a) Photo crowns, midsummer", {**PHOTO, **SUMMER, **DESK}),
        ("B  (b) All built: code limbs, scanned leaves", {**BUILT, **SUMMER, **DESK}),
        ("C  (c) Real bare stand, scanned leaves grown on it", {**STAND, **SUMMER, **DESK}),
        ("D  (a) Late autumn: recoloured, half dissolved", {**PHOTO, **LATE, **DESK}),
        ("E  (b) Late autumn: half down, the rest turned", {**BUILT, **LATE, **DESK}),
        ("F  (c) Late autumn: half down, the rest turned", {**STAND, **LATE, **DESK}),
    ],
    # The real photos behind sheet 1, as a camera shows them (not wallpaper looks).
    "sheet1-reference": [
        ("Photo: Epping Forest in leaf, (a)'s source", {"zenith": True, "hdri": hdri("epping_forest_01"), **DESK}),
        ("Photo: the bare beech stand, (c)'s wood", {"zenith": True, "hdri": hdri("autumn_forest_04"), **DESK}),
        ("Photo: a beech stand turning (Autumn Forest 01)", {"zenith": True, "hdri": hdri("autumn_forest_01", "4k"), **DESK}),
        ("Photo: conifers and bare broadleaves (Schachen)", {"zenith": True, "hdri": hdri("schachen_forest", "4k"), **DESK}),
    ],
    # 2. Where you lie, in (c), midsummer.
    "sheet2-view": [
        ("A  A ring of crowns round a channel, 90° lens", {**STAND, **SUMMER, **DESK}),
        ("B  Ultra-wide 110°, aspen leaves; beech wood recoloured", {**STAND, **SUMMER, "fov": 110, "palette": "aspen", "bark": "birch", "leafScale": 0.75, "sprays": 6000, **DESK}),
        ("C  Evergreen rim, broadleaves inside", {**STAND, **SUMMER, "hdri": hdri("schachen_forest", "4k"), "sprays": 5000, **DESK}),
        ("D  A forest edge: crowns on one side", {**STAND, **SUMMER, "clearSide": 215, **DESK}),
        ("E  Closed canopy, sky in flecks", {**STAND, **SUMMER, "closed": 1.0, **DESK}),
    ],
    # 3. Softening the day, midsummer, in (c)'s ring.
    "sheet3-light": [
        ("A  A camera's exposure, scaled to the caps", {**STAND, **SUMMER, "camera": True, **DESK}),
        ("B  Leaves glowing, deep zenith-blue gaps", {**STAND, **SUMMER, **DESK}),
        ("C  The same, gaps veiled pale at the leaves", {**STAND, **SUMMER, "veil": 0.5, **DESK}),
        ("D  The Sun behind a crown, its halo", {**STAND, "day": 196, "sunBehind": True, "halo": 0.6, "veil": 0.5, **DESK}),
        ("E  Overcast silver", {**STAND, **SUMMER, "overcast": True, **DESK}),
        ("F  Golden hour", {**STAND, "day": 196, "hour": 18.67, "veil": 0.5, **DESK}),
    ],
    # 4. The recommended look at a desktop's size, under a menu bar and icons.
    "sheet4-desk": [("Recommended: (c), the ring, glowing, veiled gaps, a soft focus; midsummer", {**STAND, **SUMMER, **REC, **DESK})],
    "sheet4-desk-autumn": [("Recommended, late autumn: half down, the rest turned", {**STAND, **LATE, **REC, **DESK})],
    # 5. A film of the recommended look in late autumn, in a breeze (4 m/s), with falling leaves at the real rate.
    "film1-autumn": [("", {**STAND, **LATE, **REC, "wind": 4, "falling": 1, **DESK, **FILM})],
}
