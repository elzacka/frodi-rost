# Fróði

Norsk diktafon for iPhone. Tar opp lyd og gjør det om til tekst, på enheten.

## Hva appen gjør

- Tar opp lyd med ett trykk, også med skjermen av
- Handlingsknappen starter og stopper opptak
- Skriver ut norsk bokmål, med tegnsetting og store bokstaver
- Lar deg hente ut lyd og tekst

## Krav

- iPhone med iOS 26.5 eller nyere
- Handlingsknappen krever iPhone 15 Pro eller nyere

## Utvikling

```bash
brew install xcodegen
./Scripts/fetch-model.sh   # ca. 487 MB, kjøres én gang
xcodegen generate
open Frodi.xcodeproj
```

Modellen ligger ikke i git. Hopper du over `fetch-model.sh`, bygger appen
likevel, men faller tilbake til iOS' egen diktatmodell.

Prosjektfilen genereres fra `project.yml`. Rediger aldri `.xcodeproj` direkte.

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

| Dokument                       | Innhold                                                            |
| ------------------------------ | ------------------------------------------------------------------ |
| [PERSONVERN.md](PERSONVERN.md) | Hva som lagres, hvilke tillatelser appen ber om, rettighetene dine |
| [SECURITY.md](SECURITY.md)     | Trusselmodell, hvordan data beskyttes, hvordan melde en sårbarhet  |
| [TREDJEPART.md](TREDJEPART.md) | Modell, kode og skrifter appen bygger på, med lisenser             |
| [CHANGELOG.md](CHANGELOG.md)   | Hva som er endret                                                  |
