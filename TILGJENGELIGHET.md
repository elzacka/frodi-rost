# Tilgjengelighet i Fróði røst

Oppdatert 13. september 2026.

Appen skal oppfylle WCAG 2.2 AA. Det som står her, er målt eller passet på
av en test, ikke lovet. Kolonnen til høyre sier hvilken test, eller at det
ikke finnes noen.

## Hva som er på plass

| Krav | Slik er det løst | Passes på av |
|---|---|---|
| Kontrast 4,5:1 for tekst | Hver tekstfarge er regnet ut mot begge flatene tekst ligger på. Tallene står under | `ContrastTests` |
| Kontrast 3:1 for ikoner, kanter og aksenter | Samme utregning for opptaksknappen, kanten og fargen som viser at opptaket går | `ContrastTests` |
| Teksten følger Dynamic Type | Alle skriftstiler i `Theme.swift` bruker `Font.custom(_:size:relativeTo:)`, så størrelsen følger innstillingen på enheten | `ThemeTests` |
| Ingen tekst under 11 px | De minste stilene, `eyebrow` og `meta`, er 11 px. Tidtakeren er 32 px, så den kan leses på armlengdes avstand i en bil | `Theme.swift` |
| Treffflater på minst 44 pt | Info-knappen, hopp-knappene i spilleren og raden som folder teksten ut er 44 pt. Opptaksknappen er 76 pt og spill av-knappen 56 pt | `Theme.swift` |
| VoiceOver | Hver knapp har norsk navn. Tidtakeren leses som tid, ikke som «0:04». Tidspunktene i teksten leses som «Spill av fra 12 minutter, 37 sekunder». Opptaksknappen heter «Start opptak» og «Stopp opptak». Raden i listen leses som én enhet | Ingen test |
| Farge er aldri det eneste signalet | Når opptaket går, bytter knappen ikon fra mikrofon til stopp, tidtakeren starter og VoiceOver-navnet endres. Lenker er understreket | Ingen test |
| Lukk med VoiceOver-gesten | `UIAccessibilityPerformEscapeEnabled` er satt, så Z-gesten lukker arkene | `Info.plist` |
| Ingen tomme knapper | Et ikon som mangler i katalogen tegner ingenting, og knappen blir stående tom. En test laster hvert ikon | `IconTests` |

## Målte kontraster

Regnet ut fra fargene i asset-katalogen, slik `ContrastTests` gjør det.

| Farge | Mot | Målt | Krav |
|---|---|---|---|
| Tekst (`TextPrimary`) | bakgrunn | 14,44:1 | 4,5:1 |
| Tekst | flate | 16,25:1 | 4,5:1 |
| Sekundær tekst (`TextSecondary`) | bakgrunn | 5,02:1 | 4,5:1 |
| Sekundær tekst | flate | 5,65:1 | 4,5:1 |
| Tekst på opptaksknappen (`AccentRecordOn`) | opptaksknappen | 4,59:1 | 4,5:1 |
| Opptaksknappen (`AccentRecord`) | bakgrunn | 3,25:1 | 3:1 |
| Opptaksknappen | flate | 3,66:1 | 3:1 |
| Opptak pågår (`RecordingActive`) | bakgrunn | 4,87:1 | 3:1 |
| Stoppikonet (`Surface`) | opptak pågår | 5,48:1 | 3:1 |
| Kant (`BorderNeutral`) | bakgrunn | 3,23:1 | 3:1 |
| Kant | flate | 3,63:1 | 3:1 |

Sekundær tekst lå på 3,92:1 mot flate i et halvt år uten at noen så det. Det
ser riktig ut på skjermen. Bare regning fant det, og derfor finnes testen.

Ett par står med vilje utenfor testen. Opptaksknappen skifter fra bronse til
rødt når opptaket går, og det er 1,50:1. Fargen er ikke det eneste signalet,
se tabellen over.

## Kjente grenser

| Grense | Hvorfor |
|---|---|
| Bare lys modus | Designsystemet har ingen mørk palett. Kontrastene over gjelder den lyse, og en mørk måtte måles på nytt |
| Bare stående | Ingen visning har en liggende utgave |
| Ikonene skalerer ikke | Ikonene har fast størrelse. Teksten ved siden av dem følger Dynamic Type |
| Ingen egen lås i appen | Appen brukes med hendene opptatt, i bil. En Face ID-sperre i det øyeblikket du skal ta opp, ville ødelegge poenget. Se [SECURITY.md](SECURITY.md) |
| Ingen lyd eller vibrasjon når opptaket starter og stopper | Bare skjermen viser om opptaket går. Et lydsignal ble bygget og tatt ut igjen |
| Redusert bevegelse | Appen har én animasjon, når teksten foldes ut. Den tar ikke hensyn til innstillingen ennå |

Om forskriften om universell utforming av IKT gjelder for en gratis app fra
én person, er ikke avklart. Målingene finnes uansett, og da hører de hjemme
her.
