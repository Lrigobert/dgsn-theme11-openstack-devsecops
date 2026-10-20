#!/usr/bin/env bash
# Phase 7 — openstack-exporter v1.7.0 sur VM4 (root). Archive vérifiée par SHA256 ; écoute locale uniquement
# (127.0.0.1:9180, scrapé par le Prometheus local). Fichiers attendus : /tmp/ose/{clouds.yaml,dgsn-root-ca.crt}
set -euo pipefail
V=1.7.0; B=https://github.com/openstack-exporter/openstack-exporter/releases/download/v$V
T=/tmp/ose-dl; mkdir -p $T; cd $T
if [ ! -x /usr/local/bin/openstack-exporter ]; then
  curl -fsSLO "$B/openstack-exporter_${V}_linux_amd64.tar.gz"
  curl -fsSLO "$B/openstack-exporter_${V}_checksums.txt"
  grep "openstack-exporter_${V}_linux_amd64.tar.gz" openstack-exporter_${V}_checksums.txt | sha256sum -c -
  tar xzf "openstack-exporter_${V}_linux_amd64.tar.gz"
  install -m 755 openstack-exporter /usr/local/bin/openstack-exporter
fi
rm -rf $T
id openstack-exporter >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin openstack-exporter
install -d -m 750 -o root -g openstack-exporter /etc/openstack-exporter
if [ -f /tmp/ose/clouds.yaml ]; then
  install -m 640 -o root -g openstack-exporter /tmp/ose/clouds.yaml /tmp/ose/dgsn-root-ca.crt /etc/openstack-exporter/
  shred -u /tmp/ose/clouds.yaml; rm -rf /tmp/ose
fi
[ -f /etc/openstack-exporter/clouds.yaml ] || { echo "clouds.yaml absent"; exit 1; }
cat > /etc/systemd/system/openstack-exporter.service <<'EOF'
[Unit]
Description=OpenStack exporter (DGSN Theme11)
After=network-online.target
[Service]
User=openstack-exporter
ExecStart=/usr/local/bin/openstack-exporter --os-client-config /etc/openstack-exporter/clouds.yaml \
  --web.listen-address 127.0.0.1:9180 \
  --disable-service.volume --disable-service.object-store --disable-service.load-balancer \
  --disable-service.container-infra --disable-service.dns --disable-service.baremetal \
  --disable-service.gnocchi --disable-service.database --disable-service.orchestration \
  dgsn
Restart=on-failure
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable --now openstack-exporter >/dev/null 2>&1; systemctl restart openstack-exporter
sleep 20
echo "service : $(systemctl is-active openstack-exporter)"
/usr/local/bin/openstack-exporter --version 2>&1 | head -1
curl -s --max-time 60 http://127.0.0.1:9180/metrics > /tmp/ose.prom
echo "métriques openstack_* : $(grep -c '^openstack_' /tmp/ose.prom)"
grep -E '^openstack_[a-z]+_up ' /tmp/ose.prom
