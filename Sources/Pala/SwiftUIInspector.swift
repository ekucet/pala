//
//  SwiftUIInspector.swift
//  Pala
//
//  SwiftUI convenience API:
//   • `.enablePala()`      → installs the debug hub.
//   • `.palaInspect(...)`  → attaches precise metadata (incl. the SwiftUI Font,
//                               resolved via reflection) to a SwiftUI element.
//

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - Frame capture

private struct InspectorFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

// MARK: - Metadata modifier

private struct UIDebugInspectModifier: ViewModifier {
    let name: String?
    let font: UIFont?
    let explicitFontDescription: String?
    /// When true and no font is given, capture the inherited SwiftUI environment font.
    let autoFont: Bool
    let textColor: UIColor?
    let background: UIColor?
    let padding: UIEdgeInsets?

    @Environment(\.font) private var environmentFont
    @State private var id = UUID()

    private var fontDescription: String? {
        if let explicitFontDescription { return explicitFontDescription }
        if autoFont, let environmentFont { return FontReflection.describe(environmentFont) }
        return nil
    }

    func body(content: Content) -> some View {
        let desc = fontDescription
        return content
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: InspectorFramePreferenceKey.self,
                                           value: geo.frame(in: .global))
                }
            )
            .onPreferenceChange(InspectorFramePreferenceKey.self) { frame in
                let meta = SwiftUIMetadata(
                    name: name,
                    font: font,
                    fontDescription: desc,
                    textColor: textColor,
                    background: background,
                    padding: padding,
                    frameInWindow: frame
                )
                MainActor.assumeIsolated { InspectorRegistry.shared.update(id, metadata: meta) }
            }
            .onDisappear {
                MainActor.assumeIsolated { InspectorRegistry.shared.remove(id) }
            }
    }
}

// MARK: - Public View extensions

public extension View {

    /// Installs the floating Pala debug hub. Call once, at the app root.
    func enablePala() -> some View {
        onAppear { Pala.enable() }
    }

    /// Attaches inspect metadata. With no `font`, Pala captures the **inherited
    /// SwiftUI environment font** automatically (place the modifier so it inherits the
    /// font, e.g. `Text("Hi").palaInspect().font(.headline)`).
    func palaInspect(_ name: String? = nil,
                        font: UIFont? = nil,
                        textColor: UIColor? = nil,
                        background: UIColor? = nil,
                        padding: UIEdgeInsets? = nil) -> some View {
        modifier(UIDebugInspectModifier(
            name: name, font: font, explicitFontDescription: nil,
            autoFont: font == nil,
            textColor: textColor, background: background, padding: padding))
    }

    /// Attaches inspect metadata with an explicit **SwiftUI `Font`**, resolved via
    /// reflection to a readable description (e.g. `headline (text style)`,
    /// `System · 17pt · semibold`, `Poppins · 16pt`). Most robust way to show fonts.
    ///
    /// ```swift
    /// Text("Sign In")
    ///     .palaInspect("Sign In Button",
    ///                     font: .headline,
    ///                     textColor: .white,
    ///                     background: .systemBlue)
    /// ```
    func palaInspect(_ name: String? = nil,
                        font: Font,
                        textColor: UIColor? = nil,
                        background: UIColor? = nil,
                        padding: UIEdgeInsets? = nil) -> some View {
        modifier(UIDebugInspectModifier(
            name: name, font: nil, explicitFontDescription: FontReflection.describe(font),
            autoFont: false,
            textColor: textColor, background: background, padding: padding))
    }
}
#endif
