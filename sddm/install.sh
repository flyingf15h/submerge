#!/bin/bash
# Installs the Submerge sign-in (SDDM) theme: Breeze's login form over the live koi pond.
# Run with: sudo ./install.sh        Undo: sudo ./install.sh --remove
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }
T=/usr/share/sddm/themes/submerge
CONF=/etc/sddm.conf.d/30-submerge-theme.conf

if [ "${1:-}" = "--remove" ]; then
    rm -rf "$T" "$CONF"
    echo "Removed; SDDM is back on the Breeze theme."
    exit 0
fi

# works from a release folder or from a git checkout
if [ -d ../wallpaper/org.submerge.wallpaper ]; then
    POND=../wallpaper/org.submerge.wallpaper/contents
    STILL=../look-and-feel/org.submerge.desktop/contents/previews/fullscreenpreview.jpg
else
    POND=../package/contents
    STILL=../theme/screenshot.png
fi

rm -rf "$T"
# start from the installed Breeze theme, then lay the Submerge files over it
cp -r /usr/share/sddm/themes/breeze "$T"
install -m 644 Background.qml theme.conf metadata.desktop "$T/"
mkdir -p "$T/pond"
cp -r "$POND"/{ui,shaders,images} "$T/pond/"
install -m 644 "$STILL" "$T/still.jpg"
install -m 644 "$STILL" "$T/preview.png"
chmod -R a+rX "$T"
printf '[Theme]\nCurrent=submerge\n' > "$CONF"
echo "Installed $T and set it in $CONF (takes effect at the next login screen)."
