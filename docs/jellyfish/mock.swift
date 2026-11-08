// Jellyfish mock-ups, drawn by SpriteKit's SKRenderer as the app's render test draws a wallpaper, so a tile shows what
// the app's shaders can draw. Not app code: the bell, the pulse and the tentacles here are the method research's
// (research-method.md) and are meant to carry into the build.
//
//   swiftc -O mock.swift -o $TMPDIR/jelly-mock && $TMPDIR/jelly-mock '<json>'
//
// The JSON: look (deep, rov, dark, fluor, gallery, glow), species (names below), count, seed, t (seconds), width and
// height (points, drawn at 2x), out (a .png, or a path prefix with times/frames). Optional: single (one jelly,
// centred, `size` its bell's share of the screen's width, `tilt`), times (one picture each), frames and fps (a film),
// speed, glow (indices of jellies caught glowing, in the dark look).
import Foundation
import Metal
import SpriteKit

struct Config: Decodable {
    var look: String
    var species: [String]
    var count: Int?, seed: UInt64?, t: Double?, width: Double?, height: Double?
    var out: String
    var single: Bool?, size: Double?, tilt: Double?, heading: Double?
    var times: [Double]?, frames: Int?, fps: Double?, speed: Double?
    var glow: [Int]?
    var near: Bool?
    var turn: Double? // a single jelly turns by this many radians in its first squeeze after 1 s
}

/// SplitMix64: the same layout for the same seed.
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

/// One species: its sizes and pulse (research-method.md §1) and the shape and colours its shader is built with.
struct Species {
    var diameter: ClosedRange<Double> // metres
    var period: Double // seconds a pulse at 15 cm; bigger ones beat slower
    var contraction = 0.4, relaxation = 1.4
    var perPulse = 0.35 // bell diameters travelled a pulse
    var slip = 0.0 // the sea nettle slips back as it re-opens
    var box: (w: Double, above: Double, below: Double) // the sprite in bell radii round the margin's centre
    var shape: [String: String]
    var body: SIMD3<Double>, organ: SIMD3<Double>, tent: SIMD3<Double>, arm: SIMD3<Double>
    var comb = false
}

let common: [String: String] = [
    "NT": "0", "TLEN": "1.0", "TW": "0.01", "TRAIL": "3.0", "SPREAD": "0.0", "SWAY": "0.15",
    "NOA": "0", "ALEN": "1.0", "AW": "0.1", "ASPREAD": "0.0", "ASWAY": "0.2", "TWIST": "1.5",
    "HEIGHT": "0.45", "RISE": "0.3", "SHRINK": "0.14", "PE": "2.0", "PQ": "2.0", "INNERR": "0.94", "INNERH": "0.55",
    "FLAP": "0.27", "LAPPETS": "0", "LAPDEPTH": "0.0", "NC": "16.0", "CANALSHARP": "16.0", "CANALK": "0.6",
    "STRIPES": "0", "GONADS": "0", "STEPS": "40", "GROOVEH": "0.5", "GROOVEK": "0.0", "STOMACH": "0.0", "LONGT": "0",
]

func v(_ hex: Int) -> SIMD3<Double> { SIMD3(Double(hex >> 16 & 255), Double(hex >> 8 & 255), Double(hex & 255)) / 255 }

/// Colours are the look research's samples (research-look.md §1, §3), as a dim lamp shows them.
let species: [String: Species] = [
    // Aurelia: a flat saucer, four horseshoe gonads, a fringe of short tentacles, four short frilled oral arms.
    "moon": Species(diameter: 0.12...0.25, period: 5.0, box: (2.6, 0.8, 1.6), shape: [
        "NT": "120", "TLEN": "0.32", "TW": "0.006", "SWAY": "0.25", "NOA": "4", "ALEN": "1.0", "AW": "0.17",
        "ASPREAD": "0.22", "ASWAY": "0.25", "TWIST": "3.0", "HEIGHT": "0.42", "RISE": "0.32", "NC": "32.0", "CANALSHARP": "10.0", "CANALK": "0.5", "GONADS": "1",
    ], body: v(0xC8C0DA), organ: v(0xD0B5DC), tent: v(0xB8B8D0), arm: v(0xC4B8D8)),
    // Chrysaora fuscescens: a striped gold bell, 24 maroon tentacles and four long white spiralling oral arms.
    "nettle": Species(diameter: 0.18...0.32, period: 2.8, contraction: 0.45, relaxation: 1.3, perPulse: 0.3, slip: 0.08,
                      box: (3.0, 0.9, 9.0), shape: [
        "NT": "24", "TLEN": "8.0", "TW": "0.012", "SWAY": "0.18", "SPREAD": "0.02", "TRAIL": "2.0", "NOA": "4", "ALEN": "7.0", "AW": "0.15",
        "ASPREAD": "0.04", "ASWAY": "0.18", "TWIST": "1.6", "HEIGHT": "0.6", "RISE": "0.28", "SHRINK": "0.12",
        "LAPPETS": "32", "LAPDEPTH": "0.05", "NC": "16.0", "CANALSHARP": "4.0", "CANALK": "0.2", "STRIPES": "16",
    ], body: v(0x977241), organ: v(0x70542F), tent: v(0x8A2A1E), arm: v(0xAFB3C8)),
    // Aequorea victoria: a clear glass wheel of a hundred fine canals and many long fine tentacles.
    "crystal": Species(diameter: 0.08...0.2, period: 2.2, contraction: 0.35, relaxation: 1.0, box: (2.6, 0.7, 3.4), shape: [
        "NT": "100", "TLEN": "3.0", "TW": "0.004", "SWAY": "0.2", "SPREAD": "0.03", "NOA": "1", "ALEN": "0.35", "AW": "0.3",
        "ASWAY": "0.05", "HEIGHT": "0.36", "RISE": "0.26", "SHRINK": "0.12", "NC": "100.0", "CANALSHARP": "40.0", "CANALK": "1.2",
    ], body: v(0x9FB4C8), organ: v(0x9FB4C8), tent: v(0x8FA4B8), arm: v(0xA8B8CC)),
    // Atolla wyvillei: a flat red crown, a groove round it, lappets, short tentacles and one long trailing one.
    "atolla": Species(diameter: 0.06...0.15, period: 3.0, box: (2.6, 0.6, 12.5), shape: [
        "NT": "20", "TLEN": "0.9", "TW": "0.018", "SWAY": "0.1", "SPREAD": "0.25", "HEIGHT": "0.32", "RISE": "0.2",
        "SHRINK": "0.1", "LAPPETS": "20", "LAPDEPTH": "0.12", "NC": "20.0", "CANALSHARP": "6.0", "CANALK": "0.3",
        "GROOVEH": "0.45", "GROOVEK": "1.2", "STOMACH": "0.5", "LONGT": "1",
    ], body: v(0xA8260B), organ: v(0x621004), tent: v(0xB8502A), arm: v(0xA8260B)),
    // Periphylla periphylla: a tall red-purple helmet with a skirt of lappets and twelve thick tentacles.
    "periphylla": Species(diameter: 0.1...0.2, period: 4.0, perPulse: 0.25, box: (3.2, 1.7, 2.2), shape: [
        "NT": "12", "TLEN": "1.8", "TW": "0.035", "SWAY": "0.35", "SPREAD": "0.2", "HEIGHT": "1.45", "RISE": "0.15",
        "SHRINK": "0.07", "PE": "1.25", "PQ": "1.1", "INNERH": "0.45", "LAPPETS": "16", "LAPDEPTH": "0.16",
        "NC": "16.0", "CANALSHARP": "4.0", "CANALK": "0.25", "GROOVEH": "0.3", "GROOVEK": "0.9", "STOMACH": "1.0",
    ], body: v(0x9E3640), organ: v(0x5A1C2A), tent: v(0x8E3A3C), arm: v(0x9E3640)),
    // Bolinopsis: a clear oval with two lobes and eight comb rows that catch the lamp in moving colours.
    "comb": Species(diameter: 0.06...0.12, period: 6.0, perPulse: 0.1, box: (2.4, 1.5, 2.1), shape: [:],
                    body: v(0x967882), organ: v(0x654E6A), tent: v(0x967882), arm: v(0x967882), comb: true),
]

/// What each look does to the colours, the backdrop and the light (research-look.md §2, research-method.md §2).
struct Look {
    var lit = true, steady = false, ring = false, events = false
    var lamp = SIMD3<Double>(1, 1, 1) // what the lamp's colour does to the bodies
    var pale = 0.0 // how far bodies go toward the tank's light
    var gain = 1.0
    var cap = 0.59 // broad light at most 150 of 255
    var glow = SIMD3<Double>(0, 0.64, 1.0) // 470 nm (Sapphire)
    var top = SIMD3<Double>(0, 0, 0), bottom = SIMD3<Double>(0, 0, 0), snow = 0.1
    var falloff = false // an ROV's lights: far ones fade to black
}

let looks: [String: Look] = [
    "deep": Look(lamp: [0.75, 0.62, 0.55], gain: 0.55, top: [0.012, 0.01, 0.014], bottom: [0.006, 0.005, 0.008], snow: 0.08),
    "rov": Look(lamp: [0.95, 0.95, 1.0], gain: 1.1, snow: 0.45, falloff: true),
    "dark": Look(lit: false, events: true, gain: 1.0, snow: 0.0),
    "fluor": Look(ring: true, lamp: [0.25, 0.45, 1.0], pale: 0.0, gain: 0.35, glow: [0, 1.0, 0.76],
                  top: [0, 0.012, 0.03], bottom: [0, 0.004, 0.012], snow: 0.05),
    "gallery": Look(lamp: [0.75, 0.95, 1.0], pale: 0.55, gain: 0.5, cap: 0.75,
                    top: [0.09, 0.35, 0.86], bottom: [0.01, 0.09, 0.26], snow: 0.12),
    "glow": Look(lit: false, steady: true, gain: 0.55, snow: 0.0),
]

func glsl(_ c: SIMD3<Double>) -> String { String(format: "vec3(%.4f, %.4f, %.4f)", c.x, c.y, c.z) }

let shaderCommon = """
float wrapf(float x, float y) { return x - y * floor(x / y); }
float hash11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}
// The bell's squeeze, 0 relaxed to 1 contracted: quick in, slow out, then a rest. p: start, period, in, out.
float squeezeAt(float t, vec4 p) {
    float tau = wrapf(t - p.x, p.y);
    return smoothstep(0.0, p.z, tau) * (1.0 - smoothstep(p.z, p.z + p.w, tau));
}
// A soft strand w wide at distance d, for pixels px wide, thinning in brightness rather than vanishing below a pixel.
float strand(float d, float w, float px) {
    float ww = max(w, px);
    return (w / ww) * (1.0 - smoothstep(ww * 0.5, ww * 0.5 + px, abs(d)));
}
float softplus(float x, float k) { return k * log(1.0 + exp(min(x / k, 30.0))); }
"""

/// The medusa: a bell marched in 24 steps (tissue seen edge-on makes the rim), tentacles and oral arms that follow
/// where the margin was a moment ago.
let medusa = shaderCommon + """
void main() {
    vec2 q = vec2((v_tex_coord.x - 0.5) * a_box.x, v_tex_coord.y * a_box.y - a_box.z);
    float px = a_box.w, t = u_t;
    float tilt = a_pose.x, seed = a_pose.y, bright = a_pose.z;
    float S = squeezeAt(t, a_pulse), Sm = squeezeAt(t - 0.15, a_pulse);
    float A = 1.0 - SHRINK * S, C = HEIGHT + RISE * S, Am = 1.0 - SHRINK * Sm;
    float cb = cos(tilt), sb = sin(tilt);
    float tissue = 0.0, skin = 0.0, organ = 0.0, ringPts = 0.0, spots = 0.0, wave = 0.0;
    if (q.y > -0.5 && q.y < C + 1.3 && abs(q.x) < 1.35) {
        float dz = 2.6 / float(STEPS);
        float jitter = hash21(v_tex_coord * 913.0 + seed);
        for (int i = 0; i < STEPS; i++) {
            float z = 1.3 - dz * (float(i) + jitter);
            float Yb = q.y * cb + z * sb;
            float Zb = -q.y * sb + z * cb;
            float rho = length(vec2(q.x, Zb));
            float phi = atan(Zb, q.x);
            float hn = clamp(Yb / C, 0.0, 1.0);
            float outer = A * pow(max(1.0 - pow(hn, PE), 0.0), 1.0 / PQ) + (Am - A) * (1.0 - smoothstep(0.0, FLAP * C, Yb));
            float bottom = -LAPDEPTH * (1.0 - pow(abs(sin(phi * float(LAPPETS) * 0.5)), 0.6));
            float inH = C * INNERH;
            float inner = A * INNERR * sqrt(max(1.0 - (Yb / inH) * (Yb / inH), 0.0));
            float below = smoothstep(bottom - 0.015, bottom + 0.015, Yb);
            float jel = smoothstep(outer + 0.02, outer - 0.02, rho) * below * smoothstep(inner - 0.02, inner + 0.02, rho);
            tissue += jel * dz;
            float sk = (exp(-pow((rho - outer) / 0.035, 2.0)) + 0.5 * exp(-pow((rho - inner) / 0.035, 2.0)) * step(Yb, inH)) * below * smoothstep(C + 0.03, C - 0.01, Yb);
            float canal = 1.0 + CANALK * pow(abs(cos(phi * NC * 0.5)), CANALSHARP) * (1.0 - hn);
            float groove = 1.0 + GROOVEK * exp(-pow((hn - GROOVEH) / 0.06, 2.0));
            float pigment = 1.0;
            #if STRIPES > 0
            pigment = 0.55 + 0.45 * smoothstep(0.2, 0.7, abs(sin(phi * float(STRIPES) * 0.5)));
            #endif
            skin += sk * canal * groove * pigment * dz;
            #if GONADS
            for (int k = 0; k < 4; k++) {
                float ang = 1.5708 * float(k) + 0.785;
                vec2 c = 0.33 * A * vec2(cos(ang), sin(ang));
                vec2 d = vec2(q.x, Zb) - c;
                float ring = length(d) - 0.15 * A;
                float open = smoothstep(0.55, 0.0, dot(normalize(d + 1e-4), vec2(cos(ang), sin(ang))));
                organ += exp(-pow(ring / 0.04, 2.0)) * open * exp(-pow((Yb - inH * 0.95) / 0.09, 2.0)) * dz * 5.0;
            }
            #endif
            organ += STOMACH * exp(-(rho * rho) / 0.09 - pow((Yb - C * 0.5) / (0.25 * C), 2.0)) * dz;
            #if RING
            float idx = floor(phi / 6.2832 * 100.0 + 0.5);
            float dphi = (phi - idx * 6.2832 / 100.0) * Am;
            ringPts += exp(-(pow(rho - outer, 2.0) + Yb * Yb + dphi * dphi) / 0.0006) * dz * 45.0;
            #endif
            #if SPOTS
            vec2 cell = vec2(phi * 7.0, Yb * 9.0);
            vec2 id = floor(cell), f = fract(cell) - 0.5;
            float h = hash21(id + seed);
            spots += sk * step(0.45, h) * exp(-dot(f, f) * 40.0) * smoothstep(1.0 - a_glow.y, 1.05 - a_glow.y, 1.0 - hn) * dz * 6.0;
            #endif
            #if PINWHEEL
            float arms = pow(max(cos(3.0 * (phi - a_glow.y)), 0.0), 6.0);
            wave += sk * arms * smoothstep(0.7, 0.05, hn) * dz * 4.0;
            #endif
        }
    }
    float tent = 0.0, arm = 0.0;
    float turnS = a_turn.x, dth = a_turn.y;
    for (int i = 0; i < NT; i++) {
        float fi = float(i);
        float phi = 6.2832 * (fi + 0.4 * hash11(fi * 7.13 + seed)) / float(NT);
        float rootY = -LAPDEPTH * 0.7 - Am * sin(phi) * sb;
        float s = (rootY - q.y) / max(cb, 0.3);
        float r = (1.0 - SHRINK * squeezeAt(t - 0.15 - s / TRAIL, a_pulse)) * (1.0 + SPREAD * s);
        float x = r * cos(phi) - sin(dth) * softplus(s - TRAIL * turnS, 0.4)
            + SWAY * s * (vnoise(vec2(s * 0.7 - t * 0.25, fi * 3.7 + seed)) - 0.5);
        float w = TW * (1.0 - 0.6 * clamp(s / TLEN, 0.0, 1.0));
        float fade = smoothstep(-0.02, 0.06, s) * (1.0 - smoothstep(TLEN * 0.5, TLEN, s));
        tent += strand(q.x - x, w, px) * fade * (0.7 + 0.3 * sin(phi));
    }
    #if LONGT
    {
        float phi = 6.2832 * hash11(seed * 3.1);
        float rootY = -LAPDEPTH * 0.7 - Am * sin(phi) * sb;
        float s = (rootY - q.y) / max(cb, 0.3);
        float x = cos(phi) * (1.0 - SHRINK * squeezeAt(t - 0.15 - s / TRAIL, a_pulse)) - sin(dth) * softplus(s - TRAIL * turnS, 0.4)
            + 1.2 * sin(s * 0.35 + seed - t * 0.05) * min(s, 4.0) / 4.0;
        float fade = smoothstep(-0.02, 0.06, s) * (1.0 - smoothstep(6.0, 10.0, s));
        tent += 0.6 * strand(q.x - x, 0.02, px) * fade;
    }
    #endif
    for (int k = 0; k < NOA; k++) {
        float fk = float(k);
        float phi = 1.5708 * fk + 0.785 + 0.3 * hash11(fk + seed);
        float rootY = C * INNERH * 0.4 - 0.14 * sin(phi) * sb;
        float s = (rootY - q.y) / max(cb, 0.3);
        float lag = s / (TRAIL * 0.6);
        float x = 0.14 * cos(phi) * (1.0 - 0.5 * SHRINK * squeezeAt(t - lag, a_pulse)) + ASPREAD * s * cos(phi)
            - sin(dth) * softplus(s - TRAIL * 0.6 * turnS, 0.4) + ASWAY * s * (vnoise(vec2(s * 0.5 - t * 0.15, fk * 5.3 + seed)) - 0.5);
        float twist = 0.35 + 0.65 * abs(cos(s * TWIST + fk * 1.3 + t * 0.1));
        float w = AW * twist * (1.0 - 0.5 * clamp(s / ALEN, 0.0, 1.0));
        float d = abs(q.x - x);
        float frill = 0.5 + vnoise(vec2(s * 9.0, fk * 11.0 + d * 30.0));
        float core = 1.0 - smoothstep(w * 0.5, w * 0.5 + px, d);
        float edge = exp(-pow((d - w * 0.45) / (0.25 * w + px), 2.0));
        float fade = smoothstep(-0.05, 0.1, s) * (1.0 - smoothstep(ALEN * 0.55, ALEN, s));
        arm += (0.12 * core + 0.4 * edge * frill) * fade;
    }
    vec3 col = vec3(0.0);
    #if LIT
    col += BODY * (tissue * 0.22 + skin * 2.6) + ORGAN * organ * 1.5 + TENT * tent * 0.8 + ARM * arm * 0.7;
    #endif
    #if STEADY
    col += GLOWC * (tissue * 0.18 + skin * 2.2 + tent * 0.5 + arm * 0.4);
    #endif
    #if RING
    col += GLOWC * min(ringPts, 2.5) / max(GAIN, 0.01) * 0.6;
    #endif
    #if SPOTS
    col += GLOWC * (spots + 0.15 * skin * smoothstep(1.0 - a_glow.y, 1.05 - a_glow.y, 0.5)) * a_glow.x;
    #endif
    #if PINWHEEL
    col += GLOWC * wave * a_glow.x;
    #endif
    col *= bright * GAIN;
    col = CAP * (vec3(1.0) - exp(-col / CAP));
    gl_FragColor = vec4(col, 0.0);
}
"""

/// A lobed comb jelly: a clear oval, its lobes, and eight comb rows whose beating catches the lamp in moving colours.
let combShader = shaderCommon + """
void main() {
    vec2 q = vec2((v_tex_coord.x - 0.5) * a_box.x, v_tex_coord.y * a_box.y - a_box.z);
    float t = u_t, tilt = a_pose.x, seed = a_pose.y, bright = a_pose.z;
    float cb = cos(tilt), sb = sin(tilt);
    float tissue = 0.0, skin = 0.0, glint = 0.0;
    float dz = 2.0 / float(STEPS);
    float jitter = hash21(v_tex_coord * 913.0 + seed);
    for (int i = 0; i < STEPS; i++) {
        float z = 1.0 - dz * (float(i) + jitter);
        float Yb = q.y * cb + z * sb, Zb = -q.y * sb + z * cb;
        vec3 p = vec3(q.x, Yb, Zb);
        float body = length(p / vec3(0.6, 1.25, 0.52)) - 1.0;
        float flap = 0.05 * sin(t * 0.7 + seed);
        float lobeL = length((p - vec3(-0.32 - flap, -0.95, 0.05)) / vec3(0.5, 0.95, 0.2)) - 1.0;
        float lobeR = length((p - vec3(0.32 + flap, -0.95, -0.05)) / vec3(0.5, 0.95, 0.2)) - 1.0;
        float f = min(body, min(lobeL, lobeR));
        tissue += smoothstep(0.04, -0.04, f) * dz;
        float sk = exp(-pow(f / 0.05, 2.0));
        skin += sk * dz;
        float phi = atan(Zb, q.x);
        float row = pow(max(cos(8.0 * phi + 0.4), 0.0), 30.0) * exp(-pow(body / 0.06, 2.0)) * smoothstep(-0.9, -0.3, Yb) * smoothstep(1.2, 0.8, Yb);
        float beat = 0.25 + pow(0.5 + 0.5 * sin(Yb * 30.0 - t * 7.0 + phi * 2.0), 6.0);
        glint += row * beat * dz * 6.0;
    }
    vec3 col = vec3(0.0);
    #if LIT
    vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (fract(q.y * 0.9 - t * 0.35 + seed) + vec3(0.0, 0.33, 0.67)));
    col += BODY * (tissue * 0.12 + skin * 2.0) + rainbow * glint * 0.9;
    #endif
    #if STEADY
    col += GLOWC * (tissue * 0.12 + skin * 2.0);
    #endif
    col *= bright * GAIN;
    col = CAP * (vec3(1.0) - exp(-col / CAP));
    gl_FragColor = vec4(col, 0.0);
}
"""

/// The water: the look's backdrop, darker toward the bottom, and three layers of drifting marine snow.
let water = shaderCommon + """
void main() {
    vec2 p = v_tex_coord * u_px;
    vec3 col = mix(BOTTOM, TOP, v_tex_coord.y);
    float s = 0.0;
    for (int i = 0; i < 3; i++) {
        float cell = 46.0 + 52.0 * float(i);
        vec2 q = p / cell + vec2(0.05 * sin(u_t * 0.05 + float(i)), u_t * (0.012 + 0.008 * float(i)));
        vec4 r = vec4(hash21(floor(q) + float(i) * 17.0), hash21(floor(q) + 3.1), hash21(floor(q) + 7.7), hash21(floor(q) + 9.3));
        vec2 f = fract(q) - 0.5 - (r.yz - 0.5) * 0.6;
        s += step(r.x, 0.22) * exp(-dot(f, f) * cell * cell / (1.2 + 2.5 * float(i))) * (0.3 + 0.7 * r.w) * (0.5 + 0.5 * float(i));
    }
    gl_FragColor = vec4(col + SNOW * s * vec3(0.8, 0.85, 0.9), 1.0);
}
"""

func source(_ base: String, _ defines: [String: String]) -> String {
    defines.sorted { $0.key < $1.key }.map { "#define \($0.key) \($0.value)\n" }.joined() + base
}

/// One jelly in metres, seen by a camera 50° across.
struct Jelly {
    var kind: String, sp: Species
    var x: Double, y: Double, z: Double, d: Double // metres
    var heading: Double, tilt: Double, seed: Double
    var t0: Double, period: Double
    var drift: SIMD2<Double>
    var turnAt = -100.0, turn = 0.0
    var glow = 0.0, glowFront = 1.0
    var node: SKSpriteNode? = nil
}

let cfg = try! JSONDecoder().decode(Config.self, from: CommandLine.arguments[1].data(using: .utf8)!)
let look = looks[cfg.look]!
let (wPt, hPt) = (cfg.width ?? 1512, cfg.height ?? 982)
let (W, H) = (Int(wPt * 2), Int(hPt * 2))
let fov = tan(25 * Double.pi / 180) * 2 // view width per metre of depth
func pxPerMetre(_ z: Double) -> Double { Double(W) / (fov * z) }
let speed = cfg.speed ?? 1
var rng = Rand(s: cfg.seed ?? 1)

/// The speed profile of one pulse, normalised so a pulse goes `perPulse` diameters: the surge while squeezing, a
/// slip back while re-opening (the sea nettle), and the softer second push of the recaptured vortex (Gemmell 2013).
func velocityShape(_ tau: Double, _ sp: Species) -> Double {
    let tc = sp.contraction, tr = sp.relaxation
    var v = tau < tc + 0.25 ? pow(sin(.pi * tau / (tc + 0.25)), 2) : 0
    if tau > tc && tau < tc + tr { v -= sp.slip * 4 * pow(sin(.pi * (tau - tc) / tr), 2) }
    let r0 = tc + 0.6 * tr
    if tau > r0 && tau < r0 + 1.4 { v += 0.35 * pow(sin(.pi * (tau - r0) / 1.4), 2) }
    return v
}
func shapeArea(_ sp: Species, _ period: Double) -> Double {
    stride(from: 0.0, to: period, by: 1.0 / 240).reduce(0) { $0 + velocityShape($1, sp) / 240 }
}

var jellies: [Jelly] = []
func addJelly(_ kind: String, x: Double, y: Double, z: Double, d: Double? = nil) {
    let sp = species[kind]!
    let dia = d ?? rng.range(sp.diameter)
    let period = sp.period * pow(dia / 0.15, 0.5) * rng.range(0.9...1.1)
    jellies.append(Jelly(kind: kind, sp: sp, x: x, y: y, z: z, d: dia,
                         heading: cfg.heading ?? rng.range(-1.0...1.0), tilt: cfg.tilt ?? rng.range(-0.25...0.6),
                         seed: rng.range(0...50), t0: rng.range(0...period), period: period,
                         drift: [rng.range(-0.004...0.004), -0.0015]))
}

if cfg.single == true {
    // Its own real size, and the camera as far back as makes it `size` of the screen's width; a pulse starts at 1 s.
    let kind = cfg.species[0], sp = species[kind]!
    let d = (sp.diameter.lowerBound + sp.diameter.upperBound) / 2, z = d / ((cfg.size ?? 0.3) * fov)
    let middle = (sp.box.below - sp.box.above) / 2 * d / 2 // the margin placed so its box is centred
    addJelly(kind, x: 0, y: min(middle, fov * z * hPt / wPt * 0.3), z: z, d: d)
    jellies[0].period = sp.period * pow(d / 0.15, 0.5)
    jellies[0].t0 = 1
    jellies[0].drift = .zero
} else {
    // Three bands of depth: one or two near, a few in the middle, more far off (research-method.md §4), the camera
    // as far back as the animals are big, as a tank's window or an ROV's camera frames them.
    let n = cfg.count ?? 10
    let scale = cfg.species.map { species[$0]!.diameter }.reduce(0) { $0 + ($1.lowerBound + $1.upperBound) / 2 } / Double(cfg.species.count) / 0.1
    var bands: [ClosedRange<Double>] = []
    for i in 0..<n { bands.append(i < n / 8 ? 0.35...0.55 : i < n * 4 / 10 ? 0.65...1.3 : 1.5...3.2) }
    if cfg.near == true { bands[0] = 0.22...0.26 }
    bands = bands.map { ($0.lowerBound * scale)...($0.upperBound * scale) }
    // A jittered grid, shuffled, so they spread over the screen as a tank shows them rather than bunching by chance.
    let cols = Int((Double(n) * wPt / hPt).squareRoot().rounded(.up)), rows = (n + cols - 1) / cols
    var cells = Array(0..<(cols * rows))
    for i in cells.indices.reversed() { cells.swapAt(i, Int(rng.next() * Double(i + 1))) }
    for (i, band) in bands.enumerated() {
        let z = rng.range(band)
        let halfW = fov * z / 2, halfH = halfW * hPt / wPt
        let (cx, cy) = (Double(cells[i] % cols), Double(cells[i] / cols))
        let u = (cx + rng.range(0.2...0.8)) / Double(cols) * 2 - 1, w = (cy + rng.range(0.2...0.8)) / Double(rows) * 2 - 1
        let near = i < n / 8 // a near one's bell would rise off the top, and its tentacles hang far down
        addJelly(cfg.species[i % cfg.species.count], x: u * (near ? 0.6 : 0.9) * halfW, y: (near ? w * 0.25 - 0.05 : w * 0.7) * halfH, z: z)
    }
}
for i in cfg.glow ?? [] where i < jellies.count {
    jellies[i].glow = 1
    jellies[i].glowFront = 0.8
}

/// Steps every jelly from its start to time t in 1/60 s substeps, so any frame rate gives the same picture: the
/// pulse's surge along its axis, turns made only while squeezing, the current and a slow sink.
var simTime = 0.0
func advance(to t: Double) {
    let dt = 1.0 / 60
    while simTime + dt <= t {
        for i in jellies.indices {
            var j = jellies[i]
            let area = shapeArea(j.sp, j.period)
            let tau = (simTime - j.t0).truncatingRemainder(dividingBy: j.period)
            let tauP = tau < 0 ? tau + j.period : tau
            if tauP < dt, cfg.single == true, let turn = cfg.turn, j.turnAt < 0, simTime > 1 {
                j.turn = turn
                j.turnAt = simTime + j.sp.contraction / 2
            }
            if tauP < dt && cfg.single != true && rng.next() < 0.35 { // a turn, made during this squeeze
                let away = abs(j.heading) > 0.5 ? -copysign(1, j.heading) : (rng.next() < 0.5 ? -1 : 1)
                j.turn = away * rng.range(0.17...0.6)
                j.turnAt = simTime + j.sp.contraction / 2
            }
            if simTime >= j.turnAt - j.sp.contraction / 2 && simTime < j.turnAt + j.sp.contraction / 2 {
                j.heading += j.turn * dt / j.sp.contraction
            }
            let v = velocityShape(tauP, j.sp) / area * j.sp.perPulse * j.d
            j.x += -sin(j.heading) * v * dt + j.drift.x * dt
            j.y += cos(j.heading) * v * dt + j.drift.y * dt
            jellies[i] = j
        }
        simTime += dt
    }
}

let time = SKUniform(name: "u_t", float: 0)
var shaders: [String: SKShader] = [:]
func shader(for j: Jelly) -> SKShader {
    if let s = shaders[j.kind] { return s }
    var d = common.merging(j.sp.shape) { $1 }
    func body(_ c: SIMD3<Double>) -> SIMD3<Double> { (c * (1 - look.pale) + look.pale * SIMD3(0.8, 0.95, 1.0)) * look.lamp }
    d["BODY"] = glsl(body(j.sp.body)); d["ORGAN"] = glsl(body(j.sp.organ)); d["TENT"] = glsl(body(j.sp.tent)); d["ARM"] = glsl(body(j.sp.arm))
    d["GLOWC"] = glsl(look.glow); d["GAIN"] = String(format: "%.3f", look.gain); d["CAP"] = String(format: "%.3f", look.cap)
    d["LIT"] = look.lit ? "1" : "0"; d["STEADY"] = look.steady ? "1" : "0"
    d["RING"] = look.ring && j.kind == "crystal" ? "1" : "0"
    d["SPOTS"] = look.events && j.kind == "periphylla" ? "1" : "0"
    d["PINWHEEL"] = look.events && j.kind == "atolla" ? "1" : "0"
    let s = SKShader(source: source(j.sp.comb ? combShader : medusa, d), uniforms: [time])
    s.attributes = ["a_box", "a_pose", "a_pulse", "a_turn", "a_glow"].map { SKAttribute(name: $0, type: .vectorFloat4) }
    shaders[j.kind] = s
    return s
}

let scene = SKScene(size: CGSize(width: wPt, height: hPt))
scene.backgroundColor = .black
let backdrop = SKSpriteNode(color: .black, size: scene.size)
backdrop.position = CGPoint(x: wPt / 2, y: hPt / 2)
backdrop.shader = SKShader(source: source(water, ["TOP": glsl(look.top), "BOTTOM": glsl(look.bottom), "SNOW": String(format: "%.3f", look.snow)]),
                           uniforms: [time, SKUniform(name: "u_px", vectorFloat2: [Float(W), Float(H)])])
scene.addChild(backdrop)
for i in jellies.indices.sorted(by: { jellies[$0].z > jellies[$1].z }) {
    let n = SKSpriteNode(color: .white, size: .zero)
    n.blendMode = .add
    n.shader = shader(for: jellies[i])
    scene.addChild(n)
    jellies[i].node = n
}

/// Places every sprite for time t: its size from its depth, its pose, and the pulse and last turn its shader draws.
func place(_ t: Double) {
    time.floatValue = Float(t)
    for j in jellies {
        let k = pxPerMetre(j.z), rPx = j.d / 2 * k
        // A turn swings the far tentacles out sideways until the bend has run down them: widen the box to hold them.
        let (bw, above, below) = (j.sp.box.w + 2 * abs(sin(j.turn)) * j.sp.box.below, j.sp.box.above, j.sp.box.below)
        let n = j.node!
        n.size = CGSize(width: bw * rPx / 2, height: (above + below) * rPx / 2)
        n.anchorPoint = CGPoint(x: 0.5, y: below / (above + below))
        // A single jelly is followed at its mean pace, as a diver's camera would: its surge and coast show against the frame.
        let follow = cfg.single == true ? j.sp.perPulse * j.d / j.period * t : 0
        let h0 = cfg.heading ?? 0
        n.position = CGPoint(x: wPt / 2 + (j.x + sin(h0) * follow) * k / 2, y: hPt / 2 + (j.y - cos(h0) * follow) * k / 2)
        n.zRotation = CGFloat(j.heading)
        let z = j.z * 0.1 / ((j.sp.diameter.lowerBound + j.sp.diameter.upperBound) / 2) // depth as if all were 10 cm
        let fog = look.falloff ? 1.2 / (1 + pow(z / 0.45, 2)) * 1.6 : exp(-(z - 0.45) / 2.2)
        n.setValue(SKAttributeValue(vectorFloat4: [Float(bw), Float(above + below), Float(below), Float(1 / rPx)]), forAttribute: "a_box")
        n.setValue(SKAttributeValue(vectorFloat4: [Float(j.tilt), Float(j.seed), Float(fog), 0]), forAttribute: "a_pose")
        n.setValue(SKAttributeValue(vectorFloat4: [Float(j.t0), Float(j.period), Float(j.sp.contraction), Float(j.sp.relaxation)]), forAttribute: "a_pulse")
        n.setValue(SKAttributeValue(vectorFloat4: [Float(t - j.turnAt), Float(j.turn), 0, 0]), forAttribute: "a_turn")
        n.setValue(SKAttributeValue(vectorFloat4: [Float(j.glow), Float(j.kind == "atolla" ? t * 3.1 : j.glowFront), 0, 0]), forAttribute: "a_glow")
    }
}

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: W, height: H, mipmapped: false)
desc.usage = [.renderTarget, .shaderRead]
desc.storageMode = .shared
let target = device.makeTexture(descriptor: desc)!
let renderer = SKRenderer(device: device)
renderer.scene = scene

func render(at t: Double, to path: String) {
    advance(to: t * speed)
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
    for (i, t) in times.enumerated() { render(at: t, to: cfg.out + String(format: "-%03d.png", i)) }
} else if let frames = cfg.frames {
    let fps = cfg.fps ?? 30, start = cfg.t ?? 20
    for f in 0..<frames { render(at: start + Double(f) / fps, to: cfg.out + String(format: "-%04d.png", f)) }
} else {
    render(at: cfg.t ?? 20, to: cfg.out)
}
