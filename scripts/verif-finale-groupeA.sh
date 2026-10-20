#!/usr/bin/env bash
# Vérification finale — groupe A (socle : pfSense, controller, VM1), après arrêt/démarrage complet.
# Tests courts : P1, P2, P3, P6 (TLS), P4 (cycle IaC), P8 (chaîne OpenSCAP, scan d'instances neuves), P9 (rafale).
# Exécuté sur VM1 dans tmux « verif ». Résultats : ~/dgsn/logs/verif/
set -uo pipefail
. ~/kolla-venv/bin/activate
L=~/dgsn/logs/verif; mkdir -p $L; S=$L/status.txt; SC=~/dgsn/scripts
run() { local n=$1; shift; local t0=$(date +%s); echo "$(date -Is) START $n" >> $S
  if "$@" > $L/$n.log 2>&1; then echo "$(date -Is) PASS  $n ($(( $(date +%s)-t0 )) s)" >> $S
  else echo "$(date -Is) FAIL  $n ($(( $(date +%s)-t0 )) s)" >> $S; fi; }
ops() { unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env; }

run P1-controller bash -c "scp -q $SC/p1-test.sh 192.168.100.40:/tmp/p1-test.sh && ssh -o BatchMode=yes 192.168.100.40 'bash /tmp/p1-test.sh' | tee /dev/stderr | grep -q P1_CONTROLLER_PASS"
run P2-openstack   bash -c "bash $SC/p2-test.sh && bash $SC/p2-test-cleanup.sh"
run P3-rbac        bash -c "bash $SC/p3-test.sh"
run P6-tls         bash -c "bash $SC/p6-tls-check.sh"
run P4-iac         bash -c "bash $SC/p4-cycle.sh apply && bash $SC/p4-cycle.sh destroy"
run P8-openscap    bash -c "ops; cd ~/dgsn/terraform/p8 && terraform apply -input=false -auto-approve -no-color >/dev/null && \
                     cd ~/dgsn/ansible/p8 && terraform -chdir=$HOME/dgsn/terraform/p8 output -json ips | python3 -c '
import sys, json
print(\"[scap]\"); [print(n, \"ansible_host=\" + ip) for n, ip in sorted(json.load(sys.stdin).items())]
print(\"[scap:vars]\nansible_user=debian\nansible_python_interpreter=/usr/bin/python3\")' > inventory.ini && \
                     ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini scan.yml -e etape=verif | grep -E 'taux_conformite|failed=' ; rc=\${PIPESTATUS[0]}; \
                     terraform -chdir=$HOME/dgsn/terraform/p8 destroy -input=false -auto-approve -no-color | tail -1; exit \$rc"
run P9-charge      bash -c "bash $SC/p9-burst.sh 8"
echo "$(date -Is) VERIF_A_DONE" >> $S
