"""A relative elevation model from a 3DEP float TIFF: subtract a plane fitted to the floodplain, then colour
height above the water with a one-hue ramp and a little hillshade.
usage: python3 -I rem.py <dem.tif> <out.png> [dark|light] [top metres]"""
import sys
import numpy as np
from PIL import Image

z = np.asarray(Image.open(sys.argv[1]), dtype=np.float32)
mode = sys.argv[3] if len(sys.argv) > 3 else "dark"
top = float(sys.argv[4]) if len(sys.argv) > 4 else 12.0
H, W = z.shape
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
flood = z < np.percentile(z, 75)                                   # the valley floor, not the uplands
A = np.c_[xx[flood], yy[flood], np.ones(flood.sum())]
coef, *_ = np.linalg.lstsq(A[::50], z[flood][::50], rcond=None)    # valley slope as a plane
rel = z - (coef[0] * xx + coef[1] * yy + coef[2])
rel -= np.percentile(rel, 2)                                       # 0 = the water surface, near enough
print("plane slope m/px:", coef[:2], " relative height percentiles 5/25/50/75/95:", np.percentile(rel, [5, 25, 50, 75, 95]).round(1))
np.save(sys.argv[2].rsplit(".", 1)[0] + ".npy", rel.astype(np.float32))
t = np.clip(rel / top, 0, 1) ** 0.6                                # most of the ramp in the first few metres
# hillshade from the north-west, vertical exaggeration 8 (the plain's relief is a few metres over kilometres)
gy, gx = np.gradient(z * 8 / 23.6)
shade = np.clip((gx - gy) / np.sqrt(2) * 0.9 + 1, 0.55, 1.45) / 1.0
stops = {"dark": [(0.0, (226, 240, 240)), (0.18, (120, 190, 196)), (0.45, (38, 110, 128)), (0.75, (12, 52, 70)), (1.0, (5, 22, 32))],
         "light": [(0.0, (60, 86, 120)), (0.2, (140, 164, 196)), (0.5, (198, 210, 226)), (1.0, (244, 242, 236))]}[mode]
ts = np.array([s[0] for s in stops]); cs = np.array([s[1] for s in stops], dtype=np.float32)
rgb = np.stack([np.interp(t, ts, cs[:, i]) for i in range(3)], -1)
rgb = np.clip(rgb * shade[..., None] ** (0.5 if mode == "dark" else 0.35), 0, 255)
Image.fromarray(rgb.astype(np.uint8)).save(sys.argv[2])
