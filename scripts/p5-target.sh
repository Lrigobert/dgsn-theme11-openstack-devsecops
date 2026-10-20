#!/usr/bin/env bash
# Phase 5 — instance cible du déploiement (VM1). Usage : p5-target.sh prep | apply <fichier.pub> | destroy
set -euo pipefail
. ~/kolla-venv/bin/activate
TF=~/dgsn/terraform/p5
case "${1:-}" in
prep)
  . /etc/kolla/admin-openrc.sh
  openstack flavor show dgsn.app >/dev/null 2>&1 || openstack flavor create dgsn.app --vcpus 1 --ram 1024 --disk 8 --public >/dev/null
  openstack flavor show dgsn.app -f value -c name -c vcpus -c ram -c disk
  unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env
  cd $TF && terraform init -input=false -no-color | tail -1 ;;
apply)
  unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env
  cd $TF
  t0=$(date +%s)
  terraform apply -input=false -auto-approve -no-color -var "deploy_public_key=$(cat "$2")" > /tmp/p5-apply.log 2>&1 || { tail -20 /tmp/p5-apply.log; exit 1; }
  IP=$(terraform output -raw app_ip)
  echo "terraform apply : $(( $(date +%s)-t0 )) s ; instance dgsn-app-1 ; IP flottante $IP"
  # Attente de cloud-init (installation de Docker sous qemu)
  for i in $(seq 1 90); do
    ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts_p5 \
      debian@$IP 'test -f /var/lib/dgsn-cloud-init-done && sudo docker version --format "docker {{.Server.Version}}"' 2>/dev/null && break
    sleep 10
  done
  echo "prête après $(( $(date +%s)-t0 )) s"
  echo "$IP" > ~/dgsn/p5-app-ip ;;
destroy)
  unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env
  cd $TF && terraform destroy -input=false -auto-approve -no-color -var "deploy_public_key=x" | tail -1 ;;
*) echo "usage: $0 prep | apply <pub> | destroy"; exit 2 ;;
esac
