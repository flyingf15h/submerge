#!/usr/bin/env bash
# Builds dist/submerge-<version>-plasma5.tar.gz: the wallpaper, Plasma style, colour scheme, global
# theme (with splash) and fonts, plus install/uninstall scripts for whoever downloads it.
set -euo pipefail
cd "$(dirname "$0")"
VERSION=1.0
NAME=submerge-$VERSION-plasma5
OUT=dist/$NAME
# the fonts and their licence come from Debian's fonts-ibm-plex unless FONTS / FONT_LICENSE say
# otherwise (e.g. the fonts folder of an earlier release)
FONTS="${FONTS:-/usr/share/fonts/truetype/ibm-plex}"
FONT_LICENSE="${FONT_LICENSE:-/usr/share/doc/fonts-ibm-plex/copyright}"
# the previews need Pillow; borrow it through uv when the system Python doesn't have it
PY=python3
python3 -c "import PIL" 2>/dev/null || PY="uv run -q --no-project --with pillow python"
rm -rf "$OUT" && mkdir -p "$OUT"/{wallpaper,desktoptheme,look-and-feel,color-schemes,fonts}

./install.sh --shaders-only
cp -r package "$OUT/wallpaper/org.submerge.wallpaper"
python3 plasma-style/build.py "$OUT/desktoptheme/submerge" >/dev/null
cp -r theme/look-and-feel/org.submerge.desktop "$OUT/look-and-feel/"
cp plasma-style/colors "$OUT/color-schemes/Submerge.colors"
cp "$FONTS"/IBMPlexMono-{Light,Regular,Medium}.ttf \
   "$FONTS"/IBMPlexSansCondensed-{ExtraLight,Light,Regular}.ttf "$OUT/fonts/"
cp "$FONT_LICENSE" "$OUT/fonts/IBM-Plex-LICENSE.txt"

# previews shown in System Settings
$PY - "$OUT" <<'PY'
import os, sys
from PIL import Image
out = sys.argv[1] + "/look-and-feel/org.submerge.desktop/contents/previews/"
os.makedirs(out, exist_ok=True)
im = Image.open("theme/screenshot.png").convert("RGB")
im.resize((1920, int(1920 * im.height / im.width))).save(out + "fullscreenpreview.jpg", quality=88)
im.resize((512, int(512 * im.height / im.width))).save(out + "preview.png")
PY

cat > "$OUT/install.sh" <<'SH'
#!/usr/bin/env bash
# Installs Submerge (Plasma 5) for the current user. Run with --apply to switch to it straight away.
set -euo pipefail
cd "$(dirname "$0")"
D="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$D/plasma/wallpapers" "$D/plasma/desktoptheme" "$D/plasma/look-and-feel" "$D/color-schemes" "$D/fonts/submerge"
rm -rf "$D/plasma/wallpapers/org.submerge.wallpaper" "$D/plasma/desktoptheme/submerge" "$D/plasma/look-and-feel/org.submerge.desktop"
cp -r wallpaper/org.submerge.wallpaper "$D/plasma/wallpapers/"
cp -r desktoptheme/submerge "$D/plasma/desktoptheme/"
cp -r look-and-feel/org.submerge.desktop "$D/plasma/look-and-feel/"
cp color-schemes/Submerge.colors "$D/color-schemes/"
cp fonts/*.ttf "$D/fonts/submerge/"
fc-cache -f "$D/fonts/submerge" >/dev/null 2>&1 || true
echo "Submerge installed."
if [ "${1:-}" = "--apply" ]; then
    plasma-apply-lookandfeel -a org.submerge.desktop
    plasma-apply-desktoptheme submerge
    plasma-apply-colorscheme Submerge
    echo "Applied. If the wallpaper doesn't switch, pick 'Submerge' under Desktop Wallpaper settings."
else
    echo "Apply it in System Settings > Colours & Themes > Global Theme > Submerge,"
    echo "or run: ./install.sh --apply"
fi
SH
cat > "$OUT/uninstall.sh" <<'SH'
#!/usr/bin/env bash
# Removes Submerge. Switch to another global theme and wallpaper first.
set -euo pipefail
D="${XDG_DATA_HOME:-$HOME/.local/share}"
rm -rf "$D/plasma/wallpapers/org.submerge.wallpaper" "$D/plasma/desktoptheme/submerge" \
       "$D/plasma/look-and-feel/org.submerge.desktop" "$D/color-schemes/Submerge.colors" "$D/fonts/submerge"
echo "Submerge removed."
SH
chmod +x "$OUT/install.sh" "$OUT/uninstall.sh"
cp theme/README.md "$OUT/README.md"
cp -r sddm "$OUT/sddm"
cp LICENSE ART-LICENSE.md "$OUT/"
tar -C dist -czf "dist/$NAME.tar.gz" "$NAME"

# separate archives for the KDE Store, one per item
mkdir -p dist/store
tar -C "$OUT/wallpaper" -czf "dist/store/submerge-wallpaper-$VERSION-plasma5.tar.gz" org.submerge.wallpaper
tar -C "$OUT/desktoptheme" -czf "dist/store/submerge-plasma-style-$VERSION-plasma5.tar.gz" submerge
tar -C "$OUT/look-and-feel" -czf "dist/store/submerge-global-theme-$VERSION-plasma5.tar.gz" org.submerge.desktop
cp "$OUT/color-schemes/Submerge.colors" dist/store/
echo "built dist/$NAME.tar.gz ($(du -h "dist/$NAME.tar.gz" | cut -f1))"
