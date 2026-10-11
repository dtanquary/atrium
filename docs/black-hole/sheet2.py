"""Sheet 2: the size slider's range (stills), and the disc turning at three speeds (a short film)."""
import multiprocessing as mp, os, subprocess, sys, time
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import bh

OUT = os.environ.get("BH_OUT", ".")
FONT = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
SKY = "starmap_gal_8k"
SIZES = [("G  Close", dict(fov=40)), ("H  Medium", dict(fov=56)), ("I  Small, in a wide sky", dict(fov=78))]
CENTRE = (0.57, 0.47)


def size_tile(job):
    label, kw = job
    return label, bh.render(800, 500, incl=84, centre=CENTRE, sky=SKY, sky_gain=0.5 if kw["fov"] > 50 else 0.4, **kw)


BUF = None
SPEEDS = [(60, "inner edge round every minute"), (180, "every 3 minutes"), (600, "every 10 minutes")]
FPS, SECONDS = 20, 14


def frame(n):
    panes = []
    for period, label in SPEEDS:
        a = Image.fromarray(bh.shade(BUF, t=n / FPS, period=period, sky_gain=0.45))
        ImageDraw.Draw(a).text((12, a.height - 34), label, fill=(230, 230, 235), font=FONT)
        panes.append(np.asarray(a))
    Image.fromarray(np.concatenate(panes, axis=1)).save(f"{OUT}/film/f{n:04d}.png")


if __name__ == "__main__":
    t = time.time()
    ctx = mp.get_context("fork")
    if "stills" in sys.argv:
        with ctx.Pool(3) as p:
            tiles = p.map(size_tile, SIZES)
        sheet = Image.new("RGB", (3 * 800 + 4 * 8, 500 + 48), (14, 14, 16))
        d = ImageDraw.Draw(sheet)
        for n, (label, a) in enumerate(tiles):
            x = 8 + n * 808
            sheet.paste(Image.fromarray(a), (x, 8))
            Image.fromarray(a).save(f"{OUT}/sheet2-{label[0]}.png")
            d.text((x + 4, 516), label, fill=(225, 225, 230), font=FONT)
        sheet.save(f"{OUT}/sheet2-sizes.png")
    if "film" in sys.argv:
        os.makedirs(f"{OUT}/film", exist_ok=True)
        BUF = bh.trace(640, 400, incl=84, fov=50, centre=(0.5, 0.48), sky=SKY)
        with ctx.Pool(8) as p:
            p.map(frame, range(FPS * SECONDS), chunksize=4)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{OUT}/film/f%04d.png",
                        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "15", f"{OUT}/sheet2-speeds.mp4"], check=True)
    print("took", round(time.time() - t, 1), "s")
