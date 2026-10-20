#!/usr/bin/env bash
# Phase 7 — provisioning Grafana (datasource + dashboard) et preuve des métriques (root sur VM4).
# Fichiers attendus dans /tmp/graf : gen-dashboard.py, grafana-provisioning.yaml
set -euo pipefail
T=/tmp/graf; DIR=/var/lib/grafana/dashboards/dgsn
python3 $T/gen-dashboard.py > /tmp/dgsn-dashboard.json
install -d -o grafana -g grafana -m 755 $DIR
install -o grafana -g grafana -m 644 /tmp/dgsn-dashboard.json $DIR/dgsn-theme11.json
awk '/^# --- datasources/{f=1;next} /^# --- dashboards/{f=0} f' $T/grafana-provisioning.yaml > /etc/grafana/provisioning/datasources/dgsn.yaml
awk '/^# --- dashboards/{f=1;next} f' $T/grafana-provisioning.yaml > /etc/grafana/provisioning/dashboards/dgsn.yaml
chown root:grafana /etc/grafana/provisioning/datasources/dgsn.yaml /etc/grafana/provisioning/dashboards/dgsn.yaml
chmod 640 /etc/grafana/provisioning/datasources/dgsn.yaml /etc/grafana/provisioning/dashboards/dgsn.yaml
systemctl restart grafana-server
for i in $(seq 1 30); do curl -sf http://127.0.0.1:3000/api/health >/dev/null && break; sleep 2; done
curl -s http://127.0.0.1:3000/api/health; echo
journalctl -u grafana-server --since "-2 min" --no-pager | grep -iE 'provision|dgsn|error' | grep -viE 'plugin' | tail -5 | cut -c1-200

echo "== Requêtes du dashboard évaluées dans Prometheus (preuve des métriques) =="
python3 - <<'EOF'
import json, urllib.parse, urllib.request
d = json.load(open("/tmp/dgsn-dashboard.json"))
ok = 0; tot = 0
for p in d["panels"]:
    for t in p.get("targets", []):
        tot += 1
        q = urllib.parse.urlencode({"query": t["expr"]})
        r = json.load(urllib.request.urlopen("http://127.0.0.1:9090/api/v1/query?" + q, timeout=30))["data"]["result"]
        vals = ", ".join("%s=%s" % (s["metric"].get("vm") or s["metric"].get("resourcetype") or t["legendFormat"], round(float(s["value"][1]), 1)) for s in r[:4])
        ok += bool(r)
        print("%-3s %-45s %-14s %s" % ("OK" if r else "--", p["title"][:45], t["legendFormat"][:14], vals[:90]))
print(f"\nrequêtes avec données : {ok}/{tot}")
EOF
cp /tmp/dgsn-dashboard.json /home/jacques4/dgsn-dashboard.json; chown jacques4: /home/jacques4/dgsn-dashboard.json
rm -rf $T
