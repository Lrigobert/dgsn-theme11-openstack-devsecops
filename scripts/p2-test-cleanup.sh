#!/usr/bin/env bash
# Supprime l'instance de test P2 et son IP flottante (libère la RAM avant une phase lourde).
. ~/kolla-venv/bin/activate
. /etc/kolla/admin-openrc.sh
VM=p2-test-cirros
if openstack server show $VM >/dev/null 2>&1; then
  ips=$(openstack server show $VM -f json -c addresses | grep -o '192\.168\.100\.[0-9]*')
  openstack server delete --wait $VM
  for ip in $ips; do openstack floating ip delete "$ip"; done
  echo "$VM supprimée"
else
  echo "$VM absente"
fi
