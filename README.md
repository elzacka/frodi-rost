# Fróði røst

Tar opp lyd på iPhone, gjør den om til tekst (transkriberer), på norsk. Alt på enheten.

«Fróði»: Norrønt for «den kunnskapsrike». «Røst»: Stemme, viser til opptaksfunksjonen.

## Status

Foreløpig i TestFlight, ikke App Store ennå. Bare tilgjengelig i Norge.

## Hva appen gjør

- Tar opp lyd – også når skjermen er låst
- Handlingsknappen starter og stopper opptak
- Ingen tidsgrense på opptak
- Opptak under ti minutter transkriberes når du stopper. Lengre opptak transkriberes når du ber om det, og fortsetter der de slapp ved avbrudd
- Transkriberer til bokmål, med tegnsetting og stor/liten forbokstav
- Transkripsjonen deles i avsnitt med tidspunkt du kan trykke på for å spille av derfra
- Lar deg eksportere lydopptak som `.m4a` og transkripsjon som `.txt` eller `.rtf`, hver for seg eller sammen

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

- iPhone med iOS 27.0 eller nyere
- Handlingsknappen krever iPhone 15 Pro eller nyere

For bygging:

- Xcode 27.0 med iOS 27.0 SDK
- xcodegen: `brew install xcodegen`
- 467 MB ledig plass til modellen

## Bygg

```bash
brew install xcodegen
./Scripts/fetch-model.sh   # kjør én gang
xcodegen generate
open Frodi.xcodeproj
```

Fra terminalen, mot appens egen simulator (se Test):

```bash
xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' build
```

nb-whisper-small ligger ikke i git-repoet. Modellen er appens eneste talemotor, så bygget stopper med en feilmelding hvis den mangler.

`fetch-model.sh` sjekker hver fil mot `Scripts/model-checksums.txt` og stopper ved avvik. Hvordan modell og pakker er låst: [SECURITY.md](SECURITY.md).

## Test

Appen har egen simulator. Delt simulator mellom sesjoner: UI-testene feiler med `Application failed preflight checks`. Samme feil skjer hvis xcodebuild starter simulatoren selv og åpner appen før iOS er ferdig med å starte. Start simulatoren først, vent til den er klar.

```bash
xcrun simctl create "Frodi-Test" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-27-0
xcrun simctl boot Frodi-Test
xcrun simctl bootstatus Frodi-Test -b
xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' test
```

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
| Transkripsjonen lager teksten i puljer med nb-whisper, som kjører inne i appen. Fremdriften lagres etter hver pulje | `Services/Transcription.swift`, `Services/WhisperTranscriber.swift`, `Services/SpeechEngine.swift` |
| Transcript strukturerer teksten som avsnitt med tidspunkt                                                                                                                                               | `Services/Transcript.swift`                                                                        |
| WordList sender ordlisten til modellen som prompt                                                                                                                                                       | `Services/WordList.swift`                                                                          |
| Når iPhone lader, kjører BackgroundTranscription transkriberingen som bakgrunnsoppgave (Background Task)                                                                                                | `Services/BackgroundTranscription.swift`                                                           |
| Vault forsegler teksten på samme måte som lyden                                                                                                                                                         | `Services/RecordingVault.swift`                                                                    |
| RecordingDetailView viser teksten bak et vern (CaptureGuard) som skjuler den ved skjermopptak (Screen Recording) og appbytte (App Switcher)                                                             | `Views/RecordingDetailView.swift`, `Views/CaptureGuard.swift`                                      |
| Ved eksport dekrypterer RecordingExport filene til en midlertidig mappe, og gir dem til delingsarket (Activity View, ofte kalt Share Sheet)                                                             | `Services/RecordingExport.swift`, `Views/ShareSheet.swift`                                         |

Visningene når aldri talemotoren direkte. Alt går via protokollen `Transcriber`.

## Lisens

Kode: MIT, se [LICENSE](LICENSE). Modell, pakker, ikoner, fonter: Egne lisenser, se [TREDJEPART.md](TREDJEPART.md).

## Bidrag

Appen er et personlig prosjekt. Feil og forslag meldes som issues på GitHub. Pull request: Les [CONTRIBUTING.md](CONTRIBUTING.md) først.

## Mer

| Dokument | Innhold |
|---|---|
| [BRUKERVEILEDNING.md](BRUKERVEILEDNING.md) | Slik tar du opp, lager tekst, bruker ordlisten, eksporterer og sletter |
| [PERSONVERN.md](PERSONVERN.md) | Hva som lagres, tillatelser, rettighetene dine, hvem som står bak |
| [SECURITY.md](SECURITY.md) | Hva som beskyttes mot hva, og hvordan melde sårbarhet |
| [TILGJENGELIGHET.md](TILGJENGELIGHET.md) | Kontrast, Dynamic Type, VoiceOver, og hva som er målt |
| [TREDJEPART.md](TREDJEPART.md) | Modell, kode, ikoner og fonter, med versjoner og lisenser |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Navn, språk, designsystem og reglene for endringer |
| [CHANGELOG.md](CHANGELOG.md) | Hva som er endret, build for build |
