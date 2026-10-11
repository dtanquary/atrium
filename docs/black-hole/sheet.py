"""Renders a sheet of labelled mock-up tiles in parallel: python3 sheet.py <name>."""
import os, sys, time
from multiprocessing import Pool
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import bh

OUT = os.environ.get("BH_OUT", ".")
TW, TH = 640, 400
SHEETS = {
    "sheet1": [
        ("A  Nearly edge on (84°), orange", dict(incl=84, fov=40)),
        ("B  Tilted (72°), orange", dict(incl=72, fov=40)),
        ("C  From above (38°), orange", dict(incl=38, fov=44)),
        ("D  White-gold disc (a cooler, sunlike gas)", dict(incl=80, fov=40, T_peak=6200, exposure=1.7)),
        ("E  Blue-white disc (true colour of a quasar's)", dict(incl=80, fov=40, T_peak=15000, exposure=1.5)),
        ("F  Small in a wide Milky Way, off centre", dict(incl=79, fov=78, centre=(0.63, 0.46), sky_gain=0.6, roll=-8)),
    ],
}


def one(job):
    label, kw = job
    return label, bh.render(TW, TH, **kw)


if __name__ == "__main__":
    name = sys.argv[1]
    t = time.time()
    jobs = SHEETS[name]
    with Pool(min(6, len(jobs))) as p:
        tiles = p.map(one, jobs)
    cols = 3
    rows = (len(tiles) + cols - 1) // cols
    cap = 40
    sheet = Image.new("RGB", (cols * TW + (cols + 1) * 8, rows * (TH + cap) + 8), (14, 14, 16))
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 21)
    d = ImageDraw.Draw(sheet)
    for n, (label, a) in enumerate(tiles):
        x = 8 + (n % cols) * (TW + 8)
        y = 8 + (n // cols) * (TH + cap)
        sheet.paste(Image.fromarray(a), (x, y))
        Image.fromarray(a).save(f"{OUT}/{name}-{label[0]}.png")
        d.text((x + 4, y + TH + 8), label, fill=(225, 225, 230), font=font)
    sheet.save(f"{OUT}/{name}.png")
    print("took", round(time.time() - t, 1), "s")
