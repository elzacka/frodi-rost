# Bidra til Fróði røst

Reglene her gjelder alt som går inn i repoet. [README.md](README.md) sier
hvordan du bygger og tester.

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

Versjon 1 gjør én ting: Gjør lyd om til tekst. Lyden kommer fra et opptak i
appen eller fra en lydfil du importerer. Ingen samtale, ingen kunnskapsbase,
ingen tekst til tale. Det hører til Fróði vit eller til
senere versjoner, og legges ikke til uten at noen har bedt om det.

## Designsystem

Visningene henter farger, skrift, avstand og hjørner fra tokenene i
`Frodi/Theme/Theme.swift`, aldri fra tall direkte.

- Bare lys modus. Designsystemet har ingen mørk palett
- Tekst på en aksentflate bruker `-on`-varianten, aldri ren svart eller hvit
- Skriften følger Dynamic Type gjennom `Font.custom(_:size:relativeTo:)`.
  Aldri `.custom(_:size:)` alene, for da følger ikke teksten innstillingen. En test leter
  etter det
- Ingenting under 11 px. Tidtakeren skal kunne leses på armlengdes avstand i
  en bil
- Ikonene kommer fra Material Symbols, aldri fra SF Symbols. Det ene unntaket
  er kontrollen i Kontrollsenter, som systemet tegner fra et SF-symbol
- Fargen `accent-knowledge` er reservert for Fróði vit og finnes ikke i
  asset-katalogen. En test passer på det

## Regler som ikke fravikes

- Ingen nettverkskode. Ingen `URLSession`, ingen SDK-er, ingen bruksstatistikk,
  ingen krasjrapportering. En test leter etter det
- Tale går gjennom nb-whisper i appen, og ingenting annet. Aldri
  `SFSpeechRecognizer`: Den viser en dialog fra Apple om at taledata sendes
  til Apple, og dialogen kan ikke slås av. `NSSpeechRecognitionUsageDescription`
  skal ikke inn i Info.plist. En test passer på det
- Filer lagres med filnavn, aldri med absolutt sti. Stien til appens mappe
  endres når appen oppdateres
- Et forseglet opptak har filbeskyttelsen `.complete`, og nøkkelen som åpner
  det, kan bare brukes mens enheten er låst opp. Ingenting i appen åpner et
  opptak på en låst enhet. Ikke legg til noe som gjør det, uten å endre begge
- En importert fil kommer forseglet inn i opptaksmappen, sammen med raden sin.
  Legg aldri en ukryptert import der: Forseglingen ville tatt den for et
  opptak fra appen
- Opplysningene om et opptak, `RecordingOrigin`, skrives én gang og aldri
  igjen. Ikke legg til noe som skriver dem på nytt, eller som skriver dem for
  et opptak som mangler dem. En test passer på at de ikke skrives to ganger
- Hvert tekstfelt har autokorrektur slått av, så det brukeren skriver, ikke
  havner i tastaturets ordbok. Systemets eget felt for å gi nytt navn følger
  ikke den innstillingen, så appen har sitt eget
- `versionIdentifier` i en SwiftData-modell som er tatt i bruk, endres aldri
- Et opptak går aldri tapt. Filen på disk er opptaket, og raden i listen
  bygges opp igjen fra filen. Bare brukeren sletter lyd, og bare etter å ha
  bekreftet det
- Ingen modus. Appen avgjør selv hva den gjør ulikt for et kort notat og et
  intervju på en time, ut fra det den kan se, først og fremst lengden. Ingen
  bryter
- Skriv «intervju», aldri «revisjon», i tekst brukeren leser
- Ingen emoji, verken i kode, commit-meldinger eller grensesnitt
- Bare iPhone, bare stående, bare Norge. Ikke legg til engelsk grensesnitt

## Prosjektfilen og versjonen

`Frodi.xcodeproj` lages av xcodegen fra `project.yml`. Rediger aldri
`.xcodeproj` direkte. Versjonen står i `project.yml` og ingen andre steder.
