#!/usr/bin/env bash
# Phase 9 — orchestration (VM1, tmux « p9 ») : rafale d'instances, cluster k3s 3 nœuds, charge HTTP,
# failover mesuré, restauration, destruction. Journal : ~/dgsn/logs/p9/. Usage : p9-run.sh [etape]
set -uo pipefail
. ~/kolla-venv/bin/activate
L=~/dgsn/logs/p9; mkdir -p $L; S=$L/status.txt
TF=~/dgsn/terraform/p9; AN=~/dgsn/ansible/p9; SC=~/dgsn/scripts
export ANSIBLE_HOST_KEY_CHECKING=False K3S_VERSION=v1.37.1+k3s1
WHOAMI=traefik/whoami:v1.12.0
run() { local n=$1; shift; local t0=$(date +%s); echo "$(date -Is) START $n" >> $S
  if "$@" > $L/$n.log 2>&1; then echo "$(date -Is) OK    $n ($(( $(date +%s)-t0 )) s)" >> $S
  else echo "$(date -Is) FAIL  $n ($(( $(date +%s)-t0 )) s)" >> $S; exit 1; fi; }
ops() { unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env; }
srv() { cd $TF && terraform output -json ips | python3 -c 'import sys,json; print(json.load(sys.stdin)["k3s-1"]["public"])'; }
KS="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

prep() {   # flavor agents + arrêt de l'instance applicative P5 pendant P9 (RAM du controller)
  unset ${!OS_*}; . /etc/kolla/admin-openrc.sh
  openstack flavor show dgsn.k3s >/dev/null 2>&1 || openstack flavor create dgsn.k3s --vcpus 1 --ram 768 --disk 5 --public >/dev/null
  ops; [ "$(openstack server show dgsn-app-1 -f value -c status)" = ACTIVE ] && openstack server stop dgsn-app-1; true
  command -v ab >/dev/null || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq apache2-utils >/dev/null
}
inventory() {
  cd $TF && terraform output -json ips | python3 -c '
import sys, json
d = json.load(sys.stdin)
line = lambda n: "%s ansible_host=%s private_ip=%s" % (n, d[n]["public"], d[n]["private"])
print("[k3s_server]"); print(line("k3s-1"))
print("[k3s_agent]"); print(line("k3s-2")); print(line("k3s-3"))
print("[k3s:children]\nk3s_server\nk3s_agent\n[k3s:vars]\nansible_user=debian\nansible_python_interpreter=/usr/bin/python3")' > $AN/inventory.ini
}
app() {
  local s; s=$(srv)
  sed "s#__WHOAMI_IMAGE__#$WHOAMI#" $AN/app-ha.yaml | $KS debian@$s "sudo k3s kubectl apply -f -"
  $KS debian@$s "sudo k3s kubectl rollout status deploy/dgsn-whoami --timeout=600s && sudo k3s kubectl get pods -o wide"
}
charge() {
  local s; s=$(srv)
  # Ventilation des « Failed requests » d'ab : « Length » = taille de réponse variable (whoami répond avec le
  # nom de la réplique), pas une erreur ; les vraies erreurs sont Connect/Receive/Exceptions et Non-2xx.
  ab -q -n 3000 -c 20 -s 10 "http://$s:30080/" | grep -E 'Complete requests|Failed requests|Connect:|Non-2xx|Requests per second|Time per request.*mean\)|  50%|  95%|  99%|longest'
}
failover() {
  local s; s=$(srv)
  ops; bash $SC/p9-failover.sh $s k3s-3
  echo "--- état du cluster après la panne"
  $KS debian@$s "sudo k3s kubectl get nodes; sudo k3s kubectl get pods -o wide"
}

START=${1:-prep}; go=0
for e in prep burst apply k3s app charge failover restore destroy; do
  [ "$e" = "$START" ] && go=1; [ $go = 1 ] || continue
  case $e in
    prep)     run prep prep ;;
    burst)    run burst bash -c "bash $SC/p9-burst.sh 8" ;;
    apply)    ops; run apply bash -c "cd $TF && terraform init -input=false -no-color >/dev/null && terraform apply -input=false -auto-approve -no-color"; inventory ;;
    k3s)      run k3s bash -c "cd $AN && ansible-playbook -i inventory.ini k3s.yml" ;;
    app)      run app app ;;
    charge)   run charge charge ;;
    failover) run failover failover ;;
    restore)  run restore bash -c "bash $SC/p9-restore.sh" ;;
    destroy)  ops; run destroy bash -c "cd $TF && terraform destroy -input=false -auto-approve -no-color | tail -1; . ~/dgsn/secrets/p3-dgsn-ops-admin.env; openstack server start dgsn-app-1" ;;
  esac
done
echo "$(date -Is) P9_RUN_DONE" >> $S
