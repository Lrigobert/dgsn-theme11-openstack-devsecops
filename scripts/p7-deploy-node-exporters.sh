#!/usr/bin/env bash
# Déploie node_exporter en mTLS sur controller et sur l'instance applicative (exécuté sur VM1).
set -uo pipefail
P=~/dgsn/pki; S=~/dgsn/scripts/p7-node-exporter-install.sh
deploy() {  # deploy <user@ip> <nom_certificat> [options ssh]
  local t=$1 n=$2; shift 2
  echo "=== $t ($n)"
  ssh -o BatchMode=yes "$@" "$t" 'rm -rf /tmp/ne; install -d -m 700 /tmp/ne'
  scp -q -o BatchMode=yes "$@" $P/$n.crt "$t:/tmp/ne/node.crt"
  scp -q -o BatchMode=yes "$@" $P/$n.key "$t:/tmp/ne/node.key"
  scp -q -o BatchMode=yes "$@" $P/dgsn-root-ca.crt "$t:/tmp/ne/ca.crt"
  scp -q -o BatchMode=yes "$@" $S "$t:/tmp/ne-install.sh"
  ssh -o BatchMode=yes "$@" "$t" 'sudo bash /tmp/ne-install.sh; rm -f /tmp/ne-install.sh'
}
deploy jacques1@192.168.100.40 node-controller
deploy debian@$(cat ~/dgsn/p5-app-ip) node-app -o UserKnownHostsFile=$HOME/.ssh/known_hosts_p5
