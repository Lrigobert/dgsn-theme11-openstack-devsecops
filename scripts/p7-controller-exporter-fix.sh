#!/usr/bin/env bash
# Controller : désactive l'exporter en clair hérité du clonage de VM1 (node-exporter.service,
# /usr/local/bin/node_exporter) au profit du paquet prometheus-node-exporter en mTLS. Root.
systemctl disable --now node-exporter.service 2>&1 | tail -1
systemctl reset-failed prometheus-node-exporter
systemctl restart prometheus-node-exporter; sleep 2
echo "prometheus-node-exporter : $(systemctl is-active prometheus-node-exporter)"
c=$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:9100/metrics || true)
echo "HTTPS sans certificat client : code '$c' (attendu 000)"
ss -ltnp | grep ':9100' | awk '{print $4, $6}'
