#!/usr/bin/env bash
# Phase 8 — préparation (VM1) : oscap + dernière version stable du SCAP Security Guide (vérifiée SHA512),
# inventaire des profils CIS disponibles pour Debian 12 et Ubuntu 22.04.
set -euo pipefail
# oscap : paquet openscap-scanner (Debian 12 / Ubuntu 24.04) ou libopenscap8 (Ubuntu 22.04)
if ! command -v oscap >/dev/null; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openscap-scanner unzip >/dev/null 2>&1 || \
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libopenscap8 unzip >/dev/null
fi
oscap --version 2>/dev/null | sed -n 1p || true   # info : oscap de VM1 (1.2.x sur 22.04) non utilisé pour les scans
D=~/dgsn/ssg; mkdir -p $D; cd $D
if [ ! -d content ]; then
  read -r TAG URL SUM < <(python3 - <<'EOF'
import json, urllib.request
rels = json.load(urllib.request.urlopen("https://api.github.com/repos/ComplianceAsCode/content/releases?per_page=10", timeout=30))
r = next(x for x in rels if not x["prerelease"] and not x["draft"])
a = {x["name"]: x["browser_download_url"] for x in r["assets"]}
v = r["tag_name"].lstrip("v")
z = f"scap-security-guide-{v}.zip"
print(r["tag_name"], a[z], a.get(z + ".sha512", "-"))
EOF
)
  echo "SSG $TAG"
  curl -fsSL -o ssg.zip "$URL"
  if [ "$SUM" != "-" ]; then curl -fsSL -o ssg.zip.sha512 "$SUM"; echo "$(awk '{print $1}' ssg.zip.sha512)  ssg.zip" | sha512sum -c -; fi
  unzip -q ssg.zip && mv scap-security-guide-* content && rm -f ssg.zip
fi
ls content | head -3
# Profils lus directement dans le datastream (indépendant de la version d'oscap locale)
for ds in content/ssg-debian12-ds.xml content/ssg-ubuntu2404-ds.xml content/ssg-ubuntu2204-ds.xml; do
  echo "== $(basename $ds)"
  [ -f $ds ] && grep -oE 'xccdf_org\.ssgproject\.content_profile_[a-z0-9_]+' $ds | sort -u | sed 's/.*content_profile_/  /' || echo "  absent"
done
echo "== playbooks Ansible fournis"
ls content/ansible 2>/dev/null | grep -iE '(debian12|ubuntu2404).*(cis|standard)' | head || true
