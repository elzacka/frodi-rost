# Tredjepartslisenser

Oppdatert 20.09.26.

Listen i appen, under Innstillinger > Mer om appen > Lisenser, har de samme
navnene og lisensene som denne filen. Versjonene under Kode er de som står i
`Package.resolved`. En test i `FrodiTests/DocumentTests.swift` feiler hvis de
tre ikke stemmer overens.

## Modell

| Hva                      | Opphav              | Lisens     | Lenke                                                 |
| ------------------------ | ------------------- | ---------- | ----------------------------------------------------- |
| nb-whisper-small         | Nasjonalbiblioteket | Apache 2.0 | https://huggingface.co/NbAiLab/nb-whisper-small       |
| CoreML-konvertering      | Barrymanalow        | Apache 2.0 | https://huggingface.co/Barrymanalow/nb-whisper-coreml |
| Tokenizer, whisper-small | OpenAI              | Apache 2.0 | https://huggingface.co/openai/whisper-small           |

Modellen og tokenizeren hentes fra faste revisjoner. Revisjonene står i
`Scripts/fetch-model.sh`, og sjekksummen for hver fil i
`Scripts/model-checksums.txt`.

## Kode

| Pakke                 | Opphav | Versjon | Lisens     | Lenke                                          |
| --------------------- | ------ | ------- | ---------- | ---------------------------------------------- |
| argmax-oss-swift      | Argmax | 1.1.0   | MIT        | https://github.com/argmaxinc/argmax-oss-swift  |
| swift-argument-parser | Apple  | 1.8.2   | Apache 2.0 | https://github.com/apple/swift-argument-parser |

argmax-oss-swift er pakken WhisperKit ligger i. Den har med seg kode fra et
annet prosjekt, som ikke er en egen pakke, men som krever attribusjon på
samme måte:

| Hva                | Opphav       | Lisens     | Lenke                                             |
| ------------------ | ------------ | ---------- | ------------------------------------------------- |
| swift-transformers | Hugging Face | Apache 2.0 | https://github.com/huggingface/swift-transformers |

## Ikoner

| Hva              | Opphav | Lisens     | Lenke                          |
| ---------------- | ------ | ---------- | ------------------------------ |
| Material Symbols | Google | Apache 2.0 | https://fonts.google.com/icons |

## Fonter

| Font    | Opphav           | Lisens                    | Lenke                                     |
| ------- | ---------------- | ------------------------- | ----------------------------------------- |
| Skranji | Font Diner       | SIL Open Font License 1.1 | https://fonts.google.com/specimen/Skranji |
| Inter   | Rasmus Andersson | SIL Open Font License 1.1 | https://rsms.me/inter/                    |
