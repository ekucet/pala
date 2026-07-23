//
//  Pala.swift
//  Pala
//
//  Public entry point: a floating debug hub (UI Inspector · Console · Layout tools).
//

#if canImport(UIKit)
import UIKit

/// Pala — a lightweight, zero-dependency in-app debug hub for iOS.
///
/// Enable it once (DEBUG only) to show a draggable bubble that opens a tool menu:
/// **UI Inspector**, **Inspect-all**, **Console**, **Grid**, **Show frames**, **Touch dots**.
///
/// ```swift
/// #if DEBUG
/// Pala.enable()
/// #endif
/// ```
public enum Pala {

    /// The running Pala version — shown in the hub menu so you can confirm which
    /// build is actually installed (a stale app binary is the usual "nothing changed").
    public static let version = "1.0.3"

    /// Installs the floating debug hub.
    @MainActor
    public static func enable() {
        PalaHub.shared.enable()
    }

    /// Removes the hub and all overlays.
    @MainActor
    public static func disable() {
        PalaHub.shared.disable()
    }

    /// Whether the hub is currently enabled.
    @MainActor
    public static var isEnabled: Bool {
        PalaHub.shared.isEnabled
    }

    // MARK: - Design-system palette

    /// Registers named design-system colors so the inspector reports the **token
    /// name** instead of a bare hex — `Primary.six · #0F62FE` rather than `#0F62FE`.
    ///
    /// Applies everywhere Pala resolves a color: UIKit text and backgrounds, layer
    /// colors, `.palaInspect` metadata, and the color sampled from SwiftUI-drawn
    /// text. Register once at startup, most specific tokens first (first match wins).
    ///
    /// ```swift
    /// #if DEBUG
    /// Pala.registerColors([
    ///     ("Primary.six", UIColor(Color.YKColor.Primary.six)),
    ///     ("TextLight.primary", UIColor(Color.YKColor.TextLight.primary)),
    /// ])
    /// #endif
    /// ```
    public static func registerColors(_ colors: [(String, UIColor)]) {
        PalaPalette.register(colors)
    }

    /// Clears every color registered with `registerColors(_:)`.
    public static func clearRegisteredColors() {
        PalaPalette.removeAll()
    }

    // MARK: - Console API

    /// Append a line to the in-app Console tool.
    @MainActor
    public static func log(_ message: String,
                           category: String = "General",
                           level: PalaLogLevel = .info) {
        PalaConsole.shared.add(message, category: category, level: level, date: currentDate())
    }

    @MainActor public static func debug(_ m: String, category: String = "General") { log(m, category: category, level: .debug) }
    @MainActor public static func info(_ m: String, category: String = "General")  { log(m, category: category, level: .info) }
    @MainActor public static func warning(_ m: String, category: String = "General") { log(m, category: category, level: .warning) }
    @MainActor public static func error(_ m: String, category: String = "General")  { log(m, category: category, level: .error) }

    private static func currentDate() -> Date { Date() }
}
#endif
