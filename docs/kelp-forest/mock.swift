// Kelp Forest mock-ups, drawn by SpriteKit's SKRenderer as the app's render test draws a wallpaper, so a tile shows
// what the app's shaders can draw. Not app code, but its water and fronds are meant to carry into the build.
//
//   swiftc -O mock.swift -o $TMPDIR/kelp-mock && $TMPDIR/kelp-mock '<json>'
//
// The world is in metres: the sea floor at y = 0, the surface at y = depth, the camera at (0, camY, 0) looking along
// +z, tipped up by pitch. A full-screen shader draws the water, the underside of the surface with its window of sky
// and the canopy lying on it, the floor, and the shafts of sunlight let through the canopy's gaps. Each frond (one
// stipe with its blades) is a sprite whose shader hangs the blades along a spine of eight points the CPU projects
// from a chain simulation of each frond in the sea. The JSON: look (names below), seed, t, width, height (points,
// drawn at 2x), out (a .png, or a path prefix with times or frames). Optional: times, frames, fps, pitch, camY,
// depth, fov, plants, fronds (most a plant), near and far (where plants stand, m), surge (significant wave height, m),
// period (the swell's peak, s), current (m/s), canopy (0 to 1), kelp (giant, bull or mixed), tank (an aquarium's back
// wall, m), expo, rays, sunElev, sunAz, speed.
import Foundation
import Metal
import SpriteKit

struct Config: Decodable {
    var look: String
    var seed: UInt64?, t: Double?, width: Double?, height: Double?
    var out: String
    var times: [Double]?, frames: Int?, fps: Double?, speed: Double?
    var pitch: Double?, camY: Double?, depth: Double?, fov: Double?
    var plants: Int?, fronds: Int?, near: Double?, far: Double?
    var surge: Double?, period: Double?, current: Double?, canopy: Double?
    var sunElev: Double?, sunAz: Double?, rays: Double?, kelp: String?
    var carry: Double? // how much of the swell carries the camera, 0 (fixed to the floor) to 1 (as the water moves)
    var expo: Double? // exposure, to hold a bright view to the look research's caps
    var tank: Double? // an aquarium: its back wall this far off, m, seen through a window of mullions
}

/// SplitMix64: the same forest for the same seed.
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

/// A look: the water's colour and clarity, the light, and the kelp. Colours are sRGB hex, worked in linear light.
struct Look {
    var ext: SIMD3<Double> // extinction per metre, red green blue
    var deep: Int, up: Int // the water's own colour looking down and looking up, just under the surface
    var sky: Int, sun: Int // Snell's window, and the sunlight under the surface
    var kelp: Int, glow: Int // a blade lit from the front, and with the light coming through it
    var sand: Int
    var kd = 0.75 // how fast the light from above fades with depth, as a share of the extinction
    var rays = 1.0, snow = 0.3, expo = 1.0, caustics = 1.0
    var sunElev = 60.0, sunAz = 10.0 // degrees: the Sun's height in the sky, and its bearing from where we look
}

/// Colours are the look research's samples of real photos (research-look.md §3), as a camera's white balance shows
/// them: deep is the water looking level at the camera's depth, up looking straight up; kelp is a near blade lit from
/// our side, glow one with the light coming through it.
let looks: [String: Look] = [
    "channel": Look(ext: [0.16, 0.1, 0.09], deep: 0x18717E, up: 0x6EB4C4, sky: 0xD4ECF0, sun: 0xFFFFFF,
                    kelp: 0x8A7F24, glow: 0xB4A632, sand: 0xA89A78, kd: 0.5),
    "teal": Look(ext: [0.25, 0.16, 0.17], deep: 0x1D4640, up: 0x7AC3C2, sky: 0xC8EEE6, sun: 0xFFFFFF,
                 kelp: 0x5E6A34, glow: 0x8E9A44, sand: 0x7E8A70, kd: 0.5),
    "bull": Look(ext: [0.2, 0.13, 0.12], deep: 0x3A7273, up: 0xA6C0D4, sky: 0xC4D2DC, sun: 0xE8EEF2,
                 kelp: 0x867151, glow: 0x9B865B, sand: 0x8A8A7A, kd: 0.5, rays: 0.15, caustics: 0.1, sunElev: 80),
    "golden": Look(ext: [0.14, 0.17, 0.3], deep: 0x4D2E02, up: 0xA88126, sky: 0xE8D8A0, sun: 0xFFF0C8,
                   kelp: 0x6C4202, glow: 0xC08A10, sand: 0x8A6A30, kd: 0.5, rays: 1.4),
    "monterey": Look(ext: [0.3, 0.2, 0.22], deep: 0x4F6862, up: 0x74D5D6, sky: 0xC8F0EE, sun: 0xFFFFFF,
                     kelp: 0x6E6430, glow: 0x9E8E34, sand: 0x7A8070, kd: 0.5, snow: 0.6),
    "dusk": Look(ext: [0.12, 0.06, 0.045], deep: 0x001E3E, up: 0x01587C, sky: 0x046489, sun: 0x6090B0,
                 kelp: 0x050A12, glow: 0x0C2034, sand: 0x0A1A2A, kd: 0.5, rays: 0.5, snow: 0.12, expo: 0.4, caustics: 0, sunElev: 4),
]

let cfg = try! JSONDecoder().decode(Config.self, from: CommandLine.arguments[1].data(using: .utf8)!)
var look = looks[cfg.look]!
if let e = cfg.sunElev { look.sunElev = e }
if let a = cfg.sunAz { look.sunAz = a }
if let r = cfg.rays { look.rays = r }
if let e = cfg.expo { look.expo *= e }
let (wPt, hPt) = (cfg.width ?? 1512, cfg.height ?? 982)
let (W, H) = (Double(Int(wPt * 2)), Double(Int(hPt * 2)))
let tanH = tan((cfg.fov ?? 64) / 2 * .pi / 180), aspect = H / W
let pitch = (cfg.pitch ?? 25) * .pi / 180
let camY = cfg.camY ?? 2.5, depth = cfg.depth ?? 12
let speed = cfg.speed ?? 1
var rng = Rand(s: cfg.seed ?? 1)

func lin(_ hex: Int) -> SIMD3<Double> {
    SIMD3(Double(hex >> 16 & 255), Double(hex >> 8 & 255), Double(hex & 255)).map { pow($0 / 255, 2.2) }
}
extension SIMD3 where Scalar == Double {
    func map(_ f: (Double) -> Double) -> SIMD3<Double> { SIMD3(f(x), f(y), f(z)) }
}
func glsl(_ c: SIMD3<Double>) -> String { String(format: "vec3(%.5f, %.5f, %.5f)", c.x, c.y, c.z) }

/// The Sun's direction under water, toward it: bent toward the vertical by refraction.
let sunDir: SIMD3<Double> = {
    let zen = (90 - look.sunElev) * .pi / 180, inWater = asin(sin(zen) / 1.333), az = look.sunAz * .pi / 180
    return SIMD3(sin(inWater) * sin(az), cos(inWater), sin(inWater) * cos(az))
}()

let defines: [String: String] = [
    "TANH": "\(tanH)", "ASPECT": "\(aspect)", "PITCH": "\(pitch)", "CAMY": "\(camY)", "DEPTH": "\(depth)",
    "EXT": glsl(look.ext), "KD": "\(look.kd)", "DEEP": glsl(lin(look.deep)), "UP": glsl(lin(look.up)),
    "SKY": glsl(lin(look.sky)), "SUN": glsl(lin(look.sun)), "KELP": glsl(lin(look.kelp)), "GLOW": glsl(lin(look.glow)),
    "SAND": glsl(lin(look.sand)), "RAYS": "\(look.rays)", "SNOW": "\(look.snow)", "EXPO": "\(look.expo)",
    "SUNDIR": glsl(sunDir), "CANOPY": "\(cfg.canopy ?? 0.5)", "CAUS": "\(look.caustics)", "WALL": "\(cfg.tank ?? 0)", "CARRY": "\(cfg.carry ?? 0)",
]

let common = """
float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float hash11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float vnoise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
    float s = 0.0; float a = 0.5;
    for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.03 + vec2(17.1, 9.3); a *= 0.5; }
    return s;
}
// The way the camera looks through a point of the screen (uv 0 to 1).
vec3 rayDir(vec2 uv) {
    vec3 d = normalize(vec3((uv.x * 2.0 - 1.0) * TANH, (uv.y * 2.0 - 1.0) * TANH * ASPECT, 1.0));
    float c = cos(PITCH); float s = sin(PITCH);
    return vec3(d.x, d.y * c + d.z * s, -d.y * s + d.z * c);
}
// Sunlight at height y above the floor, as a share of what reaches the camera's depth.
vec3 lightAt(float y) { return SUN * exp(KD * dot(EXT, vec3(0.333)) * (clamp(y, 0.0, DEPTH) - CAMY)); }
// What an endless line of sight from height y sees of the water itself: brighter looking up and toward the Sun.
vec3 waterCol(vec3 d, float y) {
    float yy = clamp(y + d.y * 5.0, 0.0, DEPTH);
    vec3 base = d.y < 0.0 ? mix(DEEP, DEEP * 0.5, smoothstep(0.0, 1.0, -d.y)) : mix(DEEP, UP, smoothstep(0.0, 1.0, d.y));
    float f = pow(max(dot(d, SUNDIR), 0.0), 5.0);
    return base * min(exp(0.5 * KD * dot(EXT, vec3(0.333)) * (yy - CAMY)), 1.35) * (1.0 + 0.6 * f);
}
vec3 fogged(vec3 c, vec3 d, float dist, float y) {
    vec3 tr = exp(-EXT * dist);
    return c * tr + waterCol(d, y) * (1.0 - tr);
}
// Where the canopy lies on the surface, 0 open water to 1 thick: patches drawn out along the swell.
float canopy(vec2 xz) {
    vec2 w = vec2(vnoise(xz * 0.17), vnoise(xz * 0.17 + 5.2));
    float n = fbm(xz * vec2(0.22, 0.34) + w * 2.0);
    return smoothstep(0.62 - 0.3 * CANOPY, 0.8 - 0.3 * CANOPY, n);
}
// The canopy's blades seen from below: one in each cell of a 45 cm grid where the canopy is thick enough, about
// 1.2 m by 20 cm, lying mostly along the swell. Returns cover, and how thin the blade is there (its edges glow).
vec2 leaves(vec2 xz, float dens) {
    vec2 g = xz / 0.45;
    vec2 i = floor(g);
    float c = 0.0; float edge = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 id = i + vec2(float(x), float(y));
            float h = hash21(id * 1.31 + 7.0);
            vec2 ctr = id + vec2(hash21(id + 3.3), hash21(id + 8.1));
            float ang = 0.35 + (hash21(id + 5.9) - 0.5) * 1.8;
            vec2 dl = g - ctr;
            vec2 r = vec2(dl.x * cos(ang) + dl.y * sin(ang), -dl.x * sin(ang) + dl.y * cos(ang));
            r.y += 0.12 * sin(r.x * 3.0 + h * 9.0);
            float e = length(r / vec2(1.6, 0.13 + 0.06 * h));
            float on = step(h, dens * 1.6 - 0.2) * (1.0 - smoothstep(0.82, 1.0, e));
            edge = on > c ? e : edge;
            c = max(c, on);
        }
    }
    return vec2(c, edge);
}
"""

/// The water, the surface overhead, the floor, and the shafts of light through the canopy.
let water = common + """
void main() {
    vec2 uv = v_tex_coord;
    vec3 d = rayDir(uv);
    float t = u_t;
    vec2 sw = u_surge;
    vec3 col = vec3(0.0);
    float dist = 400.0;
    if (d.y > 0.0) {
        float ts = (DEPTH - CAMY) / d.y;
        vec2 q = vec2(d.x, d.z) * ts + u_cam - sw;
        // Ripples tip the surface a little; under the window's edge that makes it wobble.
        vec2 g = 0.045 / (1.0 + ts * 0.08) * vec2(sin(q.x * 1.7 + t * 1.1) + 0.7 * sin(q.x * 1.1 + q.y * 2.3 - t * 1.4),
                              sin(q.y * 1.9 - t * 1.2) + 0.7 * sin(q.y * 1.3 - q.x * 2.1 + t * 0.9));
        vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
        float c = dot(d, n);
        float win = smoothstep(0.6, 0.72, c);
        vec3 dr = normalize(d + 1.6 * (n - vec3(0.0, 1.0, 0.0)));
        float sd = max(dot(dr, SUNDIR), 0.0);
        vec3 sky = SKY * (0.55 + 0.45 * smoothstep(0.66, 1.0, c)) + SUN * (exp((sd - 1.0) * 4000.0) * 2.5 + exp((sd - 1.0) * 30.0) * 0.45);
        vec3 below = waterCol(reflect(d, n), DEPTH) * 0.7;
        vec3 surf = mix(below, sky, win);
        float thick = canopy(q);
        vec2 lv = leaves(q, thick);
        lv.x = mix(lv.x, thick * 0.55, smoothstep(10.0, 30.0, ts)); // far off, too small to make out one by one
        // Lit from above through itself: deep gold where one blade lies, browner where many do, its margins paler.
        vec3 mat = GLOW * SKY * (0.16 + 0.22 * lv.y * lv.y) * (1.0 - 0.6 * thick) + KELP * lightAt(DEPTH) * 0.05;
        col = mix(surf, mat, lv.x * (0.75 + 0.25 * win));
        dist = ts;
    } else {
        float tf = CAMY / -d.y;
        vec2 p = vec2(d.x, d.z) * tf + u_cam;
        float ripple = 0.9 + 0.1 * sin(p.x * 7.0 + 3.0 * vnoise(p * 1.3));
        float rock = smoothstep(0.55, 0.7, fbm(p * 0.25));
        vec3 alb = mix(SAND * ripple, SAND * vec3(0.45, 0.42, 0.36), rock);
        vec2 sp = p + SUNDIR.xz / SUNDIR.y * DEPTH - sw;
        float shade = 1.0 - 0.75 * canopy(sp);
        float caus = pow(vnoise(p * 2.2 + vec2(t * 0.25, -t * 0.18)) * vnoise(p * 3.1 - vec2(t * 0.2, t * 0.3)) * 2.2, 2.0);
        col = alb * lightAt(0.0) * (0.25 + 0.75 * shade) * (0.75 + 0.9 * CAUS * caus * shade) * (0.4 + 0.6 * SUNDIR.y);
        dist = tf;
    }
    if (WALL > 0.0 && d.z > 0.0 && WALL / d.z < dist) {
        // The tank's back wall: cast rock, lit from the open top.
        float tw = WALL / d.z;
        vec3 P = vec3(u_cam.x, CAMY, u_cam.y) + d * tw;
        float r = fbm(P.xy * vec2(0.6, 0.9)) * 0.7 + fbm(P.xy * 3.0) * 0.3;
        col = SAND * vec3(0.55, 0.55, 0.5) * (0.4 + 0.8 * r) * lightAt(P.y) * (0.6 + 0.6 * vnoise(P.xy * 2.0 + t * 0.1));
        dist = tw;
    }
    col = fogged(col, d, min(dist, 400.0), CAMY);
    // Shafts: sunlight let through the canopy's gaps and focused by the waves, parallel in the water and so
    // fanning out from the Sun on the screen: streaks by their angle round it, only where the canopy is open.
    vec3 e1 = normalize(cross(SUNDIR, vec3(0.0, 0.0, 1.0)));
    vec3 e2 = cross(SUNDIR, e1);
    vec2 ang = normalize(vec2(dot(d, e1), dot(d, e2)) + vec2(1e-5, 0.0));
    float streak = vnoise(ang * 7.0 + vec2(t * 0.025, sw.x * 0.3)) * vnoise(ang * 19.0 + vec2(7.0, -t * 0.04 + sw.y));
    float r = min(dist, 6.0);
    vec3 Q = vec3(u_cam.x, CAMY, u_cam.y) + d * r;
    float open = 1.0 - canopy(Q.xz + SUNDIR.xz / SUNDIR.y * (DEPTH - Q.y) - sw);
    float inscatter = 1.0 - exp(-0.1 * min(dist, 40.0));
    float toward = 0.2 + 1.6 * pow(max(dot(d, SUNDIR), 0.0), 3.0);
    col += RAYS * SUN * vec3(0.6, 0.9, 1.0) * lightAt(CAMY) * pow(streak, 2.5) * (0.3 + 0.7 * open) * inscatter * toward * 0.25;
    // Marine snow, lit by the water around it.
    float sn = 0.0;
    vec2 px = uv * u_px;
    for (int i = 0; i < 3; i++) {
        float cell = 40.0 + 46.0 * float(i);
        vec2 q = px / cell + vec2((1.0 - CARRY) * sw.x * (0.6 + 0.5 * float(i)) + 0.05 * sin(t * 0.07 + float(i)), -t * (0.01 + 0.006 * float(i)));
        vec2 id = floor(q) + float(i) * 37.0;
        vec2 f = fract(q) - 0.5 - (vec2(hash21(id + 3.1), hash21(id + 7.7)) - 0.5) * 0.6;
        sn += step(hash21(id), 0.2) * exp(-dot(f, f) * cell * cell / (1.0 + 2.2 * float(i))) * (0.3 + 0.7 * hash21(id + 9.3)) * (0.4 + 0.5 * float(i));
    }
    col += SNOW * sn * waterCol(vec3(0.0, 1.0, 0.0), CAMY) * 0.6;
    col *= EXPO;
    gl_FragColor = vec4(pow(max(col, vec3(0.0)), vec3(1.0 / 2.2)) + (hash21(px) - 0.5) / 255.0, 1.0);
}
"""

/// One frond: a stipe up through the water with its blades, each on a short stalk with its gas bladder. The spine is
/// eight points in the sprite's pixels (a_s1 to a_s4), equally spaced up the frond's length in metres.
let frond = common + """
vec2 pt(int k, vec4 a, vec4 b, vec4 c, vec4 e) {
    vec2 r = a.xy;
    if (k == 1) { r = a.zw; } else if (k == 2) { r = b.xy; } else if (k == 3) { r = b.zw; }
    else if (k == 4) { r = c.xy; } else if (k == 5) { r = c.zw; } else if (k == 6) { r = e.xy; } else if (k >= 7) { r = e.zw; }
    return r;
}
vec2 at(float f, vec4 a, vec4 b, vec4 c, vec4 e) {
    float k = clamp(floor(f), 0.0, 6.0);
    return mix(pt(int(k), a, b, c, e), pt(int(k) + 1, a, b, c, e), clamp(f - k, 0.0, 1.0));
}
void main() {
    vec2 p = v_tex_coord * a_box.xy;
    float t = u_t;
    float len = a_f.w;
    // The nearest point of the spine: how far up the frond this pixel is, and how far off it.
    float best = 1e9; float fs = 0.0;
    for (int k = 0; k < 7; k++) {
        vec2 p0 = pt(k, a_s1, a_s2, a_s3, a_s4); vec2 e = pt(k + 1, a_s1, a_s2, a_s3, a_s4) - p0;
        float h = clamp(dot(p - p0, e) / max(dot(e, e), 1e-4), 0.0, 1.0);
        vec2 r = p - p0 - e * h;
        float dd = dot(r, r);
        if (dd < best) { best = dd; fs = float(k) + h; }
    }
    float s = fs / 7.0 * len;
    float ppm0 = mix(a_m.x, a_m.y, s / len);
    float px = 1.0 / ppm0; // metres a pixel here
    // Light reaches this part of the frond only where the canopy overhead lets it through.
    vec2 up = a_f.yz + SUNDIR.xz / SUNDIR.y * (DEPTH - s) - u_surge;
    vec3 lit = lightAt(s) * (0.3 + 0.7 * (1.0 - canopy(up)));
    vec2 suv = (a_box.zw + p) / u_px;
    vec3 d = rayDir(suv);
    float back = smoothstep(-0.2, 0.9, dot(d, SUNDIR)); // looking toward the light, a blade glows through
    vec3 col = vec3(0.0); float alpha = 0.0;
    // The stipe, a cord about 1.5 cm thick; bull kelp's swells to a hollow tube in its top few metres.
    float sr = STIPE * (1.0 + BULLTUBE * smoothstep(len - 3.5, len, s));
    float sw = max(sr, px * 0.6);
    float stipe = (sr / sw) * (1.0 - smoothstep(sw, sw + px, sqrt(best) * px));
    stipe *= step(0.0, s) * step(s, len);
    col = KELP * 0.6 * lit; alpha = stipe;
    // The holdfast: a mound of root-like haptera about 70 cm across where the stipes meet the rock.
    vec2 b0 = a_s1.xy; vec2 t0 = normalize(a_s1.zw - a_s1.xy);
    float hy = dot(p - b0, t0) * px; float hx = abs(dot(p - b0, vec2(-t0.y, t0.x))) * px;
    float hr = HOLD * pow(1.0 - smoothstep(-0.05, 0.45, hy), 0.7) * (0.7 + 0.6 * vnoise(vec2(dot(p - b0, vec2(-t0.y, t0.x)) * px * 7.0, a_f.x * 40.0 + hy * 3.0)));
    float hold = (1.0 - smoothstep(hr - px, hr + px, hx)) * step(-0.04, hy) * step(hy, 0.5);
    float strands = 0.55 + 0.45 * vnoise(vec2(hx * 40.0 + hy * 10.0, hy * 14.0) + a_f.x * 30.0);
    col = mix(col, KELP * 0.75 * strands * lit, hold); alpha = max(alpha, hold);
#ifndef BULL
    float sp = BLADEGAP;
    int i0 = int(floor((s - BLADELEN - 0.1) / sp));
    for (int j = 0; j < NB; j++) {
        float i = float(i0 + j);
        float hs = hash11(i * 7.13 + a_f.x * 91.7);
        float ui = (i + 0.35 * hs) * sp;
        // Few, small, worn blades low down; a dense ruff of big ones high up [SBCNPP, FS85].
        float hi = smoothstep(0.1, 0.7, ui / max(len, 1.0) + (len < 8.0 ? 0.3 : 0.0));
        if (ui > 0.4 && ui < len - 0.05 && hash11(hs * 13.1 + 4.4) < mix(0.25, 1.0, hi)) {
            float fi = ui / len * 7.0;
            vec2 base = at(fi, a_s1, a_s2, a_s3, a_s4);
            vec2 tg = normalize(at(fi + 0.08, a_s1, a_s2, a_s3, a_s4) - at(fi - 0.08, a_s1, a_s2, a_s3, a_s4));
            vec2 nm = vec2(-tg.y, tg.x);
            float ppm = mix(a_m.x, a_m.y, ui / len);
            float h2 = hash11(hs * 31.7 + 2.1); float h3 = hash11(hs * 17.3 + 5.9); float h4 = hash11(hs * 5.3 + 1.7);
            float L = mix(BLADELEN * 0.4, BLADELEN, h3) * mix(0.55, 1.0, hi) * smoothstep(0.0, 1.6, len - ui + 0.3) * ppm;
            // Each blade leaves the stipe at its own bearing round it, and the flow streams them all one way: seen
            // from here, one pointing toward or away from us is foreshortened.
            float az = h2 * 6.2832 + 0.35 * sin(t * 0.45 + h4 * 7.0);
            float el = 0.3 + 1.0 * h4 * h4;
            vec2 flow = mix(a_flow.xy, a_flow.zw, ui / len);
            vec2 dir = tg * cos(el) + nm * sin(el) * cos(az) + flow * 0.8;
            float fore = length(dir);
            dir /= fore;
            L *= clamp(fore, 0.25, 1.0);
            float fl = 0.12 * sin(t * (1.1 + h3) + hs * 6.28 + ui * 2.0);
            dir = vec2(dir.x * cos(fl) - dir.y * sin(fl), dir.x * sin(fl) + dir.y * cos(fl));
            vec2 bn = vec2(-dir.y, dir.x);
            vec2 q = p - base;
            float a = dot(q, dir) / L;
            // A blade is a ribbon that twists along its length, so it narrows to its edge here and there and shows
            // first one face and then the other.
            float tw = h3 * 6.28 + a * mix(0.8, 3.0, h4) + 0.4 * sin(t * 0.6 + h2 * 9.0);
            float facing = 0.25 + 0.75 * sqrt(abs(cos(tw)));
            float halfW = L / clamp(fore, 0.25, 1.0) * mix(0.045, 0.08, h2) * facing;
            float curl = (hash11(hs * 3.7 + 0.3) - 0.5) * 1.4;
            // A ripple runs down each blade as it flutters in the flow.
            float wave = 0.035 * a * sin(a * 9.0 - t * (1.8 + h4) + hs * 20.0) * (0.4 + min(length(flow), 1.5));
            float b = dot(q, bn) - (curl * a * a + wave) * L;
            // Outline: a short stalk, then a long blade tapering to its tip, its margin crimped, old tips worn away.
            float tip = 1.0 - 0.3 * h4 * step(0.6, h3);
            float ab = clamp((a - 0.05) / (0.95 * tip), 0.0, 1.0);
            float prof = smoothstep(0.0, 0.25, ab) * (1.0 - smoothstep(0.55, 1.0, ab) * 0.92) * (1.0 - smoothstep(0.97, 1.0, ab));
            float m = a * L * px;
            prof *= 1.0 + 0.07 * sin(m * 55.0 + hs * 20.0) + 0.05 * sin(m * 23.0 + hs * 7.0) + 0.08 * (vnoise(vec2(m * 30.0, hs * 9.0 + sign(b) * 3.0)) - 0.5);
            // Its margin toothed every 2 cm or so, as a real blade's is [SAF] (fades out where a tooth is under a pixel).
            prof *= 1.0 - 0.07 * fract(m / 0.022 + sign(b) * 0.5) * clamp(0.022 / px / 4.0 - 0.5, 0.0, 1.0);
            float hw = max(halfW * prof, 0.0);
            float cov = (1.0 - smoothstep(hw - 0.5, hw + 0.7, abs(b))) * step(0.0, a) * step(a, tip);
            cov *= min(1.0, halfW / 0.8); // fainter, not jagged, when thinner than a pixel
            // The gas bladder at the blade's foot, a little paler than the blade.
            float bl = length(vec2((m - 0.035) / 0.02, b * px / 0.011));
            float blad = (1.0 - smoothstep(0.8, 1.0 + px / 0.011, bl)) * 0.8;
            float stalk = (1.0 - smoothstep(0.003, 0.003 + px, abs(dot(q, bn)) * px)) * step(0.0, a) * step(m, 0.03);
            // Shading: blistered tissue with fine streaks along it, lit from above, and the light coming through it
            // when we look toward the Sun, more at its thin margins, less where another blade lies behind it.
            float across = b / max(hw, 1e-3);
            float rug = vnoise(vec2(m * 26.0, across * 3.0) + hs * 50.0) * 0.6 + vnoise(vec2(m * 70.0, across * 6.0) + hs * 20.0) * 0.4;
            // Corrugations: ridges across the blade about 3 cm apart, wandering, lit on one side and shaded on the
            // other (the close-up photo of a blade, research-look.md §1), fading out where they're under a pixel.
            float ridge = sin((m + 0.012 * sin(across * 2.5 + hs * 9.0)) * 210.0 + hs * 30.0);
            rug = mix(rug, rug * (0.72 + 0.28 * ridge), clamp(0.03 / px / 6.0 - 0.3, 0.0, 1.0));
            float streak = 0.85 + 0.15 * vnoise(vec2(m * 3.0, across * 9.0) + hs * 11.0);
            float thin = clamp(1.0 - abs(across), 0.0, 1.0);
            vec3 tint = mix(vec3(1.0), vec3(0.9, 1.0, 0.75), h3 * 0.5) * (0.6 + 0.6 * h4);
            float face = 0.9 + 0.1 * sin(tw);
            vec3 front = KELP * tint * lit * (0.5 + 0.5 * rug) * streak * (0.4 + 0.6 * facing) * face;
            vec3 through = GLOW * tint * lit * (0.55 + 0.45 * (1.0 - thin * 0.6)) * (0.6 + 0.4 * rug) * streak * (1.0 - 0.35 * a);
            through *= 1.0 - 0.55 * alpha;
            // Blades on our side of the column are in its shadow when we look toward the light.
            float behind = 0.35 + 0.65 * smoothstep(-0.7, 0.5, -sin(az));
            vec3 bc = mix(front, through * behind, back * 0.85 * (0.5 + 0.5 * facing));
            vec3 bcol = mix(front, through * behind, back * 0.6) * (0.85 + 0.35 * pow(max(1.0 - bl, 0.0), 2.0));
            float bcov = max(cov, max(blad, stalk));
            col = mix(col, mix(bc, bcol, max(blad, stalk)), bcov);
            alpha = alpha + bcov * (1.0 - alpha);
        }
    }
#else
    // Bull kelp: one round float about 13 cm across at the stipe's end, and a tuft of long ruffled blades streaming
    // from it with the water [SPR10, SIMN].
    vec2 T = a_s4.zw;
    vec2 tgT = normalize(a_s4.zw - a_s4.xy);
    vec2 nT = vec2(-tgT.y, tgT.x);
    float pT = 1.0 / a_m.y;
    vec3 litT = lightAt(DEPTH - 0.3) * (0.3 + 0.7 * (1.0 - canopy(a_f.yz - u_surge)));
    for (int j = 0; j < 20; j++) {
        float hj = hash11(float(j) * 3.71 + a_f.x * 51.3); float h2 = hash11(hj * 31.7 + 2.1); float h3 = hash11(hj * 17.3 + 5.9);
        float ang = (hj - 0.5) * 1.1;
        vec2 d0 = tgT * cos(ang) + nT * sin(ang);
        vec2 dir = d0 * 0.6 + a_flow.zw * 1.6;
        float fore = clamp(length(dir), 0.3, 1.0);
        dir = normalize(dir);
        vec2 bn = vec2(-dir.y, dir.x);
        float L = mix(1.6, 3.6, h2) * fore / pT;
        vec2 q = p - T;
        float a = dot(q, dir) / L;
        float tw = h3 * 6.28 + a * 2.0 + 0.4 * sin(t * 0.5 + h2 * 9.0);
        float facing = 0.25 + 0.75 * sqrt(abs(cos(tw)));
        float wave = 0.05 * a * sin(a * 7.0 - t * (1.2 + h3) + hj * 20.0) + (h3 - 0.5) * 0.5 * a * a;
        float b = dot(q, bn) - wave * L;
        float m = a * L * pT;
        float hw = 0.075 / pT * facing * smoothstep(0.0, 0.08, a) * (1.0 - smoothstep(0.7, 1.0, a) * 0.85);
        hw *= 1.0 + 0.18 * sin(m * 40.0 + hj * 20.0) * sin(m * 13.0 + hj * 3.0); // ruffled, as in calm water
        float cov = (1.0 - smoothstep(hw - 0.5, hw + 0.7, abs(b))) * step(0.0, a) * step(a, 1.0) * min(1.0, hw / 0.8);
        float across = b / max(hw, 1e-3);
        float rug = vnoise(vec2(m * 20.0, across * 3.0) + hj * 50.0);
        vec3 front = KELP * litT * (0.5 + 0.5 * rug) * (0.4 + 0.6 * facing) * (0.7 + 0.5 * h3);
        vec3 through = GLOW * litT * (0.6 + 0.4 * rug) * (1.0 - 0.4 * a) * (0.7 + 0.5 * h3) * (1.0 - 0.55 * alpha);
        col = mix(col, mix(front, through, back * 0.85 * (0.5 + 0.5 * facing)), cov);
        alpha = alpha + cov * (1.0 - alpha);
    }
    float fl = length(vec2(dot(p - T, tgT) * pT - 0.03, dot(p - T, nT) * pT)) / 0.065;
    float bulb = 1.0 - smoothstep(1.0, 1.0 + pT / 0.065, fl);
    col = mix(col, mix(KELP, GLOW, 0.5) * litT * (0.6 + 0.6 * smoothstep(1.0, 0.0, fl)), bulb);
    alpha = max(alpha, bulb);
#endif
    float dist = mix(a_m.z, a_m.w, s / len);
    vec3 f = fogged(col, d, dist, s) * EXPO;
    gl_FragColor = vec4(pow(max(f, vec3(0.0)), vec3(1.0 / 2.2)) * alpha, alpha);
}
"""

func source(_ base: String, _ extra: [String: String] = [:]) -> String {
    defines.merging(extra) { $1 }.sorted { $0.key < $1.key }.map { "#define \($0.key) \($0.value)\n" }.joined() + base
}

// MARK: The sea

/// One swell component: its amplitude at the surface (m), frequency, wave number, bearing and phase.
struct Swell { var a: Double, omega: Double, k: Double, dir: SIMD2<Double>, phase: Double, sinhKH: Double }

/// The wave number for a frequency in water this deep, from ω² = g k tanh(k h).
func waveNumber(_ omega: Double, _ h: Double) -> Double {
    var k = omega * omega / 9.81
    for _ in 0..<40 { k = omega * omega / (9.81 * tanh(k * h)) }
    return k
}

/// The sea (research-method.md §2): five swell components in a narrow band round the peak period, so it comes in
/// sets and never repeats; a slow surge under them (surf beat, 100 to 160 s); and a weak current that wanders.
let hs = cfg.surge ?? 1.0, peak = cfg.period ?? 12
let swells: [Swell] = (0..<5).map { _ in
    let om = 2 * .pi / (peak * rng.range(0.88...1.12)), k = waveNumber(om, depth), bearing = 0.35 + rng.range(-0.3...0.3)
    return Swell(a: hs * 0.158 * rng.range(0.75...1.25), omega: om, k: k, dir: SIMD2(cos(bearing), sin(bearing)),
                 phase: rng.next() * 2 * .pi, sinhKH: sinh(k * depth))
}
let beat = (x: 0.6 * hs, omega: 2 * Double.pi / rng.range(100...160), phase: rng.next() * 2 * .pi)
let current = (speed: cfg.current ?? 0.015, phase: rng.next() * 2 * .pi)

/// The water's velocity at a place and time.
func flowAt(_ p: SIMD3<Double>, _ t: Double) -> SIMD3<Double> {
    var u = SIMD3<Double>.zero
    let y = min(max(p.y, 0), depth)
    for s in swells {
        let ph = s.k * (s.dir.x * p.x + s.dir.y * p.z) - s.omega * t + s.phase
        let horiz = s.a * s.omega * cosh(s.k * y) / s.sinhKH * cos(ph)
        u += SIMD3(s.dir.x * horiz, s.a * s.omega * sinh(s.k * y) / s.sinhKH * sin(ph), s.dir.y * horiz)
    }
    u.x += beat.x * beat.omega * cos(beat.omega * t + beat.phase - 0.002 * p.x)
    let c = current.speed * (1 + 0.5 * sin(t / 420 + current.phase)), cb = 0.6 * sin(t / 900 + current.phase)
    u += SIMD3(c * cos(cb), 0, c * sin(cb)) * (0.6 + 0.8 * y / depth)
    return u
}

/// How far the surface water is carried from its rest, for the canopy and ripples drawn on it.
func surfaceShift(_ t: Double, at y: Double = depth) -> SIMD2<Double> {
    var d = SIMD2<Double>.zero
    for s in swells { d -= s.dir * (s.a * cosh(s.k * y) / s.sinhKH * sin(s.phase - s.omega * t)) }
    return d + SIMD2(beat.x * sin(beat.omega * t + beat.phase), 0)
}

// MARK: The forest

/// One frond, as the literature's tethered buoy in segments (research-method.md §2): a chain of nodes from the
/// holdfast, each buoyant, dragged toward the water's velocity as |u − v|^0.6 (u − v), links that don't stretch.
/// Slack and dragged, not springy: it rights itself over most of a minute.
let segments = 14
struct Frond {
    var base: SIMD3<Double>, len: Double, seed: Double
    var lean: SIMD3<Double> // its own way out from the plant's centre: the fan of fronds from a holdfast
    var bull = false
    var p: [SIMD3<Double>], v: [SIMD3<Double>]
    var node: SKSpriteNode? = nil
}

let near = cfg.near ?? 3.5, far = cfg.far ?? 30
let maxLen = cfg.tank != nil ? depth * 1.05 : 1.4 * depth - 0.79 // the longest frond in water this deep [JJN85]; a tank's are kept trimmed
var fronds: [Frond] = []
let kelp = cfg.kelp ?? "giant"
for plant in 0..<(cfg.plants ?? 16) {
    // Plants spread through the view, more of them far than near, as a forest in perspective has.
    let z = near + (far - near) * pow(rng.next(), 1.5)
    let x = cfg.tank != nil ? (Double(plant) + rng.next()) / Double(cfg.plants ?? 16) * 2 * (tanH * z + 1) - (tanH * z + 1) : (rng.next() * 2 - 1) * (tanH * z + 2)
    // Bull kelp is one stipe a plant, in groups; giant kelp many fronds from one holdfast. Mixed: an edge of bull kelp
    // in a giant kelp forest, as at its exposed edges [CR].
    let bull = kelp == "bull" || (kelp == "mixed" && plant % 3 == 0)
    for _ in 0..<(bull ? Int(rng.range(2...5)) : Int(rng.range(6...Double(cfg.fronds ?? 14)))) {
        let len = bull ? depth + rng.range(-0.5...2.5) : maxLen * (rng.next() < 0.65 ? rng.range(0.78...1.0) : rng.range(0.2...0.75))
        let a = rng.next() * 2 * .pi, r = rng.range(0.05...0.2)
        let spot = bull ? 1.2 : 0.12
        let base = SIMD3(x + rng.range(-spot...spot), 0, z + rng.range(-spot...spot))
        let lean = SIMD3(cos(a) * r, 0, sin(a) * r)
        let dir = SIMD3(lean.x, 1, lean.z) / (1 + r * r).squareRoot()
        let pts = (0...segments).map { i -> SIMD3<Double> in
            var q = base + dir * (len * Double(i) / Double(segments))
            if q.y > depth - 0.05 { q.y = depth - 0.05 }
            return q
        }
        fronds.append(Frond(base: base, len: len, seed: rng.next(), lean: lean, bull: bull, p: pts, v: pts.map { _ in .zero }))
    }
}

var simT = (cfg.t ?? 20) * speed - 150 // run a while first, so the forest has settled into the sea
func advance(to t: Double) {
    let dt = 1.0 / 60, seg = { (f: Frond) in f.len / Double(segments) }
    while simT < t {
        simT += dt
        for f in fronds.indices {
            let l = seg(fronds[f])
            var np = fronds[f].p
            for i in 1...segments {
                let q = fronds[f].p[i], u = flowAt(q, simT)
                let rel = u - fronds[f].v[i], r = (rel * rel).sum().squareRoot()
                // Buoyancy from the floats at every blade, more high up where the blades are; and a frond's own
                // slight lean away from the others in its plant.
                let fr = Double(i) / Double(segments)
                // Bull kelp's lift is all in its float, at the top.
                let lift = (fronds[f].bull ? (i == segments ? 2.5 : 0.04) : 0.12 + 0.3 * fr) * (SIMD3(0, 1, 0) + fronds[f].lean)
                fronds[f].v[i] += (lift + 2.0 * pow(r, 0.6) * rel) * dt
                np[i] = q + fronds[f].v[i] * dt
            }
            for i in 1...segments {
                var d = np[i] - np[i - 1]
                d *= l / max((d * d).sum().squareRoot(), 1e-6)
                np[i] = np[i - 1] + d
                np[i].y = min(np[i].y, depth - 0.03) // floating at the surface
                np[i].y = max(np[i].y, 0.02)
            }
            // A little stiffness, so a slack stipe curves rather than zigzags.
            for i in 1..<segments { np[i] += (0.5 * (np[i - 1] + np[i + 1]) - np[i]) * 0.15 }
            for i in 1...segments {
                var d = np[i] - np[i - 1]
                d *= l / max((d * d).sum().squareRoot(), 1e-6)
                np[i] = np[i - 1] + d
                np[i].y = min(max(np[i].y, 0.02), depth - 0.03)
            }
            for i in 1...segments { fronds[f].v[i] = (np[i] - fronds[f].p[i]) / dt }
            fronds[f].p = np
        }
    }
}

func project(_ p: SIMD3<Double>) -> (px: SIMD2<Double>, z: Double, dist: Double) {
    let rel = p - cam
    let zc = rel.y * sin(pitch) + rel.z * cos(pitch), yc = rel.y * cos(pitch) - rel.z * sin(pitch)
    let z = max(zc, 0.05)
    return (SIMD2(W / 2 + rel.x / z / tanH * W / 2, H / 2 + yc / z / (tanH * aspect) * H / 2), z, (rel * rel).sum().squareRoot())
}

let bladeLen = 0.9, bladeGap = 0.1
let time = SKUniform(name: "u_t", float: 0)
let surgeU = SKUniform(name: "u_surge", vectorFloat2: .zero)
let camU = SKUniform(name: "u_cam", vectorFloat2: .zero)
/// Where the camera is: on the spot, or carried part of the way with the water as a diver is.
let carry = cfg.carry ?? 0
var cam = SIMD3<Double>(0, camY, 0)
let pxU = SKUniform(name: "u_px", vectorFloat2: SIMD2(Float(W), Float(H)))

let scene = SKScene(size: CGSize(width: wPt, height: hPt))
scene.backgroundColor = .black
let backdrop = SKSpriteNode(color: .black, size: scene.size)
backdrop.position = CGPoint(x: wPt / 2, y: hPt / 2)
backdrop.zPosition = -1000
backdrop.shader = SKShader(source: source(water), uniforms: [time, surgeU, camU, pxU])
scene.addChild(backdrop)

if let wall = cfg.tank {
    // The gallery's window: a dark frame and two mullions, the visitors' side unlit.
    let frame = SKSpriteNode(color: .black, size: scene.size)
    frame.position = CGPoint(x: wPt / 2, y: hPt / 2)
    frame.zPosition = 10
    frame.shader = SKShader(source: """
    void main() {
        vec2 p = v_tex_coord * u_px;
        float e = min(min(p.x, u_px.x - p.x), min(p.y, u_px.y - p.y)) / u_px.y;
        float m = min(abs(p.x - u_px.x / 3.0), abs(p.x - 2.0 * u_px.x / 3.0)) / u_px.y;
        float solid = max(1.0 - smoothstep(0.022, 0.026, e), 1.0 - smoothstep(0.007, 0.0095, m));
        gl_FragColor = vec4(0.012, 0.02, 0.02, 1.0) * solid;
    }
    """, uniforms: [pxU])
    scene.addChild(frame)
    _ = wall
}
func frondShader(bull: Bool) -> SKShader {
    var d = ["BLADELEN": "\(bladeLen)", "BLADEGAP": "\(bladeGap)", "NB": "\(Int(ceil(2 * (bladeLen + 0.1) / bladeGap)) + 1)",
             "STIPE": bull ? "0.006" : "0.008", "BULLTUBE": bull ? "2.5" : "0.0", "HOLD": bull ? "0.18" : "0.4"]
    if bull { d["BULL"] = "1" }
    let sh = SKShader(source: source(frond, d), uniforms: [time, surgeU, pxU])
    sh.attributes = ["a_s1", "a_s2", "a_s3", "a_s4", "a_box", "a_m", "a_f", "a_flow"].map { SKAttribute(name: $0, type: .vectorFloat4) }
    return sh
}
let giantShader = frondShader(bull: false), bullShader = frondShader(bull: true)
for i in fronds.indices {
    let n = SKSpriteNode(color: .white, size: .zero)
    n.shader = fronds[i].bull ? bullShader : giantShader
    n.anchorPoint = .zero
    scene.addChild(n)
    fronds[i].node = n
}

/// Places every frond's sprite for time t: its spine projected to the screen, its scale and distance at each end,
/// and the water's flow past it there, for its blades to stream in.
func place(_ t: Double) {
    advance(to: t)
    time.floatValue = Float(t)
    let sh = surfaceShift(t), ch = surfaceShift(t, at: camY) * carry
    surgeU.vectorFloat2Value = SIMD2(Float(sh.x), Float(sh.y))
    cam = SIMD3(ch.x, camY, ch.y)
    camU.vectorFloat2Value = SIMD2(Float(ch.x), Float(ch.y))
    for fr in fronds {
        let pts = stride(from: 0, through: segments, by: 2).map { fr.p[$0] }
        let proj = pts.map { project($0) }
        let n = fr.node!
        if proj.allSatisfy({ $0.z < 0.3 }) { n.isHidden = true; continue }
        let ppm = proj.map { W / 2 / (tanH * $0.z) }
        let reach = (fr.bull ? 3.8 : bladeLen + 0.1) * ppm.max()!
        let xs = proj.map(\.px.x), ys = proj.map(\.px.y)
        let lo = SIMD2(xs.min()! - reach, ys.min()! - reach), hi = SIMD2(xs.max()! + reach, ys.max()! + reach)
        if hi.x < 0 || lo.x > W || hi.y < 0 || lo.y > H || proj.contains(where: { $0.z < 0.3 }) { n.isHidden = true; continue }
        n.isHidden = false
        let size = hi - lo
        n.position = CGPoint(x: lo.x / 2, y: lo.y / 2)
        n.size = CGSize(width: size.x / 2, height: size.y / 2)
        n.zPosition = CGFloat(-proj[3].dist)
        let l = proj.map { $0.px - lo }
        func v4(_ a: Int) -> vector_float4 { [Float(l[a].x), Float(l[a].y), Float(l[a + 1].x), Float(l[a + 1].y)] }
        // The water's flow past the frond, on the screen: 1 is about 15 cm/s.
        func flow(_ k: Int) -> SIMD2<Double> {
            let rel = (flowAt(fr.p[k], t) - fr.v[k]) / 0.15
            let at = project(fr.p[k])
            return (project(fr.p[k] + rel * 0.2).px - at.px) / (0.2 * W / 2 / (tanH * at.z))
        }
        var f0 = flow(2), f1 = flow(segments - 2)
        if fr.bull {
            // A float rides the water, so its blades stream with the current and the waves' drift, not past it.
            let u = flowAt(fr.p[segments], t) / 0.05, at = project(fr.p[segments])
            f1 = (project(fr.p[segments] + u * 0.2).px - at.px) / (0.2 * W / 2 / (tanH * at.z))
            f0 = f1
        }
        n.setValue(SKAttributeValue(vectorFloat4: v4(0)), forAttribute: "a_s1")
        n.setValue(SKAttributeValue(vectorFloat4: v4(2)), forAttribute: "a_s2")
        n.setValue(SKAttributeValue(vectorFloat4: v4(4)), forAttribute: "a_s3")
        n.setValue(SKAttributeValue(vectorFloat4: v4(6)), forAttribute: "a_s4")
        n.setValue(SKAttributeValue(vectorFloat4: [Float(size.x), Float(size.y), Float(lo.x), Float(lo.y)]), forAttribute: "a_box")
        n.setValue(SKAttributeValue(vectorFloat4: [Float(ppm[0]), Float(ppm[7]), Float(proj[0].dist), Float(proj[7].dist)]), forAttribute: "a_m")
        n.setValue(SKAttributeValue(vectorFloat4: [Float(fr.seed), Float(fr.base.x), Float(fr.base.z), Float(fr.len)]), forAttribute: "a_f")
        n.setValue(SKAttributeValue(vectorFloat4: [Float(f0.x), Float(f0.y), Float(f1.x), Float(f1.y)]), forAttribute: "a_flow")
    }
}

// MARK: Rendering

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(W), height: Int(H), mipmapped: false)
desc.usage = [.renderTarget, .shaderRead]
desc.storageMode = .shared
let target = device.makeTexture(descriptor: desc)!
let renderer = SKRenderer(device: device)
renderer.scene = scene

func render(at t: Double, to path: String) {
    place(t * speed)
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    renderer.update(atTime: t)
    let buf = queue.makeCommandBuffer()!
    renderer.render(withViewport: CGRect(x: 0, y: 0, width: W, height: H), commandBuffer: buf, renderPassDescriptor: pass)
    buf.commit()
    buf.waitUntilCompleted()
    if ProcessInfo.processInfo.environment["KTIME"] != nil {
        print(String(format: "gpu %.2f ms", (buf.gpuEndTime - buf.gpuStartTime) * 1000))
    }
    let (w, h) = (Int(W), Int(H))
    let bytes = w * 4
    var px = [UInt8](repeating: 0, count: bytes * h)
    target.getBytes(&px, bytesPerRow: bytes, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
    let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bytes, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

if let times = cfg.times {
    for (i, t) in times.enumerated() { render(at: t, to: cfg.out + String(format: "-%03d.png", i)) }
} else if let frames = cfg.frames {
    let fps = cfg.fps ?? 30, start = cfg.t ?? 20
    for f in 0..<frames { render(at: start + Double(f) / fps, to: cfg.out + String(format: "-%04d.png", f)) }
} else {
    render(at: cfg.t ?? 20, to: cfg.out)
}
