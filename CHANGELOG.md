# Endringer

Formatet følger [Keep a Changelog](https://keepachangelog.com/nb/1.1.0/).
Hver overskrift er en build lastet opp til App Store Connect, nyeste først.
Ingenting er i App Store ennå.

## Ikke utgitt

### Sikkerhet

- Nøkkelen som låser opp opptak og tekst, kan bare brukes mens enheten er låst
  opp. Før holdt det at enheten hadde vært låst opp én gang siden omstart.
  Nøkler laget av build 4 eller tidligere beholder den gamle klassen
- «Kopier»-knappen i tekstkortet erstatter markering av teksten. Det du
  kopierer, blir på enheten og forsvinner fra utklippstavlen etter fem minutter

## 0.1.0 (4) – 13. september 2026

### Sikkerhet

- Et opptak som stoppes mens enheten er låst, krypteres så snart du låser opp.
  Før ble det slettet
- Teksten skjules også når du bytter app, så den ikke havner i bildet iOS tar
  til appveksleren
- Midlertidige filer fra en avbrutt transkribering ryddes ved neste oppstart
- Databasens hjelpefiler holdes utenfor sikkerhetskopien fra første lagring
- Modellen og kodepakkene er låst til faste versjoner, og skriptet som henter
  modellen sjekker hver fil mot en liste med sjekksummer
- Appen sjekker selv at begge tokenizer-filene finnes før WhisperKit startes,
  så en ufullstendig modell aldri utløser en nedlasting
- WhisperKit skriver ikke lenger til loggen

### Rettet

- Opptak uten tale transkriberes ikke på nytt ved hver oppstart

### Endret

- Personvern-kortet forteller hva som skjer med et opptak som stoppes mens
  enheten er låst

## 0.1.0 (3) – 12. september 2026

### Endret

- Info-siden har fem kort: Fróði røst, Personvern, Språkmodell, Lisenser og
  Versjon. Mikrofontilgangen står under Personvern
- Lisenslisten kaller gruppen «Fonter», med Skranji først

## 0.1.0 (2) – 12. september 2026

### Endret

- Siden bak info-knappen heter «Info», ikke «Om»
- Handlingsknappen beskrives slik iOS 26 gjør det: hold inne, ikke trykk
- Personvern-kortet lenker til PERSONVERN.md og SECURITY.md

## 0.1.0 (1) – 12. september 2026

Første build.

### Lagt til

- Ta opp lyd, også når skjermen er av
- Den fysiske handlingsknappen på venstre side starter og stopper opptak
- Et opptak kan vare i inntil ti minutter. Nedtellingen står ved siden av
  tidtakeren mens du tar opp
- Gjør norsk tale om til tekst med nb-whisper fra Nasjonalbiblioteket, som
  kjører i appen. Modellen setter tegn og store bokstaver selv, og skriver
  dialekt om til bokmål
- Spill av opptaket, med pause, hopp på femten sekunder hver vei og en
  skyveknapp som viser og setter posisjonen
- Hent ut lyd som `.m4a` og tekst som `.txt`
- Krypter opptak og tekst med en nøkkel som aldri forlater enheten
- Skjul teksten mens skjermen tas opp eller speiles
- App-ikon og logo i Skranji, ikoner fra Heroicons
- Om-siden bak info-knappen i logohodet: hva appen gjør, personvern,
  mikrofontilgang, hvilken språkmodell som kjører, lisenser og versjon
