#!/bin/bash
# Installs the Submerge wallpaper for Plasma Login Manager.
# Run with: sudo ./install.sh        Undo: sudo ./install.sh --remove
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }

PKG=/usr/share/plasma/wallpapers/org.submerge.wallpaper
CONF=/etc/plasmalogin.conf.d/30-submerge.conf
MAIN_CONF=/etc/plasmalogin.conf

if [ "${1:-}" = "--remove" ]; then
    rm -rf "$PKG" "$CONF"
    echo "Removed $CONF and $PKG."
    exit 0
fi

if [ ! -x /usr/bin/plasma-login-wallpaper ]; then
    echo "Plasma Login Manager is not installed (/usr/bin/plasma-login-wallpaper not found)." >&2
    exit 1
fi

# Works from a release folder or a git checkout.
if [ -d ../wallpaper/org.submerge.wallpaper ]; then
    SRC=../wallpaper/org.submerge.wallpaper
elif [ -d ../package ]; then
    SRC=../package
else
    echo "Cannot find the wallpaper package next to this script." >&2
    exit 1
fi

# The plasmalogin user cannot read ~/.local/share.
install -d -m 755 /usr/share/plasma/wallpapers
rm -rf "$PKG"
cp -r "$SRC" "$PKG"
chmod -R a+rX "$PKG"

install -d -m 755 "$(dirname "$CONF")"
# Hud=false avoids ksystemstats and panel layout; LockScreen=true skips window tracking.
cat > "$CONF" <<'EOF'
[Greeter]
WallpaperPluginId=org.submerge.wallpaper

[Greeter][Wallpaper][org.submerge.wallpaper][General]
Hud=false
LockScreen=true
EOF
chmod 644 "$CONF"

if [ -f "$MAIN_CONF" ] && grep -Eq '^[[:space:]]*WallpaperPluginId[[:space:]]*=' "$MAIN_CONF"; then
    echo "Warning: $MAIN_CONF sets WallpaperPluginId, which takes priority over $CONF." >&2
    echo "Remove that line from $MAIN_CONF to see the pond." >&2
fi

echo "Installed $PKG and wrote $CONF (takes effect at the next login screen)."
echo "If you save a wallpaper in System Settings > Login Screen, Plasma writes $MAIN_CONF and replaces this drop-in."
