"""Renders Seismograph's mock-up sheets, after Canopy's: python3 -P sheet.py <sheet name> [out dir].

Each tile is drawn by mock.swift (SpriteKit's SKRenderer on Etching's own ground, as the app draws) at a 14-inch
desktop's size at 2x, then scaled down to a 640 x 400 tile with its caption in a strip below, and a second line of its
measurements: GPU time a frame at 3024 x 1964, and the brightest of R, G and B at desktop size (median, 99th, 99.9th
percentile). A `desk` sheet is one tile at full size under a menu bar and folders; a `film` is H.264 at half size, its
frames piped from mock.swift with none on disk. The traces are made by traces.py from real stations' records.
"""
import json, os, subprocess, sys, tempfile, time
from multiprocessing.pool import ThreadPool as Pool
from PIL import Image, ImageDraw, ImageFont
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from variants import SHEETS
TMP = os.path.join(tempfile.gettempdir(), "seismo-frames")
MOCK = os.path.join(tempfile.gettempdir(), "seismo-mock")
TW, TH = 640, 400
CH = 52  # the caption's strip under a tile
FONT = "/System/Library/Fonts/Helvetica.ttc"


def build():
    """mock.swift is compiled as main.swift beside LineRoute.swift, whose grain tile is Etching's ground."""
    src = os.path.join(HERE, "mock.swift")
    if not os.path.exists(MOCK) or os.path.getmtime(MOCK) < os.path.getmtime(src):
        os.makedirs(os.path.join(TMP, "src"), exist_ok=True)
        main = os.path.join(TMP, "src", "main.swift")
        with open(src) as a, open(main, "w") as b:
            b.write(a.read())
        subprocess.run(["swiftc", "-O", main, os.path.join(HERE, "../../Sources/LineRoute/LineRoute.swift"), "-o", MOCK], check=True)


def one(job):
    label, kw = job
    out = os.path.join(TMP, "".join(c for c in label if c.isalnum())[:40] + ".png")
    r = subprocess.run([MOCK, json.dumps({**kw, "out": out})], check=True, capture_output=True, text=True)
    stats = json.loads(r.stdout.split("STATS ")[-1])
    img = Image.open(out).convert("RGB")
    stats.update(measure(img))
    return label, img, stats


def measure(img):
    """The brightest of R, G and B at each pixel at desktop size, out of 255: median, 99th, 99.9th percentile, max."""
    a = np.asarray(img.resize((1512, 982), Image.LANCZOS)).max(axis=2).astype(float).ravel()
    return {"med": int(np.percentile(a, 50)), "p99": int(np.percentile(a, 99)), "p999": int(np.percentile(a, 99.9)), "max": int(a.max())}


def line(st):
    return f"GPU {st['gpu']:.2f} ms  ·  median {st['med']}, 99th {st['p99']}, 99.9th {st['p999']}" if "med" in st else ""


def caption(img, text, sub=""):
    """The tile's letter and words in its bottom-left corner over a soft shade, its measurements above them (desk)."""
    d = ImageDraw.Draw(img, "RGBA")
    font, small = ImageFont.truetype(FONT, 19), ImageFont.truetype(FONT, 13)
    w = max(d.textlength(text, font=font), d.textlength(sub, font=small) if sub else 0)
    top = img.height - (54 if sub else 34)
    d.rectangle((0, top, w + 20, img.height), fill=(0, 0, 0, 150))
    if sub:
        d.text((10, top + 5), sub, fill=(205, 205, 210), font=small)
    d.text((10, img.height - 28), text, fill=(232, 232, 236), font=font)


def under(img, text, sub=""):
    """The tile with its letter and words in a strip below it, so nothing of the sheet is covered."""
    out = Image.new("RGB", (img.width, img.height + CH), (40, 40, 44))
    out.paste(img, (0, 0))
    d = ImageDraw.Draw(out)
    d.text((10, img.height + 6), text, fill=(232, 232, 236), font=ImageFont.truetype(FONT, 19))
    if sub:
        d.text((10, img.height + 32), sub, fill=(170, 170, 176), font=ImageFont.truetype(FONT, 13))
    return out


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
    d.text((img.width - 150, 4), "Wed 18 Nov  14:30", fill=(235, 235, 235), font=font)
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
        d.text((x + 32 - tw / 2, y + 68), name, fill=(40, 40, 40) if img.getpixel((x + 32, y + 75))[0] > 128 else (240, 240, 240), font=small)


def film(name, out):
    """The variant's frames at 30 fps, H.264 at half size; the frames are piped, never written."""
    _, kw = SHEETS[name][0]
    kw = dict(kw)
    w, h = int(kw.get("width", 1512) * 2), int(kw.get("height", 982) * 2)
    crop = kw.pop("crop", None)  # x, y, w, h in device pixels, kept at 1:1; else the whole screen at half size
    vf = f"crop={crop[2]}:{crop[3]}:{crop[0]}:{crop[1]}" if crop else "scale=iw/2:-2"
    mock = subprocess.Popen([MOCK, json.dumps({**kw, "out": "-"})], stdout=subprocess.PIPE)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "bgra", "-s", f"{w}x{h}", "-r", str(kw.get("fps", 30)),
                    "-i", "-", "-vf", vf, "-c:v", "libx264", "-crf", "29", "-preset", "slow", "-pix_fmt", "yuv420p",
                    "-movflags", "+faststart", f"{out}/{name}.mp4"], stdin=mock.stdout, check=True)
    mock.wait()


if __name__ == "__main__":
    build()
    os.makedirs(TMP, exist_ok=True)
    name, out = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else HERE)
    t = time.time()
    if name.startswith("film"):
        film(name, out)
        print(name, "took", round(time.time() - t, 1), "s")
        sys.exit()
    jobs = SHEETS[name]
    with Pool(min(3, len(jobs))) as p:
        tiles = p.map(one, jobs)
    for label, _, st in tiles:
        print(f"| {label} | {st.get('med')} | {st.get('p99')} | {st.get('p999')} | {st.get('max')} | {st.get('gpu')} |")
    if name.endswith("desk"):
        label, img, st = tiles[0]
        img = img.resize((1512, 982), Image.LANCZOS)
        desktop(img)
        caption(img, label, line(st))
        img.save(f"{out}/{name}.jpg", quality=90)
    else:
        cols = 3 if len(tiles) > 4 else 2
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * TW + (cols + 1) * 8, rows * (TH + CH + 8) + 8), (40, 40, 44))
        for n, (label, img, st) in enumerate(tiles):
            img = under(img.resize((TW, TH), Image.LANCZOS), label, line(st))
            sheet.paste(img, (8 + (n % cols) * (TW + 8), 8 + (n // cols) * (TH + CH + 8)))
        sheet.save(f"{out}/{name}.jpg", quality=90)
    print(name, "took", round(time.time() - t, 1), "s")
