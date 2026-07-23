//
//  HintOverlayView.swift
//  Pala
//
//  Ekranın en üstüne yerleşen, hafif/translucent (blur) hint kartı + incelenen
//  öğenin etrafındaki renkli highlight çerçevesini çizen tam-ekran overlay.
//

#if canImport(UIKit)
import UIKit

@MainActor
final class InspectorOverlayView: UIView {

    /// Öğeye göre değişen renkli vurgu paleti ("renkli" görünüm).
    private static let palette: [UIColor] = [
        .systemPink, .systemBlue, .systemPurple, .systemTeal,
        .systemOrange, .systemGreen, .systemIndigo, .systemRed
    ]

    private let dimView = UIView()
    private let highlightView = UIView()
    private let sizeBadge = PaddedLabel()
    private let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let cardScroll = UIScrollView()
    private let cardStack = UIStackView()

    private var elements: [InspectedElement] = []
    private var index = 0

    private let closeButton = UIButton(type: .system)
    private var cardTopConstraint: NSLayoutConstraint?
    private var cardBottomConstraint: NSLayoutConstraint?

    var onDismiss: (() -> Void)?

    // MARK: - İnceleme modu (dokunarak gez)
    /// true ise: dışarı dokunma katmanı kapatmaz, o noktadaki öğeyi gösterir.
    /// Ayrıca kart alta taşınır (üstteki öğeler dokunulabilir kalsın).
    var browseMode = false {
        didSet {
            closeButton.isHidden = !browseMode
            cardTopConstraint?.isActive = !browseMode
            cardBottomConstraint?.isActive = browseMode
        }
    }
    /// Verilen pencere noktası için incelenecek katman yığınını döndürür.
    var onInspectPoint: ((CGPoint) -> [InspectedElement])?
    /// ✕ ile moddan çıkış.
    var onExit: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        // Çok hafif karartma — düşük opacity.
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.05)
        dimView.frame = bounds
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(dimView)

        // Highlight çerçevesi (renk present()'te ayarlanır).
        highlightView.layer.borderWidth = 2
        highlightView.layer.cornerRadius = 3
        highlightView.isUserInteractionEnabled = false
        addSubview(highlightView)

        // Boyut rozeti
        sizeBadge.textColor = .white
        sizeBadge.font = .systemFont(ofSize: 11, weight: .bold)
        sizeBadge.layer.cornerRadius = 5
        sizeBadge.clipsToBounds = true
        sizeBadge.isUserInteractionEnabled = false
        addSubview(sizeBadge)

        // Kart — translucent blur (hafif, düşük opacity görünüm)
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.separator.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        // Yumuşak gölge için kabı ayrıca gölgelemiyoruz (clip yüzünden); yeterli.
        addSubview(card)

        cardScroll.translatesAutoresizingMaskIntoConstraints = false
        cardScroll.showsVerticalScrollIndicator = true
        card.contentView.addSubview(cardScroll)

        cardStack.axis = .vertical
        cardStack.spacing = 10
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardScroll.addSubview(cardStack)

        let safe = safeAreaLayoutGuide

        // Scroll yüksekliğini içeriğe eşitle (999) — böylece kart içeriğe göre
        // büyür; ekranın %60'ını aşarsa (required üst sınır) scroll edilir.
        let scrollHeight = cardScroll.heightAnchor.constraint(equalTo: cardStack.heightAnchor)
        scrollHeight.priority = .defaultHigh

        // Kart üstte (varsayılan) ya da altta (browse modu) sabitlenir.
        cardTopConstraint = card.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12)
        cardTopConstraint?.isActive = true
        cardBottomConstraint = card.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            card.heightAnchor.constraint(lessThanOrEqualTo: safe.heightAnchor, multiplier: 0.6),

            cardScroll.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
            cardScroll.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
            cardScroll.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
            cardScroll.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -14),

            cardStack.topAnchor.constraint(equalTo: cardScroll.contentLayoutGuide.topAnchor),
            cardStack.leadingAnchor.constraint(equalTo: cardScroll.contentLayoutGuide.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: cardScroll.contentLayoutGuide.trailingAnchor),
            cardStack.bottomAnchor.constraint(equalTo: cardScroll.contentLayoutGuide.bottomAnchor),
            cardStack.widthAnchor.constraint(equalTo: cardScroll.frameLayoutGuide.widthAnchor),
            scrollHeight
        ])

        // ✕ kapatma butonu (yalnızca inceleme modunda görünür)
        closeButton.isHidden = true
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        closeButton.layer.cornerRadius = 18
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -14),
            closeButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 10),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func exitTapped() {
        UIView.animate(withDuration: 0.15, animations: { self.alpha = 0 },
                       completion: { _ in self.onExit?() })
    }

    // MARK: - İçerik

    func present(_ elements: [InspectedElement]) {
        self.elements = elements
        self.index = 0
        if elements.isEmpty {
            showPlaceholder()
        } else {
            showCurrent(entering: true)
        }
    }

    private func showPlaceholder() {
        highlightView.alpha = 0
        sizeBadge.alpha = 0
        cardScroll.setContentOffset(.zero, animated: false)
        cardStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let title = UILabel()
        title.text = "Inspect mode"
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textColor = .label

        let hint = UILabel()
        hint.text = "Tap an element · ✕ to exit"
        hint.font = .systemFont(ofSize: 12, weight: .medium)
        hint.textColor = .secondaryLabel

        cardStack.addArrangedSubview(title)
        cardStack.addArrangedSubview(hint)
        card.alpha = 1
        card.transform = .identity
    }

    private func showCurrent(entering: Bool) {
        guard elements.indices.contains(index) else { return }
        let element = elements[index]
        let accent = Self.accent(for: element.title)

        // Highlight — renkli, düşük dolgu opacity'si.
        highlightView.frame = element.frameInWindow
        highlightView.backgroundColor = accent.withAlphaComponent(0.14)
        highlightView.layer.borderColor = accent.cgColor
        positionSizeBadge(for: element.frameInWindow, accent: accent)

        // Kartı yeniden doldur
        cardScroll.setContentOffset(.zero, animated: false)
        cardStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        cardStack.addArrangedSubview(makeHeader(element, accent: accent))
        for prop in Self.essentials(of: element) {
            cardStack.addArrangedSubview(makeRow(prop))
        }
        cardStack.addArrangedSubview(makeFooter())

        if entering {
            // Küçük giriş animasyonu
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: -12)
            highlightView.alpha = 0
            sizeBadge.alpha = 0
            UIView.animate(withDuration: 0.24, delay: 0,
                           usingSpringWithDamping: 0.82, initialSpringVelocity: 0.5,
                           options: [.curveEaseOut]) {
                self.card.alpha = 1
                self.card.transform = .identity
                self.highlightView.alpha = 1
                self.sizeBadge.alpha = 1
            }
        } else {
            // Katman değişimi — highlight'ı kısa süre vurgula.
            highlightView.alpha = 1
            sizeBadge.alpha = 1
            UIView.animate(withDuration: 0.12, animations: {
                self.highlightView.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
            }, completion: { _ in
                UIView.animate(withDuration: 0.12) { self.highlightView.transform = .identity }
            })
        }
    }

    @objc private func stepPrev() {
        guard elements.count > 1 else { return }
        index = (index - 1 + elements.count) % elements.count
        showCurrent(entering: false)
    }

    @objc private func stepNext() {
        guard elements.count > 1 else { return }
        index = (index + 1) % elements.count
        showCurrent(entering: false)
    }

    private func positionSizeBadge(for frame: CGRect, accent: UIColor) {
        sizeBadge.backgroundColor = accent
        sizeBadge.text = String(format: "%.0f × %.0f", frame.width, frame.height)
        sizeBadge.sizeToFit()
        var origin = CGPoint(x: frame.minX, y: frame.maxY + 4)
        if origin.y + sizeBadge.bounds.height > bounds.height - 8 {
            origin.y = frame.minY - sizeBadge.bounds.height - 4
        }
        origin.x = min(max(8, origin.x), bounds.width - sizeBadge.bounds.width - 8)
        sizeBadge.frame.origin = origin
    }

    // MARK: - Yapı taşları

    private func makeHeader(_ element: InspectedElement, accent: UIColor) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 8
        container.alignment = .center

        let dot = UIView()
        dot.backgroundColor = accent
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10)
        ])
        dot.setContentHuggingPriority(.required, for: .horizontal)

        let title = UILabel()
        title.text = element.title
        title.textColor = .label
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.numberOfLines = 2
        title.lineBreakMode = .byTruncatingTail
        // Yer daralınca sayaç/rozet değil, başlık kısalsın.
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let badge = PaddedLabel()
        badge.text = element.source.rawValue
        badge.font = .systemFont(ofSize: 10, weight: .heavy)
        badge.textColor = .white
        badge.backgroundColor = accent
        badge.layer.cornerRadius = 5
        badge.clipsToBounds = true
        badge.setContentHuggingPriority(.required, for: .horizontal)

        container.addArrangedSubview(dot)
        container.addArrangedSubview(title)
        if elements.count > 1 {
            container.addArrangedSubview(makeStepper(accent: accent))
        }
        container.addArrangedSubview(badge)
        return container
    }

    /// Katman gezgini: ◀ i/n ▶ — parmağın altındaki view yığınında gezinmeyi sağlar.
    private func makeStepper(accent: UIColor) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 4
        row.alignment = .center
        row.setContentHuggingPriority(.required, for: .horizontal)
        row.setContentCompressionResistancePriority(.required, for: .horizontal)

        let prev = UIButton(type: .system)
        prev.setTitle("◀", for: .normal)
        prev.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        prev.tintColor = accent
        prev.addTarget(self, action: #selector(stepPrev), for: .touchUpInside)
        prev.widthAnchor.constraint(equalToConstant: 30).isActive = true
        prev.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let count = UILabel()
        count.text = "\(index + 1)/\(elements.count)"
        count.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        count.textColor = .secondaryLabel
        count.lineBreakMode = .byClipping
        count.setContentCompressionResistancePriority(.required, for: .horizontal)
        count.setContentHuggingPriority(.required, for: .horizontal)

        let next = UIButton(type: .system)
        next.setTitle("▶", for: .normal)
        next.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        next.tintColor = accent
        next.addTarget(self, action: #selector(stepNext), for: .touchUpInside)
        next.widthAnchor.constraint(equalToConstant: 30).isActive = true
        next.heightAnchor.constraint(equalToConstant: 30).isActive = true

        row.addArrangedSubview(prev)
        row.addArrangedSubview(count)
        row.addArrangedSubview(next)
        return row
    }

    private func makeSectionView(_ section: InspectedSection, accent: UIColor) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 5

        let header = UILabel()
        header.text = section.title.uppercased()
        header.textColor = accent
        header.font = .systemFont(ofSize: 10, weight: .heavy)
        stack.addArrangedSubview(header)

        for prop in section.properties {
            stack.addArrangedSubview(makeRow(prop))
        }
        return stack
    }

    private func makeRow(_ prop: InspectedProperty) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center

        let label = UILabel()
        label.text = prop.label
        label.textColor = .secondaryLabel
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let value = UILabel()
        value.text = prop.value
        value.textColor = .label
        value.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        value.numberOfLines = 0
        value.textAlignment = .right

        row.addArrangedSubview(label)
        if let swatch = prop.swatch {
            let dot = UIView()
            dot.backgroundColor = swatch
            dot.layer.cornerRadius = 3
            dot.layer.borderWidth = 0.5
            dot.layer.borderColor = UIColor.separator.cgColor
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 12),
                dot.heightAnchor.constraint(equalToConstant: 12)
            ])
            row.addArrangedSubview(dot)
        }
        row.addArrangedSubview(value)
        return row
    }

    private func makeFooter() -> UIView {
        let label = UILabel()
        if browseMode {
            label.text = elements.count > 1
                ? "◀ ▶ layers · tap another · ✕ exit"
                : "Tap another element · ✕ to exit"
        } else {
            label.text = elements.count > 1
                ? "◀ ▶ to step layers · tap outside to close"
                : "Tap anywhere to close"
        }
        label.textColor = .tertiaryLabel
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textAlignment = .center
        return label
    }

    // MARK: - Kompakt: yalnızca boyut · font · renk

    /// Karta sığacak kadar öz bilgi: boyut, font (adı/punto/weight), metin & arka
    /// plan rengi. Diğer her şey (origin, katman, alpha…) gizlenir.
    private static func essentials(of element: InspectedElement) -> [InspectedProperty] {
        let order = ["Size", "Font (SwiftUI)", "Font", "PostScript",
                     "Point size", "Weight", "Text color", "Color", "Background"]
        let all = element.sections.flatMap { $0.properties }
        var rows: [InspectedProperty] = []
        for label in order {
            if let prop = all.first(where: { $0.label == label }) { rows.append(prop) }
        }
        return rows
    }

    // MARK: - Renk seçimi (öğe adına göre stabil)

    private static func accent(for key: String) -> UIColor {
        let sum = key.utf8.reduce(0) { $0 + Int($1) }
        return palette[sum % palette.count]
    }

    // MARK: - Dokunma yönetimi

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        if card.frame.contains(p) { return }   // kart kendi dokunuşlarını yönetir

        if browseMode {
            // O noktadaki öğeyi göster; uygulama aksiyon almaz (katman yutar).
            let hits = onInspectPoint?(p) ?? []
            if !hits.isEmpty {
                elements = hits
                index = 0
                showCurrent(entering: true)
            }
            return
        }
        dismiss()
    }

    private func dismiss() {
        UIView.animate(withDuration: 0.18, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.onDismiss?()
        })
    }
}

/// İç boşluklu (padding) etiket — rozetler için.
@MainActor
final class PaddedLabel: UILabel {
    var inset = UIEdgeInsets(top: 3, left: 7, bottom: 3, right: 7)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: inset))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + inset.left + inset.right,
                      height: size.height + inset.top + inset.bottom)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let base = super.sizeThatFits(size)
        return CGSize(width: base.width + inset.left + inset.right,
                      height: base.height + inset.top + inset.bottom)
    }
}
#endif
