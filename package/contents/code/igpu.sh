#!/bin/sh
# Render load of an Intel integrated GPU, for machines with no discrete GPU
# (ksystemstats reports 0 for Intel iGPUs). Prints nothing if a non-Intel GPU is present
# or no idle counter is found, so the HUD falls back to the regular sensor.
f=
for c in /sys/class/drm/card[0-9]*; do
    [ -e "$c/device/driver" ] || continue
    case "$c" in *-*) continue ;; esac
    case "$(basename "$(readlink "$c/device/driver")")" in
        xe) for g in "$c"/device/tile*/gt*/gtidle; do
                case "$(cat "$g/name" 2>/dev/null)" in *-rc) f="$g/idle_residency_ms" ;; esac
            done ;;
        i915) [ -r "$c/gt/gt0/rc6_residency_ms" ] && f="$c/gt/gt0/rc6_residency_ms" ;;
        *) exit 0 ;;
    esac
done
[ -n "$f" ] || exit 0
a=$(cat "$f"); t=$(date +%s%3N)
sleep 1
b=$(cat "$f"); u=$(date +%s%3N)
[ "$u" -gt "$t" ] || exit 0
echo $(( 100 - (b - a) * 100 / (u - t) ))
