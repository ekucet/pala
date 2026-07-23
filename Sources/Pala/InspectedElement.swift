//
//  InspectedElement.swift
//  Pala
//
//  İncelenen bir öğenin ekranda gösterilecek, sunuma hazır temsili.
//

#if canImport(UIKit)
import UIKit

/// Hint kartında tek bir satır: sol tarafta etiket, sağ tarafta değer.
/// `swatch` doluysa değerin yanında küçük bir renk kutucuğu gösterilir.
public struct InspectedProperty {
    public let label: String
    public let value: String
    public let swatch: UIColor?

    public init(label: String, value: String, swatch: UIColor? = nil) {
        self.label = label
        self.value = value
        self.swatch = swatch
    }
}

/// Hint kartında mantıksal bir grup (ör. "Metin", "Geometri", "Katman").
public struct InspectedSection {
    public let title: String
    public let properties: [InspectedProperty]

    public init(title: String, properties: [InspectedProperty]) {
        self.title = title
        self.properties = properties
    }
}

/// Bir long-press sonucu üretilen tam inceleme sonucu.
public struct InspectedElement {
    /// Kart başlığı — genellikle sınıf adı ya da SwiftUI etiketi.
    public let title: String
    /// Öğenin aktif pencere koordinatlarındaki çerçevesi (highlight için).
    public let frameInWindow: CGRect
    /// Görüntülenecek gruplanmış özellikler.
    public let sections: [InspectedSection]
    /// Kaynağın SwiftUI mi yoksa UIKit mi olduğunu belirtir (rozet için).
    public let source: Source

    public enum Source: String {
        case swiftUI = "SwiftUI"
        case uiKit = "UIKit"
        case accessibility = "A11y"
        case layer = "Layer"
    }

    public init(title: String,
                frameInWindow: CGRect,
                sections: [InspectedSection],
                source: Source) {
        self.title = title
        self.frameInWindow = frameInWindow
        self.sections = sections
        self.source = source
    }
}
#endif
