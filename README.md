# Fróði røst

Tar opp lyd på iPhone og gjør den om til norsk tekst. Alt skjer på enheten.

«Fróði»: Norrønt for «den kunnskapsrike». «røst»: Stemme, fordi appen tar opp tale.

## Status

Versjon 1.0 ligger i [App Store](https://apple.co/4ryiAk4). Appen finnes bare i Norge.

## Hva appen gjør

- Tar opp lyd så lenge du vil, også når skjermen er låst, og starter og
  stopper med handlingsknappen
- Importerer lydfiler, som m4a, mp3 og wav
- Tar vare på opptaket ved en telefonsamtale og hvis appen avsluttes midt i
- Skriver bokmål med tegnsetting og stor forbokstav, også når du snakker dialekt
- Deler teksten i avsnitt med tidspunkt du kan trykke på for å spille av derfra
- Låser opplysningene om hvert opptak og sier fra hvis de er endret utenfor appen
- Eksporterer lyd som `.m4a` og tekst som `.txt` eller `.rtf`

[BRUKERVEILEDNING.md](BRUKERVEILEDNING.md) viser hvordan.

## Modell

[nb-whisper-small](https://huggingface.co/NbAiLab/nb-whisper-small) fra
Nasjonalbiblioteket. Modellen bygger på OpenAIs Whisper og er videretrent på
66 000 timer norsk tale fra Språkbanken og Nasjonalbibliotekets egen samling.
Appen bruker en CoreML-versjon av modellen, laget av Barrymanalow. Modellen
følger med appen og kjører på enheten. Kilder og lisenser: [TREDJEPART.md](TREDJEPART.md).

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

> **Viktig:** nb-whisper-small ligger ikke i git-repoet. Bygget stopper med en
> feilmelding hvis modellen mangler. `fetch-model.sh` henter den og stopper
> hvis en fil ikke stemmer med `Scripts/model-checksums.txt`. Skriptet
> forklarer også hvordan du bytter modellversjon.

På en enhet: Appen har to bundle-ID-er, `com.Tazk.Frodi` og
`com.Tazk.Frodi.Widgets` for widget-utvidelsen. Xcode klargjør begge med
automatisk signering. Fra Terminal trenger `xcodebuild` flagget
`-allowProvisioningUpdates` første gang.

## Test

Appen har sin egen simulator, `Frodi-Test`. Start den og vent til den er klar
før testene. UI-testene feiler med `Application failed preflight checks` hvis
en annen sesjon bruker simulatoren, eller hvis iOS ikke er klar.

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

Uten `-collect-test-diagnostics never` venter xcodebuild ti minutter etter
testene.

### Verktøy og målinger

Disse testene kjører bare når variabelen er satt. `xcodebuild` sender videre
variabler med prefikset `TEST_RUNNER_`, og testen ser dem uten prefikset.

| Test | Variabel | Gjør |
| --- | --- | --- |
| `FrodiTests/PiecewiseTranscriptionTests` | `FRODI_FIXTURE`, og `FRODI_WORDS` for en ordliste | Lager tekst av en lydfil på over tre minutter |
| `FrodiUITests/ScratchPlaybackShot`, `ScratchChoiceShot` | `FRODI_SHOTS=1` | Tar skjermbilder |
| `FrodiUITests/ScratchControlPress` | `FRODI_SHOTS=1` | Trykker på kontrollen i Kontrollsenter. Loggen viser hvilken prosess som kjørte handlingen |
| `FrodiUITests/ScratchKillMidRecording` | `FRODI_KILL=1` | Avslutter appen midt i et opptak og etterlater filen uten rad i databasen |

```bash
# Lydfil til PiecewiseTranscriptionTests
say -v Nora -f tekst.txt -o tekst.aiff
afconvert -f m4af -d aac@16000 -c 1 tekst.aiff tekst.m4a

TEST_RUNNER_FRODI_FIXTURE=/full/sti/tekst.m4a xcodebuild -project Frodi.xcodeproj \
  -scheme Frodi -destination 'platform=iOS Simulator,name=Frodi-Test' \
  -collect-test-diagnostics never \
  -only-testing:FrodiTests/PiecewiseTranscriptionTests test

# Loggen etter ScratchControlPress
xcrun simctl spawn Frodi-Test log show --last 3m \
  --predicate 'subsystem == "com.Tazk.Frodi" OR (process == "chronod" AND eventMessage CONTAINS "control action")'
```

## Arkitektur

Et opptak går gjennom disse stegene. Filene ligger under `Frodi/`, bortsett
fra `FrodiWidgets/`. Hvordan data beskyttes: [SECURITY.md](SECURITY.md).

| Steg | Fil |
| --- | --- |
| Handlingsknappen kjører intenten gjennom appens kontroll. Widget-utvidelsen tegner kontrollen og Live Activity-en | `Intents/ToggleRecordingIntent.swift`, `Services/RecordingActivity.swift`, `FrodiWidgets/` |
| Kontrolleren tar imot intenten og opptaksknappen, har ansvar for databasen og retter listen etter filmappen ved oppstart | `Services/RecordingController.swift` |
| Opptakeren skriver lyden til fil som PCM og fortsetter i en ny fil etter en samtale | `Services/AudioRecorder.swift` |
| Importen gjør om en lydfil til samme format som opptakeren skriver | `Services/AudioImport.swift` |
| Lagringen koder om til AAC, setter filene sammen og forsegler opptaket | `Services/AudioStorage.swift` |
| RecordingVault krypterer med en nøkkel fra Secure Enclave | `Services/RecordingVault.swift` |
| Opprinnelsen beskriver opptaket slik det kom inn, og skrives én gang | `Models/RecordingOrigin.swift`, `Models/Recording.swift` |
| Transcription lager teksten bit for bit og lagrer fremdriften etter hver bit | `Services/Transcription.swift`, `Services/WhisperTranscriber.swift` |
| Transcript deler teksten i avsnitt med tidspunkt | `Services/Transcript.swift` |
| WordList sender ordlisten til modellen som prompt | `Services/WordList.swift` |
| CaptureGuard skjuler teksten ved skjermopptak og appbytte | `Views/RecordingDetailView.swift`, `Views/CaptureGuard.swift` |
| RecordingExport dekrypterer til en midlertidig mappe og gir filene til delingsmenyen | `Services/RecordingExport.swift`, `Views/ShareSheet.swift` |

Visningene når aldri talemotoren direkte. Alt går gjennom protokollen `Transcriber`.

## Lisens

Kode: MIT, se [LICENSE](LICENSE). Modell, pakker, ikoner og fonter har egne
lisenser, se [TREDJEPART.md](TREDJEPART.md).

## Bidrag

Appen er et personlig prosjekt. Meld feil og forslag som issues på GitHub. Les
[CONTRIBUTING.md](CONTRIBUTING.md) før du sender en pull request.

## Mer

| Dokument | Innhold |
| --- | --- |
| [BRUKERVEILEDNING.md](BRUKERVEILEDNING.md) | Slik bruker du appen |
| [PERSONVERN.md](PERSONVERN.md) | Hva som lagres, tillatelser, rettighetene dine, hvem som står bak |
| [SECURITY.md](SECURITY.md) | Hva som beskyttes mot hva, og hvordan du melder en sårbarhet |
| [TILGJENGELIGHET.md](TILGJENGELIGHET.md) | Hva som er gjort for VoiceOver, tekststørrelse og kontrast |
| [TREDJEPART.md](TREDJEPART.md) | Modell, kode, ikoner og fonter, med versjoner og lisenser |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Navn, språk, designsystem og reglene for endringer |
| [CHANGELOG.md](CHANGELOG.md) | Hva som er endret i hver versjon |
