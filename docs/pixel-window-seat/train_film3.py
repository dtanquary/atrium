"""The four more sceneries moving, side by side, in real time at 48 km/h: python3 train_film3.py [day|sunset|night]
Also lays six frames of each, half a second apart, out as a strip to look at: train-strip3-<time>.png."""
import multiprocessing as mp, os, subprocess, sys, time
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import train, train_scenery

FPS, SECONDS, X0 = 30, 12, 74000.0
WHEN = sys.argv[1] if len(sys.argv) > 1 else "day"
FONT = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
OUT = f"{train.OUT}/film3-{WHEN}"


def pane(kind, n):
    v = 48 / 3.6
    return train_scenery.view(kind, WHEN, X0 + v * n / FPS, v, poles=True, t=n / FPS).astype(np.uint8)


def frame(n):
    panes = []
    for kind in train_scenery.KINDS:
        im = Image.fromarray(pane(kind, n)).resize((train.PW * 2, train.PH * 2), Image.NEAREST)
        ImageDraw.Draw(im).text((12, 8), kind, fill=(255, 255, 255), font=FONT, stroke_width=2, stroke_fill=(20, 30, 60))
        panes.append(np.asarray(im))
    Image.fromarray(np.concatenate([np.concatenate(panes[:2], axis=1), np.concatenate(panes[2:], axis=1)], axis=0)).save(f"{OUT}/f{n:04d}.png")


if __name__ == "__main__":
    t = time.time()
    os.makedirs(OUT, exist_ok=True)
    strip = np.concatenate([np.concatenate([pane(kind, k * FPS // 2) for k in range(6)], axis=1) for kind in train_scenery.KINDS], axis=0)
    Image.fromarray(strip).save(f"{train.OUT}/train-strip3-{WHEN}.png")
    with mp.get_context("fork").Pool(8) as p:
        p.map(frame, range(FPS * SECONDS), chunksize=4)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{OUT}/f%04d.png",
                    "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "14", f"{train.OUT}/train-film3-{WHEN}.mp4"], check=True)
    print("took", round(time.time() - t, 1), "s")
