#!/usr/bin/env bash
# Valide un .gitlab-ci.yml via l'API GitLab (root sur gitlab). Usage : p6-ci-lint.sh <fichier>
H="PRIVATE-TOKEN: $(cat /root/.dgsn/gitlab-pat)"; PID=$(cat /root/.dgsn/project-id)
python3 -c 'import json,sys; print(json.dumps({"content": open(sys.argv[1]).read()}))' "$1" > /tmp/lint.json
curl -s -H "$H" -H 'Content-Type: application/json' -X POST \
  "http://192.168.100.50/api/v4/projects/$PID/ci/lint" --data @/tmp/lint.json \
  | python3 -c 'import sys,json; r=json.load(sys.stdin); print("valide :", r.get("valid")); [print(" erreur :", e) for e in r.get("errors", [])]; [print(" avertissement :", w) for w in r.get("warnings", [])]'
PL=$(curl -s -H "$H" "http://192.168.100.50/api/v4/projects/$PID/pipelines?per_page=1" | python3 -c 'import sys,json; print(json.load(sys.stdin)[0]["id"])')
curl -s -H "$H" "http://192.168.100.50/api/v4/projects/$PID/pipelines/$PL" | python3 -c 'import sys,json; p=json.load(sys.stdin); print("pipeline", p["id"], p["status"], "yaml_errors:", p.get("yaml_errors"))'
