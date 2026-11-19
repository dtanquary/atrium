"""Renders a sheet of labelled mock-up tiles in parallel, after Jellyfish's: python3 sheet.py <name> [out dir].

Each tile is drawn by mock.swift (SpriteKit, as the app draws) from the variant's settings in SHEETS, at a 14-inch
desktop's size and scaled down to the tile, unless the variant asks for a smaller piece of the screen. A `desk`
sheet is one tile at full size with a menu bar and a few folder icons over it, since a small tile flatters. A variant
with an `image` is a picture cropped to the tile (Black Hole, for comparison). Each tile's luma (median, 99th, 99.9th,
max) at desktop size goes into brightness.txt beside this file.
"""
import json, os, subprocess, sys, tempfile, time
from multiprocessing.pool import ThreadPool as Pool
from PIL import Image, ImageDraw, ImageFont
from variants import SHEETS

TMP = os.path.join(tempfile.gettempdir(), "saturn-tiles")
MOCK = os.path.join(tempfile.gettempdir(), "saturn-mock")
HERE = os.path.dirname(os.path.abspath(__file__))

TW, TH = 640, 400
FONT = "/System/Library/Fonts/Helvetica.ttc"


def one(job):
    label, kw = job
    if "image" in kw:
        img = Image.open(os.path.join(HERE, kw["image"])).convert("RGB")
        h = int(img.width * TH / TW)
        return label, img.crop((0, (img.height - h) // 2, img.width, (img.height - h) // 2 + h)), None
    out = os.path.join(TMP, "".join(c for c in label if c.isalnum())[:40] + ".png")
    run = subprocess.run([MOCK, json.dumps({**kw, "out": out})], check=True, capture_output=True, text=True)
    return label, Image.open(out).convert("RGB"), json.loads(run.stdout.strip().splitlines()[-1])


def note(name, tiles):
    """Rewrites this sheet's lines in brightness.txt: each tile's luma at desktop size against the look report's caps."""
    path = os.path.join(HERE, "brightness.txt")
    keep = [l for l in open(path)] if os.path.exists(path) else ["# sheet\ttile\tmedian\t99th\t99.9th\tmax\texposure   (caps: median 30-45, 99th 170, 99.9th 195, max 215)\n"]
    keep = [l for l in keep if not l.startswith(name + "\t")]
    for label, _, s in tiles:
        if s:
            keep.append(f"{name}\t{label.split()[0]}\t{s['median']}\t{s['p99']}\t{s['p999']}\t{s['max']}\t{s['exposure']}\n")
    open(path, "w").writelines(keep)


def caption(img, text):
    """The tile's letter and words, in its bottom-left corner over a soft shade, as the menu's tiles are named."""
    d = ImageDraw.Draw(img, "RGBA")
    font = ImageFont.truetype(FONT, 19)
    w = d.textlength(text, font=font)
    d.rectangle((0, img.height - 34, w + 20, img.height), fill=(0, 0, 0, 150))
    d.text((10, img.height - 28), text, fill=(232, 232, 236), font=font)


def desktop(img):
    """A menu bar and a column of folders down the right, as a desktop has them."""
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((0, 0, img.width, 24), fill=(20, 20, 24, 110))
    bold, font = ImageFont.truetype(FONT, 14, index=1), ImageFont.truetype(FONT, 14)
    d.text((40, 4), "Finder", fill=(240, 240, 240), font=bold)
    x = 40 + d.textlength("Finder", font=bold) + 22
    for word in ("File", "Edit", "View", "Go", "Window", "Help"):
        d.text((x, 4), word, fill=(235, 235, 235), font=font)
        x += d.textlength(word, font=font) + 20
    d.text((img.width - 150, 4), "Sat 7 Nov  21:30", fill=(235, 235, 235), font=font)
    icon = os.path.join(tempfile.gettempdir(), "atrium-folder.png")
    if not os.path.exists(icon):
        subprocess.run(["sips", "-s", "format", "png", "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericFolderIcon.icns",
                        "--resampleWidth", "64", "--out", icon], capture_output=True)
    folder = Image.open(icon).convert("RGBA")
    small = ImageFont.truetype(FONT, 12)
    for n, name in enumerate(("Projects", "Screenshots", "Invoices 2026", "Photos")):
        x, y = img.width - 100, 50 + n * 100
        img.paste(folder, (x, y), folder)
        tw = d.textlength(name, font=small)
        d.text((x + 32 - tw / 2, y + 68), name, fill=(240, 240, 240), font=small)


def strips(name, out):
    """Rows of frames of one jelly through time, each row its caption and each frame its time: motion judged from strips."""
    rows = []
    for label, kw in SHEETS[name]:
        stem = os.path.join(TMP, "".join(c for c in label if c.isalnum())[:40])
        subprocess.run([MOCK, json.dumps({**kw, "out": stem})], check=True)
        frames = [Image.open(f"{stem}-{i:03d}.png").convert("RGB") for i in range(len(kw["times"]))]
        rows.append((label, kw["times"], [f.resize((f.width // 2, f.height // 2), Image.LANCZOS) for f in frames]))
    fw, fh = rows[0][2][0].size
    cols = max(len(r[2]) for r in rows)
    sheet = Image.new("RGB", (cols * (fw + 4) + 4, len(rows) * (fh + 40) + 4), (40, 40, 44))
    d = ImageDraw.Draw(sheet)
    font, small = ImageFont.truetype(FONT, 19), ImageFont.truetype(FONT, 15)
    for r, (label, times, frames) in enumerate(rows):
        y = 4 + r * (fh + 40)
        d.text((8, y + 6), label, fill=(232, 232, 236), font=font)
        for c, (t, f) in enumerate(zip(times, frames)):
            sheet.paste(f, (4 + c * (fw + 4), y + 36))
            d.text((10 + c * (fw + 4), y + 40 + fh - 22), f"{t - times[0]:.1f} s", fill=(200, 200, 205), font=small)
    sheet.save(f"{out}/{name}.jpg", quality=90)


def film(name, out):
    """A film of the variant at 30 fps, in real time, as H.264 for any Mac to play."""
    label, kw = SHEETS[name][0]
    stem = os.path.join(TMP, name)
    subprocess.run([MOCK, json.dumps({**kw, "out": stem})], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(kw.get("fps", 30)), "-i", f"{stem}-%04d.png",
                    "-c:v", "libx264", "-crf", "27", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
                    f"{out}/{name}.mp4"], check=True)


if __name__ == "__main__":
    name, out = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.abspath(__file__)))
    t = time.time()
    desk = name.endswith("desk")
    os.makedirs(TMP, exist_ok=True)
    if name.startswith("film"):
        film(name, out)
        print(name, "took", round(time.time() - t, 1), "s")
        sys.exit()
    if name.endswith("motion"):
        strips(name, out)
        print(name, "took", round(time.time() - t, 1), "s")
        sys.exit()
    with Pool(min(3, len(SHEETS[name]))) as p:
        tiles = p.map(one, SHEETS[name])
    note(name, tiles)
    if desk:
        label, img, _ = tiles[0]
        img = img.resize((1512, 982), Image.LANCZOS)
        desktop(img)
        caption(img, label)
        img.save(f"{out}/{name}.jpg", quality=90)
    else:
        cols = 3 if len(tiles) > 4 else 2
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * TW + (cols + 1) * 8, rows * (TH + 8) + 8), (40, 40, 44))
        for n, (label, img, _) in enumerate(tiles):
            img = img.resize((TW, TH), Image.LANCZOS)
            caption(img, label)
            sheet.paste(img, (8 + (n % cols) * (TW + 8), 8 + (n // cols) * (TH + 8)))
        sheet.save(f"{out}/{name}.jpg", quality=90)
    print(name, "took", round(time.time() - t, 1), "s")
