//
//  FontReflection.swift
//  Pala
//
//  Best-effort extraction of "what a SwiftUI Font was set to" via reflection.
//  There is no public API for this, so we Mirror the (private) Font.provider.base.
//  Everything degrades gracefully to a readable fallback across iOS versions.
//

#if canImport(SwiftUI)
import SwiftUI
import CoreGraphics

enum FontReflection {

    /// Returns a human-readable description of the font, e.g.
    /// "headline (text style)", "System · 17pt · semibold", "Poppins · 16pt".
    static func describe(_ font: Font) -> String {
        guard
            let provider = child(of: font, "provider"),
            let base = child(of: provider, "base")
        else {
            return "SwiftUI Font"
        }
        return describeProvider(base) ?? cleanTypeName(base)
    }

    // MARK: - Providers

    private static func describeProvider(_ base: Any) -> String? {
        let fields = childrenDict(base)

        // Text style: TextStyleProvider { style, weight?, design? }
        if let style = fields["style"] {
            var parts = [enumWord(style)]
            if let w = fields["weight"], let wn = weightWord(w) { parts.append(wn) }
            if let d = fields["design"], let dn = enumWordOptional(d) { parts.append(dn) }
            return parts.joined(separator: " · ") + " (text style)"
        }

        // System sized: SystemProvider { size, weight?, design? }
        if let size = fields["size"] as? CGFloat {
            var parts = ["System", String(format: "%.0fpt", size)]
            if let w = fields["weight"], let wn = weightWord(w) { parts.append(wn) }
            if let d = fields["design"], let dn = enumWordOptional(d) { parts.append(dn) }
            // A custom/named provider may also expose a name.
            if let name = fields["name"] as? String { parts[0] = name }
            return parts.joined(separator: " · ")
        }

        // Named/custom: NamedProvider { name, size, textStyle? }
        if let name = fields["name"] as? String {
            var parts = [name]
            if let size = fields["size"] as? CGFloat { parts.append(String(format: "%.0fpt", size)) }
            return parts.joined(separator: " · ")
        }

        // Modifier providers wrap a base (e.g. .weight(), .italic()); recurse.
        if let inner = fields["base"] ?? fields["provider"] ?? fields["modifier"] {
            if let inner = fields["base"] ?? fields["provider"], let d = describeProvider(inner) {
                return d
            }
            _ = inner
        }
        return nil
    }

    // MARK: - Reflection helpers

    private static func child(of value: Any, _ label: String) -> Any? {
        Mirror(reflecting: value).children.first { $0.label == label }?.value
    }

    private static func childrenDict(_ value: Any) -> [String: Any] {
        var out: [String: Any] = [:]
        for c in Mirror(reflecting: value).children where c.label != nil {
            out[c.label!] = c.value
        }
        return out
    }

    /// For enum values, `String(describing:)` yields the case name (e.g. "headline").
    private static func enumWord(_ value: Any) -> String {
        cleanToken(String(describing: value))
    }

    private static func enumWordOptional(_ value: Any) -> String? {
        let s = cleanToken(String(describing: value))
        let skip = ["default", "nil", "none", ""]
        return skip.contains(s) ? nil : s
    }

    /// Font.Weight prints messily; try a known keyword, else map its numeric value.
    private static func weightWord(_ value: Any) -> String? {
        let s = String(describing: value).lowercased()
        let known = ["ultralight", "thin", "light", "regular", "medium",
                     "semibold", "bold", "heavy", "black"]
        for k in known where s.contains(k) { return prettyWeight(k) }
        if let v = numericValue(in: value, depth: 0) { return nameForWeight(v) }
        return nil
    }

    private static func prettyWeight(_ k: String) -> String {
        k == "ultralight" ? "UltraLight" : k.prefix(1).uppercased() + k.dropFirst()
    }

    /// Font.Weight wraps a UIFont.Weight-style CGFloat; map it to a readable name.
    private static func nameForWeight(_ v: CGFloat) -> String {
        let table: [(CGFloat, String)] = [
            (-0.8, "UltraLight"), (-0.6, "Thin"), (-0.4, "Light"), (0.0, "Regular"),
            (0.23, "Medium"), (0.3, "Semibold"), (0.4, "Bold"), (0.56, "Heavy"), (0.62, "Black")
        ]
        return table.min(by: { abs($0.0 - v) < abs($1.0 - v) })?.1 ?? "Regular"
    }

    /// Recursively search a value (through Optionals/wrappers) for a numeric field.
    private static func numericValue(in value: Any, depth: Int) -> CGFloat? {
        if let d = value as? CGFloat { return d }
        if let d = value as? Double { return CGFloat(d) }
        if let d = value as? Float { return CGFloat(d) }
        guard depth < 3 else { return nil }
        for child in Mirror(reflecting: value).children {
            if let found = numericValue(in: child.value, depth: depth + 1) { return found }
        }
        return nil
    }

    private static func cleanToken(_ s: String) -> String {
        // Strip "Optional(...)", enum qualifiers, etc.
        var t = s
        if t.hasPrefix("Optional("), t.hasSuffix(")") { t = String(t.dropFirst(9).dropLast()) }
        if let dot = t.lastIndex(of: ".") { t = String(t[t.index(after: dot)...]) }
        return t.trimmingCharacters(in: CharacterSet(charactersIn: "()\" "))
    }

    private static func cleanTypeName(_ base: Any) -> String {
        let t = String(describing: type(of: base))
        return "SwiftUI Font (\(t))"
    }
}
#endif
