# Brukerveiledning for Fróði røst

Oppdatert 19. september 2026.

Fróði røst tar opp lyd og gjør den om til norsk tekst. Alt skjer på enheten.
Denne veiledningen viser hvordan du bruker appen.

## Ta opp

Trykk på opptaksknappen nederst på skjermen. Trykk igjen for å stoppe.
Tidtakeren over knappen viser hvor lenge opptaket har vart.

Opptaket fortsetter når skjermen låser seg og når du bytter app.

Det er ingen tidsgrense. Et opptak kan vare så lenge du vil.

Ringer noen mens du tar opp, blir opptaket satt på pause. Når samtalen er
over, fortsetter det. Fortsetter det ikke, er det du har tatt opp fram til
samtalen lagret.

Tar du opp et intervju, er det du som må fortelle den du intervjuer at det
blir tatt opp, og hva opptaket skal brukes til.

## Handlingsknappen

Knappen på venstre side av enheten kan starte og stoppe opptak. Den finnes på
iPhone 15 Pro og nyere.

Sett den opp først, i Innstillinger på enheten: Handlingsknapp > Snarvei >
Bla ned og velg «Fróði røst – Start eller stopp opptak».

Hold knappen inne for å starte et opptak. Hold den inne igjen for å stoppe.

| Enheten er | Starte | Stoppe |
|---|---|---|
| Låst opp | Starter med en gang | Stopper med en gang |
| Låst | Må låses opp først. Face ID gjør det uten at du merker det, hvis den ser deg | Stopper uten å låse opp |

## Teksten

Hvor lenge opptaket varer, avgjør når teksten lages:

| Opptaket varer | Teksten |
|---|---|
| Inntil 10 minutter | Lages når du stopper |
| Over 10 minutter | Lages når du ber om det |

For et langt opptak står det «ingen tekst ennå» i listen. Trykk på «Lag
tekst» på opptakets side, eller hold fingeren på opptaket i listen og velg
«Lag tekst» der.

Appen viser hvor langt den har kommet, i prosent. Blir den avbrutt, fortsetter
den der den slapp neste gang.

Teksten kan også lages mens enheten lader med skjermen låst. La appen være
åpen, eller sett enheten til lading.

Så lang tid tar det å lage teksten. Tallene er grove anslag:

| Opptak | Tid |
|---|---|
| 10 minutter | 4–5 minutter |
| 30 minutter | 11–13 minutter |
| 60 minutter | 22–27 minutter |

### Snarveien «Lag tekst i Fróði røst»

Snarveien lager teksten uten at appen er åpen, også for lange opptak. Legg den
i en automatisering i appen Snarveier, for eksempel når laderen kobles til.

### Slik lages teksten

Modellen nb-whisper-small fra Nasjonalbiblioteket følger med appen og kjører
inne i den. Den er videretrent på 66 000 timer norsk tale. Den setter tegn
og store bokstaver selv, og skriver om dialekt til bokmål. Du trenger ikke si
«punktum» eller «komma».

Teksten deles i avsnitt. Hvert avsnitt har et tidspunkt. Trykk på tidspunktet
for å spille av lyden derfra.

### Hvis teksten mangler

| Det står | Det betyr |
|---|---|
| «venter på transkribering» | Teksten er i kø og lages snart |
| «Fant ingen tale i dette opptaket.» | Opptaket er stille, eller lyden er for svak |
| «Teksten kunne ikke lages denne gangen.» | Noe gikk galt. Trykk på «Prøv på nytt» |

## Ordliste

Modellen kan bomme på navn og ord den ikke kjenner: Firmaer, personer,
steder, forkortelser og standarder. Skriv dem inn i ordlisten under
Innstillinger i appen, skilt med komma.

Modellen får listen før den lytter. Etterpå retter appen ord i teksten som
nesten stemmer med listen. Korte ord på under fire bokstaver og tall rettes
ikke.

Har du skrevet listen etter at teksten ble laget, holder du fingeren på
opptaket i listen og velger «Lag teksten på nytt».

## Spille av

Åpne et opptak i listen. Spilleren har spill av og pause, og to knapper som
hopper ti sekunder tilbake og fram. Skyveknappen viser hvor du er i opptaket.

## Kopiere teksten

Trykk på «Kopier» over teksten. Hele teksten kopieres, så du kan lime den inn
i en annen app. Den blir på denne enheten og forsvinner fra utklippstavlen
etter fem minutter.

## Eksportere

Trykk på delingsikonet øverst til høyre på opptakets side. Har opptaket tekst,
velger du «Opptak og tekst», «Bare opptaket» eller «Bare teksten». Deretter
kommer delingsmenyen i iOS, der du velger hvor filene skal.

Lyden eksporteres alltid som `.m4a`. Formatet for teksten velger du én gang,
under Innstillinger i appen:

| Format | Passer til |
|---|---|
| `.rtf` | Åpnes som dokument i Word, Pages og Notater. Har overskrift, dato og tidspunkt for hvert avsnitt |
| `.txt` | Ren tekst som kan limes inn hvor som helst |

Skal du bytte enhet: Eksporter opptakene først. Opptakene er låst til enheten
og kan ikke leses av en annen, heller ikke fra en sikkerhetskopi.

## Slette

Hold fingeren på opptaket i listen og velg «Slett». Appen spør før den sletter.
Opptaket og teksten blir borte fra enheten, og du kan ikke angre.

Sletter du appen, forsvinner alt.

## Personvern

Alt skjer på enheten. Ingen datatrafikk ut eller inn. Opptak, tekst og
ordliste er kryptert, og blir ikke med i sikkerhetskopier. Appen ber bare om
tilgang til mikrofonen.

Hele personvernerklæringen: [PERSONVERN.md](PERSONVERN.md).

## Spørsmål eller feil

**hei@tazk.no**
