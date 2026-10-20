#!/usr/bin/env bash
# Test d'acceptation P3 — RBAC Keystone (exécuté sur VM1). Chaque test s'exécute
# dans un sous-shell avec les identifiants de l'utilisateur concerné.
set -uo pipefail
. ~/kolla-venv/bin/activate
S=~/dgsn/secrets
r=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; r=1; }
as() { local u=$1; shift; ( unset ${!OS_*}; . "$S/p3-$u.env"; "$@" ) 2>&1; }

echo "== reader (dgsn-id-reader sur dgsn-identification) =="
out=$(as dgsn-id-reader openstack server list -f value); rc=$?
[ $rc = 0 ] && pass "reader peut lister les instances de son projet" || fail "reader ne peut pas lister : $out"
out=$(as dgsn-id-reader openstack server create p3-interdit --image cirros --flavor m1.tiny --network public1); rc=$?
echo "  -> $(echo "$out" | tail -1)"
if [ $rc != 0 ] && echo "$out" | grep -qiE '403|forbidden|not allowed|policy'; then
  pass "reader NE PEUT PAS créer d'instance (refus 403 prouvé)"
else
  fail "reader a pu créer une instance ou erreur inattendue"
  as dgsn-id-reader openstack server delete p3-interdit >/dev/null 2>&1
fi
out=$(as dgsn-id-reader openstack network create p3-interdit-net); rc=$?
[ $rc != 0 ] && pass "reader NE PEUT PAS créer de réseau ($(echo "$out" | tail -1 | cut -c1-90))" || { fail "reader a créé un réseau"; as dgsn-id-reader openstack network delete p3-interdit-net; }

echo "== member (dgsn-pj-member sur dgsn-pj) =="
out=$(as dgsn-pj-member openstack network create p3-pj-net -f value -c id); rc=$?
if [ $rc = 0 ]; then pass "member peut créer un réseau dans son projet"; as dgsn-pj-member openstack network delete p3-pj-net >/dev/null
else fail "member ne peut pas créer de réseau : $out"; fi
out=$(as dgsn-pj-member env OS_PROJECT_NAME=dgsn-identification openstack server list); rc=$?
[ $rc != 0 ] && pass "member NE PEUT PAS accéder au projet dgsn-identification ($(echo "$out" | tail -1 | cut -c1-90))" || fail "member a accédé à dgsn-identification"
out=$(as dgsn-pj-member openstack user list); rc=$?
[ $rc != 0 ] && pass "member NE PEUT PAS lister les utilisateurs (action admin refusée)" || fail "member a listé les utilisateurs"

echo "== admin (dgsn-ops-admin sur dgsn-ops) =="
out=$(as dgsn-ops-admin openstack project list -f value -c Name); rc=$?
[ $rc = 0 ] && echo "$out" | grep -q dgsn-pj && pass "admin peut administrer (liste des projets)" || fail "admin : $out"

[ $r = 0 ] && echo "P3_TEST_PASS" || echo "P3_TEST_FAIL"
exit $r
