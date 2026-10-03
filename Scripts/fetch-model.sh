#!/bin/bash
# Gets nb-whisper-small CoreML, the Whisper tokenizer and the speaker model; run once after cloning (not in git, ~0.5 GB).
# Pinned revisions, checked against Scripts/model-checksums.txt: CoreML runs in-process, so bundle only reviewed files.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Frodi/Resources/Model"
MODEL="$DEST/nb-whisper-small"
# WhisperKit requires exactly this structure under the tokenizer folder.
TOKENIZER="$DEST/tokenizer/models/openai/whisper-small"
# SpeakerKit derives these subfolders from its model names, versions and variants.
SPEAKERS="$DEST/speakerkit"
CHECKSUMS="$ROOT/Scripts/model-checksums.txt"

# Commit ids on Hugging Face; the checksum list belongs to these three. To change one: empty Frodi/Resources/Model, run this
# script (it stops at the checksums), review the new files, then regenerate the list:
# (cd Frodi/Resources/Model && find . -type f | sort | xargs shasum -a 256) > Scripts/model-checksums.txt
MODEL_REVISION="cd3550b23ae5c90a37614c842656125d4676229e"
TOKENIZER_REVISION="973afd24965f72e36ca33b3055d56a652f456b4d"
SPEAKERS_REVISION="556fc52a13327837688f02289457cded017802e9"

BASE="https://huggingface.co/Barrymanalow/nb-whisper-coreml/resolve/$MODEL_REVISION/nb-whisper-small"
TBASE="https://huggingface.co/openai/whisper-small/resolve/$TOKENIZER_REVISION"
SBASE="https://huggingface.co/argmaxinc/speakerkit-coreml/resolve/$SPEAKERS_REVISION"

mkdir -p "$MODEL" "$TOKENIZER"

download() { # $1 = URL, $2 = target file
  mkdir -p "$(dirname "$2")"
  curl -sSL --fail --proto '=https' "$1" -o "$2"
}

fetch() { # $1 = relative path under the model folder
  local target="$MODEL/$1"
  if [ -s "$target" ]; then echo "  har $1"; return; fi
  echo "  henter $1"
  download "$BASE/$1" "$target"
}

echo "CoreML-modell:"
for part in AudioEncoder MelSpectrogram TextDecoder; do
  fetch "$part.mlmodelc/coremldata.bin"
  fetch "$part.mlmodelc/metadata.json"
  fetch "$part.mlmodelc/model.mil"
  fetch "$part.mlmodelc/analytics/coremldata.bin"
  fetch "$part.mlmodelc/weights/weight.bin"
done
fetch "config.json"
fetch "generation_config.json"

echo "Tokenizer:"
for f in tokenizer.json tokenizer_config.json config.json special_tokens_map.json; do
  if [ -s "$TOKENIZER/$f" ]; then echo "  har $f"; continue; fi
  echo "  henter $f"
  download "$TBASE/$f" "$TOKENIZER/$f"
done

echo "Talermodell:"
for part in \
  speaker_segmenter/pyannote-v3/W8A16/SpeakerSegmenter \
  speaker_embedder/pyannote-v3/W8A16/SpeakerEmbedderPreprocessor \
  speaker_embedder/pyannote-v3/W8A16/SpeakerEmbedder \
  speaker_clusterer/pyannote-v4/W32A32/PldaProjector; do
  for f in coremldata.bin metadata.json model.mil analytics/coremldata.bin weights/weight.bin; do
    target="$SPEAKERS/$part.mlmodelc/$f"
    if [ -s "$target" ]; then echo "  har $part/$f"; continue; fi
    echo "  henter $part/$f"
    download "$SBASE/$part.mlmodelc/$f" "$target"
  done
done

echo "Sjekksummer:"
if (cd "$DEST" && shasum -a 256 --check --quiet "$CHECKSUMS"); then
  echo "  alle filer stemmer med Scripts/model-checksums.txt"
else
  echo "  FEIL: minst én fil stemmer ikke med Scripts/model-checksums.txt." >&2
  echo "  Ikke bygg med denne modellen før avviket er forklart." >&2
  exit 1
fi

echo
echo "Ferdig. Størrelse:"
du -sh "$DEST"
