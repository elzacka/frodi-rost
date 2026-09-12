# Fróði røst

Tar opp lyd på iPhone og gjør den om til norsk tekst. Alt skjer på enheten.

«Fróði» er norrønt for «den kunnskapsrike». «Røst» er stemme.

Fróði er en serie med to apper. Den andre heter [«Fróði vit»](https://github.com/elzacka/frodi-vit)
og er en kunnskapsassistent som svarer på det du spør om.

## Hva appen gjør

- Tar opp lyd, også når skjermen er av
- Handlingsknappen starter og stopper opptak
- Skriver teksten på norsk bokmål, med tegnsetting og store bokstaver
- Lar deg hente ut lyd og tekst

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

- iPhone med iOS 26.5 eller nyere
- Handlingsknappen krever iPhone 15 Pro eller nyere

## Bygg

```bash
brew install xcodegen
./Scripts/fetch-model.sh   # ca. 487 MB, kjør én gang
xcodegen generate
open Frodi.xcodeproj
```

Modellen ligger ikke i git. Uten den faller appen tilbake til iOS' egen
diktatmodell, som er svakere på norsk.

Xcodegen genererer prosjektfilen fra `project.yml`. Rediger aldri
`.xcodeproj` direkte.

## Test

Appen har sin egen simulator. Deler du en startet simulator med en annen
sesjon, feiler UI-testene med `Application failed preflight checks`.

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
| [TREDJEPART.md](TREDJEPART.md) | Modell, kode og fonter, med lisenser |
| [CHANGELOG.md](CHANGELOG.md) | Hva som er endret |
