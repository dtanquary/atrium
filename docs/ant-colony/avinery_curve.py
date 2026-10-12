# avinery_curve.py <folder of frames>: the dug area against time in a real dig, from the time-lapse published with
# Avinery et al. 2023 (J R Soc Interface; "Labeled Tracking Videos and Scripts", CC BY 4.0,
# https://figshare.com/articles/journal_contribution/Labeled_Tracking_Videos_and_Scripts/22649689), in which the
# authors tint the tunnels blue. The film is 106.3 s for about 17.4 h on its on-screen clock; take a frame a second
# from it first (ffmpeg -i <film> -vf fps=1,scale=390:270 <folder>/f%03d.png), so a frame is about 9.8 minutes.
# It prints the share of the final dug area at each hour: 49% in the first hour, 74% by three, 90% by eight
# (docs/ant-colony.md, "What real ants and nests do"). Run with python3 -I.
import glob, sys, numpy as np
from PIL import Image
fs = sorted(glob.glob(sys.argv[1] + "/f*.png"))
out = []
for n, f in enumerate(fs):
    a = np.asarray(Image.open(f).convert("RGB")).astype(float)
    blue = (a[..., 2] - a[..., 0] > 40)
    blue[232:250, 145:230] = False                       # the green clock label
    ys, xs = np.nonzero(blue)
    out.append((n * 17.4 / 106.3, blue.sum(), ys.max() if len(ys) else 0))
a0 = out[-1][1]
print("frame is 390x270 px = 14 cm wide arena; sand starts about y=35")
for h, area, depth in out[::6]:
    print(f"{h:5.1f} h  dug {area:6d} px ({area / a0:4.2f} of final)  deepest y {depth}")
