#!/usr/bin/env bash
# Libère les IP flottantes non associées (status DOWN, sans port) de tous les projets. Exécuté sur VM1.
. ~/kolla-venv/bin/activate
. /etc/kolla/admin-openrc.sh
n=0
for id in $(openstack floating ip list -f value -c ID -c Port | awk '$2=="None" {print $1}'); do
  openstack floating ip delete "$id" && n=$((n+1))
done
echo "IP flottantes libérées : $n ; restantes : $(openstack floating ip list -f value -c ID | wc -l)"
