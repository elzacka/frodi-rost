# Endringer

Formatet følger [Keep a Changelog](https://keepachangelog.com/nb/1.1.0/).
Hver overskrift er en build lastet opp til App Store Connect, nyeste først.

## Ikke utgitt

### Lagt til

- Under Lisenser i Innstillinger kan du trykke på en rad og lese hele
  lisensteksten
- Innstillinger har en lenke til «Tilgjengelighet». Lenken til
  sikkerhetsdokumentet heter «Sikkerhet (engelsk)», fordi dokumentet er på
  engelsk
- `.rtf`-filen sier at teksten er laget automatisk og kan inneholde feil

### Endret

- Fróði lagrer ikke stedet der en importert fil ble tatt opp, selv om filen
  oppgir det
- Når appen ber om tilgang til mikrofonen, står det at den tar opp notater og
  samtaler
- «Om opptaket» forklarer med enklere ord hva en sjekksum er, og hvilken fil
  hver sjekksum hører til
- Tekstene i appen, brukerveiledningen og personvernerklæringen er skrevet
  om til mer naturlig norsk, med det viktigste først i hver setning
- Når listen er tom, står det at brukerveiledningen under Innstillinger viser
  hvordan du tar opp med handlingsknappen

### Rettet

- Knappene du får frem ved å sveipe et opptak, er like store på alle opptak,
  også på opptak med navn
- Hvis Fróði ikke får åpnet databasen, sier meldingen at lyden blir liggende
  på enheten, og at du ikke skal slette appen
- Hvis språkmodellen mangler, ber meldingen deg skrive til hei@tazk.no

## 1.0 (9) – 28.09.26

Den første versjonen i App Store, godkjent av Apple 28.09.26.
Appen er den samme som i build 8.

## 1.0 (8) – 27.09.26

### Lagt til

- Du kan importere lydfiler fra Filer, for eksempel m4a, mp3 og wav: Trykk på
  ikonet med lydbølger og pluss øverst til venstre. Appen lager tekst av dem
  som av egne opptak, og originalen blir liggende der den var
- Du kan gi et opptak et navn: Trykk på tittelen på opptakets side og velg
  «Endre navn». Navnet står over datoen i listen
- «Om opptaket» på opptakets side viser opplysningene Fróði lagret da
  opptaket kom inn i appen: Når det kom inn, hvor langt det er og sjekksum for
  lyden. For en importert fil også filnavn, format, størrelse, opplysningene
  som stod i filen og sjekksum for originalen. Siden sier fra hvis datoen,
  lengden eller lyden er endret utenfor appen
- `.rtf`-filen har navnet som overskrift og sjekksum for lydfilen

### Endret

- Under overskriften i `.rtf`-filen står «Laget med Fróði røst»

### Rettet

- Listen ruller når du drar opp eller ned på et opptak
- Ordlisten retter ikke bøyde former, så «internkontrollen» blir stående når
  listen har «internkontroll»

### Sikkerhet

- På iPhone 17 og nyere, og på iPhone Air, bruker appen Memory Integrity
  Enforcement, Apples minnebeskyttelse i maskinvaren. Enheten stopper appen
  hvis appen leser eller skriver i minne den ikke har fått tildelt. Det gjør
  det mye vanskeligere å bruke en slik feil til å ta over appen

## 1.0 (7) – 26.09.26

### Endret

- Versjonen heter 1.0. Appen er ellers den samme som i build 6

## 0.1.0 (6) – 26.09.26

### Lagt til

- Et opptak kan vare så lenge du vil
- Teksten deles i avsnitt med tidspunkt. Trykk på tidspunktet for å spille av
  derfra
- Appen lager teksten når du ber om den hvis opptaket er over ti minutter, og
  viser hvor langt den har kommet. Den fortsetter der den slapp neste gang
  hvis noe avbryter den
- Teksten eksporteres som `.rtf` eller `.txt`. Formatet velger du i Innstillinger;
  `.rtf` har overskrift og avsnitt
- Når du eksporterer, velger du opptaket, teksten eller begge
- Sveip et opptak mot venstre for å se hva du kan gjøre med det: «Lag tekst»,
  «Prøv på nytt» eller «Lag ny tekst», og «Slett». «Slett» spør «Sikker på at
  du vil slette?» i samme rad, med «Slett» og «Behold»
- Ordliste i Innstillinger: Navn og ord Fróði bør kjenne, som firmaer, personer
  og forkortelser. Modellen får listen før den lytter, og ord i teksten som
  nesten stemmer med listen, rettes etterpå. «Lag ny tekst» i listen
  bruker listen på et opptak du alt har. Du gjør feltet høyere eller lavere
  ved å dra i håndtaket nederst til høyre
- Brukerveiledning, [BRUKERVEILEDNING.md](BRUKERVEILEDNING.md), med alt om
  opptak, handlingsknappen, teksten, ordlisten, eksport og sletting
- Handlingsknappen starter opptak også når enheten er låst. Du setter den
  til kontrollen «Start eller stopp opptak» under Handlingsknapp > Kontroll.
  Kontrollen finnes også i Kontrollsenter
- Musikk og annen lyd fortsetter, men lavere, når du starter et opptak med
  handlingsknappen mens appen ikke er åpen
- Så lenge et opptak går, viser låseskjermen og Dynamic Island «Tar opp»,
  hvor lenge det har vart og en stoppknapp

### Endret

- Siden bak knappen ved logoen øverst heter «Innstillinger». Knappen viser tre
  skyvebrytere. Siden har fire kort: Ordliste, Eksport,
  Fróði røst med versjon og kontakt, og Mer om appen med lenker til
  brukerveiledning, personvernerklæring og sikkerhet, og lisensene
- Appen krever iOS 27.0 eller nyere
- Teksten i kort, bannere og meldinger står mørkere, så den er lettere å lese
- Ikonene kommer fra Material Symbols
- Hoppknappene i spilleren hopper ti sekunder. Tallet står inne i pilen
- Handlingsknappen settes til en kontroll, ikke en snarvei. Handlingen
  «Start eller stopp opptak» finnes i Snarveier-appen, uten egen snarvei og
  uten Siri-frase
- Animasjonene følger «Reduser bevegelse» i Innstillinger på enheten

### Rettet

- Et opptak går ikke tapt når du får en telefonsamtale, heller ikke det som
  ble sagt før samtalen
- Et opptak går ikke tapt hvis appen krasjer eller blir avsluttet midt i.
  Lyden tas opp i et format som kan spilles av uansett hvor den ble avbrutt
- Et opptak som mistet raden sin i listen, får den tilbake ved neste oppstart
- Et opptak som stoppes mens enheten er låst, krypteres og får tekst senest
  når du åpner appen igjen
- Et opptak som stoppes mens enheten er låst, blir tatt vare på, også når
  appen ikke får lest filen med en gang
- Opptak startet av og til ikke, fra knappen eller fra handlingsknappen, rett
  etter at du hadde hørt på et opptak. Appen venter til avspilleren har
  sluppet lydsystemet før den tar opp
- Knappen «Åpne Innstillinger» står under meldingen om at mikrofontilgangen
  er avslått
- En tom opptaksfil etter et krasj fikk en rad som sto som «venter på tekst»
  for alltid. Appen fjerner filen og raden
- Med ordliste kunne modellen svare med tom tekst uten feilmelding. Rettet i
  talemotoren, som er oppdatert til argmax-oss-swift 1.1.0

### Sikkerhet

- Talemotoren tar med seg to pakker i stedet for åtte. Lisenslisten er
  oppdatert


## 0.1.0 (5) – 13.09.26

### Sikkerhet

- Nøkkelen som låser opp opptak og tekst, kan bare brukes mens enheten er
  låst opp
- «Kopier»-knappen i tekstkortet erstatter markering av teksten. Det du
  kopierer, blir på enheten og forsvinner fra utklippstavlen etter fem minutter
- Appen sier fra og ber deg låse opp enheten hvis den ikke får tak i nøkkelen

### Endret

- PERSONVERN.md forteller hva som skjer når du kopierer, og at opptakene er
  borte for godt om du mister enheten

## 0.1.0 (4) – 13.09.26

### Sikkerhet

- Et opptak som stoppes mens enheten er låst, krypteres så snart du låser opp
- Teksten skjules også når du bytter app, så den ikke havner i bildet iOS tar
  til appveksleren
- Appen sletter midlertidige filer ved neste oppstart hvis den ble avbrutt
  mens den laget tekst
- Databasens hjelpefiler holdes utenfor sikkerhetskopien fra første lagring
- Modellen og kodepakkene er låst til faste versjoner, og skriptet som henter
  modellen, sjekker hver fil mot en liste med sjekksummer
- Appen sjekker selv at begge tokenizer-filene finnes før WhisperKit startes,
  så en ufullstendig modell aldri utløser en nedlasting
- WhisperKit skriver ikke til loggen

### Rettet

- Appen prøver ikke å lage tekst av opptak uten tale på nytt ved hver oppstart

### Endret

- Personvernkortet forteller hva som skjer med et opptak som stoppes mens
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
- Personvernkortet lenker til PERSONVERN.md og SECURITY.md

## 0.1.0 (1) – 12.09.26

Første build.

### Lagt til

- Tar opp lyd, også når skjermen er av
- Den fysiske handlingsknappen på venstre side starter og stopper opptak
- Et opptak kan vare i inntil ti minutter. Nedtellingen står ved siden av
  tidtakeren mens du tar opp
- Gjør norsk tale om til tekst med nb-whisper fra Nasjonalbiblioteket, som
  kjører i appen. Modellen setter tegn og store bokstaver selv og skriver
  dialekt om til bokmål
- Spiller av opptaket, med pause, hopp på femten sekunder hver vei og en
  skyveknapp som viser og setter posisjonen
- Eksporterer lyd som `.m4a` og tekst som `.txt`
- Krypterer opptak og tekst med en nøkkel som aldri forlater enheten
- Skjuler teksten mens skjermen tas opp eller speiles
- Appikon og logo i Skranji, ikoner fra Heroicons
- Om-siden bak info-knappen ved logoen øverst: Hva appen gjør, personvern,
  mikrofontilgang, hvilken språkmodell som kjører, lisenser og versjon
