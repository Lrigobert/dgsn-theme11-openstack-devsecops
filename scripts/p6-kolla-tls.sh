#!/usr/bin/env bash
# Phase 6 — installation des certificats Kolla et confiance de la CA sur VM1. Idempotent.
set -euo pipefail
P=~/dgsn/pki; C=/etc/kolla/certificates
install -d -m 750 $C $C/ca
# haproxy.pem / haproxy-internal.pem = certificat + chaîne + clé privée (format attendu par Kolla)
cat $P/openstack.crt $P/dgsn-root-ca.crt $P/openstack.key > $C/haproxy.pem
cp $C/haproxy.pem $C/haproxy-internal.pem
chmod 600 $C/haproxy.pem $C/haproxy-internal.pem
cp $P/dgsn-root-ca.crt $C/ca/dgsn-root-ca.crt
# Les modèles Kolla (ex. ProxySQL) attendent la CA sous le nom root.crt (convention de « kolla-ansible certificates »)
cp $P/dgsn-root-ca.crt $C/ca/root.crt
# ProxySQL (frontal base de données) exige ses propres fichiers quand le TLS interne est activé
cat $P/openstack.crt $P/dgsn-root-ca.crt > $C/proxysql-cert.pem
cp $P/openstack.key $C/proxysql-key.pem
chmod 600 $C/proxysql-cert.pem $C/proxysql-key.pem
# Confiance système sur VM1 (curl, Terraform) + bundle Python pour le client OpenStack
sudo cp $P/dgsn-root-ca.crt /usr/local/share/ca-certificates/dgsn-root-ca.crt
sudo update-ca-certificates >/dev/null
# Fichiers d'identifiants P3 : passage en https + CA (secrets inchangés, restent sur VM1)
for f in ~/dgsn/secrets/p3-*.env; do
  sed -i 's#http://192.168.100.45:5000#https://192.168.100.45:5000#' "$f"
  grep -q '^export OS_CACERT=' "$f" || echo "export OS_CACERT=$C/ca/dgsn-root-ca.crt" >> "$f"
done
ls -l $C $C/ca
echo "P6_KOLLA_TLS_FILES_OK"
