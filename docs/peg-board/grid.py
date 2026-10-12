"""grid.py <image> <x0,y0,x1,y1 px> <out prefix> [pitch guess] [light]: fits the net of squares inside a box of a
charted pattern (an old needlework chart) and reads every square, for docs/peg-board/cut.py to take a square to a hole.
Prints the net as cut.py wants it, `net=(x, y, ax, ay, bx, by)`: the middle of the box's first square and the
steps to the next square across and down, in the image's own pixels, so a page that sits a little crooked is
followed. Writes <out prefix>.png, the box with a dot on every square's middle (red where it read as filled), to
check the fit by eye at the box's two ends, and <out prefix>.npy and -dark.npy, what it read. A fifth word reads
the light squares as the pattern and lets the net be less square (a woodcut's white dots on black).
Needs numpy and Pillow."""
import sys
import numpy as np
from PIL import Image, ImageDraw
Image.MAX_IMAGE_PIXELS = None

def fit(dark, guess, slack=0.04):
    """The net's two steps and a square's middle, from the box's darkness (0 light to 1 dark). The lines across the
    page beat down it: that beat is found first, near the guessed pitch, to a fraction of a pixel. The net is taken
    to be nearly square, so the beat across is looked for only within `slack` of the same pitch and 1.5 degrees of square to it
    (a pattern's own repeats are often stronger than the net's lines, and were mistaken for them)."""
    h, w = dark.shape
    win = np.hanning(h)[:, None] * np.hanning(w)[None, :]
    pad = (4 * h, 4 * w)
    F = np.fft.fft2((dark - dark.mean()) * win, s=pad)
    mag = np.abs(F)
    FX, FY = np.meshgrid(np.fft.fftfreq(pad[1]), np.fft.fftfreq(pad[0]))
    r = np.hypot(FX, FY)
    def peak(mask):
        iy, ix = np.unravel_index(np.argmax(np.where(mask, mag, 0)), mag.shape)
        def refine(a, b, c): return 0.5 * (a - c) / (a - 2 * b + c)   # a parabola through the peak and its neighbours
        dy = refine(mag[iy - 1, ix], mag[iy, ix], mag[(iy + 1) % pad[0], ix]); dx = refine(mag[iy, ix - 1], mag[iy, ix], mag[iy, (ix + 1) % pad[1]])
        return np.array([FX[iy, ix] + dx / pad[1], FY[iy, ix] + dy / pad[0]]), np.angle(F[iy, ix])
    down, pd = peak((r > 1 / (guess * 1.35)) & (r < 1.35 / guess) & (np.abs(FX) < 0.2 * np.abs(FY)) & (FY > 0))
    f0 = np.hypot(*down); want = np.array([down[1], -down[0]]) / f0           # square to it, pointing across
    cos = (FX * want[0] + FY * want[1]) / np.maximum(r, 1e-9)
    across, pa = peak((np.abs(r - f0) < slack * f0) & (cos > np.cos(np.radians(1.5))))
    A = np.linalg.inv(np.array([across, down]))                               # columns: the step across and the step down
    # the lines are dark, so darkness goes as cos(2 pi f.x + phase): a line is where that angle is 0, a square's middle half a turn on
    centre = A @ np.array([(np.pi - pa) / (2 * np.pi), (np.pi - pd) / (2 * np.pi)])
    return centre, A[:, 0], A[:, 1]

def read(page, box, centre, ax, ay):
    """Every square whose place is inside the box, as a rectangle of squares (along its middle row and column), each
    read from the whole page as the mean darkness of its middle half. `centre` is a square's middle in the page."""
    h, w = page.shape
    M = np.column_stack([ax, ay])
    mid = np.array([(box[0] + box[2]) / 2, (box[1] + box[3]) / 2])
    ci, cj = np.rint(np.linalg.solve(M, mid - centre)).astype(int)
    span = lambda step, half: int(half / np.hypot(*step))
    i0, i1 = ci - span(ax, (box[2] - box[0]) / 2), ci + span(ax, (box[2] - box[0]) / 2)
    j0, j1 = cj - span(ay, (box[3] - box[1]) / 2), cj + span(ay, (box[3] - box[1]) / 2)
    sums = np.zeros((h + 1, w + 1)); sums[1:, 1:] = page.cumsum(0).cumsum(1)
    q = 0.27 * np.hypot(*ax)
    out = np.zeros((j1 - j0 + 1, i1 - i0 + 1), np.float32)
    for j in range(j0, j1 + 1):
        for i in range(i0, i1 + 1):
            x, y = centre + i * ax + j * ay
            xa, xb, ya, yb = int(round(x - q)), int(round(x + q)) + 1, int(round(y - q)), int(round(y + q)) + 1
            out[j - j0, i - i0] = (sums[yb, xb] - sums[ya, xb] - sums[yb, xa] + sums[ya, xa]) / ((xb - xa) * (yb - ya))
    return out, centre + i0 * ax + j0 * ay

def otsu(v):
    hist, edges = np.histogram(v, 64); mid = (edges[:-1] + edges[1:]) / 2
    w0 = hist.cumsum(); w1 = w0[-1] - w0; m0 = (hist * mid).cumsum(); m1 = m0[-1] - m0
    k = np.argmax(w0[:-1] * w1[:-1] * (m0[:-1] / np.maximum(w0[:-1], 1) - m1[:-1] / np.maximum(w1[:-1], 1)) ** 2)
    return edges[k + 1]

if __name__ == "__main__":
    box = [int(v) for v in sys.argv[2].split(",")]; guess = float(sys.argv[4]) if len(sys.argv) > 4 else 17
    whole = Image.open(sys.argv[1]).convert("RGB")
    page = 1 - np.asarray(whole.convert("L"), np.float32) / 255
    centre, ax, ay = fit(page[box[1]:box[3], box[0]:box[2]], guess, 0.12 if len(sys.argv) > 5 else 0.04)
    cells, first = read(page, box, centre + [box[0], box[1]], ax, ay)
    t = otsu(cells); filled = (cells < t) if len(sys.argv) > 5 else (cells > t)        # a fifth word: the light squares are the pattern
    print("squares %d x %d; net=(%.1f, %.1f, %.3f, %.3f, %.3f, %.3f); threshold %.2f; %d filled; %.1f%% of squares within 0.08 of the threshold"
          % (filled.shape[1], filled.shape[0], *first, *ax, *ay, t, filled.sum(), 100 * (np.abs(cells - t) < 0.08).mean()))
    over = whole.crop(box); d = ImageDraw.Draw(over)
    for j in range(filled.shape[0]):
        for i in range(filled.shape[1]):
            x, y = first + i * ax + j * ay - [box[0], box[1]]
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(255, 40, 40) if filled[j, i] else (40, 120, 255))
    over.save(sys.argv[3] + ".png")
    np.save(sys.argv[3] + ".npy", filled)
    np.save(sys.argv[3] + "-dark.npy", cells)
    print("darkness of squares, by tenths:", np.histogram(cells, 10, (0, 1))[0].tolist())
