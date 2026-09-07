# Fróði

Norsk diktafon for iPhone. Tar opp lyd og gjør det om til tekst, på enheten.

## Hva appen gjør

- Tar opp lyd, også med skjermen av
- Handlingsknappen starter og stopper opptak
- Skriver ut norsk bokmål, med tegnsetting og store bokstaver
- Lar deg hente ut lyd og tekst

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
