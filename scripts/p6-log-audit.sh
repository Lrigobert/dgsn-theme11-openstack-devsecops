#!/usr/bin/env bash
# Extraits utiles + recherche de fuites de secrets dans les journaux de jobs (root sur gitlab).
# Usage : p6-log-audit.sh <dossier_rapports>
R=$1
for j in openstack-preflight deploy-openstack; do
  echo "--- $j"
  sed 's/\x1b\[[0-9;]*[mK]//g' "$R/$j.log" | grep -E 'Vault|Keystone|Nova|health|status' | grep -v '^\s*\$' | sed -E 's/^[0-9TZ:.-]+ [0-9A-Z]+ //' | head -8
done
echo "--- recherche de secrets dans les journaux :"
AC=$(VAULT_ADDR=https://127.0.0.1:8200 VAULT_CACERT=/opt/vault/tls/dgsn-root-ca.crt VAULT_TOKEN=$(jq -r .root_token /root/.dgsn/vault-init.json) \
     vault kv get -field=application_credential_secret kv/ci/demo-app/openstack 2>/dev/null)
# Garde-fou : un motif vide (Vault scellé/injoignable) ferait correspondre toutes les lignes -> faux positif
if [ ${#AC} -lt 16 ]; then echo "AUDIT_IMPOSSIBLE : secret de référence illisible (Vault scellé ?)"; exit 2; fi
n_ac=$(grep -c -F "$AC" "$R"/*.log | awk -F: '{s+=$2} END {print s+0}'); unset AC
n_hvs=$(grep -cE 'hvs\.[A-Za-z0-9]{20,}' "$R"/*.log | awk -F: '{s+=$2} END {print s+0}')
n_key=$(grep -c 'BEGIN OPENSSH PRIVATE KEY' "$R"/*.log | awk -F: '{s+=$2} END {print s+0}')
echo "secret d'application credential : $n_ac occurrence(s) ; jeton Vault (hvs.) : $n_hvs ; clé privée SSH : $n_key"
[ $((n_ac + n_hvs + n_key)) = 0 ] && echo "AUCUN_SECRET_DANS_LES_JOURNAUX" || echo "FUITE_DETECTEE"
