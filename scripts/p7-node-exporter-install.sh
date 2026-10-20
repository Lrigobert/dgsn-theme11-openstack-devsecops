#!/usr/bin/env bash
# Installe prometheus-node-exporter en mTLS (root sur la cible). Fichiers attendus : /tmp/ne/{node.crt,node.key,ca.crt}
# Le client (Prometheus) DOIT présenter un certificat signé par la CA DGSN (RequireAndVerifyClientCert).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
command -v prometheus-node-exporter >/dev/null || { apt-get update -qq; apt-get install -y -qq prometheus-node-exporter >/dev/null; }
install -d -m 750 -o root -g prometheus /etc/prometheus/node-tls
install -m 640 -o root -g prometheus /tmp/ne/node.crt /tmp/ne/ca.crt /etc/prometheus/node-tls/
install -m 640 -o root -g prometheus /tmp/ne/node.key /etc/prometheus/node-tls/
shred -u /tmp/ne/node.key; rm -rf /tmp/ne
cat > /etc/prometheus/node-web.yml <<'EOF'
tls_server_config:
  cert_file: /etc/prometheus/node-tls/node.crt
  key_file: /etc/prometheus/node-tls/node.key
  client_ca_file: /etc/prometheus/node-tls/ca.crt
  client_auth_type: RequireAndVerifyClientCert
  min_version: TLS12
EOF
chown root:prometheus /etc/prometheus/node-web.yml; chmod 640 /etc/prometheus/node-web.yml
grep -q 'web.config' /etc/default/prometheus-node-exporter 2>/dev/null || \
  echo 'ARGS="--web.config.file=/etc/prometheus/node-web.yml"' >> /etc/default/prometheus-node-exporter
systemctl restart prometheus-node-exporter
sleep 2
systemctl is-active prometheus-node-exporter
prometheus-node-exporter --version 2>&1 | head -1
# Preuves locales : sans certificat client -> refus ; en HTTP clair -> refus
c=$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:9100/metrics || true)
echo "HTTPS sans certificat client : code '$c' (attendu : 000 = handshake refusé)"
c=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9100/metrics || true)
echo "HTTP clair : code '$c' (attendu : 400 ou 000)"
