# Brukerveiledning for Fróði røst

Oppdatert 28.09.26.

Fróði røst tar opp lyd og gjør den om til norsk tekst. Alt skjer på enheten.
Denne veiledningen viser hvordan du bruker appen.

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

Har du sagt nei til mikrofonen, trykker du på «Åpne Innstillinger» under
meldingen i appen og slår på Mikrofon der.

Opptaket fortsetter når skjermen låser seg og når du bytter app.

Opptak har ingen tidsgrense.

Tar en samtale, Siri eller en annen app mikrofonen, setter appen opptaket på
pause. Opptaket fortsetter av seg selv når mikrofonen er ledig igjen. Får ikke
appen mikrofonen tilbake, lagrer den det du har tatt opp.

> **Viktig:** Før du tar opp en samtale der andre er til stede, må du si fra
> at du tar opp, fortelle hva opptaket skal brukes til og få samtykke fra dem.

## Importere en lydfil

Har du tatt opp med en annen app eller en annen opptaker, kan Fróði lage tekst
av lyden.

1. Trykk på «Importer lydfil», ikonet med lydbølger og pluss øverst til
   venstre.
2. Velg én eller flere lydfiler og trykk på «Åpne».

Fróði leser m4a, mp3, wav, aiff og de andre lydformatene iOS kan lese. Er
lyden i stereo, tar appen med begge kanalene.

Appen lagrer lyden i samme format som opptakene sine, i mono og med den
lydkvaliteten appen tar opp i, og krypterer den. Det holder godt for tale,
men kan være dårligere enn originalen. Originalen blir liggende der den var,
og appen endrer den ikke. Trenger du lyden i full kvalitet, må du ta vare på
originalen.

Opptaket får filnavnet som navn. Er datoen i filen fra år 2000 eller senere,
og ikke mer enn et døgn frem i tid, får opptaket den datoen. Ellers får det
tidspunktet du importerte det.

Teksten lages etter samme regel som for opptak du tar i appen. Se
[Teksten](#teksten).

Ligger filen i iCloud Drive, laster iOS den ned før Fróði får den. Kan ikke
Fróði lese filen, sier appen fra. Filen kan være skadet eller i et format
appen ikke kan lese.

> **Tips:** Opptak fra Taleopptak ligger ikke i Filer. Del opptaket fra
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

Er appen åpen når du starter et opptak, setter iOS musikk og annen lyd på
pause til du er ferdig. Starter du opptaket med knappen mens appen ikke er
åpen, fortsetter lyden, men lavere, til du stopper opptaket.

> **Tips:** Kontrollen finnes også i Kontrollsenter, der du kan legge den til
> selv.

## Teksten

Hvor lenge opptaket varer, avgjør når teksten lages. Det gjelder også lydfiler
du importerer:

| Opptaket&nbsp;varer | Teksten                 |
| ------------------- | ----------------------- |
| Inntil 10 minutter  | Lages når du stopper    |
| Over 10 minutter    | Lages når du ber om det |

Lange opptak står som «ingen tekst ennå» i listen. Sveip opptaket mot venstre
og trykk på «Lag tekst», eller åpne opptaket og trykk der.

Appen viser i prosent hvor langt den har kommet. Blir den avbrutt, fortsetter
den der den slapp.

Teksten lages mens appen er åpen. Skjermen holder seg på så lenge det pågår.
Låser du enheten, stopper appen og fortsetter når du åpner den igjen.

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
Innstillinger i appen, skilt med komma. Blir listen lang, drar du i håndtaket
nederst til høyre i feltet for å gjøre det høyere.

Modellen henter listen før den lytter. Etterpå retter appen ord i teksten som
nesten stemmer med et ord i listen. Ord på under fire bokstaver og tall rettes
ikke. Bøyde former rettes heller ikke, så «internkontrollen» blir stående når
listen har «internkontroll».

> **Tips:** Endrer du listen etter at teksten er laget: Sveip opptaket i
> listen mot venstre og trykk på «Lag ny tekst».

## Spille av

Åpne et opptak i listen. Spilleren har spill av, pause og to knapper som
hopper ti sekunder tilbake eller frem. Skyveknappen viser hvor du er i
opptaket.

## Gi opptaket et navn

Åpne opptaket og trykk på tittelen øverst. Velg «Endre navn», skriv navnet og
trykk på «Lagre». Navnet står over datoen i listen, og som overskrift når du
eksporterer teksten som `.rtf`.

Tømmer du feltet, fjerner du navnet, og listen viser datoen igjen.

Et nytt navn endrer ikke det som står under «Om opptaket». For en importert
fil står filnavnet til originalen der, og i `.rtf`-filen du eksporterer.

## Om opptaket

Nederst på opptakets side står «Om opptaket». Trykk på det for å se
opplysningene Fróði låste da opptaket kom inn i appen:

| Opptaket&nbsp;er | Opplysningene                                                                                                                                     |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tatt opp i appen | Når det ble tatt opp, hvor langt det er, og sjekksum for lyden                                                                                    |
| Importert        | Når det ble importert, filnavn, format, størrelse, lengde, datoen og andre opplysninger som stod i filen, og sjekksum for originalen og for lyden |

Du kan gi opptaket et nytt navn, men du kan ikke endre disse opplysningene.
Er datoen eller lengden endret utenfor appen, eller stemmer ikke lyden med
sjekksummen, står det «Fróði kan ikke bekrefte opplysningene om dette
opptaket.» Under står opplysningene slik de ble låst, hvis Fróði kan lese
dem.

Har et opptak ikke «Om opptaket», ble det laget med en eldre versjon av
appen, eller appen stoppet i det øyeblikket opptaket ble lagret.

En sjekksum er et fingeravtrykk av en fil. To like filer har samme sjekksum.
På en Mac finner du sjekksummen til en fil med kommandoen
`shasum -a 256 filnavn` i Terminal. Stemmer den med sjekksummen for
originalen, er filen den samme som du importerte.

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

| Format | Passer&nbsp;til                                                                                  |
| ------ | ------------------------------------------------------------------------------------------------ |
| `.rtf` | Åpnes som dokument i Word, Pages og Notater. Har overskrift, dato, sjekksum for lydfilen og tidspunkt for hvert avsnitt. For en importert fil står også filnavnet og sjekksummen til originalen |
| `.txt` | Ren tekst som kan limes inn hvor som helst                                                       |

> **Tips:** Sjekksummen i `.rtf`-filen viser hvilken lydfil teksten hører
> til. Den som får begge filene, kan sjekke at lyden er den samme som ble
> lagret i Fróði.

> **Viktig:** Skal du bytte enhet: Eksporter opptakene først. Opptakene er
> låst til enheten og kan ikke leses av en annen, heller ikke fra en
> sikkerhetskopi.

## Slette

Sveip opptaket i listen mot venstre og trykk på «Slett». Appen spør «Sikker på
at du vil slette?» i samme rad. Trykk på «Slett» igjen, eller på «Behold».
Sletter du, er opptaket og teksten borte fra enheten, og du kan ikke angre.

> **Viktig:** Sletter du appen, forsvinner alt.

## Personvern

Alt skjer på enheten. Ingen datatrafikk ut eller inn. Hva som lagres, og
rettighetene dine: [PERSONVERN.md](PERSONVERN.md).

## Spørsmål eller feil

Skriv til **hei@tazk.no**.

---

[Til toppen](#brukerveiledning-for-fróði-røst)
