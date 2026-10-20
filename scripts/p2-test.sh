#!/usr/bin/env bash
# Test d'acceptation P2 (exécuté sur VM1). Affiche PASS/FAIL par critère, idempotent.
set -uo pipefail
. ~/kolla-venv/bin/activate
. /etc/kolla/admin-openrc.sh
r=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; r=1; }
VM=p2-test-cirros SG=p2-test-sg

echo "== Services Keystone =="
openstack service list -c Name -c Type -f value | sort | tee /tmp/svc.txt
for s in keystone glance nova neutron placement; do
  grep -q "^$s " /tmp/svc.txt && pass "service $s enregistré" || fail "service $s absent"
done
openstack compute service list -f value -c Binary -c State | sort | uniq
openstack network agent list -f value -c Binary -c Alive | sort | uniq

echo "== Horizon (VIP 192.168.100.45) =="
CA=/etc/kolla/certificates/ca/dgsn-root-ca.crt
if grep -q '^kolla_enable_tls_external: "yes"' /etc/kolla/globals.yml; then
  # Phase 6 : HTTPS avec vérification de la chaîne de confiance (CA interne DGSN)
  code=$(curl -s -L -o /dev/null -w '%{http_code}' --max-time 20 --cacert $CA https://192.168.100.45/)
  [ "$code" = 200 ] && pass "Horizon HTTPS $code (certificat vérifié par la CA DGSN)" || fail "Horizon HTTPS $code"
  case "$OS_AUTH_URL" in https://*) pass "API Keystone en HTTPS ($OS_AUTH_URL)";; *) fail "API Keystone non chiffrée ($OS_AUTH_URL)";; esac
else
  code=$(curl -s -L -o /dev/null -w '%{http_code}' --max-time 20 http://192.168.100.45/)
  [ "$code" = 200 ] && pass "Horizon HTTP $code" || fail "Horizon HTTP $code"
fi

echo "== Réseaux =="
t=$(openstack network show demo-net -f value -c provider:network_type)
[ "$t" = vxlan ] && pass "demo-net type $t" || fail "demo-net type $t"
t=$(openstack network show public1 -f value -c provider:network_type)
[ "$t" = flat ] && pass "public1 type $t (externe)" || fail "public1 type $t"

echo "== Groupe de sécurité (22, 8080, ICMP autorisés ; 8081 non) =="
openstack security group show $SG >/dev/null 2>&1 || {
  openstack security group create $SG --description "Test P2 : 22/8080/ICMP seulement" >/dev/null
  openstack security group rule create $SG --protocol icmp >/dev/null
  openstack security group rule create $SG --protocol tcp --dst-port 22 >/dev/null
  openstack security group rule create $SG --protocol tcp --dst-port 8080 >/dev/null
}
openstack security group rule list $SG -f value -c "IP Protocol" -c "Port Range" -c Direction

echo "== Instance cirros =="
cat > /tmp/p2-userdata.sh <<'EOF'
#!/bin/sh
(while true; do echo "DGSN-8080" | nc -l -p 8080; done) &
(while true; do echo "DGSN-8081" | nc -l -p 8081; done) &
EOF
# Instance toujours neuve : le user-data (écouteurs 8080/8081) ne s'exécute qu'au premier boot
if openstack server show $VM >/dev/null 2>&1; then
  old=$(openstack server show $VM -f json -c addresses | grep -o '192\.168\.100\.[0-9]*')
  openstack server delete --wait $VM
  for ip in $old; do openstack floating ip delete "$ip" 2>/dev/null; done
  # Nova peut encore renvoyer l'instance en statut DELETED : attendre qu'elle quitte la liste
  for i in $(seq 1 30); do [ -z "$(openstack server list --name "^$VM\$" -f value -c ID)" ] && break; sleep 2; done
fi
if [ -z "$(openstack server list --name "^$VM\$" -f value -c ID)" ]; then
  t0=$(date +%s)
  for essai in 1 2; do
    out=$(openstack server create $VM --image cirros --flavor m1.tiny --network demo-net \
      --security-group $SG --user-data /tmp/p2-userdata.sh --wait -f value -c status 2>&1) && break
    echo "création essai $essai en échec : $(echo "$out" | tail -2)"
    openstack server delete --wait $VM 2>/dev/null; sleep 10
  done
  echo "création + ACTIVE en $(( $(date +%s) - t0 )) s"
fi
st=$(openstack server show $VM -f value -c status)
[ "$st" = ACTIVE ] && pass "instance $VM $st" || fail "instance $VM $st"

FIP=$(openstack server show $VM -f json -c addresses | grep -o '192\.168\.100\.[0-9]*' | head -1)
if [ -z "$FIP" ]; then
  FIP=$(openstack floating ip create public1 -f value -c floating_ip_address)
  openstack server add floating ip $VM "$FIP"
fi
echo "IP flottante : $FIP"

ok=0; for i in $(seq 1 60); do ping -c1 -W2 "$FIP" >/dev/null && { ok=1; break; }; sleep 5; done
[ $ok = 1 ] && pass "ping $FIP depuis VM1 (après ~$((i*5)) s)" || fail "ping $FIP"

# Attente du démarrage complet (cirros sous qemu est lent) : port 22 ouvert
for i in $(seq 1 60); do nc -z -w3 "$FIP" 22 && break; sleep 5; done
nc -z -w5 "$FIP" 22   && pass "TCP 22 autorisé : ouvert"   || fail "TCP 22 fermé"
# Le user-data (servi par le service de métadonnées Nova) ouvre 8080/8081 : délai mesuré
# (busybox nc -l ne sert qu'une connexion puis est relancé : on retient la 1re sonde réussie)
t8080=$(date +%s); ok8080=0
for i in $(seq 1 60); do nc -z -w3 "$FIP" 8080 && { ok8080=1; break; }; sleep 5; done
echo "délai user-data (8080 ouvert après SSH) : $(( $(date +%s) - t8080 )) s"
[ $ok8080 = 1 ] && pass "TCP 8080 autorisé : ouvert" || fail "TCP 8080 fermé"
sleep 3   # laisser l'écouteur 8081 se relancer si besoin
nc -z -w5 "$FIP" 8081 && fail "TCP 8081 accessible alors que non autorisé" || pass "TCP 8081 non autorisé : bloqué (timeout)"

# Contre-preuve : on autorise 8081, il devient joignable -> c'est bien le groupe de sécurité qui filtrait
rid=$(openstack security group rule create $SG --protocol tcp --dst-port 8081 -f value -c id)
sleep 5
nc -z -w5 "$FIP" 8081 && pass "TCP 8081 joignable après ajout de la règle (contre-preuve)" || fail "TCP 8081 toujours fermé après règle"
openstack security group rule delete "$rid"

[ $r = 0 ] && echo "P2_TEST_PASS" || echo "P2_TEST_FAIL"
exit $r
