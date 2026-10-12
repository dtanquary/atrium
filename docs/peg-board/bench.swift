// bench.swift: the peg board as ONE SKShader on a full-screen sprite, timed the way Atrium's render test times a
// wallpaper (SKRenderer offscreen, gpuEndTime - gpuStartTime, the last 30 of 60 frames), at three screen sizes.
// Not app code: a standalone check of the cost and of what SKShader will accept.
//   swiftc -O bench.swift -o bench && ./bench <out.png> [pitch in points, default 13.5]
import AppKit
import Metal
import SpriteKit

let source = """
vec4 hash42(vec2 p) {
    vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}
float bump(float x, float s) { return exp(-(x / s) * (x / s)); }
void main() {
    float S = 0.8660254;
    float R = 0.47;
    vec2 p = v_tex_coord * u_size;
    vec2 uv = vec2(p.x / u_pitch, p.y / (u_pitch * S));
    float j0 = floor(uv.y);
    float bd = 9.0;
    vec2 bo = vec2(0.0);
    vec2 bcell = vec2(0.0);
    vec4 bpeg = vec4(0.0);
    vec4 bh = vec4(0.0);
    float blit = 0.0;
    vec3 tight = vec3(0.0);
    vec2 mid = 0.5 * u_grid;
    for (float dj = 0.0; dj < 1.5; dj += 1.0) {
        float j = j0 + dj;
        float off = 0.5 * mod(j, 2.0);
        float i0 = floor(uv.x - off);
        for (float di = 0.0; di < 1.5; di += 1.0) {
            vec2 cell = vec2(i0 + di, j);
            vec4 h = hash42(cell);
            vec2 o = vec2(uv.x - cell.x - off, (uv.y - j) * S) - (h.xy - 0.5) * 0.11;
            float d = length(o);
            vec2 tc = (cell + 0.5) / u_grid;
            vec4 peg = texture2D(u_pegs, tc);
            vec4 w = texture2D(u_when, tc);
            float when = (w.r * 65280.0 + w.g * 255.0) * 0.01;
            float mode = 0.74 + 0.26 * cos(atan(cell.y - mid.y, cell.x + off - mid.x) - u_now * 0.157);
            float lit = peg.a * smoothstep(0.0, 1.0, u_now - when) * mode;
            vec3 c = peg.rgb * peg.rgb;
            tight += c * (lit * 0.009 * exp(-max(d - R, 0.0) / 0.16));
            if (d < bd) { bd = d; bo = o; bpeg = vec4(c, peg.a); bh = h; blit = lit; bcell = cell; }
        }
    }
    vec4 hl = texture2D(u_halo, vec2((uv.x * 2.0 + 0.5) / (2.0 * u_grid.x + 1.0), (uv.y + 0.5) / u_grid.y));
    float sweep = 0.74 + 0.26 * cos(atan(uv.y - mid.y, uv.x - mid.x) - u_now * 0.157);
    vec3 wide = hl.rgb * hl.rgb * 0.0625 * sweep;
    float r = bd / R;
    float px = 0.8 / (R * u_pitch * 2.0);
    float has = step(0.5, bpeg.a);
    vec2 hot = (bh.zw - 0.5) * 0.55 * R;
    float q = length(bo - hot) / R;
    float body = (0.40 + 0.12 * (1.0 - r * r)) * (1.0 - 0.45 * bump(r - 0.80, max(0.07, px)))
               + 0.75 * bump(r - 0.93, max(0.04, px)) + 0.10 * bump(r - 0.66, max(0.025, px));
    float hotgain = exp((fract(bh.x * 7.31 + bh.z * 3.17) - 0.5) * 2.6);
    float core = hotgain * u_bulb * (3.0 * bump(q, 0.16) + 0.35 * bump(q, 0.47));
    vec3 pc = bpeg.rgb;
    float top = max(pc.r, max(pc.g, pc.b));
    vec3 white = (0.5 * top + 0.5 * (pc.r + pc.g + pc.b) / 3.0) * vec3(1.0, 0.67, 0.35);
    float gain = exp((bh.y - 0.5) * 0.5);
    vec3 face = (pc * body + (0.35 * pc + 0.65 * white) * core) * (blit * gain) + 0.6 * wide;
    float cover = clamp((1.0 - r) * R * u_pitch * 2.0 / 1.2 + 0.5, 0.0, 1.0) * has;
    float dotp = clamp((0.21 - bd) / 0.05, 0.0, 1.0) * (1.0 - has);
    vec4 n = hash42(floor(p * 2.0));
    vec3 paper = (0.9 + 0.2 * n.x) * (u_room + wide + tight) * (1.0 + 2.2 * dotp);
    vec3 col = mix(paper, face, cover);
    col = 1.0 - exp(-col * u_expo);
    gl_FragColor = vec4(pow(col, vec3(0.4545)), 1.0);
}
"""

let lean = """
vec4 hash42(vec2 p) {
    vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}
float bump(float x, float s) { return exp(-(x / s) * (x / s)); }
void main() {
    float S = 0.8660254;
    float R = 0.47;
    vec2 p = v_tex_coord * u_size;
    vec2 uv = vec2(p.x / u_pitch, p.y / (u_pitch * S));
    float ja = floor(uv.y);
    float jb = ja + 1.0;
    float offa = 0.5 * mod(ja, 2.0);
    float offb = 0.5 - offa;
    float ia = floor(uv.x - offa + 0.5);
    float ib = floor(uv.x - offb + 0.5);
    vec2 oa = vec2(uv.x - ia - offa, (uv.y - ja) * S);
    vec2 ob = vec2(uv.x - ib - offb, (uv.y - jb) * S);
    float pick = step(dot(ob, ob), dot(oa, oa));
    vec2 cell = mix(vec2(ia, ja), vec2(ib, jb), pick);
    vec4 h = hash42(cell);
    vec2 o = mix(oa, ob, pick) - (h.xy - 0.5) * 0.11;
    float bd = length(o);
    vec2 tc = (cell + 0.5) / u_grid;
    vec4 peg = texture2D(u_pegs, tc);
    vec4 w = texture2D(u_when, tc);
    float when = (w.r * 65280.0 + w.g * 255.0) * 0.01;
    vec2 mid = 0.5 * u_grid;
    float sweep = 0.74 + 0.26 * cos(atan(uv.y - mid.y, uv.x - mid.x) - u_now * 0.157);
    float blit = peg.a * smoothstep(0.0, 1.0, u_now - when) * sweep;
    vec4 hl = texture2D(u_halo, (uv * 4.0 + 2.5) / (4.0 * u_grid));
    vec3 wide = hl.rgb * hl.rgb * 0.0625 * sweep;
    float r = bd / R;
    float px = 0.8 / (R * u_pitch * 2.0);
    float has = step(0.5, peg.a);
    vec2 hot = (h.zw - 0.5) * 0.55 * R;
    float q = length(o - hot) / R;
    float body = (0.40 + 0.12 * (1.0 - r * r)) * (1.0 - 0.45 * bump(r - 0.80, max(0.07, px)))
               + 0.75 * bump(r - 0.93, max(0.04, px)) + 0.10 * bump(r - 0.66, max(0.025, px));
    float hotgain = exp((fract(h.x * 7.31 + h.z * 3.17) - 0.5) * 2.6);
    float core = hotgain * u_bulb * (3.0 * bump(q, 0.16) + 0.35 * bump(q, 0.47));
    vec3 pc = peg.rgb * peg.rgb;
    float top = max(pc.r, max(pc.g, pc.b));
    vec3 white = (0.5 * top + 0.5 * (pc.r + pc.g + pc.b) / 3.0) * vec3(1.0, 0.67, 0.35);
    float gain = exp((h.y - 0.5) * 0.5);
    vec3 face = (pc * body + (0.35 * pc + 0.65 * white) * core) * (blit * gain) + 0.6 * wide;
    float cover = clamp((1.0 - r) * R * u_pitch * 2.0 / 1.2 + 0.5, 0.0, 1.0) * has;
    float dotp = clamp((0.21 - bd) / 0.05, 0.0, 1.0) * (1.0 - has);
    vec4 n = hash42(floor(p * 2.0));
    vec3 paper = (0.9 + 0.2 * n.x) * (u_room + wide) * (1.0 + 2.2 * dotp);
    vec3 col = mix(paper, face, cover);
    col = 1.0 - exp(-col * u_expo);
    gl_FragColor = vec4(pow(col, vec3(0.4545)), 1.0);
}
"""

let palette: [[Float]] = [[200, 25, 10], [205, 25, 75], [220, 95, 10], [205, 170, 20], [0, 195, 25], [5, 80, 190], [140, 45, 190], [235, 215, 180]]
func lin(_ v: Float) -> Float { let c = v / 255; return c <= 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4) }

/// The three small textures for a board of `cols` x `rows`: colours, times, and the glow blurred on the CPU.
func board(cols: Int, rows: Int, fill: Double, sub: Int) -> (pegs: Data, when: Data, halo: Data, hw: Int, hh: Int, blurMs: Double, stampMs: Double) {
    var pegs = [UInt8](repeating: 0, count: cols * rows * 4), when = [UInt8](repeating: 0, count: cols * rows * 4)
    let vs = sub == 2 ? 1 : sub, hw = sub * cols + (sub == 2 ? 1 : 0), hh = vs * rows      // texels: `sub` a pitch across, `vs` a row down
    var light = [Float](repeating: 0, count: hw * hh * 3)
    for j in 0..<rows { for i in 0..<cols {
        let x = Double(i) + 0.5 * Double(j & 1) - Double(cols) / 2, y = (Double(j) - Double(rows) / 2) * 0.866
        let f = sin(0.13 * x + 1) + sin(0.13 * (0.5 * x + 0.866 * y) + 2) + sin(0.13 * (-0.5 * x + 0.866 * y) + 4)
        let band = Int(floor((f + 3) / 6 * 14))
        guard fill >= 1 || band % 2 == 0 else { continue }
        let c = palette[(band / 2 + 5) % 8], k = (j * cols + i) * 4
        for n in 0..<3 { pegs[k + n] = UInt8(sqrt(lin(c[n])) * 255); light[((j * vs + vs / 2) * hw + sub * i + (sub / 2) * (j & 1) + (sub == 2 ? 0 : sub / 2)) * 3 + n] = lin(c[n]) }   // gamma 2 in the texture
        pegs[k + 3] = 255
        let t = Int(min(65535, (x * x + y * y).squareRoot() * 10))                                    // placed from the middle out, 0.01 s ticks
        when[k] = UInt8(t >> 8); when[k + 1] = UInt8(t & 255); when[k + 3] = 255
    } }
    // the wide glow: every lit peg's light spread by the measured kernel, on the half-pitch grid
    let ky = 8 * vs, kx = 7 * sub
    var ker = [Float](repeating: 0, count: (2 * ky + 1) * (2 * kx + 1))
    for a in -ky...ky { for b in -kx...kx {
        let dx = Double(b) / Double(sub), dy = Double(a) / Double(vs) * 0.866, d = (dx * dx + dy * dy).squareRoot()
        ker[(a + ky) * (2 * kx + 1) + b + kx] = Float(0.0017 * exp(-d / 0.5) + 0.00014 * exp(-d / 2.0) + (sub > 2 ? 0.009 * exp(-max(d - 0.47, 0) / 0.16) : 0))
    } }
    var glow = [Float](repeating: 0, count: hw * hh * 3)
    let t0 = CFAbsoluteTimeGetCurrent()
    var stamps = 0
    for j in 0..<hh { for i in 0..<hw {                                     // scatter: one stamp per lit peg
        let s = (j * hw + i) * 3
        guard light[s] + light[s + 1] + light[s + 2] > 0 else { continue }
        stamps += 1
        for a in max(-ky, -j)...min(ky, hh - 1 - j) { for b in max(-kx, -i)...min(kx, hw - 1 - i) {
            let w = ker[(a + ky) * (2 * kx + 1) + b + kx], o = ((j + a) * hw + i + b) * 3
            glow[o] += w * light[s]; glow[o + 1] += w * light[s + 1]; glow[o + 2] += w * light[s + 2]
        } }
    } }
    let blur = (CFAbsoluteTimeGetCurrent() - t0) * 1000
    var halo = [UInt8](repeating: 255, count: hw * hh * 4)
    for n in 0..<hw * hh { for c in 0..<3 { halo[n * 4 + c] = UInt8(min(255, (glow[n * 3 + c] * 16).squareRoot() * 255)) } }
    return (Data(pegs), Data(when), Data(halo), hw, hh, blur, blur / Double(max(stamps, 1)))
}

@MainActor func run() throws {
    let args = CommandLine.arguments
    let pitch = args.count > 2 ? Double(args[2])! : 13.5
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { fatalError("no Metal") }
    print("device:", device.name, " pitch:", pitch, "pt")
    for (label, wPt, hPt) in [("14-inch 3024x1964", 1512, 982), ("5K 5120x2880", 2560, 1440), ("6K 6016x3384", 3008, 1692)] {
        for (variant, sub, fill) in [("A: four holes read, half-pitch glow", 2, 0.5), ("A", 2, 1.0), ("B: nearest hole only, glow at 4 x 4 a hole", 4, 0.5)] {
            let size = CGSize(width: wPt, height: hPt), (w, h) = (wPt * 2, hPt * 2)
            let cols = Int(ceil(Double(wPt) / pitch)) + 2, rows = Int(ceil(Double(hPt) / (pitch * 0.866))) + 2
            let b = board(cols: cols, rows: rows, fill: fill, sub: sub)
            let tex = { (d: Data, tw: Int) -> SKTexture in let t = SKTexture(data: d, size: CGSize(width: tw, height: rows)); t.filteringMode = .nearest; return t }
            let haloTex = SKTexture(data: b.halo, size: CGSize(width: b.hw, height: b.hh)); haloTex.filteringMode = .linear
            let now = SKUniform(name: "u_now", float: 0)
            let scene = SKScene(size: size)
            let sprite = SKSpriteNode(color: .black, size: size)
            sprite.anchorPoint = .zero
            sprite.shader = SKShader(source: sub == 2 ? source : lean, uniforms: [
                SKUniform(name: "u_size", vectorFloat2: [Float(wPt), Float(hPt)]), SKUniform(name: "u_pitch", float: Float(pitch)),
                SKUniform(name: "u_grid", vectorFloat2: [Float(cols), Float(rows)]), SKUniform(name: "u_pegs", texture: tex(b.pegs, cols)),
                SKUniform(name: "u_when", texture: tex(b.when, cols)), SKUniform(name: "u_halo", texture: haloTex),
                SKUniform(name: "u_room", float: 0.0015), SKUniform(name: "u_expo", float: 1.8), SKUniform(name: "u_bulb", float: 0.35), now])
            scene.addChild(sprite)
            let renderer = SKRenderer(device: device)
            renderer.scene = scene
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead]; descriptor.storageMode = .shared
            guard let target = device.makeTexture(descriptor: descriptor) else { fatalError("no target") }
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = target; pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
            let clock = ProcessInfo.processInfo.systemUptime + 1
            var gpu = 0.0, cpu = 0.0
            for frame in 0..<60 {
                let start = CFAbsoluteTimeGetCurrent()
                now.floatValue = 30 + Float(frame) / 30
                renderer.update(atTime: clock + Double(frame) / 30)
                guard let buffer = queue.makeCommandBuffer() else { fatalError("no buffer") }
                renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
                buffer.commit(); buffer.waitUntilCompleted()
                if frame >= 30 { let g = buffer.gpuEndTime - buffer.gpuStartTime; gpu += g; cpu += CFAbsoluteTimeGetCurrent() - start - g }
            }
            print(String(format: "%@ | %@ | %d x %d holes (%d), %.0f%% filled: gpu %.2f ms, cpu %.2f ms a frame; glow %d x %d texels, blurred whole in %.1f ms on the CPU (%.4f ms a peg)",
                         label, variant, cols, rows, cols * rows, fill * 100, gpu / 30 * 1000, cpu / 30 * 1000, b.hw, b.hh, b.blurMs, b.stampMs))
            if wPt == 1512 && fill < 1 {                                    // a picture, to see that the shader draws what the Python does
                var px = [UInt8](repeating: 0, count: w * h * 4)
                target.getBytes(&px, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                           colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32)!
                for n in 0..<w * h { rep.bitmapData![n * 4] = px[n * 4 + 2]; rep.bitmapData![n * 4 + 1] = px[n * 4 + 1]; rep.bitmapData![n * 4 + 2] = px[n * 4]; rep.bitmapData![n * 4 + 3] = 255 }
                try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1].replacingOccurrences(of: ".png", with: sub == 2 ? "-A.png" : "-B.png")))
            }
        }
    }
}
try MainActor.assumeIsolated { try run() }
