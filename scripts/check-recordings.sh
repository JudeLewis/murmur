#!/bin/zsh
# Compares the speech models on Jude's kept recordings (SPEC.md 3.5): each recording through
# Tidy (Bark 3.0 Clean) and Ultra, next to what the model heard at the time. Needs "Keep
# recordings for testing" ticked in Murmur's Settings. The words stay on this Mac: never paste
# this output into the repo (it's public).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build --product Murmur >/dev/null
FOLDER="$HOME/Library/Application Support/Murmur/Recordings"
if [[ ! -d "$FOLDER" ]] || [[ -z "$(ls "$FOLDER"/*.wav 2>/dev/null)" ]]; then
  echo "No kept recordings. Tick Settings, Keep recordings for testing, then dictate as usual."
  exit 0
fi
for wav in "$FOLDER"/*.wav; do
  name="$(basename "$wav" .wav)"
  echo "== $name"
  [[ -f "$FOLDER/$name.json" ]] && echo "At the time: $(/usr/bin/python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["model"]+": "+d["heard"])' "$FOLDER/$name.json")"
  echo "Tidy:  $(.build/debug/Murmur --transcribe "$wav" 2>/dev/null)"
  echo "Ultra: $(.build/debug/Murmur --transcribe "$wav" --ultra 2>/dev/null)"
done
