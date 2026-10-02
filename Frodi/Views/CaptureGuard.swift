import SwiftUI

/// Hides content while the screen is recorded or mirrored (`isCaptured`), and whenever the scene is not active.
/// Screenshots cannot be stopped: `userDidTakeScreenshot` fires after the picture, the `isSecureTextEntry` trick is undocumented.
/// Inactive: iOS stores the app-switcher picture in the container, unencrypted by us, so hide before it is taken.
struct CaptureGuard: ViewModifier {
    @Environment(\.concealment) private var concealment

    func body(content: Content) -> some View {
        Group {
            if concealment != .none {
                VStack(spacing: Space.s3) {
                    IconView(.hidden, size: IconSize.notice)
                        .foregroundStyle(Color.Frodi.textSecondary)

                    Group {
                        if concealment == .captured {
                            Text("Teksten er skjult mens skjermen tas opp.")
                        } else {
                            Text("Teksten er skjult.")
                        }
                    }
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s6)
            } else {
                content
            }
        }
    }
}

/// Why content is hidden right now, if it is: the screen is recorded or
/// mirrored, or the scene is not active and iOS is about to photograph it for
/// the app switcher. See `CaptureGuard` for the three cases.
enum Concealment {
    case none, captured, inactive
}

extension EnvironmentValues {
    @Entry var concealment: Concealment = .none
}

/// Works out the concealment once, at the root, and hands it down. The text
/// hides behind `CaptureGuard`; a recording's name gives way to its date.
struct ConcealmentReader: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isCaptured = false

    func body(content: Content) -> some View {
        content
            .environment(\.concealment, isCaptured ? .captured : scenePhase != .active ? .inactive : .none)
            .onAppear { isCaptured = Self.screenIsCaptured }
            .onReceive(NotificationCenter.default.publisher(
                for: UIScreen.capturedDidChangeNotification
            )) { _ in
                isCaptured = Self.screenIsCaptured
            }
    }

    /// The screen the app is shown on. `UIScreen.main` is deprecated in iOS 26 (several screens), so take it from the
    /// app's scene; no scene means the app is not visible and there is nothing to hide.
    @MainActor
    private static var screenIsCaptured: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.screen.isCaptured ?? false
    }
}

extension View {
    /// Hides the content while the screen is being recorded or mirrored.
    func hiddenWhileScreenCaptured() -> some View {
        modifier(CaptureGuard())
    }

    /// Hands the app its concealment. Applied once, at the root.
    func readsConcealment() -> some View {
        modifier(ConcealmentReader())
    }
}
