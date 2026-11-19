// Beehive method probe: what a comb shader and three ways of drawing bees cost at 3024 x 1964 (a 14-inch display at
// 2x), drawn by SKRenderer as the render test draws a wallpaper. Throwaway; not app code.
//   swiftc -O docs/beehive/probe.swift -o $TMPDIR/beehive-probe-bin && $TMPDIR/beehive-probe-bin <mode> [bees] [walking share] [png]
// Modes: empty, nebula (calibration), comb (drawn every frame), kept (in a rasterised SKEffectNode), sprites (one a
// bee, over the kept comb), keptbees (still bees in a second kept node), jointed (a body and 17 leg sprites, Ant
// Colony's way), shaderbees (every bee drawn by one full-screen shader from a data texture). The comb map here is a
// placeholder and upside down (a data texture's row 0 is the bottom); only the cost is meant.
// GPU is the command buffer's own time; CPU is the frame's wall time on the main thread up to commit (the scene's
// update, the bees' step and SpriteKit's encoding); "render test's way" is the wall time to the GPU's finish less the
// GPU's time, as RenderTests.swift counts it, which carries a floor of 0.3 to 0.5 ms. Medians of 90 frames after 30.
import AppKit
import Metal
import SpriteKit

setvbuf(stdout, nil, _IONBF, 0)
let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "comb"
let beeCount = args.count > 2 ? Int(args[2])! : 300
let movingShare = args.count > 3 ? Double(args[3])! : 0.3
let png = args.count > 4 ? args[4] : nil
let (W, H) = (3024, 1964)
let size = CGSize(width: 1512, height: 982)
let repo = "/Users/dave/Development/atrium"

// MARK: the comb

// Pointy-topped hexagons (rows level, two walls upright, as in a natural comb), 14 points across the flats: a worker
// bee 12 mm long is then about 31 points, two and a bit cells.
let cellPts: Float = 14
let cols = Int(Float(size.width) / cellPts) + 2, rows = Int(Float(size.height) / (cellPts * 0.866)) + 2
/// One texel a cell: when it is drawn out (16 bits, a share of the day's building), when it fills, when it is capped.
func combMap() -> SKTexture {
    var out = [UInt8](repeating: 0, count: cols * rows * 4)
    for r in 0..<rows { for c in 0..<cols {
        // the comb grows down from the top bar as a tongue: drawn earlier near the top and middle
        let x = (Double(c) / Double(cols) - 0.5) * 2, y = Double(r) / Double(rows)
        let rank = min(1, max(0, 0.75 * (y + 0.6 * x * x) + 0.05 * sin(Double(c * 7 + r * 13))))
        let v = UInt16(rank * 65535)
        let i = (r * cols + c) * 4
        out[i] = UInt8(v >> 8); out[i + 1] = UInt8(v & 255)
        out[i + 2] = UInt8(min(255, rank * 255 + 40)); out[i + 3] = UInt8(min(255, rank * 255 + 90))
    } }
    let t = SKTexture(data: Data(out), size: CGSize(width: cols, height: rows))
    t.filteringMode = .nearest
    return t
}
let combSource = """
float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}
void main() {
    vec2 pts = v_tex_coord * u_size;
    // the nearest cell centre on a pointy-topped grid, by cube rounding
    float s = u_cell / 1.7320508; // a side's length
    vec2 q = vec2((pts.x * 0.5773503 - pts.y / 3.0) / s, (pts.y * 2.0 / 3.0) / s);
    vec3 cube = vec3(q.x, q.y, -q.x - q.y);
    vec3 rc = floor(cube + 0.5);
    vec3 d = abs(rc - cube);
    if (d.x > d.y && d.x > d.z) { rc.x = -rc.y - rc.z; } else if (d.y > d.z) { rc.y = -rc.x - rc.z; } else { rc.z = -rc.x - rc.y; }
    vec2 centre = vec2(s * 1.7320508 * (rc.x + rc.y * 0.5), s * 1.5 * rc.y);
    vec2 o = pts - centre;
    // distance in from the wall's middle line (0 at the wall, 1 at the centre), from the hexagon's three axes
    vec2 a = abs(o);
    float edge = max(a.x, dot(a, vec2(0.5, 0.8660254)));
    float inward = 1.0 - edge / (u_cell * 0.5);
    float row = rc.y; float col = rc.x + floor(rc.y * 0.5);
    vec4 m = texture2D(u_map, (vec2(col, row) + 0.5) / u_cells);
    float rank = m.r + m.g / 255.0;
    float drawn = smoothstep(rank, rank + 0.02, u_built);          // the wall's height, 0 to 1, as the cell is drawn out
    float filled = clamp((u_built - m.b) * 6.0, 0.0, 1.0);
    float capped = step(m.a, u_built);
    // wax: the rim is lit, the wall falls into shadow toward the base, the base is three rhombi lit apart
    float grain = noise(pts * 0.35) * 0.5 + noise(pts * 1.3) * 0.25;
    float wall = smoothstep(0.10, 0.0, inward) ;
    float depth = smoothstep(0.08, 0.6, inward);
    float facet = 0.85 + 0.15 * sin(3.0 * atan(o.y, o.x));
    vec3 wax = vec3(0.86, 0.66, 0.30) * (0.9 + 0.2 * grain);
    vec3 col3 = mix(wax * 1.15, wax * (0.35 + 0.25 * facet) * (1.0 - 0.5 * depth * drawn), 1.0 - wall);
    // nectar and honey: an amber pool whose meniscus catches a highlight above the centre
    vec2 hl = o / (u_cell * 0.5) - vec2(-0.25, 0.3);
    float sheen = exp(-dot(hl, hl) * 9.0) * filled;
    vec3 honey = vec3(0.75, 0.40, 0.06) * (0.55 + 0.45 * inward) + sheen * vec3(1.0, 0.9, 0.6);
    col3 = mix(col3, honey, filled * (1.0 - wall) * 0.9);
    // the cap: a dry, white-ish wax dome
    vec3 cap = vec3(0.93, 0.85, 0.66) * (0.8 + 0.25 * inward + 0.1 * grain);
    col3 = mix(col3, cap, capped * (1.0 - wall * 0.5));
    // beyond the comb's edge: the hive's dim back wall
    vec3 back = vec3(0.10, 0.07, 0.04) * (0.8 + 0.4 * grain);
    gl_FragColor = vec4(mix(back, col3, drawn) * u_light, 1.0);
}
"""

// MARK: Nebula, for calibration: its shader as the app has it, read from Shaders.swift

func nebulaSource() -> String {
    let text = try! String(contentsOfFile: repo + "/Sources/Atrium/Shaders.swift", encoding: .utf8)
    let common = text.components(separatedBy: "let shaderCommon = \"\"\"\n")[1].components(separatedBy: "\"\"\"")[0]
    let body = text.components(separatedBy: "source: shaderCommon + \"\"\"\n")[1].components(separatedBy: "\"\"\", uniforms: cycle")[0]
    return common + body
}
func nebulaUniforms() -> [SKUniform] {
    var u: [SKUniform] = [SKUniform(name: "u_size", vectorFloat2: [1512, 982]), SKUniform(name: "u_now", float: 100), SKUniform(name: "u_mix", float: 0)]
    for s in ["", "2"] {
        u += [SKUniform(name: "u_seed" + s, vectorFloat2: [31, 47]), SKUniform(name: "u_zoom" + s, float: 1.5), SKUniform(name: "u_band" + s, vectorFloat3: [0.5, 0.1, 0.3])]
        u += ["u_base", "u_dense", "u_accent", "u_hot"].map { SKUniform(name: $0 + s, vectorFloat3: [0.7, 0.4, 0.2]) }
    }
    u += [("u_every", 8), ("u_brightness", 1), ("u_contrast", 1), ("u_saturation", 1), ("u_hue", 0), ("u_detail", 0)].map { SKUniform(name: $0.0, float: Float($0.1)) }
    return u
}

// MARK: bees

/// A worker seen from above, painted at 2x: four poses of the legs, side by side, each 72 x 40 pixels (36 x 20 points).
func beeAtlas() -> SKTexture {
    let (fw, fh) = (72, 40)
    let ctx = CGContext(data: nil, width: fw * 4, height: fh, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    for f in 0..<4 {
        let x0 = CGFloat(f * fw), cy = CGFloat(fh) / 2
        ctx.setStrokeColor(CGColor(red: 0.12, green: 0.08, blue: 0.04, alpha: 1)); ctx.setLineWidth(1.6)
        for (i, lx) in [CGFloat(30), 38, 44].enumerated() {
            let swing = CGFloat(((f + i) % 2 == 0) ? 4 : -4)
            for side in [CGFloat(-1), 1] {
                ctx.move(to: CGPoint(x: x0 + lx, y: cy)); ctx.addLine(to: CGPoint(x: x0 + lx - 6 + swing * side, y: cy + side * 15)); ctx.strokePath()
            }
        }
        ctx.setFillColor(CGColor(red: 0.55, green: 0.36, blue: 0.12, alpha: 1)) // abdomen, tail to the left
        ctx.fillEllipse(in: CGRect(x: x0 + 6, y: cy - 8, width: 30, height: 16))
        ctx.setFillColor(CGColor(red: 0.16, green: 0.10, blue: 0.05, alpha: 1))
        for b in [CGFloat(11), 18, 25] { ctx.fill(CGRect(x: x0 + b, y: cy - 7, width: 3, height: 14)) }
        ctx.setFillColor(CGColor(red: 0.42, green: 0.30, blue: 0.14, alpha: 1)) // thorax, furred
        ctx.fillEllipse(in: CGRect(x: x0 + 34, y: cy - 7, width: 15, height: 14))
        ctx.setFillColor(CGColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 1)) // head
        ctx.fillEllipse(in: CGRect(x: x0 + 48, y: cy - 5, width: 10, height: 10))
        ctx.setFillColor(CGColor(red: 0.85, green: 0.88, blue: 0.9, alpha: 0.35)) // folded wings over the abdomen
        ctx.fillEllipse(in: CGRect(x: x0 + 14, y: cy - 1, width: 26, height: 8)); ctx.fillEllipse(in: CGRect(x: x0 + 14, y: cy - 7, width: 26, height: 8))
    }
    return SKTexture(cgImage: ctx.makeImage()!)
}

/// The bees' state, stepped by elapsed time: each walks in bouts at a calm pace or stands still.
struct Bee { var x, y, heading: Float; var walking: Bool; var timer: Float; var pose: Int }
var rng = SystemRandomNumberGenerator()
var bees: [Bee] = (0..<beeCount).map { i in
    Bee(x: .random(in: 20...1492), y: .random(in: 20...962), heading: .random(in: 0...6.283), walking: Double(i) / Double(beeCount) < movingShare, timer: .random(in: 0...4), pose: 0)
}
var stepTime: Float = 0
func step(_ dt: Float) {
    stepTime += dt
    for i in bees.indices where bees[i].walking {
        bees[i].heading += Float.random(in: -0.4...0.4) * dt
        let v: Float = 31 * 0.33 // a third of a body length a second
        bees[i].x += cos(bees[i].heading) * v * dt; bees[i].y += sin(bees[i].heading) * v * dt
        if bees[i].x < 10 || bees[i].x > 1502 || bees[i].y < 10 || bees[i].y > 972 { bees[i].heading += .pi }
        bees[i].pose = Int(stepTime * 8 + Float(i)) & 3
    }
}

// MARK: the scenes

let scene = SKScene(size: size)
scene.backgroundColor = .black
let built = SKUniform(name: "u_built", float: 0.55)
func combSprite() -> SKSpriteNode {
    let s = SKSpriteNode(color: .black, size: size)
    s.anchorPoint = .zero
    s.shader = SKShader(source: combSource, uniforms: [SKUniform(name: "u_size", vectorFloat2: [1512, 982]), SKUniform(name: "u_cell", float: cellPts),
        SKUniform(name: "u_cells", vectorFloat2: [Float(cols), Float(rows)]), SKUniform(name: "u_map", texture: combMap()), built,
        SKUniform(name: "u_light", float: 0.8)])
    return s
}
func keptComb() -> SKEffectNode {
    let e = SKEffectNode(); e.shouldRasterize = true; e.addChild(combSprite()); return e
}
var frames: [SKTexture] = []
var sprites: [SKSpriteNode] = []
var shown: [Int] = []
var beeData: SKUniform?
let grid = 64 // points: a bee's bounding circle (18 points) touches at most four of these
let gx = Int(size.width) / grid + 1, gy = Int(size.height) / grid + 1, slots = 8

switch mode {
case "empty": break
case "nebula":
    let s = SKSpriteNode(color: .black, size: size); s.anchorPoint = .zero
    s.shader = SKShader(source: nebulaSource(), uniforms: nebulaUniforms()); scene.addChild(s)
case "comb": scene.addChild(combSprite())
case "kept": scene.addChild(keptComb())
case "sprites", "keptbees":
    scene.addChild(keptComb())
    let atlas = beeAtlas()
    frames = (0..<4).map { SKTexture(rect: CGRect(x: Double($0) / 4, y: 0, width: 0.25, height: 1), in: atlas) }
    let resting = SKEffectNode(); resting.shouldRasterize = true
    if mode == "keptbees" { scene.addChild(resting) }
    for b in bees {
        let s = SKSpriteNode(texture: frames[0], size: CGSize(width: 36, height: 20))
        s.position = CGPoint(x: CGFloat(b.x), y: CGFloat(b.y)); s.zRotation = CGFloat(b.heading)
        if mode == "keptbees" && !b.walking { resting.addChild(s) } else { scene.addChild(s) }
        sprites.append(s); shown.append(0)
    }
case "jointed":
    // Ant Colony's way: a body and seventeen lengths of leg and antenna, each its own sprite, the legs turned every frame
    scene.addChild(keptComb())
    let atlas = beeAtlas()
    frames = [SKTexture(rect: CGRect(x: 0, y: 0, width: 0.25, height: 1), in: atlas)]
    for b in bees {
        let body = SKSpriteNode(texture: frames[0], size: CGSize(width: 36, height: 20))
        body.position = CGPoint(x: CGFloat(b.x), y: CGFloat(b.y)); body.zRotation = CGFloat(b.heading)
        for k in 0..<17 {
            let leg = SKSpriteNode(color: NSColor(red: 0.12, green: 0.08, blue: 0.04, alpha: 1), size: CGSize(width: 7, height: 0.8))
            leg.anchorPoint = CGPoint(x: 0, y: 0.5); leg.position = CGPoint(x: CGFloat(k % 6) * 3 - 6, y: k % 2 == 0 ? 3 : -3)
            body.addChild(leg)
        }
        scene.addChild(body); sprites.append(body); shown.append(0)
    }
case "shaderbees":
    scene.addChild(keptComb())
    // every bee drawn by one full-screen shader: a grid of 64-point squares, eight slots each, two texels a slot
    // (x and y to 1/256 of a point inside the square's neighbourhood; heading; pose and whether the slot is used)
    beeData = SKUniform(name: "u_bees", texture: SKTexture(data: Data(count: gx * slots * 2 * gy * 4), size: CGSize(width: gx * slots * 2, height: gy)))
    let s = SKSpriteNode(color: .clear, size: size); s.anchorPoint = .zero
    s.shader = SKShader(source: """
    void main() {
        vec2 pts = v_tex_coord * u_size;
        vec2 g = floor(pts / 64.0);
        vec4 col = vec4(0.0);
        for (int k = 0; k < 8; k++) {
            vec4 a = texture2D(u_bees, vec2((g.x * 16.0 + float(k) * 2.0 + 0.5) / u_dims.x, (g.y + 0.5) / u_dims.y));
            if (a.a < 0.5) { break; }
            vec4 b = texture2D(u_bees, vec2((g.x * 16.0 + float(k) * 2.0 + 1.5) / u_dims.x, (g.y + 0.5) / u_dims.y));
            vec2 c = g * 64.0 - 64.0 + vec2(a.r + a.g / 255.0, a.b + b.a / 255.0) * 192.0;
            float h = b.r * 6.2831853;
            vec2 d = pts - c;
            vec2 l = vec2(dot(d, vec2(cos(h), sin(h))), dot(d, vec2(-sin(h), cos(h))));
            vec2 uv = l / vec2(36.0, 20.0) + 0.5;
            if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
                vec4 t = texture2D(u_atlas, vec2((floor(b.g * 3.99) + uv.x) * 0.25, uv.y));
                col = t + col * (1.0 - t.a);
            }
        }
        gl_FragColor = col;
    }
    """, uniforms: [SKUniform(name: "u_size", vectorFloat2: [1512, 982]), SKUniform(name: "u_dims", vectorFloat2: [Float(gx * slots * 2), Float(gy)]),
                    beeData!, SKUniform(name: "u_atlas", texture: beeAtlas())])
    scene.addChild(s)
default: fatalError("mode")
}

/// The bees placed for this frame: only a walking bee is touched, and its texture only when its pose changes.
func place() {
    if mode == "sprites" || mode == "keptbees" {
        for i in bees.indices where bees[i].walking {
            sprites[i].position = CGPoint(x: CGFloat(bees[i].x), y: CGFloat(bees[i].y))
            sprites[i].zRotation = CGFloat(bees[i].heading)
            if shown[i] != bees[i].pose { shown[i] = bees[i].pose; sprites[i].texture = frames[bees[i].pose] }
        }
    } else if mode == "jointed" {
        for i in bees.indices where bees[i].walking {
            let n = sprites[i]
            n.position = CGPoint(x: CGFloat(bees[i].x), y: CGFloat(bees[i].y)); n.zRotation = CGFloat(bees[i].heading)
            for (k, leg) in n.children.enumerated() { leg.zRotation = CGFloat(sin(stepTime * 12 + Float(k))) * 0.4 + (k % 2 == 0 ? 1.2 : -1.2) }
        }
    } else if mode == "shaderbees" {
        var data = [UInt8](repeating: 0, count: gx * slots * 2 * gy * 4)
        var used = [Int](repeating: 0, count: gx * gy)
        for b in bees {
            let (cx0, cx1) = (Int((b.x - 18) / 64), Int((b.x + 18) / 64)), (cy0, cy1) = (Int((b.y - 18) / 64), Int((b.y + 18) / 64))
            for cy in max(cy0, 0)...min(cy1, gy - 1) { for cx in max(cx0, 0)...min(cx1, gx - 1) {
                let cell = cy * gx + cx, k = used[cell]
                guard k < slots else { continue }
                used[cell] += 1
                let rx = UInt16(min(max((b.x - Float(cx * 64 - 64)) / 192, 0), 1) * 65535), ry = UInt16(min(max((b.y - Float(cy * 64 - 64)) / 192, 0), 1) * 65535)
                let i = ((cy * gx + cx) * slots * 2 + k * 2) * 4
                // SpriteKit's data texture is upside down to the shader: row 0 is the bottom
                data[i] = UInt8(rx >> 8); data[i + 1] = UInt8(rx & 255); data[i + 2] = UInt8(ry >> 8); data[i + 3] = 255
                let hd = b.heading.truncatingRemainder(dividingBy: 6.2831853); let h = hd < 0 ? hd + 6.2831853 : hd
                data[i + 4] = UInt8(h / 6.2831853 * 255); data[i + 5] = UInt8(b.pose * 64); data[i + 7] = UInt8(ry & 255)
            } }
        }
        beeData!.textureValue = SKTexture(data: Data(data), size: CGSize(width: gx * slots * 2, height: gy))
    }
}

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: W, height: H, mipmapped: false)
desc.usage = [.renderTarget, .shaderRead]; desc.storageMode = .shared
let target = device.makeTexture(descriptor: desc)!
let renderer = SKRenderer(device: device)
renderer.scene = scene
var time = ProcessInfo.processInfo.systemUptime + 1
func frame() -> (cpu: Double, gpu: Double, rt: Double) {
    time += 1.0 / 60
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target; pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
    let buf = queue.makeCommandBuffer()!
    let t0 = DispatchTime.now().uptimeNanoseconds
    step(1.0 / 60); place()
    renderer.update(atTime: time)
    renderer.render(withViewport: CGRect(x: 0, y: 0, width: W, height: H), commandBuffer: buf, renderPassDescriptor: pass)
    buf.commit()
    let cpu = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6
    buf.waitUntilCompleted()
    let gpu = (buf.gpuEndTime - buf.gpuStartTime) * 1000
    return (cpu, gpu, Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6 - gpu)
}
for _ in 0..<30 { _ = frame() }
let runs = (0..<90).map { _ in frame() }
func med(_ a: [Double]) -> Double { a.sorted()[a.count / 2] }
func p10(_ a: [Double]) -> Double { a.sorted()[a.count / 10] }
// the step alone, for the bees' own CPU cost
let s0 = DispatchTime.now().uptimeNanoseconds
for _ in 0..<600 { step(1.0 / 60) }
let stepUs = Double(DispatchTime.now().uptimeNanoseconds - s0) / 600 / 1000
print(String(format: "%@ bees=%d moving=%.2f  CPU %.2f (p10 %.2f; render test's way %.2f) ms  GPU %.2f (p10 %.2f) ms  step %.1f us", mode, mode == "comb" || mode == "kept" || mode == "nebula" || mode == "empty" ? 0 : beeCount,
             movingShare, med(runs.map(\.cpu)), p10(runs.map(\.cpu)), med(runs.map(\.rt)), med(runs.map(\.gpu)), p10(runs.map(\.gpu)), stepUs))
if let png {
    var px = [UInt8](repeating: 0, count: W * H * 4)
    target.getBytes(&px, bytesPerRow: W * 4, from: MTLRegionMake2D(0, 0, W, H), mipmapLevel: 0)
    let ctx = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: png) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil); CGImageDestinationFinalize(dest)
}
