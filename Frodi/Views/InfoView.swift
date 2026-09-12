import AVFoundation
import SwiftUI

/// Info-siden: hva appen gjør, hva den ikke gjør, og hva den bygger på. Åpnes som
/// ark fra i-en i logohodet.
///
/// Skissen la Om fróði, Personvern og Versjonsinfo i en meny på en startskjerm.
/// Den startskjermen finnes ikke lenger, så innholdet ligger her. Arket, ikke en
/// ny side, fordi du skal tilbake til listen der du slapp.
///
/// Arket het «Innstillinger» til 10. september 2026, og var feil navn: her
/// stilles ingen ting inn. Det eneste kortet som gjør noe, sender deg til
/// Innstillinger i iOS – appens egne valg finnes ikke, fordi appen ikke har
/// noen. Tittelen sier nå det arket er.
struct InfoView: View {
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
                        speechModel
                        licenses
                        version
                    }
                    .padding(Space.s4)
                }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.Frodi.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Kryss, ikke «Ferdig»: her er det ingenting å bekrefte,
                    // arket bare lukkes. Ikonet har heller ingen skrift, så
                    // spørsmålet om Inter ved siden av systemtittelen faller
                    // bort. VoiceOver trenger navnet knappen ikke skriver.
                    Button { dismiss() } label: { IconView(.close, size: IconSize.toolbar) }
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
        card("Fróði røst") {
            paragraph("Fróði er norrønt og betyr «den kunnskapsrike».")
            paragraph("Fróði tar opp lyd og gjør den om til norsk tekst. Alt skjer på enheten.")
            paragraph("Trykk på opptaksknappen nederst, eller hold inne handlingsknappen på venstre side. Hold inne én gang for å starte, én gang til for å stoppe.")
            paragraph("Før du kan bruke handlingsknappen, må du sette den opp: Gå til Innstillinger > Handlingsknapp, sveip til Snarvei, trykk på «Velg en snarvei» og velg «Start eller stopp opptak» under Fróði røst.")
            paragraph("Et opptak kan vare i inntil \(RecordingLimit.minutes) minutter. Snakker du fort, blir det rundt \(RecordingLimit.formatted(RecordingLimit.words)) ord.")
        }
    }

    private var privacy: some View {
        card("Personvern") {
            paragraph("Alt skjer på enheten. Ingen datatrafikk ut eller inn.")
            microphoneAccess
            paragraph("Opptak og tekst krypteres med en nøkkel som lages i enheten (Secure Enclave). Ingen annen enhet kan lese dem, og de følger ikke med i en sikkerhetskopi.")
            paragraph("Skal du bytte enhet, må du hente ut opptakene først. Sletter du appen, forsvinner alt med én gang.")
            link("Mer om personvern", to: Self.privacyPolicy)
            link("Mer om sikkerhet", to: Self.securityPolicy)
        }
    }

    /// Mikrofonen er den eneste tilgangen appen ber om, så den hører hjemme under
    /// Personvern. Leses på nytt hver gang appen blir aktiv.
    @ViewBuilder
    private var microphoneAccess: some View {
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
                paragraph("Modellen, koden og fontene appen bygger på, med opphav og lisens.")
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lisenser")
        .accessibilityHint("Åpner listen over modell, kode og fonter")
    }

    private var version: some View {
        card("Versjon") {
            paragraph("Fróði røst \(Self.versionNumber)")
            paragraph("Spørsmål eller feil: hei@tazk.no")
        }
    }

    // Lenkene åpner i Safari. Appen henter ingenting selv; det er nettleseren
    // som går på nett, og bare når du trykker.
    private static let privacyPolicy = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/PERSONVERN.md")!
    private static let securityPolicy = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/SECURITY.md")!

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
                    IconView(.chevronRight, size: IconSize.inline)
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

    /// Lenke ut av appen, i samme størrelse som brødteksten. Understreket og i
    /// text-primary, så den skiller seg fra teksten rundt på mer enn farge.
    private func link(_ title: String, to url: URL) -> some View {
        Link(title, destination: url)
            .font(.Frodi.caption)
            .underline()
            .tint(Color.Frodi.textPrimary)
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

    private let icons = [
        Component(name: "Heroicons", origin: "Tailwind Labs", license: "MIT")
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
                    group("Modell", model)
                    group("Kode", code)
                    group("Ikoner", icons)
                    group("Fonter", fonts)
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
