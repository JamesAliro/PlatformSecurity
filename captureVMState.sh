#!/usr/bin/env bash
set -euo pipefail
out=~/baseline; mkdir -p "$out"; cd "$out"
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Priority}\t${Installed-Size}\n' | sort > packages.tsv
dpkg --get-selections > selections.txt
apt-mark showmanual | sort > manual.txt
apt-mark showauto   | sort > auto.txt
systemctl list-unit-files --state=enabled --no-pager > enabled-units.txt
systemctl list-timers --all --no-pager > timers.txt
sudo ss -tulpnH | sort > listening.txt
sudo find / -xdev -perm /6000 -type f 2>/dev/null | sort > suid-sgid.txt
lsmod | sort > modules.txt
getent passwd | awk -F: '$7 !~ /(nologin|false)$/' > login-users.txt
sudo aa-status > apparmor.txt 2>&1 || true
{ lsb_release -ds; uname -r; } > os-release.txt