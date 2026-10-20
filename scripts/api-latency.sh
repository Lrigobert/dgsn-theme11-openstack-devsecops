#!/usr/bin/env bash
# Latence des API OpenStack (moyenne sur N appels) + latence du service de métadonnées. Exécuté sur VM1.
. ~/kolla-venv/bin/activate
. /etc/kolla/admin-openrc.sh
export LC_NUMERIC=C
N=${1:-5}
TOKEN=$(openstack token issue -f value -c id)
for api in "keystone http://192.168.100.45:5000/v3/projects" \
           "nova http://192.168.100.45:8774/v2.1/servers" \
           "neutron http://192.168.100.45:9696/v2.0/networks" \
           "glance http://192.168.100.45:9292/v2/images" \
           "placement http://192.168.100.45:8780/resource_providers"; do
  set -- $api
  tot=0
  for i in $(seq 1 "$N"); do
    t=$(curl -s -o /dev/null -w '%{time_total}' -H "X-Auth-Token: $TOKEN" \
        -H 'OpenStack-API-Version: placement 1.0' "$2")
    tot=$(echo "$tot + $t" | bc -l)
  done
  printf "%-10s moyenne %.0f ms sur %d appels\n" "$1" "$(echo "$tot * 1000 / $N" | bc -l)" "$N"
done
