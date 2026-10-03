# Brukerveiledning for Fróði røst

Oppdatert 03.10.26.

Fróði røst tar opp lyd og gjør den om til norsk tekst. Alt skjer på enheten.

**Innhold**

- [Ta opp](#ta-opp)
- [Importere en lydfil](#importere-en-lydfil)
- [Handlingsknappen](#handlingsknappen)
- [Teksten](#teksten)
  - [Slik lages teksten](#slik-lages-teksten)
  - [Hvis teksten mangler](#hvis-teksten-mangler)
- [Ordliste](#ordliste)
- [Spille av](#spille-av)
- [Gi opptaket et navn](#gi-opptaket-et-navn)
- [Om opptaket](#om-opptaket)
- [Kopiere teksten](#kopiere-teksten)
- [Eksportere](#eksportere)
- [Slette](#slette)
- [Personvern](#personvern)
- [Spørsmål eller feil](#spørsmål-eller-feil)

---

## Ta opp

Trykk på opptaksknappen nederst på skjermen. Trykk igjen for å stoppe.
Tidtakeren til venstre for knappen viser hvor lenge opptaket har vart.

Hvis du har sagt nei til at appen skal få tilgang til mikrofonen, trykker du
på «Åpne Innstillinger» under meldingen i appen og slår på Mikrofon der.

Opptaket fortsetter når skjermen låser seg og når du bytter app, og det har
ingen tidsgrense.

Appen setter opptaket på pause hvis en samtale, Siri eller en annen app tar
over mikrofonen, og fortsetter når mikrofonen er ledig igjen. Det du har tatt
opp, går ikke tapt.

> **Viktig:** Det er lov å ta opp en samtale du selv er med i. Si likevel fra
> til de andre at du tar opp, og hva opptaket skal brukes til.
> Personvernreglene kan avgjøre hva du får gjøre med opptaket etterpå, for
> eksempel om du kan dele det.

## Importere en lydfil

1. Trykk på «Importer lydfil», ikonet med lydbølger og pluss øverst til
   venstre.
2. Velg én eller flere lydfiler og trykk på «Åpne».

Fróði leser m4a, mp3, wav, aiff og de andre lydformatene iOS kan lese. Appen
lagrer lyden i mono, med begge kanalene hvis lyden er i stereo, og i samme
kvalitet som egne opptak. Det holder godt for tale. Ta vare på originalen hvis
du trenger lyden i full kvalitet.

Teksten blir mest presis når det er lett å høre hva som blir sagt, og ingen
snakker i munnen på hverandre. Den lages etter samme regel som for andre
opptak, se [Teksten](#teksten).

Opptaket får filnavnet som navn og datoen som står i filen. Det får
tidspunktet du importerte det hvis filen ikke har en dato som kan stemme.

Opptak fra Taleopptak ligger ikke i Filer. Del opptaket fra Taleopptak og velg
«Lagre i Filer». Da kan du importere det.

## Handlingsknappen

Knappen på venstre side av enheten starter og stopper opptak. Den finnes på
iPhone 15 Pro og nyere.

Ta det første opptaket i appen. Da spør den om tilgang til mikrofonen.
Sett så opp knappen i Innstillinger på enheten: Handlingsknapp > Kontroll >
Velg en kontroll > Fróði røst > «Start eller stopp opptak». Du kan også legge
kontrollen til i Kontrollsenter.

Hold knappen inne for å starte et opptak. Hold den inne igjen for å stoppe.
Det virker også når enheten er låst.

Så lenge opptaket går, viser låseskjermen og Dynamic Island «Tar opp», hvor
lenge det har vart og en stoppknapp. Første gang spør iOS «Vil du tillate
løpende oppdateringer fra Fróði røst?». Svar «Tillat». Ellers stopper iOS
opptak som handlingsknappen starter.

Musikk og annen lyd tar pause mens du tar opp. Hvis du starter med knappen
mens appen ikke er åpen, fortsetter lyden, men lavere.

## Teksten

Hvor lenge opptaket varer, avgjør når teksten lages:

| Opptaket&nbsp;varer | Teksten                 |
| ------------------- | ----------------------- |
| Inntil 10 minutter  | Lages når du stopper    |
| Over 10 minutter    | Lages når du ber om det |

Lange opptak står som «ingen tekst ennå» i listen. Sveip opptaket mot venstre
og trykk på «Lag tekst» eller åpne opptaket og trykk der.

Appen viser i prosent hvor langt den har kommet. Den fortsetter der den
slapp hvis noe avbryter den.

Teksten lages mens appen er åpen. Skjermen slukker ikke så lenge det pågår.
Fróði tar pause hvis du låser enheten, og fortsetter når du åpner appen igjen.

Omtrent så lang tid tar det på iPhone 17 Pro. Eldre modeller bruker lengre
tid.

| Opptak      | Tid              |
| ----------- | ---------------- |
| 10 minutter | Under ett minutt |
| 30 minutter | 1–3 minutter     |
| 60 minutter | 3–5 minutter     |

### Slik lages teksten

Modellen nb-whisper-small fra Nasjonalbiblioteket er innebygd i appen og
kjører på enheten. Den setter tegn og store bokstaver selv, så du trenger ikke
si «punktum» eller «komma».

Teksten er ikke ordrett: Modellen skriver dialekt og muntlige former om til
bokmål, og den kan høre feil. Sjekk sitater mot lyden.

Teksten deles i avsnitt med tidspunkt. Trykk på tidspunktet for å spille av
lyden derfra.

### Hvis teksten mangler

| Det&nbsp;står                                 | Det&nbsp;betyr                              |
| --------------------------------------------- | ------------------------------------------- |
| «venter på tekst»                             | Teksten er i kø og lages snart              |
| «lager tekst, 43 %»                           | Så langt er appen kommet                    |
| «Fant ingen tale i dette opptaket.»           | Opptaket er stille, eller lyden er for svak |
| «Fróði fikk ikke laget teksten denne gangen.» | Noe gikk galt. Trykk på «Prøv på nytt»      |

I listen står de to siste kortere: «ingen tale» og «noe gikk galt».

## Ordliste

Modellen kan bomme på navn og ord den ikke kjenner: Firmaer, personer,
steder, forkortelser og standarder. Skriv dem inn i ordlisten under
Innstillinger i appen, skilt med komma. Dra i håndtaket nederst til høyre for
å gjøre feltet høyere.

Modellen får listen før den lytter, og appen retter etterpå ord som nesten
stemmer med et ord i listen. Ord på under fire bokstaver, tall og bøyde former
rettes ikke.

> **Tips:** Hvis du endrer listen etter at teksten er laget, sveiper du
> opptaket i listen mot venstre og trykker på «Lag ny tekst».

## Spille av

Åpne et opptak i listen. Spilleren har spill av, pause og to knapper som
hopper ti sekunder tilbake eller frem. Skyveknappen viser hvor du er i
opptaket.

## Gi opptaket et navn

Åpne opptaket og trykk på tittelen øverst. Velg «Endre navn», skriv navnet og
trykk på «Lagre». Navnet står over datoen i listen, og som overskrift når du
eksporterer teksten som `.rtf`. Tøm feltet for å fjerne navnet.

## Om opptaket

Nederst på opptakets side står «Om opptaket». Trykk på det for å se
opplysningene Fróði lagret da opptaket kom inn i appen:

| Opptaket&nbsp;er | Opplysningene                                                                                                                                     |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tatt opp i appen | Når det ble tatt opp, hvor langt det er, og sjekksum for lyden                                                                                    |
| Importert        | Når det ble importert, filnavn, format, størrelse, lengde, datoen og andre opplysninger som stod i filen, og sjekksum for originalen og for lyden |

Du kan ikke endre disse opplysningene. Appen viser en advarsel hvis datoen
eller lengden er endret utenfor appen, eller hvis lyden ikke stemmer med
sjekksummen: «Fróði kan ikke bekrefte opplysningene om dette opptaket.» Under
advarselen står opplysningene slik de ble lagret, hvis Fróði kan lese dem.

En sjekksum regnes ut fra innholdet i en fil og blir en annen hvis noen endrer
filen. Slik finner du sjekksummen til en fil:

| Maskin  | Kommando                                  |
| ------- | ----------------------------------------- |
| Mac     | `shasum -a 256 filnavn` i Terminal        |
| Windows | `Get-FileHash filnavn` i PowerShell       |

Filen er den samme som du importerte hvis den har samme sjekksum som
originalen. På samme måte kan den som får både `.rtf`-filen og lydfilen,
sjekke at lyden er den Fróði lagret.

## Kopiere teksten

Trykk på «Kopier» over teksten. Hele teksten kopieres, så du kan lime den inn
i en annen app innen fem minutter.

## Eksportere

Trykk på delingsikonet øverst til høyre på opptakets side. Hvis opptaket har
tekst, velger du «Opptak og tekst», «Bare opptaket» eller «Bare teksten».
Deretter velger du i delingsmenyen hvor filene skal sendes eller lagres.

Lyden eksporteres alltid som `.m4a`. Formatet for teksten velger du én gang,
under Innstillinger i appen:

| Format | Passer&nbsp;til                                                                                                                                                                                 |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.rtf` | Åpnes som dokument i Word, Pages og Notater. Har overskrift, dato, sjekksum for lydfilen og tidspunkt for hvert avsnitt. For en importert fil står også filnavnet og sjekksummen til originalen |
| `.txt` | Ren tekst som kan limes inn hvor som helst                                                                                                                                                      |

> **Viktig:** Eksporter opptakene før du bytter enhet. En annen enhet kan
> ikke lese dem, heller ikke fra en sikkerhetskopi.

## Slette

Sveip opptaket i listen mot venstre og trykk på «Slett». Appen spør «Vil du
slette opptaket?» i samme rad. Trykk på «Slett» igjen, eller på «Behold».
Da er opptaket og teksten borte fra enheten, og du kan ikke angre.

> **Viktig:** Alle opptak og all tekst forsvinner hvis du sletter appen.

## Personvern

Hva som lagres, og rettighetene dine: [PERSONVERN.md](PERSONVERN.md).

## Spørsmål eller feil

Skriv til **hei@tazk.no**.
