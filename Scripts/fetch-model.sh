#!/bin/bash
# Fetches nb-whisper-small as CoreML, and the Whisper tokenizer.
#
# The model is not in git; it is nearly half a gigabyte. Run this script once
# after cloning, before you build.
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

mkdir -p "$MODEL" "$TOKENIZER"
BASE="https://huggingface.co/Barrymanalow/nb-whisper-coreml/resolve/main/nb-whisper-small"

fetch() { # $1 = relativ sti under modellmappen
  local target="$MODEL/$1"
  mkdir -p "$(dirname "$target")"
  if [ -s "$target" ]; then echo "  har $1"; return; fi
  echo "  henter $1"
  curl -sL --fail "$BASE/$1" -o "$target"
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
TBASE="https://huggingface.co/openai/whisper-small/resolve/main"
for f in tokenizer.json tokenizer_config.json config.json special_tokens_map.json; do
  if [ -s "$TOKENIZER/$f" ]; then echo "  har $f"; continue; fi
  echo "  henter $f"
  curl -sL --fail "$TBASE/$f" -o "$TOKENIZER/$f"
done

echo
echo "Ferdig. Størrelse:"
du -sh "$DEST"
