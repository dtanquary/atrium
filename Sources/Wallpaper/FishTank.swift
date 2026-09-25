import SpriteKit

final class FishTank: SKScene {
    private var floorHeight: CGFloat { size.height * 0.12 }

    override func sceneDidLoad() {
        addWater()
        addSand()
        addSeaweed()
        addBubbles()
        for _ in 0..<max(6, Int(size.width / 120)) {
            let fish = makeFish()
            addChild(fish)
            swim(fish, fromX: .random(in: 0...size.width)) // start mid-tank so it isn't empty at launch
        }
    }

    /// Deep-to-shallow gradient with slow light rays, drawn on the GPU.
    private func addWater() {
        let water = SKSpriteNode(color: .black, size: size)
        water.anchorPoint = .zero
        water.shader = SKShader(source: """
            void main() {
                vec2 uv = v_tex_coord;
                vec3 c = mix(vec3(0.01, 0.07, 0.18), vec3(0.05, 0.35, 0.50), uv.y);
                float rays = sin(uv.x * 9.0 + uv.y * 3.0 + u_time * 0.3) * sin(uv.x * 23.0 - u_time * 0.2);
                c += max(rays, 0.0) * 0.06 * uv.y;
                gl_FragColor = vec4(c, 1.0);
            }
            """)
        addChild(water)
    }

    private func addSand() {
        let path = CGMutablePath()
        path.move(to: .zero)
        for x in stride(from: 0, through: size.width + 40, by: 40) {
            path.addLine(to: CGPoint(x: x, y: floorHeight + 12 * sin(x / 150)))
        }
        path.addLine(to: CGPoint(x: size.width + 40, y: 0))
        path.closeSubpath()

        let sand = SKShapeNode(path: path)
        sand.fillColor = NSColor(red: 0.55, green: 0.48, blue: 0.34, alpha: 1)
        sand.strokeColor = .clear
        sand.zPosition = 4
        addChild(sand)
    }

    private func addSeaweed() {
        for _ in 0..<Int(size.width / 90) {
            let height = CGFloat.random(in: 80...size.height * 0.35)
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addCurve(to: CGPoint(x: 0, y: height),
                          control1: CGPoint(x: 30, y: height / 3), control2: CGPoint(x: -30, y: height * 2 / 3))

            let weed = SKShapeNode(path: path)
            weed.strokeColor = NSColor(red: 0.1, green: .random(in: 0.4...0.6), blue: 0.3, alpha: 1)
            weed.lineWidth = .random(in: 6...12)
            weed.lineCap = .round
            weed.position = CGPoint(x: .random(in: 0...size.width), y: floorHeight - 10)
            weed.zPosition = 2
            weed.zRotation = -0.06
            let sway = SKAction.rotate(byAngle: 0.12, duration: .random(in: 2...4))
            sway.timingMode = .easeInEaseOut
            weed.run(.repeatForever(.sequence([sway, sway.reversed()])))
            addChild(weed)
        }
    }

    private func addBubbles() {
        let bubbles = SKEmitterNode()
        bubbles.particleTexture = paint(CGSize(width: 12, height: 12)) { ctx in
            let ring = CGRect(x: 0.75, y: 0.75, width: 10.5, height: 10.5)
            ctx.setFillColor(CGColor(gray: 1, alpha: 0.15))
            ctx.fillEllipse(in: ring)
            ctx.setStrokeColor(.white)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: ring)
        }
        bubbles.particleSize = CGSize(width: 12, height: 12)
        bubbles.particleBirthRate = 3
        bubbles.particleLifetime = size.height / 50
        bubbles.particlePositionRange = CGVector(dx: size.width, dy: 0)
        bubbles.position = CGPoint(x: size.width / 2, y: floorHeight)
        bubbles.emissionAngle = .pi / 2
        bubbles.particleSpeed = 60
        bubbles.particleSpeedRange = 30
        bubbles.particleScale = 0.5
        bubbles.particleScaleRange = 0.4
        bubbles.particleAlpha = 0.5
        bubbles.zPosition = 3
        bubbles.advanceSimulationTime(TimeInterval(bubbles.particleLifetime)) // fill the tank before first frame
        addChild(bubbles)
    }

    /// A fish facing +x: ellipse body, wagging triangle tail, one eye.
    private func makeFish() -> SKNode {
        let color = [NSColor.systemOrange, .systemYellow, .systemPink, .systemTeal, .systemRed].randomElement()!
        let fish = SKNode()

        let tailPath = CGMutablePath()
        tailPath.move(to: .zero)
        tailPath.addLine(to: CGPoint(x: -18, y: 10))
        tailPath.addLine(to: CGPoint(x: -18, y: -10))
        tailPath.closeSubpath()
        let tail = SKShapeNode(path: tailPath)
        tail.fillColor = color
        tail.strokeColor = .clear
        tail.position = CGPoint(x: -20, y: 0)
        tail.zRotation = -0.25
        let wag = SKAction.rotate(byAngle: 0.5, duration: 0.25)
        wag.timingMode = .easeInEaseOut
        tail.run(.repeatForever(.sequence([wag, wag.reversed()])))

        let body = SKShapeNode(ellipseOf: CGSize(width: 50, height: 24))
        body.fillColor = color
        body.strokeColor = .clear

        let eye = SKShapeNode(circleOfRadius: 3)
        eye.fillColor = .black
        eye.strokeColor = .white
        eye.lineWidth = 1.5
        eye.position = CGPoint(x: 14, y: 4)

        [tail, body, eye].forEach(fish.addChild)

        let bob = SKAction.moveBy(x: 0, y: 8, duration: .random(in: 1...2))
        bob.timingMode = .easeInEaseOut
        fish.run(.repeatForever(.sequence([bob, bob.reversed()])))
        return fish
    }

    /// Sends the fish across the tank at a random depth, then round again from a new side.
    private func swim(_ fish: SKNode, fromX startX: CGFloat? = nil) {
        let depth = CGFloat.random(in: 0.4...1.2) // smaller = further away: slower, fainter, behind the seaweed
        let leftToRight = Bool.random()
        let offLeft: CGFloat = -100, offRight = size.width + 100
        let endX = leftToRight ? offRight : offLeft

        fish.setScale(depth)
        fish.xScale = leftToRight ? depth : -depth
        fish.alpha = min(1, 0.35 + 0.55 * depth)
        fish.zPosition = depth < 0.8 ? 1 : 3
        fish.position = CGPoint(x: startX ?? (leftToRight ? offLeft : offRight),
                                y: .random(in: floorHeight + 40...size.height - 40))

        let speed = CGFloat.random(in: 40...90) * depth
        fish.run(.sequence([
            .moveTo(x: endX, duration: abs(endX - fish.position.x) / speed),
            .run { [weak self, weak fish] in
                guard let self, let fish else { return }
                self.swim(fish)
            },
        ]))
    }
}
