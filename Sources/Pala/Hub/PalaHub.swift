//
//  PalaHub.swift
//  Pala
//
//  The floating debug hub: a draggable bubble that opens a tool menu.
//  Hosts passthrough overlays (grid, frames, touch dots) and the console panel.
//

#if canImport(UIKit)
import UIKit

@MainActor
final class PalaHub: NSObject {
    static let shared = PalaHub()
    private override init() { super.init() }

    private(set) var isEnabled = false

    private var window: PassthroughWindow?
    private var root: PassthroughView { window!.rootViewController!.view as! PassthroughView }

    private let bubble = UIButton(type: .custom)
    private var menu: UIView?

    private let grid = GridOverlayView()
    private let frames = FramesOverlayView()
    private var console: ConsolePanelView?

    private var framesTimer: Timer?

    // MARK: - Lifecycle

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        installIfPossible()
    }

    func disable() {
        isEnabled = false
        framesTimer?.invalidate(); framesTimer = nil
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }

    private func installIfPossible() {
        guard isEnabled, window == nil else { return }
        guard let scene = WindowSupport.activeWindowScene else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.installIfPossible() }
            return
        }
        let win = PassthroughWindow(windowScene: scene)
        win.windowLevel = .alert
        win.backgroundColor = .clear
        let vc = UIViewController()
        vc.view = PassthroughView(frame: win.bounds)
        win.rootViewController = vc
        win.isHidden = false
        window = win

        let rootView = root
        for overlay in [grid, frames] {
            overlay.frame = rootView.bounds
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.isHidden = true
            rootView.addSubview(overlay)
        }

        setupBubble(in: rootView)
    }

    // MARK: - Bubble

    private func setupBubble(in rootView: UIView) {
        bubble.frame = CGRect(x: 0, y: 0, width: 52, height: 52)
        bubble.accessibilityIdentifier = "pala.bubble"
        bubble.backgroundColor = UIColor.systemIndigo
        bubble.setTitle("🔎", for: .normal)
        bubble.titleLabel?.font = .systemFont(ofSize: 24)
        bubble.layer.cornerRadius = 26
        bubble.layer.shadowColor = UIColor.black.cgColor
        bubble.layer.shadowOpacity = 0.3
        bubble.layer.shadowRadius = 6
        bubble.layer.shadowOffset = CGSize(width: 0, height: 3)
        bubble.addTarget(self, action: #selector(toggleMenu), for: .touchUpInside)
        bubble.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragBubble(_:))))
        rootView.addSubview(bubble)

        let safe = rootView.safeAreaInsets
        let saved = UserDefaults.standard.dictionary(forKey: "pala.bubble")
        if let x = saved?["x"] as? CGFloat, let y = saved?["y"] as? CGFloat {
            bubble.center = CGPoint(x: x, y: y)
        } else {
            bubble.center = CGPoint(x: rootView.bounds.width - 44,
                                    y: rootView.bounds.height - safe.bottom - 120)
        }
    }

    @objc private func dragBubble(_ g: UIPanGestureRecognizer) {
        guard let rootView = window?.rootViewController?.view else { return }
        let t = g.translation(in: rootView)
        bubble.center = CGPoint(x: bubble.center.x + t.x, y: bubble.center.y + t.y)
        g.setTranslation(.zero, in: rootView)
        if g.state == .ended {
            UserDefaults.standard.set(["x": bubble.center.x, "y": bubble.center.y], forKey: "pala.bubble")
            dismissMenu()
        }
    }

    // MARK: - Menu

    private struct Item { let icon: String; let title: String; let toggled: () -> Bool; let action: () -> Void }

    @objc private func toggleMenu() {
        if menu != nil { dismissMenu(); return }
        guard let rootView = window?.rootViewController?.view else { return }

        let items: [Item] = [
            Item(icon: "🎯", title: "UI Inspector", toggled: { false }, action: { [weak self] in
                self?.dismissMenu(); InspectorController.shared.enterInspectMode() }),
            Item(icon: "🌈", title: "Inspect all", toggled: { false }, action: { [weak self] in
                self?.dismissMenu(); InspectorController.shared.showAllInline() }),
            Item(icon: "▦", title: "Grid", toggled: { [weak self] in !(self?.grid.isHidden ?? true) },
                 action: { [weak self] in self?.toggleGrid() }),
            Item(icon: "⬚", title: "Show frames", toggled: { [weak self] in !(self?.frames.isHidden ?? true) },
                 action: { [weak self] in self?.toggleFrames() })
        ]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        for item in items { stack.addArrangedSubview(menuRow(item)) }

        // Version label — lets you confirm the running build is up to date.
        let version = UILabel()
        version.text = "Pala \(Pala.version)"
        version.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        version.textColor = UIColor(white: 1, alpha: 0.4)
        version.textAlignment = .center
        version.accessibilityIdentifier = "pala.version"
        stack.addArrangedSubview(version)

        let panel = UIView()
        panel.backgroundColor = UIColor(white: 0.1, alpha: 0.97)
        panel.layer.cornerRadius = 12
        panel.layer.borderWidth = 0.5
        panel.layer.borderColor = UIColor(white: 1, alpha: 0.15).cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        rootView.addSubview(panel)
        rootView.bringSubviewToFront(bubble)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -8),
            panel.widthAnchor.constraint(equalToConstant: 200),
            panel.bottomAnchor.constraint(equalTo: bubble.topAnchor, constant: -8)
        ])
        let trailing = panel.trailingAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        trailing.priority = .defaultHigh
        trailing.isActive = true

        menu = panel
        panel.alpha = 0
        UIView.animate(withDuration: 0.15) { panel.alpha = 1 }
    }

    private func menuRow(_ item: Item) -> UIView {
        let b = UIButton(type: .system)
        b.accessibilityIdentifier = "pala.menu.\(item.title)"
        b.contentHorizontalAlignment = .left
        let on = item.toggled()
        b.setTitle("  \(item.icon)  \(item.title)\(on ? "  ✓" : "")", for: .normal)
        b.setTitleColor(on ? .systemGreen : .white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        b.heightAnchor.constraint(equalToConstant: 38).isActive = true
        b.addAction(UIAction { _ in item.action() }, for: .touchUpInside)
        return b
    }

    private func dismissMenu() {
        menu?.removeFromSuperview()
        menu = nil
    }

    private func rebuildMenu() { if menu != nil { dismissMenu(); toggleMenu() } }

    // MARK: - Tool toggles

    private func toggleGrid() { grid.isHidden.toggle(); rebuildMenu() }

    private func toggleFrames() {
        frames.isHidden.toggle()
        if frames.isHidden {
            framesTimer?.invalidate(); framesTimer = nil
        } else {
            refreshFrames()
            framesTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshFrames() }
            }
        }
        rebuildMenu()
    }

    private func refreshFrames() {
        guard let app = WindowSupport.activeKeyWindow else { return }
        frames.update(LayoutScanner.allFrames(in: app))
    }

    private func toggleConsole() {
        if let c = console, c.superview != nil {
            c.removeFromSuperview(); console = nil; rebuildMenu(); return
        }
        guard let rootView = window?.rootViewController?.view else { return }
        let panel = ConsolePanelView(frame: CGRect(x: 16, y: rootView.safeAreaInsets.top + 60,
                                                   width: min(360, rootView.bounds.width - 32), height: 380))
        panel.onClose = { [weak self] in self?.console?.removeFromSuperview(); self?.console = nil }
        panel.onShare = { [weak self] text in self?.share(text) }
        rootView.insertSubview(panel, belowSubview: bubble)
        console = panel
        dismissMenu()
    }

    private func share(_ text: String) {
        guard let vc = window?.rootViewController else { return }
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        av.popoverPresentationController?.sourceView = vc.view
        vc.present(av, animated: true)
    }
}

// MARK: - Passthrough window/view

@MainActor
final class PassthroughWindow: UIWindow {
    /// A `UIWindow` returns *itself* when no subview claims a point, which would
    /// swallow the touch (especially when another window sits above us). Return
    /// nil so touches fall through to the app's windows.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if hit === self || hit === rootViewController?.view { return nil }
        return hit
    }
}

@MainActor
final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit   // empty area → pass touches to the app
    }
}
#endif
