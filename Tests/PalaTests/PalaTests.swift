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
}
#endif
