// Hourglass method probe: the bake of pile.py in Swift, to time it as the app would run it (one thread, -O).
// The same model: a cap at the angle of maximum stability under the stream, a flank that slides to the angle of
// repose once it lags far enough behind it, and the deposit map from the profile's history.
// swiftc -O bake.swift -o bake && ./bake 3024 982 900 0.1
import Foundation

let args = CommandLine.arguments
let W = Int(args.count > 1 ? args[1] : "3024")!, H = Int(args.count > 2 ? args[2] : "982")!
let period = Double(args.count > 3 ? args[3] : "900")!, dt = Double(args.count > 4 ? args[4] : "0.1")!
let scale = Double(W) / 3024   // a 6K display's bulb is the same glass at its own pixels
let sr = tan(32 * Double.pi / 180), sm = tan(35 * Double.pi / 180)
var rng = SystemRandomNumberGenerator()
func uniform(_ a: Double, _ b: Double) -> Double { Double.random(in: a...b, using: &rng) }

let x0 = W / 2, half = 0.47 * Double(W)
var floor = [Double](repeating: Double(H), count: W), ceil = [Double](repeating: 0, count: W), inside = [Bool](repeating: false, count: W)
for c in 0..<W {
    let u = min(abs(Double(c) + 0.5 - Double(W) / 2) / half, 1)
    guard u < 1 else { continue }
    floor[c] = 0.06 * Double(H) + 0.30 * Double(H) * (1 - pow(1 - u * u * u, 1.0 / 3))
    let cone = Double(H) - 8 - abs(Double(c) + 0.5 - Double(W) / 2) * tan(38 * Double.pi / 180)
    ceil[c] = min(cone, 0.94 * Double(H) - 0.30 * Double(H) * (1 - pow(1 - u * u * u, 1.0 / 3)))
    inside[c] = ceil[c] > floor[c] + 2
}
var capacity = 0.0
for c in 0..<W where inside[c] { capacity += ceil[c] - floor[c] }
let total = 0.62 * capacity, q = total / period, steps = Int(period / dt)
var h = floor

/// Sand landing at `xa` settles as a cap at the angle of maximum stability: max(h, P - sm|x - xa|), P bisected.
func capFill(_ xa: Int, _ m: Double) {
    let reach = Int(900 * scale), lo = max(xa - reach, 0), hi = min(xa + reach, W)
    var a = Double.infinity, b = -Double.infinity
    for c in lo..<hi { a = min(a, h[c]); b = max(b, h[c]) }
    b += 400
    for _ in 0..<40 {
        let p = (a + b) / 2
        var add = 0.0
        for c in lo..<hi { add += max(min(max(h[c], p - sm * Double(abs(c - xa))), ceil[c]) - h[c], 0) }
        if add > m { b = p } else { a = p }
    }
    for c in lo..<hi { h[c] = max(h[c], min(max(h[c], a - sm * Double(abs(c - xa))), ceil[c])) }
}

/// How far the flank on `side` lags behind a line at the angle of repose from the apex, and its length.
func lag(_ xa: Int, _ side: Int) -> (Double, Int) {
    var worst = 0.0, last = -1, n = 0, c = xa
    while c >= 0 && c < W {
        if inside[c] {
            if h[c] > floor[c] + 1 && h[c] < ceil[c] - 0.5 {
                worst = max(worst, h[xa] - sr * Double(abs(c - xa)) - h[c]); last = abs(c - xa); n += 1
            }
        }
        c += side
    }
    return n < 30 ? (0, 0) : (worst, last)
}

/// Slides one flank to a line at the angle of repose from the apex, keeping the sand. False if the glass holds it.
func avalanche(_ xa: Int, _ side: Int) -> Bool {
    var idx: [Int] = []
    var c = xa
    while c >= 0 && c < W { if inside[c] { idx.append(c) }; c += side }
    let old = idx.map { h[$0] }, mass = old.reduce(0, +)
    func shape(_ top: Double, _ out: inout [Double]) -> Double {
        var sum = 0.0, eroding = true
        for (k, c) in idx.enumerated() {
            let line = top - sr * Double(abs(c - xa))
            if eroding && line >= old[k] { eroding = false }
            let g = min(eroding ? line : max(line, old[k]), ceil[c])
            out[k] = g; sum += g
        }
        return sum
    }
    var out = old, a = old.min()! - 10, b = old[0]
    if shape(b, &out) < mass { return false }
    for _ in 0..<50 { let m = (a + b) / 2; if shape(m, &out) > mass { b = m } else { a = m } }
    _ = shape(a, &out)
    for (k, c) in idx.enumerated() { h[c] = out[k] }
    return true
}

// The fill: the profile kept after every step (the app would keep it only after each slide, as rows of a texture).
let t0 = Date()
var history = [Float](repeating: 0, count: (steps + 1) * W)
for c in 0..<W { history[c] = Float(h[c]) }
var need = [uniform(0.6, 1), uniform(0.6, 1)], slides = 0
for s in 1...steps {
    let land = x0 + Int((uniform(-1, 1) * 4).rounded())
    capFill(land, q * dt)
    var apex = land - 6
    for c in (land - 6)...(land + 6) where h[c] > h[apex] { apex = c }
    var best: (Double, Int)? = nil
    for (k, side) in [-1, 1].enumerated() {
        let (d, L) = lag(apex, side)
        if L > 30 && d >= max(1, need[k] * (sm - sr) * Double(L)) && d / Double(L) > (best?.0 ?? -1) { best = (d / Double(L), side) }
    }
    if let (_, side) = best {
        if avalanche(apex, side) { slides += 1 }
        need[side < 0 ? 0 : 1] = uniform(0.6, 1)
    }
    for c in 0..<W { history[s * W + c] = Float(h[c]) }
}
let simTime = Date().timeIntervalSince(t0)

// The deposit map: for each pixel, the step it was last made sand (16 bits a texel in the app).
let t1 = Date()
var map = [UInt16](repeating: UInt16.max, count: W * H)
for c in 0..<W where inside[c] {
    var below = Int(floor[c])
    for s in 1...steps {
        let top = Int(history[s * W + c])
        if top > below { for y in below..<min(top, H) { map[y * W + c] = UInt16(min(s * 65535 / steps, 65534)) } }
        below = top
    }
}
let mapTime = Date().timeIntervalSince(t1)
print(String(format: "%d x %d, %d steps of %.2f s: sim %.0f ms (%d slides), deposit map %.0f ms; history %.1f MB, map %.1f MB",
             W, H, steps, dt, simTime * 1000, slides, mapTime * 1000, Double(history.count * 4) / 1e6, Double(map.count * 2) / 1e6))
