# measure_photos.py <empty folder>: the colours and brightness of the reference photographs in
# docs/beehive/research-look.md ("Measured"), off Wikimedia Commons' 1280 px copies, which it fetches into the
# folder the first time (one request every few seconds: Commons refuses faster scripts). Boxes are fractions of
# each photo, picked by eye over a 10 x 10 grid; inside a box, the parts (cell and wall, cap and gap) are told
# apart by brightness percentiles, not by hand, as docs/ant-colony/measure_photos.py does. Brightness is the
# brightest of R, G and B out of 255, as in docs/canopy/research-look.md. None of the photographs is in the
# repository. Run with python3 -I.
import sys, os, json, time, urllib.request, urllib.parse
import numpy as np
from PIL import Image

P = sys.argv[1]
PHOTOS = {  # key: Commons file
    "glass": "Display Hive, Cumberland House - 55465763241.jpg",
    "museum": "Nature Center and Planetarium in Rock Creek Park 05.JPG",
    "honey": "Honey comb with capped honey.jpg",
    "brood": "Capped worker brood.jpg",
    "pollen": "CSIRO ScienceImage 6628 Honey bee comb showing cells filled with different coloured pollen collected from different plants.jpg",
    "frame": "Italian honeybee brood frame from Langstroth hive.jpg",
    "fresh": "Newly Created Brood Comb with Capped Brood and Larva.JPG",
    "white": "Wax comb made by swarming bees (30933182370).jpg",
    "bee": "Apis mellifera, light body, back, beltsville, md 2017-05-26-15.12 (34886290922).jpg",
    "cc0": "Honey Bees on Comb 1.jpg",
}

def fetch(key):
    path = f"{P}/{key}.jpg"
    if not os.path.exists(path):
        q = urllib.parse.urlencode({"action": "query", "format": "json", "titles": "File:" + PHOTOS[key],
                                    "prop": "imageinfo", "iiprop": "url", "iiurlwidth": 1280})
        get = lambda u: urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "research-script/0.1"}), timeout=60).read()
        info = next(iter(json.loads(get("https://commons.wikimedia.org/w/api.php?" + q))["query"]["pages"].values()))
        open(path, "wb").write(get(info["imageinfo"][0]["thumburl"])); time.sleep(5)
    return np.asarray(Image.open(path).convert("RGB")).astype(float)

def lum(a): return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
def box(a, x0, y0, x1, y1):
    h, w = a.shape[:2]; return a[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)]
def mode(a, p0, p1):  # median colour of the pixels between two luminance percentiles
    L = lum(a).ravel(); c = a.reshape(-1, 3)
    return tuple(int(v) for v in np.median(c[(L >= np.percentile(L, p0)) & (L <= np.percentile(L, p1))], axis=0))
def hexc(c): return "#%02X%02X%02X" % c
def show(label, a, *ranges):
    print(f"  {label:34s}", "  ".join(f"{hexc(mode(a, *r))} {mode(a, *r)}" for r in ranges))
def bright(label, a):
    m = a.max(axis=2)
    print(f"  {label:34s} median {np.median(m):.0f} / 90th {np.percentile(m, 90):.0f} / 99th {np.percentile(m, 99):.0f}"
          f" / 99.9th {np.percentile(m, 99.9):.0f} / max {m.max():.0f}; clipped (>=250) {(m >= 250).mean() * 100:.1f}%")
    for cap in (150, 200):  # scaled in linear light (gamma 2.2) until the 99th percentile is the cap: the median then
        k = (cap / np.percentile(m, 99)) ** 2.2; s = np.minimum(255 * ((m / 255) ** 2.2 * k) ** (1 / 2.2), 255)
        print(f"  {'':34s} 99th to {cap}: x{k:.2f} linear, median {np.median(s):.0f}, 99.9th {np.percentile(s, 99.9):.0f}")

print("Brightness, whole photo or the hive's window")
for key, b in [("glass", (0, 0.27, 1, 1)), ("museum", (0.22, 0.26, 0.72, 0.82)), ("honey", None), ("brood", None),
               ("pollen", None), ("frame", (0.30, 0.04, 0.86, 0.96)), ("fresh", None), ("cc0", None)]:
    a = fetch(key); bright(key + (" (window)" if b else ""), box(a, *b) if b else a)

print("Colours: dark | mid | bright modes as labelled")
a = fetch("glass")
show("glass: comb behind glass  cell|wall", box(a, 0.0, 0.30, 0.45, 0.55), (10, 30), (75, 95))
show("glass: bees on glass  dark|amber", box(a, 0.0, 0.55, 1.0, 1.0), (0, 3), (8, 15))
show("glass: wooden bar", box(a, 0.05, 0.19, 0.95, 0.24), (40, 60))
a = fetch("museum")
show("museum: old comb  cell|wall", box(a, 0.24, 0.52, 0.70, 0.78), (5, 20), (60, 80))
show("museum: bees", box(a, 0.24, 0.27, 0.70, 0.40), (85, 97))
show("museum: frame wood", box(a, 0.17, 0.12, 0.75, 0.22), (40, 60))
a = fetch("honey")
show("honey: caps  shadow|cap|highlight", box(a, 0.03, 0.02, 0.97, 0.28), (3, 15), (40, 60), (95, 99.5))
show("honey: nectar  cell|wall", box(a, 0.0, 0.48, 0.60, 0.85), (10, 40), (85, 97))
a = fetch("brood")
show("brood: capped brood  gap|cap|lit", box(a, 0.18, 0.28, 0.55, 0.55), (1, 8), (40, 60), (92, 99))
show("brood: empty cells  cell|rim", box(a, 0.47, 0.70, 0.72, 0.92), (5, 30), (85, 97))
show("brood: honey cells (top)  cell|rim", box(a, 0.0, 0.0, 0.70, 0.20), (5, 30), (85, 97))
a = fetch("pollen")
show("pollen: old comb  cell|wall|pollen", a, (2, 15), (30, 45), (90, 98))
P_ = a.reshape(-1, 3); sat = P_.max(1) - P_.min(1)
print("  pollen: share of cells' pixels saturated yellow-orange (bee bread)", f"{((P_[:, 0] > 150) & (sat > 90)).mean():.2f}")
a = fetch("frame")
show("frame: honey arch (top right)  cell|cap", box(a, 0.70, 0.07, 0.88, 0.17), (5, 25), (75, 95))
show("frame: capped brood, mid-age comb  cap|lit", box(a, 0.77, 0.30, 0.84, 0.36), (45, 75), (92, 99))
show("frame: wooden frame (side bar)", box(a, 0.265, 0.20, 0.285, 0.80), (40, 60))
a = fetch("fresh")
show("fresh: new comb  cell|wall|wall lit", box(a, 0.60, 0.10, 0.92, 0.95), (5, 30), (60, 80), (95, 99))
show("fresh: new capped brood (top left)", box(a, 0.10, 0.08, 0.40, 0.28), (40, 60))
a = fetch("white")
show("white: swarm comb  shadow|wax", box(a, 0.44, 0.35, 0.58, 0.65), (5, 25), (85, 97))
a = fetch("bee"); m = a.max(axis=2) > 45; b = a[m].reshape(-1, 1, 3)
show("bee (USGS, top-down)  band|amber|hair", b, (3, 15), (45, 65), (95, 99.5))
a = fetch("cc0")
show("cc0: wild comb  cell|wax", box(a, 0.30, 0.20, 0.70, 0.60), (5, 25), (85, 97))

print("Contrast of cell against wall, by state (luminance of the bright mode over the dark one; the trypophobia question)")
for label, key, b, lo, hi in [("capped honey: cap | its shadow", "honey", (0.03, 0.02, 0.97, 0.28), (3, 15), (40, 60)),
                              ("capped brood: cap | gap", "brood", (0.18, 0.28, 0.55, 0.55), (1, 8), (40, 60)),
                              ("nectar: wall | cell", "honey", (0.0, 0.48, 0.60, 0.85), (10, 40), (85, 97)),
                              ("empty, pale comb: rim | cell", "brood", (0.47, 0.70, 0.72, 0.92), (5, 30), (85, 97)),
                              ("new comb, open: wall | cell", "fresh", (0.60, 0.10, 0.92, 0.95), (5, 30), (60, 80)),
                              ("old comb, empty: wall | cell", "museum", (0.24, 0.52, 0.70, 0.78), (5, 20), (60, 80)),
                              ("old comb, pollen: pollen | empty", "pollen", (0, 0, 1, 1), (2, 15), (90, 98))]:
    a = box(fetch(key), *b); d, h = lum(np.array(mode(a, *lo), float)), lum(np.array(mode(a, *hi), float))
    print(f"  {label:34s} {h / max(d, 1):.1f}x")

print("Pollen colours in the CSIRO comb (its brightest fifth of pixels, by hue)")
import colorsys
a = fetch("pollen").reshape(-1, 3); L = lum(a); a = a[L > np.percentile(L, 80)]
hsv = np.array([colorsys.rgb_to_hsv(*(c / 255)) for c in a[::7]]); c7 = a[::7]
for h0, h1, name in [(0, 0.07, "red-brown"), (0.07, 0.11, "orange"), (0.11, 0.15, "yellow"), (0.15, 0.3, "olive-green"), (0.5, 0.95, "grey-violet")]:
    m = (hsv[:, 0] >= h0) & (hsv[:, 0] < h1)
    if m.sum(): c = tuple(int(v) for v in np.median(c7[m], axis=0)); print(f"  {name:12s} {m.mean() * 100:4.1f}% of them  {hexc(c)} {c}")

print("Hard edges: share of pixels more than 24 from the pixel 2 px away, at 1,200 px (Canopy's measure)")
for key in ["glass", "museum", "honey", "brood", "pollen", "fresh", "frame"]:
    im = Image.open(f"{P}/{key}.jpg").convert("RGB"); im.thumbnail((1200, 1200)); m = np.asarray(im).astype(float).max(axis=2)
    e = np.maximum(np.abs(m[:, 2:] - m[:, :-2])[:-2, :], np.abs(m[2:, :] - m[:-2, :])[:, :-2])
    print(f"  {key:10s} {(e > 24).mean() * 100:.0f}%")

# The proposed looks' swatches: a measured colour above, scaled in linear light (gamma 2.2) by k, and for the two
# lamp-lit looks multiplied by a warm lamp (linear 1, 0.78, 0.5: chosen, not measured; dimmed without it, pale wax
# goes olive-khaki, the fault that cut Crystals). The red lamp's ramp is chosen too.
LAMP = (1.0, 0.78, 0.5)
def scale(c, k, lamp=(1, 1, 1)): return tuple(int(round(255 * min(1, (v / 255) ** 2.2 * k * l) ** (1 / 2.2))) for v, l in zip(c, lamp))
WAX, FRESH, NECTAR, GLINT = (248, 229, 173), (200, 180, 72), (116, 85, 48), (252, 251, 247)
HONEYCAP, BROODCAP, PALECAP, WHITECAP = (203, 170, 132), (174, 122, 84), (219, 203, 169), (202, 202, 202)
OLDWALL, WOOD, YELLOW, ORANGE, REDBROWN = (54, 21, 2), (228, 178, 104), (231, 184, 81), (187, 139, 85), (160, 120, 99)
BAND, AMBER, HAIR, ONGLASS = (71, 39, 5), (175, 137, 89), (255, 249, 207), (60, 52, 44)
LOOKS = {
    "Amber (standard)": [("comb wall, lit", WAX, 0.25), ("comb wall, shade", WAX, 0.075), ("cell depth", NECTAR, 0.13),
        ("nectar", NECTAR, 1.00), ("nectar glint", GLINT, 0.50), ("capped honey", HONEYCAP, 0.48), ("capped brood", BROODCAP, 0.56),
        ("pollen yellow", YELLOW, 0.38), ("pollen orange", ORANGE, 0.50), ("pollen red-brown", REDBROWN, 0.44),
        ("frame wood", WOOD, 0.13), ("bee band", BAND, 0.75), ("bee amber", AMBER, 0.50), ("bee hair", HAIR, 0.28)],
    "Old Comb": [("comb wall", OLDWALL, 1.60), ("cell depth", OLDWALL, 0.25), ("nectar", NECTAR, 0.56), ("nectar glint", GLINT, 0.38),
        ("capped honey", HONEYCAP, 0.28), ("capped brood", BROODCAP, 0.31), ("pollen yellow", YELLOW, 0.28),
        ("pollen orange", ORANGE, 0.35), ("frame wood", WOOD, 0.075), ("bee amber", AMBER, 0.38), ("bee band", BAND, 0.62)],
    "New Comb (Light Mode)": [("comb wall, lit", WAX, 0.62), ("comb, new yellow", FRESH, 0.75), ("growing edge, white wax", GLINT, 0.55),
        ("cell depth", FRESH, 0.40), ("nectar", NECTAR, 1.00), ("capped honey", WHITECAP, 0.75), ("capped brood", PALECAP, 0.55),
        ("pollen yellow", YELLOW, 0.60), ("frame wood", WOOD, 0.50), ("bee on the glass", ONGLASS, 1.00), ("bee amber", AMBER, 0.75)],
}
print("Swatches for the proposed looks (measured colour scaled by k in linear light)")
for look, sw in LOOKS.items():
    print(" ", look); lamp = (1, 1, 1) if "Light" in look else LAMP
    for role, c, k in sw: s = scale(c, k, lamp); print(f"    {role:26s} {hexc(s)} {s}  lum {lum(np.array(s, float)):.0f}  ({c} x{k})")
print("  Red Lamp: Amber's luminance put on one ramp from (10,3,2) to (150,40,16); chosen, no photograph measured")
