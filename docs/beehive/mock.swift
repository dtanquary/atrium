// Beehive mock-ups, drawn by SpriteKit's SKRenderer as the app's render test draws a wallpaper, so a tile shows what
// the app's shader and sprites can draw. Not app code: the comb's bake, its shader and the bees' rules here are the
// research's (research-method.md, research-look.md) and are meant to carry into the build.
//
//   swiftc -O mock.swift -o $TMPDIR/beehive-mock && $TMPDIR/beehive-mock '<json>'
//
// The JSON: look (amber, old, new, red, backlit), seed, hour (the farm's own hours since six, 0 to 24), width and
// height (points, drawn at 2x), out (a .png, or a prefix with times), bees (a multiplier of 0.2 a cm²), size (0 Small,
// 1 Medium, 2 Large: a cell 10, 14 or 20 points), temp (°C of the air), holds (honey, pollen, brood), frame (none, bar,
// case), atlas (photo, painted), photo (the USGS bee's JPEG), times (one picture each, seconds after the comb landed),
// frames and fps (raw frames to stdout for ffmpeg, scaled down by `down`), t (seconds after landing of the first
// frame, 60 unless given), mix (the six-o'clock dissolve: 0 the old comb, 1 the new), kept (the comb in a rasterised
// effect node, as the app would), timing, focus (walk or cell: bee 0 shown for the motion strips).
//
// Round 2's stack: stack (deep, medium: Langstroth frames stacked as an observation hive's, the day's at the bottom,
// those above baked from the days before), wood (a CC0 pine scan for the bars), change (slide, dissolve: how the stack
// moves on when the next comb starts), f (how far through the change at the first frame, 0 to 1), dur (the change's
// seconds), rate (seconds of the farm a second of film: 60 for a time-lapse), label (text drawn in the frame), clock
// (unused here: the desktop's menu bar clock).
import AppKit
import Foundation
import ImageIO
import Metal
import SpriteKit

struct Config: Decodable {
    var look: String?, seed: UInt64?, hour: Double?, width: Double?, height: Double?
    var out: String
    var bees: Double?, size: Int?, temp: Double?, holds: String?, frame: String?, atlas: String?, photo: String?
    var times: [Double]?, frames: Int?, fps: Double?, down: Int?, t: Double?, mix: Double?, kept: Bool?, timing: Bool?
    var focus: String?, still: Bool?, full: Bool?
    var stack: String?, wood: String?, change: String?, f: Double?, dur: Double?, rate: Double?, label: String?
}
let cfg = try! JSONDecoder().decode(Config.self, from: CommandLine.arguments[1].data(using: .utf8)!)
setvbuf(stdout, nil, _IONBF, 0)

let Wpt = cfg.width ?? 1512, Hpt = cfg.height ?? 982
let (W, H) = (Int(Wpt * 2), Int(Hpt * 2))
let cell = [10.0, 14.0, 20.0][cfg.size ?? 1]      // points across the flats
let ppm = cell / 5.74                               // points a millimetre: a honey cell is 5.74 mm (Yang et al. 2021)
let beeLen = 12.0 * ppm                             // a worker, 12 mm
let look = cfg.look ?? "amber"
let hour0 = cfg.hour ?? 9
let seed = cfg.seed ?? 7
let s0 = 0.25                                       // the share of the comb there at six (research-method.md §3)

// The stack, real to scale: Langstroth frames from the cut list in Blackiston's Building Beehives For Dummies
// (dummies.com, "Cut List for Langstroth Frames", checked): side bars 9-1/8" tall for a deep frame and 6-1/4" for a
// medium, top bar 3/4" thick, bottom bar 3/8"; the comb is what lies between. Between one frame's bottom bar and the
// next one's top bar, a bee space: 6.4 to 9.5 mm (Wikipedia, "Langstroth hive", checked), 8 here.
let stackKind = cfg.stack
let stacked = stackKind != nil
let topBar = 19.05 * ppm, bottomBar = 9.525 * ppm, beeSpace = 8.0 * ppm
let frameH = (stackKind == "medium" ? 158.75 : 231.775) * ppm
let combH = stacked ? frameH - topBar - bottomBar : Hpt
let pitch = frameH + beeSpace
/// The top of frame k's comb in the stack's points (the screen's, y down, before the stack moves): frame 0, the day's,
/// rests on the screen's bottom edge; 1 is yesterday's above it; -1 is the next, below the screen until the change.
func combTop(_ k: Int) -> Double { Hpt - bottomBar - combH - Double(k) * pitch }
let change = cfg.change                             // slide or dissolve
let changeDur = cfg.dur ?? 1800
let changeStart = 16.0                              // 22:00, the next comb's first cells (round 1's overnight quarter starts at hour -8)
let fStart = cfg.f ?? 0

/// SplitMix64: the same comb for the same seed.
struct Rand {
    var s: UInt64
    mutating func next() -> Double {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
    mutating func range(_ r: ClosedRange<Double>) -> Double { r.lowerBound + (r.upperBound - r.lowerBound) * next() }
}

/// The share of the comb drawn out at h hours into the farm, and the hour a share is reached (before six for the
/// quarter drawn overnight, spread over the eight hours before it).
func built(_ h: Double) -> Double { h < 0 ? s0 * max(0, 1 + h / 8) : s0 + (1 - s0) * (1 - pow(max(0, 1 - min(h, 24) / 24), 2)) }
func hourOf(_ share: Double) -> Double { share <= s0 ? -(s0 - share) / s0 * 8 : 24 * (1 - sqrt(max(0, 1 - (share - s0) / (1 - s0)))) }

// MARK: the comb's bake

/// The frame's wood, in points: top bar, sides, bottom (none edge to edge).
let inset: (top: Double, side: Double, bottom: Double) = {
    switch cfg.frame ?? "none" {
    case "bar": return (46, 30, 0)
    case "case": return (118, 64, 52)
    default: return (0, 0, 0)
    }
}()

/// The lattice's smooth bend, the same here as in the shader: up to a third of a cell over about 26 cells.
struct Warp { var a, k, p1, p2: Double }
func warp(_ x: Double, _ y: Double, _ w: Warp) -> (Double, Double) {
    (w.a * 0.5 * (sin(y * w.k + w.p1) + 0.6 * sin((x * 0.7 + y * 0.4) * w.k * 1.3 + w.p2)),
     w.a * 0.5 * (sin(x * w.k * 0.9 + w.p2) + 0.6 * sin((x * 0.5 - y * 0.8) * w.k * 1.1 + w.p1)))
}

/// Value noise for the bake (not the shader's): smooth, about `scale` points a feature.
func vnoise(_ x: Double, _ y: Double, _ scale: Double, _ salt: UInt64) -> Double {
    func h(_ i: Int, _ j: Int) -> Double { var r = Rand(s: UInt64(bitPattern: Int64(i &* 73856093 ^ j &* 19349663)) ^ salt); return r.next() }
    let (u, v) = (x / scale, y / scale)
    let (i, j) = (Int(floor(u)), Int(floor(v)))
    let (fx, fy) = (u - floor(u), v - floor(v))
    let (sx, sy) = (fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy))
    let a = h(i, j) + (h(i + 1, j) - h(i, j)) * sx, b = h(i, j + 1) + (h(i + 1, j + 1) - h(i, j + 1)) * sx
    return a + (b - a) * sy
}

/// One comb: one texel a cell for when it is drawn out (16 bits, a share of the day's building), when it fills and when
/// it is capped (hours since six, eighths, from six hours before), and a second for what it holds.
struct Comb {
    var cols = 0, rows = 0
    var map: [UInt8] = [], kind: [UInt8] = []
    var warpP = Warp(a: 0, k: 0, p1: 0, p2: 0)
    // per cell, for the bees: where it is on screen (points, y down), and its times
    var pos: [(Double, Double)] = [], share: [Double] = [], fillH: [Double] = [], capH: [Double] = [], holds: [Int] = []
    var bakeMs = 0.0

    init(seed: UInt64, w Wpt: Double = Wpt, h Hpt: Double = Hpt, inset: (top: Double, side: Double, bottom: Double) = inset) {
        let t0 = DispatchTime.now().uptimeNanoseconds
        var rnd = Rand(s: seed &* 7919 &+ 17)
        warpP = Warp(a: cell * 0.33, k: 2 * .pi / (26 * cell), p1: rnd.range(0...6.28), p2: rnd.range(0...6.28))
        cols = Int(Wpt / cell) + 4
        rows = Int(Hpt / (cell * 0.8660254)) + 4
        let n = cols * rows
        pos = Array(repeating: (0, 0), count: n); share = Array(repeating: 2, count: n)
        fillH = Array(repeating: 99, count: n); capH = Array(repeating: 99, count: n); holds = Array(repeating: 0, count: n)
        // tongues from one to three seeds along the top bar, each a little faster or later than the others
        // in a frame of the stack, wider than it is tall, a tongue for about each comb's height of top bar, so they
        // join along the bar before they reach the bottom
        let tongues = stacked ? max(2, Int((Wpt / Hpt).rounded())) + Int(rnd.next() * 1.999)
                              : Wpt > 700 ? 2 + Int(rnd.next() * 1.999) : 1 + Int(rnd.next() * 1.999)
        var seeds: [(x: Double, speed: Double, delay: Double)] = []
        for i in 0..<tongues {
            let x = inset.side + (Wpt - 2 * inset.side) * (Double(i) + rnd.range(0.25...0.75)) / Double(tongues)
            seeds.append((x, rnd.range(0.85...1.15), rnd.range(0...0.12) * Hpt))
        }
        let top = inset.top, bottom = Hpt - inset.bottom
        var arrival: [(Double, Int)] = []
        for r in 0..<rows { for c in 0..<cols {
            let i = r * cols + c
            let (lc, lr) = (Double(c - 1), Double(r - 1))
            let lx = cell * lc + (Int(lr) & 1 == 1 ? cell / 2 : 0), ly = cell * 0.8660254 * lr
            var (x, y) = (lx, ly)
            for _ in 0..<3 { let d = warp(x, y, warpP); (x, y) = (lx - d.0, ly - d.1) } // the screen point the warp brings here
            pos[i] = (x, y)
            guard x > inset.side - cell * 0.6, x < Wpt - inset.side + cell * 0.6, y > top - cell * 0.6, y < bottom + cell * 0.6 else { continue }
            // a tongue as high as it is wide, pointed and then rounding, slowing as it nears the bottom; ragged by a
            // cell or two at its edge
            let dy = max(0, y - top)
            let slow = dy + 1.6 * max(0, dy - 0.72 * (bottom - top)) * max(0, dy - 0.72 * (bottom - top)) / (bottom - top)
            var best = Double.infinity
            for s in seeds {
                let dx = x - s.x
                best = min(best, s.delay + (sqrt(dx * dx + 0.30 * slow * slow + 4 * cell * cell) + 0.22 * abs(dx) + 0.25 * slow) / s.speed)
            }
            best += (vnoise(x, y, cell * 4, seed) - 0.5) * 3 * cell + rnd.range(-0.4...0.4) * cell
            arrival.append((best, i))
        }}
        arrival.sort { $0.0 < $1.0 }
        let total = Double(arrival.count)
        let holdsKind = cfg.holds ?? "honey"
        for (rank, a) in arrival.enumerated() {
            let i = a.1, sh = Double(rank) / total
            share[i] = sh
            let (x, y) = pos[i]
            let dh = hourOf(sh)
            var kind = 0
            if holdsKind == "pollen", sh > 0.62, sh < 0.70 { kind = 1 }
            if holdsKind == "brood" {
                let (ex, ey) = ((x - Wpt * 0.5) / (Wpt * 0.30), (y - Hpt * 0.63) / (Hpt * 0.27))
                let e = sqrt(ex * ex + ey * ey)
                if e < 1 { kind = 2 } else if e < 1 + 2.6 * cell / (Hpt * 0.27) { kind = 1 }
            }
            holds[i] = kind
            // nectar from the top down and outward a few hours after the cell is drawn; the last-drawn part (the
            // bottom) stays empty all day, for the cluster
            let patch = vnoise(x, y, cell * 7, seed &+ 3)
            if stacked && sh >= 0.72 {
                // in the stack the bottom is filled too, from the evening into the next morning, and capped on the
                // comb's second day, when it has moved up: yesterday's frame closes its last patches through today
                fillH[i] = max(dh + 2.2, 12 + 8 * (sh - 0.72) / 0.28) + 1.6 * patch + rnd.range(0...0.5)
                let corner = max(0, 1 - min(hypot(x - inset.side, y - top), hypot(Wpt - inset.side - x, y - top)) / (0.55 * Wpt))
                capH[i] = fillH[i] + 1.5 + 1.2 + 3.2 * vnoise(x, y, cell * 6, seed &+ 5) - 2.2 * corner
                if rnd.next() < 0.02 { capH[i] = 99 } // a few cells are never capped
            } else if sh < 0.72 || kind != 0 {
                fillH[i] = dh + 2.2 + 1.6 * patch + rnd.range(0...0.5)
                // capped in groups, from the top corners first
                let corner = max(0, 1 - min(hypot(x - inset.side, y - top), hypot(Wpt - inset.side - x, y - top)) / (0.55 * Wpt))
                capH[i] = fillH[i] + 1.5 + 1.2 + 3.2 * vnoise(x, y, cell * 6, seed &+ 5) - 2.2 * corner
                if kind == 1 { capH[i] = 99 } // bee bread is never capped
                if kind == 2 { fillH[i] = dh + 0.5; capH[i] = dh + 1.5 + 2.5 * patch; if rnd.next() < 0.02 { capH[i] = 99 } }
                if stacked && rnd.next() < 0.02 { capH[i] = 99 }
            }
        }
        map = Array(repeating: 255, count: n * 4); kind = Array(repeating: 255, count: n * 4)
        var vr = Rand(s: seed &+ 99)
        for i in 0..<n {
            let v = share[i] > 1 ? 65535 : UInt16(min(65534, share[i] * 65535))
            map[i * 4] = UInt8(v >> 8); map[i * 4 + 1] = UInt8(v & 255)
            func enc(_ h: Double) -> UInt8 { h > (stacked ? 57 : 25) ? 255 : UInt8(max(0, min(254, ((h + 6) * (stacked ? 4 : 8)).rounded()))) }
            map[i * 4 + 2] = enc(fillH[i]); map[i * 4 + 3] = enc(capH[i])
            kind[i * 4] = UInt8(holds[i] * 80); kind[i * 4 + 1] = UInt8(vr.next() * 255); kind[i * 4 + 2] = UInt8(vr.next() * 255)
        }
        bakeMs = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6
    }

    func texture(_ bytes: [UInt8]) -> SKTexture {
        let t = SKTexture(data: Data(bytes), size: CGSize(width: cols, height: rows))
        t.filteringMode = .nearest
        return t
    }
}

// MARK: the looks (research-look.md §3), each its own shader source as the app's looks are

typealias RGB = (Double, Double, Double)
struct Palette {
    var wall: RGB, shade: RGB, fresh: RGB, nectar: RGB, glint: RGB, cap: RGB, brood: RGB
    var bread: [RGB], room: RGB, wood: RGB, bee: RGB, lamp: (Double, Double)
    var floor: RGB, honeyT: RGB // a cell's floor (orange-brown, never olive), and honey's transmittance a unit deep
}
let palettes: [String: Palette] = [
    "amber": Palette(wall: (132, 109, 67), shade: (76, 63, 39), fresh: (160, 130, 86), nectar: (116, 76, 35), glint: (184, 164, 132),
                     cap: (145, 109, 69), brood: (134, 84, 47), bread: [(149, 106, 38), (136, 91, 45), (110, 74, 50)],
                     room: (14, 10, 7), wood: (90, 63, 30), bee: (1.0, 0.86, 0.68), lamp: (1.09, 0.68), floor: (120, 86, 40), honeyT: (0.95, 0.80, 0.62)),
    "old": Palette(wall: (67, 23, 2), shade: (44, 15, 2), fresh: (128, 104, 62), nectar: (89, 58, 27), glint: (162, 144, 116),
                   cap: (98, 72, 46), brood: (96, 60, 34), bread: [(130, 92, 33), (116, 77, 38), (96, 62, 36)],
                   room: (12, 8, 5), wood: (70, 49, 23), bee: (0.86, 0.72, 0.56), lamp: (0.94, 0.59), floor: (94, 52, 20), honeyT: (1.25, 1.20, 1.10)),
    "new": Palette(wall: (204, 186, 140), shade: (160, 142, 84), fresh: (198, 190, 170), nectar: (116, 85, 48), glint: (218, 208, 188),
                   cap: (206, 192, 156), brood: (167, 155, 129), bread: [(183, 146, 64), (176, 128, 70), (150, 112, 86)],
                   room: (58, 50, 40), wood: (166, 130, 76), bee: (1.05, 0.98, 0.9), lamp: (1.04, 0.90), floor: (172, 142, 74), honeyT: (0.86, 0.72, 0.50)),
    "backlit": Palette(wall: (70, 52, 26), shade: (176, 134, 62), fresh: (196, 172, 120), nectar: (150, 82, 20), glint: (190, 160, 110),
                       cap: (128, 94, 50), brood: (110, 68, 34), bread: [(140, 92, 30), (128, 80, 36), (104, 66, 40)],
                       room: (10, 7, 5), wood: (60, 42, 20), bee: (0.62, 0.50, 0.38), lamp: (1.155, 0.69), floor: (176, 134, 62), honeyT: (0.92, 0.66, 0.35)),
]
var pal = palettes[look == "red" ? "amber" : look]!
func v3(_ c: RGB) -> String { String(format: "vec3(%.4f, %.4f, %.4f)", c.0 / 255, c.1 / 255, c.2 / 255) }

/// The hours a texel's step is worth (quarters in the stack, which keeps two days; eighths otherwise), and a jitter of a
/// step from the cell's random channel so a patch's cells don't all start on the same quarter hour.
let hq = stacked ? "63.75" : "31.875", jit = stacked ? "0.25" : "0.0"
/// The comb's shading for one comb (`X` is A, or B for the next day's in the dissolve), in points with y down.
func block(_ X: String) -> String {
    let p = pal
    let back = look == "backlit"
    return """
    {
        vec2 lp = p + u_warp\(X).x * 0.5 * vec2(sin(p.y * u_warp\(X).y + u_warp\(X).z) + 0.6 * sin((p.x * 0.7 + p.y * 0.4) * u_warp\(X).y * 1.3 + u_warp\(X).w),
                                         sin(p.x * u_warp\(X).y * 0.9 + u_warp\(X).w) + 0.6 * sin((p.x * 0.5 - p.y * 0.8) * u_warp\(X).y * 1.1 + u_warp\(X).z));
        // the nearest cell of a pointy-topped lattice, by cube rounding
        float s = u_cell / 1.7320508;
        vec2 q = vec2((lp.x * 0.5773503 - lp.y / 3.0) / s, (lp.y * 2.0 / 3.0) / s);
        vec3 cube = vec3(q.x, q.y, -q.x - q.y);
        vec3 rc = floor(cube + 0.5);
        vec3 d = abs(rc - cube);
        if (d.x > d.y && d.x > d.z) { rc.x = -rc.y - rc.z; } else if (d.y > d.z) { rc.y = -rc.x - rc.z; }
        vec2 o = lp - vec2(s * 1.7320508 * (rc.x + rc.y * 0.5), s * 1.5 * rc.y);
        vec2 ao = abs(o);
        float apo = 0.5 * u_cell;
        float hexD = max(ao.x, 0.5 * ao.x + 0.8660254 * ao.y);
        vec2 uv = (vec2(rc.x + floor(rc.y * 0.5), rc.y) + 1.5) / u_cells;
        vec4 m = texture2D(u_map\(X), uv);
        vec4 kd = texture2D(u_kind\(X), uv);
        float built = u_state\(X).x, hr = u_state\(X).y, rise = u_state\(X).z;
        float share = (m.r * 65280.0 + m.g * 255.0) / 65535.0;
        float present = step(share, built) * step(share, 0.9999);
        float wallH = clamp((built - share) / rise, 0.0, 1.0);
        float fromWall = apo - mix(hexD, length(o) * 0.96, 0.85 * (1.0 - wallH));
        present *= mix(smoothstep(-0.6, 0.2, fromWall), 1.0, wallH);
        fromWall = max(fromWall, 0.0);
        float fresh = 1.0 - clamp((built - share) / (rise * 4.0), 0.0, 1.0);
        float level = clamp((hr - (m.b * \(hq) - 6.0 + \(jit) * kd.g)) / 1.5, 0.0, 1.0) * step(m.b, 0.999);
        float capP = clamp((hr - (m.a * \(hq) - 6.0 + \(jit) * kd.g)) / 0.25, 0.0, 1.0) * step(m.a, 0.999);
        float kind = floor(kd.r * 255.0 / 80.0 + 0.5);
        float rnd = kd.g;
        float aa = max(fwidth(fromWall), 0.05);
        // wax with one octave of grain; new wax paler, toward the growing edge
        float grain = noise(p * 0.45) * 0.6 + noise(p * 1.7) * 0.4;
        vec3 wax = mix(\(v3(p.wall)), \(v3(p.fresh)), fresh) * (0.9 + 0.2 * grain);
        // the coping at the mouth: a lit rim a pixel or two wide, thick and rough where the cell is new
        float rimW = 0.42 + (1.5 + 0.8 * grain) * (1.0 - wallH);
        float rim = 1.0 - smoothstep(rimW - aa, rimW + aa, fromWall);
        vec2 dir = o / max(length(o), 0.001);
        float rimLit = 1.0 + 0.18 * dot(dir, vec2(0.6, 0.8));
        // the base, pushed down by the cell's upward tilt; above it a band of the upper inner wall
        float shift = (0.28 + 0.10 * rnd) * u_cell * wallH;
        vec2 of = o - vec2(0.0, shift);
        vec2 aof = abs(of);
        float floorIn = apo - rimW - max(aof.x, 0.5 * aof.x + 0.8660254 * aof.y);
        float onFloor = smoothstep(-aa, aa, floorIn);
        float face = max(max(dot(of, vec2(0.866, 0.5)), dot(of, vec2(-0.866, 0.5))), dot(of, vec2(0.0, -1.0)));
        float facet = dot(of, vec2(0.866, 0.5)) >= face ? 1.0 : (dot(of, vec2(-0.866, 0.5)) >= face ? 0.91 : 0.82);
        float band = clamp((fromWall - rimW) / max(shift, 0.3), 0.0, 1.0);
        float occl = 0.88 + 0.12 * smoothstep(0.0, 0.3 * apo, floorIn);
    \(back ? """
        // lit through from behind: the thin base glows, the walls seen edge on are dark, honey glows deep amber
        vec3 floorC = \(v3(p.shade)) * facet * occl * (0.85 + 0.3 * grain) * mix(1.0, 1.25, fresh);
        vec3 bandC = mix(floorC * 0.8, \(v3(p.wall)) * 1.3, band * 0.0 + (1.0 - band));
        vec3 cellC = mix(bandC, floorC, onFloor);
        vec3 honey = floorC * pow(\(v3((p.honeyT.0 * 255, p.honeyT.1 * 255, p.honeyT.2 * 255))), vec3(0.6 + 1.6 * level));
    """ : """
        vec3 floorC = mix(\(v3(p.floor)), \(v3(p.fresh)) * 0.8, fresh * 0.6) * facet * occl * (0.92 + 0.16 * grain);
        vec3 bandC = mix(wax * 0.8, \(v3(p.floor)) * 0.66, band);
        vec3 cellC = mix(bandC, floorC, onFloor);
        vec3 honey = floorC * pow(\(v3((p.honeyT.0 * 255, p.honeyT.1 * 255, p.honeyT.2 * 255))), vec3(0.4 + 1.0 * level));
    """)
        // nectar coats the cell and rises to the mouth; when full, one still highlight from the lamp
        float isBread = step(0.5, kind) * step(kind, 1.5);
        float isBrood = step(1.5, kind);
        float wet = smoothstep(0.0, 0.12, level) * (1.0 - isBread) * (1.0 - isBrood);
        cellC = mix(cellC, mix(honey, honey * 0.8, (1.0 - onFloor) * (1.0 - smoothstep(0.5, 1.0, level))), wet);
        vec2 gl = o - vec2(-0.2, -0.24) * u_cell;
        cellC += \(v3(p.glint)) * exp(-dot(gl, gl) / (0.012 * u_cell * u_cell)) * smoothstep(0.55, 1.0, level) * 0.7 * wet;
        // bee bread, packed half way up, matte, in a few colours
        float bi = floor(kd.b * 2.99);
        vec3 bread = (bi < 0.5 ? \(v3(p.bread[0])) : (bi < 1.5 ? \(v3(p.bread[1])) : \(v3(p.bread[2])))) * (0.82 + 0.3 * noise(p * 2.2));
        cellC = mix(cellC, bread * mix(0.85, 1.0, onFloor), isBread * smoothstep(0.0, 0.3, level) * smoothstep(-0.5, 0.5, floorIn + 0.2 * apo));
        // dry caps close from the rim inward: flat, grainy, a little domed; capped brood domed and darker
        float r0 = rimW + capP * (apo - rimW + 0.4);
        float capped = (1.0 - smoothstep(r0 - aa, r0 + aa, fromWall)) * step(0.001, capP);
        float dome = clamp(fromWall / apo, 0.0, 1.0);
        float groove = 1.0 - smoothstep(rimW, rimW + 1.1, fromWall);
        vec3 capC = mix(\(v3(p.cap)), \(v3(p.brood)), isBrood) * (0.80 + 0.24 * sqrt(dome) + 0.16 * (grain - 0.5) + 0.07 * isBrood * (noise(p * 3.0) - 0.5)) * (1.0 - 0.22 * groove)
                  * (1.0 + (0.06 + 0.08 * isBrood) * dot(-dir, vec2(-0.6, -0.8)) * dome) * mix(1.0, 0.86, step(0.82, rnd) * (1.0 - isBrood));
        cellC = mix(cellC, capC, capped);
        vec3 rimC = wax * \(back ? "0.55" : "1.12") * rimLit;
        vec3 combC = mix(cellC, rimC, rim * mix(1.0, 0.4, capped * step(0.999, capP)));
        // beyond the comb: the hive's dark back, the bees on the far face as shadows only
        vec3 room = \(v3(p.room)) * (0.9 + 0.2 * noise(p * 0.02));
        col\(X) = mix(room, combC, present);
    }
    """
}

let mixing = cfg.mix != nil && !stacked
let dissolving = stacked && change == "dissolve"
let combSource = """
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void main() {
    vec2 p = vec2(v_tex_coord.x, 1.0 - v_tex_coord.y) * u_size;
    vec3 colA = vec3(0.0); vec3 colB = vec3(0.0);
\(block("A"))
\(mixing || dissolving ? block("B") : "")
\(dissolving ? """
    // the dissolve: each cell-sized patch turns to the comb below's at its own moment, in soft patches a few cells across
    float pn = noise(p / (u_cell * 5.0)) * 0.75 + noise(p / (u_cell * 1.3)) * 0.25;
    vec3 c = mix(colA, colB, smoothstep(pn - 0.05, pn + 0.05, u_mix * 1.3 - 0.15));
""" : """
    vec3 c = \(mixing ? "mix(colA, colB, u_mix)" : "colA");
""")
\(stacked ? """
    // the top bar's soft shadow on the comb hung from it, the lamp being above
    c *= 1.0 - 0.42 * (1.0 - smoothstep(0.0, 9.0, p.y));
""" : "")
    // the lamp, from beyond the upper left, by the point's place on the screen
    // a warm lamp dims toward red, so the far side of the comb goes brown and never olive
    float lf = clamp(length((u_origin + p) / u_screen - vec2(-0.1, -0.2)) / 1.4, 0.0, 1.0);
    vec3 lamp = mix(vec3(\(pal.lamp.0)), vec3(\(pal.lamp.1)) * \(look == "new" ? "vec3(1.0, 0.97, 0.92)" : "vec3(1.08, 0.94, 0.78)"), lf);
    c *= lamp;
    // the frame's wood, and the case with its shutter lifted
    float wood = 0.0;
    if (u_inset.x > 0.0) {
        float inTop = step(p.y, u_inset.x);
        float inSide = step(p.x, u_inset.y) + step(u_size.x - u_inset.y, p.x);
        float inBottom = step(u_size.y - u_inset.z, p.y);
        wood = clamp(inTop + inSide + inBottom, 0.0, 1.0);
        float lines = 0.86 + 0.1 * noise(vec2(p.x * 0.04, p.y * 1.3)) + 0.06 * noise(vec2(p.x * 0.6, p.y * 0.05));
        float linesSide = 0.86 + 0.1 * noise(vec2(p.x * 1.3, p.y * 0.04)) + 0.06 * noise(vec2(p.x * 0.05, p.y * 0.6));
        vec3 woodC = \(v3(pal.wood)) * mix(lines, linesSide, clamp(inSide - inTop, 0.0, 1.0)) * lamp;
        // a soft shadow of the wood on the comb, and a bevel at the wood's inner edge
        float edgeD = min(min(p.y - u_inset.x, min(p.x - u_inset.y, u_size.x - u_inset.y - p.x)), u_size.y - u_inset.z - p.y);
        c *= 1.0 - 0.45 * (1.0 - smoothstep(0.0, 10.0, edgeD)) * (1.0 - wood);
        woodC *= 1.0 - 0.25 * (1.0 - smoothstep(-4.0, 0.0, edgeD)) * wood;
        if (u_inset.w > 0.5) {
            // the case: a darker outer border, and the shutter's lower edge across the top, lifted
            float outer = 1.0 - step(26.0, min(min(p.x, u_size.x - p.x), u_size.y - p.y));
            woodC = mix(woodC, \(v3(pal.wood)) * 0.55 * lines * lamp, outer);
            float shutter = step(p.y, 62.0);
            woodC = mix(woodC, \(v3(pal.wood)) * 0.7 * (0.9 + 0.1 * step(0.5, fract(p.x / 180.0))) * lines * lamp, shutter);
            woodC *= 1.0 - 0.5 * (1.0 - smoothstep(62.0, 74.0, p.y)) * (1.0 - shutter);
        }
        c = mix(c, woodC, wood);
    }
\(look == "red" ? """
    // the red lamp: Amber's luminance on one deep red ramp
    float Y = dot(c, vec3(0.2126, 0.7152, 0.0722)) * 0.44;
    c = Y < 0.36 ? mix(vec3(0.039, 0.012, 0.008), vec3(0.373, 0.102, 0.039), Y / 0.36) : mix(vec3(0.373, 0.102, 0.039), vec3(0.588, 0.157, 0.063), clamp((Y - 0.36) / 0.36, 0.0, 1.0));
""" : "")
    gl_FragColor = vec4(c, 1.0);
}
"""

// MARK: the bees' atlas: one sprite a bee, a frame a pose, the head toward +x, lit from the viewer's side

enum Pose: Int, CaseIterable { case walk0, walk1, walk2, walk3, stand, headIn, tipIn, groom, festoon, fan }
let framePx = Int((beeLen * 2 * 1.5).rounded())   // a frame is 1.5 bee lengths square, at 2x
let lookTint: RGB = look == "red" ? (0.42, 0.11, 0.05) : pal.bee

func loadPhotoBee() -> CGImage? {
    guard let path = cfg.photo, let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    // mask the black ground: alpha from brightness (the photo is the bee over black, so its pixels are already
    // premultiplied by that alpha), cropped to the bee
    let (w, h) = (img.width, img.height)
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    var (x0, y0, x1, y1) = (w, h, 0, 0)
    for j in 0..<h { for i in 0..<w {
        let k = (j * w + i) * 4
        let m = Double(max(px[k], px[k + 1], px[k + 2])) / 255
        let a = min(1, max(0, (m - 0.05) / 0.13))
        let a8 = UInt8(a * a * (3 - 2 * a) * 255)
        // keep premultiplied: a pixel can't be brighter than its alpha
        px[k] = min(px[k], a8); px[k + 1] = min(px[k + 1], a8); px[k + 2] = min(px[k + 2], a8); px[k + 3] = a8
        if a8 > 40 { x0 = min(x0, i); x1 = max(x1, i); y0 = min(y0, j); y1 = max(y1, j) }
    }}
    return ctx.makeImage()?.cropping(to: CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1))
}

func makeAtlas() -> [SKTexture] {
    let n = Pose.allCases.count, F = framePx
    let ctx = CGContext(data: nil, width: F * n, height: F, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    let L = beeLen * 2 // pixels
    let photo = (cfg.atlas ?? "photo") == "photo" ? loadPhotoBee() : nil
    func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor { CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a) }
    /// Legs from above: three a side, two joints, set by the tripod's phase (0 to 1) and how far they reach.
    func legs(_ phase: Double, reach: Double = 1, front: Double = 0, hang: Bool = false) {
        ctx.setStrokeColor(rgb(58, 38, 20, 0.8)); ctx.setLineCap(.round)
        for side in [-1.0, 1.0] { for (k, hip) in [0.10, 0.0, -0.08].enumerated() {
            let tripod = (k == 1) == (side > 0) ? 0.0 : 0.5
            let swing = sin((phase + tripod) * 2 * .pi) * 0.09 * L
            var ang = [0.95, 1.6, 2.35][k] // from the head's direction, outward
            if hang { ang = [0.35, 1.5, 2.8][k] }
            if front > 0 && k == 0 { ang = 0.45 }
            let len = [0.30, 0.32, 0.40][k] * L * reach * (hang ? 1.5 : 1)
            let hx = hip * L, hy = 0.0
            let kx = hx + cos(ang) * len * 0.45 + swing * 0.3, ky = hy + side * sin(ang) * len * 0.45
            let fx = hx + cos(ang + side * 0 - (k == 0 ? 0.35 : k == 2 ? -0.3 : 0)) * len + swing, fy = hy + side * sin(ang) * len * 0.95
            ctx.setLineWidth(max(1.0, 0.036 * L))
            ctx.move(to: CGPoint(x: hx, y: hy)); ctx.addLine(to: CGPoint(x: kx, y: ky)); ctx.strokePath()
            ctx.setLineWidth(max(0.7, 0.024 * L))
            ctx.move(to: CGPoint(x: kx, y: ky)); ctx.addLine(to: CGPoint(x: fx, y: fy)); ctx.strokePath()
        }}
    }
    func shadow(_ len: Double, _ wid: Double) {
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [rgb(0, 0, 0, 0.42), rgb(0, 0, 0, 0)] as CFArray, locations: [0, 1])!
        ctx.saveGState(); ctx.translateBy(x: 0.03 * L, y: -0.05 * L); ctx.scaleBy(x: len, y: wid)
        ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 0.5, options: [])
        ctx.restoreGState()
    }
    /// The body, head toward +x, centred: from the photo, or painted.
    func body(clipFront: Double? = nil, squash: Double = 1) {
        ctx.saveGState()
        ctx.scaleBy(x: squash, y: 1)
        if let photo {
            // the photo's bee stands head up; turn it head to +x, its length L
            let k = L / Double(photo.height)
            ctx.rotate(by: -.pi / 2)
            let r = CGRect(x: -Double(photo.width) * k / 2, y: -L / 2, width: Double(photo.width) * k, height: L)
            if let c = clipFront { ctx.clip(to: CGRect(x: r.minX, y: r.minY, width: r.width, height: L * c)) } // keep the rear part
            ctx.draw(photo, in: r)
        } else {
            if let c = clipFront { ctx.clip(to: CGRect(x: -L / 2, y: -L, width: L * c, height: 2 * L)) }
            // wings folded over the abdomen, faint
            ctx.setFillColor(rgb(210, 200, 180, 0.10))
            for s in [-1.0, 1.0] { ctx.fillEllipse(in: CGRect(x: -0.42 * L, y: s * 0.05 * L - 0.09 * L, width: 0.52 * L, height: 0.18 * L)) }
            // abdomen: amber with dark bands, hairy edge
            ctx.setFillColor(rgb(175, 137, 89)); ctx.fillEllipse(in: CGRect(x: -0.5 * L, y: -0.17 * L, width: 0.56 * L, height: 0.34 * L))
            ctx.setFillColor(rgb(71, 39, 5, 0.9))
            for b in [-0.43, -0.33, -0.23, -0.13] { ctx.fill(CGRect(x: b * L, y: -0.15 * L, width: 0.045 * L, height: 0.3 * L)) }
            ctx.setFillColor(rgb(60, 32, 6)); ctx.fillEllipse(in: CGRect(x: -0.52 * L, y: -0.06 * L, width: 0.1 * L, height: 0.12 * L))
            // thorax, furred
            let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [rgb(150, 112, 62), rgb(118, 84, 44), rgb(180, 160, 120, 0)] as CFArray, locations: [0, 0.7, 1])!
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: 0.13 * L, y: 0), startRadius: 0, endCenter: CGPoint(x: 0.13 * L, y: 0), endRadius: 0.17 * L, options: [])
            // head, eyes, antennae
            ctx.setFillColor(rgb(48, 30, 14)); ctx.fillEllipse(in: CGRect(x: 0.26 * L, y: -0.1 * L, width: 0.16 * L, height: 0.2 * L))
            ctx.setStrokeColor(rgb(40, 24, 10)); ctx.setLineWidth(max(0.8, 0.02 * L))
            for s in [-1.0, 1.0] { ctx.move(to: CGPoint(x: 0.4 * L, y: s * 0.04 * L)); ctx.addLine(to: CGPoint(x: 0.5 * L, y: s * 0.12 * L)); ctx.strokePath() }
            ctx.setFillColor(rgb(210, 200, 180, 0.12))
            for s in [-1.0, 1.0] { ctx.fillEllipse(in: CGRect(x: -0.3 * L, y: s * 0.06 * L - 0.08 * L, width: 0.48 * L, height: 0.16 * L)) }
        }
        ctx.restoreGState()
    }
    for pose in Pose.allCases {
        ctx.saveGState()
        ctx.translateBy(x: Double(pose.rawValue * F) + Double(F) / 2, y: Double(F) / 2)
        switch pose {
        case .walk0, .walk1, .walk2, .walk3, .stand, .groom, .fan:
            shadow(L * 1.05, L * 0.5)
            legs(pose == .stand || pose == .groom || pose == .fan ? 0.25 : Double(pose.rawValue) / 4, front: pose == .groom ? 1 : 0)
            if pose == .fan { // wings as a still blur, spread
                ctx.setFillColor(rgb(215, 215, 220, 0.16))
                for s in [-1.0, 1.0] { ctx.saveGState(); ctx.rotate(by: s * 0.55); ctx.fillEllipse(in: CGRect(x: -0.55 * L, y: -0.16 * L, width: 0.6 * L, height: 0.32 * L)); ctx.restoreGState() }
            }
            body()
        case .festoon:
            shadow(L * 1.0, L * 0.45)
            legs(0.25, reach: 1, hang: true)
            body()
        case .headIn:
            // head first into a cell (the cell's axis is toward the viewer): the rear half shows, foreshortened,
            // its front end in the cell's shadow at the frame's centre
            ctx.translateBy(x: 0.02 * L, y: 0)
            shadow(L * 0.55, L * 0.45)
            ctx.saveGState(); ctx.translateBy(x: 0.2 * L * 0.75, y: 0); body(clipFront: 0.7, squash: 0.75); ctx.restoreGState()
            let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [rgb(10, 6, 2, 0.55), rgb(10, 6, 2, 0)] as CFArray, locations: [0, 1])!
            ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 0.16 * L, options: [])
        case .tipIn:
            // asleep in a cell: only the tip of the abdomen, end on, inside the mouth
            ctx.saveGState()
            let g0 = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [rgb(150, 110, 62, 0.95), rgb(96, 64, 30, 0.9), rgb(40, 24, 8, 0)] as CFArray, locations: [0, 0.6, 1])!
            ctx.drawRadialGradient(g0, startCenter: CGPoint(x: -0.02 * L, y: 0.02 * L), startRadius: 0, endCenter: .zero, endRadius: 0.15 * L, options: [])
            ctx.setStrokeColor(rgb(50, 28, 6, 0.55)); ctx.setLineWidth(0.03 * L)
            ctx.addArc(center: CGPoint(x: 0.05 * L, y: 0), radius: 0.07 * L, startAngle: 1.9, endAngle: 4.4, clockwise: false); ctx.strokePath()
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }
    // the look's light on the bees, as on the comb
    let img = ctx.makeImage()!
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let c2 = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c2.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    let dim = photo == nil ? 0.74 : 0.62 // the photo's studio light down to the comb's lamp
    for i in stride(from: 0, to: px.count, by: 4) {
        if look == "red" {
            let y = (0.2126 * Double(px[i]) + 0.7152 * Double(px[i + 1]) + 0.0722 * Double(px[i + 2])) * dim * 1.8
            px[i] = UInt8(min(Double(px[i + 3]), y * lookTint.0 * 1.3)); px[i + 1] = UInt8(min(Double(px[i + 3]), y * lookTint.1 * 1.3)); px[i + 2] = UInt8(min(Double(px[i + 3]), y * lookTint.2 * 1.3))
        } else {
            px[i] = UInt8(min(Double(px[i + 3]), Double(px[i]) * dim * lookTint.0))
            px[i + 1] = UInt8(min(Double(px[i + 3]), Double(px[i + 1]) * dim * lookTint.1))
            px[i + 2] = UInt8(min(Double(px[i + 3]), Double(px[i + 2]) * dim * lookTint.2))
        }
    }
    let atlas = SKTexture(cgImage: c2.makeImage()!)
    return (0..<n).map { SKTexture(rect: CGRect(x: Double($0) / Double(n), y: 0, width: 1 / Double(n), height: 1), in: atlas) }
}

// MARK: the colony (research-method.md §2, §3, §5): sent to where the map says work is, at the real pace

enum State { case walk, work, rest, cell, festoon, pair, cluster }
enum Job { case none, build, store, cap, groom }
struct Bee {
    var x = 0.0, y = 0.0, heading = 0.0
    var state = State.rest, job = Job.none
    var timer = 0.0, dist = 0.0, speed = 0.0
    var tx = 0.0, ty = 0.0, home = 0.0, scale = 1.0
    var phase = 0.0, partner = -1
    var pose = Pose.stand
}

/// A comb on the screen: the frame's comb, its day (0 the day's, 1 yesterday's, -1 the next), where its top lies in
/// the stack's points, and in a dissolve the comb it turns into.
struct Slot { let comb: Comb; let k: Int; let top: Double; let next: Comb?; let nextK: Int }
var combs: [Int: Comb] = [:]
/// Frame k's comb, baked from its own day's seed: the frame above is the very comb that was drawn out yesterday.
func combFor(_ k: Int) -> Comb {
    if let c = combs[k] { return c }
    let c = Comb(seed: UInt64(bitPattern: Int64(bitPattern: seed) &- Int64(k)), w: Wpt, h: combH, inset: (0, 0, 0))
    combs[k] = c
    return c
}
let tFirst = cfg.t ?? 180 // three minutes after the comb landed, as Ant Colony runs its ants on
func ease(_ x: Double) -> Double { let c = min(1, max(0, x)); return c * c * (3 - 2 * c) }
/// How far through the change the farm is at t, and how far the stack has slid up (eased in and out).
func fAt(_ t: Double) -> Double { change == nil ? 0 : fStart + (t - tFirst) / changeDur }
func scrollAt(_ t: Double) -> Double { change == "slide" ? pitch * ease(fAt(t)) : 0 }
var scrollNow = scrollAt(0)
let slots: [Slot] = {
    guard stacked else { return [Slot(comb: Comb(seed: seed), k: 0, top: 0, next: mixing ? Comb(seed: seed &+ 1) : nil, nextK: 0)] }
    let moving = change == "slide" && (cfg.frames != nil || cfg.times != nil)
    let (lo, hi) = change == "slide" ? (scrollAt(tFirst) - 2, moving ? pitch : scrollAt(tFirst) + 2) : (0.0, 0.0)
    var out: [Slot] = []
    for k in -1...6 {
        let top = combTop(k)
        guard top - topBar - hi < Hpt, top + combH + bottomBar - lo > 0 else { continue }
        out.append(Slot(comb: combFor(k), k: k, top: top, next: dissolving ? combFor(k - 1) : nil, nextK: k - 1))
    }
    return out
}()
let bakeMs = (stacked ? Array(combs.values) : slots.map { $0.comb }).reduce(0) { $0 + $1.bakeMs }

/// Every cell the bees can reach, in the stack's points, with its day (a frame up the stack runs 24 hours ahead).
struct World { var pos: [(Double, Double)] = [], share: [Double] = [], fillH: [Double] = [], capH: [Double] = [], holds: [Int] = [], day: [Double] = [] }
let comb: World = {
    var w = World()
    let after = dissolving && fStart >= 0.5 // the bees on the combs that show most
    for sl in slots {
        let (c, k) = after ? (sl.next!, sl.nextK) : (sl.comb, sl.k)
        for i in c.pos.indices where c.share[i] <= 1 {
            w.pos.append((c.pos[i].0, c.pos[i].1 + sl.top)); w.share.append(c.share[i]); w.fillH.append(c.fillH[i])
            w.capH.append(c.capH[i]); w.holds.append(c.holds[i]); w.day.append(24 * Double(k))
        }
    }
    return w
}()
var rng = Rand(s: seed &* 31 &+ 5)
let temp = cfg.temp ?? 22
let clusterShare = 0.85 * min(1, max(0, (15 - temp) / 5))
let clusterDensity = temp > 10 ? 0.6 + 1.0 * min(1, max(0, (14 - temp) / 4)) : 1.6 + 0.3 * min(1, (10 - temp) / 30) // a cm²
let inCellShare = temp < 10 ? min(0.4, (10 - temp) / 30 * 0.4) : 0
let gather = min(1, max(0, (18 - temp) / 4)) // homes drawn in and walkers halved between 18 and 14 °C

func hourAt(_ t: Double) -> Double { (mixing ? 0 : hour0) + t / 3600 }
let clock = (6 + hour0).truncatingRemainder(dividingBy: 24)
let night = clock >= 21 || clock < 6
let pace = night ? 0.45 : 1.0

/// The cells by what is being done at them at hour h.
struct Work { var building: [Int] = [], filling: [Int] = [], capping: [Int] = [], empty: [Int] = [], drawn: [Int] = [], edge: [Int] = [] }
func work(_ c: World, _ h: Double) -> Work {
    var w = Work()
    for i in 0..<c.share.count {
        let hk = h + c.day[i], b = built(hk)
        guard c.share[i] <= b else { continue }
        let (x, y) = c.pos[i]
        guard x > 4, x < Wpt - 4, y - scrollNow > 4, y - scrollNow < Hpt - 4 else { continue }
        w.drawn.append(i)
        let rise = built(hk + 1.5) - b
        if hk < 24, c.share[i] > b - max(rise, 0.004) { w.building.append(i) }
        if c.holds[i] != 2, hk >= c.fillH[i], hk < c.fillH[i] + 1.5 { w.filling.append(i) }
        if hk >= c.capH[i] - 0.4, hk < c.capH[i] + 0.25 { w.capping.append(i) }
        if hk < c.fillH[i] { w.empty.append(i) }
    }
    // the lower edge, where festoons hang: a building cell with nothing drawn a cell below it
    let below = Set(w.drawn.map { i -> Int in let (x, y) = c.pos[i]; return Int(x / cell) * 10000 + Int(y / (cell * 0.866)) })
    for i in w.building {
        let (x, y) = c.pos[i]
        if !below.contains(Int(x / cell) * 10000 + Int(y / (cell * 0.866)) + 2) && y - scrollNow < Hpt - beeLen { w.edge.append(i) }
    }
    return w
}

let screenCm2 = Wpt * Hpt / (ppm * ppm) / 100
let beeCount = min(1200, Int((0.2 * screenCm2 * (cfg.bees ?? 1)).rounded()))
var bees: [Bee] = []
var w0 = work(comb, hourAt(0))
let siteX = Wpt / 2
let siteY: Double = {
    // on the day's comb (in the stack, the bottom frame's)
    let ys = w0.empty.filter { comb.day[$0] == 0 }.map { comb.pos[$0].1 }.sorted()
    guard !ys.isEmpty else { return scrollNow + Hpt * 0.6 }
    let bottom = w0.drawn.filter { comb.day[$0] == 0 && abs(comb.pos[$0].0 - Wpt / 2) < Wpt * 0.15 }.map { comb.pos[$0].1 }.max() ?? scrollNow + Hpt
    let members = Double(beeCount) * clusterShare
    let radius = sqrt(members / clusterDensity * 100 / .pi) * ppm
    return min(ys[ys.count / 2], bottom - radius * 0.85)
}()

func pick(_ list: [Int]) -> Int? { list.isEmpty ? nil : list[Int(rng.next() * Double(list.count)) % list.count] }
var taken: [Int: Int] = [:]
/// A cell being worked that has room for one more bee (two at most), or nil.
func pickTask(_ list: [Int]) -> Int? {
    for _ in 0..<10 { if let i = pick(list), taken[i, default: 0] < 2 { taken[i, default: 0] += 1; return i } }
    return nil
}
/// A place to rest: any drawn cell, drawn in toward the cluster's site as the air cools.
func restPlace() -> (Double, Double) {
    let i = pick(w0.drawn) ?? 0
    var (x, y) = comb.pos[i]
    x += rng.range(-0.4...0.4) * cell; y += rng.range(-0.4...0.4) * cell
    if gather > 0 { x = siteX + (x - siteX) * (1 - 0.3 * gather); y = siteY + (y - siteY) * (1 - 0.3 * gather) }
    return (x, y)
}
func startWalk(_ b: inout Bee) {
    b.state = .walk; b.job = .none
    // a target a short walk away: a cell being worked if one is near, else anywhere drawn
    var best: (Double, Double)? = nil
    for _ in 0..<12 {
        let r = rng.next()
        let list = r < 0.3 ? w0.building : r < 0.6 ? w0.filling : r < 0.75 ? w0.capping : w0.drawn
        guard let i = r < 0.75 ? pickTask(list) : pick(list) else { continue }
        let (x, y) = comb.pos[i]
        let d = hypot(x - b.x, y - b.y)
        if d > 2.5 * beeLen && d < 7 * beeLen { best = (x, y); b.job = r < 0.3 ? .build : r < 0.6 ? .store : r < 0.75 ? .cap : .groom; break }
    }
    if best == nil { // anywhere drawn a short walk away, else stay put
        for _ in 0..<12 { if let i = pick(w0.drawn), hypot(comb.pos[i].0 - b.x, comb.pos[i].1 - b.y) < 6 * beeLen { best = comb.pos[i]; break } }
    }
    if best == nil { best = (b.x + rng.range(-1...1) * beeLen, b.y + rng.range(-1...1) * beeLen) }
    (b.tx, b.ty) = best!
    if gather > 0 { b.tx = siteX + (b.tx - siteX) * (1 - 0.3 * gather); b.ty = siteY + (b.ty - siteY) * (1 - 0.3 * gather) }
    b.tx = min(max(b.tx, beeLen), Wpt - beeLen); b.ty = min(max(b.ty, scrollNow + beeLen * 0.6), scrollNow + Hpt - beeLen * 0.6)
    b.speed = rng.range(2...5) * ppm * pace // 2 to 5 mm/s by day, slower by night
}
/// What a bee does next, at the end of a walk or a spell: a cycle that keeps about 13% walking, 40% working in place
/// and 45% still (research-method.md §2), with fewer walking as the air cools.
func next(_ b: inout Bee) {
    switch b.state {
    case .walk:
        let workP = 0.62 * (1 - 0.5 * gather)
        if rng.next() < workP && b.job != .none {
            b.state = .work
            b.timer = rng.range(20...90)
            b.pose = b.job == .store ? .headIn : b.job == .groom ? .groom : .stand
            if b.job == .store { b.heading = -.pi / 2 + rng.range(-0.7...0.7) }
        } else {
            b.state = .rest; b.job = .none; b.pose = .stand
            b.timer = exp(rng.range(log(20)...log(300))) * (night ? 1.5 : 1) * (1 + gather)
        }
    default:
        startWalk(&b)
    }
}

for i in 0..<beeCount {
    var b = Bee()
    b.scale = rng.range(0.95...1.05)
    b.heading = rng.range(0...6.283)
    b.phase = rng.range(0...100)
    let u = Double(i) / Double(max(1, beeCount))
    let h = hourAt(0)
    let festoonShare = 0.18 * (1 - min(1, max(0, (built(h) - 0.3) / 0.45))) * (1 - gather)
    if u < clusterShare {
        b.state = .cluster
    } else if u < clusterShare + festoonShare && !w0.edge.isEmpty {
        b.state = .festoon
    } else {
        let r = rng.next()
        if r < 0.13 { (b.x, b.y) = restPlace(); startWalk(&b); bees.append(b); continue } // placed first: its target is a short walk from there
        if r < 0.53 {
            let k = rng.next()
            b.job = k < 0.3 ? .build : k < 0.65 ? .store : k < 0.85 ? .cap : .groom
            let list = b.job == .build ? w0.building : b.job == .store ? w0.filling : b.job == .cap ? w0.capping : w0.drawn
            if let c = b.job == .groom ? pick(list) : pickTask(list) {
                (b.x, b.y) = comb.pos[c]
                b.state = .work; b.timer = rng.range(5...90)
                b.pose = b.job == .store ? .headIn : b.job == .groom ? .groom : .stand
                if b.job == .store { b.heading = -.pi / 2 + rng.range(-0.7...0.7) }
                if b.job == .build { b.x += rng.range(-0.3...0.3) * cell; b.y += cell * 0.4 }
                bees.append(b); continue
            }
        }
        if r > 0.93, let c = pick(w0.empty) { b.state = .cell; b.pose = .tipIn; (b.x, b.y) = comb.pos[c]; b.timer = 1e9; bees.append(b); continue }
        b.state = .rest; b.pose = .stand
        (b.x, b.y) = restPlace()
        b.timer = rng.range(0...300)
        if r > 0.90, bees.count > 0, bees[bees.count - 1].state == .rest, bees[bees.count - 1].partner < 0 {
            // face to face with the bee before, passing food
            let j = bees.count - 1
            b.state = .pair; bees[j].state = .pair; b.partner = j; bees[j].partner = i
            b.heading = bees[j].heading + .pi
            b.x = bees[j].x + cos(bees[j].heading) * beeLen * 0.82; b.y = bees[j].y + sin(bees[j].heading) * beeLen * 0.82
            b.timer = rng.range(2...10); bees[j].timer = b.timer
        }
    }
    bees.append(b)
}
// the cluster: a disc of bees packed at its density on the empty cells under the honey, a share of them in cells
do {
    let members = bees.indices.filter { bees[$0].state == .cluster }
    let spacing = sqrt(1 / (clusterDensity / 100) * 2 / sqrt(3)) * ppm // points between centres on a hex packing
    var spots: [(Double, Double)] = []
    var ring = 0
    while spots.count < members.count {
        if ring == 0 { spots.append((siteX, siteY)) } else {
            for k in 0..<(6 * ring) { let a = Double(k) / Double(6 * ring) * 2 * .pi; spots.append((siteX + cos(a) * Double(ring) * spacing, siteY + sin(a) * Double(ring) * spacing * 0.9)) }
        }
        ring += 1
    }
    for (n, i) in members.enumerated() {
        bees[i].x = spots[n].0 + rng.range(-0.25...0.25) * spacing; bees[i].y = spots[n].1 + rng.range(-0.25...0.25) * spacing
        bees[i].heading = atan2(siteY - bees[i].y, siteX - bees[i].x) + rng.range(-1.2...1.2)
        bees[i].pose = rng.next() < inCellShare ? .tipIn : .stand
        bees[i].timer = 1e9
    }
}
// festoons: chains of three to six bees hanging still from the lower edge, heads up
do {
    let members = bees.indices.filter { bees[$0].state == .festoon }
    var anchors = w0.edge.map { comb.pos[$0] }.sorted { $0.0 < $1.0 }
    var spaced: [(Double, Double)] = []
    for a in anchors where spaced.last.map({ a.0 - $0.0 > beeLen * 0.9 }) ?? true { spaced.append(a) }
    anchors = spaced
    var k = 0, chain = 0
    while k < members.count && !anchors.isEmpty {
        let a = anchors[(chain * 7) % anchors.count]
        // a curtain: two or three strands side by side, each bee hanging from the one above at a slant
        let len = 3 + chain % 4, strands = 2 + chain % 2
        for j in 0..<(len * strands) where k < members.count {
            let i = members[k], (row, strand) = (j / strands, j % strands)
            let taper = 1 - Double(row) / Double(len + 1)
            bees[i].x = a.0 + (Double(strand) - Double(strands - 1) / 2) * beeLen * 0.42 * taper + rng.range(-0.15...0.15) * beeLen
            bees[i].y = a.1 + beeLen * (0.3 + 0.55 * Double(row)) + rng.range(-0.1...0.1) * beeLen
            bees[i].heading = -.pi / 2 + rng.range(-0.55...0.55)
            bees[i].pose = .festoon; bees[i].timer = 1e9
            k += 1
        }
        chain += 1
    }
}
func applyFocus() {
    guard let focus = cfg.focus, !bees.isEmpty else { return }
    // the bee the motion strips follow: walking across the middle, or arriving at a cell to store nectar
    bees[0].x = Wpt * 0.22; bees[0].y = Hpt * 0.5; bees[0].heading = 0; bees[0].scale = 1
    if focus == "walk" { bees[0].state = .walk; bees[0].job = .none; bees[0].tx = Wpt * 0.95; bees[0].ty = Hpt * 0.5; bees[0].speed = 4 * ppm }
    else {
        let c = (w0.filling.isEmpty ? w0.drawn : w0.filling).min { hypot(comb.pos[$0].0 - Wpt * 0.4, comb.pos[$0].1 - Hpt * 0.5) < hypot(comb.pos[$1].0 - Wpt * 0.4, comb.pos[$1].1 - Hpt * 0.5) } ?? 0
        (bees[0].x, bees[0].y) = comb.pos[c]
        bees[0].state = .work; bees[0].job = .store; bees[0].pose = .headIn; bees[0].heading = -.pi / 2 + 0.3; bees[0].timer = 6.5
    }
    for i in 1..<bees.count where hypot(bees[i].x - bees[0].x, bees[i].y - bees[0].y) < beeLen * 1.2 || (focus == "walk" && abs(bees[i].y - bees[0].y) < beeLen * 0.8) {
        bees[i].x = -100 // keep its path clear
    }
}

let stepDt = 1.0 / 60
let maxTurn = Double.pi / 4 // 45° a second
var simTime = 0.0
func step() {
    simTime += stepDt
    if change != nil {
        scrollNow = scrollAt(simTime)
        // the work moves on as the stack does: looked at again every half minute of the farm
        if Int((simTime * 60).rounded()) % 1800 == 0 { w0 = work(comb, hourAt(simTime)) }
    }
    for i in bees.indices {
        var b = bees[i]
        switch b.state {
        case .walk:
            let want = atan2(b.ty - b.y, b.tx - b.x)
            var d = want - b.heading
            d = atan2(sin(d), cos(d))
            // give way to a bee just ahead
            var v = b.speed
            for j in bees.indices where j != i && abs(bees[j].x - b.x) < beeLen && abs(bees[j].y - b.y) < beeLen {
                let (ox, oy) = (bees[j].x - b.x, bees[j].y - b.y)
                let ahead = ox * cos(b.heading) + oy * sin(b.heading), side = -ox * sin(b.heading) + oy * cos(b.heading)
                if ahead > 0, ahead < beeLen * 0.8, abs(side) < beeLen * 0.35 { v *= 0.3; d -= side >= 0 ? 0.8 : -0.8 }
            }
            b.heading += max(-maxTurn * stepDt, min(maxTurn * stepDt, d))
            b.x += cos(b.heading) * v * stepDt; b.y += sin(b.heading) * v * stepDt
            b.dist += v * stepDt
            b.pose = Pose(rawValue: Int(b.dist / (beeLen * 0.42 / 4)) & 3)!
            if hypot(b.tx - b.x, b.ty - b.y) < beeLen * 0.3 { next(&b) }
        case .work, .rest, .pair:
            b.timer -= stepDt
            if b.timer <= 0 { if b.state == .pair { b.partner = -1 }; next(&b) }
        default: break
        }
        bees[i] = b
    }
}

// MARK: the scene

let size = CGSize(width: Wpt, height: Hpt)
let scene = SKScene(size: size)
scene.backgroundColor = NSColor(srgbRed: pal.room.0 / 255, green: pal.room.1 / 255, blue: pal.room.2 / 255, alpha: 1)
func u2(_ n: String, _ a: Double, _ b: Double) -> SKUniform { SKUniform(name: n, vectorFloat2: [Float(a), Float(b)]) }
func u4(_ n: String, _ a: Double, _ b: Double, _ c: Double, _ d: Double) -> SKUniform { SKUniform(name: n, vectorFloat4: [Float(a), Float(b), Float(c), Float(d)]) }
func state(_ h: Double) -> (Double, Double, Double) { (built(h), h, max(0.0015, built(h + 1.5) - built(h))) }

/// The bars' wood: a CC0 scan of pine boards (Poly Haven's coated_pine_02, 1.05 m across its 2,048 px), each bar a
/// strip cut from inside one board along its grain, tinted to the look's wood.
let woodImage: CGImage? = {
    guard let path = cfg.wood, let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}()
let woodTint: [Float] = {
    guard let img = woodImage else { return [1, 1, 1] }
    var px = [UInt8](repeating: 0, count: 32 * 32 * 4)
    let ctx = CGContext(data: &px, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: 32, height: 32))
    var m = [0.0, 0.0, 0.0]
    for i in 0..<1024 { for c in 0..<3 { m[c] += Double(px[i * 4 + c]) / 1024 } }
    // the scan's light and dark, in the look's wood: its own hue (and a glint off its coating) left out
    let lum = 0.2126 * m[0] + 0.7152 * m[1] + 0.0722 * m[2]
    return [Float(pal.wood.0 / lum), Float(pal.wood.1 / lum), Float(pal.wood.2 / lum)]
}()
let boards: [Double] = [176, 366, 565, 752, 936, 1118, 1311, 1498, 1688, 1887] // the middles of the scan's boards, px from its top
func barTexture(_ k: Int, _ bottom: Bool, _ hPts: Double) -> SKTexture? {
    guard let img = woodImage else { return nil }
    let pxmm = Double(img.width) / 1049.71
    let (w, h) = (Wpt / ppm * pxmm, hPts / ppm * pxmm)
    var r = Rand(s: UInt64(bitPattern: Int64(k * 2 + (bottom ? 1 : 0) + 1000)) &* 977)
    let cy = boards[Int(r.next() * Double(boards.count)) % boards.count] * Double(img.height) / 2048 + r.range(-20...20)
    guard let crop = img.cropping(to: CGRect(x: r.range(0...(Double(img.width) - w)), y: cy - h / 2, width: w, height: h)) else { return nil }
    return SKTexture(cgImage: crop)
}
let lampTint = look == "new" ? "vec3(1.0, 0.97, 0.92)" : "vec3(1.08, 0.94, 0.78)"
let barSource = """
void main() {
    vec2 lp = vec2(v_tex_coord.x, 1.0 - v_tex_coord.y) * u_bsize;
    vec3 w = vec3(dot(texture2D(u_texture, v_tex_coord).rgb, vec3(0.2126, 0.7152, 0.0722))) * u_tint;
    // a rounded arris along each long edge: the upper lit by the lamp above, the lower in its own shade
    w *= 1.0 + 0.14 * (1.0 - smoothstep(0.0, 1.6, lp.y)) - 0.4 * (1.0 - smoothstep(0.0, 3.0, u_bsize.y - lp.y));
    float lf = clamp(length((u_origin + lp) / u_screen - vec2(-0.1, -0.2)) / 1.4, 0.0, 1.0);
    gl_FragColor = vec4(w * mix(vec3(\(pal.lamp.0)), vec3(\(pal.lamp.1)) * \(lampTint), lf), 1.0);
}
"""

/// Each comb's uniforms the clock moves: its state, the next comb's in a dissolve, and where it lies on the screen.
struct SlotU { let k: Int; let top: Double; let stateA: SKUniform; let stateB: SKUniform?; let origin: SKUniform; let nextK: Int }
var slotU: [SlotU] = []
var barOrigins: [(SKUniform, Double)] = [] // a bar's place on the screen, and its top in the stack's points
let mixU = SKUniform(name: "u_mix", float: Float(mixing ? cfg.mix ?? 0 : fStart))
// the combs and their wood, kept in one rasterised effect node as the app would; the stack slides by moving it
let stackNode: SKNode = (cfg.kept ?? true) ? { let e = SKEffectNode(); e.shouldRasterize = true; return e }() : SKNode()
stackNode.zPosition = -100
// the stack slides by moving a plain node the kept one sits in: moving the kept node itself drew it again every frame
// (0.91 ms of GPU against 0.2), moving its parent didn't
let mover = SKNode()
mover.addChild(stackNode)
scene.addChild(mover)
for sl in slots {
    let c = sl.comb, ch = stacked ? combH : Hpt
    let st = state(mixing ? 24 : hour0 + 24 * Double(sl.k))
    let stA = u4("u_stateA", st.0, st.1, st.2, 0), origin = u2("u_origin", 0, sl.top - scrollNow)
    var uniforms: [SKUniform] = [
        u2("u_size", Wpt, ch), u2("u_screen", Wpt, Hpt), origin, SKUniform(name: "u_cell", float: Float(cell)), u2("u_cells", Double(c.cols), Double(c.rows)),
        SKUniform(name: "u_mapA", texture: c.texture(c.map)), SKUniform(name: "u_kindA", texture: c.texture(c.kind)), stA,
        u4("u_warpA", c.warpP.a, c.warpP.k, c.warpP.p1, c.warpP.p2),
        u4("u_inset", stacked ? 0 : inset.top, stacked ? 0 : inset.side, stacked ? 0 : inset.bottom, cfg.frame == "case" ? 1 : 0),
    ]
    var stB: SKUniform? = nil
    if let c2 = sl.next {
        let sb = state(mixing ? 0 : hour0 + 24 * Double(sl.nextK))
        let u = u4("u_stateB", sb.0, sb.1, sb.2, 0)
        stB = u
        uniforms += [SKUniform(name: "u_mapB", texture: c2.texture(c2.map)), SKUniform(name: "u_kindB", texture: c2.texture(c2.kind)), u,
                     u4("u_warpB", c2.warpP.a, c2.warpP.k, c2.warpP.p1, c2.warpP.p2), mixU]
    }
    let sprite = SKSpriteNode(color: .black, size: CGSize(width: Wpt, height: ch))
    sprite.anchorPoint = .zero
    sprite.position = CGPoint(x: 0, y: Hpt - sl.top - ch)
    sprite.shader = SKShader(source: combSource, uniforms: uniforms)
    stackNode.addChild(sprite)
    slotU.append(SlotU(k: sl.k, top: sl.top, stateA: stA, stateB: stB, origin: origin, nextK: sl.nextK))
    guard stacked else { continue }
    // the frame's top bar above its comb, and its bottom bar below
    for (bottom, y0, hb) in [(false, sl.top - topBar, topBar), (true, sl.top + combH, bottomBar)] {
        let o = u2("u_origin", 0, y0 - scrollNow)
        let bar = barTexture(sl.k, bottom, hb).map { SKSpriteNode(texture: $0, size: CGSize(width: Wpt, height: hb)) }
            ?? SKSpriteNode(color: .white, size: CGSize(width: Wpt, height: hb))
        bar.anchorPoint = .zero
        bar.position = CGPoint(x: 0, y: Hpt - y0 - hb)
        bar.shader = SKShader(source: barSource, uniforms: [u2("u_bsize", Wpt, hb), u2("u_screen", Wpt, Hpt), o,
                                                            SKUniform(name: "u_tint", vectorFloat3: SIMD3<Float>(woodTint[0], woodTint[1], woodTint[2]))])
        stackNode.addChild(bar)
        barOrigins.append((o, y0))
    }
}
mover.position = CGPoint(x: 0, y: scrollNow)
// the bees ride on the stack, in its points
let beeLayer = SKNode()
scene.addChild(beeLayer)
if let text = cfg.label {
    let l = SKLabelNode(fontNamed: "Helvetica-Bold")
    l.text = text; l.fontSize = 56; l.fontColor = NSColor(white: 1, alpha: 0.85)
    l.horizontalAlignmentMode = .left; l.position = CGPoint(x: 48, y: Hpt - 96); l.zPosition = 1000
    scene.addChild(l)
}

let frames = makeAtlas()
var sprites: [SKSpriteNode] = []
var shown: [Pose] = []
let spritePts = Double(framePx) / 2
for (i, b) in bees.enumerated() {
    let s = SKSpriteNode(texture: frames[b.pose.rawValue], size: CGSize(width: spritePts * b.scale, height: spritePts * b.scale))
    s.zPosition = CGFloat(i) * 0.001
    beeLayer.addChild(s); sprites.append(s); shown.append(b.pose)
}
/// The lamp's light at a point, as the comb's shader has it, for the bees there.
func lampAt(_ x: Double, _ y: Double) -> Double { pal.lamp.0 + (pal.lamp.1 - pal.lamp.0) * min(1, hypot(x / Wpt + 0.1, y / Hpt + 0.2) / 1.4) }
var placed = [Bool](repeating: false, count: 0)
func place(_ t: Double) {
    if placed.count != bees.count { placed = [Bool](repeating: false, count: bees.count) }
    for i in bees.indices {
        let b = bees[i], s = sprites[i]
        let still = b.state == .rest || b.state == .cell || b.state == .cluster || b.state == .pair
        if still && placed[i] && shown[i] == b.pose { continue }
        placed[i] = true
        var (x, y, a) = (b.x, b.y, b.heading)
        // small movements in place: a nod at the rim, a capper working, a still sway in a festoon
        switch (b.state, b.job) {
        case (.work, .build): x += cos(a) * 0.5 * sin(t * 2.4 + b.phase) * ppm
        case (.work, .cap): a += 0.12 * sin(t * 1.3 + b.phase); x += 0.3 * ppm * sin(t * 0.9 + b.phase)
        case (.work, .store): x += cos(a) * 0.35 * ppm * sin(t * 1.1 + b.phase)
        case (.festoon, _): x += 0.25 * ppm * sin(t * 0.3 + b.phase)
        default: break
        }
        s.position = CGPoint(x: x, y: Hpt - y)
        y -= scrollNow // the lamp falls by the place on the screen
        s.zRotation = CGFloat(-a)
        s.zPosition = CGFloat(i) * 0.001 + (b.state == .walk ? 10 : b.state == .festoon ? 5 : 0)
        let pose = b.state == .work && b.job == .groom ? (Int(t / 1.5 + b.phase) % 2 == 0 ? Pose.groom : Pose.stand) : b.pose
        if shown[i] != pose { shown[i] = pose; s.texture = frames[pose.rawValue] }
        let l = lampAt(x, y) / pal.lamp.0
        if abs(s.color.redComponent - l) > 0.02 { s.color = NSColor(srgbRed: l, green: l * (1 - 0.1 * (1 - l)), blue: l * (1 - 0.25 * (1 - l)), alpha: 1); s.colorBlendFactor = 1 }
    }
}

// MARK: drawing

func ms(_ t0: UInt64) -> Double { Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6 }
let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: W, height: H, mipmapped: false)
desc.usage = [.renderTarget, .shaderRead]
desc.storageMode = .shared
let target = device.makeTexture(descriptor: desc)!
let renderer = SKRenderer(device: device)
renderer.scene = scene
let start = ProcessInfo.processInfo.systemUptime + 1
var lastHourStep = -1.0

@discardableResult func draw(_ t: Double, stepBees: Bool = true) -> (gpu: Double, cpu: Double) {
    let t0 = DispatchTime.now().uptimeNanoseconds
    if stepBees && cfg.still != true { while simTime < t { step() } }
    // the comb's clock, stepped once a second of the farm, so the kept comb is drawn again only then
    scrollNow = scrollAt(t)
    if !mixing && floor(t) != lastHourStep {
        lastHourStep = floor(t)
        let h = hourAt(t)
        for u in slotU {
            let st = state(h + 24 * Double(u.k))
            u.stateA.vectorFloat4Value = [Float(st.0), Float(st.1), Float(st.2), 0]
            if let b = u.stateB { let sb = state(h + 24 * Double(u.nextK)); b.vectorFloat4Value = [Float(sb.0), Float(sb.1), Float(sb.2), 0] }
            u.origin.vectorFloat2Value = [0, Float(u.top - scrollNow)]
        }
        for (o, y0) in barOrigins { o.vectorFloat2Value = [0, Float(y0 - scrollNow)] }
        if dissolving { mixU.floatValue = Float(fAt(t)) }
    }
    mover.position = CGPoint(x: 0, y: scrollNow)
    beeLayer.position = CGPoint(x: 0, y: scrollNow)
    place(t)
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    renderer.update(atTime: start + t)
    let buf = queue.makeCommandBuffer()!
    renderer.render(withViewport: CGRect(x: 0, y: 0, width: W, height: H), commandBuffer: buf, renderPassDescriptor: pass)
    buf.commit()
    buf.waitUntilCompleted()
    let gpu = (buf.gpuEndTime - buf.gpuStartTime) * 1000
    return (gpu, ms(t0) - gpu)
}
func pixels() -> [UInt8] {
    var px = [UInt8](repeating: 0, count: W * H * 4)
    target.getBytes(&px, bytesPerRow: W * 4, from: MTLRegionMake2D(0, 0, W, H), mipmapLevel: 0)
    return px
}
/// The frame scaled down by `k` (2: the desktop's size in points), RGBA, row 0 at the top.
func scaled(_ px: [UInt8], _ k: Int) -> [UInt8] {
    let (w, h) = (W / k, H / k)
    var out = [UInt8](repeating: 255, count: w * h * 4)
    let n = k * k
    for j in 0..<h { for i in 0..<w { for c in 0..<3 {
        let s = [2, 1, 0][c]
        var sum = 0
        for dy in 0..<k { for dx in 0..<k { sum += Int(px[((j * k + dy) * W + i * k + dx) * 4 + s]) } }
        out[(j * w + i) * 4 + c] = UInt8((sum + n / 2) / n)
    } } }
    return out
}
func writePNG(_ px: [UInt8], _ w: Int, _ h: Int, _ path: String) {
    var p = px
    let ctx = CGContext(data: &p, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}
/// Black holes: drawn, empty cells clear of any bee whose floor is more than twice as dark as their brightest rim
/// (luma on the 2x frame's values, as research-look.md §2 measures a photo), and how many empty cells show at all.
func holes(_ px: [UInt8]) -> (black: Int, empty: Int, worst: Double) {
    let h = hourAt(simTime)
    var black = 0, empty = 0, worst = 0.0
    func luma(_ x: Double, _ y: Double) -> Double {
        let (i, j) = (Int(x * 2), Int(y * 2))
        guard i >= 1, j >= 1, i < W - 1, j < H - 1 else { return -1 }
        var s = 0.0
        for dj in -1...1 { for di in -1...1 { let k = ((j + dj) * W + i + di) * 4; s += 0.0722 * Double(px[k]) + 0.7152 * Double(px[k + 1]) + 0.2126 * Double(px[k + 2]) } }
        return s / 9
    }
    for i in comb.share.indices {
        let hk = h + comb.day[i]
        guard comb.share[i] <= built(hk) - state(hk).2, hk < comb.fillH[i], comb.holds[i] != 2 else { continue }
        let (x, ys) = comb.pos[i], y = ys - scrollNow
        if bees.contains(where: { abs($0.x - x) < beeLen * 0.75 && abs($0.y - ys) < beeLen * 0.75 }) { continue }
        let f = luma(x, y + 0.35 * cell * 0.33 + 0.12 * cell)
        var rim = 0.0
        for dx in stride(from: -1.4, through: 1.4, by: 0.5) { rim = max(rim, luma(x + cell / 2 + dx, y)) }
        guard f > 0, rim > 0 else { continue }
        empty += 1
        worst = max(worst, rim / max(f, 1))
        if rim / max(f, 1) > 2 { black += 1; if ProcessInfo.processInfo.environment["HOLES"] != nil { print(String(format: "hole %.0f %.0f rim %.0f floor %.0f day %.0f share %.3f", x, y, rim, f, comb.day[i], comb.share[i])) } }
    }
    return (black, empty, worst)
}

let t = tFirst
if let n = cfg.frames { // frames to stdout for ffmpeg, scaled down; `rate` seconds of the farm a second of film
    let fps = cfg.fps ?? 30, k = cfg.down ?? 4
    let out = FileHandle.standardOutput
    for f in 0..<n { draw(t + Double(f) / fps * (cfg.rate ?? 1)); out.write(Data(scaled(pixels(), k))) }
    exit(0)
}
var stats = ""
if let times = cfg.times {
    while simTime < times[0] { step() }
    applyFocus()
    for (i, tt) in times.enumerated() { draw(tt); let k = cfg.full == true ? 1 : 2; writePNG(scaled(pixels(), k), W / k, H / k, cfg.out + String(format: "-%03d.png", i)) }
} else {
    draw(t)
    let px = pixels()
    let hl = holes(px)
    if cfg.full == true { writePNG(scaled(px, 1), W, H, cfg.out) } else { writePNG(scaled(px, 2), W / 2, H / 2, cfg.out) }
    let walking = bees.filter { $0.state == .walk }.count
    stats = String(format: "\"bees\": %d, \"walking\": %d, \"black\": %d, \"empty\": %d, \"worst\": %.2f, \"built\": %.3f, \"bake\": %.1f, \"combs\": %d", bees.count, walking, hl.black, hl.empty, hl.worst, built(hourAt(t)), bakeMs, stacked ? combs.count : slots.count)
}
var gpus: [Double] = [], cpus: [Double] = []
if cfg.timing ?? true { // as the probe timed: medians of 50 frames after 20, stepped at 60 fps
    for f in 0..<70 { let (g, c) = draw(t + Double(f) / 60); if f >= 20 { gpus.append(g); cpus.append(c) } }
}
func median(_ a: [Double]) -> Double { a.isEmpty ? 0 : a.sorted()[a.count / 2] }
print(String(format: "STATS {\"gpu\": %.2f, \"cpu\": %.2f%@}", median(gpus), median(cpus), stats.isEmpty ? "" : ", " + stats))
