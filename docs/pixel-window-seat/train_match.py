"""Sets what the app's TrainWorld lays against this folder's mock-up painter, byte for byte.

    TRAIN_MATCH=/some/folder swift test --filter trainWritesItsCountry
    python3 docs/pixel-window-seat/train_match.py /some/folder

The test writes each ring's strip and the ground rows at the mock-ups' own numbers (the Large pane, focal 265, the
eye 3.5 m up, the horizon 30% up, 13.3 m/s) at a few places along the line. A strip's byte is its material, with
128 added where a lamp is.

`trainWritesItsCarriage` writes the carriage round the pane as the bytes of its picture (red, green, blue, alpha;
alpha 0 is glass) on the mock-ups' canvas at their four hours, with the pane's top on the row its file is named
for: 12, where the mock-ups had it, and 13, where the app puts it. Each is set against `train.carriage` with the
pane on that row, and those at 12 against the tiles of the saved sheets too, wherever the carriage covers them.
"""
import glob
import os
import sys
import numpy as np
import train

folder = sys.argv[1]
compared = differed = 0
for path in sorted(glob.glob(f"{folder}/ring-*.bin")):
    _, z, x = os.path.basename(path)[:-4].split("-")
    Z, X = int(z), float(x)
    ours = np.fromfile(path, dtype=np.uint8).reshape(-1, train.PW)  # rows up from the foot
    theirs, lamps = train.ring_strip(Z, int(np.floor(X * train.FOCAL / Z)) - train.CX, train.PW, 1)
    theirs = (theirs + 128 * lamps)[::-1].astype(np.uint8)
    tall = max(len(ours), len(theirs))
    a, b = np.zeros((tall, train.PW), np.uint8), np.zeros((tall, train.PW), np.uint8)
    a[:len(ours)], b[:len(theirs)] = ours, theirs
    wrong = int((a != b).sum())
    compared, differed = compared + a.size, differed + wrong
    print(f"ring {Z:>6} m at {X:>10}: {a.size:>6} bytes, {int((b > 0).sum()):>5} of them land, {int((b > 127).sum()):>3} lamps, {wrong} differ")
for path in sorted(glob.glob(f"{folder}/ground-*.bin")):
    X = float(os.path.basename(path)[7:-4])
    hy = round(train.PH * 0.7)
    rows = train.PH - hy
    ours = np.fromfile(path, dtype=np.uint8).reshape(2, rows, train.PW)
    theirs, lift = train.ground(hy, X, 13.3)
    d = np.arange(1, rows + 1)[:, None]
    away = train.EYE * train.FOCAL / d
    ours_lift = np.where(away > 100, 0.0, (ours[1].astype(float) - 2) * np.where(away > train.VERGE_M, 0.03, 0.045) + ((d // 3) % 2) * 0.022)
    wrong = int((ours[0] != theirs).sum()) + int((np.abs(ours_lift - lift) > 1e-12).sum())
    compared, differed = compared + ours.size, differed + wrong
    print(f"ground at {X:>10}: {ours.size} bytes (materials, and the dashes' tones), {wrong} differ")
for path in sorted(glob.glob(f"{folder}/poles-*.bin")):
    X = float(os.path.basename(path)[6:-4])
    ours = np.fromfile(path, dtype=np.uint8).reshape(train.PH, train.PW)[::-1]  # rows from the top, as theirs
    blank = np.full((train.PH, train.PW, 3), 255.0)
    drawn = train.pole_line(blank.copy(), round(train.PH * 0.7), X, "day")
    theirs = np.where((drawn == [52, 44, 40]).all(-1), 2, np.where((drawn != 255).any(-1), 1, 0))
    # The build lets a pole slide in and out at the pane's edges; the mock-up drew one only once all of it was inside.
    period = 50.0 * train.FOCAL / 28.0
    n0 = int(np.floor(X * train.FOCAL / 28.0)) - train.CX
    edge = [x for k in range(int(n0 // period) - 1, int((n0 + train.PW) // period) + 2) for x in [int(round(k * period)) - n0] if not 0 <= x < train.PW - 1]
    keep = np.ones(train.PW, bool)
    for x in edge:
        keep[max(0, x - 5): max(0, x + 7)] = False
    wrong = int((ours != theirs)[:, keep].sum())
    compared, differed = compared + int(keep.sum()) * train.PH, differed + wrong
    print(f"pole line at {X:>10}: {int(keep.sum()) * train.PH} bytes, {int((theirs == 2).sum())} of them pole and {int((theirs == 1).sum())} wire, {wrong} differ")


def tiles(name, cols, which):
    """A saved sheet's tiles as art pixels, each with its carriage, its hour and its letter."""
    from PIL import Image
    sheet = np.asarray(Image.open(f"{train.HERE}/{name}.png").convert("RGB"))
    wide, tall = train.CW * 3, train.CH * 3
    return [(kind, hour, letter, sheet[8 + (k // cols) * (tall + 40):, 8 + (k % cols) * (wide + 8):][1:tall:3, 1:wide:3])
            for k, (kind, hour, letter) in enumerate(which)]


saved = tiles("train-sheet1", 3, [(kind, hour, f"{letter} by {hour}") for hour in ("day", "night") for kind, letter in (("plain", "A"), ("sill", "B"), ("table", "C"))])
saved += tiles("train-sheet2", 2, [("sill", "day", "D"), ("table", "night", "E"), ("sill", "day", "F"), ("table", "dusk", "G")])
for path in sorted(glob.glob(f"{folder}/carriage-*.bin")):
    _, kind, hour, top = os.path.basename(path)[:-4].split("-")
    ours = np.fromfile(path, dtype=np.uint8).reshape(train.CH, train.CW, 4)
    train.PY0 = int(top)
    theirs = train.carriage(hour, kind)
    train.PY0 = 12
    solid = theirs[..., 3:] > 0
    theirs = np.concatenate([np.clip(theirs[..., :3], 0, 255) * solid, theirs[..., 3:]], -1).astype(np.uint8)  # cut down to bytes as `train.compose` does
    wrong = int((ours != theirs).sum())
    compared, differed = compared + ours.size, differed + wrong
    print(f"carriage {kind:>5} at {hour:>6}, the pane {top} rows down: {ours.size} bytes, {int(solid.sum())} pixels of them carriage, {wrong} differ")
    for tiled, at, letter, tile in saved:
        if int(top) == 12 and (tiled, at) == (kind, hour):
            wrong = int((ours[..., :3] != tile)[solid[..., 0]].sum())
            compared, differed = compared + 3 * int(solid.sum()), differed + wrong
            print(f"    and the saved sheet's tile {letter}: {3 * int(solid.sum())} bytes of carriage, {wrong} differ")
print(f"{compared} bytes compared, {differed} differ")
sys.exit(1 if differed else 0)
