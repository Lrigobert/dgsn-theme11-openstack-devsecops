#!/usr/bin/env bash
# Phase 2 — préparation de VM1 (poste de déploiement) : venv Kolla-Ansible 2025.1 (20.x),
# inventaire, globals, mots de passe, clé SSH vers controller. Exécuté en jacques1. Idempotent.
# Fichiers attendus dans ~/dgsn/kolla (copiés depuis C:\DGSN-Theme11\kolla).
# VM1 = Ubuntu 22.04, Python 3.10 -> ansible-core 2.17 (la 2.18 exige Python >= 3.11).
set -euo pipefail
VENV=~/kolla-venv
SRC=~/dgsn/kolla
RELEASE=2025.1

echo "== Paquets système =="
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git python3-dev python3-venv libffi-dev gcc libssl-dev tmux >/dev/null

echo "== venv + Kolla-Ansible 20.x (= $RELEASE Epoxy) =="
if [ -d "$VENV" ] && ! "$VENV/bin/pip" show kolla-ansible 2>/dev/null | grep -q '^Version: 20\.'; then
  echo "venv existant d'une autre série : recréation"; rm -rf "$VENV"
fi
[ -d "$VENV" ] || python3 -m venv "$VENV"
. "$VENV/bin/activate"
pip install -q -U pip
pip install -q 'ansible-core>=2.17,<2.18' 'kolla-ansible>=20,<21' python-openstackclient
pip show kolla-ansible ansible-core | grep -E '^(Name|Version)'

echo "== /etc/kolla =="
sudo mkdir -p /etc/kolla && sudo chown "$USER:$USER" /etc/kolla
SHARE="$VENV/share/kolla-ansible"
cp "$SRC/globals.yml" /etc/kolla/globals.yml
# Surcharges de configuration des services (ex. galera.cnf)
if [ -d "$SRC/config" ]; then mkdir -p /etc/kolla/config && cp -r "$SRC/config/." /etc/kolla/config/; fi
if [ ! -f /etc/kolla/passwords.yml ] || [ "$(cat /etc/kolla/.release 2>/dev/null)" != "$RELEASE" ]; then
  [ -f /etc/kolla/passwords.yml ] && mv /etc/kolla/passwords.yml "/etc/kolla/passwords.yml.old-$(date +%s)"
  cp "$SHARE/etc_examples/kolla/passwords.yml" /etc/kolla/passwords.yml
  kolla-genpwd -p /etc/kolla/passwords.yml
  echo "$RELEASE" > /etc/kolla/.release
  echo "passwords.yml généré pour $RELEASE (reste sur VM1, jamais copié dans le dépôt)"
fi
chmod 600 /etc/kolla/passwords.yml*

echo "== Inventaire multinœud =="
mkdir -p ~/dgsn/inventory
# Groupes de nœuds DGSN + groupes de services du modèle officiel (sans ses premiers groupes de nœuds)
awk 'BEGIN{skip=1} /^\[baremetal:children\]/{skip=0} !skip' "$SHARE/ansible/inventory/multinode" > /tmp/children.ini
cat "$SRC/inventory-hosts.ini" /tmp/children.ini > ~/dgsn/inventory/multinode
grep -c '^\[' ~/dgsn/inventory/multinode | xargs echo "groupes d'inventaire :"

echo "== Collections Ansible (core bornées + kolla stable/$RELEASE) =="
ansible-galaxy collection install --force -r "$SHARE/requirements-core.yml"
ansible-galaxy collection install --force -r "$SRC/requirements.yml"

echo "== Clé SSH VM1 -> controller =="
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 -C "jacques1@vm1-deploy"
echo "P2_SETUP_OK"
