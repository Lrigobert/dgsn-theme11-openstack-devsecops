#!/usr/bin/env bash
# Retire les services désactivés dans globals.yml (Heat, fluentd) : kolla-ansible reconfigure
# ne supprime ni leurs conteneurs ni leurs objets Keystone. Exécuté sur VM1. Idempotent.
set -uo pipefail
. ~/kolla-venv/bin/activate
. /etc/kolla/admin-openrc.sh
echo "== Conteneurs =="
ssh -o BatchMode=yes 192.168.100.40 'for c in heat_api heat_api_cfn heat_engine fluentd; do
  sudo docker rm -f "$c" >/dev/null 2>&1 && echo "supprimé : $c" || echo "absent : $c"; done
  sudo docker volume rm fluentd_data >/dev/null 2>&1 && echo "volume fluentd_data supprimé" || true'
echo "== Keystone (services, endpoints, utilisateurs Heat) =="
for s in heat heat-cfn; do
  for e in $(openstack endpoint list --service "$s" -f value -c ID 2>/dev/null); do openstack endpoint delete "$e"; done
  openstack service delete "$s" 2>/dev/null && echo "service $s supprimé" || echo "service $s absent"
done
for u in heat heat-cfn heat_domain_admin; do
  openstack user delete "$u" 2>/dev/null && echo "utilisateur $u supprimé" || true
done
openstack domain show heat_user_domain >/dev/null 2>&1 && {
  openstack domain set --disable heat_user_domain && openstack domain delete heat_user_domain && echo "domaine heat_user_domain supprimé"; }
openstack service list -f value -c Name | sort | tr '\n' ' '; echo
echo "CLEANUP_OK"
