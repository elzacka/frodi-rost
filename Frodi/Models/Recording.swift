import Foundation
import SwiftData

@Model
final class Recording {
    var createdAt: Date = Date()
    var duration: TimeInterval = 0

    /// Bare filnavnet, aldri hele stien. Sandkassen til appen får ny sti ved
    /// oppdatering og reinstallasjon, så en lagret absolutt sti peker på ingenting
    /// etter neste versjon.
    var fileName: String = ""

    /// Teksten forsegles på samme måte som lyden.
    ///
    /// En transkripsjon er ofte mer eksponerende enn lydfilen. Den er søkbar,
    /// lesbar på et blikk, og kan kopieres uten å spilles av. Å beskytte lyden
    /// og la teksten ligge i klartekst ville vært å låse døren og la vinduet stå.
    var sealedTranscript: Data?

    var transcriptionFailed: Bool = false

    /// Settes ved start og nullstilles ved slutt av `Transcription.run`, som
    /// er det eneste stedet som lagrer mens flagget er sant. Krasjer appen
    /// midt i et forsøk uten at noe annet har lagret i mellomtiden, leser
    /// neste oppstart flagget som `false` fra disk, og `transcribePending()`
    /// tar opptaket på nytt uten at det står fast som «transkriberer».
    var isTranscribing: Bool = false

    /// Hvorfor teksten mangler. Uten denne sier appen «fant ingen tale» også når
    /// årsaken er at språkmodellen ikke finnes, og det er en usann beskjed.
    var failureCode: String?

    init(createdAt: Date = Date(), duration: TimeInterval, fileName: String) {
        self.createdAt = createdAt
        self.duration = duration
        self.fileName = fileName
    }

    var fileURL: URL {
        AudioStorage.directory.appendingPathComponent(fileName)
    }

    var hasTranscript: Bool { sealedTranscript != nil }

    /// Låser opp teksten. Kalles bare når den faktisk skal vises eller hentes ut.
    func transcript() throws -> String? {
        guard let sealedTranscript else { return nil }
        return try RecordingVault.openText(sealedTranscript)
    }

    func setTranscript(_ text: String) throws {
        sealedTranscript = try RecordingVault.seal(text)
    }
}
