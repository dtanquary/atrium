import SpriteKit
import simd

/// A planted reef tank seen through the glass: shaded fish schooling at three depths, plants swaying from their
/// roots, rocks and driftwood, caustics rippling over the sand, light rays and a shimmering surface, an aerator
/// and drifting marine snow. Everything is painted in code at launch (see FishTankArt.swift).
final class FishTank: SKScene {
    /// One fish. It swims in the flat plane of its school's depth.
    private struct Swimmer {
        let node: SKSpriteNode
        var position: SIMD2<Double>
        var velocity: SIMD2<Double>
        var facing: Double
        var wander = Double.random(in: 0..<(2 * .pi))
        var tilt = 0.0
        var stroke = Double.random(in: 0..<1) // how far through a tail beat, in beats
        var frame = -1
    }

    /// Fish of one species at one depth, which school together.
    private struct School {
        let species: Species
        let depth: CGFloat // 1 is the front of the tank, smaller is further back
        let cruise: Double // points per second
        let beat: [SKWarpGeometryGrid] // one tail beat of warp frames
        var members: [Int] = []
        var home: SIMD2<Double>? // a spot they keep near, like clownfish at their anemone
    }

    private enum Z {
        static let water: CGFloat = 0, sand: CGFloat = 1, farRocks: CGFloat = 2, farPlants: CGFloat = 3, farFish: CGFloat = 4
        static let midPlants: CGFloat = 5, midFish: CGFloat = 6, bubbles: CGFloat = 7, nearFish: CGFloat = 8
        static let frontPlants: CGFloat = 9, vignette: CGFloat = 10
    }

    private var swimmers: [Swimmer] = []
    private var schools: [School] = []
    private var lastUpdate: TimeInterval?
    private var anemone = CGPoint.zero

    /// Scales the art with the display, so a bigger screen gets a bigger tank rather than smaller fish.
    private var unit: CGFloat { min(max(size.height / 982, 0.8), 1.8) }
    private var sandHeight: CGFloat { size.height * 0.22 }
    /// Fish are drawn a little larger than life against the plants, so they read from across the room.
    private var fishUnit: CGFloat { unit * 1.2 }

    override func sceneDidLoad() {
        backgroundColor = .black
        addWater()
        addSand()
        addHardscapeAndPlants()
        addSchools()
        addBubbles()
        addMarineSnow()
        addVignette()
        for _ in 0..<150 { swim(1.0 / 30) } // let the schools gather before the first frame
    }

    override func update(_ currentTime: TimeInterval) {
        swim(frameTime(currentTime, &lastUpdate))
    }

    // MARK: - Swimming

    /// The floor and ceiling a school keeps between: fish further back can't come as low, since the sand is nearer
    /// the eye there.
    private func bounds(_ depth: CGFloat) -> (floor: Double, ceiling: Double) {
        let forward = Double(min(max((depth - 0.55) / 0.5, 0), 1))
        return (Double(sandHeight) * (1 - 0.65 * forward) + Double(30 * unit), Double(size.height * 0.9 - 30 * unit))
    }

    /// Steers every fish: keep clear of schoolmates, match their heading, drift toward their middle, wander a
    /// little, and turn back from the walls just past the screen edges, the sand and the surface.
    private func swim(_ dt: Double) {
        let width = Double(size.width), wall = width * 0.1
        for school in schools {
            let body = Double(school.species.length * school.depth * fishUnit)
            let gap = body * school.species.spacing, sight = body * 6, push = school.cruise * 2.5
            let (floor, ceiling) = bounds(school.depth)
            for i in school.members {
                let p = swimmers[i].position, v = swimmers[i].velocity
                var steer = SIMD2<Double>.zero, heading = SIMD2<Double>.zero, middle = SIMD2<Double>.zero, seen = 0.0
                // ponytail: O(n²) within a school, fine up to a few dozen fish per school
                for j in school.members where j != i {
                    let d = swimmers[j].position - p, distance = max(length(d), 0.001)
                    if distance < gap { steer -= d / distance * (gap - distance) / gap * school.cruise * 3 }
                    if distance < sight {
                        heading += swimmers[j].velocity
                        middle += swimmers[j].position
                        seen += 1
                    }
                }
                if seen > 0 {
                    steer += (heading / seen - v) * 0.9
                    steer += (middle / seen - p) * 0.25
                }
                swimmers[i].wander += Double.random(in: -1...1) * dt * 1.5
                steer += SIMD2(cos(swimmers[i].wander), 0.4 * sin(swimmers[i].wander)) * school.cruise * 0.45
                if let home = school.home { steer += (home - p) * 0.08 }
                steer.x += max(0, wall - width * 0.04 - p.x) / wall * push
                steer.x -= max(0, p.x - (width * 1.04 - wall)) / wall * push
                steer.y += max(0, floor + 60 - p.y) / 60 * push * 0.6
                steer.y -= max(0, p.y - (ceiling - 60)) / 60 * push * 0.6

                var velocity = v + steer * dt
                velocity.y *= 1 - 1.4 * dt // fish mostly swim level
                let speed = length(velocity)
                velocity *= min(max(speed, school.cruise * 0.45), school.cruise * 1.35) / max(speed, 0.001)
                swimmers[i].velocity = velocity
                swimmers[i].position = p + velocity * dt
                pose(i, in: school, dt: dt)
            }
        }
    }

    /// Faces, tilts and paces the tail beat of a fish from its velocity. Turning eases its width through zero, so
    /// it reads as the fish turning round rather than flipping.
    private func pose(_ i: Int, in school: School, dt: Double) {
        var fish = swimmers[i]
        let v = fish.velocity, cruise = school.cruise
        let target = v.x > cruise * 0.15 ? 1.0 : v.x < -cruise * 0.15 ? -1.0 : (fish.facing >= 0 ? 1 : -1)
        fish.facing += max(-dt * 2.5, min(dt * 2.5, target - fish.facing))
        let pitch = max(-0.3, min(0.3, atan2(v.y, max(abs(v.x), cruise * 0.5))))
        fish.tilt += (pitch - fish.tilt) * min(1, dt * 3)
        fish.node.position = CGPoint(x: fish.position.x, y: fish.position.y)
        fish.node.xScale = CGFloat(fish.facing) * school.depth * fishUnit
        fish.node.zRotation = CGFloat(fish.facing >= 0 ? fish.tilt : -fish.tilt)

        // The tail beats faster when swimming faster. Stepping through precomputed frames here, rather than an
        // SKAction whose speed changes every frame, which SpriteKit gets steadily slower at.
        fish.stroke += dt / school.species.beat * (0.55 + 0.8 * length(v) / cruise)
        let frame = Int(fish.stroke * Double(school.beat.count)) % school.beat.count
        if frame != fish.frame {
            fish.frame = frame
            fish.node.warpGeometry = school.beat[frame]
        }
        swimmers[i] = fish
    }

    private func addSchools() {
        // Species, school size, depth. Two far schools add depth; the tetras are the showpiece school.
        let plan: [(Species, Int, CGFloat)] = [
            (.neonTetra, 14, 0.55), (.blueTang, 2, 0.6), (.yellowTang, 4, 0.75), (.neonTetra, 26, 0.85),
            (.angelfish, 2, 0.88), (.clownfish, 2, 0.95), (.blueTang, 3, 1.1),
        ]
        for (species, count, depth) in plan {
            let (texture, textureSize) = TankArt.fish(species, fog: max(0, (1 - depth) * 0.7))
            let (floor, ceiling) = bounds(depth)
            var school = School(species: species, depth: depth, cruise: .random(in: species.cruise) * Double(depth * unit),
                                beat: TankArt.swimWarps(species, textureHeight: textureSize.height))
            if species == .clownfish {
                school.home = SIMD2(Double(anemone.x), Double(anemone.y + size.height * 0.08))
            }
            let centre = school.home ?? SIMD2(Double.random(in: 0.15...0.85) * Double(size.width), .random(in: floor...ceiling))
            let heading = Bool.random() ? 1.0 : -1.0
            for _ in 0..<count {
                let node = SKSpriteNode(texture: texture, size: textureSize)
                node.setScale(depth * fishUnit)
                node.zPosition = depth < 0.7 ? Z.farFish : depth < 1 ? Z.midFish : Z.nearFish
                node.subdivisionLevels = 1
                addChild(node)
                let spread = Double(species.length * depth * fishUnit) * 2.5
                school.members.append(swimmers.count)
                swimmers.append(Swimmer(node: node,
                                        position: centre + SIMD2(.random(in: -spread...spread), .random(in: -spread...spread) * 0.5),
                                        velocity: SIMD2(heading * school.cruise, .random(in: -0.1...0.1) * school.cruise),
                                        facing: heading))
            }
            schools.append(school)
        }
    }

    // MARK: - Water, light and sand

    /// Deep-to-shallow blue, sun shafts fanning down from above the surface and swaying, faint caustic light on the
    /// far wall, and the underside of the surface shimmering along the top.
    private func addWater() {
        let water = SKSpriteNode(color: .black, size: size)
        water.anchorPoint = .zero
        water.zPosition = Z.water
        water.shader = SKShader(source: Self.caustics + """
            float hash1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
            float noise1(float x) {
                float i = floor(x);
                float f = fract(x);
                return mix(hash1(i), hash1(i + 1.0), f * f * (3.0 - 2.0 * f));
            }
            void main() {
                vec2 uv = v_tex_coord;
                vec2 pts = uv * u_size;
                float t = u_time;
                vec3 c = mix(vec3(0.012, 0.075, 0.15), vec3(0.03, 0.24, 0.36), smoothstep(0.0, 0.55, uv.y));
                c = mix(c, vec3(0.08, 0.46, 0.58), smoothstep(0.5, 1.0, uv.y));

                // Shafts: bands in the angle from a point high above the surface, drifting and flickering.
                float a = (pts.x - u_size.x * 0.38) / (u_size.y * 1.7 - pts.y);
                float shafts = noise1(a * 7.0 + sin(t * 0.06) * 0.8 + t * 0.02) * noise1(a * 19.0 - t * 0.04 + 7.0);
                shafts = smoothstep(0.22, 0.72, shafts) * (0.8 + 0.2 * sin(t * 0.8 + a * 30.0));
                c += vec3(0.45, 0.78, 0.86) * shafts * 0.13 * smoothstep(0.05, 1.0, uv.y);

                c += vec3(0.4, 0.75, 0.85) * caustic(pts / 170.0, t * 0.5) * 0.022 * smoothstep(0.25, 1.0, uv.y);

                // The surface seen from below: a bright band, ripples crossing it.
                float band = smoothstep(0.9, 0.985, uv.y);
                float ripple = sin(pts.x * 0.034 + pts.y * 0.22 + t * 0.9 + 2.0 * sin(pts.x * 0.009 - t * 0.3))
                             * sin(pts.x * 0.021 - pts.y * 0.14 - t * 0.55);
                c = mix(c, vec3(0.28, 0.7, 0.78), band * 0.5);
                c += vec3(0.75, 0.95, 1.0) * pow(max(ripple, 0.0), 3.0) * band * 0.5;

                c += (fract(sin(dot(pts, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0; // dither
                gl_FragColor = vec4(c, 1.0);
            }
            """, uniforms: [SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)])])
        addChild(water)
    }

    /// Bright lines where the cells of a moving Voronoi pattern meet, like sunlight focused by surface waves.
    private static let caustics = """
        float caustic(vec2 p, float t) {
            // Bend the cell walls into wandering curves, at two scales.
            p += 0.3 * vec2(sin(p.y * 1.7 + t * 0.7) + 0.6 * sin(p.y * 3.3 - t * 0.9 + p.x),
                            sin(p.x * 1.5 - t * 0.6) + 0.6 * sin(p.x * 3.1 + t * 0.8 - p.y));
            vec2 i = floor(p);
            vec2 f = fract(p);
            float d1 = 8.0;
            float d2 = 8.0;
            for (int y = -1; y <= 1; y++) {
                for (int x = -1; x <= 1; x++) {
                    vec2 g = vec2(float(x), float(y));
                    vec2 h = fract(sin(vec2(dot(i + g, vec2(127.1, 311.7)), dot(i + g, vec2(269.5, 183.3)))) * 43758.5453);
                    float d = length(g + 0.5 + 0.42 * sin(t + 6.2831 * h) - f);
                    if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
                }
            }
            float edge = 1.0 - smoothstep(0.0, 0.1, d2 - d1);
            return edge * edge * 0.8 + (1.0 - smoothstep(0.0, 0.35, d2 - d1)) * 0.2;
        }

        """

    /// The sand floor with caustics rippling across it: bigger up front, squashed by perspective, fading with haze.
    private func addSand() {
        let floorSize = CGSize(width: size.width, height: sandHeight)
        let sand = SKSpriteNode(texture: TankArt.sand(floorSize), size: floorSize)
        sand.anchorPoint = .zero
        sand.zPosition = Z.sand
        sand.shader = SKShader(source: Self.caustics + """
            void main() {
                vec4 s = texture2D(u_texture, v_tex_coord);
                vec2 pts = v_tex_coord * u_size;
                float back = v_tex_coord.y;
                vec2 p = vec2(pts.x, pts.y * 2.6) / mix(140.0, 60.0, back);
                float light = caustic(p, u_time * 0.7) * 0.75 + caustic(p * 1.7 + 3.7, u_time * 0.95) * 0.3;
                s.rgb += vec3(0.85, 1.0, 0.92) * light * 0.3 * (1.0 - 0.7 * back) * s.a;
                gl_FragColor = s;
            }
            """, uniforms: [SKUniform(name: "u_size", vectorFloat2: [Float(floorSize.width), Float(floorSize.height)])])
        addChild(sand)
    }

    // MARK: - Hardscape and plants

    private func addHardscapeAndPlants() {
        let far = SKSpriteNode(texture: TankArt.farRocks(CGSize(width: size.width, height: size.height * 0.15)),
                               size: CGSize(width: size.width, height: size.height * 0.15))
        far.anchorPoint = .zero
        far.position = CGPoint(x: 0, y: sandHeight * 0.86)
        far.zPosition = Z.farRocks
        addChild(far)

        // A few painted variants per row, reused with flips and sizes, keep texture memory down.
        func pool(_ kinds: [TankArt.Plant], height: CGFloat, fog: CGFloat) -> [(TankArt.Plant, SKTexture, CGSize)] {
            kinds.map { kind in
                let (texture, size) = TankArt.plant(kind, height: kind == .anemone ? height * 0.35 : height, fog: fog)
                return (kind, texture, size)
            }
        }
        let back = pool([.kelp, .grass, .redKelp, .grass], height: size.height * 0.3, fog: 0.5)
        let middle = pool([.kelp, .grass, .stems, .redKelp, .kelp, .stems], height: size.height * 0.42, fog: 0.12)
        let front = pool([.kelp, .grass, .redKelp], height: size.height * 0.62, fog: 0)

        var x = CGFloat.random(in: 0...80)
        while x < size.width { // back row along the far edge of the sand
            plant(back.randomElement()!, at: CGPoint(x: x, y: sandHeight * .random(in: 0.8...0.9)), scale: .random(in: 0.7...1.1), z: Z.farPlants)
            x += .random(in: 90...190) * unit
        }
        anemone = CGPoint(x: size.width * 0.3, y: sandHeight * 0.48)
        x = .random(in: 0...120)
        while x < size.width { // middle row, leaving room around the anemone
            if abs(x - anemone.x) > 110 * unit {
                plant(middle.randomElement()!, at: CGPoint(x: x, y: sandHeight * .random(in: 0.5...0.75)), scale: .random(in: 0.75...1.1), z: Z.midPlants)
            }
            x += .random(in: 150...290) * unit
        }
        plant(pool([.anemone], height: size.height * 0.36, fog: 0.05)[0], at: anemone, scale: 1, z: Z.midPlants)

        // Stones in front of the middle row, and a branch of driftwood.
        let wood = CGSize(width: size.width * 0.3, height: size.height * 0.17)
        let branch = SKSpriteNode(texture: TankArt.driftwood(wood, fog: 0.1), size: wood)
        branch.anchorPoint = CGPoint(x: 0.5, y: 0)
        branch.position = CGPoint(x: size.width * 0.56, y: sandHeight * 0.22)
        branch.zPosition = Z.midPlants
        addChild(branch)
        for fraction in [0.1, 0.44, 0.72, 0.93] { // clusters: a big stone with a smaller one or two nestled beside it
            let spot = CGPoint(x: size.width * fraction + .random(in: -40...40), y: sandHeight * .random(in: 0.35...0.55))
            for (i, scale) in [1, CGFloat.random(in: 0.35...0.55), .random(in: 0.25...0.4)].prefix(.random(in: 2...3)).enumerated() {
                let stone = CGSize(width: .random(in: 130...200) * unit * scale, height: .random(in: 70...105) * unit * scale)
                let rock = SKSpriteNode(texture: TankArt.rock(stone, fog: 0.12), size: stone)
                rock.anchorPoint = CGPoint(x: 0.5, y: 0.08)
                let side: CGFloat = i == 1 ? 1 : -1
                rock.position = CGPoint(x: spot.x + (i == 0 ? 0 : side * .random(in: 60...95) * unit), y: spot.y - CGFloat(i) * 8 * unit)
                rock.zPosition = Z.midPlants
                addChild(rock)
            }
        }

        // Tall plants right up against the glass at both edges, for fish to slip behind.
        for edge in [CGFloat.random(in: 0.01...0.07), .random(in: 0.12...0.16), .random(in: 0.9...0.98)] {
            plant(front.randomElement()!, at: CGPoint(x: size.width * edge, y: -size.height * 0.02), scale: .random(in: 0.85...1.1), z: Z.frontPlants)
        }
    }

    /// Plants one clump, swaying from its base with its own period and starting point.
    private func plant(_ art: (TankArt.Plant, SKTexture, CGSize), at base: CGPoint, scale: CGFloat, z: CGFloat) {
        let (kind, texture, size) = art
        let sprite = SKSpriteNode(texture: texture, size: size)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.position = base
        sprite.setScale(scale * unit)
        if Bool.random() { sprite.xScale *= -1 }
        sprite.zPosition = z
        sprite.subdivisionLevels = 1
        sprite.warpGeometry = SKWarpGeometryGrid(columns: 1, rows: 8)
        let sway = TankArt.swayWarps(width: size.width, height: size.height, strength: kind == .anemone ? 0.05 : 0.07,
                                     period: .random(in: 4.5...7.5))
        sprite.run(.sequence([.wait(forDuration: .random(in: 0...4)), sway]))
        addChild(sprite)
    }

    // MARK: - Bubbles, snow and the edges

    /// An airstone sending up a stream of wobbling bubbles that swell as they rise and pop at the surface.
    private func addBubbles() {
        let base = CGPoint(x: size.width * 0.8, y: sandHeight * 0.42)
        let stoneSize = CGSize(width: 38 * unit, height: 18 * unit)
        let stone = SKSpriteNode(texture: TankArt.rock(stoneSize, fog: 0.05), size: stoneSize)
        stone.anchorPoint = CGPoint(x: 0.5, y: 0.2)
        stone.position = base
        stone.zPosition = Z.midPlants
        addChild(stone)

        let bubbles = SKEmitterNode()
        bubbles.particleTexture = TankArt.bubble()
        bubbles.particleSize = CGSize(width: 16, height: 16)
        bubbles.position = CGPoint(x: base.x, y: base.y + 10 * unit)
        bubbles.particlePositionRange = CGVector(dx: 12 * unit, dy: 0)
        bubbles.particleBirthRate = 8
        bubbles.emissionAngle = .pi / 2
        bubbles.emissionAngleRange = 0.15
        bubbles.particleSpeed = 110
        bubbles.particleSpeedRange = 40
        bubbles.yAcceleration = 25 // buoyancy: they speed up as they rise
        let rise = Double(size.height * 0.93 - base.y) // reach the surface band: solve rise = 110t + 12.5t²
        bubbles.particleLifetime = CGFloat((-110 + sqrt(110 * 110 + 50 * rise)) / 25)
        bubbles.particleScale = 0.4 * unit
        bubbles.particleScaleRange = 0.35 * unit
        bubbles.particleScaleSpeed = 0.05
        bubbles.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.95, 0.95, 0], times: [0, 0.04, 0.94, 1])
        let wobble = SKAction.moveBy(x: 5 * unit, y: 0, duration: 0.3)
        wobble.timingMode = .easeInEaseOut
        bubbles.particleAction = .repeatForever(.sequence([wobble, wobble.reversed()]))
        bubbles.zPosition = Z.bubbles
        bubbles.advanceSimulationTime(TimeInterval(bubbles.particleLifetime))
        addChild(bubbles)
    }

    /// Specks of organic matter drifting slowly through the whole tank.
    private func addMarineSnow() {
        let snow = SKEmitterNode()
        snow.particleTexture = softDot()
        snow.particleColor = NSColor(red: 0.8, green: 0.92, blue: 0.92, alpha: 1)
        snow.particleColorBlendFactor = 1
        snow.position = CGPoint(x: size.width / 2, y: size.height / 2)
        snow.particlePositionRange = CGVector(dx: size.width, dy: size.height)
        snow.particleBirthRate = 5
        snow.particleLifetime = 40
        snow.particleSpeed = 5
        snow.particleSpeedRange = 4
        snow.emissionAngleRange = 2 * .pi
        snow.yAcceleration = -0.5
        snow.particleScale = 0.3
        snow.particleScaleRange = 0.25
        snow.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.35, 0.35, 0], times: [0, 0.15, 0.85, 1])
        snow.zPosition = Z.bubbles
        snow.advanceSimulationTime(40)
        addChild(snow)
    }

    /// Darkens the corners, as if looking into the tank through its glass.
    private func addVignette() {
        let shade = SKSpriteNode(texture: paint(CGSize(width: 64, height: 64)) { ctx in
            let centre = CGPoint(x: 32, y: 32)
            let fade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [rgb(0, 0, 0, 0), rgb(0, 0, 0, 0), rgb(0, 0, 0, 0.45)] as CFArray, locations: [0, 0.6, 1])!
            ctx.drawRadialGradient(fade, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 45, options: [.drawsAfterEndLocation])
        }, size: size)
        shade.anchorPoint = .zero
        shade.zPosition = Z.vignette
        addChild(shade)
    }
}
