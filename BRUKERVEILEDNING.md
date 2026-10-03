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
over mikrofonen. Opptaket fortsetter av seg selv når mikrofonen er ledig igjen.
Appen lagrer det du har tatt opp, også hvis den ikke får mikrofonen tilbake.

> **Viktig:** Før du tar opp en samtale der andre er til stede, må du si fra
> at du tar opp, fortelle hva opptaket skal brukes til og få samtykke fra dem.

## Importere en lydfil

Fróði kan lage tekst av lydfiler med norsk tale, uansett hvilken app eller
opptaker de kommer fra:

1. Trykk på «Importer lydfil», ikonet med lydbølger og pluss øverst til
   venstre.
2. Velg én eller flere lydfiler og trykk på «Åpne».

> **Obs:** Resultatet avhenger av hvor lett det er å høre hva som blir sagt. En
> podkastepisode gir en mer presis tekst enn for eksempel et YouTube-klipp der
> flere snakker i munnen på hverandre.

Fróði leser m4a, mp3, wav, aiff og de andre lydformatene iOS kan lese. Appen
tar med begge kanalene hvis lyden er i stereo.

Appen lagrer lyden i mono, i samme kvalitet som egne opptak. Det holder godt
for tale, men kan være dårligere enn originalen. Ta vare på originalen hvis
du trenger lyden i full kvalitet.

Opptaket får filnavnet som navn. Det får datoen i filen hvis den er fra år
2000 eller senere og ikke mer enn et døgn frem i tid. Ellers får det
tidspunktet du importerte det.

Teksten lages etter samme regel som for opptak du tar i appen. Se
[Teksten](#teksten).

Appen sier fra hvis den ikke kan lese filen. Filen kan være skadet eller i et
format appen ikke kan lese.

> **Obs:** Opptak fra Taleopptak ligger ikke i Filer. Del opptaket fra
> Taleopptak til Filer først, så kan du importere det.

## Handlingsknappen

Knappen på venstre side av enheten starter og stopper opptak. Den finnes på
iPhone 15 Pro og nyere.

Ta det første opptaket i appen, så du får gitt tilgang til mikrofonen.
Sett så opp knappen i Innstillinger på enheten: Handlingsknapp > Kontroll >
Velg en kontroll > Fróði røst > «Start eller stopp opptak».

Hold knappen inne for å starte et opptak. Hold den inne igjen for å stoppe.
Det virker også når enheten er låst, uten at du låser den opp.

Så lenge opptaket går, viser låseskjermen og Dynamic Island «Tar opp», hvor
lenge det har vart og en stoppknapp. Første gang spør iOS «Vil du tillate
løpende oppdateringer fra Fróði røst?». Svar «Tillat»; uten det stopper iOS
opptak som handlingsknappen starter.

Hvis appen er åpen når du starter et opptak, setter iOS musikk og annen lyd
på pause til du er ferdig. Hvis du starter opptaket med knappen mens appen
ikke er åpen, fortsetter lyden, men lavere, til du stopper opptaket.

> **Tips:** Kontrollen finnes også i Kontrollsenter, der du kan legge den til
> selv.

## Teksten

Hvor lenge opptaket varer, avgjør når teksten lages:

| Opptaket&nbsp;varer | Teksten                 |
| ------------------- | ----------------------- |
| Inntil 10 minutter  | Lages når du stopper    |
| Over 10 minutter    | Lages når du ber om det |

Lange opptak står som «ingen tekst ennå» i listen. Sveip opptaket mot venstre
og trykk på «Lag tekst», eller åpne opptaket og trykk der.

Appen viser i prosent hvor langt den har kommet. Den fortsetter der den
slapp hvis noe avbryter den.

Teksten lages mens appen er åpen. Skjermen holder seg på så lenge det pågår.
Appen stopper hvis du låser enheten, og fortsetter når du åpner den igjen.

Omtrent så lang tid tar det:

| Opptak      | Tid             |
| ----------- | --------------- |
| 10 minutter | Under ett minutt |
| 30 minutter | 1–2 minutter    |
| 60 minutter | 2–4 minutter    |

### Slik lages teksten

Modellen nb-whisper-small fra Nasjonalbiblioteket er innebygd i appen og
kjører på enheten. Den setter tegn og store bokstaver selv og skriver dialekt
om til bokmål.

> **Tips:** Du trenger ikke si «punktum» eller «komma».

Teksten deles i avsnitt. Hvert avsnitt har et tidspunkt. Trykk på tidspunktet
for å spille av lyden derfra.

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
Innstillinger i appen, skilt med komma. Du gjør feltet høyere ved å dra i
håndtaket nederst til høyre.

Modellen henter listen før den lytter. Etterpå retter appen ord i teksten som
nesten stemmer med et ord i listen. Ord på under fire bokstaver og tall rettes
ikke. Bøyde former rettes heller ikke, så «internkontrollen» blir stående når
listen har «internkontroll».

> **Tips:** Hvis du endrer listen etter at teksten er laget, sveiper du
> opptaket i listen mot venstre og trykker på «Lag ny tekst».

## Spille av

Åpne et opptak i listen. Spilleren har spill av, pause og to knapper som
hopper ti sekunder tilbake eller frem. Skyveknappen viser hvor du er i
opptaket.

## Gi opptaket et navn

Åpne opptaket og trykk på tittelen øverst. Velg «Endre navn», skriv navnet og
trykk på «Lagre». Navnet står over datoen i listen, og som overskrift når du
eksporterer teksten som `.rtf`.

Tøm feltet for å fjerne navnet. Da viser listen datoen igjen.

Et nytt navn endrer ikke det som står under «Om opptaket».

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

Et opptak uten «Om opptaket» ble laget med en eldre versjon av appen, eller
appen stoppet i det øyeblikket opptaket ble lagret.

En sjekksum er en rekke tall og bokstaver som regnes ut fra innholdet i en
fil. To like filer har samme sjekksum, og sjekksummen blir en annen hvis noen
endrer filen. På en Mac finner du sjekksummen til en fil med kommandoen
`shasum -a 256 filnavn` i Terminal. Filen er den samme som du importerte hvis
den har samme sjekksum som originalen.

## Kopiere teksten

Trykk på «Kopier» over teksten. Hele teksten kopieres, så du kan lime den inn
i en annen app innen fem minutter.

## Eksportere

Trykk på delingsikonet øverst til høyre på opptakets side. Hvis opptaket har
tekst, velger du «Opptak og tekst», «Bare opptaket» eller «Bare teksten». Deretter
kommer delingsmenyen i iOS, der du velger hvor filene skal sendes eller lagres.

Lyden eksporteres alltid som `.m4a`. Formatet for teksten velger du én gang,
under Innstillinger i appen:

| Format | Passer&nbsp;til                                                                                  |
| ------ | ------------------------------------------------------------------------------------------------ |
| `.rtf` | Åpnes som dokument i Word, Pages og Notater. Har overskrift, dato, sjekksum for lydfilen og tidspunkt for hvert avsnitt. For en importert fil står også filnavnet og sjekksummen til originalen |
| `.txt` | Ren tekst som kan limes inn hvor som helst                                                       |

> **Tips:** Den som får både `.rtf`-filen og lydfilen, kan sjekke med
> sjekksummen at lyden er den samme som ble lagret i Fróði.

> **Viktig:** Eksporter opptakene før du bytter enhet. En annen enhet kan
> ikke lese dem, heller ikke fra en sikkerhetskopi.

## Slette

Sveip opptaket i listen mot venstre og trykk på «Slett». Appen spør «Sikker på
at du vil slette?» i samme rad. Trykk på «Slett» igjen, eller på «Behold».
Da er opptaket og teksten borte fra enheten, og du kan ikke angre.

> **Viktig:** Alt forsvinner hvis du sletter appen.

## Personvern

Hva som lagres, og rettighetene dine: [PERSONVERN.md](PERSONVERN.md).

## Spørsmål eller feil

Skriv til **hei@tazk.no**.

---

[Til toppen](#brukerveiledning-for-fróði-røst)
