#!/usr/bin/env bash
# Inventaire de la supervision existante sur VM4 (lecture seule).
lsb_release -ds; free -m | sed -n 2,3p; df -h / | tail -1; nproc
echo "--- services"
systemctl list-units --type=service --no-pager --plain | grep -Ei 'prom|grafana|node|exporter|docker' | awk '{print $1, $3, $4}'
echo "--- conteneurs"; (command -v docker >/dev/null && sudo docker ps --format '{{.Names}} {{.Image}} {{.Ports}}') || echo "pas de docker"
echo "--- binaires / versions"
for b in prometheus grafana-server grafana node_exporter prometheus-node-exporter; do command -v $b >/dev/null && echo "$b : $($b --version 2>&1 | head -1)"; done
dpkg -l | grep -Ei 'prometheus|grafana' | awk '{print $2, $3}'
echo "--- ports"; sudo ss -ltnp | grep -E ':(9090|3000|9100|9180)\b' | awk '{print $4, $6}'
echo "--- configuration prometheus"
for f in /etc/prometheus/prometheus.yml /opt/prometheus/prometheus.yml; do [ -f $f ] && { echo "# $f"; sudo grep -vE '^\s*#|^\s*$' $f; }; done
echo "--- grafana provisioning"; sudo ls -R /etc/grafana/provisioning 2>/dev/null | head -20
sudo grep -E '^\s*(http_port|protocol|domain|\[auth.anonymous\]|enabled)' /etc/grafana/grafana.ini 2>/dev/null | head
