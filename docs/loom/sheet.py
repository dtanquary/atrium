"""Renders Loom's mock-up sheets, after Canopy's: python3 -I sheet.py <sheet name> [out dir].

Each tile is drawn by mock.swift (SpriteKit's SKRenderer, as the app draws) at a 14-inch desktop's size at 2x and
written at half that (the desktop in points, every 2 x 2 averaged), then scaled down to a 640 x 400 tile lettered with
its caption and a second line of its measurements: the mock's GPU and CPU time a frame at 3024 x 1964, the brightest
of R, G and B at desktop size (median, 99th percentile), and "busy", the look research's measure (the share of
pixels whose brightness steps more than 0.08 to a neighbour at 1,920 px across, docs/meander/measure/busy.py). A tile
with a crop is a piece at 1:1, unscaled. `fetch` downloads the Art Institute of Chicago's coverlet 66024 (CC0) into
its own new directory; a `desk` sheet is one tile at full size under a menu bar and folders; a `film` is 12 s of
H.264 at half size, its frames piped from mock.swift with none on disk.
"""
import json, os, subprocess, sys, tempfile, time
from multiprocessing.pool import ThreadPool as Pool
from PIL import Image, ImageDraw, ImageFont
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)  # run with python3 -I: only this folder, never the downloads'
from variants import SHEETS
TMP = os.path.join(tempfile.gettempdir(), "loom-frames")
MOCK = os.path.join(tempfile.gettempdir(), "loom-mock")
REF_DIR = os.path.join(tempfile.gettempdir(), "loom-ref")
TW, TH = 640, 400
FONT = "/System/Library/Fonts/Helvetica.ttc"


def build():
    src = os.path.join(HERE, "mock.swift")
    if not os.path.exists(MOCK) or os.path.getmtime(MOCK) < os.path.getmtime(src):
        subprocess.run(["swiftc", "-O", src, "-o", MOCK], check=True)


def fetch():
    """The reference coverlet, as untrusted data in its own new directory."""
    import urllib.request
    os.makedirs(REF_DIR, exist_ok=True)
    url = "https://www.artic.edu/iiif/2/e51989a6-de34-9925-7e04-23f283f28d73/full/843,/0/default.jpg"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Macintosh) atrium-mockup"})
    with urllib.request.urlopen(req) as r, open(os.path.join(REF_DIR, "aic-66024.jpg"), "wb") as f:
        f.write(r.read())


def one(job):
    label, kw = job
    if "photo" in kw:
        img = Image.open(os.path.join(REF_DIR, kw["photo"])).convert("RGB").crop(tuple(kw["box"])).resize((TW, TH), Image.LANCZOS)
        return label, img, {}
    out = os.path.join(TMP, "".join(c for c in label if c.isalnum())[:40] + ".png")
    r = subprocess.run([MOCK, json.dumps({**kw, "out": out})], check=True, capture_output=True, text=True)
    stats = json.loads(r.stdout.split("STATS ")[-1])
    img = Image.open(out).convert("RGB")
    if "crop" not in kw:
        stats.update(measure(img))
    return label, img, stats


def measure(img):
    """The brightest of R, G and B at desktop size, out of 255: median, 99th and 99.9th percentile; and busy."""
    a = np.asarray(img.resize((1512, 982), Image.LANCZOS)).max(axis=2).astype(float).ravel()
    b = np.asarray(img.resize((1920, int(1920 * img.height / img.width)), Image.LANCZOS), dtype=np.float32) / 255
    L = b @ np.array([0.2126, 0.7152, 0.0722])
    g = np.maximum(np.abs(np.diff(L, axis=0))[:, :-1], np.abs(np.diff(L, axis=1))[:-1])
    return {"med": int(np.percentile(a, 50)), "p99": int(np.percentile(a, 99)), "p999": int(np.percentile(a, 99.9)),
            "busy": round(100 * float((g > 0.08).mean()), 1)}


def line(st):
    if "gpu" not in st:
        return ""
    s = f"mock GPU {st['gpu']:.2f} / CPU {st['cpu']:.2f} ms"
    if "med" in st:
        s += f"  ·  median {st['med']}, 99th {st['p99']}  ·  busy {st['busy']}%"
    return s


def caption(img, text, sub=""):
    """The tile's letter and words in its bottom-left corner over a soft shade, its measurements above them."""
    d = ImageDraw.Draw(img, "RGBA")
    font, small = ImageFont.truetype(FONT, 19), ImageFont.truetype(FONT, 13)
    w = max(d.textlength(text, font=font), d.textlength(sub, font=small) if sub else 0)
    top = img.height - (54 if sub else 34)
    d.rectangle((0, top, w + 20, img.height), fill=(0, 0, 0, 150))
    if sub:
        d.text((10, top + 5), sub, fill=(205, 205, 210), font=small)
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
    d.text((img.width - 150, 4), "Wed 18 Nov  23:40", fill=(235, 235, 235), font=font)
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
        d.rectangle((x + 32 - tw / 2 - 4, y + 66, x + 32 + tw / 2 + 4, y + 84), fill=(0, 0, 0, 90))
        d.text((x + 32 - tw / 2, y + 68), name, fill=(240, 240, 240), font=small)


def film(name, out):
    """12 s at 30 fps in real time, H.264 at half size; the frames are piped, never written."""
    _, kw = SHEETS[name][0]
    w, h = int(kw["width"]) // 2, int(kw["height"]) // 2
    mock = subprocess.Popen([MOCK, json.dumps({**kw, "out": "-"})], stdout=subprocess.PIPE)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", f"{w}x{h}", "-r", str(kw.get("fps", 30)),
                    "-i", "-", "-c:v", "libx264", "-crf", "28", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
                    f"{out}/{name}.mp4"], stdin=mock.stdout, check=True)
    mock.wait()


if __name__ == "__main__":
    build()
    os.makedirs(TMP, exist_ok=True)
    if sys.argv[1] == "fetch":
        fetch()
        sys.exit()
    name, out = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else HERE)
    t = time.time()
    if name.startswith("film"):
        film(name, out)
        print(name, "took", round(time.time() - t, 1), "s")
        sys.exit()
    jobs = SHEETS[name]
    with Pool(1) as p:  # one at a time, so the GPU times are not each other's
        tiles = p.map(one, jobs)
    for label, _, st in tiles:
        print(f"| {label} | {st.get('med', '-')} | {st.get('p99', '-')} | {st.get('p999', '-')} | {st.get('busy', '-')}% | {st.get('gpu', '-')} |")
    if name.endswith("desk"):
        label, img, st = tiles[0]
        desktop(img)
        caption(img, label, line(st))
        img.save(f"{out}/{name}.jpg", quality=84)
    else:
        cols = 3 if len(tiles) > 4 else 2
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * TW + (cols + 1) * 8, rows * (TH + 8) + 8), (40, 40, 44))
        for n, (label, img, st) in enumerate(tiles):
            img = img.resize((TW, TH), Image.LANCZOS) if img.size != (TW, TH) else img
            caption(img, label, line(st))
            sheet.paste(img, (8 + (n % cols) * (TW + 8), 8 + (n // cols) * (TH + 8)))
        sheet.save(f"{out}/{name}.jpg", quality=84)
    print(name, "took", round(time.time() - t, 1), "s")
