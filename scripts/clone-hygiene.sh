#!/usr/bin/env bash
# Hygiène d'un clone de VM1 : retire les secrets et accès hérités du poste de déploiement.
# (passwords Kolla, identifiants OpenStack, clé SSH de VM1 vers controller, venv, état Terraform)
# Exécuté en root sur le clone. Ne touche ni ~/.ssh/authorized_keys ni la configuration système.
set -u
U=/home/jacques1
for p in /etc/kolla $U/dgsn/secrets $U/dgsn/kolla $U/dgsn/inventory $U/dgsn/terraform \
         $U/dgsn/logs $U/dgsn/logs-2024.1-echec $U/dgsn/ansible $U/dgsn/scripts \
         $U/kolla-venv $U/.ssh/id_ed25519 $U/.ssh/id_ed25519.pub $U/.ssh/known_hosts \
         $U/.ssh/known_hosts.old $U/.ssh/known_hosts_p4 $U/.ansible $U/.terraform.d \
         $U/.config/openstack; do
  [ -e "$p" ] && { rm -rf "$p"; echo "supprimé : $p"; }
done
history -c 2>/dev/null; : > $U/.bash_history
echo "--- contrôle : fichiers sensibles restants"
find / -xdev \( -name 'passwords.yml' -o -name 'p3-*.env' -o -name 'admin-openrc*.sh' -o -name 'clouds.yaml' \) 2>/dev/null | grep -v '^/proc' || echo "aucun"
echo "authorized_keys : $(grep -c '^ssh-' $U/.ssh/authorized_keys) clé(s)"
echo "CLONE_HYGIENE_OK"
