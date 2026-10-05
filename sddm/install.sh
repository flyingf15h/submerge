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

rm -rf "$T"
# start from the installed Breeze theme, then lay the Submerge files over it
cp -r /usr/share/sddm/themes/breeze "$T"
install -m 644 Background.qml theme.conf metadata.desktop "$T/"
mkdir -p "$T/pond"
cp -r ../wallpaper/org.submerge.wallpaper/contents/{ui,shaders,images} "$T/pond/"
install -m 644 ../look-and-feel/org.submerge.desktop/contents/previews/fullscreenpreview.jpg "$T/still.jpg"
install -m 644 ../look-and-feel/org.submerge.desktop/contents/previews/fullscreenpreview.jpg "$T/preview.png"
chmod -R a+rX "$T"
printf '[Theme]\nCurrent=submerge\n' > "$CONF"
echo "Installed $T and set it in $CONF (takes effect at the next login screen)."
