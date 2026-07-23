import SwiftUI
import UIKit

struct ContentView: View {
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 32) {
            Text("taps: \(taps)")
                .accessibilityIdentifier("tapCounter")

            Text("Pala")
                .font(.largeTitle.bold())
                .palaInspect("Title", font: .largeTitle, textColor: .label)

            Text("Tap the 🔎 bubble to open the debug hub")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("subtitle")

            Button("Log an event") {
                taps += 1
                Pala.info("Button tapped \(taps)", category: "UI")
            }
            .accessibilityIdentifier("logButton")

            // SwiftUI buton — kesin meta veri iliştirilmiş
            Text("Sign In")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 32)
                .background(Color.blue)
                .clipShape(Capsule())
                .accessibilityIdentifier("loginButton")
                .palaInspect("Sign In Button",
                                font: .custom("Helvetica-Bold", size: 17, relativeTo: .body),
                                textColor: .white,
                                background: .systemBlue,
                                padding: UIEdgeInsets(top: 14, left: 32, bottom: 14, right: 32))

            // Mimics the host app: palaInspect applied INSIDE a custom modifier.
            Text("Typo Test")
                .demoTypography()
                .accessibilityIdentifier("typoTest")

            // Feeds the inspector via the bridge only — NO import Pala in the modifier.
            Text("Bridge Test")
                .bridgeTypography()
                .accessibilityIdentifier("bridgeTest")

            // UIKit öğe — otomatik (annotate'siz) inceleme
            UIKitBadge(text: "UIKit Label")
                .frame(width: 220, height: 52)
                .accessibilityIdentifier("uikitBadge")

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            SessionObserver.start()   // reproduce host app's sendEvent-observer window
            Pala.info("App launched", category: "App")
            Pala.debug("Loading user profile…", category: "Network")
            Pala.warning("Cache miss for key=session", category: "Cache")
            Pala.error("Failed to decode response", category: "Network")
        }
    }
}

/// Mimics NlDesignSystem's TypographyModifier: applies font + palaInspect INSIDE
/// a custom ViewModifier (to test whether nesting via `.modifier()` breaks capture).
struct DemoTypographyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title3)
            .palaInspect("DemoTypo", font: .custom("Helvetica", size: 19))
    }
}
extension View {
    func demoTypography() -> some View { modifier(DemoTypographyModifier()) }
}

/// Writes font metadata DIRECTLY to Pala's shared store — NO `import Pala`.
/// Proves a design-system package can feed the inspector without depending on Pala.
enum PalaFontBridge {
    static func register(id: String, fontDescription: String, frame: CGRect) {
        guard !frame.isEmpty else { return }
        let key = unsafeBitCast(NSSelectorFromString("palaSharedRegistryV1"),
                                to: UnsafeRawPointer.self)
        let app = UIApplication.shared
        let store: NSMutableDictionary
        if let s = objc_getAssociatedObject(app, key) as? NSMutableDictionary {
            store = s
        } else {
            store = NSMutableDictionary()
            objc_setAssociatedObject(app, key, store, .OBJC_ASSOCIATION_RETAIN)
        }
        let entry = NSMutableDictionary()
        entry["fontDescription"] = fontDescription
        entry["frame"] = NSValue(cgRect: frame)
        store[id] = entry
    }
}

/// A modifier that feeds the inspector via the bridge only (no palaInspect).
struct BridgeTypographyModifier: ViewModifier {
    @State private var id = UUID().uuidString
    func body(content: Content) -> some View {
        content
            .font(.custom("Courier", size: 18))
            .background(GeometryReader { geo -> Color in
                PalaFontBridge.register(id: id, fontDescription: "Courier · 18pt",
                                           frame: geo.frame(in: .global))
                return Color.clear
            })
    }
}
extension View {
    func bridgeTypography() -> some View { modifier(BridgeTypographyModifier()) }
}

/// Otomatik UIKit incelemesini göstermek için gerçek bir UILabel.
struct UIKitBadge: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .systemPurple
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemGray6
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = text
    }
}
