//
//  InspectorRegistry.swift
//  Pala
//
//  Central store for metadata attached via `.palaInspect(...)`.
//
//  IMPORTANT: In multi-package apps Pala can be linked as *two static copies*
//  (e.g. the app depends on it AND a design-system package that bakes it into a
//  `TypographyModifier` does too). Each copy would otherwise have its own
//  `InspectorRegistry.shared`, so the design-system's registrations would be
//  invisible to the hub. To avoid that, the backing store lives **process-globally**
//  as an associated object on `UIApplication.shared`, keyed by an interned selector
//  (identical pointer across copies). Values are Foundation/UIKit types (shared
//  identity across copies), so any copy can read what another copy wrote.
//

#if canImport(UIKit)
import UIKit
import ObjectiveC

/// SwiftUI-side metadata that UIKit hit-testing can't read.
struct SwiftUIMetadata {
    var name: String?
    var font: UIFont?
    /// Reflected description of a SwiftUI `Font` (e.g. "headline (text style)").
    var fontDescription: String?
    var textColor: UIColor?
    var background: UIColor?
    var padding: UIEdgeInsets?
    var frameInWindow: CGRect
}

@MainActor
final class InspectorRegistry {
    static let shared = InspectorRegistry()
    private init() {}

    /// Fallback store anchor for environments with no running application
    /// (e.g. hostless unit tests), where `UIApplication.shared` would trap.
    private static let fallbackAnchor = NSObject()

    /// The process object the shared store hangs off. Normally the one
    /// `UIApplication.shared` (so every linked copy of Pala reaches the same
    /// store); in a hostless test bundle there is no application, so we go
    /// through the ObjC `sharedApplication` selector (which returns `nil` rather
    /// than trapping like the Swift accessor) and fall back to a static object.
    /// Shared by every process-global Pala store (metadata registry, palette…).
    nonisolated static var storeAnchorObject: AnyObject {
        let sel = NSSelectorFromString("sharedApplication")
        if let app = (UIApplication.self as AnyObject).perform(sel)?.takeUnretainedValue() {
            return app
        }
        return fallbackAnchor
    }

    private var storeAnchor: AnyObject { Self.storeAnchorObject }

    /// The shared backing store — one `NSMutableDictionary` per process, reachable
    /// from every linked copy of Pala.
    private var store: NSMutableDictionary {
        let key = unsafeBitCast(NSSelectorFromString("palaSharedRegistryV1"),
                                to: UnsafeRawPointer.self)
        let anchor = storeAnchor
        if let existing = objc_getAssociatedObject(anchor, key) as? NSMutableDictionary {
            return existing
        }
        let fresh = NSMutableDictionary()
        objc_setAssociatedObject(anchor, key, fresh, .OBJC_ASSOCIATION_RETAIN)
        return fresh
    }

    func update(_ id: UUID, metadata: SwiftUIMetadata) {
        let entry = NSMutableDictionary()
        if let v = metadata.name { entry["name"] = v }
        if let v = metadata.font { entry["font"] = v }
        if let v = metadata.fontDescription { entry["fontDescription"] = v }
        if let v = metadata.textColor { entry["textColor"] = v }
        if let v = metadata.background { entry["background"] = v }
        if let v = metadata.padding { entry["padding"] = NSValue(uiEdgeInsets: v) }
        entry["frame"] = NSValue(cgRect: metadata.frameInWindow)
        store[id.uuidString] = entry
    }

    func remove(_ id: UUID) {
        store.removeObject(forKey: id.uuidString)
    }

    /// All registered SwiftUI metadata (for the inspect-all layer).
    func allEntries() -> [SwiftUIMetadata] {
        store.allValues.compactMap { value in
            guard let d = value as? NSDictionary,
                  let frame = (d["frame"] as? NSValue)?.cgRectValue else { return nil }
            return SwiftUIMetadata(
                name: d["name"] as? String,
                font: d["font"] as? UIFont,
                fontDescription: d["fontDescription"] as? String,
                textColor: d["textColor"] as? UIColor,
                background: d["background"] as? UIColor,
                padding: (d["padding"] as? NSValue)?.uiEdgeInsetsValue,
                frameInWindow: frame)
        }
    }

    /// Innermost (smallest-area) registered entry containing the point.
    func metadata(at point: CGPoint) -> SwiftUIMetadata? {
        metadataStack(at: point).first
    }

    /// Registered entries containing the point, most specific (small) → general.
    func metadataStack(at point: CGPoint) -> [SwiftUIMetadata] {
        allEntries()
            .filter { $0.frameInWindow.contains(point) && !$0.frameInWindow.isEmpty }
            .sorted { area($0.frameInWindow) < area($1.frameInWindow) }
    }

    private func area(_ rect: CGRect) -> CGFloat {
        rect.width * rect.height
    }
}
#endif
