#!/usr/bin/env bash
# Mise à niveau non interactive Ubuntu 22.04 -> 24.04 du controller (exigence Kolla-Ansible 2025.1).
# À lancer en root dans tmux :  tmux new -d -s upgrade 'sudo bash /tmp/p2-upgrade-noble.sh'
# Journal : /var/log/dgsn-upgrade.log ; état final : /var/lib/dgsn/upgrade-status
set -uo pipefail
exec > >(tee -a /var/log/dgsn-upgrade.log) 2>&1
mkdir -p /var/lib/dgsn
st() { echo "$(date -Is) $*" | tee -a /var/lib/dgsn/upgrade-status; }
export DEBIAN_FRONTEND=noninteractive
# Conserver les fichiers de config locaux (netplan, sudoers, hosts…) sans question
cat > /etc/apt/apt.conf.d/99-dgsn-noninteractive <<'EOF'
Dpkg::Options { "--force-confdef"; "--force-confold"; };
EOF

if [ "$(lsb_release -rs)" = 22.04 ]; then
  st "START mise à jour jammy"
  apt-get update -q && apt-get -y -q dist-upgrade && apt-get -y autoremove || { st "FAIL jammy dist-upgrade"; exit 1; }
  sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades
  # do-release-upgrade refuse de démarrer si un redémarrage est en attente (nouveau noyau)
  if [ -f /var/run/reboot-required ]; then
    st "REBOOT requis avant do-release-upgrade : relancer ce script après redémarrage"
    systemctl reboot; exit 0
  fi
  st "START do-release-upgrade noble"
  do-release-upgrade -f DistUpgradeViewNonInteractive -m server || { st "FAIL do-release-upgrade"; exit 1; }
  if [ "$(lsb_release -rs)" != 24.04 ]; then st "FAIL version $(lsb_release -rs) après upgrade"; exit 1; fi
  st "OK noble installé, redémarrage"
  systemctl reboot
else
  st "DÉJÀ $(lsb_release -ds)"
fi
