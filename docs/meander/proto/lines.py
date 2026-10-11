"""Quick look: the centreline at several times, stacked, to judge the planform before any fields."""
import sys, numpy as np
from PIL import Image, ImageDraw
from meander import River

def panel(r, scale=8, label=""):
    w, h = int(r.L * scale), int(r.sy * scale)
    im = Image.new("RGB", (w, h), (18, 24, 38)); d = ImageDraw.Draw(im)
    d.rectangle([r.pad * scale, 0, (r.pad + r.sx) * scale, h - 1], outline=(60, 70, 90))
    cx, cy, _ = r.closed()
    for k in (-1, 0, 1):
        d.line([((x + k * r.L + r.pad) * scale, y * scale) for x, y in zip(cx, cy)], fill=(150, 200, 255), width=scale, joint="curve")
    d.text((6, 4), label, fill=(255, 255, 255))
    return im

if __name__ == "__main__":
    out = sys.argv[1]; kw = eval("dict(%s)" % (sys.argv[2] if len(sys.argv) > 2 else ""))
    times = kw.pop("times", [1000, 3000, 6000, 12000, 24000, 48000])
    r = River(fields=False, **kw); ims = []
    for n in range(1, max(times) + 1):
        r.step()
        if n in times:
            st = r.stats(); ims.append(panel(r, 5, f"step {n}  {st}  crossings {r.crossings()}")); print(st)
    sizes = np.array([c[3] for c in r.cutlog]) * r.ds
    print("loop arc lengths (W): median %.1f  10%% %.1f  90%% %.1f  n=%d" % (np.median(sizes), np.percentile(sizes, 10), np.percentile(sizes, 90), len(sizes)))
    sheet = Image.new("RGB", (ims[0].width, sum(i.height for i in ims)))
    y = 0
    for i in ims: sheet.paste(i, (0, y)); y += i.height
    sheet.save(out)
