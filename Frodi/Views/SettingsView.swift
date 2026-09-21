import SwiftUI

/// Innstillinger: the two things you can set, what the app is, and the
/// documents. Opens as a sheet from the settings button in the logo header. A
/// sheet, not a new page, because you should return to the list where you
/// left it.
///
/// Settings first, since they are what the title promises. Then the card that
/// says what the app is, with the version and the address, and last the
/// documents: how to use the app, privacy, security, accessibility and the
/// licences. The prose lives in the documents; the page links to them rather
/// than repeating them.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var words = WordList.load()
    /// The height of the word list field, in points. Kept between sessions so
    /// a field once dragged tall stays tall.
    @AppStorage(WordList.heightKey) private var fieldHeight = Double(WordListField.minHeight)
    /// The height when the finger landed on the grip; the drag adds to it.
    @State private var heightAtDragStart: Double?
    /// The same key `RecordingExport.TextFormat.chosen` reads.
    @AppStorage(RecordingExport.TextFormat.key) private var textFormat = RecordingExport.TextFormat.rtf

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Frodi.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.s4) {
                        wordList
                        export
                        about
                        documents
                    }
                    .padding(Space.s4)
                }
            }
            .navigationTitle("Innstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.Frodi.background, for: .navigationBar)
            .toolbar {
                // A cross, not «Ferdig»: there is nothing to confirm here, the sheet just
                // closes. The icon also carries no type, so the question of Inter beside the
                // system title goes away. VoiceOver needs the name the button does not write.
                ToolbarButton(icon: .close, label: "Lukk", placement: .topBarTrailing) { dismiss() }
            }
        }
    }

    // MARK: - Cards
    /// The first sentence about privacy here, and the first sentence of
    /// PERSONVERN.md. A test keeps them the same sentence.
    static let privacyOpener = "Alt skjer på enheten. Ingen datatrafikk ut eller inn."

    /// What the app is, what it runs on, which build this is, and where to write.
    private var about: some View {
        Card("Fróði røst") {
            paragraph("Fróði er norrønt og betyr «den kunnskapsrike».")
            paragraph("Appen tar opp lyd og gjør den om til norsk tekst. " + Self.privacyOpener)
            paragraph("Modellen nb-whisper-small fra Nasjonalbiblioteket er innebygd i appen og kjører på enheten.")
            paragraph("Versjon \(Self.versionNumber)")
            paragraph("Spørsmål eller feil: hei@tazk.no")
        }
    }

    /// One document per reader: the user, the privacy-minded, the security
    /// reviewer, and the licence holders. The three links open on GitHub in
    /// Safari; the licences are a screen in the app, since Apache 2.0 requires
    /// the attribution to be in the app itself.
    private var documents: some View {
        Card("Mer om appen") {
            link("Brukerveiledning", to: Self.userGuide)
            link("Personvernerklæring", to: Self.privacyPolicy)
            link("Sikkerhet", to: Self.securityPolicy)
            licenses
        }
    }

    /// Names the model should spell right: the field is where a user types
    /// them once, and every transcription reads them.
    ///
    /// A `TextEditor` with a fixed height, not a text field that grows with its
    /// content: the height is the user's to set, by the grip in the lower right
    /// corner, and the text scrolls inside it. The cards below follow the
    /// field's height through the layout, so nothing overlaps as it grows.
    private var wordList: some View {
        Card("Ordliste") {
            paragraph("Skriv inn navn og ord modellen kan bomme på. Skill dem med komma.")

            TextEditor(text: $words)
                .font(.Frodi.body)
                .foregroundStyle(Color.Frodi.textPrimary)
                .scrollContentBackground(.hidden)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Ordliste")
                .padding(Space.s2)
                .frame(height: fieldHeight)
                .background(Color.Frodi.background, in: RoundedRectangle(cornerRadius: Radius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control)
                        .strokeBorder(Color.Frodi.border, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) { placeholder }
                .overlay(alignment: .bottomTrailing) { grip }
                .onChange(of: words) { _, text in WordList.save(text) }
                .hiddenWhileScreenCaptured()
        }
    }

    /// `TextEditor` has no placeholder of its own. This one sits where the
    /// first line of text will, and lets touches through to the editor.
    @ViewBuilder
    private var placeholder: some View {
        if words.isEmpty {
            Text("Aall & Ulefos Brug, ISO 19011")
                .font(.Frodi.body)
                .foregroundStyle(Color.Frodi.textSecondary)
                .padding(WordListField.textInset)
                .padding(Space.s2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The lower right corner of the field. Drag it to make the field taller or
    /// shorter; under VoiceOver it is adjustable, one touch target per step.
    /// High priority, or the scroll view takes the vertical drag for itself.
    /// Measured in global space: the grip moves down with every point the
    /// field grows, so in its own space the finger would seem to move back
    /// and the field would shrink again, frame after frame.
    private var grip: some View {
        IconView(.resize, size: WordListField.grip)
            .foregroundStyle(Color.Frodi.textSecondary)
            .padding(Space.s2)
            .frame(width: WordListField.gripTouch, height: WordListField.gripTouch, alignment: .bottomTrailing)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { drag in
                        let start = heightAtDragStart ?? fieldHeight
                        heightAtDragStart = start
                        fieldHeight = Self.clampedHeight(start + drag.translation.height)
                    }
                    .onEnded { _ in heightAtDragStart = nil }
            )
            .accessibilityLabel("Høyde på feltet")
            .accessibilityValue("\(Int(fieldHeight)) punkt")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: fieldHeight = Self.clampedHeight(fieldHeight + WordListField.step)
                case .decrement: fieldHeight = Self.clampedHeight(fieldHeight - WordListField.step)
                @unknown default: break
                }
            }
    }

    private static func clampedHeight(_ height: Double) -> Double {
        min(max(height, WordListField.minHeight), WordListField.maxHeight)
    }

    /// The one choice the export offers in advance. What to hand over, audio or
    /// text or both, is asked where the export is made; the shape of the text
    /// is decided here, once, because it is the same every time.
    private var export: some View {
        Card("Eksport") {
            paragraph("Lyden eksporteres alltid som .m4a. Velg format for teksten.")

            HStack(spacing: Space.s2) {
                ForEach(RecordingExport.TextFormat.allCases, id: \.self) { format in
                    formatChoice(format)
                }
            }
        }
    }

    /// A pill that is filled when chosen and outlined when not. The fill is
    /// the signal for sighted readers; VoiceOver hears «valgt».
    private func formatChoice(_ format: RecordingExport.TextFormat) -> some View {
        let chosen = textFormat == format
        return Button {
            textFormat = format
        } label: {
            Text(verbatim: format.label)
                .font(.Frodi.bodyMedium)
                .foregroundStyle(chosen ? Color.Frodi.accentRecordOn : Color.Frodi.textPrimary)
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s2)
                .background(chosen ? Color.Frodi.accentRecord : Color.Frodi.background, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.Frodi.border, lineWidth: chosen ? 0 : 1))
                .frame(minHeight: ChoiceRow.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tekst som \(format.label)")
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    /// A row, not a link: the licences are inside the app. The chevron says so.
    private var licenses: some View {
        NavigationLink {
            LicensesView()
        } label: {
            HStack(spacing: Space.s2) {
                Text("Lisenser")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textPrimary)
                Spacer()
                IconView(.chevronRight, size: IconSize.inline)
                    .foregroundStyle(Color.Frodi.textSecondary)
            }
            .frame(minHeight: ChoiceRow.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lisenser")
        .accessibilityHint("Åpner listen over modell, kode, ikoner og fonter")
    }

    // The links open in Safari. The app fetches nothing itself; it is the browser
    // that goes online, and only when you tap.
    private static let userGuide = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/BRUKERVEILEDNING.md")!
    private static let privacyPolicy = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/PERSONVERN.md")!
    private static let securityPolicy = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/SECURITY.md")!

    private static var versionNumber: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(marketing) (\(build))"
    }

    // MARK: - Building blocks
    /// Running text in a card. `textPrimary`, not `textSecondary`: this is what
    /// the page is for. The card label above it is the secondary tone.
    private func paragraph(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.Frodi.caption)
            .foregroundStyle(Color.Frodi.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A link out of the app, at the same size and in the same tone as the text
    /// around it. The mark is `open_in_new` after the word, small and in the
    /// secondary tone: it says the document opens outside the app, which the
    /// chevron on the row below does not, and it is a mark that is not colour.
    /// The icon is hidden from VoiceOver; the link trait already says «lenke».
    private func link(_ title: String, to url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: Space.s1) {
                Text(verbatim: title)
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textPrimary)
                IconView(.external, size: IconSize.external)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// The packages Xcode resolves, by their identity in `Package.resolved`.
    static let code = [
        Component(name: "argmax-oss-swift", origin: "Argmax", license: "MIT"),
        Component(name: "swift-argument-parser", origin: "Apple", license: "Apache 2.0")
    ]

    /// Source that ships inside argmax-oss-swift rather than as a package of its
    /// own. Apache 2.0 asks for attribution whichever way the code arrives.
    static let embedded = [
        Component(name: "swift-transformers", origin: "Hugging Face", license: "Apache 2.0")
    ]

    static let icons = [
        Component(name: "Material Symbols", origin: "Google", license: "Apache 2.0")
    ]

    static let fonts = [
        Component(name: "Skranji", origin: "Font Diner", license: "SIL Open Font License 1.1"),
        Component(name: "Inter", origin: "Rasmus Andersson", license: "SIL Open Font License 1.1")
    ]

    static var allComponents: [Component] { model + code + embedded + icons + fonts }

    var body: some View {
        ZStack {
            Color.Frodi.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.s4) {
                    group("Modell", Self.model)
                    group("Kode", Self.code + Self.embedded)
                    group("Ikoner", Self.icons)
                    group("Fonter", Self.fonts)
                }
                .padding(Space.s4)
            }
        }
        .navigationTitle("Lisenser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.Frodi.background, for: .navigationBar)
        .frodiBackButton()
    }

    private func group(_ label: String, _ components: [Component]) -> some View {
        Card(label) {
            ForEach(components) { component in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: component.name)
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
    }
}

/// The settings card from the design system: eyebrow label in capitals over
/// its content, on surface with a 1 px border. Innstillinger and Lisenser are
/// both built of it.
private struct Card<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(verbatim: label)
                .font(.Frodi.eyebrow)
                .eyebrowTracking()
                .textCase(.uppercase)
                .foregroundStyle(Color.Frodi.textSecondary)
                .accessibilityAddTraits(.isHeader)

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
}
