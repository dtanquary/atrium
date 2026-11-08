// Sea Sparkle mock-ups, drawn by SpriteKit's SKRenderer as the app's render test draws a wallpaper, so a tile shows
// what the app's shaders can draw. Not app code: the shore here is the method research's (research-method.md §3, A)
// with faces, lips and foam added, and is meant to carry into the build.
//
//   swiftc -O mock.swift -o $TMPDIR/sea-mock && $TMPDIR/sea-mock '<json>'
//
// The JSON: view (bluff, beach, long, along), seed, swell (m), period (s), beach ("gentle", "steep"), palette (cyan,
// azure, teal, eye), look (video, eye, long, points), moon (0 none … 1 full), land (true for a headland and town),
// at (seconds after the biggest wave of the first minute breaks; or t, absolute), width and height (points, drawn at
// 2x), out (a .png, or a path prefix with times/frames). Optional: times (one picture each, relative to the moment),
// frames and fps (a film), speed.
import Foundation
import Metal
import SpriteKit

struct Config: Decodable {
    var view: String?, seed: UInt64?, swell: Double?, period: Double?, beach: String?
    var palette: String?, look: String?, moon: Double?, land: Bool?, lights: Bool?
    var at: Double?, t: Double?, peak: Double?, width: Double?, height: Double?
    var out: String
    var times: [Double]?, frames: Int?, fps: Double?, speed: Double?
}
let cfg = try! JSONDecoder().decode(Config.self, from: CommandLine.arguments[1].data(using: .utf8)!)
let (wPt, hPt) = (cfg.width ?? 1512, cfg.height ?? 982)
let (W, H) = (Int(wPt * 2), Int(hPt * 2))

/// SplitMix64: the same beach and swell for the same seed.
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

// MARK: - The view and the beach

/// A level camera: horizon (fraction of the screen's height), focal length (screen heights), eye above the water (m),
/// the shoreline's distance straight ahead (m), and how far it is turned from facing the sea square on (radians).
struct View { var hz, F, E, D0, yaw: Double }
let beachFace = 0.06 // the sand's slope above the waterline
func standing(_ D0: Double) -> Double { 1.7 + D0 * beachFace } // eye height for someone on the sand, D0 from the water
let views: [String: View] = [
    "bluff": View(hz: 0.74, F: 1.1, E: 12, D0: 22, yaw: 0),
    "beach": View(hz: 0.56, F: 1.1, E: standing(6), D0: 6, yaw: 0),
    "long": View(hz: 0.66, F: 3.0, E: standing(14), D0: 14, yaw: 0),
    "along": View(hz: 0.56, F: 1.3, E: standing(8), D0: 8, yaw: 0.75),
]
let view = views[cfg.view ?? "bluff"]!
let tanb = (cfg.beach ?? "gentle") == "steep" ? 0.07 : 0.03 // the surf zone's slope
let gamma = 0.78 // breaker index: a wave breaks when its height reaches this times the depth
let swell = cfg.swell ?? 1.0, period = cfg.period ?? 10.0
let iribarren = tanb / sqrt(swell / (9.81 * period * period / (2 * .pi))) // under 0.5 spills, over it plunges

// MARK: - The waves: a train from a seed, as the app's CPU model would hand them to the shader

/// One wave: when its crest passes where it would break on a plain beach, its breaker height, how fast its break
/// point comes in either side of its peak (a fraction of the way in per metre along the shore: the peel runs at about
/// the bore's speed over that), and where its peak is along the shore (m).
struct Wave { var tb, hb, peel, peak: Double }
var rng = Rand(s: cfg.seed ?? 1)
let groupPhase = rng.range(0...6.28), groupPhase2 = rng.range(0...6.28)
let oblique = rng.range(-0.004...0.004) // the swell's angle to the shore, as seconds a metre along it
var train: [Wave] = (0..<400).map { k in
    let kd = Double(k)
    // Sets: a group of bigger waves about every seven, under a slower swell of groups, and a little of each wave's own.
    let env = 0.78 + 0.32 * sin(2 * .pi * kd / 7 + groupPhase) + 0.14 * sin(2 * .pi * kd / 17.3 + groupPhase2) + 0.18 * (rng.next() - 0.5)
    let closeout = rng.next() < 0.2
    return Wave(tb: kd * period + rng.range(-0.22...0.22) * period, hb: swell * max(0.35, env),
                peel: closeout ? rng.range(0.0005...0.002) : rng.range(0.004...0.012), peak: rng.range(-50...50))
}
let speed = cfg.speed ?? 1
/// The moment the tiles are drawn around: the biggest wave of the first minute or so, `at` seconds after it breaks at
/// its peak, which is moved into view (`peak`, metres along the shore from straight ahead) so a still catches a break.
let moment: Double = {
    if let t = cfg.t { return t }
    let k = (3...9).max { train[$0].hb < train[$1].hb }!
    train[k].peak = cfg.peak ?? 0
    return train[k].tb + (cfg.at ?? 1.8)
}()

// MARK: - Palettes: the research's samples (research-look.md §2), as the one light under a camera's white balance

struct Palette { var sky, sea, sand, edge, body, core, foam: SIMD3<Double> }
func v(_ hex: Int) -> SIMD3<Double> { SIMD3(Double(hex >> 16 & 255), Double(hex >> 8 & 255), Double(hex & 255)) / 255 }
let palettes: [String: Palette] = [
    "cyan": Palette(sky: v(0x050d1c), sea: v(0x05070e), sand: v(0x141216), edge: v(0x0c2d37), body: v(0x145f69), core: v(0x137596), foam: v(0x378daf)),
    "azure": Palette(sky: v(0x0d111a), sea: v(0x04060c), sand: v(0x100c14), edge: v(0x020732), body: v(0x042564), core: v(0x064891), foam: v(0x257faf)),
    "teal": Palette(sky: v(0x13131a), sea: v(0x06030c), sand: v(0x141210), edge: v(0x033734), body: v(0x015464), core: v(0x008c71), foam: v(0x01b99d)),
    // As the eye sees it in the dark: paler and bluer-white, since colour vision fades in dim light (unchecked).
    "eye": Palette(sky: v(0x060a14), sea: v(0x04060b), sand: v(0x100f12), edge: v(0x101c2c), body: v(0x24405a), core: v(0x3a6584), foam: v(0x7d9fb8)),
]
let pal = palettes[cfg.palette ?? "cyan"]!

/// The look: gain on the light, how long foam keeps glowing (a multiplier), how smooth the foam is (0 lace, 1 mist),
/// sheets (0) or points (1), and a lift of the sky as a long exposure gives.
struct Look { var gain = 1.0, fade = 1.0, smooth = 0.0, points = 0.0, lift = 0.0 }
let looks: [String: Look] = [
    "video": Look(),
    "eye": Look(gain: 0.65, fade: 1.0, smooth: 0.3),
    "long": Look(gain: 0.85, fade: 3.0, smooth: 0.85, lift: 0.45),
    "points": Look(gain: 1.0, fade: 0.8, points: 1.0),
]
let look = looks[cfg.look ?? "video"]!

// MARK: - The shader

let common = """
float hash11(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
vec4 hash42(vec2 p) {
    vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}
float starLight(float d, float room, vec4 r, float t) {
    float mag = pow(r.w, 5.0);
    float twinkle = 0.8 + 0.2 * sin(mod(t, 3600.0) * (1.0 + 3.0 * r.x) + r.x * 50.0);
    return (smoothstep(min(0.6 + 1.2 * mag, room), 0.0, d) + 0.3 * mag * exp(-d * 0.4) * smoothstep(room, 0.0, d)) * (0.3 + 0.9 * mag) * twinkle;
}
float starField(vec2 pts, float cell, float density, float t) {
    vec4 r = hash42(floor(pts / cell));
    if (r.x > density) { return 0.0; }
    vec2 off = (r.yz - 0.5) * 0.7;
    return starLight(length(fract(pts / cell) - 0.5 - off) * cell, (0.5 - max(abs(off.x), abs(off.y))) * cell, r, t);
}

"""

/// The shore. A level camera; each pixel below the horizon is a point on the sea or the sand, found from its angle
/// below the horizon. Each wave is analytic (research-method.md §3): its crest, a straight line along the shore, moves
/// in at sqrt(g h) over a plane beach, so where it is at any moment is closed form. It breaks where its height reaches
/// gamma times the depth, which is furthest out at its peak and nearer in either side of it, so the break runs along
/// the crest from the peak (the peel), and a sandbar's gaps (rips) let it in further before it breaks. Unbroken it is
/// a dark face; broken it is a wall of foam that glows, brightest at its top, with a soft halo of spray, and leaves a
/// trail of lace that fades. Its swash runs up the sand and back. The wet sand and the sea mirror the glow. Nothing is
/// stored between frames.
let source = common + """
float vnoise(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(hash11(i), hash11(i + 1.0), f); }

// Where to sample the baked tileable noise (CloudNoise, 257 texels with the first repeated) for point p.
vec2 nuv(vec2 p) { return (fract(p) * 256.0 + 0.5) / 257.0; }

// How a bore glows `tb` seconds after it broke: lit over a second or so, then fading as it weakens (research-look.md §1:
// the lit area grows for 1.5 s, peaks about 2.3 s in, and is at 56% 2.8 s later). A tail of a third stays while it
// still churns into fresh water on its way in (my reading of the footage, not measured: a tunable).
float boreGlow(float tb, float fade) {
    return smoothstep(0.0, 1.3, tb) * (0.32 + 0.68 * exp(-max(tb - 1.2, 0.0) / (4.8 * fade)));
}

// The glow's colour for a level of light: edge, body, core, then the palest foam.
vec3 ramp(float L, vec3 edge, vec3 body, vec3 core, vec3 foam) {
    vec3 c = edge * smoothstep(0.0, 0.25, L);
    c = mix(c, body, smoothstep(0.2, 0.55, L));
    c = mix(c, core, smoothstep(0.5, 0.8, L));
    return mix(c, foam, smoothstep(0.78, 1.0, L));
}

void main() {
    vec2 uv = v_tex_coord;
    vec2 pts = uv * u_size;
    float aspect = u_size.x / u_size.y;
    float t = u_now;
    float hz = u_view.x, F = u_view.y, E = u_view.z, D0 = u_view.w;
    float yaw = u_beach.x, tanb = u_beach.y, tanB = u_beach.z, plunge = u_beach.w;
    float oblique = u_glowc.x;
    float y = uv.y - hz, x = (uv.x - 0.5) * aspect;
    float moon = u_moon.x;

    // The sky: a night gradient, a little paler toward the horizon, the stars, a headland and the town on it.
    float up = max(y, 0.0);
    vec3 skyTop = mix(u_sky, vec3(0.125, 0.172, 0.235), moon * 0.8) + u_sky * u_look.w * 1.6;
    vec3 skyLow = skyTop * 1.3 + vec3(0.004, 0.006, 0.010) * (1.0 + u_look.w * 3.0);
    vec3 col = mix(skyLow, skyTop, smoothstep(0.0, 0.3, up));
    float q = x / F * sin(yaw) + cos(yaw);      // how fast the ground runs seaward along this pixel's ray
    float p = x / F * cos(yaw) - sin(yaw);      // and along the shore
    if (y > 0.0) {
        float stars = starField(pts, 7.0, 0.3, t) * smoothstep(0.0, 0.06, up) * (1.0 - 0.75 * moon);
        col += vec3(0.75, 0.8, 0.9) * stars * 0.5;
        vec2 md = vec2(x - u_moon.y, y - u_moon.z);
        float r = length(md);
        // The Moon at its real size (half a degree), lit on its right by its phase (u_moon.w, the lit fraction).
        float R = 0.0044 * F;
        float lit = step(md.x / R, 1.0) * step((1.0 - 2.0 * u_moon.w) * sqrt(max(1.0 - md.y * md.y / (R * R), 0.0)), md.x / R);
        col += vec3(0.85, 0.85, 0.8) * step(0.001, moon) * (smoothstep(R, R * 0.85, r) * mix(0.03, 0.95, lit) + 0.05 * moon * exp(-r * 10.0));
        if (u_land.x > 0.0) {
            // A headland on the right, far off: a ridge rising from the sea, and a few lights along its foot.
            float xs = x - u_land.y;
            float ridge = u_land.z * smoothstep(0.0, 0.35, xs) * (0.75 + 0.25 * vnoise(xs * 9.0) + 0.1 * vnoise(xs * 31.0));
            if (y < ridge) {
                col = mix(vec3(0.008, 0.010, 0.014), vec3(0.03, 0.035, 0.045), moon);
                if (u_land.w > 0.0) {
                    vec2 cell = floor(pts / vec2(3.0, 2.0));
                    vec4 r4 = hash42(cell + 17.0);
                    float town = step(r4.x, 0.22) * smoothstep(ridge * 0.55, ridge * 0.1, y) * smoothstep(0.03, 0.08, xs) * smoothstep(0.4, 0.2, xs);
                    vec2 f = fract(pts / vec2(3.0, 2.0)) - 0.5;
                    col += vec3(0.34, 0.24, 0.12) * town * exp(-dot(f, f) * 10.0) * (0.5 + 0.5 * r4.y);
                }
            }
        }
    } else {
        float m = -y / F;                         // the ray's drop per metre
        float dFlat = E / m;                      // where it meets the sea's level
        float sFlat = dFlat * q - D0;             // metres seaward of the shoreline there
        float k = sqrt(9.81 * tanb) * 0.5;
        float gs = 9.81 * tanB;

        // The nearest wave face the ray meets, the light on the flat where it meets none, and the glow mirrored there.
        float bestD = dFlat, faceU = -1.0, faceH = 0.0, faceA = 0.0, faceGlow = 0.0, faceTau = -10.0;
        float trail = 0.0, swashEdge = 0.0, wetAge = 1000.0, swashCover = 0.0, refl = 0.0, halo = 0.0, haloD = 0.0;
        float A0 = dFlat * p;
        for (int i = 0; i < 6; i++) {
            vec4 w = i == 0 ? u_w0 : (i == 1 ? u_w1 : (i == 2 ? u_w2 : (i == 3 ? u_w3 : (i == 4 ? u_w4 : u_w5))));
            if (w.y <= 0.0) { continue; }
            float sbN = w.y / (GAMMA * tanb);
            // Twice: once where the ray meets the sea, once where it meets this wave's crest.
            float A = A0, sc = 0.0, tau = 0.0, sb = sbN, tt = 0.0;
            for (int pass = 0; pass < 2; pass++) {
                float bar = vnoise(A / 40.0 + u_seed) * 2.0 - 1.0;
                sb = sbN * (1.0 + 0.2 * bar) * mix(0.4, 1.0, smoothstep(-0.8, -0.5, bar)) * (0.3 + 0.7 * exp(-abs(A - w.w) * w.z * 1.4));
                tt = w.x - oblique * A;
                float r = sqrt(sbN) - k * tt;
                sc = r > 0.0 ? r * r : 0.0;
                tau = tt - (sqrt(sbN) - sqrt(sb)) / k + 0.3 * (vnoise(A * 0.35 + w.w * 7.0) - 0.5);   // a ragged edge to the break
                A = (sc + D0) / max(q, 0.05) * p;
            }
            float broken = smoothstep(-0.25, 0.25, tau);
            float Hn = w.y * pow(sb / max(sc, sb), 0.25) * smoothstep(4.5 * sbN, 2.2 * sbN, sc);
            float Hb = w.y * mix(1.0, 0.3 + 0.5 * clamp(sc / sb, 0.0, 1.0), smoothstep(0.0, 1.6, tau));
            float lump = 0.75 + 0.3 * vnoise(A * 0.35 + w.w) + 0.18 * vnoise(A * 1.7 - w.w * 3.0) * broken;   // the foam's lumpy top
            Hb *= lump;
            float Hh = mix(Hn, Hb, smoothstep(-0.2, 1.4, tau)) * smoothstep(0.0, 0.5, sc);   // the pile builds behind the break
            float wf = Hh * mix(mix(7.0, 1.3, smoothstep(-8.0, 0.0, tau)), 0.9, broken);
            float bright = pow(w.y, 0.7) * u_look.x;
            float glowNow = boreGlow(tau, u_look.y) * broken;
            if (q > 0.05 && Hh > 0.02) {
                // Where the ray meets this wave's face, a straight slope from its foot to its crest.
                float dA = (sc - wf + D0) / q, wd = wf / q, dC = dA + wd;
                float d = (E + Hh * dA / wd) / (m + Hh / wd);
                float u = (d - dA) / wd;
                if (u >= 0.0 && u <= 1.0 && d < bestD) {
                    bestD = d; faceU = u; faceH = Hh; faceA = A; faceTau = tau;
                    float lip = plunge * smoothstep(-0.45, 0.0, tau) * exp(-max(tau, 0.0) / 0.6) * smoothstep(0.8, 0.97, u);
                    float spill = (1.0 - plunge) * smoothstep(-1.2, 0.0, tau) * smoothstep(1.0 - 0.35 * smoothstep(-1.2, 1.0, tau), 1.0, u) * (1.0 - broken);
                    faceGlow = (glowNow * (0.3 + 0.7 * u * u) + 1.8 * lip + 0.9 * spill) * bright;
                }
                // Spray over a breaking crest: a soft halo where the ray passes just above it.
                float over = E - m * dC - Hh / lump * 0.95;
                if (over > 0.0 && dC < dFlat) {
                    float hl = (glowNow + plunge * smoothstep(-0.45, 0.0, tau) * exp(-max(tau, 0.0) / 0.8)) * bright
                             * exp(-over / (0.1 + 0.2 * Hh));
                    if (hl > halo) { halo = hl; haloD = dC; }
                }
                // The same face mirrored where the ray meets the flat.
                float dR = (Hh * dA / wd - m * dFlat) / (Hh / wd - m);
                float uR = (dR - dA) / wd;
                if (dA > dFlat && uR >= 0.0 && uR <= 1.0 && Hh / wd > m) {
                    refl = max(refl, glowNow * (0.3 + 0.7 * uR * uR) * bright);
                }
            }
            // On the flat: the foam a bore left behind it, fading.
            if (sFlat > 0.0 && sFlat < sb && tau > 0.0) {
                float tp = (sqrt(sb) - sqrt(sFlat)) / k;   // seconds after breaking that the bore passed here
                float since = tau - tp;
                if (since > 0.0) { trail += boreGlow(tp, u_look.y) * exp(-since / (2.2 * u_look.y)) * bright; }
            }
            // The swash: up the sand and back, its edge glowing, the sand it wets sparkling as it drains.
            float ts = tt - sqrt(sbN) / k;
            float u0 = sqrt(9.81 * 0.35 * w.y);
            float xr = max(u0 * ts - 0.5 * gs * ts * ts, 0.0);
            float run = u0 * u0 / (2.0 * gs);
            float dur = 2.0 * u0 / gs;
            if (sFlat < 0.0 && ts > 0.0) {
                float upSand = -sFlat;
                if (ts < dur && upSand < xr) {
                    swashCover = 1.0;
                    swashEdge += exp(-pow((upSand - xr) / 0.4, 2.0)) * smoothstep(dur * 0.6, 0.0, ts) * bright;
                    trail += 0.15 * exp(-ts / 2.5) * bright;
                }
                if (upSand < run) { wetAge = min(wetAge, max(ts - (u0 - sqrt(max(u0 * u0 - 2.0 * gs * upSand, 0.0))) / gs, 0.0)); }
            }
        }

        // What the ray met.
        float s = bestD * q - D0;
        float A = faceU >= 0.0 ? faceA : bestD * p;
        float onSand = step(s, 0.0) * step(faceU, -0.5) * (1.0 - swashCover);
        float wet = exp(-wetAge / 25.0);
        vec4 n1 = texture2D(u_noise, nuv(faceU >= 0.0 ? vec2(A * 0.07, faceU * faceH * 0.3 - faceTau * 0.2) : vec2(A * 0.07, s * 0.1)));
        vec4 n2 = texture2D(u_noise, nuv(faceU >= 0.0 ? vec2(A * 0.17, faceU * faceH * 0.75 - faceTau * 0.3) + n1.rb * 0.2 : vec2(A * 0.19, s * 0.27) + n1.rb * 0.2));
        // The sea between waves: a little of the sky's light off the water, more toward the horizon, broken by ripples.
        float graze = exp(-m * 8.0);
        vec3 sea = mix(u_sea, vec3(0.09, 0.10, 0.133), moon * 0.6) + skyLow * (0.06 + 0.6 * graze) * (0.6 + 0.8 * n2.b);
        vec3 seaFace = sea * mix(1.0, 0.55, smoothstep(-6.0, 0.0, faceTau) * (1.0 - step(0.0, faceTau)) * smoothstep(0.0, 0.9, faceU));
        vec3 sandCol = mix(u_sand, vec3(0.15, 0.133, 0.157), moon * 0.7) * (0.85 + 0.3 * n2.b);
        sandCol = mix(sandCol, sea * 0.9, wet * 0.85);
        vec3 base = onSand > 0.5 ? sandCol : (faceU >= 0.0 ? seaFace : sea);

        // Foam: billows rolling up a face, lace on the flat that thins as it ages (u_look.z smooths both to mist).
        float billow = smoothstep(0.25, 0.8, n1.g * 0.6 + n2.g * 0.5);
        float lace = smoothstep(0.55, 0.2, n1.g) * 0.8 + smoothstep(0.5, 0.25, n2.g) * 0.4;
        lace *= smoothstep(0.25, 0.6, n1.r + 0.2);
        float face = mix(0.3 + 0.9 * billow, 0.8, u_look.z);
        float flat = mix(0.12 + 1.1 * lace, 0.55, u_look.z);
        float light = faceU >= 0.0 ? faceGlow * face : trail * flat;
        light += swashEdge * (0.5 + 0.6 * n2.g);
        light += halo * 0.45 * step(haloD, bestD + 0.01) * (0.7 + 0.3 * n1.r);
        light += refl * mix(0.3, 0.55, wet * onSand + swashCover) * (0.4 + 0.8 * n2.b) * step(faceU, -0.5);

        // Noctiluca: the light broken into points, each cell flashing once in a while (research-look.md §1).
        if (u_glowc.w > 0.5) {
            vec2 cell = floor(pts / 2.0);
            vec4 r = hash42(cell + floor(t * 2.0 + hash21(cell) * 7.0) * 13.0);
            light = light * 0.2 + step(r.x, clamp(light * 0.3, 0.0, 0.5)) * (1.0 + 1.6 * r.y);
        }
        // Points on wet sand where the swash drained (Noctiluca's sparkle, sparse and dim).
        vec4 sr = hash42(floor(pts / 1.5));
        float spark = step(sr.x, 0.016) * exp(-wetAge / 9.0) * step(s, 0.0) * step(faceU, -0.5)
                    * pow(0.5 + 0.5 * sin(t * (1.0 + 2.0 * sr.y) + sr.z * 40.0), 6.0) * u_look.x;

        float L = 1.0 - exp(-light * 0.9);
        col = base + ramp(L, u_edge, u_body, u_core, u_foam) + u_foam * spark * 1.2;
        DEBUG
        // The Moon's glitter path, broken by the ripples.
        if (moon > 0.0 && s > 0.0 && faceU < 0.0) {
            float path = exp(-pow((x - u_moon.y) / (0.015 + 0.6 * m), 2.0));
            col += vec3(0.6, 0.62, 0.62) * moon * path * pow(n2.b, 5.0) * 2.0;
        }
    }
    col += (hash21(pts * 2.0) - 0.5) / 255.0;
    gl_FragColor = vec4(col, 1.0);
}
""".replacingOccurrences(of: "DEBUG", with: ProcessInfo.processInfo.environment["DEBUG"] ?? "")
   .replacingOccurrences(of: "GAMMA", with: String(format: "%.3f", gamma))

/// Weather's CloudNoise (WeatherSky.swift), copied: 257 texels square with the first row and column repeated, so it
/// wraps; r fbm from 4 cells, g billows (worley at 12, 24, 48), b fine fbm from 16, a fbm from 8. The build shares it.
func noiseTexture() -> SKTexture {
    let n = 256, m = n + 1
    func hash(_ x: Int, _ y: Int, _ s: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: x &* 374761393 &+ y &* 668265263 &+ s &* 2246822519)
        h = (h ^ (h >> 13)) &* 1274126177
        return Double(h ^ (h >> 16)) / Double(UInt32.max)
    }
    func value(_ x: Double, _ y: Double, _ period: Int, _ s: Int) -> Double {
        let (xi, yi) = (Int(floor(x)), Int(floor(y)))
        var (fx, fy) = (x - floor(x), y - floor(y))
        fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
        func h(_ i: Int, _ j: Int) -> Double { hash((i % period + period) % period, (j % period + period) % period, s) }
        return (h(xi, yi) * (1 - fx) + h(xi + 1, yi) * fx) * (1 - fy) + (h(xi, yi + 1) * (1 - fx) + h(xi + 1, yi + 1) * fx) * fy
    }
    func fbm(_ u: Double, _ v: Double, _ first: Int, _ s: Int) -> Double {
        var sum = 0.0, a = 0.5, p = first
        for o in 0..<4 { sum += a * value(u * Double(p), v * Double(p), p, s + o); a *= 0.5; p *= 2 }
        return sum / 0.9375
    }
    func worley(_ u: Double, _ v: Double, _ period: Int) -> Double {
        let (x, y) = (u * Double(period), v * Double(period))
        var best = 9.0
        for j in -1...1 { for i in -1...1 {
            let (ci, cj) = (Int(floor(x)) + i, Int(floor(y)) + j)
            let (wi, wj) = ((ci % period + period) % period, (cj % period + period) % period)
            let px = Double(ci) + hash(wi, wj, 91), py = Double(cj) + hash(wi, wj, 92)
            best = min(best, (px - x) * (px - x) + (py - y) * (py - y))
        } }
        return 1 - min(best.squareRoot(), 1)
    }
    var bytes = [UInt8](repeating: 0, count: m * m * 4)
    for y in 0..<m { for x in 0..<m {
        let (u, v) = (Double(x % n) / Double(n), Double(y % n) / Double(n))
        let billows = 0.5 * worley(u, v, 12) + 0.3 * worley(u, v, 24) + 0.2 * worley(u, v, 48)
        let i = (y * m + x) * 4
        for (c, value) in [fbm(u, v, 4, 1), billows, fbm(u, v, 16, 20), fbm(u, v, 8, 40)].enumerated() { bytes[i + c] = UInt8(value * 255) }
    } }
    let texture = SKTexture(data: Data(bytes), size: CGSize(width: m, height: m))
    texture.filteringMode = .linear
    return texture
}

func f4(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> vector_float4 { [Float(a), Float(b), Float(c), Float(d)] }
func f3(_ c: SIMD3<Double>) -> vector_float3 { [Float(c.x), Float(c.y), Float(c.z)] }

let now = SKUniform(name: "u_now", float: 0)
let waveUniforms = (0..<6).map { SKUniform(name: "u_w\($0)", vectorFloat4: f4(0, 0, 0, 0)) }
let moonUp = cfg.moon ?? 0
let uniforms: [SKUniform] = [
    SKUniform(name: "u_size", vectorFloat2: [Float(wPt), Float(hPt)]), now,
    SKUniform(name: "u_view", vectorFloat4: f4(view.hz, view.F, view.E, view.D0)),
    SKUniform(name: "u_beach", vectorFloat4: f4(view.yaw, tanb, beachFace, min(1, max(0, (iribarren - 0.3) / 0.4)))),
    SKUniform(name: "u_moon", vectorFloat4: f4(pow(moonUp, 1.6), -0.35 * wPt / hPt, 0.2, moonUp)),
    SKUniform(name: "u_land", vectorFloat4: f4((cfg.land ?? false) ? 1 : 0, 0.2 * wPt / hPt, 0.1, (cfg.lights ?? false) ? 1 : 0)),
    SKUniform(name: "u_look", vectorFloat4: f4(look.gain, look.fade, look.smooth, look.lift)),
    SKUniform(name: "u_glowc", vectorFloat4: f4(oblique, 0, 0, look.points)),
    SKUniform(name: "u_seed", float: Float(Double(cfg.seed ?? 1).truncatingRemainder(dividingBy: 97))),
    SKUniform(name: "u_sky", vectorFloat3: f3(pal.sky)), SKUniform(name: "u_sea", vectorFloat3: f3(pal.sea)),
    SKUniform(name: "u_sand", vectorFloat3: f3(pal.sand)), SKUniform(name: "u_edge", vectorFloat3: f3(pal.edge)),
    SKUniform(name: "u_body", vectorFloat3: f3(pal.body)), SKUniform(name: "u_core", vectorFloat3: f3(pal.core)),
    SKUniform(name: "u_foam", vectorFloat3: f3(pal.foam)),
    SKUniform(name: "u_noise", texture: noiseTexture()),
] + waveUniforms

/// Hands the shader the six waves that matter at time t: the newest that has come within sight, and the five before
/// it, as their age since breaking (worked out in Double here, so no clock grows in the shader).
func place(_ t: Double) {
    now.floatValue = Float(t.truncatingRemainder(dividingBy: 3600))
    let k = sqrt(9.81 * tanb) / 2
    let newest = train.lastIndex { w in
        let sb = w.hb / (gamma * tanb)
        return t > w.tb - (sqrt(4.5 * sb) - sqrt(sb)) / k
    } ?? 0
    for i in 0..<6 {
        let j = newest - i
        guard j >= 0 else { waveUniforms[i].vectorFloat4Value = f4(0, 0, 0, 0); continue }
        let w = train[j]
        waveUniforms[i].vectorFloat4Value = f4(t - w.tb, w.hb, w.peel, w.peak)
    }
}

let scene = SKScene(size: CGSize(width: wPt, height: hPt))
scene.backgroundColor = .black
let shore = SKSpriteNode(color: .black, size: scene.size)
shore.anchorPoint = .zero
shore.shader = SKShader(source: source, uniforms: uniforms)
scene.addChild(shore)

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: W, height: H, mipmapped: false)
desc.usage = [.renderTarget, .shaderRead]
desc.storageMode = .shared
let target = device.makeTexture(descriptor: desc)!
let renderer = SKRenderer(device: device)
renderer.scene = scene
var gpuTimes: [Double] = []

func render(at t: Double, to path: String?) {
    place(t)
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    renderer.update(atTime: t)
    let buf = queue.makeCommandBuffer()!
    renderer.render(withViewport: CGRect(x: 0, y: 0, width: W, height: H), commandBuffer: buf, renderPassDescriptor: pass)
    buf.commit()
    buf.waitUntilCompleted()
    gpuTimes.append(buf.gpuEndTime - buf.gpuStartTime)
    guard let path else { return }
    let bytes = W * 4
    var px = [UInt8](repeating: 0, count: bytes * H)
    target.getBytes(&px, bytesPerRow: bytes, from: MTLRegionMake2D(0, 0, W, H), mipmapLevel: 0)
    let ctx = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: bytes, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

if let times = cfg.times {
    for (i, t) in times.enumerated() { render(at: moment + t * speed, to: cfg.out + String(format: "-%03d.png", i)) }
} else if let frames = cfg.frames {
    let fps = cfg.fps ?? 30
    for f in 0..<frames { render(at: moment + Double(f) / fps * speed, to: cfg.out + String(format: "-%04d.png", f)) }
} else {
    render(at: moment, to: cfg.out)
    if ProcessInfo.processInfo.environment["COST"] != nil { // time it as the probe did: the median of 60 frames
        gpuTimes = []
        for f in 0..<90 { render(at: moment + Double(f) / 30, to: nil) }
        let g = gpuTimes.dropFirst(30).sorted()
        print(String(format: "gpu median %.3f ms at %dx%d", g[g.count / 2] * 1000, W, H))
    }
}
