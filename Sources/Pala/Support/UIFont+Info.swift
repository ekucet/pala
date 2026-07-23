//
//  UIFont+Info.swift
//  Pala
//

#if canImport(UIKit)
import UIKit

extension UIFont {
    /// Font weight'inin insan-okur adı (Regular, Semibold, Bold...).
    var inspectorWeightName: String {
        guard
            let traits = fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any],
            let raw = traits[.weight] as? CGFloat
        else {
            return "Regular"
        }

        switch UIFont.Weight(rawValue: raw) {
        case .ultraLight: return "UltraLight"
        case .thin:       return "Thin"
        case .light:      return "Light"
        case .regular:    return "Regular"
        case .medium:     return "Medium"
        case .semibold:   return "Semibold"
        case .bold:       return "Bold"
        case .heavy:      return "Heavy"
        case .black:      return "Black"
        default:          return String(format: "%.2f", raw)
        }
    }

    /// Font'un italik olup olmadığı.
    var inspectorIsItalic: Bool {
        fontDescriptor.symbolicTraits.contains(.traitItalic)
    }

    /// Sistem fontlarını okunur adlandırır (".SFUI-…" → "SF Pro (System)"),
    /// özel fontlarda gerçek aile adını döndürür.
    var inspectorFamilyName: String {
        let lower = fontName.lowercased()
        if lower.hasPrefix(".sfui") || lower.hasPrefix(".sfpro")
            || lower.contains("systemfont") || familyName.contains("AppleSystemUIFont") {
            return "SF Pro (System)"
        }
        if familyName.hasPrefix(".") { return "System" }
        return familyName
    }

    /// `UIFont(name:size:)`'a verilen gerçek PostScript adı (ör. "Poppins-Medium").
    var inspectorPostScriptName: String { fontName }

    /// "SF Pro (System) · Semibold · 17pt" biçiminde okunur özet.
    var inspectorSummary: String {
        var parts = [inspectorFamilyName, inspectorWeightName, String(format: "%.0fpt", pointSize)]
        if inspectorIsItalic { parts.append("Italic") }
        return parts.joined(separator: " · ")
    }
}
#endif
