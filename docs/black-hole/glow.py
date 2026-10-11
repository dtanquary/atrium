"""The glow Dave picked for the Black Hole (sheet 5, tile M, 2026-10-11), painted onto one of the app's snapshots:
the disc's own light, blurred at two widths and added back. The build's glow is to be matched against this.

    python3 glow.py <snapshot.png> <out.png> [strength]     (needs numpy and Pillow)

Tile M was strength 0.45 and tile N 1.1, on a 3024 x 1964 snapshot with no glow. Light is taken as the picture's
values to the power 2.2; the disc is every pixel whose red is more than 40 of 255 over its blue; the blur is 60% of
a Gaussian 14 px in radius and 40% of one 60 px in radius (0.46% and 2% of the picture's width).
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

im = Image.open(sys.argv[1]).convert('RGB')
a = np.asarray(im).astype(np.float32) / 255
light = a ** 2.2
disc = (a[..., 0] > a[..., 2] + 40 / 255)[..., None]
lit = Image.fromarray((np.clip(light * disc, 0, 1) * 255).astype(np.uint8))
wide = im.size[0] / 3024
blur = lambda r: np.asarray(lit.filter(ImageFilter.GaussianBlur(r * wide))).astype(np.float32) / 255
halo = 0.6 * blur(14) + 0.4 * blur(60)
strength = float(sys.argv[3]) if len(sys.argv) > 3 else 0.45
Image.fromarray((np.clip(light + strength * halo, 0, 1) ** (1 / 2.2) * 255).astype(np.uint8)).save(sys.argv[2])
