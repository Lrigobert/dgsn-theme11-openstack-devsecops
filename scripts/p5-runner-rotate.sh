#!/usr/bin/env bash
# Rotation du runner (jeton exposé) : suppression côté GitLab (jeton invalidé) + désenregistrement local.
# Root sur gitlab. Le nouvel enregistrement est fait par p5-ci-setup.sh (jeton jamais affiché).
set -euo pipefail
H="PRIVATE-TOKEN: $(cat /root/.dgsn/gitlab-pat)"; API=http://192.168.100.50/api/v4
for id in $(curl -sf -H "$H" "$API/runners/all?per_page=100" | python3 -c 'import sys,json; [print(r["id"]) for r in json.load(sys.stdin)]'); do
  curl -sf -H "$H" -X DELETE "$API/runners/$id" && echo "runner $id supprimé côté GitLab (jeton invalidé)"
done
# unregister échoue si le runner n'existe plus côté serveur : purger les entrées invalides localement
gitlab-runner unregister --all-runners >/dev/null 2>&1 || true
gitlab-runner verify --delete >/dev/null 2>&1 || true
echo "runners dans config.toml : $(grep -c '^\[\[runners\]\]' /etc/gitlab-runner/config.toml || true)"
echo "runners restants côté GitLab : $(curl -sf -H "$H" "$API/runners/all" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))')"
