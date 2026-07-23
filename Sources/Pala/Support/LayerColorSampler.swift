//
//  LayerColorSampler.swift
//  Pala
//
//  SwiftUI draws `Text` (and shapes) into a `CALayer` bitmap — there is no
//  readable `textColor` the way a `UILabel` has one. So to report the color of
//  a drawn element we sample its rendered pixels: glyph pixels carry the ink
//  color, everything around them is transparent, so the dominant *opaque* color
//  is the color the user actually sees.
//

#if canImport(UIKit)
import UIKit

enum LayerColorSampler {

    /// Longest edge of the downsampled buffer we histogram. Small on purpose:
    /// this runs on a tap, and the dominant color survives downsampling.
    private static let sampleEdge = 40

    /// The dominant opaque color of a layer's drawn contents, or nil when the
    /// layer has no bitmap (or is effectively empty/transparent).
    static func dominantColor(of layer: CALayer) -> UIColor? {
        guard let contents = layer.contents else { return nil }
        let cf = contents as CFTypeRef
        guard CFGetTypeID(cf) == CGImage.typeID else { return nil }
        let image = unsafeBitCast(contents as AnyObject, to: CGImage.self)
        return dominantColor(of: image)
    }

    static func dominantColor(of image: CGImage) -> UIColor? {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return nil }

        // Downsample into a small RGBA8 buffer.
        let scale = max(1.0, Double(max(w, h)) / Double(sampleEdge))
        let tw = max(1, Int(Double(w) / scale))
        let th = max(1, Int(Double(h) / scale))

        var pixels = [UInt8](repeating: 0, count: tw * th * 4)
        guard let ctx = CGContext(data: &pixels,
                                  width: tw, height: th,
                                  bitsPerComponent: 8,
                                  bytesPerRow: tw * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: tw, height: th))

        // Histogram the opaque pixels, quantized so antialiasing noise collapses
        // onto the true ink color.
        var counts: [UInt32: Int] = [:]
        var sums: [UInt32: (r: Int, g: Int, b: Int)] = [:]
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let a = pixels[i + 3]
            guard a > 153 else { continue }              // ~0.6 alpha
            // Un-premultiply.
            let af = Double(a) / 255.0
            let r = Int((Double(pixels[i + 0]) / af).rounded())
            let g = Int((Double(pixels[i + 1]) / af).rounded())
            let b = Int((Double(pixels[i + 2]) / af).rounded())
            let rc = min(255, r), gc = min(255, g), bc = min(255, b)
            let key = UInt32(rc >> 3) << 10 | UInt32(gc >> 3) << 5 | UInt32(bc >> 3)
            counts[key, default: 0] += 1
            let s = sums[key] ?? (0, 0, 0)
            sums[key] = (s.r + rc, s.g + gc, s.b + bc)
        }

        guard let (key, count) = counts.max(by: { $0.value < $1.value }), count > 0,
              let sum = sums[key] else { return nil }

        return UIColor(red: CGFloat(sum.r) / CGFloat(count) / 255.0,
                       green: CGFloat(sum.g) / CGFloat(count) / 255.0,
                       blue: CGFloat(sum.b) / CGFloat(count) / 255.0,
                       alpha: 1)
    }
}
#endif
