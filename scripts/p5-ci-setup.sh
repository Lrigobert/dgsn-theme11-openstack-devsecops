#!/usr/bin/env bash
# Phase 5 — jeton d'automatisation, runner Docker, clé de déploiement, projet. Root sur gitlab. Idempotent.
# Secrets conservés UNIQUEMENT dans /root/.dgsn (700) sur la VM gitlab (migrés vers Vault en P6).
set -euo pipefail
D=/root/.dgsn; install -d -m 700 $D
GL=http://192.168.100.50
API=$GL/api/v4

echo "== Jeton d'automatisation (PAT root, 30 jours, portée api) =="
if [ ! -s $D/gitlab-pat ]; then
  # gitlab-rails s'exécute sous l'utilisateur git : le jeton est renvoyé sur stdout et écrit par root.
  # Les jetons dgsn-automation actifs (éventuels orphelins) sont révoqués avant création.
  umask 077
  gitlab-rails runner "u = User.find_by_username('root'); u.personal_access_tokens.active.where(name: 'dgsn-automation').each(&:revoke!); t = u.personal_access_tokens.create!(name: 'dgsn-automation', scopes: [:api, :write_repository], expires_at: 30.days.from_now); puts 'TOKEN=' + t.token" \
    | sed -n 's/^TOKEN=//p' > $D/gitlab-pat
  chmod 600 $D/gitlab-pat
  [ -s $D/gitlab-pat ] || { echo "échec de création du jeton"; exit 1; }
fi
H="PRIVATE-TOKEN: $(cat $D/gitlab-pat)"
curl -sf -H "$H" $API/user | python3 -c 'import sys,json; print("PAT OK pour", json.load(sys.stdin)["username"])'

echo "== Runner Docker (exécuteur docker, socket hôte, concurrence 1) =="
if ! grep -q 'name = "dgsn-docker"' /etc/gitlab-runner/config.toml 2>/dev/null; then
  RT=$(curl -sf -H "$H" -X POST $API/user/runners \
        -d runner_type=instance_type -d description=dgsn-docker -d run_untagged=true | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')
  gitlab-runner register --non-interactive --url $GL --token "$RT" --name dgsn-docker \
    --executor docker --docker-image alpine:3.20 --docker-pull-policy if-not-present \
    --docker-volumes /var/run/docker.sock:/var/run/docker.sock --docker-volumes /cache \
    --docker-network-mode host >/dev/null 2>&1
  sed -i 's/^concurrent = .*/concurrent = 1/' /etc/gitlab-runner/config.toml
  systemctl restart gitlab-runner
fi
# Ne jamais afficher le jeton du runner (glrt-…) : masquage systématique
gitlab-runner list 2>&1 | tail -1 | sed -E 's/Token[^ ]*=[^ ]+/Token=[SECRET]/g; s/glrt-[A-Za-z0-9._-]+/[SECRET]/g'
grep -E '^concurrent|executor|volumes' /etc/gitlab-runner/config.toml

echo "== Clé SSH de déploiement CI =="
[ -f $D/deploy_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -C dgsn-ci-deploy -f $D/deploy_ed25519
cp $D/deploy_ed25519.pub /home/jacques1/dgsn-deploy.pub && chown jacques1: /home/jacques1/dgsn-deploy.pub

echo "== Groupe et projet =="
GID=$(curl -sf -H "$H" "$API/groups?search=dgsn" | python3 -c 'import sys,json; g=[x for x in json.load(sys.stdin) if x["path"]=="dgsn"]; print(g[0]["id"] if g else "")')
[ -n "$GID" ] || GID=$(curl -sf -H "$H" -X POST $API/groups -d name=DGSN -d path=dgsn -d visibility=private | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
PID=$(curl -s -H "$H" "$API/projects/dgsn%2Fdemo-app" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id",""))')
[ -n "$PID" ] || PID=$(curl -sf -H "$H" -X POST $API/projects -d name=demo-app -d namespace_id=$GID -d visibility=private \
  -d container_registry_access_level=private -d initialize_with_readme=false | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
echo "groupe=$GID projet=$PID"
echo "$PID" > $D/project-id
echo "P5_CI_SETUP_OK"
