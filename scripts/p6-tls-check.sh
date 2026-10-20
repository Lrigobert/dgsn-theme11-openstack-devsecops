#!/usr/bin/env bash
# Phase 6 — contrôle TLS des endpoints OpenStack (VIP .45) et de Vault (.50). Exécuté sur VM1.
set -uo pipefail
. ~/kolla-venv/bin/activate; . /etc/kolla/admin-openrc.sh
CA=/etc/kolla/certificates/ca/dgsn-root-ca.crt
r=0; pass() { echo "PASS  $*"; }; fail() { echo "FAIL  $*"; r=1; }

for hp in 192.168.100.45:443 192.168.100.45:5000 192.168.100.45:8774 192.168.100.45:9696 \
          192.168.100.45:9292 192.168.100.45:8780 192.168.100.50:8200; do
  out=$(echo | openssl s_client -connect "$hp" -CAfile $CA -verify_return_error 2>/dev/null)
  v=$(echo "$out" | awk -F': ' '/Verify return code/ {print $2; exit}')     # 1re occurrence (tickets de session)
  proto=$(echo "$out" | grep -oE 'New, TLSv1\.[0-9]' | head -1 | cut -d' ' -f2)
  cn=$(echo "$out" | awk -F'CN ?= ?' '/^subject=/ {print $2; exit}')
  case "$v" in "0 (ok)") pass "$hp TLS vérifié ($proto, CN=$cn)";; *) fail "$hp TLS : $v";; esac
done

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://192.168.100.45:5000/v3 || true)
[ "$code" != 200 ] && pass "Keystone en HTTP clair refusé (code '$code')" || fail "Keystone répond en HTTP clair"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 --tls-max 1.1 --cacert $CA https://192.168.100.45:5000/v3 || true)
[ "$code" != 200 ] && pass "TLS 1.1 refusé par haproxy (code '$code')" || fail "TLS 1.1 accepté"

n_http=$(openstack endpoint list -f value -c URL | grep -c '^http://' || true)
n_tot=$(openstack endpoint list -f value -c URL | wc -l)
[ "$n_http" = 0 ] && pass "catalogue : $n_tot endpoints, tous en https://" || fail "catalogue : $n_http endpoints en http://"
[ $r = 0 ] && echo "P6_TLS_PASS" || echo "P6_TLS_FAIL"; exit $r
