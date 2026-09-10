import SwiftUI

/// Ikonene i appen, hentet fra Heroicons.
///
/// Heroicons er tegnet av Tailwind Labs og er MIT-lisensiert. Filene ligger i
/// asset-katalogen som SVG med vektordata beholdt, så de er skarpe i alle
/// størrelser. `template` gjør at fargen kommer fra `foregroundStyle`, slik at
/// et ikon følger tekstfargene i designsystemet i stedet for å ha sin egen.
///
/// Hvorfor ikke SF Symbols: de er Apples, og appen skal se ut som seg selv.
/// Prisen er at ikonene ikke lenger følger skriftstørrelsen automatisk – men
/// det gjorde de heller ikke før, siden hvert kall alt satte en fast størrelse.
///
/// To utgaver er i bruk. Strek til alt som er ramme og navigasjon, fylt til
/// knappene som ligger på en farget flate, der en strek ville forsvunnet.
/// Det er slik Heroicons selv er ment å brukes.
enum Icon: String, CaseIterable {
    case information = "information-circle"
    case close = "x-mark"
    case chevronRight = "chevron-right"
    case chevronUp = "chevron-up"
    case chevronDown = "chevron-down"
    case hidden = "eye-slash"
    case share = "arrow-up-tray"
    case skipBack = "arrow-uturn-left"
    case skipForward = "arrow-uturn-right"

    case microphone = "microphone-solid"
    case stop = "stop-solid"
    case play = "play-solid"
    case pause = "pause-solid"
}

/// Et ikon i gitt størrelse, farget som teksten rundt.
///
/// Størrelsen oppgis i punkt og kommer fra målene i `Theme`, aldri som et tall
/// på stedet. Ikonet er kvadratisk: Heroicons tegnes i et rutenett på 24 × 24,
/// og en firkantet ramme holder dem på linje med hverandre.
struct IconView: View {
    private let icon: Icon
    private let size: CGFloat

    init(_ icon: Icon, size: CGFloat) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        Image(icon.rawValue)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
