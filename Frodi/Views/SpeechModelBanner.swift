import SwiftUI

/// Forteller ærlig hva som mangler før tale til tekst virker, og lar deg fikse det.
struct SpeechModelBanner: View {
    let model: SpeechModel

    @State private var transcriberLocales: [String] = []
    @State private var dictationLocales: [String] = []
    @State private var showDiagnostics = false

    var body: some View {
        switch model.state {
        case .unknown, .ready:
            EmptyView()

        case .needsDownload:
            banner(
                title: "Last ned norsk språkmodell",
                body: "Fróði trenger den norske språkmodellen fra iOS for å lage tekst. Den lastes ned én gang, og etterpå virker alt uten nett.",
                action: "Last ned"
            )

        case .downloading:
            HStack(spacing: Space.s3) {
                ProgressView()
                Text("Laster ned språkmodellen …")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.s4)
            .background(card)

        case .unsupported:
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("Norsk tale til tekst mangler")
                    .font(.Frodi.bodyMedium)
                    .foregroundStyle(Color.Frodi.textPrimary)

                Text("iOS har ingen norsk språkmodell for tale til tekst på denne enheten. Opptakene dine lagres som vanlig, men uten tekst.")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(showDiagnostics ? "Skjul detaljer" : "Vis hvilke språk som finnes") {
                    showDiagnostics.toggle()
                }
                .font(.Frodi.meta)
                .foregroundStyle(Color.Frodi.textSecondary)

                if showDiagnostics {
                    VStack(alignment: .leading, spacing: Space.s2) {
                        localeList("Transkribering", transcriberLocales)
                        localeList("Diktat", dictationLocales)
                    }
                    .padding(.top, Space.s1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.s4)
            .background(card)
            .task {
                let result = await model.diagnostics()
                transcriberLocales = result.transcriber
                dictationLocales = result.dictation
            }

        case .failed(let message):
            banner(
                title: "Nedlastingen stoppet",
                body: message,
                action: "Prøv igjen"
            )
        }
    }

    private func banner(title: String, body: String, action: String?) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(title)
                .font(.Frodi.bodyMedium)
                .foregroundStyle(Color.Frodi.textPrimary)

            Text(body)
                .font(.Frodi.caption)
                .foregroundStyle(Color.Frodi.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let action {
                Button(action) {
                    Task { await model.download() }
                }
                .font(.Frodi.bodyMedium)
                .foregroundStyle(Color.Frodi.accentRecordOn)
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s2)
                .background(Color.Frodi.accentRecord, in: Capsule())
                .padding(.top, Space.s1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(card)
    }

    private func localeList(_ title: String, _ locales: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.Frodi.eyebrow)
                .eyebrowTracking()
                .foregroundStyle(Color.Frodi.textSecondary)

            Text(locales.isEmpty ? "ingen" : locales.joined(separator: ", "))
                .font(.Frodi.meta)
                .foregroundStyle(Color.Frodi.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: Radius.card)
            .fill(Color.Frodi.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(Color.Frodi.border, lineWidth: 1)
            )
    }
}
