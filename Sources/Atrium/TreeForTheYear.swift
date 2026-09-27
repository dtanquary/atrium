import SpriteKit
import TreeGrowth

@MainActor func treeForTheYear(size: CGSize) -> SKScene { TreeScene(size: size) }

extension WeatherGround {
    /// Cissbury Ring on the South Downs (Andy Li, CC0): a grassy hilltop whose own lone tree was painted out, with the
    /// hill falling away to fields and the sea haze. Low on the screen, so the tree stands against the sky.
    static let cissbury = WeatherGround(photo: SKTexture(image: NSImage(contentsOf: resource("tree-ground.heic")) ?? NSImage()),
                                        aux: SKTexture(image: NSImage(contentsOf: resource("tree-ground-aux.png")) ?? NSImage()),
                                        top: 0.36, horizon: 0.30)
}

/// When a tree does what through the year, as days of the year (1 for 1 January) in northern Illinois at 42°N, from
/// USA National Phenology Network records, Japan Meteorological Agency normals and a photo series of the same trees
/// (see docs/tree-for-the-year.md).
struct Phenology: Sendable, Equatable {
    /// Buds swell, break, and the leaves reach full size; full bloom (cherries; 0 if it has none).
    var swell, breaks, full, bloom: Double
    /// Colour starts, peaks, half the leaves are down, and the tree is bare.
    var onset, peak, half, bare: Double

    static let whiteOak = Phenology(swell: 105, breaks: 115, full: 144, bloom: 0, onset: 278, peak: 301, half: 313, bare: 318)
    static let japaneseMaple = Phenology(swell: 96, breaks: 103, full: 130, bloom: 0, onset: 289, peak: 306, half: 316, bare: 324)
    static let yoshinoCherry = Phenology(swell: 95, breaks: 108, full: 135, bloom: 109, onset: 275, peak: 293, half: 304, bare: 312)

    /// These dates where you are: spring comes about 4 days later for each degree further from the equator and autumn
    /// about 3 days sooner (Hopkins' rule, which JMA's normals bear out), and `warmer` degrees C of calibration brings
    /// spring 4 days a degree sooner and autumn 5 later. Each shift stops at 45 days, and latitudes are held to
    /// 28°–50°, since below about 30° warm winters don't chill the buds and the rule breaks down.
    /// ponytail: latitude alone is right in eastern North America and Japan but 6–10 weeks off in western Europe,
    /// which the Gulf Stream warms; local spring and autumn temperature normals (a cached Open-Meteo archive fetch)
    /// would fix it: 4·(5.5 − T[Mar–Apr]) days for spring and 5·(T[Oct–Nov] − 8.5) for autumn.
    func moved(latitude: Double, warmer: Double) -> Phenology {
        let l = min(max(abs(latitude), 28), 50)
        let spring = min(max(4 * (l - 42) - 4 * warmer, -45), 45), autumn = min(max(-3 * (l - 42) + 5 * warmer, -45), 45)
        return Phenology(swell: swell + spring, breaks: breaks + spring, full: full + spring, bloom: bloom > 0 ? bloom + spring : 0,
                         onset: onset + autumn, peak: peak + autumn, half: half + autumn, bare: bare + autumn)
    }

    /// How old a tree planted at 15 on `planted` is on `date`: a year older at each bud break since, when an oak puts
    /// on its whole year's growth in one flush.
    /// ponytail: a transplanted oak really grows at half speed for its first two years; nobody will see it.
    func age(planted: Date, on date: Date, latitude: Double) -> Int {
        let calendar = Calendar.current
        let years = calendar.component(.year, from: planted)...max(calendar.component(.year, from: planted), calendar.component(.year, from: date))
        return 15 + years.filter { year in
            guard let start = calendar.date(from: DateComponents(year: year)) else { return false }
            let day = (breaks - 1 - (latitude < 0 ? 182.625 : 0) + 365.25).truncatingRemainder(dividingBy: 365.25)
            let bud = start.addingTimeInterval(day * 86400)
            return bud > planted && bud <= date
        }.count
    }

    /// The day of the year at `date`, 1 to 366 with the time of day as a fraction, as a northern tree would see it:
    /// half a year on south of the equator, so the southern spring falls where the northern one does.
    static func day(_ date: Date, latitude: Double) -> Double {
        guard let year = Calendar.current.dateInterval(of: .year, for: date) else { return 1 }
        let day = date.timeIntervalSince(year.start) / 86400, length = year.duration / 86400
        return (latitude < 0 ? (day + length / 2).truncatingRemainder(dividingBy: length) : day) + 1
    }
}

/// One white oak on a hilltop, living through the real seasons where you are under Weather's sky and live weather:
/// buds and catkins, full leaf, autumn colour, leaf fall, dead leaves held through the winter, and branches that catch
/// the snow. The wind sways it, rain darkens its bark, and it's the same tree every day, grown from a seed saved the
/// first time it's shown, a year older each spring.
final class TreeScene: WeatherScene {
    nonisolated static let treeKnobs: [Knob] = [
        Knob(key: "tree.held", label: "Dead leaves in winter", range: 0...1, standard: 1, section: "Tree", format: .toggle),
        Knob(key: "tree.warmer", label: "Climate, °C warmer", range: -4...4, standard: 0, section: "Tree"),
        Knob(key: "tree.sway", label: "Sway", range: 0...2, standard: 1, section: "Tree", format: .times),
        Knob(key: "tree.previewDay", label: "Preview a day of the year", range: 0...1, standard: 0, section: "Preview", format: .toggle),
        Knob(key: "tree.day", label: "Day", range: 0...364, standard: 180, section: "Preview", format: .date, shownWhen: "tree.previewDay"),
    ] + WeatherScene.settings("tree")
    private static let held = treeKnobs[0], warmer = treeKnobs[1], sway = treeKnobs[2], previewDay = treeKnobs[3], day = treeKnobs[4]

    /// ponytail: white oak only; Japanese maple and Yoshino cherry are more `TreeSpecies` values and a menu, with
    /// their own leaves, bark and `Phenology`.
    private static let species = TreeSpecies.whiteOak
    private static let calendar = Phenology.whiteOak

    // The tree shader's inputs; see `shaderSource`.
    private let sunLight = SKUniform(name: "u_sun", vectorFloat3: .zero), skyLight = SKUniform(name: "u_sky", vectorFloat3: .zero)
    /// How much of the direct light comes from the left, from the right, and from ahead, behind the tree (backlit).
    private let lightFrom = SKUniform(name: "u_w", vectorFloat3: [1, 0, 0])
    private let seasonDay = SKUniform(name: "u_day", float: 180)
    /// The tree's calendar where you are (see `Phenology`): swell, break, full leaf, bloom; onset, peak, half down, bare.
    private let spring = SKUniform(name: "u_spring", vectorFloat4: .zero), autumn = SKUniform(name: "u_autumn", vectorFloat4: .zero)
    /// The whole tree's bend and the branches' sway as fractions of the sprite, and how much the leaves flutter.
    private let windUniform = SKUniform(name: "u_wind", vectorFloat3: .zero)
    /// How wet the bark is, how much snow lies on the branches, and whether dead leaves are held, 0…1 each.
    private let treeWeather = SKUniform(name: "u_wx", vectorFloat3: [0, 0, 1])
    /// The contact shadow's depth, and how much of the crown is in leaf (bare, only the wood's shadow is left).
    private let shade = SKUniform(name: "u_shade", vectorFloat2: [0.4, 1])
    private var wet = 0.0, snow = 0.0, lastTreeUpdate: TimeInterval?
    private var tree: SKNode?, treeKey: BakeKey?
    /// The bake's pixels per metre at the trunk over its width, to turn the wind's sway in metres into the sprite's.
    private var swayScale = 0.0

    init(size: CGSize, conditions: Conditions? = nil) {
        super.init(size: size, conditions: conditions, ground: .cissbury, settings: "tree")
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - The tree's bake

    /// This Mac's tree: a seed and the day it was planted, saved the first time it's shown.
    private static var planting: (seed: UInt64, planted: Date) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "tree.seed") == nil {
            defaults.set(Int.random(in: 1...Int(Int32.max)), forKey: "tree.seed")
            defaults.set(Date(), forKey: "tree.planted")
        }
        return (UInt64(max(defaults.integer(forKey: "tree.seed"), 1)), defaults.object(forKey: "tree.planted") as? Date ?? Date())
    }

    private struct BakeKey: Hashable { var seed: UInt64, age: Int, width: Int, height: Int }

    /// A baked tree, its slabs' textures and its shadow's, shared by every copy of the scene the same size (another
    /// display, or the Settings preview), so its memory isn't doubled. The last few are kept.
    private static var bakes: [(key: BakeKey, bake: TreeBake, textures: [SKTexture], shadow: SKTexture)] = []

    /// The leaf cards (the six oak leaves' colour, normals and translucency) and the bark, decoded once.
    private static let materials: (atlas: LeafAtlas, bark: BarkImage) = {
        func pixels(_ name: String) -> (w: Int, h: Int, rgba: [UInt8]) {
            guard let source = CGImageSourceCreateWithURL(resource(name) as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return (1, 1, [0, 0, 0, 0]) }
            let (w, h) = (image.width, image.height)
            var rgba = [UInt8](repeating: 0, count: w * h * 4)
            rgba.withUnsafeMutableBytes { bytes in
                let context = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                context?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            return (w, h, rgba)
        }
        let colour = pixels("tree-leaves.heic"), normal = pixels("tree-leaves-normal.heic"), scatter = pixels("tree-leaves-scatter.heic")
        let bark = pixels("tree-bark.heic")
        return (LeafAtlas(width: colour.w, height: colour.h, color: colour.rgba, premultiplied: true, normal: normal.rgba, scatter: scatter.rgba,
                          cells: (0..<6).map { SIMD4<Int>($0 * 256, 0, 256, 256) }),
                BarkImage(width: bark.w, height: bark.h, rgba: bark.rgba))
    }()

    /// Which tree to show now: this Mac's, at its age today, for this screen at 2x.
    private var wantedKey: BakeKey {
        let (seed, planted) = Self.planting, here = Location.shared.coordinate
        let age = Self.calendar.moved(latitude: here.latitude, warmer: Self.warmer.value).age(planted: planted, on: now, latitude: here.latitude)
        return BakeKey(seed: seed, age: age, width: Int(size.width * 2), height: Int(size.height * 2))
    }

    /// Bakes the tree for `key`, or finds it already baked. About 0.2 s at 15 years old, 0.5 s at 30.
    /// ponytail: on the main thread, as Weather's first build is; move it off once the tree is old enough (about 35)
    /// for a bake to take over half a second, and crossfade when it lands.
    private static func baked(_ key: BakeKey, trunk: SIMD2<Double>, horizon: Double) -> (bake: TreeBake, textures: [SKTexture], shadow: SKTexture) {
        if let hit = bakes.first(where: { $0.key == key }) { return (hit.bake, hit.textures, hit.shadow) }
        let bake = TreeGrowth.bake(species, seed: key.seed, age: key.age, pixels: SIMD2(key.width, key.height), horizon: horizon,
                                   trunkBase: trunk, atlas: materials.atlas, bark: materials.bark)
        let size = CGSize(width: bake.size.x, height: bake.size.y)
        let textures = bake.slabs.flatMap { slab in
            [(slab.woodLight, false), (slab.woodExtra, false), (slab.leafLight, false), (slab.leafSeed, true)].map { data, nearest in
                let texture = SKTexture(data: Data(data), size: size)
                texture.filteringMode = nearest ? .nearest : .linear
                return texture
            }
        }
        let shadow = SKTexture(data: Data(bake.shadow.rgba), size: CGSize(width: bake.shadow.size.x, height: bake.shadow.size.y))
        bakes = Array((bakes + [(key, bake, textures, shadow)]).suffix(3))
        return (bake, textures, shadow)
    }

    override func addForeground() {
        // The trunk stands on the photo's grass just below the brow, 42.5% across and 22% of the way down the photo.
        let photo = WeatherGround.cissbury.photo.size(), aspect = photo.width / max(photo.height, 1), top = WeatherGround.cissbury.top
        let shown = max(size.width, size.height * top * aspect) / aspect / size.height
        let key = wantedKey
        let (bake, textures, shadowTexture) = Self.baked(key, trunk: [0.425, Double(top - 0.22 * shown)], horizon: WeatherGround.cissbury.horizon)
        let group = SKNode()
        // The bake is at 2x, so a canvas pixel is half a point; y runs down in the canvas.
        func place(_ node: SKSpriteNode, origin: SIMD2<Int>, span: SIMD2<Int>) {
            node.anchorPoint = .zero
            node.size = CGSize(width: CGFloat(span.x) / 2, height: CGFloat(span.y) / 2)
            node.position = CGPoint(x: CGFloat(origin.x) / 2, y: size.height - CGFloat(origin.y + span.y) / 2)
        }
        // A soft contact shadow on the grass: the light the crown (or, bare, the wood) blocks straight down. Only in
        // front of the trunk and just behind it: beyond the brow the hill falls away to the far fields.
        let shadow = SKSpriteNode(texture: shadowTexture)
        place(shadow, origin: bake.shadow.origin, span: bake.shadow.span)
        shadow.zPosition = 5.5
        shadow.blendMode = .multiply
        let foot = (Double(bake.shadow.origin.y + bake.shadow.span.y) - bake.trunkBase.y) / Double(bake.shadow.span.y)
        shadow.shader = SKShader(source: """
            void main() {
                // Blurred, more up and down than across: seen this low, the shade under the crown is a thin band.
                vec2 px = vec2(\(2.0 / Double(bake.shadow.size.x)), \(3.0 / Double(bake.shadow.size.y)));
                vec4 s = vec4(0.0);
                for (int i = -2; i <= 2; i++) {
                    for (int j = -2; j <= 2; j++) { s += texture2D(u_texture, v_tex_coord + vec2(float(i), float(j)) * px); }
                }
                s /= 25.0;
                float behind = smoothstep(\(foot - 0.02), \(foot + 0.12), v_tex_coord.y);
                gl_FragColor = vec4(vec3(1.0 - u_shade.x * mix(s.g, s.r, u_shade.y) * (1.0 - behind)), 1.0);
            }
            """, uniforms: [shade])
        group.addChild(shadow)
        let node = SKSpriteNode(color: .clear, size: .zero)
        place(node, origin: bake.origin, span: bake.size)
        node.zPosition = 6
        let names = (0..<bake.slabs.count).flatMap { k in ["u_woodL\(k)", "u_woodX\(k)", "u_leafL\(k)", "u_leafS\(k)"] }
        let frame = SIMD4<Float>(Float(node.position.x / size.width), Float(node.position.y / size.height),
                                 Float(node.size.width / size.width), Float(node.size.height / size.height))
        node.shader = SKShader(source: Self.shaderSource(bake, age: key.age), uniforms: zip(names, textures).map {
            SKUniform(name: $0, texture: $1)
        } + [WallpaperTime.now, seasonDay, spring, autumn, sunLight, skyLight, lightFrom, windUniform, treeWeather, SKUniform(name: "u_frame", vectorFloat4: frame),
             skyBefore, skyAfter, skyBlend, cameraUniforms.lens, groundHazeLit, deck, fog, groundColour])
        group.addChild(node)
        addChild(group)
        tree = group
        treeKey = key
        swayScale = bake.pixelsPerMetre / Double(bake.size.x)
        updateTree(dt: 0)
    }

    // MARK: - Light, season and weather

    /// Lights the tree like the ground: the direct light split by where it comes from as seen from here, left or
    /// right of the view (behind us) or ahead, behind the tree, where the bake's third light stands low.
    override func relight(direct: Sky.Vector, from: Sky.Vector, sky: Sky.Vector) {
        let across = dot(from, viewpoint.right), ahead = dot(from, viewpoint.forward)
        let back = smoothstep(-0.15, 0.5, ahead), side = 1 - back
        lightFrom.vectorFloat3Value = SIMD3<Float>(Float(smoothstep(0.3, -0.3, across) * side), Float(smoothstep(-0.3, 0.3, across) * side), Float(back))
        sunLight.vectorFloat3Value = SIMD3<Float>(direct)
        skyLight.vectorFloat3Value = SIMD3<Float>(sky)
        // The contact shadow is deepest in sunshine, when the crown blocks the direct light too.
        let sunny = (direct.sum() / max(direct.sum() + sky.sum(), 1e-6))
        shade.vectorFloat2Value.x = Float(0.2 + 0.25 * sunny)
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        let dt = currentTime - (lastTreeUpdate ?? currentTime)
        if lastTreeUpdate == nil || dt >= 1 { lastTreeUpdate = currentTime; updateTree(dt: min(max(dt, 0), 60)) }
    }

    /// The season, rain drying off the bark and snow on the branches, and a new bake when the tree turns a year older.
    private func updateTree(dt: Double) {
        let here = Location.shared.coordinate
        let d = Phenology.day(now, latitude: here.latitude), c = Self.calendar.moved(latitude: here.latitude, warmer: Self.warmer.value)
        seasonDay.floatValue = Float(d)
        spring.vectorFloat4Value = SIMD4<Float>(Float(c.swell), Float(c.breaks), Float(c.full), Float(c.bloom))
        autumn.vectorFloat4Value = SIMD4<Float>(Float(c.onset), Float(c.peak), Float(c.half), Float(c.bare))
        grassSeason.vectorFloat4Value = SIMD4<Float>(Self.grass(greenness: Self.greenness(day: d, c)), 1)
        // Bark is soaked while it rains and dries over about three hours; snow on the branches falls or melts off
        // over about two once it stops and there's none lying.
        let code = conditions.code
        let raining = (51...67).contains(code) || (80...82).contains(code) || code >= 95 || (LiveWeather.shared.latest?.precipitationTotal ?? 0) > 0.2
        let snowy = (71...77).contains(code) || code == 85 || code == 86 || conditions.snowDepth > 0.005
        wet = raining && !snowy ? 1 : max(wet - dt / 10800, 0)
        snow = snowy ? 1 : max(snow - dt / 7200, 0)
        let v = 0.9 * conditions.wind / 3.6 * Self.sway.value // m/s at the crown, a little under the 10 m wind
        let pull = Float(pow(v, 1.3) * swayScale)
        windUniform.vectorFloat3Value = [0.012 * pull, 0.004 * pull, Float(min(v / 8, 1))]
        treeWeather.vectorFloat3Value = [Float(wet), Float(snow), Float(Self.held.value)]
        // How much of the crown is in leaf, for its shadow: the leaves unfolding to falling, and a young oak's held ones.
        let late = d > 200, heldLeaves = Self.held.value * 0.4
        shade.vectorFloat2Value.y = Float(late ? max(1 - smoothstep(c.peak - 4, c.bare, d), heldLeaves) : max(smoothstep(c.breaks, c.full, d), heldLeaves * (1 - smoothstep(c.breaks - 5, c.breaks, d))))
        if live, tree != nil, wantedKey != treeKey { tree?.removeFromParent(); addForeground() } // a year older, or a new screen
    }

    /// How green the grass is on day `d`, 0 dormant straw to 1 at its peak in May and June, after photos and
    /// PhenoCam records of northern Illinois and Wisconsin grass (docs/tree-for-the-year.md): it greens up from about
    /// three weeks before the oak's buds break (half green as they do) to ten days after, so the hill is green under a
    /// still-bare tree; it cures a little in late summer; and it stays green until the hard freezes a few days after
    /// the tree is bare, then fades to straw over four weeks.
    /// ponytail: no droughts; a dry spell browns unwatered grass about every other summer at 42°N, which a few weeks
    /// of Open-Meteo rain and evaporation would show.
    static func greenness(day d: Double, _ c: Phenology) -> Double {
        guard d > 200 else { return smoothstep(c.breaks - 24, c.breaks + 10, d) }
        return (1 - 0.15 * smoothstep(190, 225, d) * (1 - smoothstep(250, 290, d))) * (1 - smoothstep(c.bare + 2, c.bare + 30, d))
    }

    /// What to multiply the ground photo's grass by for `greenness`. Measured in linear light, dormant straw is
    /// R/G 1.30, B/G 0.58 and 1.6 times as bright; peak green is R/G 0.70, B/G 0.30; the photo's grass is R/G 0.96,
    /// B/G 0.27 (about 0.6 green, as in late April).
    static func grass(greenness g: Double) -> SIMD3<Float> {
        let rg = 1.30 + (0.70 - 1.30) * g, bg = 0.58 + (0.30 - 0.58) * g, bright = 1.6 + (1.0 - 1.6) * g
        let scale = bright * (0.2126 * 0.96 + 0.7152 + 0.0722 * 0.27) / (0.2126 * rg + 0.7152 + 0.0722 * bg)
        return SIMD3<Float>(SIMD3(rg / 0.96, 1, bg / 0.27) * scale).squareRoot()
    }

    /// Now, moved to the previewed day of this year while previewing, keeping the time of day (or the previewed one).
    override var now: Date {
        let base = super.now
        guard live, Self.previewDay.value > 0.5 else { return base }
        let calendar = Calendar.current, start = calendar.dateInterval(of: .year, for: base)?.start ?? base
        let dayStart = calendar.startOfDay(for: base)
        return calendar.date(byAdding: .day, value: Int(Self.day.value), to: start)?.addingTimeInterval(base.timeIntervalSince(dayStart)) ?? base
    }
}

extension TreeScene {
    /// Draws the baked slabs back to front (slab 0 is the farthest), each its wood, the snow on it, then its leaves.
    /// Each leaf's colour and whether it's on the tree come from its baked seeds and the day of the year, so the season
    /// needs no rebake. The tree is lit like the ground, and hazed, fogged and dimmed at night like the grass it stands
    /// on. Wind bends the whole tree like a cantilever from its trunk base and sways the branches, with a phase that
    /// varies smoothly over the crown, all by u_now, so it's the same at any frame rate.
    /// `gain` takes the tree's real albedos (a leaf is about 0.08) up to the ground photo's, whose colours carry its
    /// own exposure (grass about 0.25); `ambient` is the skylight inside the crown. Both were matched against the
    /// reference crowns' contrast under this tone map.
    static func shaderSource(_ bake: TreeBake, age: Int, gain: Double = 3, ambient: Double = 0.6) -> String {
        let s = species
        func lin(_ c: SIMD3<Double>) -> String {
            String(format: "vec3(%.5f, %.5f, %.5f)", pow(c.x / 255, 2.2), pow(c.y / 255, 2.2), pow(c.z / 255, 2.2))
        }
        func f(_ x: Double) -> String { String(format: "%.5f", x) }
        let bark = SIMD3(pow(s.bark.x / 255, 2.2), pow(s.bark.y / 255, 2.2), pow(s.bark.z / 255, 2.2))
        let tint = bark / (bark * SIMD3<Double>(0.3, 0.59, 0.11)).sum()
        let w = Double(bake.size.x), h = Double(bake.size.y), bottom = Double(bake.origin.y) + h
        let baseV = (bottom - bake.trunkBase.y) / h, topV = (bottom - (bake.trunkBase.y - bake.height * bake.pixelsPerMetre)) / h
        let young = 0.5 * (1 - smoothstep(15, 40, Double(age)))
        var source = """
        vec3 decode(vec3 c) { return c * c * 4.0; }
        vec3 pal3(vec3 a, vec3 b, vec3 c, float t) {
            t = clamp(t, 0.0, 0.999) * 2.0;
            return mix(mix(a, b, clamp(t, 0.0, 1.0)), c, clamp(t - 1.0, 0.0, 1.0));
        }
        vec3 pal4(vec3 a, vec3 b, vec3 c, vec3 d, float t) {
            t = clamp(t, 0.0, 0.999) * 3.0;
            return mix(mix(mix(a, b, clamp(t, 0.0, 1.0)), c, clamp(t - 1.0, 0.0, 1.0)), d, clamp(t - 2.0, 0.0, 1.0));
        }
        // A leaf's colour (rgb) and whether it's on the tree (a) on day d, from its seeds (ambient, turn: the top and
        // the sunny outside first, whole branches together; fall or held; tint and underside) and the calendar.
        // `heldOn` 0 lets the held leaves fall, last.
        vec4 leafState(vec4 sd, float d, vec4 sp, vec4 au, float heldOn) {
            float turn = sd.g;
            float heldBit = step(0.79, sd.b);
            float held = heldBit * heldOn;
            float fall = clamp(mix(sd.b / 0.78, (sd.b - 0.8) / 0.2, heldBit), 0.0, 1.0) * (1.0 - held);
            float under = step(0.5, sd.a);
            float tint = clamp((sd.a - 0.51 * under) / 0.49, 0.0, 1.0);
            // Spring: each leaf unfolds on its own day, a faint rose-grey for a week, catkin gold at the crown's
            // scale, lime for a fortnight, and summer green (warmer or cooler by branch) by five weeks after full leaf.
            float brk = sp.y + fall * 16.0;
            float grow = smoothstep(brk, brk + 3.0, d), since = d - brk;
            vec3 col = pal3(\(lin(s.green[0])), \(lin(s.green[1])), \(lin(s.green[2])), tint);
            col *= mix(vec3(1.0), mix(vec3(1.06, 1.04, 0.86), vec3(0.93, 0.98, 1.08), turn), \(f(s.sectorTint)));
            col = mix(col, \(lin(s.lime)), 1.0 - smoothstep(sp.z, sp.z + 35.0, d));
            col = mix(col, \(lin(s.catkin)), 0.8 * (1.0 - smoothstep(10.0, 18.0, since)));
            col = mix(col, \(lin(s.rose)), 0.5 * (1.0 - smoothstep(2.0, 7.0, since)));
            // Autumn: wine to rust (a young tree runs rose-red), browning, then each leaf falls on its own day.
            float sh = (turn - 0.5) * \(f(s.autumnSpread));
            float c = smoothstep(au.x + sh, au.y + sh, d);
            vec3 aut = mix(pal4(\(lin(s.autumn[0])), \(lin(s.autumn[1])), \(lin(s.autumn[2])), \(lin(s.autumn[3])), tint), \(lin(s.youngRed)), \(f(young)));
            col = mix(col, aut, c);
            float bf = smoothstep(au.y + sh, au.w + 10.0 + sh, d);
            col = mix(col, \(lin(s.brown)), bf);
            float tf = au.y - 4.0 + fall * (au.w - au.y + 4.0) + sh * 0.5;
            float late = step((sp.z + au.x) * 0.5, d);
            float present = grow * mix(1.0, 1.0 - smoothstep(tf - 1.0, tf + 1.0, d), late);
            // Held leaves go tan after the peak and stay, fading to pale buff by March, until the new buds break.
            vec3 heldCol = mix(\(lin(s.held)), \(lin(s.buff)), (1.0 - late) * smoothstep(20.0, 80.0, d)) * (0.9 + 0.2 * tint);
            col = mix(col, mix(col, heldCol, smoothstep(au.y, au.z, d)), held * late);
            present = mix(present, grow, held * late);
            float pre = held * (1.0 - late) * (1.0 - step(sp.y, d));
            present = mix(present, 1.0 - smoothstep(sp.y - 5.0, sp.y, d), pre);
            col = mix(col, heldCol, pre);
            float dead = mix(pre, max(held, bf), late);
            vec3 underc = mix(\(lin(s.under)), \(lin(s.held)) * 1.3, dead);
            col = mix(col, col * 0.6 + underc * 0.4 * (1.0 - 0.7 * c * (1.0 - dead)), under);
            return vec4(col, present);
        }

        void main() {
            vec2 uv = v_tex_coord;
            float t = u_now;
            float hgt = clamp((uv.y - \(f(baseV))) / \(f(topV - baseV)), 0.0, 1.2);
            float ph = 6.2832 * (0.5 + 0.25 * sin(uv.x * 9.0 + uv.y * 5.0) + 0.25 * sin(uv.x * 4.0 - uv.y * 11.0 + 1.3));
            float gust = 0.75 + 0.25 * sin(6.2832 * 0.07 * t + 1.0);
            vec2 q = uv - gust * vec2(u_wind.x * hgt * hgt * (0.6 + 0.4 * sin(6.2832 * 0.3 * t)) + u_wind.y * hgt * sin(6.2832 * 0.8 * t + ph),
                                      u_wind.y * 0.35 * hgt * sin(6.2832 * 1.04 * t + ph * 1.7) * \(f(w / h)));
            // Green light bounced around inside a leafy crown, and snow in this light (as Weather's snowy ground).
            float greenf = smoothstep(u_spring.y, u_spring.z, u_day) * (1.0 - smoothstep(u_autumn.x, u_autumn.y, u_day));
            vec3 bounce = vec3(0.12, 0.2, 0.06) * 0.5 * (u_sky.r + u_sky.g + u_sky.b) / 1.8 * greenf;
            vec3 snowCol = 0.9 * (u_sky + u_sun * (u_w.x + u_w.y) * 0.4);
            vec3 bark = vec3(\(f(tint.x)), \(f(tint.y)), \(f(tint.z)));
            vec3 acc = vec3(0.0);
            float accA = 0.0;

        """
        for k in 0..<bake.slabs.count {
            source += """
                {
                    vec4 wl = texture2D(u_woodL\(k), q);
                    vec4 wx = texture2D(u_woodX\(k), q);
                    vec3 wc = bark * (u_sun * dot(u_w, wl.rgb * wl.rgb * 0.35) + u_sky * (wx.r * wx.r * 0.35 * \(f(ambient))));
                    // Wet bark is about two stops darker, with a sheen of sky on the lit ridges.
                    wc = mix(wc, wc * 0.3 + 0.05 * (u_sky + u_sun * 0.3) * smoothstep(0.15, 0.4, wx.r), u_wx.x);
                    acc = mix(acc, \(f(gain)) * wc, wl.a);
                    accA = mix(accA, 1.0, wl.a);
                    float sa = smoothstep(0.95 - 0.6 * u_wx.y, 1.1 - 0.6 * u_wx.y, wx.g) * step(0.001, u_wx.y);
                    acc = mix(acc, snowCol, sa);
                    accA = mix(accA, 1.0, sa);
                    vec4 ll = texture2D(u_leafL\(k), q);
                    vec4 sd = texture2D(u_leafS\(k), q);
                    vec3 l3 = ll.rgb * ll.rgb * 1.6;
                    float amb = sd.r * sd.r * 1.6 * \(f(ambient));
                    vec4 st = leafState(sd, u_day, u_spring, u_autumn, u_wx.z);
                    vec3 lc = st.rgb;
                    float lum = dot(lc, vec3(0.3, 0.59, 0.11));
                    lc = mix(lc, max(vec3(lum) + (lc - vec3(lum)) * 1.3, 0.0) * 0.7, u_wx.x);
                    float fl = 1.0 + 0.22 * gust * u_wind.z * sin(6.2832 * 2.0 * t + sd.g * 37.0 + sd.b * 91.0);
                    float direct = dot(u_w, l3) * fl;
                    // Light through a leaf, seen against a low Sun: brighter, more saturated, the blue gone.
                    float tl = dot(lc, vec3(0.3, 0.59, 0.11));
                    vec3 through = max(vec3(tl) + (lc - vec3(tl)) * 1.5, 0.0) * vec3(1.9, 1.7, 0.6);
                    vec3 c = lc * (u_sun * direct + u_sky * amb + bounce * clamp(1.0 - amb, 0.0, 1.0))
                        + 0.018 * u_sun * direct + u_w.z * l3.b * u_sun * through * 0.45;
                    c *= \(f(gain));
                    // Snow settles on the leaves open to the sky above that face up: the tops of held clusters.
                    c = mix(c, snowCol, smoothstep(0.62 - 0.35 * u_wx.y, 0.72 - 0.35 * u_wx.y, wx.b) * step(0.001, u_wx.y));
                    float a = ll.a * st.a;
                    acc = mix(acc, c, a);
                    accA = mix(accA, 1.0, a);
                }

            """
        }
        source += """
            vec3 land = acc / max(accA, 0.0001);
            // As the ground at the tree's foot: the night's blue-grey, the haze and the fog (see Weather's groundShader).
            float lum = dot(land, vec3(0.2126, 0.7152, 0.0722));
            land = mix(vec3(lum) * vec3(0.62, 0.85, 1.45), land, u_colour);
            vec2 above = vec2(u_frame.x + uv.x * u_frame.z, (u_cam.z + 0.03 - u_cam.w) / (1.0 - u_cam.w));
            vec3 haze = mix(decode(texture2D(u_before, above).rgb), decode(texture2D(u_after, above).rgb), u_blend) * u_hazeLit;
            haze = mix(vec3(dot(haze, vec3(0.2126, 0.7152, 0.0722))) * vec3(0.7, 0.85, 1.25), haze, u_hazeLit);
            float under = min(u_deck.a * 2.0, 0.95);
            haze = mix(min(haze, vec3(mix(40.0, 1.5, under))), vec3(dot(min(haze, vec3(1.5)), vec3(0.3, 0.5, 0.2))) * 0.08 + u_deck.rgb * 0.9, under);
            // The tree is about 50 m off. The ground's depth map puts the grass at its foot further, which fogs it the
            // same as that grass, but haze over its dark crown would veil it.
            float far = 1.6;
            float through = exp(-0.05 * 0.3);
            land = land * through + haze * (1.0 - through);
            vec3 fogCol = mix(haze, vec3(dot(haze, vec3(0.3, 0.5, 0.2))), 0.7) * 0.95;
            land = mix(land, fogCol, (1.0 - exp(-far * u_fog * 0.45)) * 0.97);
            gl_FragColor = vec4(sqrt(1.0 - exp(-land)) * accA, accA);
        }
        """
        return source
    }
}

private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}
