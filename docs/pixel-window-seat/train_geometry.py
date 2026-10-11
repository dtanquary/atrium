"""Train-window geometry on Pixel Window Seat's pane. Arithmetic only; mirrors PixelWindowSeat.swift:106-112.
A level camera square to the track: a point Z m out from the track moves f*v/Z px/s whatever its height;
flat ground d rows under the horizon is Z = H*f/d away and a pixel of it spans H/d m along the track."""
import math

W, H_CANVAS = 378, 246
def pane(pct):
    gw, gh = max(W * pct // 100, 16), max(H_CANVAS * pct // 100, 16)
    if pct < 100:
        gw = min(gw, gh * 8 // 5); gh = min(gh, gw * 29 // 20)
    return gw, gh
PANES = {"Small": pane(60), "Medium": pane(76), "Large": pane(90), "None": pane(100)}
SPEEDS = [40, 80, 120, 200]  # km/h
FPS = 30

def check():
    assert PANES["Large"] == (340, 221) and PANES["Medium"] == (287, 186), PANES  # the doc's numbers
    gw, gh = PANES["Medium"]; f = gh * 1.2; hz = gh * 62 // 100
    d = hz - 0.5 + gh * 0.04
    assert abs(11 / d * 1000 - 90) < 2 and abs(11 * f / d - 20) < 0.5  # doc: nearest row 20 km off at 90 m a pixel
check()

gw, gh = PANES["Large"]; f = gh * 1.2
print(f"panes {PANES}; Large focal {f:.1f} px; half-height angle {math.degrees(math.atan(gh/2/f)):.1f} deg, half-width {math.degrees(math.atan(gw/2/f)):.1f} deg")

print("\n== A. By distance (any eye height): px/s = f*v/Z ; a thing h m tall stands h*f/Z px ; pane is gw*Z/f m wide there ==")
print(f"{'Z m':>7} {'px per m':>8} {'pane m':>8} | " + " | ".join(f"{s:>3} km/h px/s  px/fr  cross s" for s in SPEEDS))
for Z in [3, 5, 8, 12, 20, 35, 50, 75, 100, 150, 200, 300, 500, 800, 1200, 2000, 4000, 8000, 15000, 30000, 60000]:
    cells = []
    for s in SPEEDS:
        v = s / 3.6; pps = f * v / Z
        cells.append(f"{pps:12.1f} {pps/FPS:6.2f} {gw/pps:8.1f}")
    print(f"{Z:7d} {f/Z:8.3f} {gw*Z/f:8.0f} | " + " | ".join(cells))

print("\n== B. Distance at which a thing moves 1, 4, 16 px a frame at 30 fps (m) ; and 3, 10 px/s (airliner-calm) ==")
print(f"{'km/h':>5} {'1 px/fr':>8} {'4 px/fr':>8} {'16 px/fr':>8} {'10 px/s':>8} {'3.6 px/s':>8}")
for s in SPEEDS + [20, 30, 60]:
    v = s / 3.6
    print(f"{s:5d} {f*v/30:8.0f} {f*v/120:8.0f} {f*v/480:8.0f} {f*v/10:8.0f} {f*v/3.6:8.0f}")

def rows(Heye, ground_rows, label):
    print(f"\n== C. Flat ground by row, eye {Heye} m up, {ground_rows} rows of ground ({label}) ==")
    print(f"{'d':>4} {'Z m':>8} {'m/px':>7} | " + " | ".join(f"{s:>3}: px/s  px/fr" for s in SPEEDS))
    for d in [1, 2, 3, 4, 5, 6, 8, 10, 15, 20, 30, 45, 65, 90, 110, ground_rows]:
        if d > ground_rows: continue
        print(f"{d:4d} {Heye*f/d:8.1f} {Heye/d:7.3f} | " + " | ".join(f"{s/3.6*d/Heye:9.1f} {s/3.6*d/Heye/FPS:6.2f}" for s in SPEEDS))
    for s in SPEEDS:
        v = s / 3.6
        over = [sum(1 for d in range(1, ground_rows + 1) if v * d / Heye / FPS > k) for k in (1, 4, 16)]
        print(f"  {s:3d} km/h: of {ground_rows} rows, {over[0]} move >1 px/frame, {over[1]} >4, {over[2]} >16 (first row over 1 px/frame: d={math.floor(FPS*Heye/v)+1})")

rows(3.0, gh * 62 // 100, "horizon 62% up, as the airliner")
rows(4.5, gh * 62 // 100, "horizon 62% up, as the airliner")
rows(3.0, gh * 40 // 100, "horizon 40% up")
rows(30.0, gh * 62 // 100, "a line along a hillside, 30 m above the valley floor")
rows(60.0, gh * 62 // 100, "a viaduct or a high hillside, 60 m up")

print("\n== D. What a sill hides: eye e m from the glass, sill s m below the eye, eye Heye above the ground ==")
for Heye in (3.0, 4.5):
    for e, s in [(0.45, 0.25), (0.6, 0.35), (0.6, 0.5), (0.9, 0.45)]:
        dep = math.atan(s / e); Z = Heye / math.tan(dep); d = f * math.tan(dep)
        print(f"  eye {Heye} m, {e} m from glass, sill {s} m below eye: looks down {math.degrees(dep):4.1f} deg, nearest ground {Z:5.1f} m, that is {d:5.0f} rows under the horizon")
print(f"  the pane itself: 137 rows under the horizon is {math.degrees(math.atan(137/f)):.1f} deg down; 88 rows is {math.degrees(math.atan(88/f)):.1f} deg")

print("\n== E. Cloud from below: base B m up, rows above the horizon ==")
for B in (1200, 2400):
    for u in (5, 10, 20, 40, 84):
        Z = B * f / u
        print(f"  base {B} m, {u:3d} rows up: {Z/1000:6.1f} km off, {B/u:6.1f} m/px, " + ", ".join(f"{s}: {s/3.6/(B/u):.2f} px/s" for s in SPEEDS))

print("\n== F. A pole line: every S m, Z m out ==")
for S, Z in [(60, 2.5), (60, 4), (60, 8), (50, 15), (50, 40), (50, 100), (50, 300)]:
    for s in (40, 80, 200):
        v = s / 3.6; pps = f * v / Z
        print(f"  S={S} Z={Z:5.1f} m {s:3d} km/h: {v/S:.2f} poles/s, each {pps:7.0f} px/s = {pps/FPS:6.1f} px/frame, in view {gw/pps*FPS:6.1f} frames, {f*S/Z:7.0f} px apart")
