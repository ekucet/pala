import SwiftUI
import UIKit

// Reproduces the host app's session-activity observer: a passthrough window at
// .alert+100 that OVERRIDES sendEvent to watch touches. This is what conflicts
// with a global UIWindow.sendEvent swizzle.
final class TouchObserverWindow: UIWindow {
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        backgroundColor = .clear
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        rootViewController = vc
    }
    required init?(coder: NSCoder) { fatalError() }

    override func sendEvent(_ event: UIEvent) {
        // (observe touches here in the real app)
        super.sendEvent(event)
    }

    /// Return nil to pass ALL touches through (matches the host app).
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

enum SessionObserver {
    private static var window: TouchObserverWindow?
    static func start() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
        let w = TouchObserverWindow(windowScene: scene)
        w.windowLevel = .alert + 100
        w.isHidden = false
        window = w
    }
}
