#!/usr/bin/env bash
# Crops the phone bezel off each screenshot (keeps only the app screen) and
# rounds the corners. Put your original screenshots in screens/raw/ named:
#   home.png  batch.png  communities.png  messages.png  profile.png
# Then run:  bash crop-screens.sh
set -e
cd "$(dirname "$0")"
RADIUS=46
for f in raw/*.png; do
  [ -e "$f" ] || { echo "No PNGs in raw/"; exit 1; }
  name=$(basename "$f")
  # 1) trim the uniform dark bezel around the screen
  convert "$f" -fuzz 14% -trim +repage _t.png
  # 2) round the corners with a mask
  w=$(identify -format "%w" _t.png); h=$(identify -format "%h" _t.png)
  convert -size ${w}x${h} xc:none -draw "roundrectangle 0,0,$((w-1)),$((h-1)),$RADIUS,$RADIUS" _mask.png
  convert _t.png -matte _mask.png -compose DstIn -composite "$name"
  echo "cropped -> $name (${w}x${h})"
done
rm -f _t.png _mask.png
echo "Done. Cropped screens are in $(pwd)"
