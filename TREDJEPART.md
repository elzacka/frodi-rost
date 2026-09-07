# Tredjepartslisenser

Fróði bruker fritt tilgjengelig programvare, modeller og skrifter. Ingenting
koster penger, verken å bruke eller å kjøre. Men Apache 2.0 krever at
opphavet oppgis, og denne filen er den attribusjonen.

Sist gjennomgått 7. september 2026.

## Modell for tale til tekst

| Hva | Opphav | Lisens |
|---|---|---|
| nb-whisper-small | Nasjonalbiblioteket (NbAiLab) | Apache 2.0 |
| CoreML-konvertering | `Barrymanalow/nb-whisper-coreml` | Apache 2.0 |
| Tokenizer | OpenAI, `whisper-small` | Apache 2.0 |

nb-whisper bygger på OpenAIs Whisper, videretrent på 66 000 timer norsk tale fra
Språkbanken og Nasjonalbibliotekets samling.

Modellen kjører på enheten. Den koster ingenting per bruk, sender ingen
forespørsler, og har verken kvote eller nøkkel.

## Kode

| Pakke | Opphav | Lisens |
|---|---|---|
| WhisperKit | Argmax | MIT |
| swift-transformers | Hugging Face | Apache 2.0 |
| swift-jinja | Hugging Face | Apache 2.0 |
| swift-collections | Apple | Apache 2.0 |
| swift-argument-parser | Apple | Apache 2.0 |
| swift-crypto | Apple | Apache 2.0 |
| swift-asn1 | Apple | Apache 2.0 |
| yyjson | Yao Yuan | MIT |

## Skrifter

| Skrift | Opphav | Lisens |
|---|---|---|
| Inter | Rasmus Andersson | SIL Open Font License 1.1 |
| Norse | Joël Carrouché | Joel Carrouche Free Font License 1.3 |

**Norse har en begrensning som gjelder dette repoet.** Lisensen tillater uttrykkelig
å bygge fonten inn i en app, også kommersielt. Men den forbyr videredistribusjon
uten skriftlig samtykke, og sier eksplisitt at fonten ikke kan gjøres tilgjengelig
for nedlasting fra en nettside.

Fontfilene ligger i dag i `Frodi/Resources/Fonts/` og er sporet i git. Blir dette
repoet offentlig, er det videredistribusjon. Tre veier ut: hold repoet privat, ta
fontfilene ut av git slik modellen er tatt ut, eller be Joël Carrouché om samtykke.

Fonten er heller ikke endret, slik lisensen krever.
