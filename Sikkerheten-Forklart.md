# Sikkerheten i Fróði røst, forklart

Sist oppdatert 9. september 2026.

Fróði tar opp lyd og lager tekst av den inne på enheten. Ingenting sendes,
og ingenting hentes. Dette dokumentet forklarer hva det betyr i praksis: hva
som beskytter opptakene dine, hvorfor appen er bygget slik, og hva den ikke
beskytter mot.

[PERSONVERN.md](PERSONVERN.md) sier hva som lagres og hvilke rettigheter du
har. [SECURITY.md](SECURITY.md) er den tekniske versjonen, på engelsk, for
den som vil lese koden eller melde en sårbarhet.

## Fire lag, ikke ett

Hvert lag dekker et hull det forrige lar stå åpent.

| Lag | Hva det gjør | Hva det ikke gjør |
|---|---|---|
| Sandkassen til appen | Ingen annen app kan lese mappen med opptak | Hjelper ikke hvis noen får tak i selve filene |
| Filbeskyttelse fra iOS | Filene er låst mens skjermen er låst | Gjelder bare på enheten, ikke i en kopi |
| Kryptering med egen nøkkel | En kopi som slipper ut, er uleselig | Hjelper ikke mens du selv har appen åpen |
| Ingen trafikk ut | Det finnes ingen forbindelse å avlytte | Hindrer ikke skjermbilder |

Krypteringen er den som bærer løftet. De tre andre gjør det vanskeligere å
komme dit, men bare krypteringen holder når alt annet svikter.

## Nøkkelen finnes bare inne i enheten din

Slik henger det sammen:

1. Hvert opptak får sin egen tilfeldige nøkkel, og lyden forsegles med
   AES-256-GCM.
2. Den nøkkelen pakkes inn av en nøkkel som lages inne i Secure Enclave –
   en egen brikke i enheten.
3. Nøkkelen i Enclave kan brukes, men aldri hentes ut. Heller ikke av appen
   selv, og heller ikke av deg.

Teksten fra opptaket forsegles på samme måte som lyden. Det er ikke overdrevet:
en transkripsjon er ofte mer avslørende enn lydfilen, fordi den er søkbar,
lesbar på et blikk og kan kopieres uten å spilles av. Å låse lyden og la
teksten ligge åpen ville vært å låse døren og la vinduet stå.

### To valg som er tatt med vilje

| Valg | Hvorfor |
|---|---|
| Nøkkelen er tilgjengelig etter første opplåsing, ikke bare mens enheten er ulåst | Handlingsknappen kan stoppe et opptak mens skjermen er låst. Da må nøkkelen virke, ellers går opptaket tapt i det du stopper det |
| Nøkkelen er bundet til denne enheten alene | Den blir ikke med i sikkerhetskopier og ikke over til en ny enhet |

## Mens opptaket går

Her trekker to hensyn i hver sin retning. Opptaket må kunne skrives mens
skjermen er låst – det er nettopp da du bruker appen i bil. Den ferdige filen
skal derimot ikke kunne leses mens skjermen er låst.

| Når | Beskyttelse |
|---|---|
| Opptaket går | Filen kan skrives videre etter at skjermen låser seg |
| Opptaket er ferdig | Filen er låst så lenge enheten er låst |
| Midlertidig klartekst under uttrekk | Slettes uansett hvordan jobben ender |

Klartekst finnes bare mens en jobb varer: mens teksten lages, mens du henter
ut et opptak, og mens du har opptaket åpent på skjermen.

## Hva som skjer hvis

| Situasjon | Resultat |
|---|---|
| Du mister enheten, og den er låst | Lyd og tekst kan ikke leses |
| Noen kopierer sikkerhetskopien din, eller gjenoppretter den på en ny enhet | Uleselig. Nøkkelen ble igjen på den gamle enheten |
| En annen app får lest i mappen til Fróði | Finner forseglede filer den ikke kan åpne |
| Noen avlytter nettverket | Det er ingenting å avlytte |
| Skjermen tas opp eller speiles mens teksten er åpen | Teksten skjules til opptaket stopper |
| Noen tar et skjermbilde | Bildet blir tatt. iOS gir ingen støttet måte å hindre det |
| Enheten er ulåst og appen åpen i andres hender | Da leser de det som står der, som i alle andre apper |

## Prisen: opptakene er låst til denne enheten

Dette er ikke en bivirkning. Det er selve garantien, sett fra den andre siden.
Nøkkelen ligger i denne enheten, så opptakene kan ikke leses av noen annen –
heller ikke av deg på en ny enhet, og heller ikke fra en sikkerhetskopi.

Derfor finnes uttrekk. Trykk på delingsikonet, så låser appen opp opptaket der
og da og gir deg `.m4a` og `.txt`. Filene går til Filer eller AirDrop, som
begge holder seg lokalt, og klarteksten slettes etterpå.

**Skal du bytte enhet: Hent ut opptakene først.** Etterpå er det for sent.

## Hva appen ikke beskytter mot

Vi lover ikke noe appen ikke kan holde.

- **Skjermbilder.** iOS varsler først etter at bildet er tatt. Trikset med et
  skjult passordfelt er udokumentert og kan slutte å virke uten varsel, så
  appen later ikke som om den stopper skjermbilder. Skjermopptak og speiling
  er noe annet: de varer over tid, og iOS sier fra mens det skjer. Da skjuler
  appen teksten.
- **En ulåst enhet du gir fra deg.** Det finnes ingen kodelås inne i appen.
  Fróði brukes med hendene opptatt, i bil, og en Face ID-sperre i det du
  trykker på opptak ville tatt bort hele poenget.
- **Nettverkskode som ligger i binærfilen.** Fróði bruker WhisperKit, som
  bygger på `swift-transformers`, og der finnes en HTTP-klient. Ingenting i
  Fróði kaller den: modellen og tokeniseringen leses fra appen selv, og
  nedlasting er slått av, så en fil som mangler gir en feil i stedet for et
  nettverkskall. Den presise påstanden er «appen gjør ingen nettverkskall»,
  ikke «binærfilen inneholder ingen nettverkskode». Den andre ville vært
  sterkere, og den er ikke sann.

## Talegjenkjenning skjer inne i appen

Teksten lages av en modell som ligger i appen, ikke av tjenesten iOS bruker
til diktering. Det er derfor appen bare ber om tilgang til mikrofonen, og
aldri viser Apples dialog om at taledata sendes til Apple. Den dialogen er
systemets egen tekst, og den kan ikke endres – så den eneste måten å slippe
den på, er å la være å bruke det API-et.

## Slik holdes det på plass

Løfter i et dokument ryker stille. Disse er skrevet som tester, og bygget
feiler hvis noen av dem slutter å holde:

| Test | Hva den passer på |
|---|---|
| Forseglingen holder | Klarteksten finnes ikke i den forseglede filen, lik inndata gir ulikt chiffer, og tuklet innhold blir avvist |
| Ingen unntak fra transportsikkerhet | Ingen kan åpne for usikret trafikk uten at det synes |
| Bare lyd kjører i bakgrunnen | Ingen andre bakgrunnsmoduser sniker seg inn |
| Personvernmanifestet erklærer ingen innsamling | Manifestet og virkeligheten sier det samme |
| Opptaksmappen er holdt utenfor sikkerhetskopi | Flagget blir satt på nytt, også på mapper laget av eldre versjoner |
| Appen ber ikke om talegjenkjenning | Nøkkelen som utløser Apples dialog, kommer ikke inn igjen |

## Spørsmål

**hei@tazk.no**
