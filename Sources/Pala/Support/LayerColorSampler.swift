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

    /// The **ink** color inside a region of the app window: renders the region, treats
    /// the most common color as the background, and returns the most common color that
    /// is clearly different from it — i.e. the glyphs. Used when SwiftUI draws text
    /// straight into a shared layer, so there is no per-text bitmap to sample.
    static func inkColor(in rect: CGRect, of window: UIWindow) -> UIColor? {
        guard rect.width >= 2, rect.height >= 2 else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { ctx in
            ctx.cgContext.translateBy(x: -rect.origin.x, y: -rect.origin.y)
            window.layer.render(in: ctx.cgContext)
        }
        guard let cg = image.cgImage else { return nil }

        let buckets = histogram(of: cg)
        guard buckets.count >= 2 else { return nil }

        let ranked = buckets.sorted { $0.value.count > $1.value.count }
        let background = ranked[0].value.average
        // First bucket that is visibly different from the background.
        for (_, bucket) in ranked.dropFirst() {
            let c = bucket.average
            let distance = abs(c.0 - background.0) + abs(c.1 - background.1) + abs(c.2 - background.2)
            if distance > 90 {
                return UIColor(red: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255,
                               blue: CGFloat(c.2) / 255, alpha: 1)
            }
        }
        return nil
    }

    private struct Bucket { var count = 0; var r = 0; var g = 0; var b = 0
        var average: (Int, Int, Int) { (r / max(count, 1), g / max(count, 1), b / max(count, 1)) }
    }

    /// Quantized color histogram of the opaque pixels, downsampled for speed.
    private static func histogram(of image: CGImage) -> [UInt32: Bucket] {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return [:] }
        let scale = max(1.0, Double(max(w, h)) / Double(sampleEdge * 2))
        let tw = max(1, Int(Double(w) / scale)), th = max(1, Int(Double(h) / scale))

        var pixels = [UInt8](repeating: 0, count: tw * th * 4)
        guard let ctx = CGContext(data: &pixels, width: tw, height: th,
                                  bitsPerComponent: 8, bytesPerRow: tw * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return [:] }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: tw, height: th))

        var buckets: [UInt32: Bucket] = [:]
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let a = pixels[i + 3]
            guard a > 153 else { continue }
            let af = Double(a) / 255.0
            let r = min(255, Int((Double(pixels[i + 0]) / af).rounded()))
            let g = min(255, Int((Double(pixels[i + 1]) / af).rounded()))
            let b = min(255, Int((Double(pixels[i + 2]) / af).rounded()))
            let key = UInt32(r >> 3) << 10 | UInt32(g >> 3) << 5 | UInt32(b >> 3)
            var bucket = buckets[key] ?? Bucket()
            bucket.count += 1; bucket.r += r; bucket.g += g; bucket.b += b
            buckets[key] = bucket
        }
        return buckets
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
