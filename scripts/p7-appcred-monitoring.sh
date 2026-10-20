#!/usr/bin/env bash
# Phase 7 — application credential de supervision (VM1, admin). Lecture seule par « access rules » (GET uniquement)
# sur les API interrogées par openstack-exporter. Écrit un clouds.yaml (600) pour VM4 ; secret jamais affiché.
# Usage : p7-appcred-monitoring.sh <fichier_clouds_yaml> [sans-regles]
set -euo pipefail
OUT=$1; MODE=${2:-regles}
. ~/kolla-venv/bin/activate; unset ${!OS_*}; . /etc/kolla/admin-openrc.sh
NAME=monitoring-exporter
openstack application credential show $NAME >/dev/null 2>&1 && openstack application credential delete $NAME
ARGS=(--role admin --expiration "$(date -u -d '+90 days' +%Y-%m-%dT%H:%M:%S)" --description "openstack-exporter VM4 (lecture seule)")
if [ "$MODE" = regles ]; then
  cat > /tmp/rules.json <<'EOF'
[ {"service": "identity",  "method": "GET", "path": "/v3/**"},
  {"service": "compute",   "method": "GET", "path": "/v2.1/**"},
  {"service": "network",   "method": "GET", "path": "/v2.0/**"},
  {"service": "image",     "method": "GET", "path": "/v2/**"},
  {"service": "placement", "method": "GET", "path": "/**"} ]
EOF
  ARGS+=(--access-rules /tmp/rules.json)
fi
umask 077
openstack application credential create $NAME "${ARGS[@]}" -f json | python3 -c '
import sys, json
d = {k.lower(): v for k, v in json.load(sys.stdin).items()}
print(f"""clouds:
  dgsn:
    auth_type: v3applicationcredential
    auth:
      auth_url: https://192.168.100.45:5000/v3
      application_credential_id: "{d["id"]}"
      application_credential_secret: "{d["secret"]}"
    region_name: RegionOne
    interface: public
    identity_api_version: 3
    cacert: /etc/openstack-exporter/dgsn-root-ca.crt""")' > "$OUT"
[ -s "$OUT" ] || { echo "échec"; exit 1; }
openstack application credential show $NAME -f value -c name -c unrestricted -c expires_at
openstack application credential show $NAME -f json -c access_rules | python3 -c 'import sys,json; r=json.load(sys.stdin).get("access_rules") or []; print("access rules :", len(r), "règle(s) GET" if r else "aucune")'
echo "P7_APPCRED_OK"
