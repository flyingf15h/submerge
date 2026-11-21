#!/usr/bin/env bash
# Builds dist/submerge-<version>.tar.gz: the wallpaper, Plasma style, colour scheme, global
# theme (with splash) and fonts, plus install/uninstall scripts for whoever downloads it.
set -euo pipefail
cd "$(dirname "$0")"
# other distros: FONTS_DIR=/path/to/IBMPlex/ttf FONTS_LICENSE=/path/to/LICENSE SKIP_SHADERS=1 ./build-dist.sh
FONTS_DIR="${FONTS_DIR:-/usr/share/fonts/truetype/ibm-plex}"
FONTS_LICENSE="${FONTS_LICENSE:-/usr/share/doc/fonts-ibm-plex/copyright}"
VERSION=2.0
OUT=dist/submerge-$VERSION
rm -rf "$OUT" && mkdir -p "$OUT"/{wallpaper,desktoptheme,look-and-feel,color-schemes,fonts}

[ -n "${SKIP_SHADERS:-}" ] || ./install.sh --compile-only
cp -r package "$OUT/wallpaper/org.submerge.wallpaper"
python3 plasma-style/build.py "$OUT/desktoptheme/submerge" >/dev/null
cp -r theme/look-and-feel/org.submerge.desktop "$OUT/look-and-feel/"
cp plasma-style/colors "$OUT/color-schemes/Submerge.colors"
cp "$FONTS_DIR"/IBMPlexMono-{Light,Regular,Medium}.ttf \
   "$FONTS_DIR"/IBMPlexSansCondensed-{ExtraLight,Light,Regular}.ttf "$OUT/fonts/"
cp "$FONTS_LICENSE" "$OUT/fonts/IBM-Plex-LICENSE.txt"

# previews shown in System Settings
mkdir -p "$OUT/look-and-feel/org.submerge.desktop/contents/previews"
python3 - "$OUT" <<'PY'
import sys
from PIL import Image
out = sys.argv[1] + "/look-and-feel/org.submerge.desktop/contents/previews/"
im = Image.open("theme/screenshot.png").convert("RGB")
im.resize((1920, int(1920 * im.height / im.width))).save(out + "fullscreenpreview.jpg", quality=88)
im.resize((512, int(512 * im.height / im.width))).save(out + "preview.png")
PY

cat > "$OUT/install.sh" <<'SH'
#!/usr/bin/env bash
# Installs Submerge for the current user. Run with --apply to switch to it straight away.
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
    B="$D/submerge-backup"
    C="${XDG_CONFIG_HOME:-$HOME/.config}"
    # Keep the first backup so re-running --apply preserves original settings.
    if [ ! -f "$B/state" ]; then
        mkdir -p "$B"
        rm -f "$B/absent"
        for f in kdeglobals plasmarc kscreenlockerrc ksplashrc kcminputrc kwinrc plasma-org.kde.plasma.desktop-appletsrc; do
            if [ -f "$C/$f" ]; then
                cp -p "$C/$f" "$B/"
            else
                printf '%s\n' "$f" >> "$B/absent"
            fi
        done
        kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage > "$B/lookandfeel" || true
        kreadconfig6 --file plasmarc --group Theme --key name --default default > "$B/desktoptheme" || true
        kreadconfig6 --file kdeglobals --group General --key ColorScheme > "$B/colorscheme" || true
        kreadconfig6 --file kdeglobals --group Icons --key Theme > "$B/icons" || true
        kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme > "$B/cursor" || true
        touch "$B/state"
    fi
    # Omit --resetLayout so user panels stay intact.
    plasma-apply-lookandfeel -a org.submerge.desktop
    plasma-apply-desktoptheme submerge
    plasma-apply-colorscheme Submerge
    # the pond on the lock screen too, with its own centred clock in place of Plasma's
    kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.submerge.wallpaper
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.submerge.wallpaper --group General --key LockScreen true
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General --key alwaysShowClock true
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General --key hideClockWhenIdle true
    if command -v qdbus6 >/dev/null 2>&1 && qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "desktops().forEach(function (d) { d.wallpaperPlugin = 'org.submerge.wallpaper'; })" >/dev/null 2>&1; then
        echo "Applied."
    else
        echo "Applied. If the wallpaper doesn't switch, pick 'Submerge' under Desktop Wallpaper settings."
    fi
    echo "Backup: $B"
else
    echo "Apply it in System Settings > Colours & Themes > Global Theme > Submerge,"
    echo "or run: ./install.sh --apply"
fi
SH
cat > "$OUT/uninstall.sh" <<'SH'
#!/usr/bin/env bash
# Removes Submerge; restores saved wallpaper, theme, colours, icons, cursor, lock screen and splash.
set -euo pipefail
D="${XDG_DATA_HOME:-$HOME/.local/share}"
B="$D/submerge-backup"
C="${XDG_CONFIG_HOME:-$HOME/.config}"
if [ -f "$B/state" ]; then
    # Plasma keeps per-plugin wallpaper config, so org.kde.image recovers prior images.
    if command -v qdbus6 >/dev/null 2>&1; then
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "desktops().forEach(function (d) { if (d.wallpaperPlugin === 'org.submerge.wallpaper') d.wallpaperPlugin = 'org.kde.image'; })" >/dev/null 2>&1 || true
    fi
    lookandfeel="$(head -n 1 "$B/lookandfeel" 2>/dev/null || true)"
    desktoptheme="$(head -n 1 "$B/desktoptheme" 2>/dev/null || true)"
    colorscheme="$(head -n 1 "$B/colorscheme" 2>/dev/null || true)"
    icons="$(head -n 1 "$B/icons" 2>/dev/null || true)"
    cursor="$(head -n 1 "$B/cursor" 2>/dev/null || true)"
    plasma-apply-lookandfeel -a "${lookandfeel:-org.kde.breeze.desktop}" || true
    plasma-apply-desktoptheme "${desktoptheme:-default}" || true
    if [ -n "$colorscheme" ]; then
        plasma-apply-colorscheme "$colorscheme" || true
    fi
    if [ -n "$icons" ]; then
        kwriteconfig6 --file kdeglobals --group Icons --key Theme "$icons" || true
    fi
    if [ -n "$cursor" ] && command -v plasma-apply-cursortheme >/dev/null 2>&1; then
        plasma-apply-cursortheme "$cursor" || true
    fi
    # Leave kdeglobals, plasmarc, kwinrc, kcminputrc and appletsrc intact to keep post-install edits.
    for f in kscreenlockerrc ksplashrc; do
        if [ -f "$B/absent" ] && grep -Fxq "$f" "$B/absent"; then
            rm -f "$C/$f" || true
        elif [ -f "$B/$f" ]; then
            mkdir -p "$C" && cp -p "$B/$f" "$C/$f" || true
        fi
    done
    rm -rf "$B"
fi
rm -rf "$D/plasma/wallpapers/org.submerge.wallpaper" "$D/plasma/desktoptheme/submerge" \
       "$D/plasma/look-and-feel/org.submerge.desktop" "$D/color-schemes/Submerge.colors" "$D/fonts/submerge"
fc-cache -f >/dev/null 2>&1 || true
echo "Submerge removed."
if [ -f /etc/plasmalogin.conf.d/30-submerge.conf ]; then
    echo "The login screen wallpaper stays installed. Remove it with: sudo ./plasmalogin/install.sh --remove"
fi
SH
chmod +x "$OUT/install.sh" "$OUT/uninstall.sh"
cp theme/README.md "$OUT/README.md"
cp LICENSE ART-LICENSE.md "$OUT/"
cp -r sddm "$OUT/sddm"
cp -r plasmalogin "$OUT/plasmalogin"
tar -C dist -czf "dist/submerge-$VERSION.tar.gz" "submerge-$VERSION"

# separate archives for the KDE Store, one per item
mkdir -p dist/store
tar -C "$OUT/wallpaper" -czf "dist/store/submerge-wallpaper-$VERSION.tar.gz" org.submerge.wallpaper
tar -C "$OUT/desktoptheme" -czf "dist/store/submerge-plasma-style-$VERSION.tar.gz" submerge
tar -C "$OUT/look-and-feel" -czf "dist/store/submerge-global-theme-$VERSION.tar.gz" org.submerge.desktop
cp "$OUT/color-schemes/Submerge.colors" dist/store/
echo "built dist/submerge-$VERSION.tar.gz ($(du -h "dist/submerge-$VERSION.tar.gz" | cut -f1))"
