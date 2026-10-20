#!/usr/bin/env bash
# Phase 7 — ajout des jobs DGSN à Prometheus sur VM4 (root). Idempotent, sauvegarde + validation promtool.
# Fichiers attendus dans /tmp/prom : prometheus-dgsn-jobs.yml, prometheus-client.{crt,key}, dgsn-root-ca.crt
set -euo pipefail
F=/etc/prometheus/prometheus.yml; T=/tmp/prom
install -d -m 750 -o root -g prometheus /etc/prometheus/dgsn-tls
if [ -f $T/prometheus-client.key ]; then
  install -m 640 -o root -g prometheus $T/prometheus-client.crt $T/dgsn-root-ca.crt /etc/prometheus/dgsn-tls/
  install -m 640 -o root -g prometheus $T/prometheus-client.key /etc/prometheus/dgsn-tls/
  shred -u $T/prometheus-client.key
fi
[ -f $F.avant-dgsn ] || cp -p $F $F.avant-dgsn          # sauvegarde de la configuration d'origine
if [ -f $T/prometheus-dgsn-jobs.yml ]; then
  sed -i '/# DGSN-THEME11 BEGIN/,/# DGSN-THEME11 END/d' $F  # idempotence
  tail -c1 $F | od -c | grep -q '\\n' || echo >> $F
  cat $T/prometheus-dgsn-jobs.yml >> $F
fi
rm -rf $T
# La configuration d'origine référence alert_rules.yml, absent (préexistant, hors périmètre) : promtool l'exige,
# Prometheus le tolère (motif sans correspondance). On valide donc une copie sans rule_files.
python3 - "$F" <<'EOF'
import sys, yaml
c = yaml.safe_load(open(sys.argv[1])); c.pop("rule_files", None)
yaml.safe_dump(c, open("/tmp/prom-check.yml", "w"))
EOF
promtool check config /tmp/prom-check.yml && rm -f /tmp/prom-check.yml
systemctl reload prometheus || systemctl restart prometheus
sleep 75   # au moins un cycle de collecte du job openstack (60 s)
curl -s http://127.0.0.1:9090/api/v1/targets | python3 -c '
import sys, json
for t in json.load(sys.stdin)["data"]["activeTargets"]:
    if t["labels"]["job"].startswith("dgsn"):
        print("%-16s %-24s %-5s %s" % (t["labels"]["job"], t["labels"]["instance"], t["health"], t.get("lastError","")[:80]))'
