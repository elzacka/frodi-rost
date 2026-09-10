import AVFoundation
import SwiftUI

/// Innstillinger og informasjon om appen, åpnet som ark fra tannhjulet i logohodet.
///
/// Skissen la Om fróði, Personvern og Versjonsinfo i en meny på en startskjerm.
/// Den startskjermen finnes ikke lenger, så innholdet ligger her. Arket, ikke en
/// ny side, fordi du skal tilbake til listen der du slapp.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var microphone = AVAudioApplication.shared.recordPermission

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Frodi.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.s4) {
                        about
                        privacy
                        microphoneAccess
                        speechModel
                        licenses
                        version
                    }
                    .padding(Space.s4)
                }
            }
            .navigationTitle("Innstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.Frodi.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Kryss, ikke «Ferdig»: her er det ingenting å bekrefte,
                    // arket bare lukkes. Ikonet har heller ingen skrift, så
                    // spørsmålet om Inter ved siden av systemtittelen faller
                    // bort. VoiceOver trenger navnet knappen ikke skriver.
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Lukk")
                }
            }
        }
        // Går du til Innstillinger for å gi tilgang til mikrofonen, skal kortet
        // si det riktige når du kommer tilbake.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { microphone = AVAudioApplication.shared.recordPermission }
        }
    }

    // MARK: - Kort

    private var about: some View {
        card("Om Fróði røst") {
            paragraph("Fróði tar opp lyd og gjør den om til norsk tekst. Alt skjer på enheten.")
            paragraph("Trykk på mikrofonen nederst i listen, eller bruk handlingsknappen på siden av enheten. Ett trykk starter opptaket, neste stopper det. Opptaket fortsetter selv om skjermen er av.")
            paragraph("Et opptak kan vare i inntil \(RecordingLimit.minutes) minutter. Snakker du fort, blir det rundt \(RecordingLimit.formatted(RecordingLimit.words)) ord, eller omtrent \(RecordingLimit.formatted(RecordingLimit.characters)) tegn.")
            paragraph("Grensen er der fordi språkmodellen bruker mer minne jo lengre opptaket er. Fróði stopper selv når tiden er ute, og feltet nederst teller ned mens du snakker. Du kan ta opp så mange ganger du vil.")
            paragraph("Navnet er norrønt: Fróði betyr «den kunnskapsrike», og røst er stemme.")
        }
    }

    private var privacy: some View {
        card("Personvern") {
            paragraph("Fróði sender ingenting og henter ingenting. Verken lyden eller teksten forlater enheten.")
            paragraph("Opptak og tekst krypteres med en nøkkel som lages i enheten og aldri forlater den. Ingen annen enhet kan lese dem, og de følger ikke med i en sikkerhetskopi.")
            paragraph("Skal du bytte enhet, må du hente ut opptakene først. Sletter du appen, forsvinner alt med én gang.")
        }
    }

    private var microphoneAccess: some View {
        card("Mikrofon") {
            switch microphone {
            case .granted:
                paragraph("Fróði har tilgang til mikrofonen. Det er den eneste tilgangen appen ber om.")
            case .denied:
                paragraph("Fróði har ikke tilgang til mikrofonen og kan ikke ta opp. Du gir tilgang i Innstillinger på enheten.")
                pillButton("Åpne Innstillinger") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            default:
                paragraph("Fróði spør om tilgang til mikrofonen første gang du tar opp. Det er den eneste tilgangen appen ber om.")
            }
        }
    }

    private var speechModel: some View {
        card("Språkmodell") {
            if Transcription.usesBundledModel {
                paragraph("nb-whisper-small fra Nasjonalbiblioteket gjør tale om til tekst. Modellen følger med appen og kjører inne i den.")
                paragraph("Den er trent på 66\u{00A0}000 timer norsk tale. Derfor setter den tegn og store bokstaver selv, og skriver dialekt om til bokmål. Du trenger ikke si «punktum» og «komma».")
            } else {
                paragraph("Modellen fra Nasjonalbiblioteket er ikke med i dette bygget. Fróði bruker diktatmodellen fra iOS i stedet.")
                paragraph("Den kjører også på enheten, men er svakere på norsk: du må si «punktum» og «komma» selv, og dialekt blir ofte feil.")
            }
        }
    }

    private var licenses: some View {
        NavigationLink {
            LicensesView()
        } label: {
            card("Lisenser", opensScreen: true) {
                paragraph("Modellen, koden og skriftene appen bygger på, med opphav og lisens.")
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lisenser")
        .accessibilityHint("Åpner listen over modell, kode og skrifter")
    }

    private var version: some View {
        card("Versjon") {
            paragraph("Fróði røst \(Self.versionNumber)")
            paragraph("Spørsmål eller feil: hei@tazk.no")
        }
    }

    private static var versionNumber: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(marketing) (\(build))"
    }

    // MARK: - Byggeklosser

    /// Innstillingskortet fra designsystemet: eyebrow-etikett i versaler over
    /// brødtekst i caption, på surface med 1px kant.
    @ViewBuilder
    private func card(_ label: String, opensScreen: Bool = false, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack(spacing: Space.s2) {
                Text(label)
                    .font(.Frodi.eyebrow)
                    .eyebrowTracking()
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .accessibilityAddTraits(.isHeader)

                if opensScreen {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.Frodi.caption)
                        .foregroundStyle(Color.Frodi.textSecondary)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(Color.Frodi.surface, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.Frodi.border, lineWidth: 1)
        )
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.Frodi.caption)
            .foregroundStyle(Color.Frodi.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pillButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.Frodi.bodyMedium)
            .foregroundStyle(Color.Frodi.accentRecordOn)
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s2)
            .background(Color.Frodi.accentRecord, in: Capsule())
    }
}

/// Attribusjonen Apache 2.0 krever, i appen og ikke bare i repoet.
///
/// Samme innhold som TREDJEPART.md. Endres den ene, endres den andre.
struct LicensesView: View {
    private struct Component: Identifiable {
        let name: String
        let origin: String
        let license: String

        var id: String { name }
    }

    private let model = [
        Component(name: "nb-whisper-small", origin: "Nasjonalbiblioteket", license: "Apache 2.0"),
        Component(name: "CoreML-konvertering", origin: "Barrymanalow", license: "Apache 2.0"),
        Component(name: "Tokenizer, whisper-small", origin: "OpenAI", license: "Apache 2.0")
    ]

    private let code = [
        Component(name: "WhisperKit", origin: "Argmax", license: "MIT"),
        Component(name: "swift-transformers", origin: "Hugging Face", license: "Apache 2.0"),
        Component(name: "swift-jinja", origin: "Hugging Face", license: "Apache 2.0"),
        Component(name: "swift-collections", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-argument-parser", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-crypto", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-asn1", origin: "Apple", license: "Apache 2.0"),
        Component(name: "yyjson", origin: "Yao Yuan", license: "MIT")
    ]

    private let fonts = [
        Component(name: "Inter", origin: "Rasmus Andersson", license: "SIL Open Font License 1.1"),
        Component(name: "Skranji", origin: "Font Diner", license: "SIL Open Font License 1.1")
    ]

    var body: some View {
        ZStack {
            Color.Frodi.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.s4) {
                    Text("Lisensene under krever at opphavet oppgis. Dette er den attribusjonen.")
                        .font(.Frodi.caption)
                        .foregroundStyle(Color.Frodi.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    group("Modell", model)
                    group("Kode", code)
                    group("Skrifter", fonts)
                }
                .padding(Space.s4)
            }
        }
        .navigationTitle("Lisenser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.Frodi.background, for: .navigationBar)
    }

    private func group(_ label: String, _ components: [Component]) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(label)
                .font(.Frodi.eyebrow)
                .eyebrowTracking()
                .textCase(.uppercase)
                .foregroundStyle(Color.Frodi.textSecondary)
                .accessibilityAddTraits(.isHeader)

            ForEach(components) { component in
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.name)
                        .font(.Frodi.bodyMedium)
                        .foregroundStyle(Color.Frodi.textPrimary)

                    Text("\(component.origin) · \(component.license)")
                        .font(.Frodi.meta)
                        .foregroundStyle(Color.Frodi.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(Color.Frodi.surface, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.Frodi.border, lineWidth: 1)
        )
    }
}
