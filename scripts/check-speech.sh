#!/bin/zsh
# Checks the speech model end to end without anyone speaking: the Mac's own
# voice says a sentence into a file, Murmur's test mode transcribes it, and
# this prints OK if the key words came back (with British spelling and the
# fillers gone). The first run downloads the model, about 400 MB.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build --product Murmur >/dev/null
CLIP="$(mktemp -d)/check.aiff"
say -v Daniel -o "$CLIP" "So, um, I realized that my favorite color is gray. Can you send the report by Tuesday?"
TEXT="$(.build/debug/Murmur --transcribe "$CLIP" 2>/dev/null)"
echo "Heard: $TEXT"

for word in realised favourite colour grey report Tuesday; do
  if [[ "$TEXT" != *"$word"* ]]; then echo "NOT OK: missing \"$word\""; exit 1; fi
done
if [[ "$TEXT" == *" um"* ]]; then echo "NOT OK: \"um\" was kept"; exit 1; fi
echo "OK"
