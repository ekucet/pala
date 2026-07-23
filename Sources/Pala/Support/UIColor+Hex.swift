//
//  UIColor+Hex.swift
//  Pala
//

#if canImport(UIKit)
import UIKit

extension UIColor {
    /// Rengin okunabilir açıklaması: bilinen sistem rengiyse adı + `#RRGGBB`
    /// (+ gerekiyorsa opaklık). Çözümlenemezse "n/a".
    var inspectorDescription: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            // düşer
        } else {
            var w: CGFloat = 0
            if getWhite(&w, alpha: &a) {
                r = w; g = w; b = w
            } else {
                return "n/a"
            }
        }

        let ri = Int((r * 255).rounded())
        let gi = Int((g * 255).rounded())
        let bi = Int((b * 255).rounded())
        let hex = String(format: "#%02X%02X%02X", ri, gi, bi)

        var text = hex
        if let name = inspectorName {
            text = "\(name) · \(hex)"
        }
        if a < 0.999 {
            text += " · \(Int((a * 100).rounded()))% opacity"
        }
        return text
    }

    /// The color's name: a **registered design-system token** first (e.g. "Primary.six"),
    /// otherwise a known system color (e.g. "systemBlue"). Nil if neither matches.
    var inspectorName: String? {
        // An app-registered token wins — it's more meaningful than the system
        // color it happens to resemble.
        if let token = PalaPalette.name(for: self) { return token }

        let trait = UITraitCollection.current
        guard let mine = palaResolvedRGB(trait) else { return nil }
        for (name, color) in UIColor.inspectorKnownColors {
            if let other = color.palaResolvedRGB(trait), UIColor.palaApproxEqual(mine, other) {
                return name
            }
        }
        return nil
    }

    func palaResolvedRGB(_ trait: UITraitCollection) -> (CGFloat, CGFloat, CGFloat)? {
        let c = resolvedColor(with: trait)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if c.getRed(&r, green: &g, blue: &b, alpha: &a) { return (r, g, b) }
        var w: CGFloat = 0
        if c.getWhite(&w, alpha: &a) { return (w, w, w) }
        return nil
    }

    static func palaApproxEqual(_ x: (CGFloat, CGFloat, CGFloat),
                                _ y: (CGFloat, CGFloat, CGFloat)) -> Bool {
        abs(x.0 - y.0) < 0.03 && abs(x.1 - y.1) < 0.03 && abs(x.2 - y.2) < 0.03
    }

    /// iOS 13'ten beri var olan, karşılaştırılabilir sistem renkleri.
    private static let inspectorKnownColors: [(String, UIColor)] = [
        // Önce temel/canlı renkler — böylece beyaz "white" olur, "systemBackground" değil.
        ("white", .white), ("black", .black),
        ("systemRed", .systemRed), ("systemOrange", .systemOrange),
        ("systemYellow", .systemYellow), ("systemGreen", .systemGreen),
        ("systemTeal", .systemTeal), ("systemBlue", .systemBlue),
        ("systemIndigo", .systemIndigo), ("systemPurple", .systemPurple),
        ("systemPink", .systemPink), ("systemBrown", .systemBrown),
        ("systemGray", .systemGray), ("systemGray2", .systemGray2),
        ("systemGray3", .systemGray3), ("systemGray4", .systemGray4),
        ("systemGray5", .systemGray5), ("systemGray6", .systemGray6),
        // Sonra semantik renkler.
        ("label", .label), ("secondaryLabel", .secondaryLabel),
        ("tertiaryLabel", .tertiaryLabel), ("quaternaryLabel", .quaternaryLabel),
        ("placeholderText", .placeholderText), ("separator", .separator),
        ("link", .link),
        ("systemBackground", .systemBackground),
        ("secondarySystemBackground", .secondarySystemBackground),
        ("tertiarySystemBackground", .tertiarySystemBackground),
        ("systemGroupedBackground", .systemGroupedBackground)
    ]
}
#endif
