#!/bin/bash
# Builds every app icon size from one master image (macOS `sips`, no packages).
#
#   tool/generate_icons.sh path/to/icon_1024.png
#
# The master should be a square, full-bleed PNG of at least 1024x1024 with NO
# rounded corners and NO transparency: Android and iOS round it themselves.
# Set ICON_OUT to write somewhere else (dry run) instead of the project.
set -euo pipefail
SRC="${1:?usage: tool/generate_icons.sh master.png}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ICON_OUT:-$ROOT}"

w=$(sips -g pixelWidth "$SRC" | awk '/pixelWidth/{print $2}')
h=$(sips -g pixelHeight "$SRC" | awk '/pixelHeight/{print $2}')
[ "$w" = "$h" ] || { echo "master must be square (got ${w}x${h})"; exit 1; }
[ "$w" -ge 1024 ] || echo "warning: master is ${w}px; 1024px or more avoids soft icons"

resize() { # size dest
  mkdir -p "$(dirname "$2")"
  sips -s format png -z "$1" "$1" "$SRC" --out "$2" >/dev/null
}

# Android launcher icons
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  resize "${d#*:}" "$OUT/android/app/src/main/res/mipmap-${d%%:*}/ic_launcher.png"
done

# iOS: sizes come from the asset catalogue's own Contents.json
SET="$OUT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
if [ -f "$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json" ]; then
  mkdir -p "$SET"
  python3 - "$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json" <<'PY' | while read -r px file; do resize "$px" "$SET/$file"; done
import json,sys
for i in json.load(open(sys.argv[1]))['images']:
    base=float(i['size'].split('x')[0]); scale=int(i['scale'].rstrip('x'))
    print(round(base*scale), i['filename'])
PY
fi

# Web
resize 192 "$OUT/web/icons/Icon-192.png"
resize 512 "$OUT/web/icons/Icon-512.png"
resize 192 "$OUT/web/icons/Icon-maskable-192.png"
resize 512 "$OUT/web/icons/Icon-maskable-512.png"
resize 32 "$OUT/web/favicon.png"
echo "Icons written under $OUT"
