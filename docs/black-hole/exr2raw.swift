// Decodes an image (here NASA's OpenEXR star map) to raw linear float32 RGBA: exr2raw in out.raw
import Foundation
import ImageIO
import CoreGraphics
let a = CommandLine.arguments
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = img.width, h = img.height
let cs = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 32, bytesPerRow: w * 16, space: cs, bitmapInfo: info.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
try! Data(bytes: ctx.data!, count: w * h * 16).write(to: URL(fileURLWithPath: a[2]))
print(w, h)
