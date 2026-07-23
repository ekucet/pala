import XCTest
@testable import Pala

#if canImport(UIKit)
import UIKit

final class PalaTests: XCTestCase {

    func testColorHexRGB() {
        // `.red` matches no known system color → bare hex; `.black`/`.white` are
        // named, so the description carries the "name · #hex" prefix.
        XCTAssertEqual(UIColor.red.inspectorDescription, "#FF0000")
        XCTAssertEqual(UIColor.black.inspectorDescription, "black · #000000")
        XCTAssertEqual(UIColor.white.inspectorDescription, "white · #FFFFFF")
    }

    func testColorHexWithAlpha() {
        let c = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        XCTAssertTrue(c.inspectorDescription.contains("#000000"))
        XCTAssertTrue(c.inspectorDescription.contains("50%"))
    }

    func testFontSummaryContainsSizeAndWeight() {
        let font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        let summary = font.inspectorSummary
        XCTAssertTrue(summary.contains("17pt"))
        XCTAssertTrue(summary.contains("Semibold"))
    }

    @MainActor
    func testRegistryReturnsInnermostElement() {
        let registry = InspectorRegistry.shared
        let outer = UUID()
        let inner = UUID()
        registry.update(outer, metadata: SwiftUIMetadata(
            name: "outer", font: nil, textColor: nil, background: nil,
            frameInWindow: CGRect(x: 0, y: 0, width: 200, height: 200)))
        registry.update(inner, metadata: SwiftUIMetadata(
            name: "inner", font: nil, textColor: nil, background: nil,
            frameInWindow: CGRect(x: 40, y: 40, width: 40, height: 40)))

        let hit = registry.metadata(at: CGPoint(x: 50, y: 50))
        XCTAssertEqual(hit?.name, "inner")

        registry.remove(outer)
        registry.remove(inner)
    }

    // MARK: - Design-system palette

    func testRegisteredTokenNameBeatsSystemColorName() {
        PalaPalette.removeAll()
        defer { PalaPalette.removeAll() }

        // Pure black would otherwise be named "black" by the system table.
        PalaPalette.register([("TextLight.primary", .black)])
        XCTAssertEqual(UIColor.black.inspectorDescription, "TextLight.primary · #000000")
    }

    func testUnregisteredColorStillFallsBackToSystemName() {
        PalaPalette.removeAll()
        PalaPalette.register([("Brand.accent", UIColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1))])
        defer { PalaPalette.removeAll() }

        XCTAssertEqual(UIColor.white.inspectorDescription, "white · #FFFFFF")
    }

    // MARK: - Drawn-color sampling

    /// SwiftUI text is a bitmap: transparent around opaque glyph pixels. The
    /// sampler must report the glyph (ink) color, not the transparent majority.
    func testSamplerFindsInkColorAmongTransparentPixels() {
        let size = 20
        let ink = (r: UInt8(220), g: UInt8(30), b: UInt8(40))
        var px = [UInt8](repeating: 0, count: size * size * 4)   // fully transparent
        // Paint a few opaque "glyph" pixels (premultiplied == raw at alpha 255).
        for i in 0..<12 {
            let o = i * 4
            px[o + 0] = ink.r; px[o + 1] = ink.g; px[o + 2] = ink.b; px[o + 3] = 255
        }

        let ctx = CGContext(data: &px, width: size, height: size,
                            bitsPerComponent: 8, bytesPerRow: size * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        let image = ctx!.makeImage()!

        let sampled = LayerColorSampler.dominantColor(of: image)
        XCTAssertNotNil(sampled)

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        sampled?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, CGFloat(ink.r) / 255, accuracy: 0.05)
        XCTAssertEqual(g, CGFloat(ink.g) / 255, accuracy: 0.05)
        XCTAssertEqual(b, CGFloat(ink.b) / 255, accuracy: 0.05)
    }

    /// A fully transparent bitmap has no visible color to report.
    func testSamplerReturnsNilForFullyTransparentBitmap() {
        let size = 8
        var px = [UInt8](repeating: 0, count: size * size * 4)
        let ctx = CGContext(data: &px, width: size, height: size,
                            bitsPerComponent: 8, bytesPerRow: size * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        XCTAssertNil(LayerColorSampler.dominantColor(of: ctx!.makeImage()!))
    }
}
#endif
