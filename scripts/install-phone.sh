#!/bin/zsh
# Builds Murmur for Jude's iPhone 16, installs it and opens it. The phone must be
# unlocked and plugged in, or on the same Wi-Fi as the Mac.
# Run from anywhere: ./scripts/install-phone.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PHONE=00008140-000834E10E82801C
# A fresh build number each time, or iOS can keep showing the old keyboard.
BUILD_NUMBER="$(date +%Y%m%d%H%M)"
APP=iPhone/build/DerivedData/Build/Products/Release-iphoneos/MurmurPhone.app

echo "Building for the iPhone (the first time takes a few minutes)…"
xcodebuild -project iPhone/Murmur.xcodeproj -scheme MurmurPhone -configuration Release \
  -destination "id=$PHONE" -derivedDataPath iPhone/build/DerivedData \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" -quiet build

echo "Installing on the iPhone…"
xcrun devicectl device install app --device "$PHONE" "$APP" >/dev/null
# Open it straight away, so the speech model starts getting ready (minutes after
# every update). A locked phone refuses, so keep trying for two minutes.
for attempt in {1..24}; do
  if xcrun devicectl device process launch --device "$PHONE" com.judelewis.murmur.iphone >/dev/null 2>&1; then
    echo "Done. Murmur is open on the iPhone. Leave it on screen until it says Ready."
    exit 0
  fi
  [[ $attempt == 1 ]] && echo "Unlock the iPhone to finish…"
  sleep 5
done
echo "Done. Murmur is on the iPhone. Unlock it, tap the Murmur icon, and leave it on screen until it says Ready."
