"""How bright, contrasty, busy and colourful a picture is, at a common 1920 px width, so renders can be
scored against the references. usage: python3 -I busy.py img [fx0,fy0,fx1,fy1] ...  (crop optional, after each image)
luma: mean brightness 0-1 · rms: brightness spread · edges: share of pixels whose brightness steps >0.08 to a
neighbour (line work, hatching, speckle) · chroma: mean (max-min)/255 · hues: share of coloured pixels in the
commonest 60 degrees of hue (1.0 = one colour family)"""
import sys, colorsys
import numpy as np
from PIL import Image
Image.MAX_IMAGE_PIXELS = None
args = sys.argv[1:]; i = 0
while i < len(args):
    im = Image.open(args[i]).convert("RGB"); name = args[i].rsplit("/", 1)[-1]; i += 1
    if i < len(args) and args[i][0].isdigit():
        f = list(map(float, args[i].split(","))); W, H = im.size
        im = im.crop((int(f[0] * W), int(f[1] * H), int(f[2] * W), int(f[3] * H))); i += 1
    im = im.resize((1920, int(1920 * im.size[1] / im.size[0])), Image.LANCZOS)
    a = np.asarray(im, dtype=np.float32) / 255
    L = a @ np.array([0.2126, 0.7152, 0.0722])
    g = np.maximum(np.abs(np.diff(L, axis=0))[:, :-1], np.abs(np.diff(L, axis=1))[:-1])
    ch = a.max(2) - a.min(2)
    col = a[ch > 0.12][::37]
    if len(col) > 100:
        h = np.array([colorsys.rgb_to_hsv(*c)[0] for c in col]) * 360
        hist = np.histogram(h, bins=36, range=(0, 360))[0]; hist = np.concatenate([hist, hist[:5]])
        fam = max(hist[k:k + 6].sum() for k in range(36)) / len(h)
    else: fam = 1.0
    print(f"{name:44s} luma {L.mean():.2f}  rms {L.std():.2f}  edges {(g > 0.08).mean():6.1%}  chroma {ch.mean():.2f}  hues {fam:.2f}")
