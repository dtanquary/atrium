// Canopy's stand: a Poly Haven HDRI's zenith through the wallpaper's camera, its sky keyed out, written as the HEIC
// with alpha that Canopy.swift grows its leaves on (`Resources/canopy-<name>.heic`).
//
//   swiftc -O stand.swift -o $TMPDIR/canopy-stand && $TMPDIR/canopy-stand <the .hdr> <out dir> [name]
//
// The camera is Canopy's: a pinhole straight up, 1512 px to a unit of tan (90° across a 3024 px screen), the picture
// spanning tan ±1.1 across and ±0.75 up, so a 16:10 screen has 5% to spare each side to sway into. The key unmixes
// each pixel between the sky right behind it and the dark wood, so a twig thinner than a pixel comes out as the
// share of it covered. The sky behind is the luminance closed over 13 px (twigs lifted to the sky round them, the
// blue between clouds kept at its own level), or, where that is still dark, the brightest few percent of each 48 px
// block, filled in where wood hides it. Only the wood's brightness is kept, as a share of the sky above it, grey and
// sRGB-encoded, premultiplied by its cover in alpha. Writes `canopy-<name>.heic`, and to look at, `look-<name>.jpg`
// (the key over a flat sky) and `photo-<name>.jpg` (the HDRI as a camera meters it). Run on Schachen Forest's 16K
// .hdr (417 MB) on 2026-11-16, in 3 s; the download was deleted afterwards.
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers
import simd

let args = CommandLine.arguments
let (W, H, perTan) = (3326, 2268, 1512.0)
let name = args.count > 3 ? args[3] : "stand"

// The rows of the equirectangular picture within 55° of the zenith, as linear float RGB.
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil)!
let full = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let (ew, eh) = (full.width, full.height), rows = Int(Double(eh) * 55 / 180) + 2
let top = full.cropping(to: CGRect(x: 0, y: 0, width: ew, height: rows))!
var eq = [Float](repeating: 0, count: ew * rows * 4)
let ctx = CGContext(data: &eq, width: ew, height: rows, bitsPerComponent: 32, bytesPerRow: ew * 16,
                    space: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
ctx.draw(top, in: CGRect(x: 0, y: 0, width: ew, height: rows))

// Reprojected: row 0 is the top of the picture (north), screen right is west.
var view = [SIMD3<Float>](repeating: .zero, count: W * H)
view.withUnsafeMutableBufferPointer { O in
    nonisolated(unsafe) let O = O
    eq.withUnsafeBufferPointer { E in
        nonisolated(unsafe) let E = E
        DispatchQueue.concurrentPerform(iterations: H) { j in
            for i in 0..<W {
                let x = -(Double(i) + 0.5 - Double(W) / 2) / perTan, y = (Double(H) / 2 - Double(j) - 0.5) / perTan
                let n = (x * x + y * y + 1).squareRoot()
                let lon = atan2(y, x), lat = asin(1 / n)
                let fx = (lon / (2 * .pi) + 0.5) * Double(ew) - 0.5, fy = (0.5 - lat / .pi) * Double(eh) - 0.5
                let x0 = Int(floor(fx)), y0 = max(Int(floor(fy)), 0), ax = Float(fx - floor(fx)), ay = Float(fy - floor(fy))
                func px(_ a: Int, _ b: Int) -> SIMD3<Float> {
                    let k = (min(b, rows - 1) * ew + ((a % ew) + ew) % ew) * 4
                    return SIMD3(E[k], E[k + 1], E[k + 2])
                }
                O[j * W + i] = (px(x0, y0) * (1 - ax) + px(x0 + 1, y0) * ax) * (1 - ay) + (px(x0, y0 + 1) * (1 - ax) + px(x0 + 1, y0 + 1) * ax) * ay
            }
        }
    }
}
eq = []

func lum(_ v: SIMD3<Float>) -> Float { 0.2126 * v.x + 0.7152 * v.y + 0.0722 * v.z }
let Y = view.map(lum)
let sorted = Y.sorted(), n = W * H
let global = sorted[Int(Double(n - 1) * 0.97)], dark = sorted[Int(Double(n - 1) * 0.02)]

// The sky's level block by block, filled in where no sky shows, then smoothed.
let B = 48, bw = (W + B - 1) / B, bh = (H + B - 1) / B
var sky = [Float](repeating: -1, count: bw * bh)
for by in 0..<bh { for bx in 0..<bw {
    var vals: [Float] = []
    for y in stride(from: by * B, to: min(by * B + B, H), by: 2) { for x in stride(from: bx * B, to: min(bx * B + B, W), by: 2) { vals.append(Y[y * W + x]) } }
    vals.sort()
    let v = vals[Int(Double(vals.count - 1) * 0.97)]
    sky[by * bw + bx] = v < global * 0.45 ? -1 : v // a block of dense wood is not sky
} }
for _ in 0..<400 where sky.contains(-1) {
    let old = sky
    for by in 0..<bh { for bx in 0..<bw where old[by * bw + bx] < 0 {
        var s: Float = 0, c: Float = 0
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let x = bx + dx, y = by + dy
            if x >= 0, y >= 0, x < bw, y < bh, old[y * bw + x] >= 0 { s += old[y * bw + x]; c += 1 }
        }
        if c > 0 { sky[by * bw + bx] = s / c }
    } }
}
for _ in 0..<2 { // a 3 × 3 box blur, twice
    let old = sky
    for by in 0..<bh { for bx in 0..<bw {
        var s: Float = 0, c: Float = 0
        for dy in -1...1 { for dx in -1...1 {
            let x = bx + dx, y = by + dy
            if x >= 0, y >= 0, x < bw, y < bh { s += old[y * bw + x]; c += 1 }
        } }
        sky[by * bw + bx] = s / c
    } }
}
// The sky right behind each pixel: the luminance closed (a running max, then a running min, over 13 px), which
// lifts twigs and thin limbs to the sky round them and keeps the blue between clouds at its own level; where that
// is still dark (trunks, limbs, the conifers' masses) the block estimate stands in.
func run(_ a: [Float], _ r: Int, _ pick: @escaping @Sendable (Float, Float) -> Float) -> [Float] {
    var t = a, o = a
    t.withUnsafeMutableBufferPointer { T in a.withUnsafeBufferPointer { A in
        nonisolated(unsafe) let T = T, A = A
        DispatchQueue.concurrentPerform(iterations: H) { j in
            for i in 0..<W { var v = A[j * W + i]; for d in -r...r { v = pick(v, A[j * W + min(max(i + d, 0), W - 1)]) }; T[j * W + i] = v }
        }
    } }
    o.withUnsafeMutableBufferPointer { O in t.withUnsafeBufferPointer { T in
        nonisolated(unsafe) let O = O, T = T
        DispatchQueue.concurrentPerform(iterations: W) { i in
            for j in 0..<H { var v = T[j * W + i]; for d in -r...r { v = pick(v, T[min(max(j + d, 0), H - 1) * W + i]) }; O[j * W + i] = v }
        }
    } }
    return o
}
let closed = run(run(Y, 6, { max($0, $1) }), 6, { min($0, $1) })
// the sky's own colour, for unmixing
var skyRGB = SIMD3<Float>.zero, cnt: Float = 0
for i in stride(from: 0, to: n, by: 7) where Y[i] > global * 0.8 { skyRGB += view[i]; cnt += 1 }
skyRGB /= max(cnt, 1)
let skyHue = skyRGB / lum(skyRGB)

var out = [UInt8](repeating: 0, count: n * 4)
out.withUnsafeMutableBufferPointer { O in
    nonisolated(unsafe) let O = O
    DispatchQueue.concurrentPerform(iterations: H) { j in
        for i in 0..<W {
            let k = j * W + i
            let fx = (Float(i) + 0.5) / Float(B) - 0.5, fy = (Float(j) + 0.5) / Float(B) - 0.5
            let x0 = min(max(Int(floor(fx)), 0), bw - 1), y0 = min(max(Int(floor(fy)), 0), bh - 1)
            let x1 = min(x0 + 1, bw - 1), y1 = min(y0 + 1, bh - 1), ax = min(max(fx - Float(x0), 0), 1), ay = min(max(fy - Float(y0), 0), 1)
            let block = (sky[y0 * bw + x0] * (1 - ax) + sky[y0 * bw + x1] * ax) * (1 - ay) + (sky[y1 * bw + x0] * (1 - ax) + sky[y1 * bw + x1] * ax) * ay
            // (the blue between clouds can be a quarter as bright as the clouds round it: where the sky shows as
            // blue as that, the closing is trusted much further down)
            let blue = simd_smoothstep(1.6, 1.9, Double(view[k].z / max(view[k].y, 1e-6)))
            let t = Float(simd_smoothstep(0.15 - 0.11 * blue, 0.35 - 0.25 * blue, Double(closed[k] / block)))
            let S = block + (max(closed[k], Y[k]) - block) * t
            var m = min(max((S - Y[k]) / max(S - dark, 1e-6), 0), 1)
            m = min(max((m - 0.04) / 0.96, 0), 1) // the sky's own grain is not twigs
            let fg = m > 0.02 ? simd_max((view[k] - (1 - m) * S * skyHue) / m, .zero) : .zero
            let g = min(lum(fg) / S, 0.5)
            for ch in 0..<3 { O[k * 4 + ch] = UInt8(min(pow(Double(g), 1 / 2.2), 1) * 255 * Double(m) + 0.5) } // grey, premultiplied
            O[k * 4 + 3] = UInt8(m * 255 + 0.5)
        }
    }
}

func write(_ bytes: [UInt8], _ w: Int, _ h: Int, _ path: String, _ type: UTType, alpha: Bool, quality: Double = 0.8) {
    var b = bytes
    let c = CGContext(data: &b, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue)!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, c.makeImage()!, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    CGImageDestinationFinalize(dest)
}
write(out, W, H, args[2] + "/canopy-\(name).heic", .heic, alpha: true)
// To look at: the matte over a flat sky, and the HDRI as a camera shows it.
var look = [UInt8](repeating: 255, count: n * 4)
for k in 0..<n { let a = Float(out[k * 4 + 3]) / 255; for ch in 0..<3 { look[k * 4 + ch] = UInt8(Float(out[k * 4 + ch]) + (1 - a) * Float([150, 175, 215][ch])) } }
write(look, W, H, args[2] + "/look-\(name).jpg", .jpeg, alpha: false)
let meter = 0.18 / (Y.reduce(0, +) / Float(n))
var photo = [UInt8](repeating: 255, count: n * 4)
for k in 0..<n { for ch in 0..<3 { photo[k * 4 + ch] = UInt8(min(pow(max(Double(view[k][ch] * meter), 0), 1 / 2.2), 1) * 255) } }
write(photo, W, H, args[2] + "/photo-\(name).jpg", .jpeg, alpha: false)
print("sky \(global), dark \(dark), sky colour \(skyRGB), cover \(out.enumerated().filter { $0.offset % 4 == 3 }.map { Double($0.element) }.reduce(0, +) / 255 / Double(n))")
