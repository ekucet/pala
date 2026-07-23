# Changelog

All notable changes to **Pala** are documented here.

## [1.0.2] — 2026-07-23

### Added
- **Color names from your design system.** `Pala.registerColors(_:)` registers named
  tokens, so the inspector prints `Primary6 · #0F62FE` instead of a bare hex —
  everywhere it resolves a color (UIKit text, backgrounds, layers, `.palaInspect`
  metadata). A registered token wins over the system color it resembles.
- **Drawn-color sampling.** SwiftUI `Text` has no readable color property (it's drawn
  into a `CALayer`), so tapping one now reports a **Drawn color** sampled from the
  rendered pixels — the dominant opaque color, i.e. the ink the user actually sees.
  Works regardless of how the color was applied (`foregroundColor`, `foregroundStyle`,
  or a design-system modifier).

## [1.0.1] — 2026-07-23

### Added
- **New brand mark.** The bubble now shows the Pala face (sunglasses silhouette) as a
  clean circle, replacing the magnifier glyph; same art ships as the Example app icon.
  The image is embedded in-source (base64) so the library still needs **no resource
  bundle** and renders identically however it's integrated.
- **Smart menu placement.** The tool menu opens **upward** by default but flips
  **downward** when the bubble sits near the top, and clamps **left/right** to stay fully
  on screen wherever the bubble is dragged.

### Changed
- README rewritten with fresh screenshots and the new brand mark.

## [1.0.0] — 2026-07-23

First release under the **Pala** name — rebranded from *Pablogy*, feature-equivalent
to the former 4.0.9. Also fixes the stale color/font unit tests and makes the
registry store resilient when `UIApplication.shared` is unavailable (hostless tests).
Earlier entries below are retained as historical context under the old name.

## [4.0.9] — 2026-07-23

### Fixed
- **Fonts from a design-system package now reach the inspector.** In multi-package apps
  Pala can be linked as two static copies, each with its own `InspectorRegistry.shared`;
  a `.palaInspect` baked into a shared `TypographyModifier` registered into a copy the
  hub could not see, so annotated fonts never appeared. The registry is now **process-global**
  (stored on `UIApplication` via an interned selector key), so any copy's registrations are
  visible to the hub. Reverted the dynamic-library workaround � static linking is fine now.

## [4.0.7] — 2026-07-23

### Fixed
- **Fonts now show in multi-package apps.** Pala is now a **dynamic library**, so an
  app and a design-system package that both depend on Pala share ONE instance (one
  registry). Previously a static copy per module meant `.palaInspect` (e.g. baked
  into a `TypographyModifier`) registered into one registry while the hub read another —
  so annotated SwiftUI fonts never appeared.

## [4.0.6] — 2026-07-23

### Changed
- **Hide internal wrapper views** — SwiftUI/UIKit private containers (`_UIHostingView`,
  `PlatformGroupContainer`, `*GraphicsView`, `_`-prefixed views…) are no longer shown
  in the inspector or inspect-all; they were noise. Real content views and your own
  views are unaffected.

## [4.0.5] — 2026-07-22

### Fixed
- **Inspect-all now shows the SwiftUI font** from `.palaInspect(font:)`. Previously the
  inline label only used the UIFont, so `.palaInspect(font: .custom("Ubuntu", size: 15))`
  entries showed size only. They now show the reflected font (e.g. "Ubuntu-Bold · 15pt").

## [4.0.4] — 2026-07-22

### Changed
- **Compact tap card** — the inspect card now shows only the essentials: **size, font
  (name · point size · weight), text color and background**. Everything else (origin,
  center, layer, alpha…) is hidden for a small, focused readout.

## [4.0.3] — 2026-07-22

### Improved
- **Inspect-all coverage** — SwiftUI text/images are drawn into `CALayer`s (not
  `UILabel`s), so they were mostly missed. Inspect-all now also collects
  contents-bearing drawing layers, so SwiftUI screens outline far more elements.
- **Inline label placement** — each element's property label is now placed on the best
  free side (right → left → below → above) instead of only right/left/below.

## [4.0.2] — 2026-07-22

### Fixed
- **Inspector was stuck on Pala's own overlay.** With Grid/frames on (or in
  multi-window apps), it could inspect Pala's full-screen overlay instead of the app,
  so every tap showed the same view and you couldn't browse elements. It now resolves
  the app's real content window, **excluding Pala's own hub window**, and skips its
  overlay views.
- **Ordering:** the most informative candidate (SwiftUI/UIKit element with font/color)
  is shown first, instead of a tiny raw drawing layer.

### Removed
- **Console** removed from the tool menu (the `Pala.log(...)` API still exists).

## [4.0.1] — 2026-07-22

### Fixed
- **Taps stopped working** in apps that have another passthrough window above the hub
  (e.g. a session-activity observer window at a high `windowLevel`). The hub window now
  overrides `hitTest` to return nil for empty areas, so touches always fall through to
  the app. Covered by a regression test that reproduces the exact scenario.

### Removed
- The **Touch dots** tool and its global `UIWindow.sendEvent` swizzle — it was invasive
  and could conflict with apps that observe `sendEvent` themselves.

## [4.0.0] — 2026-07-22

Pala is now a **floating debug hub**, not just an inspector.

### Added
- **SwiftUI Font readout** — `.palaInspect(font: .headline)` (or `.system(...)`,
  `.custom("Ubuntu", size: 15)`) shows **what the font was set to** in code, resolved
  by reflecting the SwiftUI `Font` (name · size · weight). `.palaInspect()` with no
  font auto-captures the inherited environment font. Great for spotting design
  mismatches (e.g. "should be Ubuntu 15 purple — is it?").
- **Debug hub** — a draggable **🔎 bubble** opens a tool menu.
- **Console tool** — a floating, draggable log viewer with level badges, category,
  search, filter, clear and share. Public API: `Pala.log/info/warning/error/debug(...)`.
- **Layout overlays** — **Grid**, **Show frames** (live view outlines) and **Touch dots**.
- **Inspect-all** and the **UI Inspector** are now launched from the hub menu.

### Changed
- **Public API (breaking):** `Pala.enable()` now installs the hub (no `activation:`
  parameter). The old gesture-based activation and `Pala.Activation` are removed.
  `.enablePala()` (SwiftUI) and `.palaInspect(...)` remain.

### Notes
- The UI Inspector keeps everything from 3.x: inspect mode, layer navigator, accessibility
  + CALayer inspection, color names and clearer font output.

## [3.0.1] — 2026-07-22

### Changed
- Documentation: README rewritten end-to-end — features, step-by-step Xcode install
  with the SPM **Up to Next Major Version** note, a gestures table, and architecture.

## [3.0.0] — 2026-07-22

### Changed
- **Minimum deployment target raised to iOS 16** (breaking).
- **All user-facing strings are now in English** (card labels, inspect mode, inline-all).

### Added
- **Clearer font output** — friendly family name (`SF Pro (System)` for the system
  font, real family for custom fonts) plus the exact **PostScript** name, point size
  and weight, for UIKit and `.palaInspect`-annotated elements.

### Fixed
- Candidate ordering — all sources are merged and ranked by area + information
  richness, so a `UILabel` (with font/color) is shown before its accessibility
  wrapper instead of after it.

### Notes
- Exact font/color for **un-annotated pure-SwiftUI `Text`** is still not readable —
  no public API exposes it (SwiftUI draws text with CoreGraphics). Frame/label/role
  come from accessibility; use `.palaInspect(font:)` for precise typography.

## [2.1.0] — 2026-07-22

### Added
- **Inspect mode** — long-press (3 s) enters a mode whose overlay intercepts all
  touches, so you can tap elements one by one to browse their info **without firing
  the app's own actions**. The card sits at the bottom (top elements stay tappable);
  `◀ i/n ▶` steps layers; **✕** exits.
- **Color names** — known system colors are shown by name next to the hex
  (e.g. `systemBlue · #007AFF`, `label`, `white`).

### Changed
- The default activation is now **long-press (3 s) → inspect mode** instead of
  double-tap. Double-tap is still available via `.enablePala(activation: .doubleTap)`.
- The activation gesture uses `cancelsTouchesInView`, so entering the mode no longer
  triggers the button/control you pressed.

## [2.0.1] — 2026-07-22

### Added
- **CALayer hit-testing** — SwiftUI-drawn images/shapes that are neither separate
  views nor accessibility elements are now captured from the layer tree, so a
  double-tap can isolate a drawn image's frame instead of only its container.

### Fixed
- The layer stepper no longer truncates the `i/n` counter to `…`; the title
  shortens instead.

## [2.0.0] — 2026-07-22

### Changed
- **Renamed the library/module from `UIDebugInspector` to `Pala`** (breaking).
  Update your import to `import Pala`. The API is now `Pala.enable()` /
  `Pala.disable()`, and the SwiftUI modifiers are `.enablePala()` and
  `.palaInspect(...)`.

## [1.0.2] — 2026-07-22

### Fixed
- **Accessibility traversal** now also uses the method-based container API
  (`accessibilityElementCount()` / `accessibilityElement(at:)`), not just the
  `accessibilityElements` array. Real-app SwiftUI screens expose their a11y
  children through the method API, so tapping now reports the actual element
  instead of falling back to the generic hosting view.

## [1.0.1] — 2026-07-22

### Added
- **Automatic accessibility inspection** — even **un-annotated** SwiftUI elements
  (Text / Button / Image) are now identified on tap and drawn in inspect-all, using
  the accessibility tree (frame + label + role), no annotation required. Shown with
  an **A11y** badge.

### Notes
- Exact **font/color** for pure-SwiftUI elements still require `.palaInspect(...)`;
  frame, label and role are detected automatically.

## [1.0.0] — 2026-07-22

First public release.

### Added
- **Double-tap inspector** — double-tap any element to see its **frame, size,
  center, font (family · name · size · weight), text color, background, padding,
  corner radius, border, shadow** and more in a translucent card.
- **Inspect-all mode** — two-finger tap outlines **every** element on screen with a
  colored rectangle and writes its properties **inline right next to it**, all at
  once (no card, no modal).
- **Layer navigator** — a `◀ i/n ▶` stepper walks the full stack of views under
  your finger (deepest → ancestors) instead of being stuck on one view.
- **SwiftUI `.palaInspect(...)`** modifier for precise font / color / padding
  metadata on pure-SwiftUI elements (which UIKit hit-testing can't read).
- **Configurable activation** — `.doubleTap` (default) or `.longPress(duration:)`.
- Colorful per-element accents, highlight frame + size badge, haptic feedback.
- Zero third-party dependencies; iOS 13+; compiles only where UIKit is available.
- Example app + UI tests exercising every mode on the simulator.

[4.0.7]: https://github.com/ekucet/Pala/releases/tag/v4.0.7
[4.0.6]: https://github.com/ekucet/Pala/releases/tag/v4.0.6
[4.0.5]: https://github.com/ekucet/Pala/releases/tag/v4.0.5
[4.0.4]: https://github.com/ekucet/Pala/releases/tag/v4.0.4
[4.0.3]: https://github.com/ekucet/Pala/releases/tag/v4.0.3
[4.0.2]: https://github.com/ekucet/Pala/releases/tag/v4.0.2
[4.0.1]: https://github.com/ekucet/Pala/releases/tag/v4.0.1
[4.0.0]: https://github.com/ekucet/Pala/releases/tag/v4.0.0
[3.0.1]: https://github.com/ekucet/Pala/releases/tag/v3.0.1
[3.0.0]: https://github.com/ekucet/Pala/releases/tag/v3.0.0
[2.1.0]: https://github.com/ekucet/Pala/releases/tag/v2.1.0
[2.0.1]: https://github.com/ekucet/Pala/releases/tag/v2.0.1
[2.0.0]: https://github.com/ekucet/Pala/releases/tag/v2.0.0
[1.0.2]: https://github.com/ekucet/Pala/releases/tag/v1.0.2
[1.0.1]: https://github.com/ekucet/Pala/releases/tag/v1.0.1
[1.0.0]: https://github.com/ekucet/Pala/releases/tag/v1.0.0
