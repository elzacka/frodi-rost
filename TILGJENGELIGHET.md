# Tilgjengelighet i Fróði røst

Oppdatert 03.10.26.

Appen skal oppfylle WCAG 2.2 AA. Kolonnen Test sier hva som sikrer hvert
punkt, eller at ingen test gjør det.

## Hva som er på plass

| Krav                                        | Slik&nbsp;er&nbsp;det&nbsp;løst                                                                                                                                                                                                          | Test            |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| Kontrast 4,5:1 for tekst                    | Hver tekstfarge er regnet ut mot begge flatene tekst ligger på. Tallene står under                                                                                                                                                       | `ContrastTests` |
| Kontrast 3:1 for ikoner, kanter og aksenter | Samme utregning for opptaksknappen, kanten og fargen som viser at opptaket går                                                                                                                                                           | `ContrastTests` |
| Teksten følger Dynamic Type                 | Alle skriftstiler i `Theme.swift` bruker `Font.custom(_:size:relativeTo:)`, så størrelsen følger innstillingen på enheten                                                                                                                | `ThemeTests`    |
| Ingen tekst under 11 px                     | De minste stilene, `eyebrow` og `meta`, er 11 px. Tidtakeren er 32 px, lesbar på armlengdes avstand i bil                                                                                                                                | `Theme.swift`   |
| Trefflater på minst 44 pt                   | Innstillinger-knappen, importknappen, hopp-knappene i spilleren og radene som folder ut teksten og «Om opptaket» er 44 pt. Knappene bak et sveipet opptak er minst 44 pt. Opptaksknappen er 76 pt og spill av-knappen 56 pt                                                                                              | `Theme.swift`   |
| VoiceOver                                   | Hver knapp har norsk navn. Tidtakeren leses som tid, ikke som «0:04». Tidspunktene i teksten leses som «Spill av fra 12 minutter, 37 sekunder». Opptaksknappen heter «Start opptak» og «Stopp opptak», importknappen «Importer lydfil». Raden i listen leses som én enhet, med navnet først når opptaket har et navn | Ingen test      |
| Farge er aldri det eneste signalet          | Når opptaket går, bytter knappen ikon fra mikrofon til stopp, tidtakeren starter og VoiceOver-navnet endres. Lenker ut av appen har et ikon etter ordet. Kan ikke Fróði bekrefte opplysningene om et opptak, står det i tekst, ikke bare som en rød kant                                                                                  | Ingen test      |
| Sveipet har et alternativ                   | Handlingene bak et opptak i listen, «Slett» og teksthandlingen, finnes også som egendefinerte VoiceOver-handlinger på raden. Ingen trenger sveipet (WCAG 2.5.1). Spørsmålet «Sikker på at du vil slette?» står i raden, og «Slett» og «Behold» er egne knapper                                                | Ingen test      |
| Lukk med VoiceOver-gesten                   | `UIAccessibilityPerformEscapeEnabled` er satt, så Z-gesten lukker arkene                                                                                                                                                                 | `Info.plist`    |
| Redusert bevegelse                          | Når innstillingen er på, folder teksten og «Om opptaket» seg ut uten animasjon, og raden som sveipes eller slettes, flytter seg uten animasjon                                                                                                          | Ingen test      |
| Ingen tomme knapper                         | Et ikon som mangler i katalogen tegner ingenting, og knappen blir stående tom. En test laster hvert ikon                                                                                                                                 | `IconTests`     |

## Målte kontraster

Regnet ut fra fargene i asset-katalogen, slik `ContrastTests` gjør det. Appen
har to tekstfarger og ingen blanding. Sekundær tekst mot brødtekst måler
2,88:1, og en test krever minst 2,5:1, så skillet mellom dem er synlig.

| Farge                                      | Mot            | Målt    | Krav  |
| ------------------------------------------ | -------------- | ------- | ----- |
| Tekst (`TextPrimary`)                      | bakgrunn       | 14,44:1 | 4,5:1 |
| Tekst                                      | flate          | 16,25:1 | 4,5:1 |
| Sekundær tekst (`TextSecondary`)           | bakgrunn       | 5,02:1  | 4,5:1 |
| Sekundær tekst                             | flate          | 5,65:1  | 4,5:1 |
| Tekst på opptaksknappen (`AccentRecordOn`) | opptaksknappen | 4,59:1  | 4,5:1 |
| Opptaksknappen (`AccentRecord`)            | bakgrunn       | 3,25:1  | 3:1   |
| Opptaksknappen                             | flate          | 3,66:1  | 3:1   |
| Opptak pågår (`RecordingActive`)           | bakgrunn       | 4,87:1  | 3:1   |
| Stoppikonet (`Surface`)                    | opptak pågår   | 5,48:1  | 3:1   |
| Kant (`BorderNeutral`)                     | bakgrunn       | 3,23:1  | 3:1   |
| Kant                                       | flate          | 3,63:1  | 3:1   |

> **Merk:** Opptaksknappen skifter fra bronse til rødt når opptaket starter,
> og kontrasten mellom de to fargene er bare 1,50:1. Paret er med hensikt ikke
> testet, fordi fargen aldri er det eneste signalet. Se raden «Farge er aldri
> det eneste signalet» over.

## Kjente grenser

| Grense                                                    | Hvorfor                                                                                                                                                                        |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Bare lys modus                                            | Designsystemet har ingen mørk palett                                                                                                                                          |
| Bare stående modus                                        | Ingen liggende layout er bygget                                                                                                                                                |
| Ikonene skalerer ikke                                     | Fast størrelse. Teksten ved siden av følger Dynamic Type                                                                                                                       |
| Ordliste-feltet i Innstillinger mangler VoiceOver-hint    | Har bare et navn, ulikt Lisenser-raden som har både navn og hint                                                                                                               |
| Ingen lyd når opptaket starter eller stopper              | Handlingsknappen vibrerer ved hvert trykk, uansett hva den er satt til. Det bekrefter trykket, ikke opptaket. Låseskjermen og Dynamic Island viser om opptaket går, men bare for den som ser dit |
