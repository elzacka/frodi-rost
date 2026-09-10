import Foundation

/// Hvor langt et opptak kan være, og hvor mye tekst det blir.
///
/// Grensen finnes fordi minnet setter den. nb-whisper vokser med lengden på
/// opptaket, rundt 60 MB per minutt lyd oppå de 400 MB modellen selv tar. Målt
/// på simulator 9. september 2026 gikk ti minutter gjennom på 1 130 MB, mens
/// femten minutter ble drept. Uten en grense er det ikke opptaket som stopper,
/// men transkripsjonen etterpå – og da er teksten tapt uten at noen sa fra.
///
/// Ti minutter er det lengste som er målt helt gjennom. Tallet står her alene,
/// og alt annet regnes ut fra det: setningen i innstillingene, nedtellingen i
/// opptaksfeltet og stoppen i `AudioRecorder`. Skal grensen endres, er det
/// denne linjen som endres.
///
/// **Taket er ikke målt på enhet.** Nevral motor har en annen minneprofil enn
/// simulatoren, og en enhet med 4 GB har mindre å gå på enn Mac-en. Blir opptak
/// drept på enhet, er det dette tallet som skal ned.
enum RecordingLimit {
    static let duration: TimeInterval = 10 * 60

    static var minutes: Int { Int(duration / 60) }

    /// Ord er enheten appen alt teller i: detaljvisningen sier «114 ord».
    ///
    /// 170 ord i minuttet er målt, ikke antatt – 512 ord på 3 minutter og
    /// 1 683 på 10. Det er fort snakket, og tallet er derfor et tak og ikke et
    /// anslag. Sier du mindre i minuttet, får du mindre tekst.
    static var words: Int { minutes * 170 }

    /// Et norsk ord er i snitt rundt fem tegn, pluss mellomrommet etter.
    static var characters: Int { words * 6 }

    /// Tall skrevet på norsk, med hardt mellomrom som tusenskille.
    ///
    /// Språket er låst til bokmål her av samme grunn som i `AppLocale`: en
    /// enhet satt til engelsk skal fortsatt vise norsk tekst.
    static func formatted(_ number: Int) -> String {
        number.formatted(.number.locale(AppLocale.norwegian))
    }
}
