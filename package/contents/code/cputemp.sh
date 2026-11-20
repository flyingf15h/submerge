#!/bin/sh
# Current CPU package temperature in °C, read straight from the kernel's hwmon sensors.
# Prefers the package/die sensor (what the CPU throttles on), then a per-core max, then
# laptop/ACPI fallbacks. Prints nothing if no sensor is found.
pick() { # hwmon name, label regex
    for h in /sys/class/hwmon/hwmon*; do
        [ "$(cat "$h/name" 2>/dev/null)" = "$1" ] || continue
        for l in "$h"/temp*_label; do
            [ -e "$l" ] && grep -qE "$2" "$l" && { cat "${l%_label}_input"; return 0; }
        done
    done
    return 1
}
coremax() {
    for h in /sys/class/hwmon/hwmon*; do
        [ "$(cat "$h/name" 2>/dev/null)" = coretemp ] && cat "$h"/temp*_input
    done 2>/dev/null | sort -n | tail -1
}
v=$(pick coretemp '^Package id 0' || pick k10temp '^Tdie' || pick k10temp '^Tctl' \
    || pick zenpower '^Tdie' || pick thinkpad '^CPU$' || coremax)
if [ -z "$v" ]; then
    for z in /sys/class/thermal/thermal_zone*; do
        case "$(cat "$z/type" 2>/dev/null)" in x86_pkg_temp|cpu*|soc*|acpitz) v=$(cat "$z/temp"); break ;; esac
    done
fi
[ -n "$v" ] && echo $(( v / 1000 ))
