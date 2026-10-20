#!/usr/bin/env bash
# Phase 4 — préparation (VM1) : Terraform, image Debian 12 genericcloud, flavor dgsn.p4. Idempotent.
set -euo pipefail
. ~/kolla-venv/bin/activate
. /etc/kolla/admin-openrc.sh

echo "== Terraform =="
if ! command -v terraform >/dev/null; then
  sudo install -d -m 0755 /etc/apt/keyrings
  wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/hashicorp.gpg
  echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq terraform >/dev/null
fi
terraform version | head -1

echo "== Image Debian 12 genericcloud =="
if ! openstack image show debian-12 >/dev/null 2>&1; then
  IMG=/tmp/debian-12-genericcloud-amd64.qcow2
  BASE=https://cloud.debian.org/images/cloud/bookworm/latest
  wget -q -O "$IMG" "$BASE/debian-12-genericcloud-amd64.qcow2"
  # Vérification d'intégrité contre le SHA512SUMS officiel
  wget -q -O /tmp/SHA512SUMS "$BASE/SHA512SUMS"
  ( cd /tmp && grep ' debian-12-genericcloud-amd64.qcow2$' SHA512SUMS | sha512sum -c - )
  openstack image create debian-12 --file "$IMG" --disk-format qcow2 --container-format bare \
    --public --property os_distro=debian --property os_version=12 --min-disk 3 --min-ram 384 -f value -c id
  rm -f "$IMG"
fi
openstack image show debian-12 -f value -c name -c status -c size

echo "== Flavor dgsn.p4 (écart : 512 Mo, contrainte RAM du lab) =="
openstack flavor show dgsn.p4 >/dev/null 2>&1 || \
  openstack flavor create dgsn.p4 --vcpus 1 --ram 512 --disk 5 --public -f value -c id
openstack flavor show dgsn.p4 -f value -c name -c vcpus -c ram -c disk
echo "P4_PREP_OK"
