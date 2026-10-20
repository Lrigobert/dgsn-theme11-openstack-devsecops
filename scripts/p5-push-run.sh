#!/usr/bin/env bash
# Phase 5 — pousse une version de l'application et attend la fin du pipeline. Root sur gitlab.
# Usage : p5-push-run.sh <v1-vulnerable|v2-corrige> "<message de commit>"
# Sorties : statut, durée (API GitLab), statut de chaque job, rapports dans /home/jacques1/dgsn/p5-reports/<version>/
set -uo pipefail
V=$1; MSG=$2
D=/root/.dgsn; H="PRIVATE-TOKEN: $(cat $D/gitlab-pat)"; PID=$(cat $D/project-id)
API=http://192.168.100.50/api/v4
SRC=/home/jacques1/dgsn/demo-app
W=/root/demo-app-repo
OUT=/home/jacques1/dgsn/p5-reports/$V; mkdir -p "$OUT"

if [ ! -d $W/.git ]; then
  git clone -q "http://oauth2:$(cat $D/gitlab-pat)@192.168.100.50/dgsn/demo-app.git" $W 2>/dev/null || { mkdir -p $W; git -C $W init -q -b main; }
  git -C $W remote remove origin 2>/dev/null
  git -C $W remote add origin "http://oauth2:$(cat $D/gitlab-pat)@192.168.100.50/dgsn/demo-app.git"
fi
cp "$SRC/$V/app.py" "$SRC/$V/requirements.txt" "$SRC/common/Dockerfile" "$SRC/common/.gitlab-ci.yml" $W/
[ -f "$SRC/common/dgsn-root-ca.crt" ] && cp "$SRC/common/dgsn-root-ca.crt" $W/   # CA publique (P6)
cd $W
git -c user.name="DGSN CI" -c user.email="ci@dgsn.lab" add -A
# --allow-empty : relance possible d'un pipeline sans modification du code
git -c user.name="DGSN CI" -c user.email="ci@dgsn.lab" commit -q --allow-empty -m "$MSG"
SHA=$(git rev-parse HEAD)
git push -q -u origin main 2>&1 | grep -v oauth2 || true
echo "commit $SHA poussé ($V)"

# Attente du pipeline de ce commit
for i in $(seq 1 30); do
  PL=$(curl -s -H "$H" "$API/projects/$PID/pipelines?sha=$SHA" | python3 -c 'import sys,json; p=json.load(sys.stdin); print(p[0]["id"] if p else "")')
  [ -n "$PL" ] && break; sleep 2
done
echo "pipeline $PL"
while :; do
  ST=$(curl -s -H "$H" "$API/projects/$PID/pipelines/$PL" | python3 -c 'import sys,json; print(json.load(sys.stdin)["status"])')
  case $ST in success|failed|canceled|skipped) break;; esac
  sleep 10
done
curl -s -H "$H" "$API/projects/$PID/pipelines/$PL" | python3 -c '
import sys,json; p=json.load(sys.stdin)
print("PIPELINE", p["id"], "statut=%s" % p["status"], "durée=%ss" % p["duration"], "file+exécution=%ss" % (p.get("queued_duration") or 0))'
curl -s -H "$H" "$API/projects/$PID/pipelines/$PL/jobs?per_page=50" | python3 -c '
import sys,json
for j in sorted(json.load(sys.stdin), key=lambda j: j["id"]):
    print("  job %-18s %-8s %5ss" % (j["name"], j["status"], round(j["duration"] or 0)))'
# Rapports et journaux des jobs
for J in $(curl -s -H "$H" "$API/projects/$PID/pipelines/$PL/jobs?per_page=50" | python3 -c 'import sys,json; [print("%s:%s" % (j["id"], j["name"])) for j in json.load(sys.stdin)]'); do
  id=${J%%:*}; name=${J#*:}
  curl -s -H "$H" "$API/projects/$PID/jobs/$id/trace" > "$OUT/$name.log"
  if curl -sf -H "$H" -o "$OUT/$name-artifacts.zip" "$API/projects/$PID/jobs/$id/artifacts"; then
    python3 -m zipfile -e "$OUT/$name-artifacts.zip" "$OUT/" && rm -f "$OUT/$name-artifacts.zip"
  else rm -f "$OUT/$name-artifacts.zip"; fi
done
chown -R jacques1: /home/jacques1/dgsn/p5-reports
echo "rapports : $OUT"; ls "$OUT"
