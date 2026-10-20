#!/usr/bin/env bash
# Phase 6 — PKI interne du lab (exécuté sur VM1, poste d'administration). Idempotent.
# La clé privée de la CA reste dans ~/dgsn/pki (700/600) ; seul le certificat de CA (public) est diffusé.
# Production DGSN : CA racine hors ligne + CA intermédiaire (ou Vault PKI), clés en HSM.
set -euo pipefail
P=~/dgsn/pki; install -d -m 700 $P; cd $P
DAYS=397

if [ ! -f ca.key ]; then
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 -out ca.key
  chmod 600 ca.key
  openssl req -x509 -new -key ca.key -sha384 -days 3650 -out dgsn-root-ca.crt \
    -subj "/C=MA/O=DGSN Lab Theme11/OU=Securite/CN=DGSN Lab Root CA" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" -addext "keyUsage=critical,keyCertSign,cRLSign"
fi

issue() {  # issue <nom> <CN> <SAN>
  local n=$1 cn=$2 san=$3
  [ -f "$n.crt" ] && openssl x509 -in "$n.crt" -noout -checkend 2592000 >/dev/null && { echo "$n : certificat valide conservé"; return; }
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$n.key"; chmod 600 "$n.key"
  openssl req -new -key "$n.key" -out "$n.csr" -subj "/C=MA/O=DGSN Lab Theme11/CN=$cn"
  openssl x509 -req -in "$n.csr" -CA dgsn-root-ca.crt -CAkey ca.key -CAcreateserial -days $DAYS -sha256 -out "$n.crt" \
    -extfile <(printf "subjectAltName=%s\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\n" "$san")
  rm -f "$n.csr"; echo "$n : certificat émis"
}
issue_client() {  # issue_client <nom> <CN> : certificat client (EKU clientAuth) pour le mTLS
  local n=$1 cn=$2
  [ -f "$n.crt" ] && openssl x509 -in "$n.crt" -noout -checkend 2592000 >/dev/null && { echo "$n : certificat valide conservé"; return; }
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$n.key"; chmod 600 "$n.key"
  openssl req -new -key "$n.key" -out "$n.csr" -subj "/C=MA/O=DGSN Lab Theme11/CN=$cn"
  openssl x509 -req -in "$n.csr" -CA dgsn-root-ca.crt -CAkey ca.key -CAcreateserial -days $DAYS -sha256 -out "$n.crt" \
    -extfile <(printf "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=clientAuth\n")
  rm -f "$n.csr"; echo "$n : certificat client émis"
}

issue openstack openstack.dgsn.lab "DNS:openstack.dgsn.lab,IP:192.168.100.45,IP:192.168.100.40"
issue vault     vault.dgsn.lab     "DNS:vault.dgsn.lab,DNS:gitlab.dgsn.lab,IP:192.168.100.50,IP:127.0.0.1"
# Phase 7 : node_exporter en mTLS (serveurs) + client Prometheus
issue node-controller node-controller.dgsn.lab "DNS:controller.dgsn.lab,IP:192.168.100.40"
issue node-app        node-app.dgsn.lab        "DNS:dgsn-app-1.dgsn.lab,IP:192.168.100.220"
issue_client prometheus-client prometheus.dgsn.lab

for n in openstack vault node-controller node-app prometheus-client; do
  openssl verify -CAfile dgsn-root-ca.crt $n.crt
  openssl x509 -in $n.crt -noout -subject -enddate -ext subjectAltName | tr '\n' ' '; echo
done
ls -l $P
echo "P6_PKI_OK"
