# Endringer

Formatet følger [Keep a Changelog](https://keepachangelog.com/no/1.1.0/).

## [Ikke utgitt]

Første versjon.

### Lagt til

- Ta opp lyd, også når skjermen er av
- Den fysiske handlingsknappen på venstre side starter og stopper opptak
- Gjør norsk tale om til tekst med nb-whisper fra Nasjonalbiblioteket, som
  kjører i appen. Modellen setter tegn og store bokstaver selv, og skriver
  dialekt om til bokmål
- Spill av opptaket, med pause, hopp på femten sekunder hver vei og en
  skyveknapp som viser og setter posisjonen
- Hent ut lyd som `.m4a` og tekst som `.txt`
- Krypter opptak og tekst med en nøkkel som aldri forlater enheten
- Skjul teksten mens skjermen tas opp eller speiles
- App-ikon og logo i Skranji
- Info-siden bak info-knappen i logohodet: hva appen gjør, personvern og
  mikrofontilgang, hvilken språkmodell som kjører, lisenser og versjon

### Sikkerhet

- Et opptak som stoppes mens enheten er låst, krypteres så snart du låser opp
- Teksten skjules også når du bytter app, så den ikke havner i bildet iOS tar
  til appveksleren
- Midlertidige filer fra en avbrutt transkribering ryddes ved neste oppstart
- Modellen og kodepakkene er låst til faste versjoner, og skriptet som henter
  modellen sjekker hver fil mot en liste med sjekksummer
