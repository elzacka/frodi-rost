# Endringer

Formatet følger [Keep a Changelog](https://keepachangelog.com/no/1.1.0/).

## [Ikke utgitt]

### Endret
- Tale til tekst bruker nå nb-whisper fra Nasjonalbiblioteket, kjørt inne i
  appen. Tegnsetting, store bokstaver og dialekt håndteres langt bedre, og
  lyden forlater aldri appens eget område
- Opptakene krypteres med en nøkkel som aldri forlater telefonen. Du kan hente
  ut lyd og tekst når du vil, men bare fra denne enheten
- Listen viser dato, tidspunkt og lengde på én linje, delt med en loddrett
  strek. Pillen «Startet med handlingsknappen» er borte
- Detaljsiden har ikke lenger overskriften «OPPTAK» og egen linje for lengde.
  Begge deler står nå i tittellinjen, slik at teksten får hele kortet
- Tale til tekst går nå gjennom SpeechAnalyzer i stedet for den eldre
  talegjenkjenningen. Appen ber ikke lenger om tilgang til talegjenkjenning,
  og viser ikke lenger Apples melding om at taledata sendes til dem

### Lagt til
- Norsk tale til tekst, bekreftet på enhet
- Handlingsknappen starter og stopper opptak
- Banner som sier fra når den norske språkmodellen mangler, med nedlasting
- Mulighet for å prøve transkriberingen på nytt
- Opptak uten tekst blir forsøkt på nytt når språkmodellen er på plass
- Lydopptak med bakgrunnsstøtte, slik at opptaket fortsetter med skjermen av
- Tale til tekst på enheten, låst til norsk bokmål
- App Intent for handlingsknappen, med talekommandoer i Snarveier
- Liste over opptak med sletting
