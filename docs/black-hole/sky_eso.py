"""A licence-clean sky for the mock-ups: ESO/S. Brunier's Milky Way panorama (CC BY 4.0) blurred to a glow, with the
HYG catalogue's 119,614 real stars (CC BY-SA 4.0) drawn sharp over it. Galactic equirect, 8192 × 4096, linear RGBA float32."""
import csv, numpy as np
from PIL import Image, ImageFilter
import bh

Image.MAX_IMAGE_PIXELS = None
W, H = 8192, 4096
pan = Image.open(f"{bh.DATA}/eso/eso0932a.jpg").convert("RGB").filter(ImageFilter.GaussianBlur(5)).resize((W, H), Image.BICUBIC)
sky = (np.asarray(pan, dtype=np.float32) / 255.0) ** 2.2 * 0.26
G = np.array([[-0.0548755604, -0.8734370902, -0.4838350155],
              [+0.4941094279, -0.4448296300, +0.7469822445],
              [-0.8676661490, -0.1980763734, +0.4559837762]])  # equatorial J2000 to galactic
n = 0
for row in csv.DictReader(open(f"{bh.DATA}/hyg/hyg_v44.csv")):
    try:
        ra, dec, mag = float(row["ra"]) * 15, float(row["dec"]), float(row["mag"])
    except ValueError:
        continue
    if mag < -2 or mag > 11:
        continue
    ci = float(row["ci"]) if row["ci"] not in ("", None) else 0.6
    r, d = np.radians(ra), np.radians(dec)
    g = G @ np.array([np.cos(d) * np.cos(r), np.cos(d) * np.sin(r), np.sin(d)])
    l, b = np.arctan2(g[1], g[0]), np.arcsin(g[2])
    x, y = (0.5 - l / (2 * np.pi)) % 1.0 * W, (0.5 - b / np.pi) * (H - 1)
    T = 4600 * (1 / (0.92 * ci + 1.7) + 1 / (0.92 * ci + 0.62))  # Ballesteros 2012, B-V to kelvin
    col = bh.blackbody(np.array([T]))[0]
    col = col / col.max()
    flux = 2.2 * 10 ** (-0.4 * (mag - 5.0))
    sig = 0.75 / max(0.25, np.cos(b))  # wider toward the poles, where the map's pixels are narrow
    x0, y0 = int(np.floor(x)), int(np.floor(y))
    rx = int(np.ceil(3 * sig)) + 1
    xs = np.arange(x0 - rx, x0 + rx + 1)
    ys = np.arange(max(0, y0 - 3), min(H, y0 + 4))
    wx = np.exp(-0.5 * ((xs + 0.5 - x) / sig) ** 2)
    wy = np.exp(-0.5 * ((ys + 0.5 - y) / 0.75) ** 2)
    k = np.outer(wy, wx)
    k *= min(flux / k.sum(), 9.0 / k.max())
    sky[np.ix_(ys, xs % W)] += k[..., None] * col
    n += 1
out = np.zeros((H, W, 4), dtype=np.float32)
out[..., :3] = sky
out.tofile(f"{bh.DATA}/sky_eso_hyg.raw")
print(n, "stars", sky.mean(), np.percentile(sky, [50, 90, 99]))
