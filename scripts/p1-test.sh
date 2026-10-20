#!/usr/bin/env bash
# Test d'acceptation P1 (exécuté sur controller). Affiche PASS/FAIL par critère.
r=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; r=1; fi; }

echo "hostname=$(hostname)  machine-id=$(cat /etc/machine-id)"
ip -br a; ip route; df -h / | tail -1

chk "hostname = controller"                 '[ "$(hostname)" = controller ]'
# Après le déploiement Kolla, keepalived ajoute la VIP 192.168.100.45 sur ens33 : seules .40 (+ VIP) sont admises
chk "ens33 = 192.168.100.40/24 (+ VIP .45 keepalived), pas de DHCP" \
    '[ "$(ip -4 -o addr show ens33 | awk "{print \$4}" | grep -vxE "192\.168\.100\.(40/24|45/32)" | wc -l)" = 0 ] && ip -4 -o addr show ens33 | grep -q "192.168.100.40/24"'
chk "ens37 en DHCP (192.168.232.x)"         'ip -4 -o addr show ens37 | grep -q "192\.168\.232\."'
chk "ens38 UP sans IPv4"                    'ip link show ens38 | grep -q "state UP" && ! ip -4 -o addr show ens38 | grep -q inet'
chk "une seule route par défaut (NAT)"      '[ "$(ip route | grep -c ^default)" = 1 ] && ip route | grep -q "^default via 192.168.232"'
chk "cloud-init réseau désactivé"           'grep -q "config: disabled" /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg'
chk "/ >= 100 Go"                           '[ "$(df -BG --output=size / | tail -1 | tr -dc 0-9)" -ge 100 ]'
chk "/etc/hosts sans 127.0.1.1"             '! grep -q "^127\.0\.1\.1" /etc/hosts'
chk "machine-id régénéré (≠ VM1)"           '[ "$(cat /etc/machine-id)" != bf4e0a5c30e041229e775e53925a9a39 ]'
chk "sudo NOPASSWD"                         'sudo -n true'
chk "pfSense joignable"                     'ping -c2 -W2 192.168.100.1'
chk "Internet joignable (8.8.8.8)"          'ping -c2 -W2 8.8.8.8'
chk "DNS (archive.ubuntu.com)"              'getent hosts archive.ubuntu.com'
[ $r = 0 ] && echo "P1_CONTROLLER_PASS" || echo "P1_CONTROLLER_FAIL"
exit $r
