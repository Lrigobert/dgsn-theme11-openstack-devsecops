# Politique Vault de la CI dgsn/demo-app : lecture seule, uniquement ses secrets.
path "kv/data/ci/demo-app/*" {
  capabilities = ["read"]
}
