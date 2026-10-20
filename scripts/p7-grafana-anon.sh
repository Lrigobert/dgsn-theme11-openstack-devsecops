#!/usr/bin/env bash
# Active/désactive TEMPORAIREMENT l'accès anonyme en lecture seule (Viewer) à Grafana, le temps d'une capture.
# Usage (root sur VM4) : p7-grafana-anon.sh on|off
set -euo pipefail
F=/etc/grafana/grafana.ini
sed -i '/^# DGSN-ANON BEGIN/,/^# DGSN-ANON END/d' $F
if [ "$1" = on ]; then
  ORG=$(sqlite3 /var/lib/grafana/grafana.db "select name from org where id=1;" 2>/dev/null || echo "Main Org.")
  cat >> $F <<EOF
# DGSN-ANON BEGIN (temporaire, capture du dashboard P7)
[auth.anonymous]
enabled = true
org_name = $ORG
org_role = Viewer
hide_version = true
# DGSN-ANON END
EOF
fi
systemctl restart grafana-server
for i in $(seq 1 30); do curl -sf http://127.0.0.1:3000/api/health >/dev/null && break; sleep 2; done
c=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/api/dashboards/uid/dgsn-theme11)
echo "accès anonyme $1 : lecture du dashboard sans authentification -> HTTP $c"
