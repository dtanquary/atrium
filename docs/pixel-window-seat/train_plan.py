"""More arithmetic for the train plan: the airliner's own pace for comparison, looking ahead, a ring table."""
import math
gw, gh = 340, 221; f = gh * 1.2; FPS = 30

# 1. What "calm" has meant so far: the airliner at 1x (PixelWindowSeat.swift:106-112, 177).
hz, apron, dip = gh * 62 // 100, gh // 6, gh * 0.04
d0 = hz - 0.5 + dip; dA = hz + apron - 0.5 + dip
print(f"airliner, Large: nearest visible ground {11/d0*1000:.0f} m/px -> {250/(11/d0*1000):.1f} px/s; its cloud {8.6/d0*1000:.0f} m/px -> {250/(8.6/d0*1000):.1f} px/s;"
      f" the apron's nearest cloud {250/(8.6/dA*1000):.1f} px/s; crossing {gw/(250/(11/d0*1000)):.0f} s; at 10x {2500/(8.6/dA*1000):.0f} px/s")
assert abs(250/(8.6/dA*1000) * 1.5 * 1.9 - 15) < 0.3  # doc: paints 15 times a second up to 1.9x

# 2. Looking ahead by yaw t: a point Z out, at angle a across the pane, moves f*v/Z * cos^2(t+a)/cos^2(a).
half = math.atan(gw / 2 / f)
print(f"\nlooking ahead (pane half-width {math.degrees(half):.1f} deg): speed against the side view, at the trailing edge / centre / leading edge")
for t in (0, 15, 30, 45, 60, 66, 75):
    k = [math.cos(math.radians(t) + a) ** 2 / math.cos(a) ** 2 for a in (-half, 0, half)]
    print(f"  {t:2d} deg: {k[0]:.2f} / {k[1]:.2f} / {k[2]:.2f}")

# 3. Eye height at which the pane's bottom row of flat ground moves no more than 30 px/s (so the row engine reads again)
for s in (40, 60, 80, 120):
    print(f"  {s} km/h: bottom row (137 under the horizon) is under 30 px/s from {s/3.6*137/30:.0f} m up; under 10 px/s from {s/3.6*137/10:.0f} m")

# 4. A ring table: eye 3.5 m, by speed. Standing things on rings at chosen distances.
Heye = 3.5
rings = [("verge, as streaks", 15, 0), ("verge, as streaks", 40, 0), ("lineside trees, a hedge", 110, 12), ("trees, a farm", 180, 15), ("houses, poles along a road", 300, 8),
         ("copses, a village", 500, 15), ("woods, a spire", 900, 30), ("low rise, pylons", 1800, 40), ("near hills", 3500, 120), ("hills", 7000, 300),
         ("far hills", 15000, 800), ("mountains", 30000, 2500), ("far range", 60000, 3500)]
print(f"\nrings, eye {Heye} m, Large pane: Z, rows under horizon, px per m, thing height -> px, px/s at 40/60/80/120 km/h")
for name, Z, tall in rings:
    sp = " ".join(f"{f*s/3.6/Z:7.1f}" for s in (40, 60, 80, 120))
    print(f"  {name:28s} {Z:6d} m  d={Heye*f/Z:6.2f}  {f/Z:7.4f} px/m  {tall:5d} m -> {tall*f/Z:5.1f} px | {sp}")

# 5. Rain on the glass: a drop's path. Air along the glass ~ train speed; a bead's own fall a few cm/s to ~1 m/s
#    once it runs. Slope from horizontal = atan(fall / drag-driven sideways speed): left as a tunable, shown for scale.
for s in (0, 40, 80, 120):
    for fall, k in [(0.3, 0.02)]:
        side = k * s / 3.6
        print(f"  rain bead at {s:3d} km/h: runs {math.degrees(math.atan2(fall, side)):4.0f} deg below level (fall {fall} m/s, sideways {side:.2f} m/s: a guess, to be set from footage)")

# 6. Paint cost, scaled from the doc's own figure: 1.3 ms to paint the Large pane's 75,140 px every frame.
per = 1.3e-3 / (gw * gh)
print(f"\nthe airliner's painting is {per*1e9:.0f} ns a pixel (1.3 ms / {gw*gh}); None is {378*246} px -> {per*378*246*1e3:.2f} ms")
for hzn in (0.62, 0.45, 0.40):
    ground = int(gh * hzn) * gw
    print(f"  horizon {int(hzn*100)}% up: {ground} px of ground and standing things, {gw*gh-ground} px of sky and cloud")
print(f"memory: 13 rings x {gw} columns x 4 bytes = {13*gw*4/1024:.0f} KB; ground band 100 rows x {gw} x 1 = {100*gw/1024:.0f} KB; cloud rows {84*gw*2/1024:.0f} KB; picture and sky {2*gw*gh*4/1024:.0f} KB")
