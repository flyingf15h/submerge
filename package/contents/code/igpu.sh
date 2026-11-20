#!/bin/sh
# Render load of an Intel integrated GPU, read from its idle counter (ksystemstats reports 0 there).
# Other cards are skipped: on hybrid laptops the gpu sensor polls nvidia-smi, which keeps the dGPU awake.
# Prints nothing if no idle counter is found, so the HUD falls back to the regular sensor.
f=
for c in /sys/class/drm/card[0-9]*; do
    [ -e "$c/device/driver" ] || continue
    case "$c" in *-*) continue ;; esac
    case "$(basename "$(readlink "$c/device/driver")")" in
        xe) for g in "$c"/device/tile*/gt*/gtidle; do
                case "$(cat "$g/name" 2>/dev/null)" in *-rc) f="$g/idle_residency_ms" ;; esac
            done ;;
        i915) [ -r "$c/gt/gt0/rc6_residency_ms" ] && f="$c/gt/gt0/rc6_residency_ms" ;;
        *) continue ;;
    esac
done
[ -n "$f" ] || exit 0
a=$(cat "$f"); t=$(date +%s%3N)
sleep 1
b=$(cat "$f"); u=$(date +%s%3N)
[ "$u" -gt "$t" ] || exit 0
echo $(( 100 - (b - a) * 100 / (u - t) ))
