# Tredjepartslisenser

Oppdatert 13. september 2026.

Listen i appen, under Info > Lisenser, har de samme navnene og lisensene som
denne filen. Versjonene under Kode er de `Package.resolved` løser opp. En test
i `FrodiTests/DocumentTests.swift` feiler hvis de tre skiller lag.

## Modell

| Hva | Opphav | Lisens | Lenke |
|---|---|---|---|
| nb-whisper-small | Nasjonalbiblioteket | Apache 2.0 | https://huggingface.co/NbAiLab/nb-whisper-small |
| CoreML-konvertering | Barrymanalow | Apache 2.0 | https://huggingface.co/Barrymanalow/nb-whisper-coreml |
| Tokenizer, whisper-small | OpenAI | Apache 2.0 | https://huggingface.co/openai/whisper-small |

Modellen og tokenizeren hentes fra faste revisjoner. Revisjonene står i
`Scripts/fetch-model.sh`, og sjekksummen for hver fil i
`Scripts/model-checksums.txt`.

## Kode

| Pakke | Opphav | Versjon | Lisens | Lenke |
|---|---|---|---|---|
| WhisperKit | Argmax | 0.18.0 | MIT | https://github.com/argmaxinc/whisperkit |
| swift-transformers | Hugging Face | 1.1.9 | Apache 2.0 | https://github.com/huggingface/swift-transformers |
| swift-jinja | Hugging Face | 2.4.2 | Apache 2.0 | https://github.com/huggingface/swift-jinja |
| swift-collections | Apple | 1.6.0 | Apache 2.0 | https://github.com/apple/swift-collections |
| swift-argument-parser | Apple | 1.8.2 | Apache 2.0 | https://github.com/apple/swift-argument-parser |
| swift-crypto | Apple | 4.5.2 | Apache 2.0 | https://github.com/apple/swift-crypto |
| swift-asn1 | Apple | 1.7.2 | Apache 2.0 | https://github.com/apple/swift-asn1 |
| yyjson | Yao Yuan | 0.12.0 | MIT | https://github.com/ibireme/yyjson |

## Ikoner

| Hva | Opphav | Lisens | Lenke |
|---|---|---|---|
| Heroicons | Tailwind Labs | MIT | https://heroicons.com |

## Fonter

| Font | Opphav | Lisens | Lenke |
|---|---|---|---|
| Skranji | Font Diner | SIL Open Font License 1.1 | https://fonts.google.com/specimen/Skranji |
| Inter | Rasmus Andersson | SIL Open Font License 1.1 | https://rsms.me/inter/ |
