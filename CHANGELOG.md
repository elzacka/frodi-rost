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
- Teksten eksporteres som `.rtf` eller `.txt`. Formatet velger du i Innstillinger;
  `.rtf` har overskrift og avsnitt
- Når du eksporterer, velger du opptaket, teksten eller begge
- Sveip et opptak mot venstre for å se hva du kan gjøre med det: «Lag tekst»,
  «Prøv på nytt» eller «Lag ny tekst», og «Slett». «Slett» spør «Sikker på at
  du vil slette?» i samme rad, med «Slett» og «Behold»
- Ordliste i Innstillinger: Navn og ord Fróði bør kjenne, som firmaer, personer
  og forkortelser. Modellen får listen før den lytter, og ord i teksten som
  nesten stemmer med listen, rettes etterpå. «Lag ny tekst» i listen
  bruker listen på et opptak du alt har. Feltet gjøres høyere eller lavere
  ved å dra i håndtaket nederst til høyre
- Brukerveiledning, [BRUKERVEILEDNING.md](BRUKERVEILEDNING.md), med alt om
  opptak, handlingsknappen, teksten, ordlisten, eksport og sletting
- Handlingsknappen starter opptak også når enheten er låst. Du setter den
  til kontrollen «Start eller stopp opptak» under Handlingsknapp > Kontroller.
  Kontrollen finnes også i Kontrollsenter
- Så lenge et opptak går, viser låseskjermen og Dynamic Island «Tar opp»,
  hvor lenge det har vart og en stoppknapp

### Endret

- Siden bak knappen i logohodet heter «Innstillinger». Knappen viser tre
  skyvebrytere. Siden har fire kort: Ordliste, Eksport,
  Fróði røst med versjon og kontakt, og Mer om appen med lenker til
  brukerveiledning, personvernerklæring og sikkerhet, og lisensene

- Appen krever iOS 27.0 eller nyere
- Teksten i kort, bannere og meldinger står mørkere, så den er lettere å lese
- Ikonene kommer fra Material Symbols
- Hoppknappene i spilleren hopper ti sekunder. Tallet står inne i pilen
- Handlingsknappen settes til en kontroll, ikke en snarvei. Snarveien
  «Start eller stopp opptak» og Siri-frasen er borte; handlingen finnes
  fortsatt i Snarveier-appen
- Animasjonene følger «Reduser bevegelse» i Innstillinger på enheten

### Rettet

- Et opptak overlever en telefonsamtale, med alt som ble sagt før den. Før
  ble det slettet når du stoppet etterpå
- Et opptak overlever at appen krasjer eller blir avsluttet midt i. Lyden tas
  opp i et format som kan spilles av uansett hvor den ble avbrutt
- Et opptak som mistet raden sin i listen, får den tilbake ved neste oppstart
- Et opptak som stoppes mens enheten er låst, blir tatt vare på. Før slettet
  appen det, fordi den ikke fikk lest filen og tok det for tomt
- Opptak kunne nekte å starte, fra knappen og fra handlingsknappen, rett
  etter at du hadde hørt på et opptak. Appen venter til avspilleren har
  sluppet lydsystemet før den tar opp
- Er mikrofontilgangen avslått, står knappen «Åpne Innstillinger» under
  meldingen om det
- En opptaksfil uten lyd, etterlatt av et krasj, fikk en rad som sto som
  «venter på tekst» for alltid. Filen fjernes, og raden med den
- Med ordliste kunne modellen svare med tom tekst uten feilmelding. Rettet i
  talemotoren, som er oppdatert til argmax-oss-swift 1.1.0

### Sikkerhet

- Talemotoren tar med seg to pakker i stedet for åtte. Lisenslisten følger


## 0.1.0 (5) – 13.09.26

### Sikkerhet

- Nøkkelen som låser opp opptak og tekst, kan bare brukes mens enheten er
  låst opp
- «Kopier»-knappen i tekstkortet erstatter markering av teksten. Det du
  kopierer, blir på enheten og forsvinner fra utklippstavlen etter fem minutter
- Får ikke appen tak i nøkkelen, sier den fra og ber deg låse opp enheten

### Endret

- PERSONVERN.md forteller hva som skjer når du kopierer, og at opptakene er
  borte for godt om du mister enheten

## 0.1.0 (4) – 13.09.26

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

## 0.1.0 (3) – 12.09.26

### Endret

- Info-siden har fem kort: Fróði røst, Personvern, Språkmodell, Lisenser og
  Versjon. Mikrofontilgangen står under Personvern
- Lisenslisten kaller gruppen «Fonter», med Skranji først

## 0.1.0 (2) – 12.09.26

### Endret

- Siden bak info-knappen heter «Info», ikke «Om»
- Handlingsknappen beskrives slik iOS 26 gjør det: Hold inne, ikke trykk
- Personvern-kortet lenker til PERSONVERN.md og SECURITY.md

## 0.1.0 (1) – 12.09.26

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
