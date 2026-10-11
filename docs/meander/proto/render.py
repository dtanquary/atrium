"""Draws the prototype's fields the way the app's shader would: the three per-texel fields are quantised to what an
RGBA8 texture holds, read through a cubic B-spline (the four-tap read Turing Patterns uses), and everything else is
per-pixel arithmetic on those reads. Nothing here looks at the centreline itself."""
import numpy as np
from PIL import Image
from scipy.ndimage import maximum_filter, minimum_filter  # each stands in for one more texture read, see reads

AMAX = 600.0   # the oldest age the texture tells apart (T); older land is all 'ancient'
TS = 0.7       # time between scroll-bar ridges (T): about 0.2 W at the average bank's pace


def smooth(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def bspline_up(a, f):
    def up(a, axis):
        n = a.shape[axis]
        p = (np.arange(n * f) + 0.5) / f - 0.5
        i = np.floor(p).astype(int); t = p - i
        ws = ((1 - t) ** 3 / 6, (4 - 6 * t * t + 3 * t ** 3) / 6, (1 + 3 * t + 3 * t * t - 3 * t ** 3) / 6, t ** 3 / 6)
        sh = [1, 1]; sh[axis] = -1
        return sum(w.reshape(sh) * np.take(a, np.clip(i + k - 1, 0, n - 1), axis=axis) for k, w in enumerate(ws))
    return up(up(a.astype(np.float32), 0), 1)


def reads(r, f=2, crop=None):
    """The shader's texture reads at f pixels a texel: the stamp (16 bits), the water field and the hollow field
    (8 bits each), and the stamp twice more:
      inside: about two texels into the water, for the water's own age (nothing for the river, a lake's age for a
        lake); at a bank the plain read is already a blend of the water's stamp and the land's beside it.
      land: about two texels further from the water, used in place of the plain read close to a bank, so a cut
        bank is a clean step up to old ground.
    The shader would step along the water field's slope for those; the newest and the oldest stamp within two
    texels give the same answers here."""
    q = AMAX / 65535
    st = np.round(np.clip(r.stamp, r.t - AMAX, r.t) / q) * q
    hk = np.round(np.clip(r.hollow, 0, 1) * 255) / 255
    wa = np.round(np.clip(r.water(), 0, 1) * 255) / 255  # bank distance: 0.5 is the bank
    inner, outer = maximum_filter(st, size=5), minimum_filter(st, size=5)
    if crop is not None:
        y0, y1, x0, x1 = crop
        st, hk, wa, inner, outer = (a[y0:y1, x0:x1] for a in (st, hk, wa, inner, outer))
    S, WA = bspline_up(st, f), bspline_up(wa, f)
    near = 1 - smooth((WA - 0.5) * r.tex, 0.5, 3.0)  # within a texel of a bank fully, by three not at all
    return S, bspline_up(hk, f), WA, bspline_up(inner, f), bspline_up(outer, f) * near + S * (1 - near)


def noise(shape, cell, seed):
    """Soft value noise, for paper grain and for ground the river never reached."""
    rng = np.random.default_rng(seed)
    g = rng.uniform(-1, 1, (shape[0] // cell + 3, shape[1] // cell + 3)).astype(np.float32)
    return bspline_up(g, cell)[cell:cell + shape[0], cell:cell + shape[1]]


def grad(a):
    gy, gx = np.gradient(a)
    return gx, gy


def ramp(v, stops):
    xs = [s[0] for s in stops]
    return np.stack([np.interp(v, xs, [s[1][c] for s in stops]) for c in range(3)], axis=-1)


def rgb(*c): return np.array(c, np.float32) / 255


# Colours measured by meander-look from the references (scripts/palettes.py): a relative elevation model of the Sauk
# (Washington Geological Survey) for the relief, and the legend of Fisk's 1944 plates for the map.
RELIEF = {
    "Survey Blue": dict(river=rgb(153, 200, 211), ground=rgb(0, 22, 31), wet=rgb(52, 130, 151),
                        stops=[(0.0, rgb(120, 178, 192)), (0.10, rgb(52, 130, 151)), (0.32, rgb(24, 93, 115)), (0.52, rgb(14, 76, 97)),
                               (0.72, rgb(10, 64, 83)), (0.90, rgb(4, 46, 63)), (1.0, rgb(1, 30, 42))]),
    "Rainforest": dict(river=rgb(151, 202, 192), ground=rgb(2, 21, 15), wet=rgb(52, 132, 113),
                       stops=[(0.0, rgb(118, 180, 166)), (0.10, rgb(52, 132, 113)), (0.32, rgb(24, 97, 80)), (0.52, rgb(14, 80, 65)),
                              (0.72, rgb(8, 67, 54)), (0.90, rgb(0, 47, 37)), (1.0, rgb(1, 30, 22))]),
    "Garnet": dict(river=rgb(210, 187, 173), ground=rgb(30, 9, 13), wet=rgb(143, 108, 101),
                   stops=[(0.0, rgb(186, 156, 145)), (0.10, rgb(143, 108, 101)), (0.32, rgb(112, 70, 71)), (0.52, rgb(100, 54, 59)),
                          (0.72, rgb(92, 42, 51)), (0.90, rgb(81, 25, 38)), (1.0, rgb(48, 14, 21))]),
}


def relief(r, f=2, palette="Survey Blue", crop=None, seed=7, pre=None):
    """Lidar relief, coloured by height above the river (a relative elevation model): the river and the bars at
    its level are the lightest thing, land darkens as it builds up, and there are no outlines."""
    S, HK, WA, SI, SL = pre or reads(r, f, crop)
    px = 1.0 / (r.tex * f)  # one pixel, in widths
    p = RELIEF[palette]
    age = r.t - SL  # so the cut bank is a clean step up to old ground, and only the bar side ramps
    # height above the river, 0 to 1: a bar is up out of the water within a couple of T, then silts up for ages
    h = 0.25 * (1 - np.exp(-age / 2.5)) + 0.75 * (1 - np.exp(-age / 90))
    lage = np.maximum(r.t - SI, 0)  # the lake's own age (only right within two texels of its banks)
    hollow = smooth(0.66 - HK, 0.0, 0.12) * smooth(lage, 2.0, 12.0) * np.exp(-lage / 140)  # an old channel stays low for a long while: never at once
    h = h - 0.14 * hollow * smooth(h, 0.1, 0.4) * (1 - smooth(0.5 - WA, -0.6 * px, 0.6 * px))
    # scroll bars: old bank lines, so contours of the stamp; two spacings beating, uneven in strength, and low
    gx, gy = grad(S); g = np.hypot(gx, gy)
    fade = 1 - smooth(2 * np.pi * g / TS, 0.7, 1.5)  # too fine to draw, and across a scarp: flat
    patch = 0.55 + 0.45 * noise(S.shape, 70 * f // 2, seed + 5)
    scroll = (0.6 * np.cos(2 * np.pi * S / TS) + 0.4 * np.cos(2 * np.pi * S / (TS * 1.618) + 1.3)) * fade * patch * (0.35 + 0.65 * np.exp(-age / 150))
    broad = np.cos(2 * np.pi * S / 2.9 + 0.7) * (1 - smooth(2 * np.pi * g / 2.9, 0.7, 1.5)) * (0.5 + 0.5 * np.exp(-age / 200))  # sets of scrolls: arcs that show at a glance
    scroll = scroll + 0.9 * broad
    water = smooth(0.5 - WA, -0.6 * px, 0.6 * px)
    still = smooth(r.t - SI, 0.3, 4.0)  # water the river has left dulls a little over its first few T: a lake
    # ground the river has not reached in memory: not flat, but nothing like a river's work either
    wild = smooth(age, AMAX * 0.80, AMAX * 0.98)
    rough = 0.6 * noise(S.shape, 60 * f // 2, seed) + 0.3 * noise(S.shape, 22 * f // 2, seed + 1) + 0.1 * noise(S.shape, 8 * f // 2, seed + 2)
    hc = np.clip(h + 0.02 * scroll, 0, 1)
    col = ramp(hc, p["stops"])
    col = col * (1 - wild[..., None]) + (p["ground"] + (np.array(p["stops"][5][1]) - p["ground"]) * smooth(rough, -0.1, 0.55)[..., None]) * wild[..., None]
    # light from the upper left on the fine relief only, and none within a few pixels of water: no rims
    hs = 0.35 * h + 0.03 * scroll + 0.05 * wild * rough
    gx, gy = grad(hs)
    z = 5.0 * f
    nx, ny = -gx * z, -gy * z
    lx, ly, lz = -0.55, -0.62, 0.56
    shade = (nx * lx + ny * ly + lz) / np.sqrt(nx * nx + ny * ny + 1) - lz
    away = smooth(WA - 0.5, 0.5 * px, 4 * px)
    col = col * np.clip(1 + 0.9 * shade * away, 0.72, 1.3)[..., None]
    wcol = p["river"][None, None, :] * (1 - (0.35 * still)[..., None]) + p["wet"][None, None, :] * (0.35 * still)[..., None]
    col = col * (1 - water[..., None]) + wcol * water[..., None]
    yy, xx = np.mgrid[0:S.shape[0], 0:S.shape[1]]
    vig = 1 - 0.22 * (((xx / S.shape[1] - 0.5) ** 2 + (yy / S.shape[0] - 0.5) ** 2) * 2)
    return np.clip(col * vig[..., None] * 0.86, 0, 1)


FISK = {
    # Fisk's four muted inks on cream, his line ink (not black), and the river left as bare paper
    "Fisk 1944": dict(paper=rgb(235, 224, 196), river=rgb(244, 237, 216), line=rgb(89, 75, 59),
                      inks=[rgb(188, 199, 139), rgb(215, 114, 97), rgb(154, 180, 159), rgb(221, 208, 123)]),
    "Fisk 1944 Dark": dict(paper=rgb(27, 24, 20), river=rgb(166, 158, 138), line=rgb(80, 76, 67),
                           inks=[rgb(100, 106, 74), rgb(123, 65, 55), rgb(82, 96, 84), rgb(110, 104, 61)]),
    # one ink, older is paler
    "Sage": dict(paper=rgb(235, 224, 196), river=rgb(244, 237, 216), line=rgb(89, 75, 59), inks=[rgb(188, 199, 139), rgb(172, 186, 124)]),
    "Salmon": dict(paper=rgb(235, 224, 196), river=rgb(244, 237, 216), line=rgb(89, 75, 59), inks=[rgb(215, 114, 97), rgb(203, 100, 86)]),
    "Sage Dark": dict(paper=rgb(27, 24, 20), river=rgb(166, 158, 138), line=rgb(80, 76, 67), inks=[rgb(100, 106, 74), rgb(86, 92, 62)]),
}
# Fisk's order, by how many stages old the land is (meander-look's reading of his legend): four solids for the newest
# (sage, salmon, grey-teal, straw), then runs of four stages in one ink at about 65, 50, 40 and 23 percent.
ORDER = [(0, 1.0), (1, 1.0), (2, 1.0), (3, 1.0)] + [(i, c) for i in (2, 1, 0, 3) for c in (0.65, 0.5, 0.4, 0.23)]
# The other rule: how much ink is left by age in stages, sliding smoothly (his solid, 65, 50, 40, 23 percent as flat tints)
COVER = ([0, 1.5, 3, 6, 12, 30, 90, 120], [1.0, 1.0, 0.65, 0.5, 0.4, 0.23, 0.12, 0.0])


def fisk(r, f=2, palette="Fisk 1944", crop=None, seed=7, rule="fixed", pre=None):
    """A map of the river's old courses: each spot is inked for the stage in which the river last left it.
    rule "fixed": stages of 5 T, each stage's ink fixed to the land for good (the inks in turn), paler with age.
      Thin stripes; nothing on the sheet ever changes colour except by fading.
    rule "order": stages of 11 T, coloured as Fisk colours land that many stages old (four solids, then runs of
      four in one ink), the whole sheet sliding to the next colours over the last third of every stage.
    The live river is bare paper between two bank lines; a lake keeps that line when new and it thins."""
    S, HK, WA, SI, SL = pre or reads(r, f, crop)
    px = 1.0 / (r.tex * f)
    p = FISK[palette]
    stage = 5.0 if rule == "fixed" else 11.0
    st = S / stage
    k = np.floor(st).astype(int)
    inks = np.array(p["inks"], np.float32)
    grain = 1 + 0.03 * noise(S.shape, 3, seed)[..., None] + 0.025 * noise(S.shape, 40, seed + 2)[..., None]
    paper = p["paper"][None, None, :] * grain
    if rule == "fixed":
        cover = np.interp((r.t - S) / stage, COVER[0], COVER[1]).astype(np.float32)
        col = paper * (1 - cover[..., None]) + inks[k % len(inks)] * grain * cover[..., None]
    else:
        def tint(j):  # the colour of land j stages old
            j = np.clip(j, 0, 60)
            if len(inks) == 4:
                ink = np.array([ORDER[min(i, len(ORDER) - 1)][0] for i in range(61)])[j]
                cov = np.array([ORDER[i][1] if i < len(ORDER) else 0.23 * max(0.0, 1 - (i - len(ORDER) + 1) / 34) for i in range(61)], np.float32)[j]
            else:  # one ink: paler with age, alternate stages a touch apart so the bands still show
                ink = j % len(inks)
                cov = np.interp(j, [0, 3, 4, 8, 12, 16, 30, 54], [1, 1, 0.65, 0.5, 0.4, 0.23, 0.12, 0]).astype(np.float32)
            return paper * (1 - cov[..., None]) + inks[ink] * grain * cov[..., None], cov
        now = r.t / stage
        j = int(np.floor(now)) - k
        slide = float(smooth(now - np.floor(now), 0.67, 1.0))
        (c0, v0), (c1, v1) = tint(j), tint(j + 1)
        col = c0 * (1 - slide) + c1 * slide; cover = v0 * (1 - slide) + v1 * slide
    # thin lines where one stage meets the next and along old scarps; faint ridge-and-swale lines inside a stage
    gx, gy = grad(st); g = np.hypot(gx, gy) + 1e-9
    fr = st - k
    edge = np.maximum(1 - smooth(np.minimum(fr, 1 - fr) / g, 0.2, 0.8), smooth(g * stage, 1.75, 4.0)) * (0.25 + 0.75 * smooth(cover, 0.0, 0.5))
    sc = S / (TS * 2); gs = g * stage / (TS * 2)
    fs = sc - np.floor(sc)
    hach = (1 - smooth(np.minimum(fs, 1 - fs) / gs, 0.15, 0.6)) * (1 - smooth(gs, 0.22, 0.4)) * cover
    ink = np.clip(0.45 * edge + 0.12 * hach, 0, 1)[..., None]
    col = col * (1 - ink) + p["line"][None, None, :] * ink
    w = smooth(0.5 - WA, -0.6 * px, 0.6 * px)[..., None]
    col = col * (1 - w) + p["river"][None, None, :] * grain * w
    fresh = 1 - smooth(r.t - SI, 0.5, 6.0)  # the river, and a lake for its first few T, wear the full bank line
    off = np.abs(WA - 0.5)
    line = np.maximum((1 - smooth(off, 0.3 * px, 1.3 * px)) * 0.7, (1 - smooth(off, 0.5 * px, 1.5 * px)) * fresh)[..., None]
    col = col * (1 - line) + p["line"][None, None, :] * line
    yy, xx = np.mgrid[0:S.shape[0], 0:S.shape[1]]
    vig = 1 - 0.16 * (((xx / S.shape[1] - 0.5) ** 2 + (yy / S.shape[0] - 0.5) ** 2) * 2)
    return np.clip(col * vig[..., None], 0, 1)


def save(a, path):
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(path)
