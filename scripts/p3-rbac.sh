#!/usr/bin/env bash
# Phase 3 — Keystone RBAC DGSN (exécuté sur VM1 avec admin-openrc). Idempotent.
# Projets métier + 1 utilisateur par rôle (admin / member / reader).
# Les mots de passe sont générés aléatoirement et stockés UNIQUEMENT sur VM1 :
#   ~/dgsn/secrets/p3-<user>.env (mode 600) -> migrés vers Vault en phase 6.
set -euo pipefail
. ~/kolla-venv/bin/activate
. /etc/kolla/admin-openrc.sh
SECRETS=~/dgsn/secrets; mkdir -p "$SECRETS"; chmod 700 "$SECRETS"

declare -A DESC=(
  [dgsn-identification]="Identification (titres, biométrie) — données sensibles"
  [dgsn-pj]="Police judiciaire — enquêtes"
  [dgsn-ops]="Exploitation de la plateforme"
)
for p in "${!DESC[@]}"; do
  openstack project show "$p" >/dev/null 2>&1 || openstack project create "$p" --domain default --description "${DESC[$p]}" >/dev/null
done

# utilisateur:projet:rôle
USERS=(
  "dgsn-ops-admin:dgsn-ops:admin"
  "dgsn-pj-member:dgsn-pj:member"
  "dgsn-id-reader:dgsn-identification:reader"
)
for u in "${USERS[@]}"; do
  IFS=: read -r user proj role <<<"$u"
  envf="$SECRETS/p3-$user.env"
  if ! openstack user show "$user" >/dev/null 2>&1; then
    pw=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)
    openstack user create "$user" --domain default --password "$pw" --description "Test RBAC P3 ($role sur $proj)" >/dev/null
    umask 077
    cat > "$envf" <<EOF
export OS_AUTH_URL=$OS_AUTH_URL
export OS_IDENTITY_API_VERSION=3
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USERNAME=$user
export OS_PASSWORD=$pw
export OS_PROJECT_NAME=$proj
export OS_INTERFACE=internal
EOF
  fi
  openstack role add --user "$user" --project "$proj" "$role"
done

echo "== Affectations =="
openstack role assignment list --names -f value -c User -c Role -c Project | grep dgsn | sort
echo "P3_RBAC_OK"
