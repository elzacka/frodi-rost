# Bidra til Fróði røst

Reglene her gjelder alt som går inn i repoet. [README.md](README.md) sier
hvordan du bygger og tester.

**Innhold**

- [Navn](#navn)
- [Språk](#språk)
- [Omfang](#omfang)
- [Designsystem](#designsystem)
- [Regler som ikke fravikes](#regler-som-ikke-fravikes)
- [Prosjektfilen og versjonen](#prosjektfilen-og-versjonen)
- [Før en build lastes opp](#før-en-build-lastes-opp)

---

## Navn

| Form       | Skrives                                    | Brukes til                                     |
| ---------- | ------------------------------------------ | ---------------------------------------------- |
| Fróði røst | med ó og ø, og «røst» med liten forbokstav | alt en bruker leser: Appnavn, App Store, prosa |
| Frodi      | ASCII                                      | kode, filnavn, bundle-ID, scheme og target     |

«røst» er en del av ordmerket, ikke et egennavn.

## Språk

| Hva                                                                                                                            | Språk                                                        |
| ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| Alt en bruker leser: Tekstene i appen, App Store, README, BRUKERVEILEDNING, PERSONVERN, CHANGELOG, TREDJEPART, TILGJENGELIGHET | norsk bokmål                                                 |
| SECURITY.md                                                                                                                    | engelsk                                                      |
| Kode, identifikatorer, filnavn, kommentarer og commit-meldinger                                                                | engelsk                                                      |

Norsk tekst skrives som norsk, ikke oversatt fra engelsk til slutt: Aktiv
form, korte setninger, «du», og alltid æ, ø og å. Sitattegn er «slik». Lag
aldri et norsk sammensatt ord ved å oversette et engelsk uttrykk ord for
ord. Bruk det norske ordet der det finnes, og det engelske der det ikke gjør.
Datoer skrives 19.09.26 på norsk og 2026-09-19 på engelsk.

## Omfang

Versjon 1 gjør én ting: Tar opp, og gjør lyden om til tekst. Ingen samtale,
ingen kunnskapsbase, ingen tekst til tale. Det hører til Fróði vit eller til
senere versjoner, og legges ikke til uten at noen har bedt om det.

## Designsystem

Tokenene i `Frodi/Theme/Theme.swift` er den eneste kilden til farger,
skrift, avstand og hjørner. Visningene bruker tokenene, aldri tall direkte.

- Bare lys modus. Designsystemet har ingen mørk palett
- Tekst på en aksentflate bruker `-on`-varianten, aldri ren svart eller hvit
- Skriften følger Dynamic Type gjennom `Font.custom(_:size:relativeTo:)`.
  Aldri `.custom(_:size:)` alene, for det fryser teksten. En test leter
  etter det
- Ingenting under 11 px. Tidtakeren skal kunne leses på armlengdes avstand i
  en bil
- Ikonene kommer fra Material Symbols, aldri fra SF Symbols. Det ene unntaket
  er kontrollen i Kontrollsenter, som systemet tegner fra et SF-symbol
- Fargen `accent-knowledge` er reservert for Fróði vit og finnes ikke i
  asset-katalogen. En test passer på det

## Regler som ikke fravikes

- Ingen nettverkskode. Ingen `URLSession`, ingen SDK-er, ingen analyse, ingen
  krasjrapportering. En test leter etter det
- Tale går gjennom nb-whisper i appen, og ingenting annet. Aldri
  `SFSpeechRecognizer`: Den viser en dialog fra Apple om at taledata sendes
  til Apple, og dialogen kan ikke slås av. `NSSpeechRecognitionUsageDescription`
  skal ikke inn i Info.plist. En test passer på det
- Filstier lagres som filnavn, aldri som absolutte adresser. Sandkassens
  sti endres ved oppdatering
- Et forseglet opptak har filvern `.complete`, og nøkkelen som åpner det,
  kan bare brukes mens enheten er låst opp. Ingenting i appen åpner et opptak
  på en låst enhet; ikke legg til noe som gjør det uten å løsne begge
- `versionIdentifier` i en SwiftData-modell som er tatt i bruk, endres aldri
- Et opptak går aldri tapt. Filen på disk er opptaket; raden i listen er
  bare et bilde av den og bygges opp igjen fra filen. Det eneste som sletter
  lyd, er brukeren, etter et spørsmål
- Ingen modus. Det appen gjør ulikt for et kort notat og et intervju på en
  time, avgjør den ut fra det den kan se, først og fremst lengden, ikke ut
  fra en bryter
- Skriv «intervju», aldri «revisjon», i tekst brukeren leser
- Ingen emoji, verken i kode, commit-meldinger eller grensesnitt
- Bare iPhone, bare stående, bare Norge. Ikke legg til engelsk grensesnitt

## Prosjektfilen og versjonen

`Frodi.xcodeproj` lages av xcodegen fra `project.yml`. Rediger aldri
`.xcodeproj` direkte. Versjonen står i `project.yml` og ingen andre steder.
`swift Scripts/asc-status.swift` spør App Store Connect hva som er lastet
opp, og stopper hvis buildnummeret alt er brukt.

## Før en build lastes opp

- Alle tester går grønt på simulatoren `Frodi-Test`
- Hver ny eller endret tekst i appen er lest gjennom av et menneske.
  `Scripts/string-diff.py <commit for forrige build>` skriver ut listen
- [CHANGELOG.md](CHANGELOG.md) har en overskrift for builden
- [TREDJEPART.md](TREDJEPART.md) og lisenslisten i appen er like. En test
  passer på det

---

[Til toppen](#bidra-til-fróði-røst)
