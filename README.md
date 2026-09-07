# Fróði røst

Tar opp lyd på iPhone og gjør det om til norsk tekst. Alt skjer på enheten.

## Hva appen gjør

- Tar opp lyd, også med skjermen av
- Handlingsknappen starter og stopper opptak
- Skriver ut norsk bokmål, med tegnsetting og store bokstaver
- Lar deg hente ut lyd og tekst

## Modell

Tale til tekst gjøres av **nb-whisper-small** fra Nasjonalbiblioteket. Den bygger
på OpenAIs Whisper, videretrent på 66 000 timer norsk tale fra Språkbanken og
bibliotekets egen samling. Derfor setter den punktum og store bokstaver av seg
selv, og skriver dialekt om til bokmål.

Modellen følger med appen og kjører lokalt. Den koster ingenting å bruke, og
appen kontakter ingen tjeneste for å transkribere.

| Kilde | Lenke |
|---|---|
| Modellen | [NbAiLab/nb-whisper-small](https://huggingface.co/NbAiLab/nb-whisper-small) |
| CoreML-versjonen appen bruker | [Barrymanalow/nb-whisper-coreml](https://huggingface.co/Barrymanalow/nb-whisper-coreml) |
| Alle modellene fra NB | [huggingface.co/NbAiLab](https://huggingface.co/NbAiLab) |
| Om laben | [ai.nb.no](https://ai.nb.no/) |

## Krav

- iPhone med iOS 26.5 eller nyere
- Handlingsknappen krever iPhone 15 Pro eller nyere

## Bygg

```bash
brew install xcodegen
./Scripts/fetch-model.sh   # ca. 487 MB, kjøres én gang
xcodegen generate
open Frodi.xcodeproj
```

Modellen ligger ikke i git. Uten den faller appen tilbake til iOS' egen
diktatmodell, som er svakere på norsk.

Prosjektfilen genereres fra `project.yml`. Rediger aldri `.xcodeproj` direkte.

## Test

Appen har sin egen simulator. Deles en bootet simulator med en annen sesjon,
feiler UI-testene med `Application failed preflight checks`.

```bash
xcrun simctl create "Frodi-Test" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcodebuild -project Frodi.xcodeproj -scheme Frodi \
  -destination 'platform=iOS Simulator,name=Frodi-Test' test
```

## Mer

| Dokument | Innhold |
|---|---|
| [PERSONVERN.md](PERSONVERN.md) | Hva som lagres, tillatelser, rettighetene dine |
| [SECURITY.md](SECURITY.md) | Hva som beskyttes mot hva, og hvordan melde sårbarhet |
| [TREDJEPART.md](TREDJEPART.md) | Modell, kode og skrifter, med lisenser |
| [CHANGELOG.md](CHANGELOG.md) | Hva som er endret |
