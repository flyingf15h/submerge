#!/usr/bin/env bash
# Recompiles the shaders and installs/updates the wallpaper in Plasma.
# --compile-only just rebuilds the shaders (used by build-dist.sh).
set -euo pipefail
cd "$(dirname "$0")"
# the compiled .qsb files are committed, so uv is only needed to rebuild them
shaders=(shaders/*.vert shaders/*.frag)
if ! command -v uv >/dev/null 2>&1; then
    [ "${1:-}" = "--compile-only" ] && { echo "uv is required to compile shaders: https://docs.astral.sh/uv/" >&2; exit 1; }
    echo "uv not found, using the precompiled shaders"
    shaders=()
fi
for f in "${shaders[@]}"; do
    uv run -q --no-project --with "PySide6-Addons==6.10.*" python -c \
        'import os,sys,PySide6;os.execv(os.path.join(os.path.dirname(PySide6.__file__),"qsb"),["qsb"]+sys.argv[1:])' \
        --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "package/contents/shaders/$(basename "$f").qsb" "$f"
done
[ "${1:-}" = "--compile-only" ] && exit 0
# the plugin used to be called org.stillwaters.pond
kpackagetool6 --type Plasma/Wallpaper --remove org.stillwaters.pond >/dev/null 2>&1 || true
kpackagetool6 --type Plasma/Wallpaper --upgrade package >/dev/null 2>&1 \
    || kpackagetool6 --type Plasma/Wallpaper --install package
echo "Installed. Plasma picks up QML changes after: systemctl --user restart plasma-plasmashell"
