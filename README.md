# Fróði røst

Tar opp lyd på iPhone, gjør den om til tekst (transkriberer), på norsk. Alt på enheten.

«Fróði»: Norrønt for «den kunnskapsrike». «Røst»: Stemme, viser til opptaksfunksjonen.

## Status

Foreløpig i TestFlight, ikke App Store ennå. Bare tilgjengelig i Norge.

## Hva appen gjør

- Tar opp lyd – også når skjermen er låst
- Handlingsknappen starter og stopper opptak
- Ingen tidsgrense på opptak
- Korte opptak transkriberes i sanntid. Opptak over ti minutter transkriberes på forespørsel, fortsetter der det slapp ved avbrudd
- Transkriberer til bokmål, med tegnsetting og stor/liten forbokstav
- Transkripsjonen deles i avsnitt med tidspunkt du kan klikke på for å finne tilbake i lydopptaket og spille av derfra
- Lar deg eksportere lydopptak som `.m4a`, transkripsjon som `.txt` eller `.rtf`

## Modell

**nb-whisper-small** fra Nasjonalbiblioteket: Tale til tekst. Bygger på OpenAIs Whisper, videretrent på 66 000 timer norsk tale fra Språkbanken og Nasjonalbibliotekets egen samling. Setter tegn og stor forbokstav selv, skriver om dialekt til bokmål.

Modellen følger med appen og kjører på enheten. Gratis i bruk, ingen kobling til eksterne tjenester.

| Kilde | Lenke |
|---|---|
| Modellen | [NbAiLab/nb-whisper-small](https://huggingface.co/NbAiLab/nb-whisper-small) |
| CoreML-versjonen appen bruker | [Barrymanalow/nb-whisper-coreml](https://huggingface.co/Barrymanalow/nb-whisper-coreml) |
| Alle modellene fra NB | [huggingface.co/NbAiLab](https://huggingface.co/NbAiLab) |
| Om AI-laben | [ai.nb.no](https://ai.nb.no/) |

## Krav

For bruk:

- iPhone med iOS 26.5 eller nyere
- Handlingsknappen krever iPhone 15 Pro eller nyere

For bygging:

- Xcode 26.6 med iOS 26.5 SDK
- xcodegen: `brew install xcodegen`
- Ca. 500 MB ledig plass til modellen

## Bygg

```bash
brew install xcodegen
./Scripts/fetch-model.sh   # ca. 467 MB, kjør én gang
xcodegen generate
open Frodi.xcodeproj
```

Fra terminalen, mot appens egen simulator (se Test):

```bash
xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' build
```

nb-whisper-small ligger ikke i git-repoet. Uten modellen: Fallback til iOS' innebygde diktering (systemets talegjenkjenning, via Apples `SFSpeechRecognizer`/`SpeechAnalyzer`), svakere på norsk. Info-siden i appen viser hvilken modell som kjører.

`fetch-model.sh` henter modellen fra en fast versjon, sjekker hver fil mot `Scripts/model-checksums.txt`. Feil sum: Skriptet stopper. WhisperKit låst til én versjon i `project.yml`. `Package.resolved` ligger i git, samme pakker ved nytt utsjekk.

Xcodegen genererer prosjektfilen fra `project.yml`. Aldri rediger `.xcodeproj` direkte.

## Test

Appen har egen simulator. Delt simulator mellom sesjoner: UI-testene feiler med `Application failed preflight checks`. Samme feil skjer hvis xcodebuild starter simulatoren selv og åpner appen før iOS er ferdig med å starte. Start simulatoren først, vent til den er klar.

```bash
xcrun simctl create "Frodi-Test" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcrun simctl boot Frodi-Test
xcrun simctl bootstatus Frodi-Test -b
xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' test
```

Uten modellen: Hopper over testene i «Modell i pakken». Resten kjører.

## Arkitektur

Et opptak går gjennom disse stegene. Filene ligger under `Frodi/`.

| Steg                                                                                                                                                                                                    | Fil                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Handlingsknappen trigger intenten (App Intent), som kjører i bakgrunnen når iOS tillater det                                                                                                          | `Intents/ToggleRecordingIntent.swift`                                                              |
| Kontrolleren tar imot kall fra intenten og opptaksknappen, og «eier» databasen                                                                                                                         | `Services/RecordingController.swift`                                                               |
| Opptakeren skriver lyden fortløpende til fil som PCM (Pulse-Code Modulation), i stedet for å holde den i minnet til opptaket stoppes. Et krasj vil derfor ikke føre til at opptaket går tapt.           | `Services/AudioRecorder.swift`                                                                     |
| Ved oppstart sammenligner kontrolleren databaselisten med filmappen. En fil uten tilhørende rad, får en ny rad                                                                                          | `Services/RecordingController.swift`                                                               |
| Lagringen holder filen i appens sandkasse (App Sandbox) med filvern (Data Protection), utenom sikkerhetskopiering                                                                                       | `Services/AudioStorage.swift`                                                                      |
| Vault forsegler opptaket med en nøkkel fra Secure Enclave                                                                                                                                               | `Services/RecordingVault.swift`                                                                    |
| Transkripsjonen lager teksten i puljer, med nb-whisper i appen som hovedmotor og iOS' egen diktatmodell (`DictationTranscriber` i `SpeechAnalyzer`) som reserve. Fremdriften lagres etter hver pulje | `Services/Transcription.swift`, `Services/WhisperTranscriber.swift`, `Services/SpeechEngine.swift` |
| Transcript strukturerer teksten som avsnitt med tidspunkt                                                                                                                                               | `Services/Transcript.swift`                                                                        |
| WordList sender ordlisten til modellen som prompt                                                                                                                                                       | `Services/WordList.swift`                                                                          |
| Når iPhone lader, kjører BackgroundTranscription transkriberingen som bakgrunnsoppgave (Background Task)                                                                                                | `Services/BackgroundTranscription.swift`                                                           |
| Vault forsegler teksten på samme måte som lyden                                                                                                                                                         | `Services/RecordingVault.swift`                                                                    |
| RecordingDetailView viser teksten bak et vern (CaptureGuard) som skjuler den ved skjermopptak (Screen Recording) og appbytte (App Switcher)                                                             | `Views/RecordingDetailView.swift`, `Views/CaptureGuard.swift`                                      |
| Ved eksport dekrypterer RecordingExport filene til en midlertidig mappe, og gir dem til delingsarket (Activity View, ofte kalt Share Sheet)                                                             | `Services/RecordingExport.swift`, `Views/ShareSheet.swift`                                         |

Visningene når aldri talemotoren direkte. Alt går via protokollen `Transcriber`. `Transcription.usesBundledModel` avgjør hvilken motor som kjører.

## Lisens

Kode: MIT, se [LICENSE](LICENSE). Modell, pakker, ikoner, fonter: Egne lisenser, se [TREDJEPART.md](TREDJEPART.md).

## Bidrag

Appen er et personlig prosjekt. Feil og forslag meldes som issues på GitHub. Pull request: Les [CONTRIBUTING.md](CONTRIBUTING.md) først.

## Mer

| Dokument | Innhold |
|---|---|
| [PERSONVERN.md](PERSONVERN.md) | Hva som lagres, tillatelser, rettighetene dine, hvem som står bak |
| [SECURITY.md](SECURITY.md) | Hva som beskyttes mot hva, og hvordan melde sårbarhet |
| [TILGJENGELIGHET.md](TILGJENGELIGHET.md) | Kontrast, Dynamic Type, VoiceOver, og hva som er målt |
| [TREDJEPART.md](TREDJEPART.md) | Modell, kode, ikoner og fonter, med versjoner og lisenser |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Navn, språk, designsystem og reglene for endringer |
| [CHANGELOG.md](CHANGELOG.md) | Hva som er endret, build for build |
