#!/usr/bin/env bash
# Phase 8 — analyse finale (VM1) : non-conformités restantes par sévérité, échecs tolérés, preuve Fail2Ban.
set -uo pipefail
. ~/kolla-venv/bin/activate; unset ${!OS_*}; . ~/dgsn/secrets/p3-dgsn-ops-admin.env
R=~/dgsn/p8-reports; AN=~/dgsn/ansible/p8
echo "== Règles encore en échec après remédiation (scap-1), par sévérité"
python3 - $R/scap-1/oscap-apres-results.xml <<'EOF'
import sys, collections, xml.etree.ElementTree as ET
ns = {"x": "http://checklists.nist.gov/xccdf/1.2"}
r = ET.parse(sys.argv[1]).getroot()
tr = r.find(".//x:TestResult", ns)
fails = [(rr.get("severity"), rr.get("idref").split("content_rule_")[-1]) for rr in tr.findall("x:rule-result", ns) if rr.find("x:result", ns).text == "fail"]
print("par sévérité :", dict(collections.Counter(s for s, _ in fails)))
for sev in ("high", "medium", "low", "unknown"):
    for s, rid in sorted(fails):
        if s == sev: print(f"  [{s}] {rid}")
EOF
echo "== Tâches en échec toléré pendant la remédiation"
grep -E '^(fatal|failed): \[scap-1\]' ~/dgsn/logs/p8/remediation.log -B2 | grep -E '^TASK' | sed 's/TASK \[//; s/\] \**$//' | sort -u
echo "== Fail2Ban"
IP1=$(awk '/scap-1/ {sub("ansible_host=","",$2); print $2}' $AN/inventory.ini)
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
$SSH debian@$IP1 "sudo systemctl is-active fail2ban; sudo fail2ban-client status sshd | grep -E 'Currently|Total'"
# Attaquant simulé : le controller (192.168.100.40), autorisé temporairement sur le port 22
RID=$(openstack security group rule create dgsn-p8-sg --protocol tcp --dst-port 22 --remote-ip 192.168.100.40/32 -f value -c id)
echo "règle temporaire SSH depuis 192.168.100.40 : $RID"
ssh -o BatchMode=yes 192.168.100.40 "for i in 1 2 3 4 5; do ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 attaquant\$i@$IP1 true 2>/dev/null; done; echo tentatives envoyées"
sleep 5
$SSH debian@$IP1 "sudo fail2ban-client status sshd | grep -E 'Currently banned|Total banned|Banned IP'"
r=$(ssh -o BatchMode=yes 192.168.100.40 "timeout 8 bash -c 'echo > /dev/tcp/$IP1/22' 2>/dev/null && echo ouvert || echo bloqué")
echo "connexion TCP 22 depuis l'attaquant après bannissement : $r"
$SSH debian@$IP1 "sudo fail2ban-client set sshd unbanip 192.168.100.40 >/dev/null; sudo fail2ban-client status sshd | grep 'Currently banned'"
openstack security group rule delete "$RID" && echo "règle temporaire supprimée"
echo "== SSH d'administration (VM1, ignoreip) toujours possible : $($SSH debian@$IP1 hostname)"
