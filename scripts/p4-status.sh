#!/usr/bin/env bash
# État du cycle P4 (exécuté sur VM1) : instances du projet dgsn-ops, session tmux, statut, mesures.
. ~/kolla-venv/bin/activate
. ~/dgsn/secrets/p3-dgsn-ops-admin.env
echo "instances dgsn-ops : $(openstack server list -f value -c Name | wc -l)"
tmux ls 2>&1 | sed 's/^/tmux : /'
echo "--- status"; cat ~/dgsn/logs/p4/status.txt 2>/dev/null
echo "--- mesures"; grep -hE 'terraform (apply|destroy) :|ansible-playbook :|TOTAL|PASS|FAIL' ~/dgsn/logs/p4/*.txt 2>/dev/null
