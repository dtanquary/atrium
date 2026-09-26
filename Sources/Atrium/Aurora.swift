import SpriteKit

/// Aurora colours, bottom to top: lower fringe, body, upper, crown. All real emissions and their mixes: 557.7 nm oxygen
/// green, 630 nm oxygen red high up, nitrogen pink along the lower edge in strong displays, nitrogen blue and violet
/// where the top is sunlit, yellow where green and red overlap, and the white of a faint display.
let auroraPalettes: [(name: String, colours: [SIMD3<Float>])] = [
    ("Green", [[0.25, 1.0, 0.55], [0.2, 1.0, 0.5], [0.2, 0.85, 0.55], [0.6, 0.25, 1.0]]),   // the classic
    ("Storm", [[1.0, 0.3, 0.6], [0.2, 1.0, 0.5], [0.7, 0.8, 0.35], [1.0, 0.15, 0.2]]),      // pink edge, green, red crown
    ("Red", [[0.3, 0.95, 0.5], [1.0, 0.35, 0.3], [1.0, 0.15, 0.2], [0.75, 0.1, 0.3]]),       // as seen from mid-latitudes
    ("Pink", [[1.0, 0.25, 0.6], [1.0, 0.45, 0.75], [0.75, 0.4, 1.0], [0.5, 0.25, 1.0]]),
    ("Purple", [[0.9, 0.3, 0.8], [0.6, 0.35, 1.0], [0.45, 0.3, 1.0], [0.8, 0.2, 0.5]]),
    ("Blue", [[0.25, 0.9, 0.7], [0.3, 0.6, 1.0], [0.35, 0.4, 1.0], [0.55, 0.3, 1.0]]),      // sunlit nitrogen
    ("Yellow", [[0.4, 1.0, 0.45], [0.8, 1.0, 0.35], [1.0, 0.8, 0.3], [1.0, 0.35, 0.25]]),   // green and red overlapping
    ("White", [[0.85, 1.0, 0.92], [0.8, 0.95, 0.9], [0.75, 0.85, 0.95], [0.65, 0.7, 0.95]]), // a faint display
]

/// Curtains of aurora shading from one real colour to the next, fine vertical rays drifting through them, under stars,
/// over a real snowy range lit by their light. The palette is pinned in Settings or rolled on each load.
@MainActor func aurora(size: CGSize) -> SKScene {
    let c = (auroraPalettes.first { $0.name == UserDefaults.standard.string(forKey: "aurora.palette") }
        ?? auroraPalettes.randomElement()!).colours
    let scene = shaderScene(size: size, source: shaderCommon + """
    void main() {
        float aspect = u_size.x / u_size.y;
        vec2 uv = v_tex_coord;
        vec2 p = uv * vec2(aspect, 1.0);
        float t = u_time;

        vec3 col = mix(vec3(0.02, 0.05, 0.08), vec3(0.004, 0.008, 0.03), smoothstep(0.1, 1.0, uv.y));
        col += vec3(0.85, 0.9, 1.0) * starField(uv * u_size, 11.0, 0.3, t);

        // three curtains: a folding lower edge with a bright rim, light fading upward through the palette,
        // fine rays sheared along the folds, and patches that come and go along their length
        vec3 aurora = vec3(0.0);
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float x = p.x * (0.6 + 0.25 * fi) + fi * 3.1;
            float fold = sin(x * 2.4 + t * 0.04 + fi * 1.7) + 0.6 * sin(x * 5.3 - t * 0.03 + fi);
            float edge = 0.5 + 0.1 * fi + 0.045 * fold + 0.08 * (noise(vec2(x * 0.7 + t * 0.01, fi * 4.0)) - 0.5);
            float h = uv.y - edge;
            float rim = exp(-abs(h) * 70.0);
            float body = smoothstep(-0.004, 0.004, h) * exp(-max(h, 0.0) * 9.0);
            float tail = smoothstep(0.02, 0.1, h) * exp(-max(h, 0.0) * 4.0) * 0.4;
            float below = exp(min(h, 0.0) * 30.0) * 0.15;
            float rx = x * 45.0 + fold * 3.0 + t * 0.15;
            float rays = noise(vec2(rx, fi * 5.0 + t * 0.05)) * 0.7 + noise(vec2(rx * 2.3, fi * 9.0)) * 0.3;
            rays = 0.25 + 1.4 * rays * rays;
            float pn = noise(vec2(x * 0.6 - t * 0.008, fi * 3.0 + 1.0));
            float patches = smoothstep(0.25, 0.7, pn);
            // colour by height above the edge, with the bands drifting up and down along the curtain
            float ch = h + (0.5 - pn) * 0.09;
            vec3 hue = mix(u_fringe, u_body, smoothstep(-0.01, 0.012, ch));
            hue = mix(hue, u_upper, smoothstep(0.03, 0.14, ch));
            hue = mix(hue, u_crown, smoothstep(0.12, 0.3, ch));
            aurora += hue * ((body + rim * 0.7 + tail) * rays + below) * patches * (1.0 - 0.25 * fi);
        }
        col += (1.0 - exp(-aurora * 0.9)) * smoothstep(1.12, 0.72, uv.y);   // soft clip where curtains overlap

        col = grade(col, 0.3, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """, uniforms: [
        SKUniform(name: "u_fringe", vectorFloat3: c[0]), SKUniform(name: "u_body", vectorFloat3: c[1]),
        SKUniform(name: "u_upper", vectorFloat3: c[2]), SKUniform(name: "u_crown", vectorFloat3: c[3]),
    ], knobs: gradeKnobs("aurora"))
    scene.addChild(auroraGround(size: size, palette: c, grade: (scene as! ShaderScene).knobs.map(\.uniform)))
    return scene
}

/// The Tetons in winter from Teton Point (NPS photo by A. Falgoust, public domain,
/// commons.wikimedia.org/wiki/File:Teton_Point_Turnout_in_Winter_(52098766554).jpg) with the sky cut out, stored as its
/// albedo at half scale: its own daylight, haze and colour cast were taken out offline. `aurora-ground-aux` holds each
/// point's distance in red (log, estimated with Depth Anything V2) and open snow in green.
@MainActor private enum AuroraGround {
    static let photo = SKTexture(image: NSImage(contentsOf: resource("aurora-ground.heic")) ?? NSImage())
    static let aux = SKTexture(image: NSImage(contentsOf: resource("aurora-ground-aux.png")) ?? NSImage())
    /// Where the highest summit sits: down from the top of the photo as a fraction of its height, and up the screen.
    static let summit = 60.0 / 1390, peak = 0.38
}

/// The snowy range and the flats in front of it, as seen on a real long exposure: lit by a diffuse light that's
/// part starlight and part the aurora's own colour, bluer and greyer as the eye sees in the dark, hazing into the
/// glow above the skyline with distance, and glinting where near snow catches the light.
@MainActor private func auroraGround(size: CGSize, palette c: [SIMD3<Float>], grade: [SKUniform]) -> SKNode {
    let photo = AuroraGround.photo.size(), aspect = photo.width / max(photo.height, 1)
    let peak = size.height * AuroraGround.peak, summit = AuroraGround.summit
    let width = max(size.width, peak / (1 - summit) * aspect), height = width / aspect
    let top = peak + summit * height
    let ground = SKSpriteNode(texture: AuroraGround.photo, size: CGSize(width: width, height: height))
    ground.anchorPoint = CGPoint(x: 0.5, y: 1)
    ground.position = CGPoint(x: size.width / 2, y: top)
    ground.zPosition = 1
    // The light: starlight blue mixed with the aurora's body and upper colours (squared, roughly linear), each
    // scaled to unit brightness so only their hue mixes, then set so lit snow is a fraction of the aurora's peak.
    func unit(_ v: SIMD3<Float>) -> SIMD3<Float> { v / max((v * [0.2126, 0.7152, 0.0722]).sum(), 1e-4) }
    let tint = unit(0.2 * c[0] * c[0] + 0.6 * c[1] * c[1] + 0.2 * c[2] * c[2])
    let light = unit(0.6 * unit([0.55, 0.72, 1.0]) + 0.4 * tint) * 0.035
    let glow = SIMD3<Float>(0.02, 0.05, 0.08) + c[1] * 0.04
    ground.shader = SKShader(source: shaderCommon + """
    void main() {
        vec4 photo = texture2D(u_texture, v_tex_coord);
        vec2 aux = texture2D(u_aux, v_tex_coord).rg;
        vec3 albedo = 2.0 * pow(photo.rgb / max(photo.a, 0.004), vec3(2.2));
        vec3 col = albedo * u_light;
        col = mix(col, dot(col, vec3(0.2126, 0.7152, 0.0722)) * vec3(0.78, 0.92, 1.2), 0.3);   // Purkinje
        float far = (pow(32.0, aux.r) - 1.0) / 3.1;
        col = mix(col, pow(u_glow, vec3(2.2)), 1.0 - exp(-0.06 * far));
        // crystals on the near snow catching the light, twinkling slowly
        vec2 pts = u_frame.xy + v_tex_coord * u_frame.zw;
        float glint = starField(pts, 3.0, 0.15, u_time * 3.0) * aux.g * smoothstep(0.6, 0.1, aux.r);
        col += glint * vec3(0.85, 0.95, 1.0) * 0.3;
        col = grade(pow(col, vec3(1.0 / 2.2)), 0.3, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(pts * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0) * photo.a;
    }
    """, uniforms: [
        SKUniform(name: "u_aux", texture: AuroraGround.aux), SKUniform(name: "u_light", vectorFloat3: light),
        SKUniform(name: "u_glow", vectorFloat3: glow),
        SKUniform(name: "u_frame", vectorFloat4: [Float((size.width - width) / 2), Float(top - height), Float(width), Float(height)]),
    ] + grade)
    return ground
}
