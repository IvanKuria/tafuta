#!/usr/bin/env bash
# Fetch the MobileCLIP S0 Core ML models (image + text encoders) from Hugging Face.
# Models are large and not committed; run this once before building the app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="https://huggingface.co/apple/coreml-mobileclip/resolve/main"
DESTS=("$ROOT/models" "$ROOT/app/Resources/Models")

for m in mobileclip_s0_image mobileclip_s0_text; do
  for DEST in "${DESTS[@]}"; do
    pkg="$DEST/$m.mlpackage"
    mkdir -p "$pkg/Data/com.apple.CoreML/weights"
    echo "↓ $m → $DEST"
    curl -sL "$BASE/$m.mlpackage/Manifest.json" -o "$pkg/Manifest.json"
    curl -sL "$BASE/$m.mlpackage/Data/com.apple.CoreML/model.mlmodel" -o "$pkg/Data/com.apple.CoreML/model.mlmodel"
    curl -sL "$BASE/$m.mlpackage/Data/com.apple.CoreML/weights/weight.bin" -o "$pkg/Data/com.apple.CoreML/weights/weight.bin"
  done
done
echo "Done. Models in: ${DESTS[*]}"
