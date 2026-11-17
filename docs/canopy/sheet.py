"""Renders Canopy's mock-up sheets, after Kelp Forest's: python3 sheet.py <sheet name> [out dir].

Each tile is drawn by mock.swift (SpriteKit's SKRenderer, as the app draws) at a 14-inch desktop's size at 2x and
written at half that (the desktop in points), then scaled down to a 640 x 400 tile lettered with its caption and a
second line of its measurements: GPU and CPU time a frame at 3024 x 1964, and the brightest of R, G and B at desktop
size (median, 99th, 99.9th percentile) with the share of hard edges. `stats <sheet>` prints them as a Markdown table;
`fetch` downloads the HDRIs (Poly Haven, CC0) each into its own new directory; a `desk` sheet is one tile at full size
under a menu bar and folders; a `film` is H.264 at half size, its frames piped from mock.swift with none on disk.
"""
import json, os, subprocess, sys, tempfile, time
from multiprocessing.pool import ThreadPool as Pool
from PIL import Image, ImageDraw, ImageFont
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)  # run with python3 -I: only this folder, never the downloads'
from variants import SHEETS, HDRIS, HDRI_DIR
TMP = os.path.join(tempfile.gettempdir(), "canopy-frames")
MOCK = os.path.join(tempfile.gettempdir(), "canopy-mock")
TW, TH = 640, 400
FONT = "/System/Library/Fonts/Helvetica.ttc"


def build():
    src = os.path.join(HERE, "mock.swift")
    if not os.path.exists(MOCK) or os.path.getmtime(MOCK) < os.path.getmtime(src):
        subprocess.run(["swiftc", "-O", src, "-o", MOCK], check=True)


def fetch():
    """Each HDRI into its own new directory, as untrusted data."""
    import urllib.request
    for name, res in HDRIS:
        d = os.path.join(HDRI_DIR, name)
        path = os.path.join(d, f"{name}_{res}.hdr")
        if os.path.exists(path):
            continue
        os.makedirs(d, exist_ok=True)
        url = f"https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/{res}/{name}_{res}.hdr"
        req = urllib.request.Request(url, headers={"User-Agent": "atrium-mockup"})
        with urllib.request.urlopen(req) as r, open(path, "wb") as f:
            f.write(r.read())


def one(job):
    label, kw = job
    out = os.path.join(TMP, "".join(c for c in label if c.isalnum())[:40] + ".png")
    r = subprocess.run([MOCK, json.dumps({**kw, "out": out})], check=True, capture_output=True, text=True)
    stats = json.loads(r.stdout.split("STATS ")[-1])
    img = Image.open(out).convert("RGB")
    stats.update(measure(img))
    return label, img, stats


def measure(img):
    """The brightest of R, G and B at each pixel at desktop size, out of 255: median, 99th, 99.9th percentile and max;
    and the hard edges, the share of pixels more than 24 from the pixel 2 px away at 1,200 px (the look research's)."""
    a = np.asarray(img.resize((1512, 982), Image.LANCZOS)).max(axis=2).astype(float).ravel()
    b = np.asarray(img.resize((1200, 779), Image.LANCZOS)).max(axis=2).astype(float)
    edge = (np.abs(b[:, 2:] - b[:, :-2])[:-2, :] > 24) | (np.abs(b[2:, :] - b[:-2, :])[:, :-2] > 24)
    return {"med": int(np.percentile(a, 50)), "p99": int(np.percentile(a, 99)), "p999": int(np.percentile(a, 99.9)),
            "max": int(a.max()), "edges": round(100 * float(edge.mean()), 1)}


def line(st, sky=False):
    if "med" not in st:
        return ""
    cost = f"GPU {st['gpu']:.2f} / CPU {st['cpu']:.2f} ms  ·  " if st.get("gpu") else ""
    s = f"{cost}median {st['med']}, 99th {st['p99']}, 99.9th {st['p999']}  ·  edges {st['edges']}%"
    return s + (f"  ·  sky {round(100 * st['sky'])}%" if sky and "sky" in st else "")


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
    d.text((img.width - 150, 4), "Mon 16 Nov  16:30", fill=(235, 235, 235), font=font)
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


def film(name, out):
    """12 s at 30 fps in real time, H.264 at half size; the frames are piped, never written."""
    _, kw = SHEETS[name][0]
    w, h = int(kw["width"]), int(kw["height"])
    mock = subprocess.Popen([MOCK, json.dumps({**kw, "out": "-"})], stdout=subprocess.PIPE)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", f"{w}x{h}", "-r", str(kw.get("fps", 30)),
                    "-i", "-", "-c:v", "libx264", "-crf", "30", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
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
    with Pool(min(3, len(jobs))) as p:
        tiles = p.map(one, jobs)
    with open(os.path.join(TMP, name + ".json"), "w") as f:
        json.dump([(label, st) for label, _, st in tiles], f)
    for label, _, st in tiles:
        print(f"| {label} | {st.get('med')} | {st.get('p99')} | {st.get('p999')} | {st.get('max')} | {st.get('edges')}% | "
              f"{st.get('gpu', '-')} | {st.get('cpu', '-')} | {st.get('bake', '-')} | {round(100 * st['sky']) if 'sky' in st else '-'}% |")
    sky = name.startswith("sheet2")
    if name.endswith(("desk", "desk-autumn")):
        label, img, st = tiles[0]
        desktop(img)
        caption(img, label, line(st))
        img.save(f"{out}/{name}.jpg", quality=90)
    else:
        cols = 3 if len(tiles) > 4 else 2
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * TW + (cols + 1) * 8, rows * (TH + 8) + 8), (40, 40, 44))
        for n, (label, img, st) in enumerate(tiles):
            img = img.resize((TW, TH), Image.LANCZOS)
            caption(img, label, line(st, sky))
            sheet.paste(img, (8 + (n % cols) * (TW + 8), 8 + (n // cols) * (TH + 8)))
        sheet.save(f"{out}/{name}.jpg", quality=90)
    print(name, "took", round(time.time() - t, 1), "s")
