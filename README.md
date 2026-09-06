# Fróði

Norsk diktafon for iPhone. Tar opp lyd og gjør det om til tekst — alt på
telefonen, uten nett.

## Hva appen gjør

- Tar opp lyd med ett trykk, også med skjermen av
- Kan startes med handlingsknappen på iPhone, uten å åpne appen først
- Gjør opptaket om til norsk tekst på enheten
- Lagrer opptak og tekst lokalt

## Personvern

Fróði sender ingenting. Appen har ingen nettverkskode, ingen sporing og ingen
tredjepartsbiblioteker. Opptakene og teksten blir liggende på telefonen din, og
er beskyttet så lenge telefonen er låst.

Se [PERSONVERN.md](PERSONVERN.md).

## Krav

- iPhone med iOS 26.5 eller nyere
- Handlingsknappen krever iPhone 15 Pro eller nyere

## Utvikling

```bash
brew install xcodegen
xcodegen generate
open Frodi.xcodeproj
```

Prosjektfilen genereres fra `project.yml`. Rediger aldri `.xcodeproj` direkte.

## Status

Tidlig versjon. Én funksjon: opptak med tale til tekst.
