#!/usr/bin/env bash
# Vérification finale — test court P8 : chaîne OpenSCAP opérationnelle (instances neuves, scan CIS, destruction).
set -uo pipefail
. ~/kolla-venv/bin/activate; unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env
TF=~/dgsn/terraform/p8; AN=~/dgsn/ansible/p8
cd $TF && terraform apply -input=false -auto-approve -no-color | tail -1
terraform -chdir=$TF output -json ips | python3 -c '
import sys, json
print("[scap]"); [print(n, "ansible_host=" + ip) for n, ip in sorted(json.load(sys.stdin).items())]
print("[scap:vars]\nansible_user=debian\nansible_python_interpreter=/usr/bin/python3")' > $AN/inventory.ini
cd $AN && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini scan.yml -e etape=verif > /tmp/verif-p8.log 2>&1; rc=$?
grep -E 'taux_conformite' /tmp/verif-p8.log | sed 's/^ *//'
grep -A3 'PLAY RECAP' /tmp/verif-p8.log | tail -2
terraform -chdir=$TF destroy -input=false -auto-approve -no-color | tail -1
[ $rc = 0 ] && echo "P8_VERIF_PASS" || echo "P8_VERIF_FAIL"
