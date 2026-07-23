//
//  PalaPalette.swift
//  Pala
//
//  A registry of *named* design-system colors, so the inspector can print a
//  meaningful token name ("Primary.six · #0F62FE") instead of a bare hex.
//
//  Like `InspectorRegistry`, the backing store is process-global (an associated
//  object on `UIApplication`, keyed by an interned selector, holding Foundation
//  values) so any linked copy of Pala — or any module that doesn't import Pala
//  at all — can register and read the same palette.
//

#if canImport(UIKit)
import UIKit
import ObjectiveC

enum PalaPalette {

    /// Registered `(name, color)` pairs, in registration order — the first match wins,
    /// so callers can put more specific tokens first.
    private static var store: NSMutableArray {
        let key = unsafeBitCast(NSSelectorFromString("palaSharedPaletteV1"),
                                to: UnsafeRawPointer.self)
        let anchor = InspectorRegistry.storeAnchorObject
        if let existing = objc_getAssociatedObject(anchor, key) as? NSMutableArray {
            return existing
        }
        let fresh = NSMutableArray()
        objc_setAssociatedObject(anchor, key, fresh, .OBJC_ASSOCIATION_RETAIN)
        return fresh
    }

    static func register(_ colors: [(String, UIColor)]) {
        let store = self.store
        for (name, color) in colors {
            store.add([name, color] as NSArray)
        }
    }

    static func removeAll() {
        store.removeAllObjects()
    }

    /// The registered name whose color matches, or nil.
    static func name(for color: UIColor) -> String? {
        let trait = UITraitCollection.current
        guard let mine = color.palaResolvedRGB(trait) else { return nil }
        for case let entry as NSArray in store {
            guard entry.count == 2,
                  let name = entry[0] as? String,
                  let candidate = entry[1] as? UIColor,
                  let other = candidate.palaResolvedRGB(trait) else { continue }
            if UIColor.palaApproxEqual(mine, other) { return name }
        }
        return nil
    }
}
#endif
