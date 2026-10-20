#!/usr/bin/env bash
# Récupère les artefacts d'un job du dernier pipeline au statut donné et résume les rapports.
# Root sur gitlab. Usage : p5-fetch-artifact.sh <nom_job> <dossier_sortie>
H="PRIVATE-TOKEN: $(cat /root/.dgsn/gitlab-pat)"; PID=$(cat /root/.dgsn/project-id); API=http://192.168.100.50/api/v4
JOB=$1; OUT=$2; mkdir -p "$OUT"
id=$(curl -s -H "$H" "$API/projects/$PID/jobs?per_page=50" | python3 -c "import sys,json; j=[x for x in json.load(sys.stdin) if x['name']=='$JOB' and x.get('artifacts_file')]; print(j[0]['id'] if j else '')")
[ -n "$id" ] || { echo "aucun artefact pour $JOB"; exit 1; }
curl -sf -H "$H" -o /tmp/a.zip "$API/projects/$PID/jobs/$id/artifacts" && python3 -m zipfile -e /tmp/a.zip "$OUT/" && rm -f /tmp/a.zip
chown -R jacques1: "$OUT"
python3 - "$OUT" <<'EOF'
import json, os, sys
d = sys.argv[1]
for f in sorted(os.listdir(d)):
    p = os.path.join(d, f)
    if f == "semgrep.json":
        r = json.load(open(p))["results"]
        print(f"{f}: {len(r)} findings")
        for x in r:
            print(f"  - {x['check_id'].split('.')[-1]} (ligne {x['start']['line']}, {x['extra'].get('severity')})")
    elif f.startswith("trivy") and f.endswith(".json"):
        vulns = [v for res in json.load(open(p)).get("Results", []) for v in res.get("Vulnerabilities") or []]
        print(f"{f}: {len(vulns)} vulnérabilités HIGH/CRITICAL")
        for v in vulns[:15]:
            print(f"  - {v['VulnerabilityID']} {v['PkgName']} {v['InstalledVersion']} -> {v.get('FixedVersion','')} [{v['Severity']}]")
EOF
