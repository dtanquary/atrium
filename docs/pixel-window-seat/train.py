"""Mock-up painter for a train view in Pixel Window Seat, written as geometry so a build can be matched to it.

The lens is the airliner's (Large pane 340 × 221 on the 378 × 246 canvas, focal 265 px, looking square out of the
side). A thing Z metres from the track stands focal / Z px per metre and slides focal × speed / Z px a second.
The picture is rings of standing things at fixed distances, each sliding by whole pixels, over ground rows.
The sky's colours, Sun, Moon and stars are the app's own, from renders of Pixel Window Seat.
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get("TRAIN_OUT", ".")
CW, CH = 378, 246
PW, PH = 340, 221
PX0, PY0 = 19, 12
FOCAL = 265.0
EYE = 3.5
CX = PW // 2


# ---- the airliner's hash and noise (PixelWindowSeat.swift), so placements can be ported exactly
def hash2(x, z, salt):
    x = np.asarray(x, dtype=np.int64).astype(np.uint64)
    z = np.asarray(z, dtype=np.int64).astype(np.uint64)
    with np.errstate(over="ignore"):
        v = x * np.uint64(0x9E3779B97F4A7C15) ^ z * np.uint64(0xC2B2AE3D27D4EB4F) ^ np.uint64((salt * 0x165667B19E3779F9) & (2 ** 64 - 1))
        v = (v ^ (v >> np.uint64(31))) * np.uint64(0xBF58476D1CE4E5B9)
        v = (v ^ (v >> np.uint64(29))) * np.uint64(0x94D049BB133111EB)
        return v ^ (v >> np.uint64(32))


def unit(v):
    return (v >> np.uint64(40)).astype(np.float64) / 16777216.0


def rnd(x, z, salt):
    return unit(hash2(x, z, salt))


def noise(x, z, salt):
    x, z = np.broadcast_arrays(np.asarray(x, dtype=np.float64), np.asarray(z, dtype=np.float64))
    fx, fz = np.floor(x), np.floor(z)
    ix, iz = fx.astype(np.int64), fz.astype(np.int64)
    u, v = x - fx, z - fz
    u, v = u * u * (3 - 2 * u), v * v * (3 - 2 * v)
    a, b = rnd(ix, iz, salt), rnd(ix + 1, iz, salt)
    c, d = rnd(ix, iz + 1, salt), rnd(ix + 1, iz + 1, salt)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def fbm(x, z, layers, salt):
    x, z = np.broadcast_arrays(np.asarray(x, dtype=np.float64), np.asarray(z, dtype=np.float64))
    x, z = x.copy(), z.copy()
    total, strength = np.zeros(x.shape), 0.5
    for layer in range(layers):
        total += strength * noise(x, z, salt + layer * 101)
        strength, x, z = strength / 2, x * 2.03, z * 2.03
    return total / (1 - strength * 2)


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32


# ---- materials (daylight colours)
M = {
    "leaf0": (40, 78, 50), "leaf1": (60, 106, 58), "leaf2": (94, 138, 68), "trunk": (64, 52, 46),
    "fir0": (32, 64, 54), "fir1": (48, 88, 66),
    "white": (228, 222, 206), "whiteS": (176, 176, 178), "brick": (164, 100, 80), "brickS": (120, 74, 66),
    "stone": (176, 166, 150), "stoneS": (130, 124, 118),
    "roofR": (150, 72, 58), "roofRS": (112, 56, 52), "slate": (88, 92, 108), "slateS": (64, 68, 84),
    "glass": (58, 66, 88), "door": (70, 52, 44), "hedge": (50, 90, 48), "hedge1": (70, 112, 56),
    "road": (128, 126, 126), "pole": (58, 50, 46),
    "wheat": (208, 190, 116), "pasture": (118, 164, 88), "crop": (90, 144, 76), "fallow": (152, 124, 94),
    "rape": (214, 200, 96), "ley": (150, 180, 108), "stubble": (190, 170, 124),
    "verge": (86, 128, 70), "ballast": (120, 112, 104),
}
NAMES = list(M)
COL = np.array([M[n] for n in NAMES], dtype=np.float64)
I = {n: k + 1 for k, n in enumerate(NAMES)}  # 0 is empty


# ---- stamps: small drawn things, as arrays of material numbers (0 = see through), feet on the bottom row
def tree(h, seed, sun=1):
    """A broadleaf tree h px tall. sun is +1 when lit from the right."""
    h = max(3, int(h))
    w = max(3, int(round(h * (0.62 + 0.22 * rnd(seed, 1, 5)))))
    a = np.zeros((h, w), dtype=np.uint8)
    trunk = max(1, int(round(h * 0.24)))
    ch = h - trunk
    cy, cx = (ch - 1) / 2, (w - 1) / 2
    yy, xx = np.mgrid[0:ch, 0:w]
    ragged = 0.80 + 0.36 * rnd(xx + seed * 7, yy, 11)
    r2 = ((yy - cy) / (ch / 2 + 0.3)) ** 2 + ((xx - cx) / (w / 2 + 0.3)) ** 2
    crown = r2 < ragged
    lit = ((xx - cx) * sun / (w / 2) * 0.7 - (yy - cy) / (ch / 2) * 0.9 + (rnd(xx, yy + seed, 13) - 0.5) * 0.7)
    tone = np.where(lit > 0.55, I["leaf2"], np.where(lit > -0.35, I["leaf1"], I["leaf0"]))
    a[:ch][crown] = tone[crown]
    tw = 1 if h < 20 else 2
    a[ch - 1:, int(cx) - (tw - 1) // 2: int(cx) - (tw - 1) // 2 + tw] = I["trunk"]
    return a


def fir(h, seed, sun=1):
    h = max(4, int(h))
    w = max(3, int(round(h * 0.42)) | 1)
    a = np.zeros((h, w), dtype=np.uint8)
    cx = w // 2
    for y in range(h - 1):
        half = int(round((y + 1) / (h - 1) * (w / 2) * (0.75 + 0.25 * ((y % 3) / 2))))
        for x in range(cx - half, cx + half + 1):
            if 0 <= x < w:
                a[y, x] = I["fir1"] if (x - cx) * sun > 0 else I["fir0"]
    a[h - 1, cx] = I["trunk"]
    return a


def house(hpx, seed, sun=1, kind=None):
    """A house whose eaves are hpx px up: a wall with windows under a pitched roof."""
    kind = kind if kind is not None else int(rnd(seed, 2, 21) * 3)
    wall, wallS = [("white", "whiteS"), ("brick", "brickS"), ("stone", "stoneS")][kind]
    roof, roofS = ("roofR", "roofRS") if rnd(seed, 3, 22) < 0.55 else ("slate", "slateS")
    hw = max(2, int(hpx))
    w = max(4, int(round(hw * (1.5 + 0.9 * rnd(seed, 4, 23)))))
    rh = max(2, int(round(hw * 0.7)))
    a = np.zeros((hw + rh, w), dtype=np.uint8)
    a[rh:, :] = I[wall]
    shade = slice(0, max(1, w // 4)) if sun > 0 else slice(w - max(1, w // 4), w)
    a[rh:, shade] = I[wallS]
    for y in range(rh):
        inset = int(round((rh - 1 - y) * 0.9)) if rnd(seed, 5, 24) < 0.5 else 0  # a hipped roof, or a plain gable end on
        a[y, inset: w - inset] = I[roof] if y > 0 else I[roofS]
    if hw >= 4:
        for x in range(1 + (w // 4 if sun > 0 else 0), w - 1, max(2, hw // 2 + 1)):
            a[rh + hw // 3: rh + hw // 3 + max(1, hw // 4), x] = I["glass"]
    elif hw >= 2:
        a[rh + hw // 2 - (hw > 2), w // 2 + (1 if sun > 0 else -1)] = I["glass"]
    if rnd(seed, 6, 25) < 0.6 and w > 5:
        a[max(0, rh // 3 - 1): rh // 2 + 1, w - 2 if rnd(seed, 7, 26) < 0.5 else 1] = I["brickS"]  # a chimney
    return a


def spire(hpx, seed, sun=1):
    """A village church: a nave with a tower and a spire hpx px tall in all."""
    hpx = max(6, int(hpx))
    nave_h, nave_w = max(2, hpx // 3), max(4, int(hpx * 0.9))
    tw = max(2, hpx // 5)
    a = np.zeros((hpx, nave_w + tw), dtype=np.uint8)
    a[hpx - nave_h:, tw:] = I["stone"]
    a[hpx - nave_h - max(1, nave_h // 2): hpx - nave_h, tw:] = I["slate"]
    a[hpx - int(hpx * 0.62):, :tw] = I["stoneS"] if sun > 0 else I["stone"]
    top = hpx - int(hpx * 0.62)
    for y in range(top):
        if tw == 2 and y < top // 2:
            a[y, 0 if sun < 0 else 1] = I["slateS"]
        else:
            a[y, :tw] = I["slateS"]
    return a


# ---- the picture's light, per time of day
TIMES = {"day": "13", "sunset": "18.6", "dusk": "19.6", "night": "23"}
_base = {}


def base(time, scenery="3"):
    k = (time, scenery)
    if k not in _base:
        _base[k] = np.asarray(Image.open(f"{HERE}/train-base/h{TIMES[time]}.png").convert("RGB")).astype(np.float64)
    return _base[k]


def light(time):
    """How this hour dims and tints a daylight colour: the ratio of the airliner's own ground at that hour to noon's."""
    if time == "day":
        return np.ones(3), np.zeros(3)
    day, now = base("day")[120:240].reshape(-1, 3), base(time)[120:240].reshape(-1, 3)
    keep = now.sum(1) < np.percentile(now.sum(1), 90)  # leave the lamps out
    tint = now[keep].mean(0) / day[keep].mean(0) * {"sunset": 1.0, "dusk": 1.35, "night": 2.1}[time]
    floor = {"sunset": (10, 6, 10), "dusk": (8, 8, 18), "night": (9, 13, 27)}[time]
    return tint, np.array(floor, dtype=np.float64)


def sky(time, horizon_y, X=0.0, cover=0.34, cloud_seed=3):
    """The pane's sky down to the horizon row: the app's own bands, Sun, Moon and stars, with cloud seen from below."""
    b = base(time)
    out = np.zeros((PH, PW, 3))
    rows = horizon_y  # pane rows above the horizon
    have = 91
    src = b[:have, PX0:PX0 + PW]
    n = min(rows, have)
    out[rows - n: rows] = src[have - n:]
    if rows > have:  # higher than the airliner's pane looks: carry its top band on up
        top = np.median(src[0:4].reshape(-1, 3), axis=0)
        grad = (np.median(src[0:6].reshape(-1, 3), axis=0) - np.median(src[20:26].reshape(-1, 3), axis=0)) / 20
        for j in range(rows - have):
            out[rows - have - 1 - j] = np.clip(top + grad * (j + 1) * 0.8, 0, 255)
        if time in ("night", "dusk"):  # and its stars at the same density
            bright = src.sum(-1) > np.median(src.sum(-1)) + 90
            dens = bright.mean()
            ys, xs = np.mgrid[0:rows - have, 0:PW]
            star = rnd(xs, ys, 77) < dens
            cols = src[bright]
            pick = (rnd(xs, ys, 78) * len(cols)).astype(int)
            out[:rows - have][star] = cols[pick[star]]
    # cloud: a layer 1.2 km up, each row above the horizon one distance
    if cover > 0:
        j = (rows - np.arange(rows))[:, None].astype(np.float64)  # rows above the horizon, 1 at the bottom
        dist = 1200.0 * FOCAL / j
        cols = np.arange(PW)[None, :]
        n_x = np.floor(X * j / 1200.0) + cols - CX  # slides by whole pixels
        wx = n_x * 1200.0 / j
        f = fbm(wx / 2600.0 + 40, dist / 2600.0, 4, 900 + cloud_seed)
        thick = np.clip((f - (1 - cover) * 0.74) / 0.16, 0, 1)
        thick *= np.clip((j - 2) / 10, 0, 1)  # none on the horizon itself, where hills stand
        ctone = {"day": [(168, 184, 212), (206, 218, 236), (244, 247, 252)],
                 "sunset": [(120, 92, 122), (206, 128, 112), (252, 186, 132)],
                 "dusk": [(58, 54, 88), (86, 74, 110), (128, 100, 128)],
                 "night": [(20, 22, 38), (28, 30, 50), (40, 42, 66)]}[time]
        ctone = np.array(ctone, dtype=np.float64)
        d = BAYER[np.arange(rows)[:, None] % 4, cols % 4]
        level = np.clip(thick * 2.6 + (d - 0.5) * 0.5, 0, 2.999)
        shade = ctone[level.astype(int)]
        # lit from above by day: the thin edges are the brightest; from below at sunset: the same table reversed
        mask = thick > 0.02 + d * 0.10
        sk = out[:rows]
        sk[mask] = shade[mask]
        out[:rows] = sk
    return out


# ---- rings: each is filled a column at a time from hashes of the place.
RINGS = [60000, 30000, 15000, 7000, 3500, 1800, 900, 500, 300, 180, 110]
RISE = {7000: 520.0, 3500: 230.0, 1800: 90.0, 900: 34.0, 500: 12.0}  # how high the land can swell at each ring, m
HAZE_KM = 26.0
FIELD = ["wheat", "pasture", "crop", "fallow", "ley", "pasture", "stubble", "crop", "rape", "ley"]


def ring_strip(Z, n0, width, sun):
    """Columns n0 … n0+width of the ring Z metres off: material numbers, with the ring's foot on the bottom row,
    and a mask of lamps (windows that light at night).

    A pixel's own speckle goes by its height above the foot (`up`). On the sheets Dave picked from it went by the
    row counted from the strip's top (`yy`), and the strip is as tall as the tallest thing in view, so a hill's
    speckle would have reshuffled whenever a taller one slid in. The shapes are the same."""
    ppm = FOCAL / Z
    n = np.arange(n0, n0 + width)
    wx = n / ppm  # metres along the track
    salt = int(Z)
    if Z >= 15000:  # a height line: far hills and ranges
        if Z >= 30000:
            ridge = 1 - np.abs(2 * fbm(wx / 26000.0, Z / 9000.0, 5, salt) - 1)
            hm = 2600.0 * ridge ** 2 * np.clip((fbm(wx / 90000.0, 3.0, 2, salt + 9) - 0.42) * 5, 0, 1)
        else:
            hm = 950.0 * np.clip(fbm(wx / (Z * 0.9), Z / 4000.0, 4, salt) * 1.5 - 0.28, 0, 1)
        hp = np.round(hm * ppm).astype(int)
        H = max(2, hp.max() + 1)
        a = np.zeros((H, width), dtype=np.uint8)
        yy = np.arange(H)[:, None]
        up = H - 1 - yy  # px above the foot
        body = up < hp[None, :]
        wood = fbm(wx / (Z * 0.12), 7.0, 3, salt + 5)[None, :] + (rnd(n[None, :], up, salt + 6) - 0.5) * 0.25
        if Z >= 30000:
            snow = up > (1700.0 * ppm + (rnd(n[None, :], up, salt + 7) - 0.5) * 2)
            a[body] = np.where(snow, I["white"], np.where(wood > 0.55, I["slate"], I["slateS"]))[body]
        else:
            a[body] = np.where(wood > 0.58, I["leaf0"], np.where(wood > 0.42, I["crop"], I["pasture"]))[body]
        return a, np.zeros_like(a, dtype=bool)
    # nearer: the land's own swell with its fields, woods along it where the country is wooded, and stamps
    swell = RISE.get(Z, 0.0) * np.clip(fbm(wx / (Z * 1.3) + 3.0, Z / 2000.0, 3, salt + 60) * 1.7 - 0.42, 0, 1)
    sp = np.round(swell * ppm).astype(int)
    H = int(np.ceil(34 * ppm)) + 3 + int(sp.max())
    a = np.zeros((H, width), dtype=np.uint8)
    lamps = np.zeros((H, width), dtype=bool)
    yy = np.arange(H)[:, None]
    up = H - 1 - yy
    if sp.max() > 0:  # fields on the face of the swell, in strips that follow it, hedged
        flen = {7000: 520.0, 3500: 380.0, 1800: 300.0, 900: 250.0, 500: 230.0}[Z]
        band = np.floor(up / np.maximum(2.0, sp[None, :] / 3.0 + 0.5)).astype(int)
        fid = np.floor(wx[None, :] / flen + band * 0.37)
        pick = (rnd(fid, band, salt + 61) * len(FIELD)).astype(int)
        fields = np.array([I[f] for f in FIELD])[pick]
        woodp = fbm(wx[None, :] / (Z * 0.2), up / 3.0, 3, salt + 62) > 0.63
        body = up < sp[None, :]
        a[body] = np.where(woodp, I["leaf0"], fields)[body]
        hedge = (np.abs(wx[None, :] / flen + band * 0.37 - np.round(wx[None, :] / flen + band * 0.37)) * flen * ppm < 0.6) & body
        a[hedge] = I["hedge"]
        if Z >= 1800:
            town = noise(wx[None, :] / 1400.0, 2.0, 4242) > 0.62
            lamps |= body & town & (rnd(n[None, :], up, salt + 63) < 0.035)
    wooded = fbm(wx / 900.0, Z / 300.0, 3, salt + 1)
    if Z >= 500:
        th = np.round((10 + 14 * fbm(wx / 60.0, 1.0, 3, salt + 2)) * ppm * np.clip((wooded - 0.50) * 9, 0, 1)).astype(int)
        body = (up >= sp[None, :]) & (up < (sp + th)[None, :])
        tone = np.where(rnd(n[None, :], up, salt + 3) < 0.35, I["leaf1"], I["leaf0"])
        a[body] = tone[body]
    cell = {7000: 700.0, 3500: 420.0, 1800: 260.0, 900: 150.0, 500: 90.0, 300: 60.0, 180: 44.0, 110: 34.0}[Z]
    c0, c1 = int(np.floor(wx[0] / cell)) - 2, int(np.floor(wx[-1] / cell)) + 2
    for c in range(c0, c1 + 1):  # stamps, one draw per cell of track
        r = float(rnd(c, 1, salt + 30))
        pos = (c + float(rnd(c, 2, salt + 31))) * cell
        village = float(noise(np.array([pos / 1400.0]), np.array([2.0]), 4242)[0])  # the same villages on every ring
        woods_here = float(fbm(np.array([pos / 900.0]), np.array([Z / 300.0]), 3, salt + 1)[0])
        seed = int(hash2(c, 3, salt + 32) % np.uint64(1 << 30))
        st = None
        if Z == 900 and village > 0.70 and r < 0.2:
            st = spire(30 * ppm, seed, sun)
        elif village > 0.64 and 300 <= Z <= 1800 and r < {1800: 0.8, 900: 0.75, 500: 0.7, 300: 0.5}[Z]:
            st = house(max(2, 5.0 * ppm), seed, sun)
        elif Z <= 500 and r < {500: 0.07, 300: 0.09, 180: 0.07, 110: 0.0}[Z]:
            st = house(max(2, 5.5 * ppm), seed, sun)  # a farm on its own
        elif r > 1 - np.clip(0.18 + (woods_here - 0.45) * 2.2, 0.08, 0.8) and Z <= 900:
            hm = 9 + 9 * float(rnd(c, 4, salt + 33))
            st = fir(hm * 1.2 * ppm, seed, sun) if rnd(c, 5, salt + 34) < 0.2 else tree(hm * ppm, seed, sun)
        if st is None:
            continue
        x = int(round(pos * ppm)) - n0 - st.shape[1] // 2
        h = st.shape[0]
        for sx in range(st.shape[1]):
            if 0 <= x + sx < width:
                lift = int(sp[x + sx] * (0.35 + 0.65 * float(rnd(c, 6, salt + 35))))  # it stands on the swell's face
                top = H - h - lift
                if top < 0:
                    continue
                colm = st[:, sx]
                a[top: top + h, x + sx] = np.where(colm > 0, colm, a[top: top + h, x + sx])
                lamps[top: top + h, x + sx] |= (colm == I["glass"]) & (rnd(seed + sx, np.arange(h), 55) < 0.8)
    if Z == 300:  # a lane with its line of poles, the only poles there are: far enough to be calm
        lane = fbm(wx / 2400.0, 5.0, 2, 808) > 0.50
        pole = (np.round(wx / 42.0) * 42.0 * ppm).round().astype(int) == n
        sel = lane & pole
        a[H - 7:, sel] = np.where(a[H - 7:, sel] == 0, I["pole"], a[H - 7:, sel])
    # Lights that show only after dark, so that a night with no village in view still has something to rest on
    # (added in the build, after the sheets): far off, the windows of farms too small to draw, a few together; nearer,
    # a lamp in a farm's yard, 4 to 7 m up.
    if Z >= 1800:
        hamlet = np.clip((noise(wx / 420.0, 6.0, salt + 64) - 0.5) * 4, 0, 1)
        on = np.nonzero(rnd(n, 1, salt + 65) < 0.06 * hamlet)[0]
        lamps[H - 1 - (sp[on] * rnd(n[on], 2, salt + 66)).astype(int), on] = True  # on the swell's face, or at its foot
    elif Z >= 180:
        for c in range(c0, c1 + 1):
            x = int(round((c + float(rnd(c, 8, salt + 37))) * cell * ppm)) - n0
            if rnd(c, 7, salt + 36) < 0.3 and 0 <= x < width:
                up = int(sp[x]) + int(round((4.0 + 3.0 * float(rnd(c, 9, salt + 38))) * ppm))
                if up < H:
                    lamps[H - 1 - up, x] = True
    return a, lamps


LANE_M = 62.0   # a lane and its hedge run beside the line here: level lines, which stay still as we go
VERGE_M = 15.0  # nearer than this is the railway's own grass


def ground(horizon_y, X, speed):
    """The rows under the horizon as material numbers plus a small lightness, d = 1 at the top."""
    rows = PH - horizon_y
    a = np.zeros((rows, PW), dtype=np.uint8)
    lift = np.zeros((rows, PW))
    cols = np.arange(PW)
    lane_d = int(round(EYE * FOCAL / LANE_M))
    for d in range(1, rows + 1):
        Z = EYE * FOCAL / d
        ppm = d / EYE
        n = np.floor(X * ppm) + cols - CX
        wx = n / ppm
        if Z > 100:  # fields, each a stretch of track long, in belts of distance
            belt = 0 if d <= 1 else 1 if d <= 2 else 2 if d <= 4 else 3
            u = wx / (230.0 + 60 * belt) + belt * 0.37
            pick = (rnd(np.floor(u), belt, 4100) * len(FIELD)).astype(int)
            a[d - 1] = np.array([I[FIELD[p]] for p in pick])
            edge = np.abs(u - np.round(u)) * (230.0 + 60 * belt) < max(1.5, 1.2 / ppm)
            a[d - 1][edge & (rnd(np.floor(u), belt, 4101) < 0.6)] = I["hedge"]
            continue
        # the near field: one crop for a long way, drawn out into soft dashes that flow
        if d == lane_d - 2 or d == lane_d - 1:
            a[d - 1] = I["hedge"] if d == lane_d - 2 else I["hedge1"]
        elif d == lane_d:
            a[d - 1] = I["road"]
        elif Z > LANE_M:
            a[d - 1] = np.where(fbm(wx / 1500.0, 0.5, 2, 4200) > 0.5, I["ley"], I["wheat"])
        elif Z > VERGE_M:
            a[d - 1] = np.where(fbm(wx / 1900.0, 1.5, 2, 4201) > 0.5, I["pasture"], I["crop"])
        else:
            a[d - 1] = I["verge"]
        L = max(10.0, 2.2 * speed * ppm / 30.0)  # a dash is at least twice what its row moves in a frame
        s = fbm(n / L, d / 3.0, 2, 4300)
        lift[d - 1] = (np.floor(s * 5) - 2) * (0.03 if Z > VERGE_M else 0.045) + ((d // 3) % 2) * 0.022
    return a, lift


def shade(mat, time, Z=None, lift=None, lamps=None, horizon_rgb=None):
    """Material numbers to RGB at this hour, hazed toward the horizon's colour by distance."""
    tint, floor = light(time)
    rgb = COL[np.clip(mat.astype(int) - 1, 0, None)]
    if lift is not None:
        rgb = rgb * (1 + lift[..., None])
    rgb = rgb * tint + floor
    if Z is not None and horizon_rgb is not None:
        hz = 1 - np.exp(-Z / 1000.0 / HAZE_KM)
        rgb = rgb * (1 - hz) + horizon_rgb * hz
    if lamps is not None and time in ("night", "dusk"):
        rgb[lamps] = (255, 204, 128) if time == "night" else (255, 214, 150)
    return rgb


def water(pic, hy, time, t=0.0):
    """The lake under the horizon: the sky's own colours turned over and deepened, small ripples that shimmer in
    place (water has nothing in it to follow, so nothing slides), and a path of glitter under the Sun."""
    rows = PH - hy
    deep = {"day": (34, 78, 118), "sunset": (70, 56, 92), "dusk": (30, 34, 66), "night": (10, 14, 32)}[time]
    out = np.zeros((rows, PW, 3))
    sky_part = pic[:hy]
    warm = sky_part[..., 0] + sky_part[..., 1] - sky_part[..., 2]  # the Sun or Moon is warm white; cloud is not
    sun = np.unravel_index(np.argmax(warm), warm.shape) if warm.max() > 285 and sky_part.sum(-1)[np.unravel_index(np.argmax(warm), warm.shape)] > 650 else None
    cols = np.arange(PW)
    tick = int(t * 2.5)
    for d in range(1, rows + 1):
        src = sky_part[max(0, hy - 1 - int(d * 1.6))]
        mirror = np.median(src, axis=0) * 0.6 + src * 0.4  # a breath of the clouds, softened
        k = 0.30 + 0.35 * min(1.0, d / rows)
        row = mirror * (1 - k) + np.array(deep) * k
        L = 3 + d // 5
        cell = (cols + (d * 7) % L) // L
        r = rnd(cell, d * 131 + (tick + cell) // 3, 60)
        row = row * np.where(r < 0.16, 1.10, np.where(r > 0.90, 0.90, 1.0))[:, None]
        if sun is not None:
            glint = np.exp(-np.abs(cols - sun[1]) / (5.0 + d * 0.45)) * (0.75 if time == "day" else 0.9)
            on = rnd(cell, d * 17 + tick, 61) < glint
            row[on] = row[on] * 0.25 + pic[sun] * 0.75
        out[d - 1] = row
    return out


def pole_line(pic, hy, X, time, Z=28.0, spacing=50.0, height=8.2):
    """A line of telegraph poles beside the track, far enough out to cross the window in a few seconds, with two
    wires that rise to each pole and sag between: the one near thing, and a level rhythm."""
    ppm = FOCAL / Z
    tint, floor = light(time)
    ink = np.array([52, 44, 40]) * tint + floor
    wire = np.array([44, 40, 40]) * tint + floor
    foot = hy + int(round(EYE * ppm))
    top = foot - int(round(height * ppm))
    n0 = int(np.floor(X * ppm)) - CX
    cols = np.arange(PW) + n0
    period = spacing * ppm
    phase = (cols / period) % 1.0
    sag = 4.0 * phase * (1 - phase)  # 0 at a pole, 1 mid-span
    for off, drop in ((3, 5.0), (9, 6.0)):  # two wires, on the arm and under it
        y = np.round(top + off + drop * sag).astype(int)
        ok = (y >= 0) & (y < PH)
        pic[y[ok], np.arange(PW)[ok]] = pic[y[ok], np.arange(PW)[ok]] * 0.35 + wire * 0.65
    for k in range(int(np.floor(cols[0] / period)) - 1, int(np.floor(cols[-1] / period)) + 2):
        x = int(round(k * period)) - n0
        if 0 <= x < PW - 1:
            pic[max(0, top): min(PH, foot), x: x + 2] = ink
            pic[max(0, top + 2): top + 4, max(0, x - 5): x + 7] = ink  # the cross-arm
    return pic


def wet_glass(pic, rain, time, t, speed):
    """Rain on the pane: the view softens, beads sit still, and a few long threads lie nearly level, as water does
    on a moving train (about 9 degrees below level at speed; straight down at a stand)."""
    soft = (np.roll(pic, 1, 1) + pic * 2 + np.roll(pic, -1, 1) + np.roll(pic, 1, 0) + np.roll(pic, -1, 0)) / 6
    grey = soft.mean(axis=(0, 1))
    out = soft * (1 - 0.22 * rain) + grey * 0.22 * rain
    hi = np.clip(out.max(axis=(0, 1)) * 1.05 + 18, 0, 255)
    n = int(120 * rain)
    for k in range(n):  # beads: a light pixel over a dark one
        x, y = int(rnd(k, 1, 90) * (PW - 2)), int(rnd(k, 2, 90) * (PH - 3))
        big = rnd(k, 3, 90) < 0.22
        out[y, x: x + 1 + big] = out[y, x: x + 1 + big] * 0.6 + hi * 0.4
        out[y + 1, x: x + 1 + big] *= 0.7
        if big:
            out[y + 2, x: x + 2] *= 0.8
    slope = np.tan(np.radians(9.0)) * min(1.0, speed / 10.0) + (0 if speed > 1 else 4.0)
    xs = np.arange(PW)
    for k in range(int(2 + 2 * rain)):  # threads
        y0 = PH * (0.14 + 0.24 * k + 0.07 * rnd(k, 5, 91))
        y = np.round(y0 + slope * xs + 1.4 * np.sin(xs / 7.0 + k * 2.1) * (rnd(xs // 9, k, 92) - 0.3)).astype(int)
        ok = (y >= 1) & (y < PH - 1)
        run = ((xs - t * 46 + k * 37) % 120) < 26  # water running along it
        a = np.where(run, 0.5, 0.22)[ok][:, None]
        out[y[ok], xs[ok]] = out[y[ok], xs[ok]] * (1 - a) + hi * a
        out[y[ok] + 1, xs[ok]] *= 0.7
    return out


def view(time="day", X=0.0, speed=13.3, horizon_up=0.30, cover=0.30, spill=False, cloud_seed=9, scenery="country",
         poles=False, rain=0.0, t=0.0):
    """The whole view through the pane, PH × PW × 3, with the train X metres along at `speed` m/s."""
    hy = round(PH * (1 - horizon_up))
    b = base(time)
    out = sky(time, hy, X, cover, cloud_seed)
    horizon_rgb = np.median(b[84:90, PX0:PX0 + PW].reshape(-1, 3), axis=0)
    sun = 1
    if scenery == "lake":
        out[hy:] = water(out, hy, time, t)
    else:
        gm, lift = ground(hy, X, speed)
        out[hy:] = shade(gm, time, lift=lift)
    lit = []
    for Z in RINGS:
        if scenery == "lake" and Z < 1800:
            continue  # the lake lies between us and the far shore
        ppm = FOCAL / Z
        n0 = int(np.floor(X * ppm)) - CX
        strip, lamps = ring_strip(Z, n0, PW, sun)
        foot = hy + int(round(EYE * ppm))  # the row its feet stand on
        H = strip.shape[0]
        y0 = foot - H
        rgb = shade(strip, time, Z=Z, lamps=lamps, horizon_rgb=horizon_rgb)
        m = (strip > 0) | (lamps & (time in ("night", "dusk")))  # a light with nothing drawn under it shows after dark
        ys = slice(max(0, y0), foot)
        sub = slice(max(0, -y0), H)
        region = out[ys]
        region[m[sub]] = rgb[sub][m[sub]]
        out[ys] = region
        if time in ("night", "dusk"):
            yy, xx = np.nonzero(lamps[sub])
            lit += [(int(y) + max(0, y0), int(x)) for y, x in zip(yy, xx)]
    if scenery == "lake" and lit:  # each lamp on the far shore leaves a broken streak in the water
        for y, x in lit:
            for k in range(1, 14):
                if hy + k < PH and rnd(x, k + int(t * 2) * 31, 71) < 0.5 - k * 0.055:
                    out[hy + k, x] = out[hy + k, x] * 0.45 + np.array([255, 204, 128]) * 0.55 * (1 - k / 16)
    if poles:
        out = pole_line(out, hy, X, time)
    if rain > 0:
        out = wet_glass(out, rain, time, t, speed)
    if spill and time in ("night", "dusk"):  # the carriage's own windows light the grass beside the line, and ride with us
        rows = PH - hy
        yy, xx = np.mgrid[0:rows, 0:PW]
        d = yy + 1.0
        Zg = EYE * FOCAL / d
        for cxw in (-52, 96, 244, 392):  # a lit window every 148 px of pane
            wgt = np.clip(1 - np.abs(xx - cxw - (d - rows) * 0.25) / (30 + d * 0.22), 0, 1) * np.clip((16.0 - Zg) / 5.0, 0, 1)
            dth = BAYER[yy % 4, xx % 4]
            on = wgt * 0.9 > dth * 0.9 + 0.08
            warm = np.array([150, 118, 70]) if time == "night" else np.array([120, 100, 70])
            g = out[hy:]
            g[on] = g[on] * 0.55 + warm * (0.5 + 0.35 * wgt[on][:, None])
            out[hy:] = g
    return np.clip(out, 0, 255)


# ---- the carriage round the pane
def carriage(time, kind="plain", horizon_up=0.30):
    """The cabin as an RGBA picture laid over the canvas: wall, frame, and for the fuller ones a sill and curtain,
    or a table with its lamp. Alpha 0 is glass."""
    tint, floor = light(time)
    dim = {"day": 1.0, "sunset": 0.62, "dusk": 0.34, "night": 0.22}[time]
    def c(rgb, glow=0.0):
        v = np.array(rgb, dtype=np.float64) * dim
        return np.clip(v * (1 - glow) + np.array(rgb) * glow, 0, 255)
    lit = time in ("night", "dusk")
    out = np.zeros((CH, CW, 4))
    wall, frame, gasket = c((52, 56, 72)), c((122, 126, 142)), c((20, 22, 30))
    out[..., :3] = wall
    out[..., 3] = 255
    yy, xx = np.mgrid[0:CH, 0:CW]
    def rr(x0, y0, x1, y1, r):
        inx = np.clip(np.minimum(xx - x0, x1 - 1 - xx), None, r)
        iny = np.clip(np.minimum(yy - y0, y1 - 1 - yy), None, r)
        inside = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
        corner = (inx < r) & (iny < r) & ((r - inx - 0.5) ** 2 + (r - iny - 0.5) ** 2 > r * r)
        return inside & ~corner
    out[rr(PX0 - 5, PY0 - 5, PX0 + PW + 5, PY0 + PH + 5, 11)] = np.append(frame, 255)
    out[rr(PX0 - 5, PY0 - 5, PX0 + PW + 5, PY0 - 3, 2)] = np.append(c((150, 154, 168)), 255)  # light on the frame's top edge
    out[rr(PX0 - 1, PY0 - 1, PX0 + PW + 1, PY0 + PH + 1, 7)] = np.append(gasket, 255)
    glass = rr(PX0, PY0, PX0 + PW, PY0 + PH, 6)
    out[glass] = 0
    if kind in ("sill", "table"):
        cur = [c((126, 62, 58)), c((156, 80, 70)), c((188, 104, 86))]  # a red curtain, gathered at the left
        for y in range(PY0, PY0 + PH):
            t = (y - PY0) / PH
            tie = 0.62
            wdt = 30 - 15 * np.exp(-((t - tie) / 0.16) ** 2) + (6 * (t - tie) if t > tie else 0)
            for x in range(PX0, PX0 + int(round(wdt))):
                fold = int(((x - PX0) / max(wdt, 1) * 5 + 0.3 * np.sin(y / 9.0)) % 3)
                out[y, x] = np.append(cur[fold], 255)
        y = PY0 + int(PH * 0.62)
        out[y - 1: y + 2, PX0: PX0 + 16] = np.append(c((214, 178, 96)), 255)  # its tie
    if kind == "sill":
        y0 = PY0 + PH - 9
        out[y0: y0 + 2, PX0 - 3: PX0 + PW + 3] = np.append(c((170, 172, 182)), 255)
        out[y0 + 2: PY0 + PH + 2, PX0 - 3: PX0 + PW + 3] = np.append(c((104, 108, 124)), 255)
    if kind == "table":
        ty = PY0 + PH - 46  # the table's far edge, against the wall under the glass
        out[ty - 5: ty - 3, PX0 - 3: PX0 + PW + 3] = np.append(c((170, 172, 182)), 255)  # the sill
        out[ty - 3: ty, PX0 - 3: PX0 + PW + 3] = np.append(c((96, 100, 116)), 255)
        wood = [c((92, 58, 44)), c((118, 76, 54)), c((140, 94, 64))]
        for y in range(ty, CH):
            board = (y - ty) // 11
            for x in range(0, CW):
                tone = wood[1] if board % 2 == 0 else wood[1] * 0.93
                if (y - ty) % 11 == 10:
                    tone = wood[0]
                elif rnd((x + board * 37) // 23, y, 31) < 0.05:
                    tone = wood[2] * 0.9
                out[y, x] = np.append(tone, 255)
        out[ty: ty + 1, :] = np.append(c((172, 124, 86)), 255)
        # the lamp, at the right, by the glass
        lx, base_y = PX0 + PW - 58, ty + 14
        brass = c((176, 140, 70), 0.5 if lit else 0)
        out[base_y - 2: base_y + 1, lx - 6: lx + 7] = np.append(brass, 255)
        out[base_y - 20: base_y - 2, lx - 1: lx + 1] = np.append(brass, 255)
        shade_on = np.array([255, 222, 160]) if lit else c((226, 208, 178))
        for k in range(15):
            half = 7 + k * 6 // 14
            y = base_y - 36 + k
            out[y, lx - half: lx + half + 1] = np.append(shade_on * (0.86 + 0.14 * (k / 14) if lit else 1), 255)
            if not lit:
                out[y, lx - half: lx - half + 3] = np.append(c((190, 170, 146)), 255)
        if lit:  # its pool of light on the table
            for y in range(ty + 1, CH):
                for x in range(lx - 80, lx + 80):
                    if 0 <= x < CW:
                        r = ((x - lx) / 78.0) ** 2 + ((y - base_y) / 26.0) ** 2
                        if r < 1 and (1 - r) > BAYER[y % 4, x % 4] * 0.95:
                            out[y, x, :3] = np.clip(out[y, x, :3] * 0.6 + np.array([190, 130, 70]) * (0.45 + 0.4 * (1 - r)), 0, 255)
    return out


def reflections(pic, time, kind):
    """What the lit carriage leaves in the glass after dark: the lamp's ghost, and a breath of the table's light."""
    if kind != "table" or time not in ("night", "dusk"):
        return pic
    ty = PH - 46
    lx, base_y = PW - 58 - 34, ty + 14 - 2  # the ghost stands a little toward the middle of the glass
    k = 0.5 if time == "night" else 0.32
    for j in range(15):
        half = 7 + j * 6 // 14
        y = base_y - 36 + j
        pic[y, lx - half: lx + half + 1] = pic[y, lx - half: lx + half + 1] * (1 - k) + np.array([255, 214, 150]) * k
    pic[base_y - 20: base_y - 2, lx - 1: lx + 1] = pic[base_y - 20: base_y - 2, lx - 1: lx + 1] * (1 - k * 0.6) + np.array([176, 140, 70]) * k * 0.6
    yy, xx = np.mgrid[0:PH, 0:PW]
    glow = np.clip(1 - (((xx - lx) / 70.0) ** 2 + ((yy - (ty - 8)) / 18.0) ** 2), 0, 1)
    on = (glow > BAYER[yy % 4, xx % 4]) & (yy < ty - 5)
    pic[on] = pic[on] * 0.72 + np.array([150, 104, 60]) * 0.28
    return pic


def compose(time="day", kind="plain", X=5200.0, speed=13.3, horizon_up=0.30, cover=0.30, **kw):
    """One finished frame of the canvas, CH × CW × 3 uint8."""
    pic = reflections(view(time, X, speed, horizon_up, cover, **kw), time, kind)
    cab = carriage(time, kind, horizon_up)
    out = np.zeros((CH, CW, 3))
    out[PY0: PY0 + PH, PX0: PX0 + PW] = pic
    al = cab[..., 3:4] / 255.0
    out = out * (1 - al) + cab[..., :3] * al
    return np.clip(out, 0, 255).astype(np.uint8)[:CH]


def sheet(name, tiles, cols=3, scale=3):
    from PIL import ImageDraw, ImageFont
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
    tw, th, cap = CW * scale, CH * scale, 40
    rows = (len(tiles) + cols - 1) // cols
    im = Image.new("RGB", (cols * tw + (cols + 1) * 8, rows * (th + cap) + 8), (14, 14, 16))
    d = ImageDraw.Draw(im)
    for k, (label, a) in enumerate(tiles):
        x, y = 8 + (k % cols) * (tw + 8), 8 + (k // cols) * (th + cap)
        im.paste(Image.fromarray(a).resize((tw, th), Image.NEAREST), (x, y))
        d.text((x + 4, y + th + 8), label, fill=(225, 225, 230), font=font)
    im.save(f"{OUT}/{name}.png")


if __name__ == "__main__":
    import sys
    X = float(sys.argv[1]) if len(sys.argv) > 1 else 52000.0
    if "sheet2" in sys.argv:
        tiles = [("D  A lake beside the line, by day", compose("day", "sill", X, scenery="lake")),
                 ("E  The lake at night, from the table", compose("night", "table", X, scenery="lake")),
                 ("F  A line of poles and wires 28 m out", compose("day", "sill", X, poles=True)),
                 ("G  Rain on the glass at dusk", compose("dusk", "table", X, cover=0.62, rain=1.0))]
        sheet("train-sheet2", tiles, cols=2)
    else:
        tiles = []
        for time in ("day", "night"):
            for kind, label in (("plain", "A  A plain window"), ("sill", "B  A sill and a curtain"), ("table", "C  A table and its lamp")):
                tiles.append((f"{label}, by {time}", compose(time, kind, X)))
        sheet("train-sheet1", tiles)
