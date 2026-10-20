#!/usr/bin/env bash
# Phase 2 — ressources initiales (init-runonce de kolla-ansible) adaptées au lab DGSN.
# Réseau externe flat "public1" sur physnet1 (= ens38, VMnet1) : 192.168.100.0/24,
# pool d'IP flottantes .200-.230, passerelle pfSense .1. Réseau tenant demo-net en VXLAN.
set -euo pipefail
. ~/kolla-venv/bin/activate
# post-deploy crée admin-openrc.sh / clouds.yaml en root:600 -> propriété à jacques1, mode 600 conservé
for f in /etc/kolla/admin-openrc*.sh /etc/kolla/clouds.yaml; do
  [ -e "$f" ] && sudo chown "$USER:$USER" "$f" && chmod 600 "$f"
done
. /etc/kolla/admin-openrc.sh

if openstack network show public1 >/dev/null 2>&1; then
  echo "init-runonce déjà exécuté (public1 existe)"; exit 0
fi
export ENABLE_EXT_NET=1
export EXT_NET_CIDR='192.168.100.0/24'
export EXT_NET_RANGE='start=192.168.100.200,end=192.168.100.230'
export EXT_NET_GATEWAY='192.168.100.1'
bash ~/kolla-venv/share/kolla-ansible/init-runonce
echo "P2_INIT_OK"
