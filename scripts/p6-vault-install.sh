#!/usr/bin/env bash
# Phase 6 — installation et initialisation de Vault sur la VM gitlab (root). Idempotent.
# Fichiers attendus dans /home/jacques1/dgsn/vault : vault.hcl, vault.crt, vault.key, dgsn-root-ca.crt
# Secrets d'initialisation (clé de descellement, jeton root) : /root/.dgsn/vault-init.json (600) uniquement.
set -euo pipefail
S=/home/jacques1/dgsn/vault; D=/root/.dgsn
export VAULT_ADDR=https://127.0.0.1:8200 VAULT_CACERT=/opt/vault/tls/dgsn-root-ca.crt

echo "== Paquet vault (dépôt HashiCorp signé) =="
if ! command -v vault >/dev/null; then
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/hashicorp.gpg
  echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq vault jq >/dev/null
fi
vault version

echo "== TLS et configuration =="
install -d -o vault -g vault -m 750 /opt/vault/tls /opt/vault/data /var/log/vault
install -o vault -g vault -m 644 $S/vault.crt $S/dgsn-root-ca.crt /opt/vault/tls/
[ -f $S/vault.key ] && install -o vault -g vault -m 600 $S/vault.key /opt/vault/tls/
[ -f /opt/vault/tls/vault.key ] || { echo "clé TLS de Vault absente"; exit 1; }
install -o vault -g vault -m 640 $S/vault.hcl /etc/vault.d/vault.hcl
cp $S/dgsn-root-ca.crt /usr/local/share/ca-certificates/dgsn-root-ca.crt && update-ca-certificates >/dev/null 2>&1
[ -f $S/vault.key ] && shred -u $S/vault.key
systemctl enable --now vault >/dev/null 2>&1; systemctl restart vault
# vault status : 0 = descellé, 2 = scellé, 1 = erreur (injoignable) -> ne pas laisser set -e interrompre
for i in $(seq 1 30); do rc=0; vault status >/dev/null 2>&1 || rc=$?; [ $rc -ne 1 ] && break; sleep 2; done
echo "vault joignable (code status=$rc)"

echo "== Initialisation (lab : 1 part / seuil 1 ; production : 5/3 + auto-unseal HSM) =="
st() { vault status -format=json 2>/dev/null || true; }   # code 2 si scellé
if [ "$(st | jq -r .initialized)" = false ]; then
  umask 077
  vault operator init -key-shares=1 -key-threshold=1 -format=json > $D/vault-init.json
fi
if [ "$(st | jq -r .sealed)" = true ]; then
  vault operator unseal "$(jq -r '.unseal_keys_b64[0]' $D/vault-init.json)" >/dev/null
fi
st | jq -c '{initialized, sealed, version, storage_type}'
echo "P6_VAULT_INSTALL_OK"
