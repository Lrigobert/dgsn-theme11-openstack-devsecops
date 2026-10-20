#!/usr/bin/env bash
# Variables CI du projet dgsn/demo-app (root sur gitlab). Usage : p5-ci-vars.sh <ip_application>
# DEPLOY_SSH_KEY : variable de type fichier, protégée, lue depuis /root/.dgsn (jamais affichée).
# (En phase 6, la clé et les identifiants OpenStack sont servis par Vault.)
set -euo pipefail
IP=$1
H="PRIVATE-TOKEN: $(cat /root/.dgsn/gitlab-pat)"; PID=$(cat /root/.dgsn/project-id)
API=http://192.168.100.50/api/v4/projects/$PID/variables
setvar() {  # setvar <clé> <type> <protégée> <fichier_valeur|valeur>
  curl -s -o /dev/null -H "$H" -X DELETE "$API/$1"
  curl -sf -o /dev/null -H "$H" -X POST "$API" --form "key=$1" --form "variable_type=$2" \
       --form "protected=$3" --form "value=<$4" && echo "variable $1 ($2, protégée=$3) définie"
}
printf '%s' "$IP" > /tmp/app_host && setvar APP_HOST env_var false /tmp/app_host && rm -f /tmp/app_host
setvar DEPLOY_SSH_KEY file true /root/.dgsn/deploy_ed25519
curl -sf -H "$H" "$API" | python3 -c 'import sys,json; [print(" -", v["key"], v["variable_type"], "protected" if v["protected"] else "") for v in json.load(sys.stdin)]'
