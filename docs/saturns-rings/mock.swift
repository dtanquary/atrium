// Saturn's Rings mock-ups, drawn by SpriteKit's SKRenderer as the app's render test draws a wallpaper, so a tile shows
// what the app's shader can draw. Not app code, but the shader here (the ring plane and the planet in one pass, the
// rings' light from a single-scattering slab, the radial pyramid that filters the bands, the two shadows, ringshine,
// the moons' ripples) is meant to carry into the build: see research-method.md.
//
//   swiftc -O "$PWD/mock.swift" -o $TMPDIR/saturn-mock && $TMPDIR/saturn-mock '<json>'   (the full path: it finds profile.tsv by it)
//
// It reads profile.tsv beside this file (made by profile.py). The JSON: view (A to E, below), or any of r, h (Mm),
// yaw, pitch, fov (degrees) to override it; sunEl (degrees above the ring plane, negative south; today -8.4) and sunAz
// (degrees round the planet from the camera); face (lit or unlit); palette (sunlit, ringlight, golden, backlit);
// ripple (pan, daphnis or none), amp (times its real size), moonAhead (Mm ahead of the camera), spokes (0 to 1);
// exposure (left out, it puts the brightest real thing in frame, the lit B ring's brightest bands or the planet's
// lit limb, at a 99.9th of 190 with the 99th at most 170, and lets the median fall where it falls); t (s), width and
// height (points, drawn at 2x), out (a .png). planetCap (standard on for the unlit face) holds the planet's own exposure
// at the most that keeps its lit face buttercream, so the dimmer rings set the exposure; flatAlbedo draws the rings from
// tau alone, for comparison. It prints the frame's luma median, 99th, 99.9th, max and the exposure.
import Foundation
import Metal
import SpriteKit

struct Config: Decodable {
    var view: String?
    var r: Double?, h: Double?, yaw: Double?, pitch: Double?, fov: Double?
    var sunEl: Double?, sunAz: Double?
    var face: String?, palette: String?
    var ripple: String?, amp: Double?, moonAhead: Double?, spokes: Double?
    var exposure: Double?, t: Double?
    var planetCap: Bool?, flatAlbedo: Bool?
    var width: Double?, height: Double?
    var out: String
}
let cfg = try! JSONDecoder().decode(Config.self, from: CommandLine.arguments[1].data(using: .utf8)!)

// MARK: The views. Mm, Saturn at the origin, ring plane z = 0, the camera at +x. yaw: 0 looks straight in at Saturn,
// 90 along the orbit. pitch: down from level.
struct View { var r: Double, h: Double, yaw: Double, pitch: Double, fov: Double }
let views: [String: View] = [
    "A": View(r: 150, h: 12, yaw: 0, pitch: 24, fov: 74),      // looking in, the planet rising
    "B": View(r: 126, h: 4, yaw: 55, pitch: 9, fov: 70),       // along the rings to the horizon
    "C": View(r: 126, h: 4, yaw: 38, pitch: 7, fov: 70),       // along the rings, the planet's limb rising at one side
    "D": View(r: 112, h: 40, yaw: 10, pitch: 38, fov: 66),     // from above
    "E": View(r: 134.4, h: 1.6, yaw: 86, pitch: 17, fov: 60),  // low over the Encke gap, 1-2 km a pixel near the bottom
]
var view = views[cfg.view ?? "A"]!
view.r = cfg.r ?? view.r; view.h = cfg.h ?? view.h; view.yaw = cfg.yaw ?? view.yaw
view.pitch = cfg.pitch ?? view.pitch; view.fov = cfg.fov ?? view.fov

// MARK: The profile: tau and the particles' brightness every 8 km (profile.tsv)
let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let lines = try! String(contentsOf: here.appendingPathComponent("profile.tsv"), encoding: .utf8)
    .split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("#") }
let prof = lines.map { $0.split(separator: "\t").map { Double($0)! } }
let N = prof.count, start = prof[0][0] / 1000, step = (prof[1][0] - prof[0][0]) / 1000 // Mm
let tau = prof.map { $0[1] }, albedo = cfg.flatAlbedo == true ? prof.map { _ in 0.28 } : prof.map { $0[2] }

// The radial pyramid (research-method.md §4): row (j, m) holds, for each texel, the mean of exp(-tau 2^j) over a box
// 2^m texels wide centred on it (two bytes, red and green), and the mean brightness over the same box (blue, 0.5 = 255).
let K = 12, levels = 13
var pyr = [UInt8](repeating: 255, count: N * K * levels * 4)
func prefix(_ g: [Double]) -> [Double] { var p = [0.0]; for x in g { p.append(p.last! + x) }; return p }
func boxMean(_ pre: [Double], _ i: Int, _ half: Double, outside: Double) -> Double {
    func at(_ x: Double) -> Double {
        if x <= 0 { return x * outside }
        if x >= Double(N) { return pre[N] + (x - Double(N)) * outside }
        let i0 = Int(x); return pre[i0] + (x - Double(i0)) * (pre[min(i0 + 1, N)] - pre[i0])
    }
    let a = Double(i) + 0.5 - half, b = Double(i) + 0.5 + half
    return (at(b) - at(a)) / (b - a)
}
let albPre = prefix(albedo)
for j in 0..<K {
    let pre = prefix(tau.map { exp(-$0 * pow(2, Double(j))) })
    for m in 0..<levels {
        let half = Double(1 << m) / 2
        for i in 0..<N {
            let v = Int(min(max(boxMean(pre, i, half, outside: 1), 0), 1) * 65535)
            let a = min(max(boxMean(albPre, i, half, outside: 0.2), 0), 0.5) / 0.5 * 255
            let o = ((j * levels + m) * N + i) * 4
            pyr[o] = UInt8(v >> 8); pyr[o + 1] = UInt8(v & 255); pyr[o + 2] = UInt8(a)
        }
    }
}
let table = SKTexture(data: Data(pyr), size: CGSize(width: N, height: K * levels))

// MARK: Palettes (research-look.md): five stops dark to light, each from one Cassini photograph's ring pixels.
func hex(_ s: String) -> SIMD3<Float> {
    let v = Int(s, radix: 16)!; return SIMD3(Float(v >> 16 & 255), Float(v >> 8 & 255), Float(v & 255)) / 255
}
let palettes: [String: [String]] = [
    "sunlit": ["1f1d24", "8a827f", "968e8d", "cebdb0", "e3d3c8"],     // PIA06485, lit face
    "ringlight": ["140c0a", "503f31", "695442", "9a7d67", "f2cfa2"],  // PIA09860, unlit face from 5 degrees
    "golden": ["1d0a03", "362217", "533d29", "a48860", "ddbd84"],     // PIA08304, unlit face at high phase
    "backlit": ["171517", "39352c", "514c41", "746f5e", "d5d5d6"],    // PIA17172
]
let face = cfg.face ?? "lit"
let ramp = (palettes[cfg.palette ?? (face == "lit" ? "sunlit" : "ringlight")]!).map(hex)

// MARK: The shader
func mean(_ v: String, _ u: String, _ w: String, _ k: String) -> String {
    "vec4 \(v)At = pyrAt(\(u), \(w), \(k)); vec4 \(v)0 = texture2D(u_table, \(v)At.xy); vec4 \(v)1 = texture2D(u_table, \(v)At.xz); float \(v) = mix(pyrOf(\(v)0), pyrOf(\(v)1), \(v)At.w); float \(v)Alb = \(v)0.b * 0.5;"
}
let rows = Double(K * levels)
let source = """
float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
vec4 hash42(vec2 p) {
    vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}
// Faint sparse stars, display values: luma 30 at most (the look report's cap).
float stars(vec2 pts) {
    vec4 r = hash42(floor(pts / 7.0));
    if (r.x > 0.05) { return 0.0; }
    vec2 off = (r.yz - 0.5) * 0.6;
    float d = length(fract(pts / 7.0) - 0.5 - off) * 7.0;
    return smoothstep(0.9, 0.0, d) * (0.25 + 0.75 * pow(r.w, 4.0)) * 30.0 / 255.0;
}
// Where the pyramid keeps the mean of exp(-tau k) over a box 2w texels wide, in the two rows of k round k.
vec4 pyrAt(float u, float w, float k) {
    float m = clamp(log2(2.0 * w), 0.0, 11.999), j = clamp(log2(max(k, 1.0)), 0.0, 10.999), j0 = floor(j);
    return vec4((u + 0.0) / \(Double(N)), (j0 * 13.0 + m + 0.5) / \(rows), ((j0 + 1.0) * 13.0 + m + 0.5) / \(rows), j - j0);
}
float pyrOf(vec4 t) { return t.r * (255.0 * 256.0 / 65535.0) + t.g * (255.0 / 65535.0); }
vec3 rampAt(float t, vec3 c0, vec3 c1, vec3 c2, vec3 c3, vec3 c4) {
    float x = clamp(t, 0.0, 1.0) * 4.0;
    vec3 c = mix(c0, c1, clamp(x, 0.0, 1.0));
    c = mix(c, c2, clamp(x - 1.0, 0.0, 1.0));
    c = mix(c, c3, clamp(x - 2.0, 0.0, 1.0));
    return mix(c, c4, clamp(x - 3.0, 0.0, 1.0));
}
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

void main() {
    vec2 ndc = (v_tex_coord - 0.5) * 2.0;
    vec3 d = normalize(u_rot * vec3(ndc.x * u_lens.x, ndc.y * u_lens.y, 1.0));
    vec3 c = u_cam, s = u_sun;
    float req = 60.268, k = 60.268 / 54.364;

    // the ring plane, and the moon's ripple: a shift of radius (and a squeeze of the streamlines) downstream of it
    float tr = -c.z / d.z;
    vec3 p = c + tr * d;
    float r = length(p.xy);
    float crowd = 1.0, tilt = 0.0, gap = 1.0;
    float dr = (r - u_moon.x) * 1000.0;                                   // km from the moon's orbit
    float edge = u_moon.z;                                                // km from the moon to the gap's edge
    if (u_moon.w > 0.0 && abs(dr) > edge && abs(dr) < 60.0 * edge) {
        float phi = atan(p.y, p.x) - u_moon.y;
        float down = mod(-sign(dr) * phi, 6.2831853);                     // radians downstream of the moon
        float lambda = 9.424778 * abs(dr);                                // 3 pi |dr| (Showalter et al. 1986)
        float theta = 6.2831853 * down * u_moon.x * 1000.0 / lambda;      // the wake's phase
        float a = u_moon.w * pow(edge / abs(dr), 2.0) * exp(-theta / 25.0);
        r -= a * sin(theta) / 1000.0;
        crowd = clamp(1.0 + a * cos(theta) * theta / abs(dr), 0.5, 2.0);
        // Daphnis's edge waves stand up out of the plane: their slope turns each crest toward or away from the Sun
        float rise = u_wave * exp(-(abs(dr) - edge) / 8.0) * exp(-theta / 25.0);
        vec2 along = normalize(vec2(-p.y, p.x)) * -sign(dr);
        tilt = rise * 6.2831853 / lambda * cos(theta) * dot(normalize(s.xy), along);
    }
    float u = (r - \(start)) / \(step);
    float w = max(0.5 * length(vec2(dfdx(u), dfdy(u))), 0.5);
    // The moon's gap, drawn sharp from its own edges rather than the 8 km profile: real gap edges are sharper than any
    // camera has resolved (research-look.md). Antialiased over the pixel's footprint in km.
    if (u_moon.w > 0.0) {
        float off = abs(r - u_moon.x) * 1000.0, fw = max(0.5 * length(vec2(dfdx(r), dfdy(r))) * 1000.0, 0.01);
        gap = smoothstep(edge - fw, edge + fw, off);
    }

    // the planet: an oblate spheroid, a sphere once z is stretched by k
    vec3 cs = vec3(c.xy, c.z * k), ds = vec3(d.xy, d.z * k);
    float A = dot(ds, ds), B = dot(cs, ds), C = dot(cs, cs) - req * req;
    float disc = B * B - A * C;
    float tp = disc > 0.0 ? (-B - sqrt(disc)) / A : 1e9;

    // the moon itself, a small grey ball in its gap
    vec3 mc = vec3(cos(u_moon.y), sin(u_moon.y), 0.0) * u_moon.x;
    vec3 oc = c - mc;
    float mb = dot(oc, d), mdisc = mb * mb - dot(oc, oc) + u_moonSize * u_moonSize;
    float tm = (u_moon.w > 0.0 && mdisc > 0.0) ? -mb - sqrt(mdisc) : 1e9;

    vec3 lin = vec3(0.0);   // light, before exposure: planet and rings in I/F
    float sky = 1.0;        // how much of the sky shows
    float planet = 0.0;     // how much of the pixel is planet, for its own colours
    vec3 planetLin = vec3(0.0);
    if (tp < 1e8) {
        vec3 h = c + tp * d;
        vec3 n = normalize(vec3(h.xy, h.z * k * k));
        float lat = asin(clamp(n.z, -1.0, 1.0));
        float mu0p = max(dot(n, s), 0.0), mup = max(-dot(n, d), 0.02);
        // buttercream belts and zones, the south a paler gold (PIA06193, PIA11141, PIA11478)
        float band = 0.5 + 0.5 * sin(lat * 23.0 + 0.7 * sin(lat * 9.0)) * (0.6 + 0.4 * sin(lat * 5.0 + 1.0));
        vec3 col = mix(vec3(0.66, 0.59, 0.44), vec3(0.82, 0.73, 0.59), band);
        col = mix(col, vec3(0.88, 0.79, 0.51), 0.25 * smoothstep(0.1, -0.6, lat));
        col = pow(col, vec3(2.2)); // the photographs' display colours, in linear light
        float ts = -h.z / s.z;
        float rq = length((h + ts * s).xy);
        float uq = (rq - \(start)) / \(step);
        float wq = max(0.5 * length(vec2(dfdx(uq), dfdy(uq))), 0.5);
        \(mean("eq", "uq", "wq", "1.0 / abs(s.z)"))
        float through = ts > 0.0 ? eq : 1.0;
        float lit = 0.42 * pow(mu0p, 0.9) * pow(mup, -0.1) * through;
        // ringshine: the rings' lit face lights the hemisphere on its side, their unlit face the other, dimmer
        float side = n.z * sign(s.z);
        float shine = 0.42 * 0.012 * (smoothstep(-0.2, 0.7, side) + 0.35 * smoothstep(-0.2, 0.7, -side));
        planetLin = col / luma(col) * lit + vec3(2.25, 0.714, 0.148) * shine; // #372110 in linear light, luma 1
        lin = planetLin * u_planetExposure;
        planet = 1.0;
        sky = 0.0;
    }
    float ringT = 1.0;
    float t = 0.0;
    if (tr > 0.0 && tr < tp && r > 72.2 && r < 141.9) {
        float mu = max(abs(d.z), 1e-4), mu0 = max(abs(s.z) + tilt, 2e-3);
        float kv = 1.0 / mu, ks = 1.0 / mu0;
        \(mean("eView", "u", "w", "kv * crowd"))
        float light = 0.0;
        if (c.z * s.z > 0.0) {
            \(mean("eBoth", "u", "w", "(kv + ks) * crowd"))
            light = eViewAlb * (1.0 - eBoth) * mu0 / (mu + mu0);
            t = light / (0.28 * mu0 / (mu + mu0));
        } else {
            float k2 = abs(kv - ks) < 0.1 * ks ? ks * 1.1 : kv;
            \(mean("eSun", "u", "w", "ks * crowd"))
            \(mean("eK2", "u", "w", "k2 * crowd"))
            light = eViewAlb * (eSun - eK2) / (mu * (k2 - ks));
            // the most an unlit slab can pass at this angle, at tau = ln(k2/ks) / (k2 - ks)
            float best = log(k2 / ks) / (k2 - ks);
            t = light / (0.28 * (exp(-best * ks) - exp(-best * k2)) / (mu * (k2 - ks)));
        }
        // the planet's shadow: does the way to the Sun meet the spheroid? Soft over the Sun's width.
        vec3 ps = vec3(p.xy, 0.0), ss = normalize(vec3(s.xy, s.z * k));
        float b = dot(ps, ss);
        float miss = sqrt(max(dot(ps, ps) - b * b, 0.0));
        float sunlit = b < 0.0 ? smoothstep(req - 0.02 + b * 0.0005, req + 0.02 - b * 0.0005, miss) : 1.0;
        // spokes: faint radial smudges over the B ring, sheared a little by its orbits (dark at low phase)
        float spoke = 0.0;
        float az = atan(p.y, p.x);
        for (int i = 0; i < 5; i++) {
            float fi = float(i);
            float at = -0.3 + 0.13 * fi + 0.02 * sin(fi * 7.0) + (r - 112.0) / 112.0 * (0.4 + 0.3 * fi);
            spoke += exp(-pow((az - at) / (0.012 + 0.009 * fract(fi * 0.37)), 2.0)) * (0.6 + 0.4 * fract(fi * 0.61));
        }
        spoke *= smoothstep(99.0, 104.0, r) * smoothstep(117.0, 113.0, r) * u_spokes;
        light *= 1.0 - 0.25 * min(spoke, 1.0);
        // the rings take the palette's colour at their brightness against a saturated B ring's
        vec3 hueLin = pow(rampAt(t * 0.95, u_c0, u_c1, u_c2, u_c3, u_c4), vec3(2.2));
        eView = mix(1.0, eView, gap);
        lin = lin * eView + hueLin / max(luma(hueLin), 1e-4) * light * sunlit * gap * u_exposure;
        ringT = eView;
        t *= sunlit;
        sky *= eView;
        planet *= eView;
    }
    if (tm < min(tp, tr > 0.0 ? tr : 1e9)) {
        vec3 n = normalize(c + tm * d - mc);
        lin = vec3(0.12 * max(dot(n, s), 0.0) + 0.002) * u_planetExposure; // a dark icy moonlet, about as bright as the A ring
        sky = 0.0; planet = 0.0;
    }

    // exposure and a knee that stays nearly straight to luma 185 (Cassini's contrast kept) and never passes 214
    vec3 col = pow(lin / sqrt(sqrt(1.0 + pow(lin / 0.68, vec3(4.0)))), vec3(0.4545));
    // the sky: near-black (luma 4-8) and faint stars, both behind whatever the rings let through
    col += (6.0 / 255.0 + stars(v_tex_coord * u_size)) * sky;
    col += 3.0 / 255.0 * (1.0 - sky);
    col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 255.0;
    gl_FragColor = vec4(col, 1.0);
}
"""

// MARK: The scene
let wPt = cfg.width ?? 1512, hPt = cfg.height ?? 982
let W = Int(wPt * 2), H = Int(hPt * 2)
let face1 = face == "lit" ? 1.0 : -1.0
let sunEl = (cfg.sunEl ?? -8.4) * .pi / 180
let camZ = (sunEl < 0 ? -1.0 : 1.0) * face1 * view.h
let cam = SIMD3<Double>(view.r, 0, camZ)
let yaw = view.yaw * .pi / 180, pitch = view.pitch * .pi / 180
var f = cos(yaw) * SIMD3<Double>(-1, 0, 0) + sin(yaw) * SIMD3<Double>(0, 1, 0)
f = simd_normalize(cos(pitch) * f + sin(pitch) * SIMD3(0, 0, camZ > 0 ? -1 : 1))
let right = simd_normalize(simd_cross(f, SIMD3(0, 0, camZ > 0 ? 1 : -1))), up = simd_cross(right, f)
let az = (cfg.sunAz ?? 140) * .pi / 180
let sun = SIMD3<Float>(Float(cos(sunEl) * cos(az)), Float(cos(sunEl) * sin(az)), Float(sin(sunEl)))
let tx = tan(view.fov / 2 * .pi / 180)

// The moon: Pan in the Encke gap or Daphnis in the Keeler gap, `moonAhead` Mm ahead of the camera along its orbit.
// Edge amplitudes are worked out, not measured (unchecked): a streamline at distance x from a moon of mass ratio mu is
// forced to a e = 2.24 mu a (a/x)^2 (Julian & Toomre), with Pan 4.95e15 kg and Daphnis 7.7e13 kg (masses unchecked):
// about 1.8 km at the Encke gap's edges and 2.5 km at the Keeler gap's. Daphnis's waves stand 0.5-1.5 km tall (PIA11654).
let ripple = cfg.ripple ?? "none", amp = cfg.amp ?? 1
let moons: [String: (a: Double, edge: Double, size: Double, radial: Double, rise: Double)] = [
    "pan": (133.584, 161, 0.014, 1.8, 0), "daphnis": (136.504, 17.5, 0.0038, 2.5, 1.0),
]
let moon = moons[ripple]
let ahead = (cfg.moonAhead ?? 8) / (moon?.a ?? 1)
let uMoon = SKUniform(name: "u_moon", vectorFloat4: moon.map { [Float($0.a), Float(ahead), Float($0.edge), Float($0.radial * amp)] } ?? [0, 0, 1, 0])

let device = MTLCreateSystemDefaultDevice()!, queue = device.makeCommandQueue()!
let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: W, height: H, mipmapped: false)
desc.usage = [.renderTarget, .shaderRead]; desc.storageMode = .shared
let target = device.makeTexture(descriptor: desc)!
let uExposure = SKUniform(name: "u_exposure", float: 1), uPlanetExposure = SKUniform(name: "u_planetExposure", float: 1)
// the planet's lit face at its brightest (I/F 0.42, face on) lands at luma about 195, #d1bb97's zone
let planetCap = (cfg.planetCap ?? (face == "unlit")) ? 1.52 : Double.infinity
func expose(_ e: Double) { uExposure.floatValue = Float(e); uPlanetExposure.floatValue = Float(min(e, planetCap)) }
let shader = SKShader(source: source, uniforms: [
    SKUniform(name: "u_table", texture: table), SKUniform(name: "u_cam", vectorFloat3: SIMD3<Float>(cam)),
    SKUniform(name: "u_rot", matrixFloat3x3: matrix_float3x3(columns: (SIMD3<Float>(right), SIMD3<Float>(up), SIMD3<Float>(f)))),
    SKUniform(name: "u_sun", vectorFloat3: sun), SKUniform(name: "u_lens", vectorFloat2: [Float(tx), Float(tx * hPt / wPt)]),
    SKUniform(name: "u_size", vectorFloat2: [Float(wPt), Float(hPt)]), uExposure, uPlanetExposure, uMoon,
    SKUniform(name: "u_moonSize", float: Float(moon?.size ?? 0)), SKUniform(name: "u_wave", float: Float((moon?.rise ?? 0) * amp)),
    SKUniform(name: "u_spokes", float: Float(cfg.spokes ?? 0)),
] + ramp.enumerated().map { SKUniform(name: "u_c\($0.offset)", vectorFloat3: $0.element) })
let scene = SKScene(size: CGSize(width: wPt, height: hPt))
let node = SKSpriteNode(color: .black, size: scene.size)
node.position = CGPoint(x: wPt / 2, y: hPt / 2); node.shader = shader
scene.addChild(node)
let renderer = SKRenderer(device: device)
renderer.scene = scene

func render() -> [UInt8] {
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target; pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
    renderer.update(atTime: cfg.t ?? 0)
    let buf = queue.makeCommandBuffer()!
    renderer.render(withViewport: CGRect(x: 0, y: 0, width: W, height: H), commandBuffer: buf, renderPassDescriptor: pass)
    buf.commit(); buf.waitUntilCompleted()
    var px = [UInt8](repeating: 0, count: W * H * 4)
    target.getBytes(&px, bytesPerRow: W * 4, from: MTLRegionMake2D(0, 0, W, H), mipmapLevel: 0)
    return px
}
/// Luma (Rec. 709 of the 8-bit values, as the look report measured) at the median, 99th, 99.9th and max.
func stats(_ px: [UInt8]) -> [Int] {
    var hist = [Int](repeating: 0, count: 256)
    for i in stride(from: 0, to: px.count, by: 4) {
        hist[min(255, Int((0.0722 * Double(px[i]) + 0.7152 * Double(px[i + 1]) + 0.2126 * Double(px[i + 2])).rounded()))] += 1
    }
    let n = px.count / 4
    func pct(_ p: Double) -> Int { var s = 0; for (v, c) in hist.enumerated() { s += c; if Double(s) >= p * Double(n) { return v } }; return 255 }
    return [pct(0.5), pct(0.99), pct(0.999), hist.lastIndex { $0 > 0 }!]
}

var px: [UInt8]
var exposure = cfg.exposure ?? 1
if cfg.exposure == nil {
    // the brightest exposure that keeps the caps: bisect on its log
    var lo = log(0.05), hi = log(400.0)
    for _ in 0..<14 {
        let mid = (lo + hi) / 2
        expose(exp(mid))
        let s = stats(render())
        if s[1] <= 170 && s[2] <= 190 { lo = mid } else { hi = mid }
    }
    exposure = exp(lo)
}
expose(exposure)
px = render()
let s = stats(px)
print(String(format: "{\"median\": %d, \"p99\": %d, \"p999\": %d, \"max\": %d, \"exposure\": %.3f}", s[0], s[1], s[2], s[3], exposure))
let ctx = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: cfg.out) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
