import SwiftUI

/// Designsystemet i kode. Verdiene her er de eneste som skal brukes —
/// ingen egendefinerte farger, avstander eller radiuser ute i viewene.
///
/// Kilde: dev_only/designsystem/frodi-designsystem-v0.1.html

// MARK: - Farger

extension Color {
    enum Frodi {
        static let background = Color("Background")
        static let surface = Color("Surface")
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let border = Color("BorderNeutral")

        /// Brukes kun til opptaksrelaterte elementer.
        static let accentRecord = Color("AccentRecord")
        /// Tekst og ikoner oppå `accentRecord`. Aldri ren svart eller hvit.
        static let accentRecordOn = Color("AccentRecordOn")
        /// Aktivt opptak pågår.
        static let recordingActive = Color("RecordingActive")

        // accent-knowledge (#2E9C82) er reservert til kunnskapsdelen og
        // finnes derfor ikke her ennå. Legg den inn når den delen bygges.
    }
}

// MARK: - Typografi

extension Font {
    enum Frodi {
        /// Norse Bold. Logo og appnavn. Samme skrift som i app-ikonet.
        static let display = custom("Norse-Bold", size: 30, relativeTo: .largeTitle)
        /// Inter 600. Skjermtitler.
        ///
        /// Norse er en pyntefont med bare majuskler, og blir tynn og tung å lese
        /// i løpende grensesnitt. Den er derfor holdt til logoen, der den hører
        /// hjemme. Titler som «Ingen opptak ennå» må kunne leses raskt, også med
        /// stor tekst og i bil, og WCAG 2.2 AA gjelder.
        static let title = custom("Inter-SemiBold", size: 20, relativeTo: .title2)
        /// Inter 500, sporet. Små etiketter over en seksjon.
        static let eyebrow = custom("Inter-Medium", size: 11, relativeTo: .caption2)
        /// Inter 500. Timeren under opptak. Skal kunne leses på avstand i bil.
        static let timer = custom("Inter-Medium", size: 32, relativeTo: .largeTitle)
        static let body = custom("Inter-Regular", size: 15, relativeTo: .body)
        static let bodyMedium = custom("Inter-Medium", size: 15, relativeTo: .body)
        static let caption = custom("Inter-Regular", size: 13, relativeTo: .footnote)
        static let meta = custom("Inter-Regular", size: 11, relativeTo: .caption2)
    }
}

// MARK: - Avstand

/// 8px-grid. Ingen egendefinerte tall utenfor denne skalaen.
enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 40
}

// MARK: - Hjørneradius

enum Radius {
    static let control: CGFloat = 12
    static let card: CGFloat = 16
    static let pill: CGFloat = 24
}

// MARK: - Opptaksknapp

enum RecordButton {
    static let diameter: CGFloat = 100
    static let inner: CGFloat = 74
    static let ring: CGFloat = 3
}

// MARK: - Sporing

extension Text {
    /// Eyebrow-etiketter er sporet 0.06em i designsystemet.
    func eyebrowTracking() -> some View {
        tracking(11 * 0.06)
    }
}
