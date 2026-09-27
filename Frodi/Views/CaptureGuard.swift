import SwiftUI

/// Hides content while the screen is being recorded or mirrored.
///
/// iOS offers no way to prevent a screenshot. `userDidTakeScreenshot` arrives
/// only after the picture is taken, and the trick with a hidden
/// `isSecureTextEntry` field is undocumented and can stop working without
/// notice. So we do not pretend to stop screenshots.
///
/// Screen recording and mirroring are different: `isCaptured` is a supported
/// API, and it lasts over time. While it is on, a recording running in the
/// background can capture the text without you thinking about it. So we hide
/// it instead.
///
/// The app switcher is the third case. When the app leaves the foreground, iOS
/// photographs the screen for the switcher and keeps the picture in the app's
/// container, where nothing of ours encrypts it. So the text is also hidden
/// whenever the scene is not active, which is before that picture is taken.
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

    /// The screen the app is actually shown on.
    ///
    /// `UIScreen.main` is deprecated in iOS 26 because an app can be shown on
    /// several screens. So we take the screen from the scene the app is in. If
    /// there is no scene, the app is not visible, and then there is nothing to
    /// hide.
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
