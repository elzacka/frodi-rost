import SwiftUI

/// Skjuler innhold mens skjermen tas opp eller speiles.
///
/// iOS gir ingen måte å hindre et skjermbilde på. `userDidTakeScreenshot`
/// kommer først etter at bildet er tatt, og trikset med et skjult
/// `isSecureTextEntry`-felt er udokumentert og kan slutte å virke uten varsel.
/// Vi later derfor ikke som om vi stopper skjermbilder.
///
/// Skjermopptak og speiling er noe annet: `UIScreen.isCaptured` er et støttet
/// API, og den varer over tid. Er den på, kan et opptak som går i bakgrunnen
/// fange teksten uten at du tenker over det. Da skjuler vi den heller.
struct CaptureGuard: ViewModifier {
    @State private var isCaptured = UIScreen.main.isCaptured

    func body(content: Content) -> some View {
        Group {
            if isCaptured {
                VStack(spacing: Space.s3) {
                    Image(systemName: "eye.slash")
                        .font(.title2)
                        .foregroundStyle(Color.Frodi.textSecondary)

                    Text("Teksten er skjult mens skjermen tas opp.")
                        .font(.Frodi.caption)
                        .foregroundStyle(Color.Frodi.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s6)
            } else {
                content
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIScreen.capturedDidChangeNotification
        )) { _ in
            isCaptured = UIScreen.main.isCaptured
        }
    }
}

extension View {
    /// Skjuler innholdet mens skjermen tas opp eller speiles.
    func hiddenWhileScreenCaptured() -> some View {
        modifier(CaptureGuard())
    }
}
