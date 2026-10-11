"""Looks at the train moving: reads a film written by the test `trainFilmsItself` (the pane's own art pixels, frame
by frame), measures how things move between frames, and lays frames out as a strip to look at.

    TRAIN_FILM=/tmp/f.bin TRAIN_FILM_FPS=30 TRAIN_FILM_SECONDS=6 TRAIN_FILM_DEFAULTS="seat.previewTime=1,seat.previewHour=23" \\
      swift test -c release -Xswiftc -enable-testing --filter trainFilmsItself
    python3 docs/pixel-window-seat/train_strips.py /tmp/f.bin [strip.png [every [rows-from-top:rows-to]]]

What it reports:
- lamps (pixels of the lamp's own colour, after dark): for each one in a frame, how far along its row it is in the
  next. A lamp that moved more than a pixel jumped more than its own width. One found nowhere within 3 went behind
  something or off the edge. (Two lamps side by side can count as one that stayed and one that moved.)
- the pole: where its two-pixel column stands in each frame, and so how far it steps.
- how much of the picture changes between frames, in the sky, round the horizon and in the near field.
"""
import sys
import numpy as np
from PIL import Image

LAMPS = [(255, 204, 128), (255, 214, 150), (222, 232, 255), (255, 172, 94), (255, 88, 72), (118, 230, 212)]  # warm, and a city's others


def load(path):
    with open(path, "rb") as f:
        w, h, n, fps = f.readline().split()
        w, h, n = int(w), int(h), int(n)
        raw = np.frombuffer(f.read(), dtype=np.uint8).reshape(n, h, w, 4)
    return raw[:, ::-1, :, :3], float(fps)  # rows from the top


def grown(mask, by):
    out = mask.copy()
    for dy in range(-by, by + 1):
        for dx in range(-by, by + 1):
            out |= np.roll(np.roll(mask, dy, 0), dx, 1)
    return out


def measure(frames, fps):
    n, h, w, _ = frames.shape
    hy = round(h * 0.7)
    lamp = np.zeros(frames.shape[:3], bool)
    for c in LAMPS:
        lamp |= (frames == c).all(-1)
    print(f"{n} frames of {w} x {h} at {fps:g} a second; lamp pixels in a frame: {lamp.sum((1, 2)).min()} to {lamp.sum((1, 2)).max()}")
    if lamp.any():
        # A lamp slides left along its own row. Where is it a frame later: the same pixel, or 1, 2 or 3 to the left?
        # If nowhere, something has come in front of it (the pole, a tree), or it has left the pane.
        moved = np.zeros(5, int)
        for t in range(n - 1):
            a, b = lamp[t].copy(), lamp[t + 1]
            a[:, :4] = False  # (about to leave at the left edge)
            for d in range(4):
                near = a & np.roll(b, d, axis=1)
                moved[d] += near.sum()
                a &= ~near
            moved[4] += a.sum()
        total = moved.sum()
        print(f"  a lamp, a frame later, along its row: the same pixel {moved[0] / total:.1%}, 1 px on {moved[1] / total:.2%}, 2 px on {moved[2] / total:.3%} ({moved[2]}), "
              f"3 px on {moved[3] / total:.3%} ({moved[3]}), hidden or gone {moved[4] / total:.2%} ({moved[4]} of {total})")
    # the pole: its darkest full-height column pair, by day or night, found as the column whose pixels above the
    # horizon equal the pixel at its own foot
    xs = []
    for t in range(n):
        f = frames[t]
        col = (f[hy - 40: hy + 20] == f[hy - 40: hy - 39]).all(-1).all(0) & ((f[hy - 40] != f[hy - 40, 3]).any(-1))
        idx = np.flatnonzero(col)
        xs.append(int(idx[0]) if 1 <= len(idx) <= 4 else None)
    steps = [a - b for a, b in zip(xs, xs[1:]) if a is not None and b is not None and 0 < a - b < 60]
    if steps:
        print(f"  the pole steps {min(steps)} to {max(steps)} px a frame ({np.mean(steps):.2f} on average, {np.mean(steps) * fps:.0f} px a second); in view in {sum(x is not None for x in xs)} of {n} frames")
    change = (frames[1:] != frames[:-1]).any(-1)
    for name, y0, y1 in (("sky", 0, hy - 50), ("round the horizon", hy - 50, hy + 10), ("near field", hy + 16, h)):
        part = change[:, y0:y1]
        print(f"  {name}: {part.mean():.1%} of its pixels change from one frame to the next (most in one frame {part.mean((1, 2)).max():.1%})")


if __name__ == "__main__":
    frames, fps = load(sys.argv[1])
    measure(frames, fps)
    if len(sys.argv) > 2:
        every = int(sys.argv[3]) if len(sys.argv) > 3 else 1
        y0, y1 = (int(v) for v in sys.argv[4].split(":")) if len(sys.argv) > 4 else (0, frames.shape[1])
        pick = frames[::every][:12, y0:y1]
        strip = np.concatenate(list(pick), axis=0)
        Image.fromarray(strip).resize((strip.shape[1] * 3, strip.shape[0] * 3), Image.NEAREST).save(sys.argv[2])
