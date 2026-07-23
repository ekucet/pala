//
//  WindowSupport.swift
//  Pala
//

#if canImport(UIKit)
import UIKit

enum WindowSupport {

    /// The app's real content window to inspect — **excluding Pala's own hub
    /// window** (a `PassthroughWindow`) so the inspector never ends up inspecting the
    /// grid/frames overlays instead of the app. Prefers the key window; otherwise the
    /// lowest-level visible window (the main content sits below alert-level overlays).
    @MainActor
    static var activeKeyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted { ($0.activationState == .foregroundActive ? 0 : 1)
                    < ($1.activationState == .foregroundActive ? 0 : 1) }

        for scene in scenes {
            let candidates = scene.windows.filter { window in
                !(window is PassthroughWindow) && !window.isHidden
            }
            if let key = candidates.first(where: { $0.isKeyWindow }) { return key }
            if let main = candidates.min(by: { $0.windowLevel.rawValue < $1.windowLevel.rawValue }) {
                return main
            }
        }
        return nil
    }

    /// Overlay pencereyi doğru sahneye bağlamak için aktif window scene.
    @MainActor
    static var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }
}
#endif
