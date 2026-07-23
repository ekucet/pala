//
//  InspectAllOverlayView.swift
//  Pala
//
//  Ekrandaki her öğeyi renkli bir çerçeveyle işaretler ve öğenin YANINA
//  özelliklerini (boyut, font, renk, padding) doğrudan yazar. Kart/modal yok —
//  hepsi tek seferde, yerinde. Boşluğa dokununca kapanır.
//

#if canImport(UIKit)
import UIKit

@MainActor
final class InspectAllOverlayView: UIView {

    static let palette: [UIColor] = [
        .systemPink, .systemBlue, .systemPurple, .systemTeal,
        .systemOrange, .systemGreen, .systemIndigo, .systemRed
    ]

    var onDismiss: (() -> Void)?

    private let toolbar = PaddedLabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.15)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = UIColor.black.withAlphaComponent(0.15)
    }

    func present(_ targets: [ViewInspector.Target]) {
        for (i, t) in targets.enumerated() {
            let color = Self.palette[i % Self.palette.count]

            // Çerçeve
            let box = UIView(frame: t.frameInWindow)
            box.backgroundColor = color.withAlphaComponent(0.08)
            box.layer.borderColor = color.withAlphaComponent(0.95).cgColor
            box.layer.borderWidth = 1.5
            box.layer.cornerRadius = 2
            box.isUserInteractionEnabled = false
            addSubview(box)

            // Öğenin yanındaki özellik etiketi
            let label = makeInfoLabel(for: t, color: color)
            place(label, besides: t.frameInWindow)
            addSubview(label)
        }

        // Üst ipucu
        toolbar.text = "\(targets.count) elements · tap empty space to close"
        toolbar.font = .systemFont(ofSize: 12, weight: .semibold)
        toolbar.textColor = .white
        toolbar.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toolbar.layer.cornerRadius = 8
        toolbar.clipsToBounds = true
        toolbar.isUserInteractionEnabled = false
        addSubview(toolbar)

        alpha = 0
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
    }

    // MARK: - Etiket üretimi

    private func makeInfoLabel(for t: ViewInspector.Target, color: UIColor) -> UILabel {
        let label = PaddedLabel()
        label.inset = UIEdgeInsets(top: 4, left: 7, bottom: 4, right: 7)
        label.numberOfLines = 0
        label.isUserInteractionEnabled = false
        label.backgroundColor = UIColor(white: 0.07, alpha: 0.86)
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.layer.borderWidth = 1
        label.layer.borderColor = color.withAlphaComponent(0.9).cgColor

        let text = NSMutableAttributedString()
        // Başlık satırı — accent renkli, kalın.
        text.append(NSAttributedString(string: shortTitle(t.title) + "\n", attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .heavy),
            .foregroundColor: color
        ]))
        // Özellik satırları — monospace, beyaz.
        let body = t.lines.joined(separator: "\n")
        text.append(NSAttributedString(string: body, attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 10.5, weight: .medium),
            .foregroundColor: UIColor.white
        ]))
        label.attributedText = text

        label.preferredMaxLayoutWidth = 190
        label.sizeToFit()
        return label
    }

    /// Etiketi öğenin en uygun tarafına yerleştir: sağ → sol → alt → üst; hangisi
    /// ekrana tam sığıyorsa onu seç, hiçbiri sığmazsa sağa koyup ekrana kıstır.
    private func place(_ label: UILabel, besides rect: CGRect) {
        let gap: CGFloat = 6
        let w = label.bounds.width
        let h = label.bounds.height
        let m: CGFloat = 4

        let right = CGPoint(x: rect.maxX + gap, y: rect.minY)
        let left  = CGPoint(x: rect.minX - gap - w, y: rect.minY)
        let below = CGPoint(x: rect.minX, y: rect.maxY + gap)
        let above = CGPoint(x: rect.minX, y: rect.minY - gap - h)

        func fits(_ p: CGPoint) -> Bool {
            p.x >= m && p.y >= m &&
            p.x + w <= bounds.width - m && p.y + h <= bounds.height - m
        }

        let chosen = [right, left, below, above].first(where: fits) ?? right
        let x = min(max(m, chosen.x), bounds.width - w - m)
        let y = min(max(m, chosen.y), bounds.height - h - m)
        label.frame = CGRect(x: x, y: y, width: w, height: h)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        toolbar.sizeToFit()
        toolbar.center.x = bounds.midX
        toolbar.frame.origin.y = safeAreaInsets.top + 8
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.15, animations: { self.alpha = 0 },
                       completion: { _ in self.onDismiss?() })
    }

    private func shortTitle(_ s: String) -> String {
        let trimmed = s.split(separator: "<").first.map(String.init) ?? s
        return trimmed.count > 26 ? String(trimmed.prefix(26)) + "…" : trimmed
    }
}
#endif
