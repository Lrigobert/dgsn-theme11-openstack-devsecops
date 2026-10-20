#!/usr/bin/env bash
# Phase 6 — application credential Keystone pour la CI (exécuté sur VM1, utilisateur dgsn-ops-admin).
# Rôle limité à « member » sur dgsn-ops, non « unrestricted » (ne peut créer d'autres credentials),
# expiration 30 jours. Le secret est écrit dans un fichier 600 transmis à Vault puis détruit.
# Usage : p6-appcred.sh <fichier_sortie_json>
set -euo pipefail
OUT=$1
. ~/kolla-venv/bin/activate
unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env
NAME=ci-demo-app
# Rotation : l'ancien credential est supprimé avant d'en créer un nouveau
openstack application credential show $NAME >/dev/null 2>&1 && openstack application credential delete $NAME
EXP=$(date -u -d '+30 days' +%Y-%m-%dT%H:%M:%S)
umask 077
openstack application credential create $NAME --role member --expiration "$EXP" \
  --description "CI GitLab dgsn/demo-app (lu via Vault)" -f json \
  | python3 -c '
import sys, json
d = {k.lower().replace(" ", "_"): v for k, v in json.load(sys.stdin).items()}   # clés « ID »/« Secret » selon la version du client
json.dump({"application_credential_id": d["id"], "application_credential_secret": d["secret"],
           "project": "dgsn-ops", "expires_at": d.get("expires_at")}, sys.stdout)' > "$OUT"
[ -s "$OUT" ] || { echo "échec : fichier de sortie vide"; exit 1; }
openstack application credential show $NAME -f value -c name -c roles -c unrestricted -c expires_at
echo "P6_APPCRED_OK (secret écrit dans $OUT, jamais affiché)"
