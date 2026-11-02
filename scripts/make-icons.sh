#!/bin/zsh
# Makes the app icons from the logo, Resources/Logo/murmur.svg (Jude's pick, B1,
# 2 Nov 2026): the iPhone icon (square; iOS rounds the corners) and the Mac
# icon (a rounded square with a margin, as macOS icons have).
# Run after changing the logo: ./scripts/make-icons.sh
set -euo pipefail
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"

# iPhone: 1024 square, no transparency.
qlmanage -t -s 1024 -o "$WORK" Resources/Logo/murmur.svg >/dev/null 2>&1
sips -s format jpeg "$WORK/murmur.svg.png" --out "$WORK/flat.jpg" >/dev/null
sips -s format png "$WORK/flat.jpg" --out iPhone/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png >/dev/null

# Mac: the same art in an 824 point rounded square, centred on a clear 1024 canvas.
python3 - "$WORK" <<'PY'
import re, sys
work = sys.argv[1]
art = open("Resources/Logo/murmur.svg").read()
inner = re.search(r'<svg[^>]*>(.*)</svg>', art, re.S).group(1)
open(f"{work}/mac.svg", "w").write(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
    '<defs><clipPath id="r"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath></defs>'
    f'<g clip-path="url(#r)"><g transform="translate(100 100) scale(0.8046875)">{inner}</g></g></svg>')
PY
qlmanage -t -s 1024 -o "$WORK" "$WORK/mac.svg" >/dev/null 2>&1
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/mac.svg.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/mac.svg.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "OK: iPhone/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png and Resources/AppIcon.icns"
