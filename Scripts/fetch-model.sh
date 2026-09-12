#!/bin/bash
# Fetches nb-whisper-small as CoreML, and the Whisper tokenizer.
#
# The model is not in git; it is nearly half a gigabyte. Run this script once
# after cloning, before you build.
#
# Both repositories are fetched at a fixed revision, and every file is checked
# against Scripts/model-checksums.txt before the script reports success. A CoreML
# model is parsed by the system and runs inside the app's process, so what ends
# up in the bundle has to be exactly what was reviewed, not whatever the
# repository serves on the day.
#
# To move to a newer revision: change MODEL_REVISION or TOKENIZER_REVISION,
# delete Frodi/Resources/Model, run the script (it fetches, then fails on the
# checksums), review the new files, and regenerate the list with
#   (cd Frodi/Resources/Model && find . -type f | sort | xargs shasum -a 256) > Scripts/model-checksums.txt
#
# Sources:
# model:      https://huggingface.co/Barrymanalow/nb-whisper-coreml (apache-2.0)
# tokenizer:  https://huggingface.co/openai/whisper-small (apache-2.0)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Frodi/Resources/Model"
MODEL="$DEST/nb-whisper-small"
# WhisperKit requires exactly this structure under the tokenizer folder.
TOKENIZER="$DEST/tokenizer/models/openai/whisper-small"
CHECKSUMS="$ROOT/Scripts/model-checksums.txt"

# Commit ids on Hugging Face. The checksum list belongs to these two revisions.
MODEL_REVISION="cd3550b23ae5c90a37614c842656125d4676229e"
TOKENIZER_REVISION="973afd24965f72e36ca33b3055d56a652f456b4d"

BASE="https://huggingface.co/Barrymanalow/nb-whisper-coreml/resolve/$MODEL_REVISION/nb-whisper-small"
TBASE="https://huggingface.co/openai/whisper-small/resolve/$TOKENIZER_REVISION"

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
