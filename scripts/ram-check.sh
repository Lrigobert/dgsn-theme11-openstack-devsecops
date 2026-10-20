#!/usr/bin/env bash
# Mesure de la capacité mémoire OpenStack (exécuté sur VM1). Sert avant chaque phase lourde.
. ~/kolla-venv/bin/activate
. /etc/kolla/admin-openrc.sh
echo "== controller =="
ssh -o BatchMode=yes 192.168.100.40 'free -m | sed -n 1,2p; echo "conteneurs: $(sudo docker ps -q | wc -l)"; sudo docker stats --no-stream --format "{{.Name}} {{.MemUsage}}" | sort -k2 -h -r | head -8'
echo "== Placement (inventaire / usage MEMORY_MB, VCPU) =="
RP=$(openstack resource provider list -f value -c uuid | head -1)
openstack resource provider inventory list "$RP" -f value -c resource_class -c total -c reserved -c allocation_ratio
openstack resource provider usage show "$RP" -f value
echo "== Instances =="
openstack server list --all-projects -f value -c Name -c Status -c Flavor
echo "== Flavors =="
openstack flavor list -f value -c Name -c RAM -c VCPUs -c Disk
