"""One centreline panel per parameter set, all at the same time, to pick the planform."""
import sys, numpy as np
from PIL import Image
from meander import River
from lines import panel
out, steps = sys.argv[1], int(sys.argv[2]); ims = []
for spec in sys.argv[3:]:
    kw = eval("dict(%s)" % spec); r = River(fields=False, **kw)
    for _ in range(steps): r.step()
    st = r.stats(); sizes = np.array([c[3] for c in r.cutlog]) * r.ds
    lab = f"{spec} | sinu {st['sinuosity']} cuts {st['cuts']} peak {st['peak']} mean {st['mean']} loop median {np.median(sizes) if len(sizes) else 0:.0f} W  y {st['ymin']}..{st['ymax']} crossings {r.crossings()}"
    print(lab); ims.append(panel(r, 6, lab))
sheet = Image.new("RGB", (ims[0].width, sum(i.height for i in ims))); y = 0
for i in ims: sheet.paste(i, (0, y)); y += i.height
sheet.save(out)
