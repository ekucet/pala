//
//  InspectorController.swift
//  Pala
//
//  Presents the UI inspector (inspect mode + inspect-all), launched by the hub.
//

#if canImport(UIKit)
import UIKit

@MainActor
final class InspectorController {

    static let shared = InspectorController()
    private init() {}

    private var overlayWindow: UIWindow?

    /// Enter inspect mode: a touch-intercepting overlay lets you tap elements to
    /// browse their details without firing the app's own actions.
    func enterInspectMode() {
        guard let window = WindowSupport.activeKeyWindow else { return }
        teardownOverlay()

        let overlay = makeOverlayWindow()
        let root = InspectorOverlayView(frame: overlay.bounds)
        root.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.browseMode = true
        root.onExit = { [weak self] in self?.teardownOverlay() }
        root.onInspectPoint = { p in ViewInspector.inspectStack(at: p, in: window) }

        let vc = UIViewController()
        vc.view = root
        overlay.rootViewController = vc
        overlay.isHidden = false
        root.present([])   // placeholder: "Tap an element"
        overlayWindow = overlay

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Show every element outlined with a colored rectangle + inline properties.
    func showAllInline() {
        guard let window = WindowSupport.activeKeyWindow else { return }
        let targets = ViewInspector.allTargets(in: window)
        guard !targets.isEmpty else { return }
        teardownOverlay()

        let overlay = makeOverlayWindow()
        let root = InspectAllOverlayView(frame: overlay.bounds)
        root.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.onDismiss = { [weak self] in self?.teardownOverlay() }

        let vc = UIViewController()
        vc.view = root
        overlay.rootViewController = vc
        overlay.isHidden = false
        root.present(targets)
        overlayWindow = overlay

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Overlay window

    private func makeOverlayWindow() -> UIWindow {
        let overlay: UIWindow
        if let scene = WindowSupport.activeWindowScene {
            overlay = UIWindow(windowScene: scene)
        } else {
            overlay = UIWindow(frame: UIScreen.main.bounds)
        }
        overlay.windowLevel = .alert + 1   // above the hub bubble
        overlay.backgroundColor = .clear
        return overlay
    }

    private func teardownOverlay() {
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil
    }
}
#endif
