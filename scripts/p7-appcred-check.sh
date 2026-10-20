#!/usr/bin/env bash
# Vérifie les access rules de l'application credential de supervision (VM1, admin).
. ~/kolla-venv/bin/activate; unset ${!OS_*}; . /etc/kolla/admin-openrc.sh
openstack application credential show monitoring-exporter -f json | python3 -c '
import sys, json
d = {k.lower().replace(" ", "_"): v for k, v in json.load(sys.stdin).items()}
r = d.get("access_rules") or []
if isinstance(r, str):
    import ast; r = ast.literal_eval(r) if r.strip() else []
print("unrestricted :", d.get("unrestricted"), "| expiration :", d.get("expires_at"))
print("access rules :", len(r))
for x in r: print("  -", x.get("service"), x.get("method"), x.get("path"))'
