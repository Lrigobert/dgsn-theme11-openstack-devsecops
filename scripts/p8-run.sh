#!/usr/bin/env bash
# Phase 8 — orchestration (VM1, dans tmux « p8 ») : instances -> scan avant -> remédiation -> scan après.
# Journal : ~/dgsn/logs/p8/status.txt et un fichier par étape. Usage : p8-run.sh [etape_de_depart]
set -uo pipefail
. ~/kolla-venv/bin/activate; unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env
L=~/dgsn/logs/p8; mkdir -p $L; S=$L/status.txt
TF=~/dgsn/terraform/p8; AN=~/dgsn/ansible/p8
export ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_CALLBACKS_ENABLED=profile_tasks
# Seule exclusion : bug SSG 0.1.82 (paquet NetworkManager inexistant sous Debian 12)
SKIP=wireless_disable_interfaces
run() { local n=$1; shift; local t0=$(date +%s); echo "$(date -Is) START $n" >> $S
  if "$@" > $L/$n.log 2>&1; then echo "$(date -Is) OK    $n ($(( $(date +%s)-t0 )) s)" >> $S
  else echo "$(date -Is) FAIL  $n ($(( $(date +%s)-t0 )) s)" >> $S; exit 1; fi; }
inventory() {
  cd $TF && terraform output -json ips | python3 -c '
import sys, json
print("[scap]")
for n, ip in sorted(json.load(sys.stdin).items()): print(f"{n} ansible_host={ip}")
print("[scap:vars]\nansible_user=debian\nansible_python_interpreter=/usr/bin/python3")' > $AN/inventory.ini
  cat $AN/inventory.ini
}
START=${1:-apply}; go=0
for e in apply scan-avant remediation scan-apres; do
  [ "$e" = "$START" ] && go=1; [ $go = 1 ] || continue
  case $e in
    apply)       run apply bash -c "cd $TF && terraform init -input=false -no-color >/dev/null && terraform apply -input=false -auto-approve -no-color"; inventory >> $L/apply.log ;;
    scan-avant)  run scan-avant  bash -c "cd $AN && ansible-playbook -i inventory.ini scan.yml -e etape=avant" ;;
    remediation) run remediation bash -c "cd $AN && ansible-playbook -i inventory.ini remediation.yml --become --skip-tags $SKIP" ;;   # playbook SSG : exécution root attendue
    scan-apres)  run scan-apres  bash -c "cd $AN && ansible-playbook -i inventory.ini scan.yml -e etape=apres" ;;
  esac
done
echo "$(date -Is) P8_RUN_DONE" >> $S
