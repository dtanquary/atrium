"""The app's snapshots beside the mock-up tiles Dave chose from, and the look in numbers against tile H.

    python3 compare.py <folder of snapshots> <out.jpg>

The folder holds the render test's pictures under these names (heat-size.png), each made with
SNAPSHOT_DEFAULTS="blackhole.heat=<heat>,blackhole.size=<size>" SNAPSHOT_SCENE="Black Hole" swift test --filter everySceneRenders:
Orange-1.0, White-gold-1.0, Blue-white-1.0, Orange-1.46, Orange-0.657. Needs numpy and Pillow.
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
D = os.path.dirname(os.path.abspath(__file__)) + '/'
FONT = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 20)
def tile(name):
    if name in 'ADE':
        im = Image.open(D + 'sheet1.jpg'); n = 'ABCDEF'.index(name); s = im.size[0] / 1952
        x, y = 8 + (n % 3) * 648, 8 + (n // 3) * 440
        return im.crop((round(x * s), round(y * s), round((x + 640) * s), round((y + 400) * s))).resize((800, 500), Image.LANCZOS)
    if name in 'GHI':
        im = Image.open(D + 'sheet2-sizes.jpg'); n = 'GHI'.index(name); s = im.size[0] / 2432
        x = 8 + n * 808
        return im.crop((round(x * s), round(8 * s), round((x + 800) * s), round(508 * s))).resize((800, 500), Image.LANCZOS)
    im = Image.open(D + 'sheet3-sky.jpg'); s = im.size[0] / 976
    return im.crop((round(8 * s), round(8 * s), round(968 * s), round(608 * s))).resize((800, 500), Image.LANCZOS)
def mine(path):
    im = Image.open(path).convert('RGB'); w, h = im.size
    im = im.resize((800, round(800 * h / w)), Image.LANCZOS); top = (im.size[1] - 500) // 2
    return im.crop((0, top, 800, top + 500))
rows = [("A  mock-up: orange, close", 'A', "the app: Orange, size 1.5", 'Orange-1.46.png'),
        ("D  mock-up: white-gold (tilted 80, close)", 'D', "the app: White-gold, size 1", 'White-gold-1.0.png'),
        ("E  mock-up: blue-white (tilted 80, close)", 'E', "the app: Blue-white, size 1", 'Blue-white-1.0.png'),
        ("G  mock-up: close", 'G', "the app: size 1.5", 'Orange-1.46.png'),
        ("H  mock-up: medium (hole off centre)", 'H', "the app: size 1, the default", 'Orange-1.0.png'),
        ("I  mock-up: small", 'I', "the app: size 0.65", 'Orange-0.657.png'),
        ("K  mock-up: the sky Dave picked", 'K', "the app: Orange, size 1", 'Orange-1.0.png')]
cap = 34
sheet = Image.new('RGB', (2 * 800 + 3 * 8, len(rows) * (500 + cap) + 8), (14, 14, 16))
d = ImageDraw.Draw(sheet)
for n, (a, t, b, f) in enumerate(rows):
    y = 8 + n * (500 + cap)
    sheet.paste(tile(t), (8, y)); sheet.paste(mine(sys.argv[1] + '/' + f), (816, y))
    d.text((12, y + 504), a, fill=(225, 225, 230), font=FONT); d.text((820, y + 504), b, fill=(225, 225, 230), font=FONT)
sheet.save(sys.argv[2], quality=88)
print(sheet.size)


# The look in numbers, tile H beside the app's default, both 800 x 500.
for name, pic in [("mock-up H", tile('H')), ("the app", mine(sys.argv[1] + '/Orange-1.0.png'))]:
    a = np.asarray(pic).astype(float) / 255
    luma = a @ [0.2126, 0.7152, 0.0722]
    disc = (a[..., 0] > 0.25) & (a[..., 0] > a[..., 2] * 1.25)                      # the orange disc: red well over blue
    fine = luma - np.asarray(Image.fromarray((luma * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(4))).astype(float) / 255
    ys, xs = disc.nonzero()
    far = ~disc & (np.hypot(*np.meshgrid(np.arange(800) - xs.mean(), np.arange(500) - ys.mean())) > 260)
    # the disc's widest row, and boxes along it either side of the hole: the side coming toward us over the side going away
    row = int(ys.mean()) - 40 + int(a[int(ys.mean()) - 40:int(ys.mean()) + 40].max(axis=2).mean(axis=1).argmax())
    lit = np.nonzero(a[row - 3:row + 4].mean(axis=0).max(axis=1) > 0.43)[0]
    mid, half = (lit.min() + lit.max()) / 2, (lit.max() - lit.min()) / 2
    left = luma[row - 3:row + 4, int(mid - 0.85 * half):int(mid - 0.3 * half)].mean()
    right = luma[row - 3:row + 4, int(mid + 0.3 * half):int(mid + 0.85 * half)].mean()
    print(f"{name}: the disc's luma at its 10th, 50th, 90th, 99th percentile {np.percentile(luma[disc], [10, 50, 90, 99]).round(2)}; "
          f"fine contrast {fine[disc].std():.3f}; approaching over receding {left / right:.2f}; empty sky's median luma {np.median(luma[far]):.3f}")
