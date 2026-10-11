"""Sets what the app's TrainWorld lays against this folder's mock-up painter, byte for byte.

    TRAIN_MATCH=/some/folder swift test --filter trainWritesItsCountry
    python3 docs/pixel-window-seat/train_match.py /some/folder

The test writes each ring's strip and the ground rows at the mock-ups' own numbers (the Large pane, focal 265, the
eye 3.5 m up, the horizon 30% up, 13.3 m/s) at a few places along the line. A strip's byte is its material, with
128 added where a lamp is.
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
print(f"{compared} bytes compared, {differed} differ")
sys.exit(1 if differed else 0)
