#!/usr/bin/env bash
# Mesure mémoire reproductible du controller (exécuté sur controller). Usage : mem-measure.sh <etiquette>
echo "== $1 — $(date -Is) =="
free -m | sed -n 1,3p
n=$(sudo docker ps -q | wc -l)
tot=$(sudo docker stats --no-stream --format '{{.MemUsage}}' | awk '{v=$1; if (v ~ /GiB/) {sub(/GiB/,"",v); v*=1024} else if (v ~ /MiB/) {sub(/MiB/,"",v)} else if (v ~ /kB/) {sub(/kB/,"",v); v/=1024}; s+=v} END {printf "%d", s}')
echo "conteneurs=$n  memoire_conteneurs_Mo=$tot  disponible_Mo=$(free -m | awk '/^Mem/ {print $7}')"
if [ -r /sys/kernel/mm/ksm/run ]; then
  echo "ksm_run=$(cat /sys/kernel/mm/ksm/run) pages_sharing=$(cat /sys/kernel/mm/ksm/pages_sharing) gain_Mo=$(( $(cat /sys/kernel/mm/ksm/pages_sharing) * 4 / 1024 ))"
fi
sudo docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' | sort -k2 -h -r | head -12
