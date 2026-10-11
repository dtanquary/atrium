"""Proposed Meander palettes, built from the measured references, and a swatch sheet of them.
Each palette: ground, five deposit ages (oldest -> youngest), the river, and the line colour.
Dark ramps are the measured lidar ramps with the top end held down (river at ~0.7 luma, not white).
usage: python3 -I palettes.py [swatches.png]"""
import sys
import numpy as np
from PIL import Image, ImageDraw
Y = np.array([0.2126, 0.7152, 0.0722])
def mix(a, b, t): return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))
def scale_to(c, luma):  # same hue and saturation at another brightness
    c = np.array(c, float); return tuple(int(round(v)) for v in np.clip(c * luma * 255 / (c @ Y), 0, 255))

# --- Fisk's own inks, measured on the legend of Plate 22 sheet 1 (LSU scan) ---
paper, line = (235, 224, 196), (89, 75, 59)
ink = {"sage": (188, 199, 139), "salmon": (215, 114, 97), "teal": (154, 180, 159), "straw": (221, 208, 123)}
cover = [0.23, 0.40, 0.50, 0.65, 1.0]              # dots, fine, medium and wide hatch, solid (measured)
P = {}
for name, c in ink.items():
    if name == "straw": continue
    P[f"Fisk {name} · Light"] = dict(ground=paper, ages=[mix(paper, c, k) for k in cover], river=(244, 237, 216), line=line)
    dground = (27, 24, 20)                          # his line ink, darkened: warm black, not #000
    dc = scale_to(c, 0.40)
    P[f"Fisk {name} · Dark"] = dict(ground=dground, ages=[mix(dground, dc, k) for k in cover], river=scale_to(paper, 0.62), line=scale_to(paper, 0.30))
# his four solids together (the one many-hued palette): newest four stages 16..19, then the present river
P["Fisk 1944 · Light"] = dict(ground=paper, ages=[mix(paper, ink["teal"], .4), ink["straw"], ink["teal"], ink["salmon"], ink["sage"]], river=(244, 237, 216), line=line)
dg = (27, 24, 20)
P["Fisk 1944 · Dark"] = dict(ground=dg, ages=[mix(dg, scale_to(ink["teal"], .36), .5)] + [scale_to(ink[k], l) for k, l in (("straw", .40), ("teal", .36), ("salmon", .30), ("sage", .40))], river=scale_to(paper, 0.62), line=scale_to(paper, 0.30))

# --- lidar ramps, measured from the Washington Geological Survey pictures (median colour at each luma) ---
ramps = {
  "Survey Blue (Sauk)":    [(0, 24, 34), (4, 46, 63), (14, 76, 97), (30, 104, 127), (52, 130, 151), (81, 155, 173), (115, 178, 193), (153, 200, 211), (192, 222, 229), (234, 243, 246)],
  "Rainforest (Quinault)": [(2, 23, 17), (0, 47, 37), (14, 80, 65), (31, 109, 90), (52, 132, 113), (81, 159, 140), (114, 181, 166), (151, 202, 192), (190, 224, 217), (234, 245, 243)],
  "Garnet (Chehalis)":     [(33, 10, 14), (81, 25, 38), (100, 54, 59), (120, 81, 79), (143, 108, 101), (168, 135, 126), (189, 160, 149), (210, 187, 173), (230, 213, 199), (244, 238, 227)],
  "Amethyst (Okanogan)":   [(28, 15, 31), (58, 33, 63), (92, 51, 79), (131, 74, 107), (165, 100, 111), (185, 128, 123), (201, 157, 138), (217, 184, 172), (237, 212, 209), (249, 244, 247)],
}
for name, r in ramps.items():
    # Dark: ground = the ramp's darkest stop dimmed a little; ages climb stops 1..5; river = stop 7 (luma ~0.75), not white
    P[f"{name} · Dark"] = dict(ground=mix((0, 0, 0), r[0], 0.9), ages=[r[1], mix(r[1], r[2], .6), r[2], mix(r[2], r[3], .6), r[4]], river=r[7], line=r[5])
    # Light (after the Survey's Yakima picture: pale ground, the river the darkest thing)
    P[f"{name} · Light"] = dict(ground=mix(r[9], (246, 244, 238), .5), ages=[r[8], mix(r[8], r[7], .6), r[7], mix(r[7], r[6], .6), r[6]], river=r[3], line=r[2])
# --- true colour, from NASA's Landsat views (Mamoré 2014, Ucayali 1985) ---
P["Landsat · Dark"] = dict(ground=(48, 63, 52), ages=[(50, 69, 57), (59, 85, 61), (79, 104, 75), (112, 130, 93), (168, 172, 125)], river=(209, 170, 103), line=(30, 29, 46))

def luma(c): return float(np.array(c) @ Y / 255)
for name, p in P.items():
    f = lambda c: "(%3d,%3d,%3d)" % c
    print(f"{name:30s} ground {f(p['ground'])} {luma(p['ground']):.2f} | ages old->young " + " ".join(f(c) for c in p["ages"]) +
          f" [{luma(p['ages'][0]):.2f}..{luma(p['ages'][-1]):.2f}] | river {f(p['river'])} {luma(p['river']):.2f} | line {f(p['line'])}")
if len(sys.argv) > 1:
    names = list(P); cw, ch = 520, 64
    im = Image.new("RGB", (cw * 2, ch * ((len(names) + 1) // 2)), (40, 40, 40)); d = ImageDraw.Draw(im)
    for i, n in enumerate(names):
        p = P[n]; x0, y0 = (i % 2) * cw, (i // 2) * ch
        d.rectangle((x0, y0, x0 + cw - 2, y0 + ch - 2), fill=p["ground"])
        for j, c in enumerate(p["ages"]): d.rectangle((x0 + 150 + j * 50, y0 + 14, x0 + 198 + j * 50, y0 + ch - 16), fill=c)
        d.rectangle((x0 + 410, y0 + 14, x0 + 500, y0 + ch - 16), fill=p["river"]); d.line((x0 + 150, y0 + ch - 9, x0 + 500, y0 + ch - 9), fill=p["line"], width=2)
        d.text((x0 + 6, y0 + 24), n, fill=p["line"])
    im.save(sys.argv[1])
