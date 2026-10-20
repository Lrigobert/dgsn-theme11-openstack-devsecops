#!/usr/bin/env bash
# Phase 1 — personnalisation du clone "controller" (exécuté en root sur la VM).
# Idempotent. Ne redémarre pas : le redémarrage est lancé ensuite depuis l'hôte.
set -euo pipefail

NEW_HOST=controller
MGMT_IP=192.168.100.40/24
MAC_MGMT=00:0c:29:01:2c:f3   # ethernet0 -> VMnet1 (gestion)
MAC_NAT=00:0c:29:01:2c:fd    # ethernet1 -> VMnet8 (NAT, Internet)
MAC_EXT=00:0c:29:01:2c:07    # ethernet2 -> VMnet1 (externe Neutron, sans IP)

ifname_by_mac() { ip -o link | awk -v m="$1" 'tolower($0) ~ m {sub(":","",$2); print $2}'; }
IF_MGMT=$(ifname_by_mac "$MAC_MGMT"); IF_NAT=$(ifname_by_mac "$MAC_NAT"); IF_EXT=$(ifname_by_mac "$MAC_EXT")
echo "Interfaces : gestion=$IF_MGMT nat=$IF_NAT externe=$IF_EXT"
[ -n "$IF_MGMT" ] && [ -n "$IF_NAT" ] && [ -n "$IF_EXT" ] || { echo "ERREUR: interface introuvable"; exit 1; }

echo "== Disque (avant) =="; lsblk
ROOT_LV=$(findmnt -no SOURCE /)
PV=$(pvs --noheadings -o pv_name | awk '{print $1}' | head -n1)
DISK=/dev/$(lsblk -dno PKNAME "$PV")
PARTNUM=$(cat /sys/class/block/"$(basename "$PV")"/partition)
echo "root=$ROOT_LV pv=$PV disque=$DISK partition=$PARTNUM"
command -v growpart >/dev/null || apt-get install -y cloud-guest-utils
growpart "$DISK" "$PARTNUM" || echo "growpart : rien à agrandir"
pvresize "$PV"
if [ "$(vgs --noheadings --units b -o vg_free | tr -dc 0-9)" -gt 0 ]; then
  lvextend -r -l +100%FREE "$ROOT_LV"
fi
echo "== Disque (après) =="; lsblk; df -h /

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

echo "== Réseau (netplan, cloud-init désactivé) =="
mkdir -p /etc/cloud/cloud.cfg.d
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
mkdir -p /root/netplan-backup
find /etc/netplan -maxdepth 1 -name '*.yaml' ! -name '01-dgsn.yaml' -exec mv {} /root/netplan-backup/ \;
cat > /etc/netplan/01-dgsn.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IF_MGMT:
      match: {macaddress: "$MAC_MGMT"}
      set-name: $IF_MGMT
      dhcp4: false
      dhcp6: false
      addresses: [$MGMT_IP]
      # Routes héritées de VM1 vers les VLAN du lab (routeur 192.168.100.254)
      routes:
        - {to: 192.168.10.0/24, via: 192.168.100.254}
        - {to: 192.168.20.0/24, via: 192.168.100.254}
        - {to: 192.168.30.0/24, via: 192.168.100.254}
        - {to: 192.168.110.0/24, via: 192.168.100.254}
        - {to: 192.168.120.0/24, via: 192.168.100.254}
    $IF_NAT:
      match: {macaddress: "$MAC_NAT"}
      set-name: $IF_NAT
      dhcp4: true
      dhcp6: false
    $IF_EXT:
      match: {macaddress: "$MAC_EXT"}
      set-name: $IF_EXT
      dhcp4: false
      dhcp6: false
      link-local: []
      optional: true
EOF
chmod 600 /etc/netplan/01-dgsn.yaml
netplan generate

MARK=/var/lib/dgsn/p1-ids-regenerated
if [ ! -f "$MARK" ]; then
  echo "== machine-id =="
  rm -f /etc/machine-id /var/lib/dbus/machine-id
  systemd-machine-id-setup
  ln -sf /etc/machine-id /var/lib/dbus/machine-id

  echo "== Clés hôte SSH =="
  rm -f /etc/ssh/ssh_host_*
  ssh-keygen -A
  mkdir -p "$(dirname "$MARK")" && date -Is > "$MARK"
else
  echo "== machine-id et clés hôte déjà régénérés ($(cat "$MARK")) =="
fi

echo "== sudo =="
SUDO_USER_NAME=jacques1
echo "$SUDO_USER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$SUDO_USER_NAME
chmod 440 /etc/sudoers.d/*
visudo -c

echo "P1_SCRIPT_OK interfaces=$IF_MGMT,$IF_NAT,$IF_EXT"
