#!/usr/bin/env bash
# Copies the shaders into the package and installs/updates the wallpaper in Plasma 5.
# --shaders-only just refreshes the package shaders (used by build-dist.sh).
set -euo pipefail
cd "$(dirname "$0")"
# Qt 5 compiles GLSL at runtime, so the sources ship as they are (no qsb step)
cp shaders/*.vert shaders/*.frag package/contents/shaders/
[ "${1:-}" = "--shaders-only" ] && exit 0
# the plugin used to be called org.stillwaters.pond
kpackagetool5 --type Plasma/Wallpaper --remove org.stillwaters.pond >/dev/null 2>&1 || true
kpackagetool5 --type Plasma/Wallpaper --upgrade package >/dev/null 2>&1 \
    || kpackagetool5 --type Plasma/Wallpaper --install package
echo "Installed. Plasma picks up QML changes after: systemctl --user restart plasma-plasmashell"
