#!/usr/bin/env bash
# Phase 9 — test de charge du plan de contrôle : création simultanée de N instances (VM1).
# Mesure : durée jusqu'à N instances ACTIVE, taux de succès ; puis suppression. Usage : p9-burst.sh [N]
set -uo pipefail
N=${1:-8}
. ~/kolla-venv/bin/activate; unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env
NET=$(openstack network show demo-net -f value -c id 2>/dev/null || openstack network list --internal -f value -c ID | head -1)
t0=$(date +%s.%N)
openstack server create burst --image cirros --flavor m1.tiny --nic net-id=$NET --min $N --max $N -f value -c id >/dev/null
api=$(python3 -c "import time; print(round(time.time()-$t0,1))")
echo "appel API (création de $N instances) : ${api} s"
for i in $(seq 1 120); do
  act=$(openstack server list --name '^burst' --status ACTIVE -f value -c ID | wc -l)
  err=$(openstack server list --name '^burst' --status ERROR -f value -c ID | wc -l)
  [ $((act + err)) -ge $N ] && break; sleep 5
done
tot=$(python3 -c "import time; print(round(time.time()-$t0,1))")
echo "instances ACTIVE : $act/$N ; ERROR : $err ; durée jusqu'à l'état final : ${tot} s ; débit : $(python3 -c "print(round($act/$tot*60,1))") instances/min"
ssh -o BatchMode=yes 192.168.100.40 "free -m | awk '/^Mem/ {print \"controller : RAM disponible \" \$7 \" Mo\"}'; cat /sys/kernel/mm/ksm/pages_sharing | awk '{print \"KSM : \" int(\$1*4/1024) \" Mo partagés\"}'"
t1=$(date +%s)
openstack server delete --wait $(openstack server list --name '^burst' -f value -c ID)
echo "suppression des $N instances : $(( $(date +%s)-t1 )) s"
[ "$act" = "$N" ] && echo "P9_BURST_PASS" || echo "P9_BURST_FAIL"
