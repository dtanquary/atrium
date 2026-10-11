"""The train's four more sceneries as geometry, with train.py's lens, rings and hashes, so a build can be matched to
them: mountains (a line along a high valley), snow (a line over a bare plateau), desert and steppe, and a city.

    python3 train_scenery.py [metre] sheet3    # the sheet to pick from: train-sheet3.png, in TRAIN_OUT or here

Each ring is laid as countryside's are (train.ring_strip): the land's height along the line, what covers its face,
what stands in each plot of track, and the lights that show after dark. Only whole-number and four-function
arithmetic goes into a strip (no powers, no exp), so the build's doubles land on the same bytes.
"""
import numpy as np
import train
from train import FOCAL, EYE, PW, PH, CX, I, rnd, noise, fbm, hash2

KINDS = ["mountains", "snow", "desert", "city"]
SALT = {"mountains": 100000, "snow": 200000, "desert": 300000, "city": 400000}
# Lights with nothing drawn under them by day, and what colour each lit thing is after dark (anything else: warm).
LIGHT_ONLY = [I[k] for k in ("lampO", "lampR", "lampT", "lampW")]
LAMPS = {I["glassW"]: (222, 232, 255), I["lampW"]: (222, 232, 255), I["lampO"]: (255, 172, 94), I["lampR"]: (255, 88, 72),
         I["lampT"]: (118, 230, 212)}


# How far off things have faded two thirds of the way to the horizon's colour, km: mountain air is clear, a city's is not.
HAZE = {"country": train.HAZE_KM, "mountains": 60.0, "snow": 40.0, "desert": 45.0, "city": 16.0}


def clip(v):
    return np.clip(v, 0, 1)


# ---- how high the land stands above the track at each ring, in metres
PEAK = {"mountains": {60000: 4800.0, 30000: 4500.0, 15000: 4200.0, 7000: 2600.0, 3500: 450.0, 1800: 130.0, 900: 30.0, 500: 9.0},
        "snow": {60000: 2600.0, 30000: 2400.0, 15000: 2200.0, 7000: 1300.0, 3500: 300.0, 1800: 80.0, 900: 26.0, 500: 9.0},
        "desert": {60000: 2200.0, 30000: 1500.0, 15000: 1100.0, 7000: 600.0, 3500: 90.0, 1800: 30.0, 900: 6.0},
        "city": {}}


def ridged(x, z, layers, salt):
    """Noise folded at its middle, layer on layer, so that it comes to sharp crests; 0 to 1."""
    x, z = np.asarray(x, dtype=np.float64).copy(), np.asarray(z, dtype=np.float64) + np.zeros(np.shape(x))
    total, strength = np.zeros(x.shape), 0.5
    for layer in range(layers):
        total += strength * (1 - np.abs(2 * noise(x, z, salt + layer * 101) - 1))
        strength, x, z = strength / 2, x * 2.03, z * 2.03
    return total / (1 - strength * 2)


def heights(kind, Z, wx, salt):
    top = PEAK[kind].get(Z, 0.0)
    if top == 0:
        return np.zeros(len(wx))
    if kind == "mountains" and Z >= 3500:  # sharp crests, cut by side valleys where the ranges behind show through
        crest = ridged(wx / (Z * 0.5 + 2500.0), Z / 9000.0, 5, salt)
        massif = clip((fbm(wx / (Z * 1.6 + 5000.0), 3.0, 2, salt + 9) - 0.20) * 2.5)
        return top * clip(crest * 1.5 - 0.35) * (0.45 + 0.55 * massif)
    if kind == "desert" and 7000 <= Z <= 30000:  # mesas: flat tops, steep sides, the plain between
        return top * clip((fbm(wx / (Z * 0.7 + 2500.0), Z / 4000.0, 4, salt) - 0.50) * 10)
    if Z >= 15000:  # rounded: fells, a low far range
        return top * clip(fbm(wx / (Z * 0.9), Z / 4000.0, 4, salt) * 1.5 - 0.28)
    return top * clip(fbm(wx / (Z * 1.3) + 3.0, Z / 2000.0, 3, salt + 60) * 1.7 - 0.42)


# ---- stamps of these sceneries' own; the rest are train.py's, some in other materials
def remap(a, pairs):
    """A stamp with some of its materials changed for others."""
    table = np.arange(256, dtype=np.uint8)
    for was, now in pairs:
        table[I[was]] = I[now]
    return table[a]


CHALET = [("brick", "chalet"), ("brickS", "chaletS"), ("roofR", "slate"), ("roofRS", "slateS")]  # dark timber, grey shingles
CABIN = [("white", "falu"), ("whiteS", "faluS"), ("stone", "falu"), ("stoneS", "faluS"), ("brick", "chalet"), ("brickS", "chaletS"),
         ("roofR", "snow"), ("roofRS", "snowS"), ("slate", "snow"), ("slateS", "snowS")]  # red or tarred timber under snow


def snow_fir(h, seed, sun=1):
    """A fir with snow lying on its boughs: on the lit side all but every third row, and its tip."""
    a = train.fir(h, seed, sun)
    rows = np.arange(a.shape[0])[:, None]
    a[(a == I["fir1"]) & (rows % 3 != 2)] = I["snow"]
    a[:2][a[:2] > 0] = I["snow"]
    return a


def bush(h, seed, sun=1):
    """A clump of desert scrub h px tall, about twice as wide: a low mound, lit on top and on the Sun's side."""
    h = max(1, int(h))
    w = max(2, int(round(h * (1.5 + 0.9 * rnd(seed, 1, 5)))))
    a = np.zeros((h, w), dtype=np.uint8)
    cx = (w - 1) / 2
    yy, xx = np.mgrid[0:h, 0:w]
    r2 = ((yy - (h - 1)) / (h + 0.3)) ** 2 + ((xx - cx) / (w / 2 + 0.3)) ** 2
    body = r2 < 0.78 + 0.34 * rnd(xx + seed * 7, yy, 11)
    lit = (xx - cx) * sun / (w / 2) * 0.8 - (yy - (h - 1) / 2) / (h / 2 + 0.5) * 0.8 + (rnd(xx, yy + seed, 13) - 0.5) * 0.6
    a[body] = np.where(lit > 0.1, I["scrub"], I["scrubS"])[body]
    return a


def ger(h, seed, sun=1):
    """A herder's round felt tent h px tall: a low white dome with a door, which glows after dark."""
    h = max(2, int(h))
    w = max(4, int(round(h * 2.1)))
    a = np.zeros((h, w), dtype=np.uint8)
    cx = (w - 1) / 2
    yy, xx = np.mgrid[0:h, 0:w]
    body = ((yy - (h - 1)) / (h + 0.2)) ** 2 + ((xx - cx) / (w / 2 + 0.2)) ** 2 < 1
    a[body] = np.where((xx - cx) * sun > -w / 5, I["white"], I["whiteS"])[body]
    a[h - 1 - (h > 2):, int(cx) + (1 if sun > 0 else 0)] = I["glass"]  # the door, toward the Sun
    return a


def block(w, h, seed, sun, floor, style, light=None):
    """A city building w by h px with a storey every `floor` px: concrete, brick or glass, one end in shade, a
    darker edge to its roof, and windows in rows. Returns it and which of its windows are lit after dark; `light`
    says whether it carries a red light (a tower's) above its roof, which adds a row."""
    wall, wallS, win = [("conc", "concS", "glass"), ("brick", "brickS", "glass"), ("glassT", "glassTS", "glassW")][style]
    w, h = max(1, int(w)), max(2, int(h))
    a = np.full((h, w), I[wall], dtype=np.uint8)
    side = max(1, w // 4) if w >= 4 else 0
    if side:
        a[:, (slice(0, side) if sun > 0 else slice(w - side, w))] = I[wallS]
    a[0, :] = I[wallS]
    pitch = max(2, int(round(floor)))
    tall = 1 if pitch < 4 else 2  # a window's height
    lit = np.zeros((h, w), dtype=bool)
    share = 0.10 + 0.55 * float(rnd(seed, 8, 27)) * float(rnd(seed, 9, 28))  # how much of the building is up
    for y in range(2 if h > 3 else 1, h - tall, pitch):
        for x in (range(1, w - 1, 2) if w >= 3 else range(w)):
            a[y: y + tall, x] = I[win]
            lit[y, x] = rnd(seed + x, y, 55) < share
            if tall == 2:
                lit[y + 1, x] = lit[y, x]
    if light:
        a = np.vstack([np.zeros((1, w), dtype=np.uint8), a])
        lit = np.vstack([np.zeros((1, w), dtype=bool), lit])
        a[0, w // 2], lit[0, w // 2] = I["lampR"], True
    return a, lit


# ---- rings
FIELDS = {"mountains": ["alp", "pasture", "alp", "ley", "alp", "pasture", "stubble", "alp", "ley", "pasture"]}
PLOT = {"mountains": {7000: 700.0, 3500: 420.0, 1800: 260.0, 900: 150.0, 500: 90.0, 300: 60.0, 180: 44.0, 110: 34.0},
        "snow": {7000: 700.0, 3500: 420.0, 1800: 260.0, 900: 150.0, 500: 90.0, 300: 60.0, 180: 44.0, 110: 34.0},
        "desert": {7000: 700.0, 3500: 420.0, 1800: 260.0, 900: 60.0, 500: 40.0, 300: 26.0, 180: 18.0, 110: 13.0},
        "city": {15000: 200.0, 7000: 120.0, 3500: 90.0, 1800: 70.0, 900: 90.0, 500: 70.0, 300: 32.0, 180: 21.0, 110: 18.0}}
TALLEST = {"mountains": 34.0, "snow": 34.0, "desert": 12.0, "city": 0.0}  # what can stand on a ring, m (a city's are below)
TOWER = {15000: 420.0, 7000: 450.0, 3500: 380.0, 1800: 250.0, 900: 95.0, 500: 48.0, 300: 15.0, 180: 10.0, 110: 7.0}


def downtown(pos):
    """Where a city's towers gather, 0 to 1, at a place along the line."""
    return float(clip((fbm(np.array([pos / 5000.0]), np.array([7.0]), 2, 5152)[0] - 0.42) * 5))


def ring_strip(kind, Z, n0, width, sun):
    """Columns n0 … n0+width of the ring Z metres off in one of the four sceneries: material numbers with the ring's
    foot on the bottom row, and a mask of what lights after dark, as train.ring_strip gives for countryside."""
    if kind == "country" or (kind == "city" and Z >= 30000):  # (a city lies in the same country, under the same hills)
        return train.ring_strip(Z, n0, width, sun)
    ppm = FOCAL / Z
    n = np.arange(n0, n0 + width)
    wx = n / ppm
    salt = int(Z) + SALT[kind]
    pad = 4
    hpe = np.round(heights(kind, Z, np.arange(n0 - pad, n0 + width + pad) / ppm, salt) * ppm).astype(int)
    sp = hpe[pad:-pad]
    slope = (hpe[2 * pad:] - hpe[:-2 * pad]) * sun  # above 0 where the land's face is turned to the Sun
    room = max(TOWER[Z], 17.0) if kind == "city" else TALLEST[kind]  # (17 m: a house, a tree or a works by the line)
    H = int(np.ceil(room * ppm)) + 4 + int(sp.max())
    a = np.zeros((H, width), dtype=np.uint8)
    lamps = np.zeros((H, width), dtype=bool)
    yy = np.arange(H)[:, None]
    up = H - 1 - yy
    alt = up / ppm  # metres above the track
    body = up < sp[None, :]
    # (Speckle is drawn two pixels at a time along a row, so that a ring sliding a pixel changes half as much of it.)
    jit = rnd(n[None, :] // 2, up, salt + 6)
    lit = jit >= np.clip(-slope[None, :] / 4.0, 0, 1)  # level ground is lit; a face turned away is in shade, raggedly

    # the land's face
    if kind == "mountains" and Z >= 3500:
        snowline = {60000: 2300.0, 30000: 2100.0, 15000: 1900.0, 7000: 1500.0, 3500: 99999.0}[Z]
        j2 = rnd(n[None, :] // 2, up, salt + 7) - 0.5
        crag = fbm(wx[None, :] / (Z * 0.05 + 300.0), alt / 110.0, 3, salt + 5)  # cliffs, clearings and gullies
        forest = alt < 1050.0 + j2 * 160 + (crag - 0.5) * 500
        meadow = alt < 1400.0 + j2 * 200 + (crag - 0.5) * 300
        snowy = alt > snowline + j2 * 260 - (crag - 0.5) * 700
        sunny = j2 + 0.5 < np.clip(0.30 + slope[None, :] * 0.06, 0, 1)  # the firs' lit tops, more of them toward the Sun
        m = np.where(snowy, np.where(crag > 0.70, I["rockS"], np.where(lit, I["snow"], I["snowS"])),
                     np.where(forest, np.where(crag > 0.70, I["alp"], np.where(sunny, I["fir1"], I["fir0"])),
                              np.where(meadow, I["alp"], np.where(lit, I["rock"], I["rockS"]))))
        a[body] = m[body]
    elif kind == "mountains":  # the valley's floor: meadows in strips, patches of fir
        if sp.max() > 0:
            flen = {1800: 300.0, 900: 250.0, 500: 230.0}[Z]
            band = np.floor(up / np.maximum(2.0, sp[None, :] / 3.0 + 0.5)).astype(int)
            fid = np.floor(wx[None, :] / flen + band * 0.37)
            fields = np.array([I[f] for f in FIELDS[kind]])[(rnd(fid, band, salt + 61) * len(FIELDS[kind])).astype(int)]
            a[body] = np.where(fbm(wx[None, :] / (Z * 0.2), up / 3.0, 3, salt + 62) > 0.63, I["fir0"], fields)[body]
    elif kind == "snow":
        crust = fbm(wx[None, :] / (Z * 0.2 + 150.0), alt / (Z * 0.012 + 6.0), 3, salt + 62)  # where the wind has bared it
        # A far fell is white only where it is turned to the Sun; the rest of it lies in blue shadow, which is what
        # shows it against a pale sky.
        sunlit = slope[None, :] >= 2 if Z >= 7000 else lit
        m = np.where(crust > 0.64, I["rockS"], np.where((crust < 0.31) & (Z <= 3500), I["birch"], np.where(sunlit, I["snow"], I["snowS"])))
        a[body] = m[body]
    elif kind == "desert":
        if Z >= 60000:
            a[body] = np.where(lit, I["rock"], I["rockS"])[body]
        elif Z >= 7000:  # a mesa: banded rock over a skirt of scree
            layer = np.floor(alt / {30000: 230.0, 15000: 120.0, 7000: 70.0}[Z]).astype(int)
            m = np.where(up * 10 < sp[None, :] * 3, np.where(lit, I["sand"], I["sandS"]),
                         np.where(~lit, I["mesaS"], np.where(layer % 2 == 0, I["mesa"], I["mesa2"])))
            a[body] = m[body]
        else:  # dunes and low rises, with a little scrub
            a[body] = np.where(rnd(n[None, :], up, salt + 63) < 0.06, I["scrub"], np.where(lit, I["sand"], I["sandS"]))[body]

    # woods along the land's top
    wooded = fbm(wx / 900.0, Z / 300.0, 3, salt + 1)
    if kind in ("mountains", "snow") and 500 <= Z <= 1800:
        most = 9.0 if kind == "mountains" else 14.0  # (a plateau is bare but for its sheltered hollows)
        th = np.round((10 + 14 * fbm(wx / 60.0, 1.0, 3, salt + 2)) * ppm * clip((wooded - 0.50 - (kind == "snow") * 0.08) * most)).astype(int)
        fringe = (up >= sp[None, :]) & (up < (sp + th)[None, :])
        dark = rnd(n[None, :] // 2, up, salt + 3) >= 0.35 if kind == "mountains" else up < (sp + th)[None, :] - 1  # (or under snow)
        a[fringe] = np.where(dark, I["fir0"], I["fir1"] if kind == "mountains" else I["snow"])[fringe]

    # what stands in each plot of track
    cell = PLOT[kind].get(Z)
    c0, c1 = (int(np.floor(wx[0] / cell)) - 2, int(np.floor(wx[-1] / cell)) + 2) if cell else (0, -1)
    for c in range(c0, c1 + 1):
        r = float(rnd(c, 1, salt + 30))
        pos = (c + float(rnd(c, 2, salt + 31))) * cell
        village = float(noise(np.array([pos / 1400.0]), np.array([2.0]), 4242)[0])  # the same villages on every ring
        woods_here = float(fbm(np.array([pos / 900.0]), np.array([Z / 300.0]), 3, salt + 1)[0])
        seed = int(hash2(c, 3, salt + 32) % np.uint64(1 << 30))
        size = float(rnd(c, 4, salt + 33))
        st, glow = None, None
        if kind == "mountains":
            if Z > 1800:
                continue
            if Z == 900 and village > 0.70 and r < 0.2:
                st = train.spire(30 * ppm, seed, sun)
            elif village > 0.64 and Z >= 300 and r < {1800: 0.8, 900: 0.75, 500: 0.7, 300: 0.5}[Z]:
                st = remap(train.house(max(2, 5.0 * ppm), seed, sun), CHALET)
            elif Z <= 500 and r < {500: 0.07, 300: 0.09, 180: 0.07, 110: 0.0}[Z]:
                st = remap(train.house(max(2, 5.5 * ppm), seed, sun), CHALET)  # a farm, or a hay barn, on its own
            elif r > 1 - np.clip(0.16 + (woods_here - 0.45) * 2.2, 0.07, 0.7) and Z <= 900:
                st = train.tree((8 + 7 * size) * ppm, seed, sun) if rnd(c, 5, salt + 34) < 0.25 else train.fir((13 + 13 * size) * ppm, seed, sun)
        elif kind == "snow":
            if Z > 1800:
                continue
            if village > 0.66 and Z >= 300 and r < {1800: 0.6, 900: 0.6, 500: 0.55, 300: 0.4}[Z]:
                st = remap(train.house(max(2, 4.5 * ppm), seed, sun), CABIN)  # cabins, a few together
            elif Z <= 500 and r < {500: 0.05, 300: 0.06, 180: 0.05, 110: 0.0}[Z]:
                st = remap(train.house(max(2, 4.5 * ppm), seed, sun), CABIN)
            elif r > 1 - np.clip(0.03 + (woods_here - 0.52) * 2.6, 0.02, 0.6) and Z <= 900:
                st = snow_fir((10 + 10 * size) * ppm, seed, sun)
        elif kind == "desert":
            if Z > 900:
                continue
            if village > 0.69 and 180 <= Z <= 500 and r < 0.5:
                st = ger(3.2 * ppm, seed, sun)  # a camp of them
            elif r > 1 - {900: 0.35, 500: 0.42, 300: 0.46, 180: 0.5, 110: 0.5}[Z] * (0.5 + woods_here):
                st = bush((1.2 + 2.2 * size * size) * ppm, seed, sun)
        else:  # a city: towers far off where its centre is, slabs and blocks nearer, houses and yards by the line
            centre, high = downtown(pos), TOWER[Z] * (0.30 + 0.70 * size * size)
            low = 0.6 if Z == 110 else 1.0  # by the line stand only low things, sheds and garden trees: the city's lights show over them
            style = int(rnd(c, 5, salt + 34) * 3)
            if Z >= 3500:
                if r < 0.10 + 0.80 * centre:
                    st, glow = block((26 + 30 * rnd(c, 6, salt + 35)) * ppm, high * (0.45 + 0.55 * centre) * ppm, seed, sun, 2, 0 if style == 1 else style,
                                     light=high * (0.45 + 0.55 * centre) > 120)
            elif Z >= 500:
                if r < 0.78:  # slabs and blocks of every size, with sky between them
                    tall = high * (0.55 + 0.45 * centre)
                    st, glow = block(cell * (0.40 + 0.75 * rnd(c, 6, salt + 35)) * ppm, tall * ppm, seed, sun, 3.2 * ppm, style, light=tall > 90)
            elif r < 0.40:
                st = train.house(max(2, (5.0 + 2.5 * size) * low * ppm), seed, sun)
            elif r < 0.64:
                st, glow = block(cell * (0.7 + 0.6 * rnd(c, 6, salt + 35)) * ppm, max(3, (4.5 + high * 0.8) * low * ppm), seed, sun, 3.2 * ppm, style % 2)
            elif r < 0.80:
                st = train.tree((7 + 7 * size) * low * ppm, seed, sun)
            if Z < 180:
                glow = np.zeros_like(st, dtype=bool) if st is not None else None  # (too fast to carry lights at 1×)
        if st is None:
            continue
        if glow is None:
            glow = (st == I["glass"]) & (rnd(seed + np.arange(st.shape[1])[None, :], np.arange(st.shape[0])[:, None], 55) < 0.8)
            if Z < 180:
                glow[:] = False
        x = int(round(pos * ppm)) - n0 - st.shape[1] // 2
        h = st.shape[0]
        for sx in range(st.shape[1]):
            if 0 <= x + sx < width:
                lift = int(sp[x + sx] * (0.35 + 0.65 * float(rnd(c, 6, salt + 35)))) if kind != "city" else 0
                top = H - h - lift
                if top < 0:
                    continue
                colm = st[:, sx]
                a[top: top + h, x + sx] = np.where(colm > 0, colm, a[top: top + h, x + sx])
                lamps[top: top + h, x + sx] = np.where(colm > 0, glow[:, sx], lamps[top: top + h, x + sx])

    # a line of poles 300 m out: beside a lane, a winter road or a desert track; in a city, street lamps on theirs
    if Z == 300 and kind != "city":
        lane = fbm(wx / 2400.0, 5.0, 2, 808 + SALT[kind]) > 0.50
        pole = (np.round(wx / 42.0) * 42.0 * ppm).round().astype(int) == n
        sel = lane & pole
        a[H - 7:, sel] = np.where(a[H - 7:, sel] == 0, I["pole"], a[H - 7:, sel])
    if kind == "city" and Z in (180, 300, 500, 900):
        gap = {900: 70.0, 500: 55.0, 300: 45.0, 180: 40.0}[Z]
        post = np.nonzero((np.round(wx / gap) * gap * ppm).round().astype(int) == n)[0]
        tall = int(round(8.5 * ppm))
        for x in post:
            if a[H - 1 - tall, x] == 0:  # (one behind a building doesn't show)
                if Z <= 300:
                    a[H - tall:, x] = np.where(a[H - tall:, x] == 0, I["pole"], a[H - tall:, x])
                a[H - 1 - tall, x], lamps[H - 1 - tall, x] = I["lampO"], True

    # lights that show only after dark
    if kind == "city":
        if Z >= 1800:  # the far city's streets and windows, seen edge-on: a seam of lights along its foot
            dense = clip((fbm(wx / 9000.0, 3.0, 2, 5151) - 0.25) * 3.5)
            for row, share in ((0, 0.42), (1, 0.20), (2, 0.07)):
                on = np.nonzero((rnd(n, row, salt + 65) < share * dense) & (a[H - 1 - row] == 0))[0]
                tint = rnd(n[on], row, salt + 66)
                a[H - 1 - row, on] = np.where(tint < 0.45, I["lampO"], np.where(tint < 0.62, I["lampW"], np.where(tint < 0.66, I["lampT"], np.where(tint < 0.69, I["lampR"], 0))))
                lamps[H - 1 - row, on] = True
        return a, lamps
    far, near, reach = {"mountains": (1.0, 0.3, 620.0), "snow": (0.7, 0.2, 1e9), "desert": (0.45, 0.14, 1e9)}[kind]
    if Z >= 1800 and Z <= 7000:
        hamlet = clip((noise(wx / 420.0, 6.0, salt + 64) - 0.5) * 4)
        on = np.nonzero(rnd(n, 1, salt + 65) < 0.06 * far * hamlet)[0]
        lamps[H - 1 - (np.minimum(sp[on], int(reach * ppm)) * rnd(n[on], 2, salt + 66)).astype(int), on] = True  # low on the land's face
    elif 180 <= Z <= 900:
        for c in range(c0, c1 + 1):
            x = int(round((c + float(rnd(c, 8, salt + 37))) * cell * ppm)) - n0
            if rnd(c, 7, salt + 36) < near and 0 <= x < width:
                at = int(sp[x]) + int(round((4.0 + 3.0 * float(rnd(c, 9, salt + 38))) * ppm))
                if at < H:
                    lamps[H - 1 - at, x] = True
    return a, lamps


# ---- the ground: what each scenery's rows are made of. `lines` are level lines, which stay still as we go: the rows
# just beyond `LANE_M`, far to near. `far` and `near` are the near field's two crops beyond the lane and this side of it.
GROUND = {
    "mountains": dict(fields=FIELDS["mountains"], hedge="hedge", lines=("rock", "river", "river"), far=("alp", "pasture"), near=("pasture", "alp"), verge="verge"),
    "snow": dict(fields=["snow", "snow", "snowS", "snow", "ice", "snow", "snowS", "snow", "snow", "ice"], hedge=None,
                 lines=("snowS", "snowS", "road"), far=("snow", "snowS"), near=("snow", "snow"), verge="snowS", rails=(38.0,), rail="birch"),  # a snow fence, 38 m off
    "desert": dict(fields=["steppe", "sand", "steppe", "steppe1", "sand", "steppe", "steppe1", "steppe", "sandS", "steppe"], hedge=None,
                   lines=("scrubS", "scrub", "track"), far=("steppe", "sand"), near=("steppe", "steppe1"), verge="sandS"),
    "city": dict(fields=["tar", "concS", "tar", "slate", "tar", "brickS", "tar", "concS", "slateS", "tar"], hedge=None,
                 lines=("brickS", "brick", "tar"), far=("tar", "ballast"), near=("ballast", "ballast"), verge="ballast",
                 rails=(19.0, 20.435, 33.0, 34.435)),  # the next lines' rails, metres off
}


def ground(hy, X, speed, kind, eye=EYE):
    """A scenery's rows under the horizon, as train.ground gives countryside's: material numbers and a lightness."""
    if kind == "country":
        return train.ground(hy, X, speed)
    EYE = eye
    g = GROUND[kind]
    rows = PH - hy
    a = np.zeros((rows, PW), dtype=np.uint8)
    lift = np.zeros((rows, PW))
    cols = np.arange(PW)
    lane_d = int(round(EYE * FOCAL / train.LANE_M))
    rails = [int(round(EYE * FOCAL / m)) for m in g.get("rails", ())]
    for d in range(1, rows + 1):
        Z = EYE * FOCAL / d
        ppm = d / EYE
        n = np.floor(X * ppm) + cols - CX
        wx = n / ppm
        if Z > 100:
            belt = 0 if d <= 1 else 1 if d <= 2 else 2 if d <= 4 else 3
            u = wx / (230.0 + 60 * belt) + belt * 0.37
            pick = (rnd(np.floor(u), belt, 4100 + SALT[kind]) * len(g["fields"])).astype(int)
            a[d - 1] = np.array([I[g["fields"][p]] for p in pick])
            if g["hedge"]:
                edge = np.abs(u - np.round(u)) * (230.0 + 60 * belt) < max(1.5, 1.2 / ppm)
                a[d - 1][edge & (rnd(np.floor(u), belt, 4101 + SALT[kind]) < 0.6)] = I[g["hedge"]]
            continue
        if lane_d - 2 <= d <= lane_d:
            a[d - 1] = I[g["lines"][d - lane_d + 2]]
        elif d in rails:
            a[d - 1] = I[g.get("rail", "rail")]
        elif Z > train.LANE_M:
            a[d - 1] = np.where(fbm(wx / 1500.0, 0.5, 2, 4200 + SALT[kind]) > 0.5, I[g["far"][0]], I[g["far"][1]])
        elif Z > train.VERGE_M:
            a[d - 1] = np.where(fbm(wx / 1900.0, 1.5, 2, 4201 + SALT[kind]) > 0.5, I[g["near"][0]], I[g["near"][1]])
        else:
            a[d - 1] = I[g["verge"]]
        L = max(10.0, 2.2 * speed * ppm / 30.0)
        s = fbm(n / L, d / 3.0, 2, 4300)
        lift[d - 1] = (np.floor(s * 5) - 2) * (0.03 if Z > train.VERGE_M else 0.045) + ((d // 3) % 2) * 0.022
    return a, lift


# ---- the view
def view(kind, time="day", X=52000.0, speed=13.3, horizon_up=0.30, cover=0.30, cloud_seed=9, poles=False, t=0.0, water=False, eye=EYE):
    """The whole view through the pane in one of the sceneries, PH × PW × 3, as train.view gives countryside's.
    At sunset the lamps are half on, each at its own draw. `water` lays a lake beside the line, as Changing can."""
    hy = round(PH * (1 - horizon_up))
    b = train.base(time)
    out = train.sky(time, hy, X, cover, cloud_seed)
    horizon_rgb = np.median(b[84:90, train.PX0:train.PX0 + PW].reshape(-1, 3), axis=0)
    dark = time in ("night", "dusk", "sunset")
    if water:
        out[hy:] = train.water(out, hy, time, t)
    else:
        gm, lift = ground(hy, X, speed, kind, eye)
        out[hy:] = train.shade(gm, time, lift=lift)
    lit = []
    for Z in train.RINGS:
        if water and Z < 1800:
            continue
        ppm = FOCAL / Z
        n0 = int(np.floor(X * ppm)) - CX
        strip, lamps = ring_strip(kind, Z, n0, PW, 1)
        if time == "sunset":
            lamps = lamps & (rnd(n0 + np.arange(PW)[None, :], np.arange(strip.shape[0])[::-1, None], 70) < 0.5)
        foot = min(PH, hy + int(round(eye * ppm)))
        H = strip.shape[0]
        y0 = foot - H
        rgb = train.shade(strip, time, Z=Z * train.HAZE_KM / HAZE[kind], horizon_rgb=horizon_rgb)
        m = (strip > 0) & ~np.isin(strip, LIGHT_ONLY)
        if dark:
            glow = np.full(strip.shape + (3,), (255.0, 204.0, 128.0) if time == "night" else (255.0, 214.0, 150.0))
            for mat, colour in LAMPS.items():
                glow[strip == mat] = colour
            rgb[lamps] = glow[lamps]
            m = m | lamps
        ys = slice(max(0, y0), foot)
        sub = slice(max(0, -y0), H)
        region = out[ys]
        region[m[sub]] = rgb[sub][m[sub]]
        out[ys] = region
        if dark:
            yy, xx = np.nonzero(lamps[sub])
            lit += [(int(y) + max(0, y0), int(x), rgb[sub][y, x]) for y, x in zip(yy, xx)]
    if water:  # each lamp on the far shore leaves a broken streak of its own colour in the water
        for y, x, colour in lit:
            for k in range(1, 14):
                if hy + k < PH and rnd(x, k + int(t * 2) * 31, 71) < 0.5 - k * 0.055:
                    out[hy + k, x] = out[hy + k, x] * 0.45 + colour * 0.55 * (1 - k / 16)
    if poles and kind != "city":
        out = train.pole_line(out, hy, X, time)
    return np.clip(out, 0, 255)


def compose(kind, time="day", X=52000.0, **kw):
    """One finished frame of the canvas in the plain window, CH × CW × 3 uint8."""
    cab = train.carriage(time, "plain")
    out = np.zeros((train.CH, train.CW, 3))
    out[train.PY0: train.PY0 + PH, train.PX0: train.PX0 + PW] = view(kind, time, X, **kw)
    al = cab[..., 3:4] / 255.0
    return np.clip(out * (1 - al) + cab[..., :3] * al, 0, 255).astype(np.uint8)


TILES = [("mountains", "H  Mountains: a line along a high valley"), ("snow", "I  Snow: a line over a bare plateau"),
         ("desert", "J  Desert and steppe"), ("city", "K  A city")]

if __name__ == "__main__":
    import sys
    X = float(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1][0].isdigit() else 52000.0
    tiles = []
    for kind, label in TILES:
        for time, when in (("day", "by day"), ("sunset", "at dusk"), ("night", "at night")):
            tiles.append((f"{label}, {when}", compose(kind, time, X, poles=True)))
    tiles += [("L  The city from a viaduct, the eye 12.5 m up (not what the build can do yet)", compose("city", "night", X, eye=12.5)),
              ("L  The same by day", compose("city", "day", X, eye=12.5)),
              ("M  A city where a lake lies beside the line (as Changing brings)", compose("city", "night", X, water=True))]
    train.sheet("train-sheet3", tiles)
