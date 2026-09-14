import AVFoundation
import SwiftUI

/// The Info page: what the app does, what it does not do, and what it builds on.
/// Opens as a sheet from the i in the logo header.
///
/// The sketch put Om fróði, Personvern and Versjonsinfo in a menu on a start
/// screen. That start screen no longer exists, so the content lives here. A sheet,
/// not a new page, because you should return to the list where you left it.
///
/// The sheet was called «Innstillinger» until 10 September 2026, and that was the
/// wrong name: nothing here is set. The one paragraph that does anything sends you
/// to Settings in iOS; the app has no options of its own. The title now says what
/// the page is.
struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var microphone = AVAudioApplication.shared.recordPermission
    @State private var words = WordList.load()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Frodi.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.s4) {
                        about
                        privacy
                        speechModel
                        wordList
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
                    // A cross, not «Ferdig»: there is nothing to confirm here, the sheet just
                    // closes. The icon also carries no type, so the question of Inter beside the
                    // system title goes away. VoiceOver needs the name the button does not write.
                    Button { dismiss() } label: { IconView(.close, size: IconSize.toolbar) }
                        .accessibilityLabel("Lukk")
                }
            }
        }
        // If you go to Settings to grant microphone access, the card should say the
        // right thing when you come back.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { microphone = AVAudioApplication.shared.recordPermission }
        }
    }

    // MARK: - Cards
    private var about: some View {
        card("Fróði røst") {
            paragraph("Fróði er norrønt og betyr «den kunnskapsrike».")
            paragraph("Fróði tar opp lyd og gjør den om til norsk tekst. Alt skjer på enheten.")
            paragraph("Trykk på opptaksknappen nederst, eller hold inne handlingsknappen på venstre side. Hold inne én gang for å starte, én gang til for å stoppe.")
            paragraph("Før du kan bruke handlingsknappen, må du sette den opp: Gå til Innstillinger > Handlingsknapp, sveip til Snarvei, trykk på «Velg en snarvei» og velg «Start eller stopp opptak» under Fróði røst.")
            paragraph("Et opptak kan vare så lenge du vil. Er det under \(Transcription.immediateMinutes) minutter, lager Fróði teksten med en gang. Er det lengre, lager Fróði teksten når du ber om det. Det tar en stund: la appen være åpen, eller sett enheten til lading, så fortsetter Fróði mens den lader.")
        }
    }

    /// The first sentence of the Personvern card, and the first sentence of
    /// PERSONVERN.md. A test keeps them the same sentence.
    static let privacyOpener = "Alt skjer på enheten. Ingen datatrafikk ut eller inn."

    private var privacy: some View {
        card("Personvern") {
            paragraph(Self.privacyOpener)
            microphoneAccess
            paragraph("Opptak og tekst krypteres med en nøkkel som lages i enheten (Secure Enclave). Ingen annen enhet kan lese dem, og de følger ikke med i en sikkerhetskopi.")
            paragraph("Stopper du et opptak mens enheten er låst, krypterer Fróði det så snart du låser opp. Teksten skjules når skjermen tas opp og når du bytter app.")
            paragraph("Skal du bytte enhet, må du hente ut opptakene først. Sletter du appen, forsvinner alt med én gang.")
            link("Mer om personvern", to: Self.privacyPolicy)
            link("Mer om sikkerhet", to: Self.securityPolicy)
        }
    }

    /// The microphone is the only permission the app asks for, so it belongs under
    /// Personvern. Re-read every time the app becomes active.
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

    /// The app's one setting. Names the model should spell right: the field is
    /// where a user types them once, and every transcription reads them.
    private var wordList: some View {
        card("Ordliste") {
            paragraph("Navn og ord Fróði bør kjenne: firmaer, personer, forkortelser. Skriv dem slik du vil ha dem i teksten, med komma mellom. Fróði retter ord i teksten som nesten stemmer. Har du et opptak fra før, kan du holde på det i listen og velge «Lag teksten på nytt». Listen blir på enheten, kryptert som teksten.")

            TextField("Nordkvist AS, HMS, Kari Berg", text: $words, axis: .vertical)
                .lineLimit(2...8)
                .font(.Frodi.body)
                .foregroundStyle(Color.Frodi.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(Space.s3)
                .background(Color.Frodi.background, in: RoundedRectangle(cornerRadius: Radius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control)
                        .strokeBorder(Color.Frodi.border, lineWidth: 1)
                )
                .accessibilityLabel("Ordliste")
                .onChange(of: words) { _, text in WordList.save(text) }
                .hiddenWhileScreenCaptured()
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

    // The links open in Safari. The app fetches nothing itself; it is the browser
    // that goes online, and only when you tap.
    private static let privacyPolicy = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/PERSONVERN.md")!
    private static let securityPolicy = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/SECURITY.md")!

    private static var versionNumber: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(marketing) (\(build))"
    }

    // MARK: - Building blocks
    /// The settings card from the design system: eyebrow label in capitals over
    /// body text in caption, on surface with a 1 px border.
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

    /// A link out of the app, at the same size as the body text. Underlined and in
    /// text-primary, so it differs from the text around it by more than colour.
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

/// The attribution Apache 2.0 requires, in the app and not only in the repo.
///
/// The same names and licences as TREDJEPART.md, which also carries versions
/// and links. `DocumentTests` fails if the two lists, or `Package.resolved`,
/// disagree.
struct LicensesView: View {
    struct Component: Identifiable {
        let name: String
        let origin: String
        let license: String

        var id: String { name }
    }

    static let model = [
        Component(name: "nb-whisper-small", origin: "Nasjonalbiblioteket", license: "Apache 2.0"),
        Component(name: "CoreML-konvertering", origin: "Barrymanalow", license: "Apache 2.0"),
        Component(name: "Tokenizer, whisper-small", origin: "OpenAI", license: "Apache 2.0")
    ]

    static let code = [
        Component(name: "WhisperKit", origin: "Argmax", license: "MIT"),
        Component(name: "swift-transformers", origin: "Hugging Face", license: "Apache 2.0"),
        Component(name: "swift-jinja", origin: "Hugging Face", license: "Apache 2.0"),
        Component(name: "swift-collections", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-argument-parser", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-crypto", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-asn1", origin: "Apple", license: "Apache 2.0"),
        Component(name: "yyjson", origin: "Yao Yuan", license: "MIT")
    ]

    static let icons = [
        Component(name: "Material Symbols", origin: "Google", license: "Apache 2.0")
    ]

    static let fonts = [
        Component(name: "Skranji", origin: "Font Diner", license: "SIL Open Font License 1.1"),
        Component(name: "Inter", origin: "Rasmus Andersson", license: "SIL Open Font License 1.1")
    ]

    static var allComponents: [Component] { model + code + icons + fonts }

    var body: some View {
        ZStack {
            Color.Frodi.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.s4) {
                    group("Modell", Self.model)
                    group("Kode", Self.code)
                    group("Ikoner", Self.icons)
                    group("Fonter", Self.fonts)
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
