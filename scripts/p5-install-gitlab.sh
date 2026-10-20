#!/usr/bin/env bash
# Phase 5 — installation GitLab CE (économe) + Docker + GitLab Runner sur la VM gitlab.
# Exécuté en root (sudo) sur gitlab, avec ~/dgsn/gitlab/gitlab.rb copié au préalable. Idempotent.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
SRC=/home/jacques1/dgsn/gitlab
CODENAME=$(lsb_release -cs)

echo "== Dépôts signés GitLab (CE + Runner) =="
apt-get update -qq
apt-get install -y -qq curl ca-certificates gnupg openssh-server tzdata perl >/dev/null
install -d -m 0755 /usr/share/keyrings
# GitLab CE : namespace "gitlab" ; GitLab Runner : namespace "runner"
for ns_repo in gitlab/gitlab-ce runner/gitlab-runner; do
  repo=${ns_repo#*/}
  key=/usr/share/keyrings/gitlab_${repo}.gpg
  [ -s "$key" ] || curl -fsSL "https://packages.gitlab.com/${ns_repo}/gpgkey" | gpg --dearmor --yes -o "$key"
  echo "deb [signed-by=$key] https://packages.gitlab.com/${ns_repo}/ubuntu/ ${CODENAME} main" \
    > /etc/apt/sources.list.d/gitlab_${repo}.list
done
apt-get update -qq

echo "== Configuration économe avant installation =="
install -d -m 0775 /etc/gitlab
install -m 0600 "$SRC/gitlab.rb" /etc/gitlab/gitlab.rb

echo "== GitLab CE =="
if ! dpkg -s gitlab-ce >/dev/null 2>&1; then
  t0=$(date +%s)
  EXTERNAL_URL="http://192.168.100.50" apt-get install -y -qq gitlab-ce >/var/log/dgsn-gitlab-install.log 2>&1
  echo "installation gitlab-ce : $(( $(date +%s) - t0 )) s"
else
  gitlab-ctl reconfigure >/var/log/dgsn-gitlab-reconfigure.log 2>&1
fi
dpkg -s gitlab-ce | grep '^Version'

echo "== Docker + registre local non TLS (TLS en P6) =="
apt-get install -y -qq docker.io >/dev/null
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{ "insecure-registries": ["192.168.100.50:5050"], "log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"} }
EOF
systemctl restart docker
docker version --format 'docker {{.Server.Version}}'

echo "== GitLab Runner =="
apt-get install -y -qq gitlab-runner >/dev/null
usermod -aG docker gitlab-runner
gitlab-runner --version | head -1

echo "== Attente de GitLab (HTTP) =="
for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://192.168.100.50/users/sign_in || true)
  [ "$code" = 200 ] && break; sleep 10
done
echo "GitLab /users/sign_in : HTTP $code"
free -m | sed -n 1,3p
echo "P5_INSTALL_OK"
