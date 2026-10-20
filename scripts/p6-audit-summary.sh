#!/usr/bin/env bash
# Synthèse du journal d'audit Vault (root sur gitlab) : connexions JWT acceptées/refusées, lectures de secrets.
# Le journal d'audit de Vault hache les valeurs sensibles (HMAC) : aucun secret en clair.
L=/var/log/vault/audit.log
python3 - "$L" <<'EOF'
import json, sys, collections
c = collections.Counter()
for line in open(sys.argv[1]):
    e = json.loads(line)
    if e.get("type") != "response":
        continue
    path = e.get("request", {}).get("path", "")
    err = e.get("error")
    if path == "auth/jwt/login":
        # accepté = un jeton a été délivré (response.auth) ; sinon refus (erreur de validation des claims)
        ok = bool(e.get("response", {}).get("auth"))
        c["login JWT " + ("accepté" if ok else "REFUSÉ")] += 1
    elif path.startswith("kv/data/ci/demo-app/"):
        c["lecture " + path.split("/", 3)[3] + (" REFUSÉE" if err else "")] += 1
for k, v in sorted(c.items()):
    print(f"{v:4d}  {k}")
EOF
echo "valeurs sensibles hachées (hmac-sha256) dans l'audit : $(grep -c 'hmac-sha256' $L) entrées"
