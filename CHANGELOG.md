# Endringer

Formatet følger [Keep a Changelog](https://keepachangelog.com/nb/1.1.0/).
Hver overskrift er en build lastet opp til App Store Connect, nyeste først.

## Ikke utgitt

### Lagt til

- Et opptak kan vare så lenge du vil. Grensen på ti minutter er borte
- Teksten deles i avsnitt med tidspunkt. Trykk på tidspunktet for å høre
  stedet i opptaket
- Er opptaket over ti minutter, lager appen teksten når du ber om den, og
  viser hvor langt den har kommet. Blir den avbrutt, fortsetter den der den
  slapp neste gang
- Teksten eksporteres som `.rtf` eller `.txt`. Formatet velger du på Info-siden;
  `.rtf` har overskrift og avsnitt
- Når du eksporterer, velger du opptaket, teksten eller begge
- «Slett» spør først, i et ark nederst på skjermen
- Ordliste på Info-siden: Navn og ord Fróði bør kjenne, som firmaer, personer
  og forkortelser. Modellen får listen før den lytter, og ord i teksten som
  nesten stemmer med listen, rettes etterpå. «Lag teksten på nytt» i listen
  bruker listen på et opptak du alt har
- Teksten lages også mens enheten lader, med skjermen låst
- Snarveien «Lag tekst i Fróði røst» lager teksten uten at appen er åpen, også
  for lange opptak. Den kan legges i en automatisering i Snarveier
- Brukerveiledning, [BRUKERVEILEDNING.md](BRUKERVEILEDNING.md), med alt om
  opptak, handlingsknappen, teksten, ordlisten, eksport og sletting

### Endret

- Info-siden lenker til brukerveiledningen og personvernerklæringen. Kortene
  Ordliste og Eksport har én setning hver

- Appen krever iOS 27.0 eller nyere
- Teksten i kort, bannere og meldinger står mørkere, så den er lettere å lese
- Ikonene kommer fra Material Symbols, ikke lenger fra Heroicons
- Hoppknappene i avspilleren hopper ti sekunder, ikke femten. Tallet står
  inne i pilen igjen

### Rettet

- Et opptak overlever en telefonsamtale. Før ble det slettet når du stoppet
  etterpå
- Et opptak overlever at appen krasjer eller blir avsluttet midt i. Lyden tas
  opp i et format som kan spilles av uansett hvor den ble avbrutt
- Et opptak som mistet raden sin i listen, får den tilbake ved neste oppstart
- Et opptak som stoppes mens enheten er låst, blir tatt vare på. Før slettet
  appen det, fordi den ikke fikk lest filen og tok det for tomt

### Sikkerhet

- Nøkkelen som låser opp opptak og tekst, kan brukes av appen etter at
  enheten har vært låst opp én gang siden omstart, også mens den er låst
  igjen. Det er det som lar teksten lages mens enheten lader. Fra build 5 til
  14. september 2026 krevde nøkkelen at enheten var låst opp; en nøkkel laget
  av build 5 eller 6 beholder det kravet, og på den enheten lages teksten
  bare mens appen er åpen

## 0.1.0 (5) – 13. september 2026

### Sikkerhet

- Nøkkelen som låser opp opptak og tekst, kunne bare brukes mens enheten var
  låst opp. Endret igjen etter denne builden, se over
- «Kopier»-knappen i tekstkortet erstatter markering av teksten. Det du
  kopierer, blir på enheten og forsvinner fra utklippstavlen etter fem minutter
- Får ikke appen tak i nøkkelen, sier den fra og ber deg låse opp enheten

### Endret

- PERSONVERN.md forteller hva som skjer når du kopierer, og at opptakene er
  borte for godt om du mister enheten

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
- Handlingsknappen beskrives slik iOS 26 gjør det: Hold inne, ikke trykk
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
- Eksporter lyd som `.m4a` og tekst som `.txt`
- Krypter opptak og tekst med en nøkkel som aldri forlater enheten
- Skjul teksten mens skjermen tas opp eller speiles
- App-ikon og logo i Skranji, ikoner fra Heroicons
- Om-siden bak info-knappen i logohodet: Hva appen gjør, personvern,
  mikrofontilgang, hvilken språkmodell som kjører, lisenser og versjon
