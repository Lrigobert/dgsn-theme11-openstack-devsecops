#!/usr/bin/env bash
# Phase 9 — mesure du failover (VM1). Sonde HTTP horodatée (0,5 s) sur le NodePort du serveur k3s pendant
# l'arrêt BRUTAL d'un agent (virsh destroy dans nova_libvirt sur le controller = coupure électrique).
# Usage : p9-failover.sh <ip_serveur> <nom_instance_victime>
set -uo pipefail
SRV=$1; VICTIM=$2; OUT=~/dgsn/logs/p9; mkdir -p $OUT; LOG=$OUT/sonde.csv
. ~/kolla-venv/bin/activate; unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env
# Nom libvirt de l'instance victime : attribut admin -> credentials admin ; l'instance appartient au
# projet dgsn-ops, d'où la recherche --all-projects par nom exact
unset ${!OS_*}; . /etc/kolla/admin-openrc.sh
VID=$(openstack server list --all-projects --name "^${VICTIM}\$" -f value -c ID | head -1)
DOM=$(openstack server show "$VID" -f value -c OS-EXT-SRV-ATTR:instance_name)
[ -n "$DOM" ] || { echo "ERREUR : domaine libvirt introuvable pour $VICTIM"; exit 1; }
echo "victime : $VICTIM ($VID, domaine libvirt $DOM)"
: > $LOG
( while :; do
    t=$(date +%s.%N)
    r=$(curl -s -m 1 -o /tmp/w.txt -w '%{http_code}' "http://$SRV:30080/" 2>/dev/null)
    h=$(grep -m1 '^Hostname:' /tmp/w.txt 2>/dev/null | awk '{print $2}')
    echo "$t,$r,$h" >> $LOG; sleep 0.5
  done ) & PROBE=$!
sleep 20                                     # ligne de base (3 répliques servies)
T_KILL=$(date +%s.%N); echo "arrêt brutal à $(date -Is)"
ssh -o BatchMode=yes 192.168.100.40 "sudo docker exec nova_libvirt virsh destroy $DOM" || { kill $PROBE; echo "ERREUR : arrêt brutal non effectué"; exit 1; }
sleep 90                                     # observation de la reprise
kill $PROBE; wait $PROBE 2>/dev/null
python3 - "$LOG" "$T_KILL" <<'EOF'
import csv, sys
rows = [(float(t), c, h) for t, c, h in csv.reader(open(sys.argv[1]))]
tk = float(sys.argv[2])
before = [r for r in rows if r[0] < tk]; after = [r for r in rows if r[0] >= tk]
ko = [r for r in after if r[1] != "200"]
print(f"sondes : {len(rows)} (avant arrêt {len(before)}, après {len(after)})")
print(f"avant arrêt : {sum(r[1]=='200' for r in before)}/{len(before)} OK, répliques vues : {sorted({r[2] for r in before if r[2]})}")
if ko:
    first, last = ko[0][0] - tk, ko[-1][0] - tk
    print(f"échecs après arrêt : {len(ko)}/{len(after)} ; 1er échec à +{first:.1f} s ; dernier échec à +{last:.1f} s")
    print(f"TEMPS DE REPRISE (arrêt -> dernier échec) : {last:.1f} s")
else:
    print("aucun échec observé : TEMPS DE REPRISE 0 s (bascule transparente)")
tail = after[-20:]
print(f"fin d'observation : {sum(r[1]=='200' for r in tail)}/{len(tail)} OK, répliques vues : {sorted({r[2] for r in tail if r[2]})}")
EOF
