# /etc/vault.d/vault.hcl — HashiCorp Vault (lab DGSN, nœud unique sur la VM gitlab)
ui            = true
disable_mlock = true            # recommandé avec le stockage intégré Raft
api_addr      = "https://192.168.100.50:8200"
cluster_addr  = "https://192.168.100.50:8201"

storage "raft" {
  path    = "/opt/vault/data"
  node_id = "gitlab"
}

listener "tcp" {
  address                  = "0.0.0.0:8200"
  tls_cert_file            = "/opt/vault/tls/vault.crt"
  tls_key_file             = "/opt/vault/tls/vault.key"
  tls_client_ca_file       = "/opt/vault/tls/dgsn-root-ca.crt"
  tls_min_version          = "tls12"
  # mTLS : le certificat client est vérifié S'IL est présenté (poste d'admin), sans être exigé
  # pour la CI qui s'authentifie par JWT. Exigence stricte = perspective (voir rapport).
  tls_require_and_verify_client_cert = false
}
