# Brukerveiledning for Fróði røst

Oppdatert 19.09.26.

Fróði røst tar opp lyd og gjør den om til norsk tekst. Alt skjer på enheten.
Denne veiledningen viser hvordan du bruker appen.

**Innhold**

- [Ta opp](#ta-opp)
- [Handlingsknappen](#handlingsknappen)
- [Teksten](#teksten)
  - [Snarveien «Lag tekst i Fróði røst»](#snarveien-lag-tekst-i-fróði-røst)
  - [Slik lages teksten](#slik-lages-teksten)
  - [Hvis teksten mangler](#hvis-teksten-mangler)
- [Ordliste](#ordliste)
- [Spille av](#spille-av)
- [Kopiere teksten](#kopiere-teksten)
- [Eksportere](#eksportere)
- [Slette](#slette)
- [Personvern](#personvern)
- [Spørsmål eller feil](#spørsmål-eller-feil)

---

## Ta opp

Trykk på opptaksknappen nederst på skjermen. Trykk igjen for å stoppe.
Tidtakeren over knappen viser hvor lenge opptaket har vart.

Opptaket fortsetter når skjermen låser seg og når du bytter app.

Opptak har ingen tidsgrense.

Blir du oppringt mens du tar opp, settes opptaket på pause og fortsetter når
samtalen er over. Hvis ikke, er alt fram til samtalen lagret.

> **Viktig:** Tar du opp en samtale, må du si fra til de andre at du tar den
> opp, og hva du skal bruke opptaket til.

## Handlingsknappen

Knappen på venstre side av enheten kan starte og stoppe opptak. Den finnes på
iPhone 15 Pro og nyere.

Sett den opp først, i Innstillinger på enheten: Handlingsknapp > Snarvei >
Bla ned og velg «Fróði røst – Start eller stopp opptak».

Hold knappen inne for å starte et opptak. Hold den inne igjen for å stoppe.

| Enheten er | Starte | Stoppe |
|---|---|---|
| Låst opp | Starter med en gang | Stopper med en gang |
| Låst | Enheten må låses opp først. Har du Face ID, skjer det automatisk når kameraet ser deg | Stopper uten å låse opp |

## Teksten

Hvor lenge opptaket varer, avgjør når teksten lages:

| Opptaket varer | Teksten |
|---|---|
| Inntil 10 minutter | Lages når du stopper |
| Over 10 minutter | Lages når du ber om det |

Lange opptak står som «ingen tekst ennå» i listen. Åpne opptaket og trykk på
«Lag tekst», eller hold fingeren på opptaket i listen og velg «Lag tekst».

Appen viser i prosent hvor mye av teksten som er laget. Blir transkriberingen
avbrutt, fortsetter den der den slapp.

Teksten lages mens appen er åpen, eller mens enheten lader med skjermen låst.

Omtrent så lang tid tar det:

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
på enheten. Den er trent på 66 000 timer norsk tale, setter tegn og store
bokstaver selv og skriver dialekt om til bokmål.

> **Tips:** Du trenger ikke si «punktum» eller «komma».

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

Modellen henter listen før den lytter. Etterpå retter appen ord i teksten som
nesten stemmer med et ord i listen. Ord på under fire bokstaver og tall rettes
ikke.

> **Tips:** Endrer du listen etter at teksten er laget: Hold fingeren på
> opptaket i listen og velg «Lag teksten på nytt».

## Spille av

Åpne et opptak i listen. Spilleren har spill av, pause og to knapper som
hopper ti sekunder tilbake eller fram. Skyveknappen viser hvor du er i
opptaket.

## Kopiere teksten

Trykk på «Kopier» over teksten. Hele teksten kopieres, så du kan lime den inn
i en annen app. Teksten blir på enheten og forsvinner fra utklippstavlen
etter fem minutter.

## Eksportere

Trykk på delingsikonet øverst til høyre på opptakets side. Har opptaket tekst,
velger du «Opptak og tekst», «Bare opptaket» eller «Bare teksten». Deretter
kommer delingsmenyen i iOS, der du velger hvor filene skal sendes eller lagres.

Lyden eksporteres alltid som `.m4a`. Formatet for teksten velger du én gang,
under Innstillinger i appen:

| Format | Passer til |
|---|---|
| `.rtf` | Åpnes som dokument i Word, Pages og Notater. Har overskrift, dato og tidspunkt for hvert avsnitt |
| `.txt` | Ren tekst som kan limes inn hvor som helst |

> **Viktig:** Skal du bytte enhet: Eksporter opptakene først. Opptakene er
> låst til enheten og kan ikke leses av en annen, heller ikke fra en
> sikkerhetskopi.

## Slette

Hold fingeren på opptaket i listen og velg «Slett». Appen spør før den sletter.
Opptaket og teksten blir borte fra enheten, og du kan ikke angre.

> **Viktig:** Sletter du appen, forsvinner alt.

## Personvern

Alt skjer på enheten. Ingen datatrafikk ut eller inn. Opptak, tekst og
ordliste er kryptert, og blir ikke med i sikkerhetskopier. Appen ber bare om
tilgang til mikrofonen.

Hele personvernerklæringen: [PERSONVERN.md](PERSONVERN.md).

## Spørsmål eller feil

Skriv til **hei@tazk.no**.

---

[Til toppen](#brukerveiledning-for-fróði-røst)
