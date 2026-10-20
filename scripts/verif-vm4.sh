#!/usr/bin/env bash
# Vérification finale — groupe C, côté VM4 (après redémarrage) : services, cibles Prometheus DGSN.
for s in prometheus grafana-server openstack-exporter; do echo "  $s : $(systemctl is-active $s)"; done
sleep 90   # au moins un cycle de collecte du job openstack (60 s)
curl -s http://127.0.0.1:9090/api/v1/targets | python3 -c '
import sys, json
for t in json.load(sys.stdin)["data"]["activeTargets"]:
    if t["labels"]["job"].startswith("dgsn"):
        print("  cible", t["labels"]["job"], t["labels"]["instance"], t["health"])'
