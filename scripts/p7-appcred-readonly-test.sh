#!/usr/bin/env bash
# Preuve : le credential de supervision lit (GET) mais ne peut pas écrire (POST). Root sur VM4. Aucun secret affiché.
C=/etc/openstack-exporter/clouds.yaml; CA=/etc/openstack-exporter/dgsn-root-ca.crt
read -r ID SEC < <(python3 -c 'import yaml; a=yaml.safe_load(open("'$C'"))["clouds"]["dgsn"]["auth"]; print(a["application_credential_id"], a["application_credential_secret"])')
TOK=$(curl -s --cacert $CA -D - -o /dev/null -H 'Content-Type: application/json' https://192.168.100.45:5000/v3/auth/tokens \
  -d "{\"auth\":{\"identity\":{\"methods\":[\"application_credential\"],\"application_credential\":{\"id\":\"$ID\",\"secret\":\"$SEC\"}}}}" \
  | awk 'tolower($1)=="x-subject-token:" {print $2}' | tr -d '\r'); unset SEC
[ -n "$TOK" ] && echo "jeton Keystone obtenu (application credential de supervision)" || { echo "échec d'authentification"; exit 1; }
r=$(curl -s -o /dev/null -w '%{http_code}' --cacert $CA -H "X-Auth-Token: $TOK" https://192.168.100.45:9696/v2.0/networks)
echo "GET  /v2.0/networks  -> HTTP $r (attendu 200 : lecture autorisée)"
w=$(curl -s -o /dev/null -w '%{http_code}' --cacert $CA -H "X-Auth-Token: $TOK" -H 'Content-Type: application/json' \
  -X POST https://192.168.100.45:9696/v2.0/networks -d '{"network":{"name":"interdit-supervision"}}')
echo "POST /v2.0/networks  -> HTTP $w (attendu 401/403 : écriture refusée par les access rules)"
s=$(curl -s -o /dev/null -w '%{http_code}' --cacert $CA -H "X-Auth-Token: $TOK" -H 'Content-Type: application/json' \
  -X POST https://192.168.100.45:8774/v2.1/servers -d '{"server":{"name":"interdit"}}')
echo "POST /v2.1/servers   -> HTTP $s (attendu 401/403)"
[ "$r" = 200 ] && [ "$w" != 201 ] && [ "$s" != 202 ] && echo "LECTURE_SEULE_PROUVEE" || echo "ECHEC_PREUVE"
