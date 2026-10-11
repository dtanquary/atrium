"""How far the Mamoré moved between NASA Earth Observatory's 1985 and 2014 Landsat views (29 years).
Segments the open channel (bright, sandy water and bars) in a corridor around the river in both images,
then reports its width, how much of the 1985 channel is still channel in 2014, and the mean distance from
1985's centreline pixels to the nearest 2014 channel, all in channel widths."""
import numpy as np
from PIL import Image, ImageFilter, ImageDraw
R = "refs/"
a85 = Image.open(R + "eo-mamore-1985-landsat5.jpg").convert("RGB")
a14 = Image.open(R + "eo-mamore-2014-landsat8.jpg").convert("RGB")
W, H = a85.size
def channel(im, lo):
    a = np.asarray(im, dtype=np.float32)
    luma = a @ np.array([0.2126, 0.7152, 0.0722])
    green = a[..., 1] - (a[..., 0] + a[..., 2]) / 2            # vegetation is green; water and sand are not
    m = (luma > lo) & (green < 22)
    return np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(5))) > 0
# corridor: a fat polyline down the main stem (sheet coordinates x2.5 = image pixels), wide enough for 2 belts
pts = [(190, 0), (300, 250), (370, 420), (390, 600), (420, 760), (460, 900), (500, 1200)]
cor = Image.new("L", (W, H), 0)
ImageDraw.Draw(cor).line([(x * 2.5, y * 2.5) for x, y in pts], fill=255, width=300)
cor = np.asarray(cor) > 0
m85, m14 = channel(a85, 150) & cor, channel(a14, 150) & cor
def width(m):
    """Erode until half the area is gone: a ribbon w wide loses 2 px of width a step, so w = 4 k."""
    a0, cur = m.sum(), m.copy()
    for k in range(1, 60):
        cur = cur & np.roll(cur, 1, 0) & np.roll(cur, -1, 0) & np.roll(cur, 1, 1) & np.roll(cur, -1, 1)
        if cur.sum() < a0 / 2: return 4 * k
    return 240
w85, w14 = width(m85), width(m14)
print(f"channel share of corridor 1985 {m85.sum()/cor.sum():.1%}, 2014 {m14.sum()/cor.sum():.1%}; width ~{w85:.0f} px (1985), ~{w14:.0f} px (2014) of {W}")
both = (m85 & m14).sum()
print(f"of the 1985 channel, {both/m85.sum():.0%} is still channel in 2014; of the 2014 channel, {both/m14.sum():.0%} was channel in 1985")
# distance from each 1985 channel pixel to the nearest 2014 channel pixel, by repeated dilation (cheap, coarse)
d = np.full(m85.shape, 999, np.int16); cur = m14.copy(); d[cur] = 0
for k in range(1, 121):
    cur = cur | np.roll(cur, 1, 0) | np.roll(cur, -1, 0) | np.roll(cur, 1, 1) | np.roll(cur, -1, 1)
    d[cur & (d == 999)] = k
dd = d[m85]
w = (w85 + w14) / 2
print(f"1985 channel pixels now outside the 2014 channel sit a median {np.median(dd[dd>0]):.0f} px (90th pct {np.percentile(dd[dd>0],90):.0f} px) from it: "
      f"{np.median(dd[dd>0])/w:.2f} and {np.percentile(dd[dd>0],90)/w:.2f} channel widths in 29 years")
Image.fromarray(np.dstack([m85 * 255, m14 * 200, m14 * 255]).astype(np.uint8)).resize((W // 2, H // 2)).save("work/mamore-change.png")
