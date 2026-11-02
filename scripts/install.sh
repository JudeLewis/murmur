#!/bin/zsh
# Builds Murmur, wraps it as Murmur.app, signs it, puts it in Applications and opens it.
# Run from anywhere: ./scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Building (the first time takes a few minutes)…"
swift build -c release --product Murmur "$@"
BIN="$(swift build -c release --show-bin-path)"

APP="build/Murmur.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Murmur" "$APP/Contents/MacOS/Murmur"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Sign with the Apple Development certificate if there is one. macOS ties the
# Microphone and Accessibility permissions to the signature: with a real
# certificate they survive rebuilds; with ad hoc signing ("-") they must be
# allowed again after every install.
IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')"
if [[ -z "$IDENTITY" ]]; then
  echo "No Apple Development certificate found; signing ad hoc."
  IDENTITY="-"
fi
codesign --force --sign "$IDENTITY" "$APP"

pkill -x Murmur 2>/dev/null && sleep 1 || true
rm -rf /Applications/Murmur.app
cp -R "$APP" /Applications/
open /Applications/Murmur.app
echo "Done. Murmur is in Applications and running: look for the wave icon in the menu bar."
