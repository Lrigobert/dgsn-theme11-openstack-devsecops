#!/usr/bin/env bash
# Démarre l'instance applicative dgsn-app-1 si elle est arrêtée (après un redémarrage du controller). VM1.
. ~/kolla-venv/bin/activate; unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env
st=$(openstack server show dgsn-app-1 -f value -c status)
[ "$st" = SHUTOFF ] && openstack server start dgsn-app-1
for i in $(seq 1 30); do st=$(openstack server show dgsn-app-1 -f value -c status); [ "$st" = ACTIVE ] && break; sleep 4; done
echo "dgsn-app-1 : $st"
for i in $(seq 1 40); do curl -sf --max-time 3 http://$(cat ~/dgsn/p5-app-ip)/health && break; sleep 5; done; echo
