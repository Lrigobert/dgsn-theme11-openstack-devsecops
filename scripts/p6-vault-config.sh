#!/usr/bin/env bash
# Phase 6 — configuration de Vault (root sur gitlab). Idempotent.
# Audit fichier, KV v2 « kv », authentification JWT GitLab (id_tokens), politique et rôle CI restreints,
# clé SSH de déploiement CI importée depuis /root/.dgsn (aucun secret affiché).
set -euo pipefail
export VAULT_ADDR=https://127.0.0.1:8200 VAULT_CACERT=/opt/vault/tls/dgsn-root-ca.crt
export VAULT_TOKEN=$(jq -r .root_token /root/.dgsn/vault-init.json)
S=/home/jacques1/dgsn/vault

vault audit list 2>/dev/null | grep -q '^file/' || vault audit enable file file_path=/var/log/vault/audit.log >/dev/null
vault secrets list | grep -q '^kv/' || vault secrets enable -path=kv -version=2 kv >/dev/null
vault auth list | grep -q '^jwt/' || vault auth enable jwt >/dev/null

# Émetteur = external_url de GitLab ; clés publiques de signature des id_tokens
vault write auth/jwt/config jwks_url="http://192.168.100.50/oauth/discovery/keys" bound_issuer="http://192.168.100.50" >/dev/null
vault policy write ci-demo-app $S/ci-demo-app.hcl >/dev/null

# Rôle : uniquement le projet dgsn/demo-app, branche main protégée, audience Vault, jeton 10 min
vault write auth/jwt/role/ci-demo-app - >/dev/null <<'EOF'
{
  "role_type": "jwt",
  "user_claim": "project_path",
  "bound_audiences": ["https://vault.dgsn.lab"],
  "bound_claims_type": "string",
  "bound_claims": {
    "project_path": "dgsn/demo-app",
    "ref": "main",
    "ref_type": "branch",
    "ref_protected": "true"
  },
  "token_policies": ["ci-demo-app"],
  "token_ttl": "10m",
  "token_max_ttl": "15m",
  "token_no_default_policy": true
}
EOF

# Clé SSH de déploiement (fichier local root:600 -> Vault ; jamais affichée)
vault kv put kv/ci/demo-app/deploy-ssh private_key=@/root/.dgsn/deploy_ed25519 >/dev/null

echo "audit   : $(vault audit list -format=json | jq -r 'keys|join(",")')"
echo "secrets : $(vault secrets list -format=json | jq -r 'keys|join(",")')"
echo "auth    : $(vault auth list -format=json | jq -r 'keys|join(",")')"
vault read -format=json auth/jwt/role/ci-demo-app | jq -c '.data | {bound_claims, bound_audiences, token_policies, token_ttl}'
echo "secrets CI : $(vault kv list -format=json kv/ci/demo-app | jq -r 'join(",")')"
echo "P6_VAULT_CONFIG_OK"
