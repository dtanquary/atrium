import SpriteKit

@MainActor func murmuration(size: CGSize) -> SKScene { Murmuration(size: size) }

/// A starling murmuration over a low horizon at sunset. The flock is simulated in 3D (separation, alignment,
/// cohesion) and drawn with perspective, so it thins and darkens as it folds. A roaming target and an unseen
/// falcon that dives through every so often keep it changing shape.
final class Murmuration: SKScene {
    private struct Bird { var x, y, z, vx, vy, vz: Float; var cell: Int32 }

    private var flock: [Bird] = []
    private var sprites: [SKSpriteNode] = []
    private var cellStart: [Int32] = [], cellItems: [Int32] = []
    private var cols = 0, rows = 0, layers = 0
    private var time: TimeInterval = 0
    private var lastTime: TimeInterval?

    private let neighbourRadius: Float = 40
    private let personalSpace: Float = 20
    private let depth: Float = 400 // the grid covers z in ±depth; the flock stays well inside it
    private let focal: Float = 1300 // perspective strength; nearer birds (z > 0) draw bigger

    override func sceneDidLoad() {
        let w = size.width, h = size.height
        addChild(backdrop(size, [
            (0, rgb(1, 0.72, 0.45)), (0.12, rgb(0.98, 0.56, 0.42)), (0.32, rgb(0.78, 0.43, 0.5)),
            (0.6, rgb(0.42, 0.34, 0.54)), (1, rgb(0.16, 0.18, 0.37)),
        ]))
        addSunAndClouds()

        let horizon = treeline(width: w, base: h * 0.08, hills: h * 0.012, trees: h * 0.015...h * 0.05, spacing: 5...16,
                               color: rgb(0.14, 0.08, 0.14), pineChance: 0.25, resolution: 0.5)
        horizon.zPosition = 3
        addChild(horizon)
        let reeds = grassFringe(width: w, height: h * 0.07, color: rgb(0.08, 0.045, 0.08))
        reeds.zPosition = 4
        addChild(reeds)

        cols = Int(Float(w) / neighbourRadius) + 3
        rows = Int(Float(h) / neighbourRadius) + 3
        layers = Int(2 * depth / neighbourRadius) + 1
        cellStart = [Int32](repeating: 0, count: cols * rows * layers + 1)

        // ponytail: each simulated bird is drawn as a little cluster of four, so ~1,300 boids read as ~5,000 starlings
        let count = Int(w * h / 1100)
        let ink = rgb(0.06, 0.04, 0.08)
        let cluster = paint(CGSize(width: 12, height: 12)) { ctx in
            ctx.setFillColor(ink)
            for (x, y, r) in [(3.0, 4.0, 1.1), (8.5, 3.0, 1.0), (6.0, 8.5, 1.15), (10.0, 9.0, 0.9)] as [(CGFloat, CGFloat, CGFloat)] {
                ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
            }
        }
        for _ in 0..<count {
            let a = Float.random(in: 0...(2 * .pi)), r = sqrt(Float.random(in: 0...1))
            flock.append(Bird(x: Float(w) * 0.45 + cos(a) * r * 300, y: Float(h) * 0.62 + sin(a) * r * 110,
                              z: .random(in: -150...150), vx: .random(in: 90...130), vy: .random(in: -15...15), vz: .random(in: -15...15), cell: 0))
            let sprite = SKSpriteNode(texture: cluster, size: CGSize(width: 12, height: 12))
            sprite.zRotation = .random(in: 0...(2 * .pi))
            sprite.alpha = 0.85
            sprite.zPosition = 2
            addChild(sprite)
            sprites.append(sprite)
        }
        cellItems = [Int32](repeating: 0, count: count)
        place()
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastTime)
        time += dt
        simulate(Float(dt))
        place()
    }

    private func place() {
        let cx = Float(size.width / 2), cy = Float(size.height / 2)
        for (bird, sprite) in zip(flock, sprites) {
            let s = focal / (focal - bird.z)
            sprite.position = CGPoint(x: CGFloat(cx + (bird.x - cx) * s), y: CGFloat(cy + (bird.y - cy) * s))
            sprite.setScale(CGFloat(s))
        }
    }

    /// One step of the flock. Neighbours come from a 3D grid of `neighbourRadius` cells, capped at 10 per bird
    /// (starlings track about seven), so the cost stays linear in flock size.
    private func simulate(_ dt: Float) {
        let w = Float(size.width), h = Float(size.height), t = Float(time)
        let cols = cols, rows = rows, layers = layers, radius = neighbourRadius, space = personalSpace, depth = depth

        // Where the flock is drawn toward, and how tightly it holds together, both wander slowly.
        let targetX = w * (0.5 + 0.2 * sin(0.061 * t) + 0.06 * sin(0.17 * t + 1))
        let targetY = h * (0.56 + 0.1 * sin(0.093 * t + 2))
        let cohesion: Float = 0.4 + 0.2 * sin(0.05 * t)

        // The falcon: every 26 s it crosses the sky for 5 s, passing through where the flock was when it started.
        let cycle = t.truncatingRemainder(dividingBy: 26)
        var falcon: (x: Float, y: Float)?
        if cycle > 19 {
            let p = (cycle - 19) / 5 * 1.6 - 0.8, angle = Float(Int(t / 26) % 7) * 0.9
            falcon = (targetX + cos(angle) * p * w * 0.6, targetY + sin(angle) * p * h * 0.4)
        }

        cellStart.withUnsafeMutableBufferPointer { start in
            cellItems.withUnsafeMutableBufferPointer { items in
                flock.withUnsafeMutableBufferPointer { birds in
                    // Bucket birds into grid cells (counting sort).
                    for c in 0..<start.count { start[c] = 0 }
                    for i in 0..<birds.count {
                        let cx = min(max(Int(birds[i].x / radius) + 1, 0), cols - 1)
                        let cy = min(max(Int(birds[i].y / radius) + 1, 0), rows - 1)
                        let cz = min(max(Int((birds[i].z + depth) / radius), 0), layers - 1)
                        birds[i].cell = Int32((cz * rows + cy) * cols + cx)
                        start[Int(birds[i].cell) + 1] += 1
                    }
                    for c in 1..<start.count { start[c] += start[c - 1] }
                    var fill = Array(start)
                    for i in 0..<birds.count {
                        let c = Int(birds[i].cell)
                        items[Int(fill[c])] = Int32(i)
                        fill[c] += 1
                    }

                    for i in 0..<birds.count {
                        var b = birds[i]
                        var ax: Float = 0, ay: Float = 0, az: Float = 0
                        var sx: Float = 0, sy: Float = 0, sz: Float = 0 // neighbours' summed position
                        var ux: Float = 0, uy: Float = 0, uz: Float = 0 // and velocity
                        var seen = 0
                        let c = Int(b.cell), cx = c % cols, cy = c / cols % rows, cz = c / (cols * rows)
                        search: for gz in max(cz - 1, 0)...min(cz + 1, layers - 1) {
                          for gy in max(cy - 1, 0)...min(cy + 1, rows - 1) {
                            for gx in max(cx - 1, 0)...min(cx + 1, cols - 1) {
                                let cell = (gz * rows + gy) * cols + gx
                                for k in Int(start[cell])..<Int(start[cell + 1]) {
                                    let j = Int(items[k])
                                    if j == i { continue }
                                    let o = birds[j]
                                    let dx = b.x - o.x, dy = b.y - o.y, dz = b.z - o.z
                                    let d2 = dx * dx + dy * dy + dz * dz
                                    if d2 > radius * radius { continue }
                                    let d = d2.squareRoot() + 0.01
                                    if d < space {
                                        let push = 900 * (1 - d / space) / d
                                        ax += dx * push; ay += dy * push; az += dz * push
                                    }
                                    sx += o.x; sy += o.y; sz += o.z
                                    ux += o.vx; uy += o.vy; uz += o.vz
                                    seen += 1
                                    if seen == 10 { break search }
                                }
                            }
                          }
                        }
                        if seen > 0 {
                            let n = Float(seen)
                            ax += (ux / n - b.vx) * 2.4 + (sx / n - b.x) * cohesion
                            ay += (uy / n - b.vy) * 2.4 + (sy / n - b.y) * cohesion
                            az += (uz / n - b.vz) * 2.4 + (sz / n - b.z) * cohesion
                        }
                        // Steer toward the target at a constant pull, which turns the flock without squeezing it to a point.
                        let tx = targetX - b.x, ty = targetY - b.y, td = (tx * tx + ty * ty).squareRoot() + 1
                        ax += tx / td * 45
                        ay += ty / td * 45
                        az -= b.z * 0.35

                        // Soft walls keep the flock in the sky and on screen, with room for perspective to push near birds outward.
                        ay += max(0, h * 0.3 - b.y) * 4 - max(0, b.y - h * 0.82) * 4
                        ax += max(0, w * 0.12 - b.x) * 4 - max(0, b.x - w * 0.88) * 4

                        if let falcon {
                            let dx = b.x - falcon.x, dy = b.y - falcon.y, d = (dx * dx + dy * dy).squareRoot() + 0.01
                            if d < 130 {
                                let flee = 1100 * (1 - d / 130) / d
                                ax += dx * flee; ay += dy * flee
                            }
                        }

                        b.vx += ax * dt; b.vy += ay * dt; b.vz += az * dt
                        let speed = (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz).squareRoot()
                        let clamped = min(max(speed, 90), 170)
                        b.vx *= clamped / speed; b.vy *= clamped / speed; b.vz *= clamped / speed
                        birds[i] = b
                    }
                    for i in 0..<birds.count {
                        birds[i].x += birds[i].vx * dt
                        birds[i].y += birds[i].vy * dt
                        birds[i].z += birds[i].vz * dt
                    }
                }
            }
        }
    }

    private func addSunAndClouds() {
        let w = size.width, h = size.height
        let glow = SKSpriteNode(texture: radialGlow(diameter: 128, stops: [
            (0, rgb(1, 0.95, 0.8, 0.9)), (0.08, rgb(1, 0.85, 0.6, 0.7)), (0.3, rgb(1, 0.65, 0.4, 0.25)), (1, rgb(1, 0.5, 0.3, 0)),
        ]), size: CGSize(width: h * 0.9, height: h * 0.9))
        glow.position = CGPoint(x: w * 0.7, y: h * 0.1)
        glow.blendMode = .add
        glow.zPosition = 1
        addChild(glow)

        let streak = radialGlow(diameter: 64, stops: [(0, rgb(1, 1, 1, 0.9)), (0.5, rgb(1, 1, 1, 0.4)), (1, rgb(1, 1, 1, 0))])
        for _ in 0..<7 {
            let cloud = SKSpriteNode(texture: streak, size: CGSize(width: .random(in: 300...700), height: .random(in: 14...34)))
            cloud.position = CGPoint(x: .random(in: 0...w), y: h * .random(in: 0.18...0.5))
            cloud.color = NSColor(red: 1, green: .random(in: 0.6...0.8), blue: .random(in: 0.55...0.7), alpha: 1)
            cloud.colorBlendFactor = 1
            cloud.alpha = .random(in: 0.2...0.45)
            cloud.zPosition = 1
            addChild(cloud)
        }
    }
}
