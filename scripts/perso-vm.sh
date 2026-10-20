#!/usr/bin/env bash
# Personnalisation d'un clone de VM1 (Ubuntu 22.04) : nom, IP de gestion, identités uniques,
# disque, swap. Exécuté en root sur le clone. Idempotent. Ne redémarre pas.
# Usage : perso-vm.sh <hostname> <ip/24> [swap_Go]
# Interfaces du clone de VM1 : ens33 = VMnet1 (gestion), ens37 = VMnet8 (NAT, DHCP).
set -euo pipefail
NEW_HOST=$1; MGMT_IP=$2; SWAP_GO=${3:-4}

echo "== Disque =="
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS | grep -v loop
ROOT_LV=$(findmnt -no SOURCE /)
PV=$(pvs --noheadings -o pv_name | awk '{print $1}' | head -n1)
DISK=/dev/$(lsblk -dno PKNAME "$PV")
PARTNUM=$(cat /sys/class/block/"$(basename "$PV")"/partition)
growpart "$DISK" "$PARTNUM" || echo "growpart : rien à agrandir"
pvresize "$PV"
if [ "$(vgs --noheadings --units b -o vg_free | tr -dc 0-9)" -gt 0 ]; then lvextend -r -l +100%FREE "$ROOT_LV"; fi
df -h / | tail -1

echo "== Swap ${SWAP_GO} Go =="
cur=$(( $(stat -c %s /swap.img 2>/dev/null || echo 0) / 1024 / 1024 / 1024 ))
if [ "$cur" -lt "$SWAP_GO" ]; then
  swapoff /swap.img 2>/dev/null || true
  fallocate -l "${SWAP_GO}G" /swap.img && chmod 600 /swap.img && mkswap /swap.img >/dev/null
  grep -q '^/swap.img' /etc/fstab || echo '/swap.img none swap sw 0 0' >> /etc/fstab
  swapon /swap.img
fi
swapon --show

echo "== Hostname et /etc/hosts =="
hostnamectl set-hostname "$NEW_HOST"
sed -i '/^127\.0\.1\.1/d' /etc/hosts
sed -i '/# DGSN-LAB BEGIN/,/# DGSN-LAB END/d' /etc/hosts
cat >> /etc/hosts <<'EOF'
# DGSN-LAB BEGIN
192.168.100.1   pfsense
192.168.100.10  serveurs1 vm1
192.168.100.30  vm4 monitoring
192.168.100.40  controller
192.168.100.41  compute2
192.168.100.45  openstack-vip
192.168.100.50  gitlab
# DGSN-LAB END
EOF

echo "== Réseau =="
mkdir -p /etc/cloud/cloud.cfg.d
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
mkdir -p /root/netplan-backup
find /etc/netplan -maxdepth 1 -name '*.yaml' ! -name '01-dgsn.yaml' -exec mv {} /root/netplan-backup/ \;
cat > /etc/netplan/01-dgsn.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      dhcp4: false
      dhcp6: false
      addresses: [$MGMT_IP]
      routes:
        - {to: 192.168.10.0/24, via: 192.168.100.254}
        - {to: 192.168.20.0/24, via: 192.168.100.254}
        - {to: 192.168.30.0/24, via: 192.168.100.254}
        - {to: 192.168.110.0/24, via: 192.168.100.254}
        - {to: 192.168.120.0/24, via: 192.168.100.254}
    ens37:
      dhcp4: true
      dhcp6: false
EOF
chmod 600 /etc/netplan/01-dgsn.yaml
netplan generate

MARK=/var/lib/dgsn/perso-ids-regenerated
if [ ! -f "$MARK" ]; then
  echo "== machine-id et clés hôte SSH =="
  rm -f /etc/machine-id /var/lib/dbus/machine-id
  systemd-machine-id-setup
  ln -sf /etc/machine-id /var/lib/dbus/machine-id
  rm -f /etc/ssh/ssh_host_*
  ssh-keygen -A
  mkdir -p "$(dirname "$MARK")" && date -Is > "$MARK"
fi
echo "PERSO_OK host=$NEW_HOST ip=$MGMT_IP machine-id=$(cat /etc/machine-id)"
