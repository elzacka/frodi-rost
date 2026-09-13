# Fróði røst

Tar opp lyd på iPhone og gjør den om til norsk tekst. Alt skjer på enheten.

«Fróði» er norrønt for «den kunnskapsrike». «Røst» er stemme.

Fróði er en serie med to apper. Den andre heter [«Fróði vit»](https://github.com/elzacka/frodi-vit)
og er en kunnskapsassistent som svarer på det du spør om.

## Status

Appen er foreløpig kun i TestFlight, ikke App Store. Den vil bare bli tilgjengelig i Norge.

## Hva appen gjør

- Tar opp lyd, også når skjermen er av
- Handlingsknappen starter og stopper opptak
- Skriver teksten på norsk bokmål, med tegnsetting og store bokstaver
- Lar deg hente ut lyd og tekst, som `.m4a`, `.txt` og `.rtf`
- Tar opp så lenge du vil. Et intervju på en time er et vanlig opptak
- Deler teksten i avsnitt med tidspunkt, så du finner stedet i lyden bak en
  setning
- Lager teksten med en gang for korte opptak. Er opptaket over ti minutter,
  lager appen teksten når du ber om den, og fortsetter der den slapp om den
  blir avbrutt

## Modell

**nb-whisper-small** fra Nasjonalbiblioteket (NB) gjør tale om til tekst. Modellen
bygger på OpenAIs Whisper og er videretrent på 66 000 timer norsk tale fra
Språkbanken og NBs egen samling. Derfor setter den tegn og store
bokstaver selv, og skriver dialekt om til bokmål.

Modellen følger med appen og kjører på enheten. Den koster ingenting å
bruke, og appen kontakter ingen tjeneste for å lage teksten.

| Kilde | Lenke |
|---|---|
| Modellen | [NbAiLab/nb-whisper-small](https://huggingface.co/NbAiLab/nb-whisper-small) |
| CoreML-versjonen appen bruker | [Barrymanalow/nb-whisper-coreml](https://huggingface.co/Barrymanalow/nb-whisper-coreml) |
| Alle modellene fra NB | [huggingface.co/NbAiLab](https://huggingface.co/NbAiLab) |
| Om AI-laben | [ai.nb.no](https://ai.nb.no/) |

## Krav

For å bruke appen:

- iPhone med iOS 26.5 eller nyere
- Handlingsknappen krever iPhone 15 Pro eller nyere

For å bygge den:

- Xcode 26.6 med iOS 26.5 SDK
- xcodegen, `brew install xcodegen`
- Rundt 500 MB ledig plass til modellen

## Bygg

```bash
brew install xcodegen
./Scripts/fetch-model.sh   # ca. 467 MB, kjør én gang
xcodegen generate
open Frodi.xcodeproj
```

Fra terminalen, mot appens egen simulator (se under Test):

```bash
xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' build
```

Modellen ligger ikke i git. Uten den faller appen tilbake til iOS' egen
diktatmodell, som er svakere på norsk. Info-siden i appen sier hvilken
modell som kjører.

Skriptet henter modellen fra en fast versjon og sjekker hver fil mot
`Scripts/model-checksums.txt`. Stemmer ikke summene, stopper det. WhisperKit er
låst til én versjon i `project.yml`, og `Package.resolved` ligger i git, så et
nytt utsjekk bygger de samme pakkene.

Xcodegen genererer prosjektfilen fra `project.yml`. Rediger aldri
`.xcodeproj` direkte.

## Test

Appen har sin egen simulator. Deler du en startet simulator med en annen
sesjon, feiler UI-testene med `Application failed preflight checks`. Den samme
feilen kommer hvis xcodebuild starter simulatoren selv og åpner appen før iOS
er ferdig med å starte. Start simulatoren først, og vent til den er klar.

```bash
xcrun simctl create "Frodi-Test" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcrun simctl boot Frodi-Test
xcrun simctl bootstatus Frodi-Test -b
xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' test
```

Uten modellen hopper testene i «Modell i pakken» over. Resten kjører.

## Arkitektur

Ett opptak går gjennom disse stegene. Filene ligger under `Frodi/`.

| Steg | Fil |
|---|---|
| Handlingsknappen kjører intenten, i bakgrunnen når iOS lar den | `Intents/ToggleRecordingIntent.swift` |
| Intenten og opptaksknappen går gjennom én kontroller, som også eier databasen | `Services/RecordingController.swift` |
| Lyden tas opp som PCM, så et krasj ikke tar opptaket med seg | `Services/AudioRecorder.swift` |
| Listen og mappen sjekkes mot hverandre ved oppstart, så en fil uten rad får en rad | `Services/RecordingController.swift` |
| Filen ligger i sandkassen med filvern, utenfor sikkerhetskopien | `Services/AudioStorage.swift` |
| Opptaket forsegles med en nøkkel fra Secure Enclave | `Services/RecordingVault.swift` |
| Teksten lages stykke for stykke, med nb-whisper i appen eller med diktatmodellen i iOS. Fremdriften lagres etter hvert stykke | `Services/Transcription.swift`, `Services/WhisperTranscriber.swift`, `Services/SpeechEngine.swift` |
| Teksten er avsnitt med tidspunkt | `Services/Transcript.swift` |
| Teksten forsegles på samme måte som lyden | `Services/RecordingVault.swift` |
| Teksten vises bak et vern som skjuler den ved skjermopptak og appbytte | `Views/RecordingDetailView.swift`, `Views/CaptureGuard.swift` |
| Hent ut dekrypterer filene til en midlertidig mappe og gir dem til delingsarket | `Services/RecordingExport.swift`, `Views/ShareSheet.swift` |

Visningene når aldri talemotoren direkte. Alt går gjennom protokollen
`Transcriber`, og `Transcription.usesBundledModel` avgjør hvilken motor som
kjører.

## Lisens

Koden er MIT, se [LICENSE](LICENSE). Modellen, pakkene, ikonene og fontene
har egne lisenser, se [TREDJEPART.md](TREDJEPART.md).

## Bidrag

Dette er et personlig prosjekt. Meld feil og forslag som issues på GitHub.
Vil du sende en pull request, les [CONTRIBUTING.md](CONTRIBUTING.md) først.

## Mer

| Dokument | Innhold |
|---|---|
| [PERSONVERN.md](PERSONVERN.md) | Hva som lagres, tillatelser, rettighetene dine, hvem som står bak |
| [SECURITY.md](SECURITY.md) | Hva som beskyttes mot hva, og hvordan melde sårbarhet |
| [TILGJENGELIGHET.md](TILGJENGELIGHET.md) | Kontrast, Dynamic Type, VoiceOver, og hva som er målt |
| [TREDJEPART.md](TREDJEPART.md) | Modell, kode, ikoner og fonter, med versjoner og lisenser |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Navn, språk, designsystem og reglene for endringer |
| [CHANGELOG.md](CHANGELOG.md) | Hva som er endret, build for build |
