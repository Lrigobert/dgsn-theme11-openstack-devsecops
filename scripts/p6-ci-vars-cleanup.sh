#!/usr/bin/env bash
# Phase 6 — suppression des secrets en variables CI (désormais servis par Vault). Root sur gitlab.
H="PRIVATE-TOKEN: $(cat /root/.dgsn/gitlab-pat)"; PID=$(cat /root/.dgsn/project-id)
API=http://192.168.100.50/api/v4/projects/$PID/variables
curl -s -o /dev/null -w "suppression DEPLOY_SSH_KEY : HTTP %{http_code}\n" -H "$H" -X DELETE "$API/DEPLOY_SSH_KEY"
echo "variables CI restantes :"
curl -s -H "$H" "$API" | python3 -c 'import sys,json; v=json.load(sys.stdin); [print(" -", x["key"], x["variable_type"]) for x in v] or print(" (aucune)")'
