#!/usr/bin/env bash
# Phase 6 — import de l'application credential dans Vault (root sur gitlab), puis destruction du fichier.
# Usage : p6-vault-put-appcred.sh <fichier_json>
set -euo pipefail
F=$1
export VAULT_ADDR=https://127.0.0.1:8200 VAULT_CACERT=/opt/vault/tls/dgsn-root-ca.crt
export VAULT_TOKEN=$(jq -r .root_token /root/.dgsn/vault-init.json)
vault kv put kv/ci/demo-app/openstack @"$F" >/dev/null
shred -u "$F"
echo "clés stockées : $(vault kv get -format=json kv/ci/demo-app/openstack | jq -r '.data.data | keys | join(",")')"
echo "fichier source détruit : $([ -e "$F" ] && echo NON || echo oui)"
