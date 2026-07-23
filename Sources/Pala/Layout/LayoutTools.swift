//
//  LayoutTools.swift
//  Pala
//
//  Passthrough layout overlays: grid, all-frames borders, and touch indicators.
//

#if canImport(UIKit)
import UIKit

// MARK: - Grid

@MainActor
final class GridOverlayView: UIView {
    var spacing: CGFloat = 8 { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) { super.init(frame: frame); shared() }
    required init?(coder: NSCoder) { super.init(coder: coder); shared() }
    private func shared() { backgroundColor = .clear; isUserInteractionEnabled = false }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.18).cgColor)
        ctx.setLineWidth(0.5)
        var x: CGFloat = 0
        while x <= rect.width { ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: rect.height)); x += spacing }
        var y: CGFloat = 0
        while y <= rect.height { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: rect.width, y: y)); y += spacing }
        ctx.strokePath()
        // Emphasise every 8th line.
        ctx.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(0.5)
        x = 0
        while x <= rect.width { ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: rect.height)); x += spacing * 8 }
        y = 0
        while y <= rect.height { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: rect.width, y: y)); y += spacing * 8 }
        ctx.strokePath()
    }
}

// MARK: - All frames

@MainActor
final class FramesOverlayView: UIView {
    private var frames: [CGRect] = []

    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { super.init(coder: coder); backgroundColor = .clear; isUserInteractionEnabled = false }

    func update(_ rects: [CGRect]) { frames = rects; setNeedsDisplay() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setStrokeColor(UIColor.systemPink.withAlphaComponent(0.55).cgColor)
        ctx.setLineWidth(0.5)
        for f in frames { ctx.stroke(f) }
    }
}

// MARK: - Frame collection

enum LayoutScanner {
    @MainActor
    static func allFrames(in window: UIWindow) -> [CGRect] {
        var out: [CGRect] = []
        func walk(_ v: UIView) {
            for sub in v.subviews {
                if sub is InspectorOverlayView || sub is InspectAllOverlayView { continue }
                if String(describing: type(of: sub)).hasPrefix("Pala") { continue }
                guard !sub.isHidden, sub.alpha > 0.02, sub.bounds.width > 1, sub.bounds.height > 1 else { continue }
                out.append(sub.convert(sub.bounds, to: window).integral)
                walk(sub)
                if out.count > 800 { return }
            }
        }
        walk(window)
        return out
    }
}
#endif
