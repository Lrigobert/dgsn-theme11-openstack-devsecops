#!/usr/bin/env bash
# Phase 6 — test négatif : un pipeline sur une branche NON protégée ne doit pas obtenir les secrets Vault.
# Root sur gitlab. Résultat attendu : job openstack-preflight en échec, « Vault : connexion REFUSÉE ».
set -uo pipefail
D=/root/.dgsn; H="PRIVATE-TOKEN: $(cat $D/gitlab-pat)"; PID=$(cat $D/project-id)
API=http://192.168.100.50/api/v4; W=/root/demo-app-repo; B=feature/test-vault
OUT=/home/jacques1/dgsn/p5-reports/branche-non-protegee; mkdir -p $OUT
cd $W && git checkout -q main && git checkout -q -B $B
git -c user.name="DGSN CI" -c user.email="ci@dgsn.lab" commit -q --allow-empty -m "test : accès Vault depuis une branche non protégée"
SHA=$(git rev-parse HEAD); git push -q -f origin $B 2>&1 | grep -v oauth2; git checkout -q main
for i in $(seq 1 30); do
  PL=$(curl -s -H "$H" "$API/projects/$PID/pipelines?sha=$SHA" | python3 -c 'import sys,json; p=json.load(sys.stdin); print(p[0]["id"] if p else "")'); [ -n "$PL" ] && break; sleep 2
done
while :; do
  ST=$(curl -s -H "$H" "$API/projects/$PID/pipelines/$PL" | python3 -c 'import sys,json; print(json.load(sys.stdin)["status"])')
  case $ST in success|failed|canceled|skipped) break;; esac; sleep 10
done
echo "pipeline $PL sur $B : $ST"
curl -s -H "$H" "$API/projects/$PID/pipelines/$PL/jobs?per_page=50" | python3 -c '
import sys,json
for j in sorted(json.load(sys.stdin), key=lambda j: j["id"]): print("  job %-20s %s" % (j["name"], j["status"]))'
JID=$(curl -s -H "$H" "$API/projects/$PID/pipelines/$PL/jobs" | python3 -c 'import sys,json; print([j["id"] for j in json.load(sys.stdin) if j["name"]=="openstack-preflight"][0])')
curl -s -H "$H" "$API/projects/$PID/jobs/$JID/trace" > $OUT/openstack-preflight.log
echo "--- extrait du job openstack-preflight :"
sed 's/\x1b\[[0-9;]*[mK]//g' $OUT/openstack-preflight.log | grep -E 'Vault|Keystone|Nova' | sed 's/^[0-9TZ:.-]* [0-9A-Z]* //'
# Nettoyage : suppression de la branche de test
curl -s -o /dev/null -H "$H" -X DELETE "$API/projects/$PID/repository/branches/$(python3 -c 'import urllib.parse;print(urllib.parse.quote("'$B'", safe=""))')"
git branch -q -D $B 2>/dev/null; chown -R jacques1: /home/jacques1/dgsn/p5-reports
