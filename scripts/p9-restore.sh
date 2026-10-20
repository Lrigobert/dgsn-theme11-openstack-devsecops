#!/usr/bin/env bash
# Phase 9 — test de restauration (VM1) : instance porteuse d'un fichier témoin -> snapshot Glance ->
# suppression -> restauration depuis le snapshot -> vérification du témoin. Mesure du RTO.
set -uo pipefail
. ~/kolla-venv/bin/activate; unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env
NET=dgsn-p9-net; SG=dgsn-p9-sg; KP=dgsn-p9-admin; KH=~/.ssh/known_hosts_p9r
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$KH"
rm -f $KH
waitssh() { for i in $(seq 1 90); do $SSH debian@$1 true 2>/dev/null && return 0; sleep 10; done; return 1; }
fip() { local ip; ip=$(openstack floating ip create public1 -f value -c floating_ip_address); openstack server add floating ip $1 $ip; echo $ip; }

openstack server create rst-src --image debian-12 --flavor dgsn.k3s --network $NET --security-group $SG --key-name $KP --config-drive true --wait >/dev/null
IP=$(fip rst-src); waitssh $IP || { echo "rst-src injoignable"; exit 1; }
MARK="DGSN-$(date +%s)-$RANDOM"
$SSH debian@$IP "echo $MARK | sudo tee /var/lib/dgsn-temoin >/dev/null; sync"
echo "témoin écrit sur rst-src : $MARK"
t0=$(date +%s)
openstack server image create rst-src --name rst-snap --wait >/dev/null
echo "snapshot Glance : $(( $(date +%s)-t0 )) s ($(openstack image show rst-snap -f value -c size | awk '{printf "%.0f Mo", $1/1048576}'))"
openstack server delete --wait rst-src; openstack floating ip delete $IP
echo "instance source supprimée (incident simulé) à $(date -Is)"
t1=$(date +%s)
openstack server create rst-restored --image rst-snap --flavor dgsn.k3s --network $NET --security-group $SG --key-name $KP --config-drive true --wait >/dev/null
IP2=$(fip rst-restored); waitssh $IP2 || { echo "restauration injoignable"; exit 1; }
GOT=$($SSH debian@$IP2 "sudo cat /var/lib/dgsn-temoin")
RTO=$(( $(date +%s)-t1 ))
echo "témoin lu sur rst-restored : $GOT"
echo "RTO (restauration depuis snapshot jusqu'au service SSH + donnée vérifiée) : ${RTO} s"
openstack server delete --wait rst-restored; openstack floating ip delete $IP2; openstack image delete rst-snap
[ "$GOT" = "$MARK" ] && echo "P9_RESTORE_PASS" || echo "P9_RESTORE_FAIL"
