// Loom mock-ups, drawn by SpriteKit's SKRenderer as the app's render test draws a wallpaper, so a tile shows what
// the app's shaders can draw. Not app code. The cloth is the method research's (research-method.md: one full-screen
// shader reading a drawdown texture, a texel a crossing, threads and rows in whole device pixels), with what the
// look research says makes cloth read as cloth (research-look.md §1): round threads, wool floats that bulge and are
// hairy at the edges over a fine cotton ground, and nothing quite regular.
//
//   swiftc -O mock.swift -o $TMPDIR/loom-mock && $TMPDIR/loom-mock '<json>'
//
// The JSON: draft (honeysuckle, summer-winter, double-weave, goose-eye), palette (names in `palettes`), pitch (device
// px an end, whole), look (soft, crisp), view (flat, reed, selvedge, bench), band (open warp above the fell, device
// px), contrast (held, real), rows (rows woven: the next row's fraction is the shuttle's place), pace (rows a
// second), wind (steady, weaver), width and height (points, drawn at 2x), out (a .png at points, or "-" for a film's
// raw frames at half the points), crop (x, y, w, h in device px: that piece at 1:1), t, frames, fps.
import Foundation
import Metal
import SpriteKit
import ImageIO

struct Config: Decodable {
    var draft: String
    var palette: String
    var pitch: Double?, look: String?, view: String?, band: Double?, contrast: String?
    var rows: Double?, pace: Double?, wind: String?
    var width: Double?, height: Double?
    var out: String
    var crop: [Double]?
    var t: Double?, frames: Int?, fps: Double?
    var plump: Double?, fuzz: Double?, gap: Double?, wool: Double?, sw: Double?, st: Double? // tuning: the wool's fatness and hair, the ground's gaps, the pattern pick's height in ends
}

// MARK: drafts, all from Mary Meigs Atwater, The Shuttle-Craft Book of American Hand-Weaving (Macmillan, 1928;
// public domain in the US: research-look.md §4), Internet Archive shuttlecraftbook028554mbp.

/// Honeysuckle, her draft No. 6 (Diagram 6, p. 158), read from the right. The first 16 ends are spelled out in her
/// text (p. 107: "4, 3, 2, 1. The next, 4, 3, 4, 3 and 2, 3 then 2, 1, 2, 1, 2, 1"); the other ten follow from her
/// count of heddles a repeat (5 on harness 1, 8 on 2, 8 on 3, 5 on 4) and her treadling (p. 113), which this
/// threading matches block for block when woven as drawn in.
let honeysuckle = [4, 3, 2, 1, 4, 3, 4, 3, 2, 3, 2, 1, 2, 1, 2, 1, 2, 3, 2, 3, 4, 3, 4, 1, 2, 3]
/// Her treadling for it (p. 113): treadle, times. Treadle 1 brings down harnesses 1 and 2, 2 brings 2 and 3, 3
/// brings 3 and 4, 4 brings 1 and 4 (her six-treadle tie-up, p. 95); the tabby sheds are 1&3 and 2&4.
let honeysuckleTreadling = [(3, 2), (2, 1), (1, 1), (4, 1), (3, 3), (2, 3), (1, 6), (2, 3), (3, 3), (4, 1), (1, 1), (2, 1)]
/// Goose-Eye, her No. 291 (p. 272): "When treadled 'as drawn in' 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 2, 1, 4, 3, 2, 1,
/// 4, 3, 2 we have the pattern known as 'Goose-Eye'", so the threading is that too, on a 2/2 twill tie-up.
let gooseEye = [1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 2, 1, 4, 3, 2, 1, 4, 3, 2]

/// A woven cloth, one repeat: which thread is on top at each crossing, its colour, and which rows are pattern rows
/// (a thick wool weft over a fine ground, as overshot and summer-and-winter are woven).
struct Weave {
    var ends: Int, rows: Int
    var warpTop: [Bool] // rows × ends
    var colour: [Int] // the top thread's palette index, rows × ends
    var pattern: [Bool] // per row
    var weft: [Int] // per row: the weft's palette index
}

/// Overshot: each pattern pick on its treadle (the weft over the ends on the two harnesses it brings down, under the
/// rest), then a tabby pick, A and B by turns. Ground 0 for warp and tabby, wool 1 (2 where `alt`, by blocks).
/// `square` scales her pick counts to the yarns' sizes: a pattern pick and its tabby are about two ends tall in real
/// coverlets (research-method.md §2), so each block is woven for about half its ends in pattern picks, "until
/// square", as overshot woven as drawn in is meant to be.
func overshot(_ threading: [Int], _ treadling: [(Int, Int)], alt: Bool, square: Double = 0.5) -> Weave {
    let sunk: [Int: Set<Int>] = [1: [1, 2], 2: [2, 3], 3: [3, 4], 4: [1, 4]]
    var w = Weave(ends: threading.count, rows: 0, warpTop: [], colour: [], pattern: [], weft: [])
    var tabby = 0
    for (b, (treadle, times)) in treadling.enumerated() {
        for _ in 0..<max(1, Int((Double(times) * square).rounded())) {
            let wool = alt && b % 2 == 1 ? 2 : 1
            for s in threading { w.warpTop.append(!sunk[treadle]!.contains(s)) }
            w.pattern.append(true); w.weft.append(wool)
            for s in threading { w.warpTop.append(s % 2 != tabby) }
            w.pattern.append(false); w.weft.append(0)
            tabby ^= 1
        }
    }
    w.rows = w.pattern.count
    w.colour = (0..<w.rows).flatMap { r in (0..<w.ends).map { e in w.warpTop[r * w.ends + e] ? 0 : w.weft[r] } }
    return w
}

/// A profile: the blocks of an overshot threading (1-2 is A, 2-3 B, 3-4 C, 1-4 D), one square for each pair of
/// neighbouring ends, as Atwater's short-form drafts for the "more elaborate weaves" are written (p. 149).
func profile(_ threading: [Int]) -> [Int] {
    (0..<threading.count).map { i in
        let a = threading[i], b = threading[(i + 1) % threading.count], pair = Set([a, b])
        return pair == [1, 2] ? 0 : pair == [2, 3] ? 1 : pair == [3, 4] ? 2 : 3
    }
}
func treadlingBlocks(_ t: [(Int, Int)]) -> [Int] { t.flatMap { (treadle, times) in Array(repeating: treadle - 1, count: times) } }

/// Summer and winter from a profile (p. 150): each square four ends, a tie-down, the block's pattern harness, the
/// other tie-down, the pattern harness again. Each pick of the profile's treadling is two pattern picks (on one
/// tie-down, then the other) with a tabby after each. The weft lies over the ends of the blocks woven, but for the
/// tie-down that is up, and under the rest but for the other tie-down: over three and under one, or the reverse.
func summerWinter(_ squares: [Int], _ picks: [Int]) -> Weave {
    var ends: [(tie: Int, block: Int)] = []
    for b in squares { ends += [(1, -1), (0, b), (2, -1), (0, b)] }
    var w = Weave(ends: ends.count, rows: 0, warpTop: [], colour: [], pattern: [], weft: [])
    for b in picks {
        for tie in [1, 2] {
            for e in ends { w.warpTop.append(e.tie == tie || (e.tie == 0 && e.block != b)) }
            w.pattern.append(true); w.weft.append(1)
            for e in ends { w.warpTop.append(tie == 1 ? e.tie != 0 : e.tie == 0) }
            w.pattern.append(false); w.weft.append(0)
        }
    }
    w.rows = w.pattern.count
    w.colour = (0..<w.rows).flatMap { r in (0..<w.ends).map { e in w.warpTop[r * w.ends + e] ? 0 : w.weft[r] } }
    return w
}

/// Double weave from a profile: two cloths of plain weave, one in the wool's colour and one in the ground's, that
/// change places at every block; where the block woven is the end's own, the coloured cloth is on top. What shows is
/// the face cloth's plain weave, four ends a square and four picks a pick of the treadling.
func doubleWeave(_ squares: [Int], _ picks: [Int]) -> Weave {
    let ends = squares.flatMap { Array(repeating: $0, count: 4) }, rows = picks.flatMap { Array(repeating: $0, count: 4) }
    var w = Weave(ends: ends.count, rows: rows.count, warpTop: [], colour: [], pattern: Array(repeating: false, count: rows.count), weft: [])
    for (r, b) in rows.enumerated() {
        for (e, a) in ends.enumerated() { w.warpTop.append((r + e) % 2 == 0); w.colour.append(a == b ? 1 : 0) }
        w.weft.append(0)
    }
    return w
}

/// A 2/2 twill: the warp in the wool's colour, the weft in the ground's.
func twill(_ threading: [Int], _ treadling: [Int]) -> Weave {
    let sunk: [Int: Set<Int>] = [1: [1, 2], 2: [2, 3], 3: [3, 4], 4: [1, 4]]
    var w = Weave(ends: threading.count, rows: treadling.count, warpTop: [], colour: [], pattern: Array(repeating: false, count: treadling.count), weft: [])
    for t in treadling {
        for s in threading { let up = !sunk[t]!.contains(s); w.warpTop.append(up); w.colour.append(up ? 1 : 0) }
        w.weft.append(0)
    }
    return w
}

func weave(_ name: String, alt: Bool) -> Weave {
    switch name {
    case "summer-winter": return summerWinter(profile(honeysuckle), treadlingBlocks(honeysuckleTreadling))
    case "double-weave": return doubleWeave(profile(honeysuckle), treadlingBlocks(honeysuckleTreadling))
    case "goose-eye": return twill(gooseEye, gooseEye)
    default: return overshot(honeysuckle, honeysuckleTreadling, alt: alt)
    }
}

// MARK: colours (research-look.md §2: sampled from museum pieces, then held to the caps in §3)

/// Ground (warp and tabby), wool, a second wool (red and blue only), the floor beside the cloth, the dark behind it.
struct Palette { var ground: Int, wool: Int, real: Int, alt: Int = 0, floor: Int = 0x15110E, back: Int = 0x0A0908, expo = 0.9 }
let palettes: [String: Palette] = [
    "indigo": Palette(ground: 0xDCD8CB, wool: 0x4F6A8C, real: 0x1D2035),
    "madder": Palette(ground: 0xDDD3C6, wool: 0x9A4331, real: 0x7C2E28),
    "walnut": Palette(ground: 0xE0D2BF, wool: 0x6A4E3E, real: 0x4A3328),
    "weld": Palette(ground: 0xDDD8CC, wool: 0x8E7A50, real: 0x594E2D),
    "undyed": Palette(ground: 0xE2D8C6, wool: 0x6B5444, real: 0x2D2826),
    "red-blue": Palette(ground: 0xE1D7CC, wool: 0x9A4331, real: 0x9A4331, alt: 0x2F343F),
    "blue-on-blue": Palette(ground: 0x0A1430, wool: 0x2E4E72, real: 0x3E5F86, floor: 0x06070A, expo: 0.42),
    "madder-dark": Palette(ground: 0x2A0A0E, wool: 0x8A3A33, real: 0x963F34, floor: 0x08060A, expo: 0.42),
    "walnut-dark": Palette(ground: 0x1E1512, wool: 0x7E685C, real: 0x8E7868, floor: 0x080706, expo: 0.42),
    "black-sheep": Palette(ground: 0x2D2B32, wool: 0x958888, real: 0xA89A98, floor: 0x09090B, expo: 0.42),
]

// MARK: the shader

let source = """
float h21(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void main() {
    vec2 sp = vec2(v_tex_coord.x, 1.0 - v_tex_coord.y) * u_px;
    float X = sp.x - u_margin;
    float C = u_take + (u_yref - sp.y);
    float depth = 1.0;
    if (u_view > 2.5) {
        // from the bench: the cloth's plane in perspective, the near edge at the bottom of the screen
        float yb = u_px.y - sp.y;
        depth = u_hor / max(u_hor - yb, 1.0);
        X = u_px.x * 0.5 + (sp.x - u_px.x * 0.5) * depth;
        // the fell 58% of the way up: a hand's width of cloth between it and the breast beam, foreshortened
        float ybF = u_px.y * 0.58;
        C = u_take + (yb - ybF * u_hor / (u_hor - ybF) / depth) * depth * 1.6;
    }
    vec2 fw = max(fwidth(vec2(X, C)) * 0.785, vec2(0.001));
    float P = u_P;
    float pairH = u_hp + u_ht;
    float qx = X / P; float e = floor(qx); float fx = qx - e;
    float pr = floor(C / pairH); float rem = C - pr * pairH;
    float sub = step(u_hp, rem); float row = 2.0 * pr + sub;
    float rh = mix(u_hp, u_ht, sub);
    float fy = (rem - sub * u_hp) / rh;
    // how far the shuttle is across the row in the weaving, from the side it entered
    float N = floor(u_rows); float fr = u_rows - N;
    float eIn = mix(u_ends - 1.0 - e, e, 1.0 - mod(N, 2.0));
    float coverN = clamp((min(fr / u_cross, 1.0) * (u_ends + 6.0) - 3.0 - eIn) / 3.0, 0.0, 1.0);
    float woven = row < N ? 1.0 : (row < N + 0.5 ? coverN : 0.0);
    float detail = 1.0 - smoothstep(0.15, 0.45, max(fw.x / P, fw.y / max(rh, 1.0)));
    vec3 L = normalize(vec3(-0.35, 0.5, 0.8));

    vec4 t = texture2D(u_draw, vec2(mod(e, u_grid.x) + 0.5, mod(row, u_grid.y) + 0.5) / u_grid);
    float fl = floor(t.r * 255.0 + 0.5);
    float warpTop = mod(fl, 2.0); float prevC = mod(floor(fl * 0.5), 2.0); float nextC = mod(floor(fl * 0.25), 2.0);
    float isPat = mod(floor(fl * 0.125), 2.0);
    float seed = t.b;
    vec3 topc = texture2D(u_pal, vec2(floor(t.g * 255.0 + 0.5) + 0.5, 0.5) / vec2(8.0, 1.0)).rgb;
    topc *= topc;
    vec4 rw = texture2D(u_rowc, vec2(mod(row, u_grid.y) + 0.5, 0.5) / vec2(u_grid.y, 1.0));
    vec3 weftc = texture2D(u_pal, vec2(floor(rw.r * 255.0 + 0.5) + 0.5, 0.5) / vec2(8.0, 1.0)).rgb;
    weftc *= weftc;
    vec4 wp = texture2D(u_warpc, vec2(mod(e, u_grid.x) + 0.5, 0.5) / vec2(u_grid.x, 1.0));
    vec3 warpc = texture2D(u_pal, vec2(floor(wp.r * 255.0 + 0.5) + 0.5, 0.5) / vec2(8.0, 1.0)).rgb;
    warpc *= warpc;
    vec3 back = texture2D(u_pal, vec2(4.5, 0.5) / vec2(8.0, 1.0)).rgb; back *= back;

    // the ground: the thread on top at this crossing, round, with the gap between threads dark
    float across = mix(fy, fx, warpTop);
    float along = mix(fx, fy, warpTop);
    float sw = mix(u_st, u_sw, warpTop) * (0.92 + 0.16 * seed) * (1.0 + 0.08 * (vn(vec2(along * 0.6 + seed * 37.0, e * 3.1 + row * 1.7)) - 0.5) * detail);
    float off = (h21(vec2(seed * 91.0, 3.0)) - 0.5) * 0.12;
    float d = clamp((across - 0.5 - off) / sw * 0.5, -1.0, 1.0);
    vec3 n = mix(vec3(0.0, d, sqrt(max(1.0 - d * d, 0.0))), vec3(d, 0.0, sqrt(max(1.0 - d * d, 0.0))), warpTop);
    float lam = 1.0 - u_relief + u_relief * 1.25 * max(dot(n, L), 0.0);
    float dive = mix(1.0, 0.5 + 0.5 * smoothstep(-0.05, 0.45, along), 1.0 - prevC) * mix(1.0, 0.5 + 0.5 * smoothstep(-0.05, 0.45, 1.0 - along), 1.0 - nextC);
    float fib = 1.0 + 0.10 * (vn(vec2(along * 1.5 + seed * 13.0, across * 9.0)) - 0.5) * detail;
    float wa = mix(fw.y / max(rh, 1.0), fw.x / P, warpTop);
    float cover = mix(sw, clamp((sw * 0.5 - abs(across - 0.5 - off)) / max(wa, 0.06) + 0.5, 0.0, 1.0), 1.0 - smoothstep(0.3, 0.8, wa));
    vec3 thr = topc * (0.93 + 0.14 * seed) * mix(0.85, lam * dive * fib, detail);
    vec3 under = mix(mix(back, topc, u_gap), weftc * 0.35, isPat);
    vec3 col = mix(under, thr, cover);
    // a pattern row's weft on top is the wool, drawn below; what lies under it is in shadow
    col = mix(col, weftc * 0.3, isPat * (1.0 - warpTop));

    // the wool: the pattern floats of this pair and the pairs either side, fat, soft and hairy, over the ground
    if (u_supp > 0.5) {
        for (int k = 0; k < 3; k++) {
            float dk = k == 0 ? -1.0 : (k == 1 ? 1.0 : 0.0);
            float rp = 2.0 * (pr + dk);
            float wv = rp < N ? 1.0 : (rp < N + 0.5 ? coverN : 0.0);
            vec4 f = texture2D(u_draw, vec2(mod(e, u_grid.x) + 0.5, mod(rp, u_grid.y) + 0.5) / u_grid);
            float ff = floor(f.r * 255.0 + 0.5);
            float on = (1.0 - mod(ff, 2.0)) * wv;
            float info = floor(f.a * 255.0 + 0.5);
            float flen = mod(info, 16.0) + 1.0; float fidx = floor(info / 16.0);
            float u = (fidx + fx) / flen;
            float ue = min(u, 1.0 - u) * flen;
            float pinch = 0.5 + 0.5 * smoothstep(0.0, 0.5, ue);
            float wd = 1.0 - smoothstep(0.15, 0.45, max(fw.x / P, fw.y / u_hp));
            float hh = 0.5 * u_hp * u_plump * (1.0 + 0.3 * sin(3.14159 * u) * min(flen - 1.0, 3.0) / 3.0) * pinch * (0.9 + 0.2 * f.b);
            float dc = C - ((pr + dk) * pairH + 0.5 * u_hp);
            float edge = hh * (1.0 + u_fuzz * (0.3 * (vn(vec2(X / P * 2.5 + f.b * 40.0, C / P * 1.2)) - 0.5) + 0.2 * (vn(vec2(X / P * 7.0, C / P * 3.0 + 5.0)) - 0.5)));
            float cov = clamp((edge - abs(dc)) / max(fw.y * 1.3, u_fuzz * 0.12 * P) + 0.5, 0.0, 1.0) * on;
            float hair = u_fuzz * 0.6 * (1.0 - smoothstep(edge, edge + 0.4 * P, abs(dc))) * smoothstep(0.5, 0.8, vn(vec2(X / P * 9.0 + f.b * 9.0, dc / P * 2.5))) * on * wd;
            float ny = clamp(dc / max(edge, 0.01), -1.0, 1.0);
            float nz = sqrt(max(1.0 - ny * ny, 0.0));
            float nx = (u < 0.5 ? -1.0 : 1.0) * (1.0 - pinch) * 1.6;
            vec3 wn = normalize(vec3(nx, ny, nz));
            // a pillow: lit on its crown, in shadow where it dives and where it meets its neighbours
            float wl = (1.0 - u_relief + u_relief * 1.35 * max(dot(wn, L), 0.0)) * mix(1.0, mix(0.3, 1.0, nz * mix(0.5, 1.0, pinch)), wd);
            // strands along the float, some lighter and some darker, and a slow change of shade along it
            float st = vn(vec2(X / P * 1.1 + f.b * 31.0 + 0.6 * sin(dc / u_hp * 5.0), dc / u_hp * 6.0 + f.b * 3.0)) * 0.55 + vn(vec2(X / P * 2.8, dc / u_hp * 11.0 + 11.0)) * 0.45;
            float wfib = 1.0 + u_fuzz * 0.42 * (st - 0.5) * wd;
            vec4 frw = texture2D(u_rowc, vec2(mod(rp, u_grid.y) + 0.5, 0.5) / vec2(u_grid.y, 1.0));
            vec3 wool = texture2D(u_pal, vec2(floor(frw.r * 255.0 + 0.5) + 0.5, 0.5) / vec2(8.0, 1.0)).rgb;
            wool *= wool * (0.9 + 0.2 * f.b);
            col = mix(col, wool * 0.85, hair * (1.0 - cov));
            col = mix(col, wool * mix(0.85, wl * wfib, wd), cov);
        }
    }

    // above the fell: the warp, open, half of it lifted for the next pick
    float wsw = u_sw * 0.85;
    float dwo = clamp((fx - 0.5) / wsw * 0.5 * 2.0, -1.0, 1.0);
    float wcov = mix(wsw, clamp((wsw * 0.5 - abs(fx - 0.5)) / max(fw.x / P, 0.06) + 0.5, 0.0, 1.0), 1.0 - smoothstep(0.3, 0.8, fw.x / P));
    vec4 nx4 = texture2D(u_draw, vec2(mod(e, u_grid.x) + 0.5, mod(N, u_grid.y) + 0.5) / u_grid);
    float lifted = mod(floor(nx4.r * 255.0 + 0.5), 2.0);
    vec3 warpOpen = warpc * mix(0.8, 0.6 + 0.4 * sqrt(max(1.0 - dwo * dwo, 0.0)), detail) * mix(0.72, 1.0, lifted);
    vec3 open = mix(back, warpOpen, wcov);
    col = mix(open, col, woven);

    // the reed at the top of the band: a dark rail, and the reed's fine wires a dent (two ends) apart
    if (u_view > 0.5 && u_view < 1.5) {
        float ry = u_reed - sp.y;
        float wire = 1.0 - smoothstep(0.0, 1.5, abs(mod(X, 2.0 * P) - P));
        vec3 reed = mix(open * 0.55, vec3(0.05, 0.05, 0.055), wire * 0.8);
        col = mix(col, reed, step(0.0, ry) * step(ry, u_reedH));
        col = mix(col, vec3(0.012, 0.009, 0.007) * (0.8 + 0.4 * vn(vec2(X * 0.01, sp.y * 0.2))), step(u_reedH, ry));
    }
    // beside the cloth: the floor, past selvedges that waver a little from pick to pick
    if (u_view > 1.5 && u_view < 2.5) {
        float wob = (h21(vec2(row, 7.0)) - 0.5) * 0.5 * P;
        float inside = clamp((X - wob) / 1.5, 0.0, 1.0) * clamp((u_clothW - X + wob) / 1.5, 0.0, 1.0);
        vec3 floorc = texture2D(u_pal, vec2(3.5, 0.5) / vec2(8.0, 1.0)).rgb;
        floorc *= floorc * (0.85 + 0.3 * vn(vec2(sp.x * 0.004, sp.y * 0.03)));
        col = mix(floorc, col, inside);
    }
    // from the bench: the cloth rolls away over the breast beam at the bottom, and the warp fades into the loom
    if (u_view > 2.5) {
        float yb = u_px.y - sp.y;
        col *= mix(0.35, 1.0, smoothstep(0.0, u_px.y * 0.12, yb));
        // 2.5 cm of open warp past the fell, then the reed standing in the beater, then the dark of the loom with
        // the warp running back into it
        float ybF = u_px.y * 0.58; float kF = ybF * u_hor / (u_hor - ybF) * 1.6;
        float a = (2.5 * 11.8 * P + kF) / 1.6; float ybR = a * u_hor / (u_hor + a);
        float dR = u_hor / (u_hor - ybR);
        float xr = u_px.x * 0.5 + (sp.x - u_px.x * 0.5) * dR;
        float wire = 1.0 - smoothstep(0.0, 1.2, abs(mod(xr, 2.0 * P) - P) / dR);
        float hR = u_px.y * 0.08;
        vec3 reed = mix(vec3(0.03, 0.028, 0.026), vec3(0.16, 0.16, 0.17), wire);
        vec3 beyond = mix(back, warpOpen * 0.25, wcov * (1.0 - smoothstep(ybR, u_px.y, yb)));
        col = mix(col, reed, step(ybR, yb) * (1.0 - step(ybR + hR, yb)));
        col = mix(col, vec3(0.022, 0.016, 0.011) * (0.8 + 0.4 * vn(vec2(sp.x * 0.01, sp.y * 0.3))), step(ybR + hR, yb) * (1.0 - step(ybR + hR * 1.5, yb)));
        col = mix(col, beyond, step(ybR + hR * 1.5, yb));
    }
    col *= u_expo;
    gl_FragColor = vec4(sqrt(max(col, vec3(0.0))), 1.0);
}
"""

// MARK: textures

func texture(_ bytes: [UInt8], _ w: Int, _ h: Int) -> SKTexture {
    let t = SKTexture(data: Data(bytes), size: CGSize(width: w, height: h))
    t.filteringMode = .nearest
    return t
}
func rgb(_ hex: Int) -> [UInt8] { [UInt8(hex >> 16 & 255), UInt8(hex >> 8 & 255), UInt8(hex & 255), 255] }

/// SplitMix64: the same cloth for the same seed.
struct Rand {
    var s: UInt64
    mutating func next() -> Double {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}

/// The drawdown as a texel a crossing: R flags (1 warp on top, 2 the float carries on before along its own thread,
/// 4 after, 8 a pattern row), G the top thread's palette index, B a random number for that thread, A where the
/// crossing sits in its float (index × 16 + length − 1, each up to 15). Rows' wefts and ends' colours alongside.
func bake(_ w: Weave) -> (draw: [UInt8], rows: [UInt8], warp: [UInt8]) {
    var rng = Rand(s: 7)
    let endSeed = (0..<w.ends).map { _ in UInt8(rng.next() * 255) }, rowSeed = (0..<w.rows).map { _ in UInt8(rng.next() * 255) }
    func up(_ r: Int, _ e: Int) -> Bool { w.warpTop[((r % w.rows + w.rows) % w.rows) * w.ends + (e % w.ends + w.ends) % w.ends] }
    var draw = [UInt8](repeating: 0, count: w.ends * w.rows * 4)
    for r in 0..<w.rows { for e in 0..<w.ends {
        let u = up(r, e)
        // the float this crossing is in, along its own thread: the warp up the rows, the weft across the ends
        var before = 0, after = 0
        if u {
            while before < 15 && up(r - before - 1, e) { before += 1 }
            while after < 15 && up(r + after + 1, e) { after += 1 }
        } else {
            while before < 15 && !up(r, e - before - 1) { before += 1 }
            while after < 15 && !up(r, e + after + 1) { after += 1 }
        }
        let len = min(before + after + 1, 16)
        let k = (r * w.ends + e) * 4
        draw[k] = UInt8((u ? 1 : 0) | (before > 0 ? 2 : 0) | (after > 0 ? 4 : 0) | (w.pattern[r] ? 8 : 0))
        draw[k + 1] = UInt8(w.colour[r * w.ends + e])
        draw[k + 2] = u ? endSeed[e] : rowSeed[r]
        draw[k + 3] = UInt8(min(before, 15) * 16 + len - 1)
    } }
    let rows: [UInt8] = (0..<w.rows).flatMap { r -> [UInt8] in [UInt8(w.weft[r]), rowSeed[r], 0, 255] }
    // an end's colour: what it shows where it is on top (its own thread's colour)
    let warp: [UInt8] = (0..<w.ends).flatMap { e -> [UInt8] in
        let r = (0..<w.rows).first { w.warpTop[$0 * w.ends + e] } ?? 0
        return [UInt8(w.colour[r * w.ends + e]), endSeed[e], 0, 255]
    }
    return (draw, rows, warp)
}

// MARK: rendering

let device = MTLCreateSystemDefaultDevice()!, queue = device.makeCommandQueue()!

final class Target {
    let w: Int, h: Int, tex: MTLTexture, pass = MTLRenderPassDescriptor()
    init(_ w: Int, _ h: Int) {
        (self.w, self.h) = (w, h)
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]; d.storageMode = .shared
        tex = device.makeTexture(descriptor: d)!
        pass.colorAttachments[0].texture = tex; pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
    }
    /// RGBA, top row first.
    func rgba() -> [UInt8] {
        var b = [UInt8](repeating: 0, count: w * h * 4)
        tex.getBytes(&b, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        for n in 0..<w * h { b.swapAt(n * 4, n * 4 + 2); b[n * 4 + 3] = 255 }
        return b
    }
}

/// The average of each k × k square (the display's light is averaged, as a reduced still must be: research-method.md §4).
func reduce(_ px: [UInt8], _ w: Int, _ h: Int, by k: Int) -> [UInt8] {
    let ow = w / k, oh = h / k
    var out = [UInt8](repeating: 255, count: ow * oh * 4)
    for y in 0..<oh { for x in 0..<ow { for c in 0..<3 {
        var s = 0.0
        for dy in 0..<k { for dx in 0..<k { let v = Double(px[((y * k + dy) * w + x * k + dx) * 4 + c]) / 255; s += v * v } }
        out[(y * ow + x) * 4 + c] = UInt8(min(255, (s / Double(k * k)).squareRoot() * 255 + 0.5))
    } } }
    return out
}

func savePNG(_ px: [UInt8], _ w: Int, _ h: Int, to path: String) {
    var b = px
    let ctx = CGContext(data: &b, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

@MainActor func main() {
    let cfg = try! JSONDecoder().decode(Config.self, from: CommandLine.arguments[1].data(using: .utf8)!)
    let pts = CGSize(width: cfg.width ?? 1512, height: cfg.height ?? 982)
    let (W, H) = (Int(pts.width * 2), Int(pts.height * 2))
    let pal = palettes[cfg.palette]!, real = cfg.contrast == "real"
    let w = weave(cfg.draft, alt: cfg.palette == "red-blue")
    let supp = w.pattern.contains(true)
    // an end and a row in whole device pixels (research-method.md §4, rule 1); a pattern pick and its tabby about
    // two ends together, as in real coverlets (§2: 30 ends and 13–18 pattern picks an inch)
    let P = max(2.0, (cfg.pitch ?? 8).rounded())
    let (hp, ht) = supp ? ((P * (cfg.wool ?? 1.4)).rounded(), max(1, (P * 0.6).rounded())) : (P, P)
    let soft = cfg.look != "crisp"
    let view = ["flat": 0.0, "reed": 1, "selvedge": 2, "bench": 3][cfg.view ?? "flat"]!
    let band = cfg.band ?? 60
    let margin = view == 2 ? (Double(W) * 0.16).rounded() : 0
    let clothW = Double(W) - 2 * margin

    var paletteBytes = [UInt8](repeating: 255, count: 8 * 4)
    for (i, c) in [pal.ground, real ? pal.real : pal.wool, pal.alt, pal.floor, pal.back].enumerated() { paletteBytes.replaceSubrange(i * 4..<i * 4 + 4, with: rgb(c)) }
    let b = bake(w)

    // Where the weaving is: rows woven (the shuttle's place in the next), and how much cloth has been wound on.
    func rowStart(_ r: Double) -> Double { (r / 2).rounded(.down) * (hp + ht) + (Int(r) % 2 == 1 ? hp : 0) }
    func clothPos(_ x: Double) -> Double { let r = x.rounded(.down); return rowStart(r) + (x - r) * (Int(r) % 2 == 1 ? ht : hp) }
    let wind = cfg.wind == "weaver" ? (5 * 11.8 * P).rounded() : 0 // a weaver winds on about 5 cm at a time
    func state(_ t: Double) -> (rows: Double, take: Double, yref: Double) {
        let rows = (cfg.rows ?? 2000) + (cfg.pace ?? 0) * t
        if wind == 0 { return (rows, clothPos(rows).rounded(.down), band) }
        // as a weaver works: the fell climbs a hand's width, then the cloth is wound on over four seconds
        let q = clothPos(rows) / wind, k = q.rounded(.down), phase = q - k
        let span = 4 * (cfg.pace ?? 1) * (hp + ht) / 2 / wind
        let s = min(max(phase / max(span, 1e-6), 0), 1), ease = s * s * (3 - 2 * s)
        return (rows, ((k - 1 + ease) * wind).rounded(.down), band + wind)
    }

    let scene = SKScene(size: pts)
    let sprite = SKSpriteNode(color: .black, size: pts)
    sprite.anchorPoint = .zero
    let uRows = SKUniform(name: "u_rows", float: 0), uTake = SKUniform(name: "u_take", float: 0), uYref = SKUniform(name: "u_yref", float: 0)
    let horizon = Double(H) * 1.15
    sprite.shader = SKShader(source: source, uniforms: [
        SKUniform(name: "u_px", vectorFloat2: [Float(W), Float(H)]),
        SKUniform(name: "u_P", float: Float(P)), SKUniform(name: "u_hp", float: Float(hp)), SKUniform(name: "u_ht", float: Float(ht)),
        SKUniform(name: "u_supp", float: supp ? 1 : 0), SKUniform(name: "u_grid", vectorFloat2: [Float(w.ends), Float(w.rows)]),
        SKUniform(name: "u_draw", texture: texture(b.draw, w.ends, w.rows)), SKUniform(name: "u_rowc", texture: texture(b.rows, w.rows, 1)),
        SKUniform(name: "u_warpc", texture: texture(b.warp, w.ends, 1)), SKUniform(name: "u_pal", texture: texture(paletteBytes, 8, 1)),
        SKUniform(name: "u_ends", float: Float(clothW / P)), SKUniform(name: "u_margin", float: Float(margin)), SKUniform(name: "u_clothW", float: Float(clothW)),
        SKUniform(name: "u_view", float: Float(view)), SKUniform(name: "u_hor", float: Float(horizon)),
        SKUniform(name: "u_reed", float: Float(band * 0.62)), SKUniform(name: "u_reedH", float: Float(max(10, P * 1.5))),
        SKUniform(name: "u_sw", float: Float(cfg.sw ?? (soft ? 0.85 : 0.74))), SKUniform(name: "u_st", float: Float(cfg.st ?? (soft ? 0.95 : 0.76))),
        SKUniform(name: "u_gap", float: Float(cfg.gap ?? (soft ? 0.6 : 0.16))), SKUniform(name: "u_relief", float: soft ? 0.42 : 0.72),
        SKUniform(name: "u_plump", float: Float(cfg.plump ?? (soft ? 1.6 : 1.0))), SKUniform(name: "u_fuzz", float: Float(cfg.fuzz ?? (soft ? 2.4 : 0.15))),
        SKUniform(name: "u_expo", float: Float(pal.expo * (soft ? 1.0 : 1.05))), uRows, uTake, uYref,
        SKUniform(name: "u_cross", float: Float(min(1, 1.5 * (cfg.pace ?? 1)))),
    ])
    scene.addChild(sprite)

    let renderer = SKRenderer(device: device)
    renderer.scene = scene
    let target = Target(W, H)
    let clock = ProcessInfo.processInfo.systemUptime + 1
    var gpu: [Double] = [], cpu: [Double] = []
    func draw(_ t: Double, timed: Bool = false) {
        let t0 = CFAbsoluteTimeGetCurrent()
        let s = state(t)
        uRows.floatValue = Float(s.rows); uTake.floatValue = Float(s.take); uYref.floatValue = Float(s.yref)
        renderer.update(atTime: clock + t)
        let buffer = queue.makeCommandBuffer()!
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: W, height: H), commandBuffer: buffer, renderPassDescriptor: target.pass)
        buffer.commit(); buffer.waitUntilCompleted()
        if timed { let g = buffer.gpuEndTime - buffer.gpuStartTime; gpu.append(g * 1000); cpu.append((CFAbsoluteTimeGetCurrent() - t0 - g) * 1000) }
    }

    if let frames = cfg.frames {
        // a film's raw frames at a quarter of the device pixels (half the points), averaged, to stdout
        let fps = cfg.fps ?? 30
        for f in 0..<frames {
            draw((cfg.t ?? 0) + Double(f) / fps)
            let small = reduce(target.rgba(), W, H, by: 4)
            FileHandle.standardOutput.write(Data(small))
        }
        return
    }
    for i in 0..<12 { draw((cfg.t ?? 0) + Double(i) / 60 * 0, timed: i >= 4) }
    draw(cfg.t ?? 0)
    let px = target.rgba()
    if let c = cfg.crop {
        let (x0, y0, cw, ch) = (Int(c[0]), Int(c[1]), Int(c[2]), Int(c[3]))
        var out = [UInt8](repeating: 0, count: cw * ch * 4)
        for y in 0..<ch { for x in 0..<cw { for k in 0..<4 { out[(y * cw + x) * 4 + k] = px[((y0 + y) * W + x0 + x) * 4 + k] } } }
        savePNG(out, cw, ch, to: cfg.out)
    } else {
        savePNG(reduce(px, W, H, by: 2), W / 2, H / 2, to: cfg.out)
    }
    let med = { (a: [Double]) in a.sorted()[a.count / 2] }
    print("STATS " + String(format: "{\"gpu\": %.3f, \"cpu\": %.3f, \"ends\": %d, \"rows\": %d}", med(gpu), med(cpu), w.ends, w.rows))
}

MainActor.assumeIsolated { main() }
