#!/usr/bin/env bash
# Phase 4 — cycle Terraform + Ansible + tests (exécuté sur VM1).
# Usage : p4-cycle.sh apply   -> terraform apply + ansible + tests, durée mesurée
#         p4-cycle.sh destroy -> terraform destroy, durée mesurée
set -uo pipefail
. ~/kolla-venv/bin/activate
unset ${!OS_*}
. ~/dgsn/secrets/p3-dgsn-ops-admin.env      # projet dgsn-ops (secrets sur VM1 uniquement)
TF=~/dgsn/terraform/p4
AN=~/dgsn/ansible/p4
r=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; r=1; }

case "${1:-}" in
apply)
  rm -f ~/.ssh/known_hosts_p4              # nouvelles instances = nouvelles clés hôte
  cd "$TF" && terraform init -input=false -upgrade >/dev/null || exit 1
  T0=$(date +%s)
  terraform apply -input=false -auto-approve -no-color > /tmp/p4-apply.log 2>&1 || { tail -30 /tmp/p4-apply.log; exit 1; }
  T1=$(date +%s)
  echo "terraform apply : $((T1-T0)) s ($(grep -o 'Apply complete.*' /tmp/p4-apply.log))"
  cd "$AN" && ansible-playbook site.yml > /tmp/p4-ansible.log 2>&1; arc=$?
  T2=$(date +%s)
  grep -A8 'PLAY RECAP' /tmp/p4-ansible.log | grep -E 'ok='
  echo "ansible-playbook : $((T2-T1)) s (rc=$arc)"
  TOTAL=$((T2-T0))
  echo "TOTAL apply + configuration : ${TOTAL} s ($((TOTAL/60)) min $((TOTAL%60)) s)"
  [ $arc = 0 ] && pass "Ansible sans erreur sur les 5 instances" || fail "Ansible rc=$arc"
  [ $TOTAL -lt 600 ] && pass "durée ${TOTAL} s < 600 s" || fail "durée ${TOTAL} s >= 600 s"

  echo "== Tests =="
  cd "$TF"
  n=$(openstack server list --name '^dgsn-p4-' --status ACTIVE -f value -c Name | wc -l)
  [ "$n" = 5 ] && pass "5 instances ACTIVE" || fail "$n instances ACTIVE"
  B=$(terraform output -json floating_ips | python3 -c 'import sys,json;print(json.load(sys.stdin)["bastion-1"])')
  for w in web-1 web-2; do
    ip=$(terraform output -json floating_ips | python3 -c "import sys,json;print(json.load(sys.stdin)['$w'])")
    out=$(curl -s --max-time 10 "http://$ip/")
    echo "$out" | grep -q "$w" && pass "HTTP $w ($ip) : $out" || fail "HTTP $w ($ip)"
    nc -z -w5 "$ip" 22 && fail "SSH direct vers $w ouvert (doit passer par le bastion)" || pass "SSH direct vers $w ($ip) refusé : accès uniquement via bastion"
  done
  APP=$(terraform output -json private_ips | python3 -c 'import sys,json;print(json.load(sys.stdin)["app-1"])')
  DB=$(terraform output -json private_ips | python3 -c 'import sys,json;print(json.load(sys.stdin)["db-1"])')
  cd "$AN"
  ansible web-1 -m command -a "curl -s --max-time 5 http://$APP:8080/" -o 2>/dev/null | grep -q 'app-1' \
    && pass "web-1 -> app-1:8080 autorisé" || fail "web-1 -> app-1:8080"
  ansible bastion-1 -m command -a "curl -s --max-time 5 http://$APP:8080/" -o >/dev/null 2>&1 \
    && fail "bastion -> app-1:8080 ouvert (non prévu)" || pass "bastion -> app-1:8080 bloqué (seul web autorisé)"
  ansible web-1 -m command -a "timeout 5 bash -c 'echo > /dev/tcp/$DB/5432'" -o >/dev/null 2>&1 \
    && fail "web-1 -> db-1:5432 ouvert (non prévu)" || pass "web-1 -> db-1:5432 bloqué (seul app autorisé)"
  ansible all -m command -a "cat /etc/dgsn-role" -o 2>/dev/null | sed 's/ (stdout)//' | sort
  [ $r = 0 ] && echo "P4_APPLY_PASS" || echo "P4_APPLY_FAIL"
  exit $r ;;
destroy)
  cd "$TF"
  T0=$(date +%s)
  terraform destroy -input=false -auto-approve -no-color > /tmp/p4-destroy.log 2>&1 || { tail -30 /tmp/p4-destroy.log; exit 1; }
  echo "terraform destroy : $(( $(date +%s)-T0 )) s ($(grep -o 'Destroy complete.*' /tmp/p4-destroy.log))"
  # Nova peut encore lister brièvement des instances en statut DELETED
  for i in $(seq 1 30); do
    n=$(openstack server list --name '^dgsn-p4-' -f value -c Name | wc -l); [ "$n" = 0 ] && break; sleep 2
  done
  [ "$n" = 0 ] && echo "PASS  0 instance restante" || { echo "FAIL  $n instances restantes"; exit 1; }
  echo "P4_DESTROY_PASS" ;;
*) echo "usage: $0 apply|destroy"; exit 2 ;;
esac
