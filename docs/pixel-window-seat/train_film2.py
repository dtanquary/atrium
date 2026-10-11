"""The train view moving with a lake, with poles and in rain, side by side, in real time: python3 train_film2.py"""
import multiprocessing as mp, os, subprocess, time
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import train

FPS, SECONDS, X0 = 30, 14, 52000.0
FONT = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
SCALE = 2
PANES = [("a lake beside the line", "day", "sill", dict(scenery="lake")),
         ("poles and wires 28 m out", "day", "sill", dict(poles=True)),
         ("rain at dusk", "dusk", "table", dict(cover=0.62, rain=1.0))]
CABS = {}


def frame(n):
    panes = []
    v = 48 / 3.6
    for label, time, kind, kw in PANES:
        pic = train.reflections(train.view(time, X0 + v * n / FPS, v, t=n / FPS, **kw), time, kind)
        out = np.zeros((train.CH, train.CW, 3))
        out[train.PY0: train.PY0 + train.PH, train.PX0: train.PX0 + train.PW] = pic
        cab = CABS[(time, kind)]
        al = cab[..., 3:4] / 255.0
        a = np.clip(out * (1 - al) + cab[..., :3] * al, 0, 255).astype(np.uint8)[:train.CH]
        im = Image.fromarray(a).resize((train.CW * SCALE, a.shape[0] * SCALE), Image.NEAREST)
        ImageDraw.Draw(im).text((48, 30), label, fill=(255, 255, 255), font=FONT, stroke_width=2, stroke_fill=(20, 30, 60))
        panes.append(np.asarray(im))
    Image.fromarray(np.concatenate(panes, axis=1)).save(f"{train.OUT}/film2/f{n:04d}.png")


if __name__ == "__main__":
    t = time.time()
    os.makedirs(f"{train.OUT}/film2", exist_ok=True)
    CABS = {(tm, k): train.carriage(tm, k) for _, tm, k, _ in PANES}
    with mp.get_context("fork").Pool(8) as p:
        p.map(frame, range(FPS * SECONDS), chunksize=4)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{train.OUT}/film2/f%04d.png",
                    "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "14", f"{train.OUT}/train-film2.mp4"], check=True)
    print("took", round(time.time() - t, 1), "s")
