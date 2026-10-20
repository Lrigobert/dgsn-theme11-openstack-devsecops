#!/usr/bin/env bash
# Descellement de Vault après redémarrage de la VM gitlab (root sur gitlab).
# Lab : clé unique stockée en local (/root/.dgsn, 600). Production : seuil 3/5 détenu par des personnes
# distinctes, ou auto-unseal par HSM/KMS — jamais la clé sur le même serveur.
set -euo pipefail
export VAULT_ADDR=https://127.0.0.1:8200 VAULT_CACERT=/opt/vault/tls/dgsn-root-ca.crt
for i in $(seq 1 30); do rc=0; vault status >/dev/null 2>&1 || rc=$?; [ $rc -ne 1 ] && break; sleep 2; done
if [ "$(vault status -format=json 2>/dev/null | jq -r .sealed)" = true ]; then
  vault operator unseal "$(jq -r '.unseal_keys_b64[0]' /root/.dgsn/vault-init.json)" >/dev/null
fi
vault status -format=json 2>/dev/null | jq -c '{sealed, version, storage_type}'
