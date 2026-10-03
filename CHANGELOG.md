# Endringer

Formatet følger [Keep a Changelog](https://keepachangelog.com/nb/1.1.0/).
Hver overskrift er en build lastet opp til App Store Connect, nyeste først.
Listen starter med den første versjonen i App Store.

## 1.1.0 (11) – 04.10.26

### Endret

- Tekstmodus i Innstillinger har en kortere forklaring
- Lenken til «Tilgjengelighet» i Innstillinger er fjernet

## 1.1.0 (10) – 03.10.26

### Lagt til

- Tekstmodus i Innstillinger. Med Avansert viser teksten hvem som sa hva, og
  du kan gi personene navn
- Under Lisenser i Innstillinger kan du trykke på en rad og lese hele
  lisensteksten
- Innstillinger lenker til «Tilgjengelighet». Lenken til sikkerhetsdokumentet
  heter «Sikkerhet (engelsk)»
- `.rtf`-filen sier at teksten er laget automatisk og kan inneholde feil
- Lisenser viser talermodellen som finner ut hvem som sa hva i et opptak

### Endret

- Fróði lagrer ikke stedet der en importert fil ble tatt opp, selv om filen
  oppgir det
- Når appen ber om tilgang til mikrofonen, står det at den tar opp notater og
  samtaler
- «Om opptaket» forklarer kort hva en sjekksum er, og at lydfilen du
  eksporterer, har sjekksummen for lyden
- Før du sletter et opptak, spør appen «Vil du slette opptaket?»
- Meldingene om mikrofontilgang og lange opptak er kortere
- En feilmelding i listen har selve feilen som overskrift, ikke «Noe gikk galt»
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

Den første versjonen i App Store.

### Lagt til

- Tar opp lyd så lenge du vil, også når skjermen er låst
- Handlingsknappen starter og stopper opptak, også når enheten er låst.
  Kontrollen finnes også i Kontrollsenter
- Låseskjermen og Dynamic Island viser at opptaket går, hvor lenge det har
  vart, og en stoppknapp
- Opptaket går ikke tapt ved en telefonsamtale eller hvis appen avsluttes
  midt i
- Importerer lydfiler fra Filer, for eksempel m4a, mp3 og wav
- Lager tekst på enheten med nb-whisper-small fra Nasjonalbiblioteket.
  Opptak på inntil ti minutter får tekst når du stopper, lengre opptak når du
  ber om det
- Deler teksten i avsnitt med tidspunkt du kan trykke på for å spille av
  derfra
- Ordliste i Innstillinger for navn og ord modellen kan bomme på
- Navn på opptak, og «Om opptaket» med dato, lengde og sjekksum
- Eksporterer lyd som `.m4a` og tekst som `.rtf` eller `.txt`
- Krypterer opptak, tekst og navn med en nøkkel som aldri forlater enheten
- Skjuler teksten ved skjermopptak og i appveksleren
- «Kopier» holder teksten på enheten, og teksten forsvinner fra
  utklippstavlen etter fem minutter
- Memory Integrity Enforcement, Apples minnebeskyttelse i maskinvaren, på
  iPhone 17 og nyere og på iPhone Air
