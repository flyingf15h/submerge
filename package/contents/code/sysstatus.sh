#!/bin/sh
# "<pending updates> <security updates> <cpu vulnerabilities>", -1 where unknown.
up=-1; sec=-1
if [ -x /usr/lib/update-notifier/apt-check ]; then
    r=$(/usr/lib/update-notifier/apt-check 2>&1 | tail -1)
    up=${r%%;*}; sec=${r##*;}
elif command -v checkupdates >/dev/null; then
    up=$(checkupdates 2>/dev/null | wc -l)
elif command -v dnf >/dev/null; then
    up=$(dnf -q check-update 2>/dev/null | grep -c '^[a-zA-Z0-9]')
    sec=$(dnf -q updateinfo list --security 2>/dev/null | wc -l)
elif command -v zypper >/dev/null; then
    up=$(zypper -q lu 2>/dev/null | grep -c '^v')
    sec=$(zypper -q lp -g security 2>/dev/null | grep -c '^[^-]*| *security')
fi
vul=$(grep -l '^Vulnerable' /sys/devices/system/cpu/vulnerabilities/* 2>/dev/null | wc -l)
case "$up" in ''|*[!0-9-]*) up=-1 ;; esac
case "$sec" in ''|*[!0-9-]*) sec=-1 ;; esac
echo "$up $sec $vul"
