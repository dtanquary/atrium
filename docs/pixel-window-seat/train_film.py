"""The train view moving at two speeds, side by side, in real time: python3 train_film.py"""
import multiprocessing as mp, os, subprocess, time
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import train

FPS, SECONDS, SCALE, X0 = 30, 14, 3, 52000.0
SPEEDS = [(48, "48 km/h, a slow scenic train"), (80, "80 km/h")]
FONT = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
CAB = None


def frame(n):
    panes = []
    for kmh, label in SPEEDS:
        v = kmh / 3.6
        pic = train.view("day", X0 + v * n / FPS, v)
        out = np.zeros((train.CH, train.CW, 3))
        out[train.PY0: train.PY0 + train.PH, train.PX0: train.PX0 + train.PW] = pic
        al = CAB[..., 3:4] / 255.0
        a = np.clip(out * (1 - al) + CAB[..., :3] * al, 0, 255).astype(np.uint8)[:train.CH]
        im = Image.fromarray(a).resize((train.CW * SCALE, a.shape[0] * SCALE), Image.NEAREST)
        ImageDraw.Draw(im).text((70, 46), label, fill=(255, 255, 255), font=FONT, stroke_width=2, stroke_fill=(20, 30, 60))
        panes.append(np.asarray(im))
    Image.fromarray(np.concatenate(panes, axis=1)).save(f"{train.OUT}/film/f{n:04d}.png")


if __name__ == "__main__":
    t = time.time()
    os.makedirs(f"{train.OUT}/film", exist_ok=True)
    CAB = train.carriage("day", "plain")
    with mp.get_context("fork").Pool(8) as p:
        p.map(frame, range(FPS * SECONDS), chunksize=4)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{train.OUT}/film/f%04d.png",
                    "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "14", f"{train.OUT}/train-speeds.mp4"], check=True)
    print("took", round(time.time() - t, 1), "s")
