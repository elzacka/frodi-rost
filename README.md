# Fróði røst

Tar opp lyd på iPhone og gjør den om til norsk tekst. Alt skjer på enheten.

«Fróði»: Norrønt for «den kunnskapsrike». «røst»: Stemme, fordi appen tar opp tale.

## Status

Versjon 1.0 ligger i [App Store](https://apple.co/4ryiAk4). Appen finnes bare i Norge.

## Hva appen gjør

- Tar opp lyd så lenge du vil, også når skjermen er låst
- Importerer lydfiler, som m4a, mp3 og wav
- Fortsetter etter en telefonsamtale og tar vare på opptaket hvis appen avsluttes midt i
- Starter og stopper med handlingsknappen, også når enheten er låst
- Lager tekst av opptak på inntil ti minutter når du stopper, og av lengre opptak når du ber om det
- Skriver bokmål med tegnsetting og stor forbokstav, også når du snakker dialekt
- Deler teksten i avsnitt med tidspunkt du kan trykke på for å spille av derfra
- Gir opptakene navnet du velger
- Låser opplysningene om hvert opptak og sier fra hvis de er endret utenfor appen
- Eksporterer lyd som `.m4a` og tekst som `.txt` eller `.rtf`

[BRUKERVEILEDNING.md](BRUKERVEILEDNING.md) viser hvordan.

## Modell

[nb-whisper-small](https://huggingface.co/NbAiLab/nb-whisper-small) fra Nasjonalbiblioteket. Modellen bygger på OpenAIs Whisper og er videretrent på 66 000 timer norsk tale fra Språkbanken og Nasjonalbibliotekets egen samling. Modellen følger med appen og kjører på enheten. Kilder og lisenser: [TREDJEPART.md](TREDJEPART.md).

## Krav

For å bruke appen:

- iPhone med iOS 27.0 eller nyere
- Handlingsknappen krever iPhone 15 Pro eller nyere

For å bygge appen:

- Xcode 27.0 med iOS 27.0 SDK
- xcodegen
- 467 MB ledig plass til modellen

## Bygg

```bash
brew install xcodegen
./Scripts/fetch-model.sh   # kjør én gang
xcodegen generate
open Frodi.xcodeproj
```

Fra Terminal, på appens egen simulator (se Test):

```bash
xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' build
```

På en enhet: Appen har to bundle-ID-er, `com.Tazk.Frodi` og
`com.Tazk.Frodi.Widgets` for widget-utvidelsen. Xcode klargjør begge selv med
automatisk signering. Fra Terminal trenger `xcodebuild` flagget
`-allowProvisioningUpdates` første gang.

> **Viktig:** nb-whisper-small ligger ikke i git-repoet. Modellen er appens eneste talemotor, så bygget stopper med en feilmelding hvis den mangler. `fetch-model.sh` henter den og stopper hvis en fil ikke stemmer med `Scripts/model-checksums.txt`.

Ny modellversjon: Endre `MODEL_REVISION` eller `TOKENIZER_REVISION` i `Scripts/fetch-model.sh`, tøm `Frodi/Resources/Model` og kjør skriptet. Det henter filene og stopper fordi sjekksummene ikke stemmer. Gå gjennom de nye filene og lag sjekksumlisten på nytt:

```bash
(cd Frodi/Resources/Model && find . -type f | sort | xargs shasum -a 256) > Scripts/model-checksums.txt
```

## Test

Appen har sin egen simulator, `Frodi-Test`. Start den først og vent til den er klar.

> **Viktig:** UI-testene feiler med `Application failed preflight checks` hvis flere sesjoner deler simulatoren. Det samme skjer hvis xcodebuild starter simulatoren selv og åpner appen før iOS er klar.

```bash
xcrun simctl create "Frodi-Test" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-27-0
xcrun simctl boot Frodi-Test
xcrun simctl bootstatus Frodi-Test -b
xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' \
  -collect-test-diagnostics never test
```

Flagget `-collect-test-diagnostics never` sparer ti minutter. Uten det venter xcodebuild på en diagnoserapport som aldri kommer, etter at testene er ferdige. Med det tar kjøringen under ett minutt.

### Verktøy og målinger

Disse testene kjører bare når en miljøvariabel er satt. `xcodebuild` sender bare variabler med prefikset `TEST_RUNNER_` videre, og testen ser dem uten prefikset.

Test talemotoren på en lydfil på over tre minutter, med og uten ordliste (`FRODI_WORDS`):

```bash
say -v Nora -f tekst.txt -o tekst.aiff
afconvert -f m4af -d aac@16000 -c 1 tekst.aiff tekst.m4a
TEST_RUNNER_FRODI_FIXTURE=/full/sti/tekst.m4a xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' \
  -only-testing:FrodiTests/PiecewiseTranscriptionTests test
```

`ScratchPlaybackShot` og `ScratchChoiceShot` tar skjermbilder. `ScratchControlPress` trykker på appens kontroll i Kontrollsenter, og loggen viser hvilken prosess som kjørte handlingen. For skjermbildene bytter du ut testnavnet og hopper over `log show`:

```bash
TEST_RUNNER_FRODI_SHOTS=1 xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' \
  -collect-test-diagnostics never \
  -only-testing:FrodiUITests/ScratchControlPress test
xcrun simctl spawn Frodi-Test log show --last 3m \
  --predicate 'subsystem == "com.Tazk.Frodi" OR (process == "chronod" AND eventMessage CONTAINS "control action")'
```

Tvangsavslutt appen midt i et opptak og sjekk om filen som blir igjen, kan åpnes. Testen etterlater med vilje en opptaksfil uten rad i databasen:

```bash
TEST_RUNNER_FRODI_KILL=1 xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' \
  -only-testing:FrodiUITests/ScratchKillMidRecording test
afinfo "$(xcrun simctl get_app_container booted com.Tazk.Frodi data)"/Documents/Opptak/*.caf
```

## Arkitektur

Et opptak går gjennom disse stegene. Filene ligger under `Frodi/`, bortsett fra `FrodiWidgets/`. Hvordan data beskyttes: [SECURITY.md](SECURITY.md).

| Steg                                                                                                                                  | Fil                                                                                        |
| ------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Handlingsknappen kjører intenten gjennom appens kontroll, også på låst enhet. En widget-utvidelse tegner kontrollen og Live Activity-en | `Intents/ToggleRecordingIntent.swift`, `Services/RecordingActivity.swift`, `FrodiWidgets/` |
| Kontrolleren tar imot intenten og trykk på opptaksknappen, har ansvar for databasen og retter listen etter filmappen ved oppstart | `Services/RecordingController.swift`                                                       |
| Opptakeren skriver lyden fortløpende til fil som PCM og fortsetter i en ny fil etter en samtale                                       | `Services/AudioRecorder.swift`                                                             |
| Importen gjør om en lydfil til samme format som opptakeren skriver                                                                    | `Services/AudioImport.swift`                                                               |
| Lagringen koder om til AAC, setter filene sammen og forsegler opptaket                                                                | `Services/AudioStorage.swift`                                                              |
| RecordingVault krypterer lyd, tekst, navn og opprinnelse med en nøkkel fra Secure Enclave                                             | `Services/RecordingVault.swift`                                                            |
| Opprinnelsen er opplysningene om opptaket, skrevet én gang da det kom inn                                                             | `Models/RecordingOrigin.swift`, `Models/Recording.swift`                                   |
| Transcription lager teksten bit for bit med nb-whisper og lagrer fremdriften etter hver bit                                           | `Services/Transcription.swift`, `Services/WhisperTranscriber.swift`                        |
| Transcript deler teksten i avsnitt med tidspunkt                                                                                      | `Services/Transcript.swift`                                                                |
| WordList sender ordlisten til modellen som prompt                                                                                     | `Services/WordList.swift`                                                                  |
| CaptureGuard skjuler teksten ved skjermopptak og appbytte                                                                             | `Views/RecordingDetailView.swift`, `Views/CaptureGuard.swift`                              |
| RecordingExport dekrypterer til en midlertidig mappe og gir filene til delingsmenyen                                                | `Services/RecordingExport.swift`, `Views/ShareSheet.swift`                                 |

Visningene når aldri talemotoren direkte. Alt går gjennom protokollen `Transcriber`.

## Lisens

Kode: MIT, se [LICENSE](LICENSE). Modell, pakker, ikoner, fonter: Egne lisenser, se [TREDJEPART.md](TREDJEPART.md).

## Bidrag

Appen er et personlig prosjekt. Meld feil og forslag som issues på GitHub. Les [CONTRIBUTING.md](CONTRIBUTING.md) før du sender en pull request.

## Mer

| Dokument                                   | Innhold                                                   |
| ------------------------------------------ | --------------------------------------------------------- |
| [BRUKERVEILEDNING.md](BRUKERVEILEDNING.md) | Slik bruker du appen                                      |
| [PERSONVERN.md](PERSONVERN.md)             | Hva som lagres, tillatelser, rettighetene dine, hvem som står bak |
| [SECURITY.md](SECURITY.md)                 | Hva som beskyttes mot hva, og hvordan du melder en sårbarhet |
| [TILGJENGELIGHET.md](TILGJENGELIGHET.md)   | Kontrast, Dynamic Type, VoiceOver og hva som er målt      |
| [TREDJEPART.md](TREDJEPART.md)             | Modell, kode, ikoner og fonter, med versjoner og lisenser |
| [CONTRIBUTING.md](CONTRIBUTING.md)         | Navn, språk, designsystem og reglene for endringer        |
| [CHANGELOG.md](CHANGELOG.md)               | Hva som er endret, build for build                        |

---

[Til toppen](#fróði-røst)
