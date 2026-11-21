"""Renders Beehive's mock-up sheets, after Canopy's: python3 -I sheet.py <sheet name> [out dir].

Each tile is drawn by mock.swift (SpriteKit's SKRenderer, as the app draws) at a 14-inch desktop's size at 2x and
written at half that (the desktop in points), then scaled down to a 640 x 400 tile lettered with its caption and a
second line of its measurements: GPU and CPU time a frame at 3024 x 1964, the brightest of R, G and B at desktop size
(median, 99th, 99.9th percentile), the share of hard edges, and the black holes (empty cells whose floor is more than
twice as dark as their rim) among the empty cells showing. A crop (sheet 4) is the screen's own pixels at 2x. `fetch`
downloads the USGS bee photograph into its own new directory; a `desk` sheet is one tile at full size under a menu
bar and folders; a `film` is H.264 at half the desktop's size, its frames piped from mock.swift with none on disk; a
`motion` sheet is strips of frames two seconds apart.
"""
import json, os, subprocess, sys, tempfile, time
from multiprocessing.pool import ThreadPool as Pool
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)  # run with python3 -I: only this folder, never the downloads'
sys.dont_write_bytecode = True  # no __pycache__ beside the docs
from variants import SHEETS, PHOTO, PHOTO_DIR, WOOD
TMP = os.path.join(tempfile.gettempdir(), "beehive-frames")
MOCK = os.path.join(tempfile.gettempdir(), "beehive-mock")
TW, TH = 640, 400
WOOD_URL = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/coated_pine_02/coated_pine_02_diff_2k.jpg"
FONT = "/System/Library/Fonts/Helvetica.ttc"
COMMONS = ("https://commons.wikimedia.org/w/api.php?action=query&prop=imageinfo&iiprop=url&iiurlwidth=1920&format=json&titles=File:"
           "Apis_mellifera,_light_body,_back,_beltsville,_md_2017-05-26-15.12_(34886290922).jpg")


def build():
    src = os.path.join(HERE, "mock.swift")
    if not os.path.exists(MOCK) or os.path.getmtime(MOCK) < os.path.getmtime(src):
        subprocess.run(["swiftc", "-O", src, "-o", MOCK], check=True)


def fetch():
    """The USGS Bee Inventory and Monitoring Lab's worker from above (Public Domain Mark 1.0), and Poly Haven's
    coated_pine_02 for the stack's bars (CC0, polyhaven.com/license), into their own directory."""
    import urllib.request, urllib.parse
    os.makedirs(PHOTO_DIR, exist_ok=True)
    head = {"User-Agent": "atrium-mockup/1.0"}
    if not os.path.exists(WOOD):
        with urllib.request.urlopen(urllib.request.Request(WOOD_URL, headers=head)) as r, open(WOOD, "wb") as f:
            f.write(r.read())
    if os.path.exists(PHOTO):
        return
    with urllib.request.urlopen(urllib.request.Request(urllib.parse.quote(COMMONS, safe=":/?&=,"), headers=head)) as r:
        url = list(json.load(r)["query"]["pages"].values())[0]["imageinfo"][0]["thumburl"]
    with urllib.request.urlopen(urllib.request.Request(url, headers=head)) as r, open(PHOTO, "wb") as f:
        f.write(r.read())


def measure(img, desk=True):
    """The brightest of R, G and B at each pixel at desktop size, out of 255: median, 99th, 99.9th percentile and max;
    and the hard edges, the share of pixels more than 24 from the pixel 2 px away at 1,200 px (the look research's)."""
    a = np.asarray(img.resize((1512, 982), Image.LANCZOS) if desk else img).max(axis=2).astype(float).ravel()
    b = np.asarray(img.resize((1200, 779), Image.LANCZOS)).max(axis=2).astype(float)
    edge = (np.abs(b[:, 2:] - b[:, :-2])[:-2, :] > 24) | (np.abs(b[2:, :] - b[:-2, :])[:, :-2] > 24)
    return {"med": int(np.percentile(a, 50)), "p99": int(np.percentile(a, 99)), "p999": int(np.percentile(a, 99.9)),
            "max": int(a.max()), "edges": round(100 * float(edge.mean()), 1)}


def one(job):
    label, kw = job
    out = os.path.join(TMP, "".join(c for c in label if c.isalnum())[:40] + ".png")
    r = subprocess.run([MOCK, json.dumps({**kw, "out": out})], check=True, capture_output=True, text=True)
    stats = json.loads(r.stdout.split("STATS ")[-1])
    img = Image.open(out).convert("RGB")
    stats.update(measure(img, not kw.get("full")))
    os.remove(out)
    return label, img, stats


def line(st):
    if "med" not in st:
        return ""
    s = f"GPU {st['gpu']:.2f} / CPU {st['cpu']:.2f} ms  ·  median {st['med']}, 99th {st['p99']}, 99.9th {st['p999']}  ·  edges {st['edges']}%"
    return s + (f"  ·  holes {st['black']}/{st['empty']}" if "black" in st else "")


def caption(img, text, sub=""):
    """The tile's letter and words, in its bottom-left corner over a soft shade, with its measurements under them."""
    d = ImageDraw.Draw(img, "RGBA")
    font, small = ImageFont.truetype(FONT, 19), ImageFont.truetype(FONT, 13)
    w = max(d.textlength(text, font=font), d.textlength(sub, font=small) if sub else 0)
    top = img.height - (54 if sub else 34)
    d.rectangle((0, top, w + 20, img.height), fill=(0, 0, 0, 150))
    if sub:
        d.text((10, top + 5), sub, fill=(205, 205, 210), font=small)
    d.text((10, img.height - 28), text, fill=(232, 232, 236), font=font)


def desktop(img, clock="Wed 18 Nov  15:00"):
    """A menu bar and a column of folders down the right, as a desktop has them."""
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((0, 0, img.width, 24), fill=(20, 20, 24, 110))
    bold, font = ImageFont.truetype(FONT, 14, index=1), ImageFont.truetype(FONT, 14)
    d.text((40, 4), "Finder", fill=(240, 240, 240), font=bold)
    x = 40 + d.textlength("Finder", font=bold) + 22
    for word in ("File", "Edit", "View", "Go", "Window", "Help"):
        d.text((x, 4), word, fill=(235, 235, 235), font=font)
        x += d.textlength(word, font=font) + 20
    d.text((img.width - 150, 4), clock, fill=(235, 235, 235), font=font)
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
    """12 s at 30 fps in real time, H.264 at half the desktop's size; the frames are piped, never written."""
    _, kw = SHEETS[name][0]
    k = kw.get("down", 4)
    w, h = int(kw["width"] * 2 // k), int(kw["height"] * 2 // k)
    mock = subprocess.Popen([MOCK, json.dumps({**kw, "out": "-"})], stdout=subprocess.PIPE)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", f"{w}x{h}", "-r", str(kw.get("fps", 30)),
                    "-i", "-", "-vf", "crop=trunc(iw/2)*2:trunc(ih/2)*2", "-c:v", "libx264", "-crf", "28", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
                    f"{out}/{name}.mp4"], stdin=mock.stdout, check=True)
    mock.wait()


def moments(name, out):
    """Rows of whole desktops at moments of a change, each its own still, each row its caption and each frame its clock."""
    rows = SHEETS[name]
    jobs = [(f"{r}{c}", kw) for r, (_, cells) in enumerate(rows) for c, kw in cells]
    with Pool(3) as p:
        done = p.map(one, jobs)
    fw, fh = 300, 195
    cols = max(len(cells) for _, cells in rows)
    sheet = Image.new("RGB", (cols * (fw + 4) + 4, len(rows) * (fh + 40) + 4), (40, 40, 44))
    d = ImageDraw.Draw(sheet)
    font, small = ImageFont.truetype(FONT, 19), ImageFont.truetype(FONT, 13)
    n = 0
    for r, (label, cells) in enumerate(rows):
        y = 4 + r * (fh + 40)
        d.text((8, y + 6), label, fill=(232, 232, 236), font=font)
        for c, (clock, _) in enumerate(cells):
            _, img, st = done[n]
            n += 1
            sheet.paste(img.resize((fw, fh), Image.LANCZOS), (4 + c * (fw + 4), y + 36))
            d.rectangle((4 + c * (fw + 4), y + 36 + fh - 22, 4 + c * (fw + 4) + 150, y + 36 + fh), fill=(0, 0, 0))
            d.text((10 + c * (fw + 4), y + 36 + fh - 19), f"{clock}  ·  median {st['med']}", fill=(220, 220, 225), font=small)
            print(f"| {label[:1]} {clock} | {st['med']} | {st['p99']} | {st['p999']} | {st['max']} | {st['edges']}% | {st.get('black')} / {st.get('empty')} |")
    sheet.save(f"{out}/{name}.jpg", quality=88)


def strips(name, out):
    """Rows of frames a few seconds apart, each row its caption and each frame its time: motion judged from strips."""
    rows = []
    for label, kw in SHEETS[name]:
        stem = os.path.join(TMP, "".join(c for c in label if c.isalnum())[:40])
        subprocess.run([MOCK, json.dumps({**kw, "out": stem})], check=True, capture_output=True)
        paths = [f"{stem}-{i:03d}.png" for i in range(len(kw["times"]))]
        rows.append((label, kw["times"], [Image.open(p).convert("RGB") for p in paths]))
        for p in paths:
            os.remove(p)
    fw, fh = rows[0][2][0].size
    cols = max(len(r[2]) for r in rows)
    sheet = Image.new("RGB", (cols * (fw + 4) + 4, len(rows) * (fh + 40) + 4), (40, 40, 44))
    d = ImageDraw.Draw(sheet)
    font, small = ImageFont.truetype(FONT, 19), ImageFont.truetype(FONT, 13)
    for r, (label, times, frames) in enumerate(rows):
        y = 4 + r * (fh + 40)
        d.text((8, y + 6), label, fill=(232, 232, 236), font=font)
        for c, (t, f) in enumerate(zip(times, frames)):
            sheet.paste(f, (4 + c * (fw + 4), y + 36))
            d.text((8 + c * (fw + 4), y + 38 + fh - 18), f"{t - times[0]:.0f} s", fill=(200, 200, 205), font=small)
    sheet.save(f"{out}/{name}.jpg", quality=90)


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
    elif name.endswith("motion"):
        strips(name, out)
    elif name.endswith("change"):
        moments(name, out)
    else:
        jobs = SHEETS[name]
        with Pool(min(3, len(jobs))) as p:
            tiles = p.map(one, jobs)
        with open(os.path.join(TMP, name + ".json"), "w") as f:
            json.dump([(label, st) for label, _, st in tiles], f)
        for label, _, st in tiles:
            print(f"| {label} | {st['med']} | {st['p99']} | {st['p999']} | {st['max']} | {st['edges']}% | {st.get('black', '-')} / {st.get('empty', '-')} "
                  f"| {st.get('gpu', '-')} | {st.get('cpu', '-')} | {st.get('bees', '-')} | {st.get('walking', '-')} |")
        if name.endswith("desk"):
            label, img, st = tiles[0]
            desktop(img, SHEETS[name][0][1].get("clock", "Wed 18 Nov  15:00"))
            caption(img, label, line(st))
            img.save(f"{out}/{name}.jpg", quality=88)
        else:
            cols = 3 if len(tiles) > 4 else 2
            rows = (len(tiles) + cols - 1) // cols
            sheet = Image.new("RGB", (cols * TW + (cols + 1) * 8, rows * (TH + 8) + 8), (40, 40, 44))
            for n, (label, img, st) in enumerate(tiles):
                img = img.resize((TW, TH), Image.LANCZOS)
                caption(img, label, line(st))
                sheet.paste(img, (8 + (n % cols) * (TW + 8), 8 + (n // cols) * (TH + 8)))
            sheet.save(f"{out}/{name}.jpg", quality=88)
    print(name, "took", round(time.time() - t, 1), "s")
