//
//  ViewInspector.swift
//  Pala
//
//  Bir noktadaki en derin görünümü bulur ve incelenebilir özelliklerini çıkarır.
//

#if canImport(UIKit)
import UIKit

@MainActor
enum ViewInspector {

    /// Ana giriş noktası. Önce SwiftUI registry'sine, isabet yoksa UIKit view
    /// ağacına bakarak bir `InspectedElement` üretir.
    static func inspect(at pointInWindow: CGPoint, in window: UIWindow) -> InspectedElement? {
        inspectStack(at: pointInWindow, in: window).first
    }

    /// Noktanın altındaki tüm katmanları en spesifikten en genele doğru döndürür:
    /// önce SwiftUI annotate'li kayıtlar, sonra en derin UIKit view'dan pencereye
    /// kadar olan ata zinciri. Kullanıcı kartta bunlar arasında gezebilir.
    static func inspectStack(at pointInWindow: CGPoint, in window: UIWindow) -> [InspectedElement] {
        // Tüm kaynaklardan aday topla. Öncelik = ne kadar BİLGİ-DOLU (küçük=önce):
        //  0 = SwiftUI kaydı (kesin font/renk)
        //  1 = UIKit içerik view'ı (label/buton/görsel — font/renk taşır)
        //  2 = accessibility yaprağı (frame/label/rol)
        //  3 = çizim katmanı (CALayer — sadece geometri)
        //  4 = UIKit sarmalayıcı/container
        var scored: [(el: InspectedElement, prio: Int)] = []

        for meta in InspectorRegistry.shared.metadataStack(at: pointInWindow) {
            scored.append((element(from: meta), 0))
        }
        for leaf in accessibilityLeaves(in: window) where leaf.frameInWindow.contains(pointInWindow) {
            scored.append((element(from: leaf), 2))
        }
        if let deepest = deepestView(at: pointInWindow, in: window, root: window) {
            for layerEl in layerCandidates(under: deepest, at: pointInWindow, in: window) {
                scored.append((layerEl, 3))
            }
            var current: UIView? = deepest
            while let view = current {
                if !(view is InspectorOverlayView), !(view is InspectAllOverlayView),
                   !isInternalWrapper(view) {
                    scored.append((element(from: view, in: window), isContentView(view) ? 1 : 4))
                }
                if view === window { break }
                current = view.superview
            }
        }

        // En bilgi-dolu önce (öncelik); eşit öncelikte küçük alan (en spesifik) önce.
        scored.sort {
            if $0.prio != $1.prio { return $0.prio < $1.prio }
            let a0 = $0.el.frameInWindow.width * $0.el.frameInWindow.height
            let a1 = $1.el.frameInWindow.width * $1.el.frameInWindow.height
            return a0 < a1
        }

        // Yakın-eş çerçeveleri tekille (öncelikli/ilk olan kalır).
        var out: [InspectedElement] = []
        var used: [CGRect] = []
        for item in scored {
            if used.contains(where: { nearlyEqual($0, item.el.frameInWindow) }) { continue }
            used.append(item.el.frameInWindow)
            out.append(item.el)
            if out.count >= 14 { break }
        }
        return out
    }

    private static func isContentView(_ v: UIView) -> Bool {
        v is UILabel || v is UIButton || v is UIControl || v is UIImageView
            || v is UITextField || v is UITextView
    }

    /// SwiftUI/UIKit private wrapper views (`_UIHostingView`, `PlatformGroupContainer`…)
    /// that are noise for the user — hidden from results.
    private static func isInternalWrapper(_ v: UIView) -> Bool {
        let n = String(describing: type(of: v))
        if n.hasPrefix("_") { return true }   // private classes are always internal
        if isContentView(v) { return false }
        return n.contains("Hosting")
            || n.contains("PlatformGroupContainer")
            || n.contains("PlatformView")
            || n.contains("GraphicsView")
    }

    // MARK: - "Hepsini göster" hedefleri

    /// "Hepsini göster" katmanında öğenin yanında gösterilecek hedef.
    struct Target {
        let title: String
        let frameInWindow: CGRect
        let source: InspectedElement.Source
        /// Öğenin yanında yazılacak kompakt özellik satırları.
        let lines: [String]
        /// Etiketin yanındaki renk kutucuğu (metin ya da arka plan rengi).
        let swatch: UIColor?
    }

    /// Ekrandaki tüm ilginç öğeleri (SwiftUI kayıtları + anlamlı UIKit view'lar)
    /// ve her birinin kompakt özelliklerini toplar.
    static func allTargets(in window: UIWindow) -> [Target] {
        var targets: [Target] = []

        // 1) SwiftUI annotate'li kayıtlar.
        for meta in InspectorRegistry.shared.allEntries() where !meta.frameInWindow.isEmpty {
            targets.append(Target(
                title: meta.name ?? "Text",
                frameInWindow: meta.frameInWindow,
                source: .swiftUI,
                lines: compactLines(size: meta.frameInWindow.size,
                                    font: meta.font,
                                    fontDescription: meta.fontDescription,
                                    textColor: meta.textColor,
                                    background: meta.background,
                                    padding: meta.padding),
                swatch: meta.textColor ?? meta.background))
        }

        // 2) Anlamlı UIKit view'lar.
        let windowArea = max(1, window.bounds.width * window.bounds.height)
        func walk(_ view: UIView) {
            for sub in view.subviews {
                if sub is InspectorOverlayView || sub is InspectAllOverlayView { continue }
                guard !sub.isHidden, sub.alpha > 0.02 else { continue }
                if isInteresting(sub), !isInternalWrapper(sub) {
                    let frame = sub.convert(sub.bounds, to: window)
                    let area = frame.width * frame.height
                    if frame.width >= 10, frame.height >= 10,
                       area < windowArea * 0.9,
                       window.bounds.intersects(frame) {
                        let (font, textColor) = textAttributes(of: sub)
                        targets.append(Target(
                            title: String(describing: type(of: sub)),
                            frameInWindow: frame,
                            source: .uiKit,
                            lines: compactLines(size: frame.size,
                                                font: font,
                                                textColor: textColor,
                                                background: sub.backgroundColor,
                                                padding: nil),
                            swatch: textColor ?? sub.backgroundColor))
                    }
                }
                walk(sub)
            }
        }
        walk(window)

        // 3) Accessibility yaprakları (annotate'siz SwiftUI). Var olan bir
        //    çerçeveye çok yakın olanları atla (registry/UIKit ile çakışmasın).
        for leaf in accessibilityLeaves(in: window) {
            let frame = leaf.frameInWindow
            let area = frame.width * frame.height
            guard frame.width >= 10, frame.height >= 10, area < windowArea * 0.9 else { continue }
            if targets.contains(where: { nearlyEqual($0.frameInWindow, frame) }) { continue }

            let role = roleName(leaf.traits)
            var lines = [String(format: "%.0f × %.0f", frame.width, frame.height), role]
            if let v = leaf.value, !v.isEmpty { lines.append("= " + String(v.prefix(24))) }

            targets.append(Target(
                title: leaf.label.isEmpty ? role : String(leaf.label.prefix(26)),
                frameInWindow: frame,
                source: .accessibility,
                lines: lines,
                swatch: nil))
        }

        // 4) Çizim katmanları — SwiftUI metin/görselleri UILabel değil, CALayer'a
        //    `contents` ile çizilir. Bunları toplamak SwiftUI ekranlarında kapsamı
        //    ciddi artırır (her çizilen öğe bir çerçeve alır).
        var visited = 0
        func walkLayers(_ layer: CALayer, depth: Int) {
            guard visited < 600, depth < 44, targets.count < 200 else { return }
            for sub in layer.sublayers ?? [] {
                visited += 1
                if sub.isHidden || sub.opacity < 0.02 { continue }
                if sub.contents != nil {
                    let frame = window.layer.convert(sub.bounds, from: sub)
                    let area = frame.width * frame.height
                    if frame.width >= 8, frame.height >= 6, area < windowArea * 0.5,
                       window.bounds.intersects(frame),
                       !targets.contains(where: { nearlyEqual($0.frameInWindow, frame) }) {
                        targets.append(Target(
                            title: "Drawing",
                            frameInWindow: frame,
                            source: .layer,
                            lines: [String(format: "%.0f × %.0f", frame.width, frame.height)],
                            swatch: nil))
                    }
                }
                walkLayers(sub, depth: depth + 1)
            }
        }
        walkLayers(window.layer, depth: 0)

        // En küçük (en spesifik) önce; kalabalığı sınırla.
        targets.sort { ($0.frameInWindow.width * $0.frameInWindow.height)
                     < ($1.frameInWindow.width * $1.frameInWindow.height) }
        return targets.count > 120 ? Array(targets.prefix(120)) : targets
    }

    private static func nearlyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 6) -> Bool {
        abs(a.minX - b.minX) < tolerance && abs(a.minY - b.minY) < tolerance &&
        abs(a.width - b.width) < tolerance && abs(a.height - b.height) < tolerance
    }

    private static func textAttributes(of v: UIView) -> (UIFont?, UIColor?) {
        if let l = v as? UILabel { return (l.font, l.textColor) }
        if let b = v as? UIButton { return (b.titleLabel?.font, b.currentTitleColor) }
        if let t = v as? UITextField { return (t.font, t.textColor) }
        if let t = v as? UITextView { return (t.font, t.textColor) }
        return (nil, nil)
    }

    private static func compactLines(size: CGSize,
                                     font: UIFont?,
                                     fontDescription: String? = nil,
                                     textColor: UIColor?,
                                     background: UIColor?,
                                     padding: UIEdgeInsets?) -> [String] {
        var lines = [String(format: "%.0f × %.0f", size.width, size.height)]
        if let desc = fontDescription {
            lines.append(desc)                       // reflected SwiftUI font (e.g. "Ubuntu-Bold · 15pt")
        } else if let f = font {
            lines.append(String(format: "%.0fpt · %@", f.pointSize, f.inspectorWeightName))
        }
        if let c = textColor {
            lines.append(c.inspectorDescription)
        }
        if let b = background {
            lines.append("bg " + b.inspectorDescription)
        }
        if let p = padding, p != .zero {
            if p.top == p.bottom, p.left == p.right, p.top == p.left {
                lines.append(String(format: "pad %.0f", p.top))
            } else {
                lines.append(String(format: "pad ↑%.0f ←%.0f ↓%.0f →%.0f", p.top, p.left, p.bottom, p.right))
            }
        }
        return lines
    }

    private static func isInteresting(_ v: UIView) -> Bool {
        if v is UILabel || v is UIButton || v is UIControl || v is UIImageView
            || v is UITextField || v is UITextView { return true }
        if let bg = v.backgroundColor, bg.cgColor.alpha > 0.02 { return true }
        if v.layer.cornerRadius > 0.5 || v.layer.borderWidth > 0.5 { return true }
        return false
    }

    // MARK: - Accessibility ağacı (annotate'siz SwiftUI granülerliği)

    /// SwiftUI'nin çizdiği (ayrı UIView olmayan) öğeleri, erişilebilirlik
    /// ağacından yakalanan bir yaprak.
    struct A11yLeaf {
        let frameInWindow: CGRect
        let label: String
        let value: String?
        let traits: UIAccessibilityTraits
    }

    /// Pencere altındaki tüm erişilebilirlik yapraklarını (Text/Button/Image...)
    /// pencere koordinatlarındaki çerçeveleriyle toplar.
    static func accessibilityLeaves(in window: UIWindow) -> [A11yLeaf] {
        var leaves: [A11yLeaf] = []
        let screenSpace = window.screen.coordinateSpace

        func addLeaf(_ obj: NSObject) {
            let screenFrame = obj.accessibilityFrame
            guard screenFrame.width > 1, screenFrame.height > 1 else { return }
            let frame = screenSpace.convert(screenFrame, to: window)
            guard window.bounds.intersects(frame) else { return }
            leaves.append(A11yLeaf(frameInWindow: frame,
                                   label: obj.accessibilityLabel ?? "",
                                   value: obj.accessibilityValue,
                                   traits: obj.accessibilityTraits))
        }

        // Erişilebilirlik çocukları hem dizi (`accessibilityElements`) hem de
        // method tabanlı (`accessibilityElementCount`/`accessibilityElement(at:)`)
        // API ile sunulabilir — SwiftUI/UIKit çoğunlukla ikincisini kullanır.
        func a11yChildren(of node: NSObject) -> [NSObject] {
            if let arr = node.accessibilityElements as? [NSObject], !arr.isEmpty {
                return arr
            }
            let count = node.accessibilityElementCount()
            guard count != NSNotFound, count > 0 else { return [] }
            var out: [NSObject] = []
            for i in 0..<min(count, 500) {
                if let el = node.accessibilityElement(at: i) as? NSObject { out.append(el) }
            }
            return out
        }

        func visit(_ node: NSObject, depth: Int) {
            guard leaves.count < 250, depth < 48 else { return }

            let children = a11yChildren(of: node)
            if !children.isEmpty {
                for child in children { visit(child, depth: depth + 1) }
                return
            }
            if let view = node as? UIView {
                if view is InspectorOverlayView || view is InspectAllOverlayView { return }
                if view.isHidden || view.alpha < 0.02 { return }
                if view.isAccessibilityElement {
                    addLeaf(view)
                } else {
                    for sub in view.subviews { visit(sub, depth: depth + 1) }
                }
            } else {
                addLeaf(node)   // UIAccessibilityElement yaprağı
            }
        }

        visit(window, depth: 0)
        return leaves
    }

    static func roleName(_ traits: UIAccessibilityTraits) -> String {
        if traits.contains(.button) { return "Button" }
        if traits.contains(.header) { return "Header" }
        if traits.contains(.link) { return "Link" }
        if traits.contains(.image) { return "Image" }
        if traits.contains(.searchField) { return "SearchField" }
        if traits.contains(.adjustable) { return "Adjustable" }
        if traits.contains(.staticText) { return "Text" }
        return "Element"
    }

    // MARK: - CALayer hit-test (çizilen görsel/şekiller)

    /// Verilen view'in katman ağacında, noktayı içeren ve view'den daha küçük
    /// alt-katmanları en spesifikten en genele döndürür.
    private static func layerCandidates(under view: UIView,
                                        at point: CGPoint,
                                        in window: UIWindow) -> [InspectedElement] {
        let viewFrame = view.convert(view.bounds, to: window)
        let viewArea = max(1, viewFrame.width * viewFrame.height)
        var found: [(CGRect, CALayer)] = []
        var visited = 0

        func walk(_ layer: CALayer, depth: Int) {
            guard visited < 150, depth < 28 else { return }
            for sub in layer.sublayers ?? [] {
                visited += 1
                if sub.isHidden || sub.opacity < 0.02 { continue }
                let frame = window.layer.convert(sub.bounds, from: sub)
                if frame.contains(point), frame.width >= 6, frame.height >= 6,
                   (frame.width * frame.height) < viewArea * 0.98 {
                    found.append((frame, sub))
                }
                walk(sub, depth: depth + 1)
            }
        }
        walk(view.layer, depth: 0)

        found.sort { ($0.0.width * $0.0.height) < ($1.0.width * $1.0.height) }

        var out: [InspectedElement] = []
        var used: [CGRect] = []
        for (frame, layer) in found {
            if used.contains(where: { nearlyEqual($0, frame) }) { continue }
            used.append(frame)
            out.append(element(fromLayer: layer, frameInWindow: frame))
            if out.count >= 6 { break }
        }
        return out
    }

    private static func element(fromLayer layer: CALayer, frameInWindow frame: CGRect) -> InspectedElement {
        let geometry = [
            InspectedProperty(label: "Origin", value: format(point: frame.origin)),
            InspectedProperty(label: "Size", value: format(size: frame.size)),
            InspectedProperty(label: "Center",
                              value: format(point: CGPoint(x: frame.midX, y: frame.midY)))
        ]

        var katman: [InspectedProperty] = [
            InspectedProperty(label: "Class", value: String(describing: type(of: layer)))
        ]
        let hasContents = layer.contents != nil
        if hasContents {
            katman.append(InspectedProperty(label: "Contents", value: "yes (image/drawing)"))
            // SwiftUI text/shapes expose no color property — sample the drawn
            // pixels so the card still reports the color the user actually sees.
            if let drawn = LayerColorSampler.dominantColor(of: layer) {
                katman.append(InspectedProperty(label: "Drawn color",
                                                value: drawn.inspectorDescription,
                                                swatch: drawn))
            }
        }
        if let bg = layer.backgroundColor {
            let c = UIColor(cgColor: bg)
            katman.append(InspectedProperty(label: "Background", value: c.inspectorDescription, swatch: c))
        }
        if layer.cornerRadius > 0.5 {
            katman.append(InspectedProperty(label: "Corner radius", value: String(format: "%.1f", layer.cornerRadius)))
        }
        if layer.borderWidth > 0.5 {
            katman.append(InspectedProperty(label: "Border", value: String(format: "%.1f", layer.borderWidth)))
        }
        katman.append(InspectedProperty(label: "Opacity", value: String(format: "%.2f", layer.opacity)))

        return InspectedElement(
            title: hasContents ? "Image/Drawing Layer" : String(describing: type(of: layer)),
            frameInWindow: frame,
            sections: [InspectedSection(title: "Geometry", properties: geometry),
                       InspectedSection(title: "Layer", properties: katman)],
            source: .layer)
    }

    private static func element(from leaf: A11yLeaf) -> InspectedElement {
        let role = roleName(leaf.traits)
        let frame = leaf.frameInWindow

        let geometry = [
            InspectedProperty(label: "Origin", value: format(point: frame.origin)),
            InspectedProperty(label: "Size", value: format(size: frame.size)),
            InspectedProperty(label: "Center",
                              value: format(point: CGPoint(x: frame.midX, y: frame.midY)))
        ]

        var a11y = [InspectedProperty(label: "Role", value: role)]
        if !leaf.label.isEmpty {
            a11y.append(InspectedProperty(label: "Label", value: "\"\(leaf.label.prefix(80))\""))
        }
        if let v = leaf.value, !v.isEmpty {
            a11y.append(InspectedProperty(label: "Value", value: "\"\(v.prefix(60))\""))
        }

        let title = leaf.label.isEmpty ? role : String(leaf.label.prefix(40))
        return InspectedElement(
            title: title,
            frameInWindow: frame,
            sections: [InspectedSection(title: "Geometry", properties: geometry),
                       InspectedSection(title: "Accessibility", properties: a11y)],
            source: .accessibility)
    }

    // MARK: - Hit-testing

    /// `userInteractionEnabled` / `isHidden` durumlarına bakılmaksızın, verilen
    /// noktayı içeren en derin (en önde) görünümü bulur. Kendi overlay
    /// pencerelerimizi atlar.
    static func deepestView(at pointInWindow: CGPoint,
                            in coordinateSpace: UIView,
                            root: UIView) -> UIView? {
        let local = root.convert(pointInWindow, from: coordinateSpace)
        guard shouldTraverse(root), root.bounds.contains(local) else {
            return nil
        }

        // Üstteki alt görünümler önce denensin (reversed = z-order tepesi).
        for sub in root.subviews.reversed() {
            if let hit = deepestView(at: pointInWindow, in: coordinateSpace, root: sub) {
                return hit
            }
        }
        return root
    }

    private static func shouldTraverse(_ view: UIView) -> Bool {
        if view is InspectorOverlayView || view is InspectAllOverlayView { return false }
        if view is GridOverlayView || view is FramesOverlayView || view is PassthroughView { return false }
        if view.alpha <= 0.01 { return false }
        // Tamamen görünmez ama layout'ta yer kaplayanları yine de gösterebiliriz;
        // burada yalnızca gizli olanları eleriz.
        if view.isHidden { return false }
        return true
    }

    // MARK: - SwiftUI metadata → element

    private static func element(from meta: SwiftUIMetadata) -> InspectedElement {
        var geometry: [InspectedProperty] = [
            InspectedProperty(label: "Origin", value: format(point: meta.frameInWindow.origin)),
            InspectedProperty(label: "Size", value: format(size: meta.frameInWindow.size))
        ]
        geometry.append(InspectedProperty(label: "Center",
                                          value: format(point: CGPoint(x: meta.frameInWindow.midX,
                                                                       y: meta.frameInWindow.midY))))

        var typography: [InspectedProperty] = []
        if let desc = meta.fontDescription {
            // The SwiftUI Font as set in code (reflected), e.g. "Ubuntu · 15pt".
            typography.append(InspectedProperty(label: "Font (SwiftUI)", value: desc))
        }
        if let font = meta.font {
            typography.append(InspectedProperty(label: "Font", value: font.inspectorFamilyName))
            typography.append(InspectedProperty(label: "PostScript", value: font.inspectorPostScriptName))
            typography.append(InspectedProperty(label: "Point size", value: String(format: "%.1f pt", font.pointSize)))
            typography.append(InspectedProperty(label: "Weight", value: font.inspectorWeightName))
        }
        if let color = meta.textColor {
            typography.append(InspectedProperty(label: "Text color",
                                                value: color.inspectorDescription,
                                                swatch: color))
        }

        var layout: [InspectedProperty] = []
        if let padding = meta.padding {
            layout.append(InspectedProperty(label: "Padding", value: format(insets: padding)))
        }

        var appearance: [InspectedProperty] = []
        if let bg = meta.background {
            appearance.append(InspectedProperty(label: "Background",
                                                value: bg.inspectorDescription,
                                                swatch: bg))
        }

        var sections = [InspectedSection(title: "Geometry", properties: geometry)]
        if !typography.isEmpty {
            sections.append(InspectedSection(title: "Typography", properties: typography))
        }
        if !layout.isEmpty {
            sections.append(InspectedSection(title: "Layout", properties: layout))
        }
        if !appearance.isEmpty {
            sections.append(InspectedSection(title: "Appearance", properties: appearance))
        }

        return InspectedElement(title: meta.name ?? "SwiftUI Element",
                                frameInWindow: meta.frameInWindow,
                                sections: sections,
                                source: .swiftUI)
    }

    // MARK: - UIKit view → element

    private static func element(from view: UIView, in window: UIWindow) -> InspectedElement {
        let frameInWindow = view.convert(view.bounds, to: window)

        // Geometri
        var geometry: [InspectedProperty] = [
            InspectedProperty(label: "Origin", value: format(point: frameInWindow.origin)),
            InspectedProperty(label: "Size", value: format(size: frameInWindow.size)),
            InspectedProperty(label: "Center",
                              value: format(point: CGPoint(x: frameInWindow.midX, y: frameInWindow.midY)))
        ]
        if let id = view.accessibilityIdentifier, !id.isEmpty {
            geometry.append(InspectedProperty(label: "a11y id", value: id))
        }

        var sections: [InspectedSection] = [InspectedSection(title: "Geometry", properties: geometry)]

        // Tipe özgü (metin / görsel) bölüm
        if let typeSection = typeSpecificSection(for: view) {
            sections.append(typeSection)
        }

        // Yerleşim / padding (boş değilse)
        if let layoutSection = layoutSection(for: view) {
            sections.append(layoutSection)
        }

        // Görünüm & katman
        sections.append(appearanceSection(for: view))

        return InspectedElement(title: String(describing: type(of: view)),
                                frameInWindow: frameInWindow,
                                sections: sections,
                                source: .uiKit)
    }

    private static func typeSpecificSection(for view: UIView) -> InspectedSection? {
        if let label = view as? UILabel {
            return textSection(text: label.text,
                               font: label.font,
                               color: label.textColor,
                               lines: label.numberOfLines,
                               alignment: label.textAlignment)
        }
        if let field = view as? UITextField {
            return textSection(text: field.text ?? field.placeholder,
                               font: field.font,
                               color: field.textColor,
                               lines: 1,
                               alignment: field.textAlignment)
        }
        if let textView = view as? UITextView {
            return textSection(text: textView.text,
                               font: textView.font,
                               color: textView.textColor,
                               lines: 0,
                               alignment: textView.textAlignment)
        }
        if let button = view as? UIButton {
            return textSection(text: button.titleLabel?.text ?? button.currentTitle,
                               font: button.titleLabel?.font,
                               color: button.currentTitleColor,
                               lines: button.titleLabel?.numberOfLines ?? 1,
                               alignment: button.titleLabel?.textAlignment ?? .center)
        }
        if let image = view as? UIImageView {
            var props: [InspectedProperty] = []
            if let img = image.image {
                props.append(InspectedProperty(label: "Image size", value: format(size: img.size)))
                props.append(InspectedProperty(label: "Scale", value: String(format: "%.0fx", img.scale)))
            } else {
                props.append(InspectedProperty(label: "Image", value: "none"))
            }
            props.append(InspectedProperty(label: "contentMode", value: contentModeName(image.contentMode)))
            return InspectedSection(title: "Image", properties: props)
        }
        return nil
    }

    private static func textSection(text: String?,
                                    font: UIFont?,
                                    color: UIColor?,
                                    lines: Int,
                                    alignment: NSTextAlignment) -> InspectedSection {
        var props: [InspectedProperty] = []
        if let text = text, !text.isEmpty {
            props.append(InspectedProperty(label: "Text", value: "\"\(text.prefix(80))\""))
        }
        if let font = font {
            props.append(InspectedProperty(label: "Font", value: font.inspectorFamilyName))
            props.append(InspectedProperty(label: "PostScript", value: font.inspectorPostScriptName))
            props.append(InspectedProperty(label: "Point size", value: String(format: "%.1f pt", font.pointSize)))
            props.append(InspectedProperty(label: "Weight", value: font.inspectorWeightName))
        }
        if let color = color {
            props.append(InspectedProperty(label: "Color",
                                           value: color.inspectorDescription,
                                           swatch: color))
        }
        props.append(InspectedProperty(label: "Lines", value: lines == 0 ? "unlimited" : "\(lines)"))
        props.append(InspectedProperty(label: "Alignment", value: alignmentName(alignment)))
        return InspectedSection(title: "Text", properties: props)
    }

    /// Padding / kenar boşlukları. Anlamlı bir değer yoksa nil döner.
    private static func layoutSection(for view: UIView) -> InspectedSection? {
        var props: [InspectedProperty] = []

        if view.layoutMargins != .zero {
            props.append(InspectedProperty(label: "layoutMargins",
                                           value: format(insets: view.layoutMargins)))
        }
        if view.safeAreaInsets != .zero {
            props.append(InspectedProperty(label: "safeArea",
                                           value: format(insets: view.safeAreaInsets)))
        }
        if let scroll = view as? UIScrollView, scroll.contentInset != .zero {
            props.append(InspectedProperty(label: "contentInset",
                                           value: format(insets: scroll.contentInset)))
        }
        if #available(iOS 15.0, *),
           let button = view as? UIButton,
           let insets = button.configuration?.contentInsets {
            props.append(InspectedProperty(
                label: "contentInsets",
                value: String(format: "↑%.0f ←%.0f ↓%.0f →%.0f",
                              insets.top, insets.leading, insets.bottom, insets.trailing)))
        }

        return props.isEmpty ? nil : InspectedSection(title: "Layout", properties: props)
    }

    private static func appearanceSection(for view: UIView) -> InspectedSection {
        var props: [InspectedProperty] = []

        if let bg = view.backgroundColor {
            props.append(InspectedProperty(label: "Background",
                                           value: bg.inspectorDescription,
                                           swatch: bg))
        } else {
            props.append(InspectedProperty(label: "Background", value: "clear/none"))
        }

        props.append(InspectedProperty(label: "Alpha", value: String(format: "%.2f", view.alpha)))

        let layer = view.layer
        if layer.cornerRadius > 0 {
            props.append(InspectedProperty(label: "Corner radius", value: String(format: "%.1f", layer.cornerRadius)))
        }
        if layer.borderWidth > 0 {
            props.append(InspectedProperty(label: "Border", value: String(format: "%.1f", layer.borderWidth)))
            if let border = layer.borderColor {
                let c = UIColor(cgColor: border)
                props.append(InspectedProperty(label: "Border color",
                                               value: c.inspectorDescription,
                                               swatch: c))
            }
        }
        if layer.shadowOpacity > 0 {
            props.append(InspectedProperty(label: "Shadow", value: String(format: "opacity %.2f · radius %.1f",
                                                                        layer.shadowOpacity, layer.shadowRadius)))
        }
        props.append(InspectedProperty(label: "clipsToBounds", value: view.clipsToBounds ? "true" : "false"))
        props.append(InspectedProperty(label: "userInteraction",
                                       value: view.isUserInteractionEnabled ? "on" : "off"))

        return InspectedSection(title: "Appearance & Layer", properties: props)
    }

    // MARK: - Biçimlendirme yardımcıları

    private static func format(point: CGPoint) -> String {
        String(format: "x %.1f · y %.1f", point.x, point.y)
    }

    private static func format(size: CGSize) -> String {
        String(format: "%.1f × %.1f", size.width, size.height)
    }

    private static func format(insets: UIEdgeInsets) -> String {
        if insets.top == insets.bottom, insets.left == insets.right, insets.top == insets.left {
            return String(format: "%.0f (all sides)", insets.top)
        }
        return String(format: "↑%.0f ←%.0f ↓%.0f →%.0f",
                      insets.top, insets.left, insets.bottom, insets.right)
    }

    private static func alignmentName(_ a: NSTextAlignment) -> String {
        switch a {
        case .left: return "left"
        case .center: return "center"
        case .right: return "right"
        case .justified: return "justified"
        case .natural: return "natural"
        @unknown default: return "?"
        }
    }

    private static func contentModeName(_ m: UIView.ContentMode) -> String {
        switch m {
        case .scaleToFill: return "scaleToFill"
        case .scaleAspectFit: return "aspectFit"
        case .scaleAspectFill: return "aspectFill"
        case .center: return "center"
        case .top: return "top"
        case .bottom: return "bottom"
        case .left: return "left"
        case .right: return "right"
        default: return "\(m.rawValue)"
        }
    }
}
#endif
