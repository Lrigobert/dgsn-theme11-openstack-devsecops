#!/usr/bin/env python3
"""Liste les tags actifs d'images Kolla sur quay.io (openstack.kolla/<image>), filtrés par motif.
Usage : quay-tags.py <motif> <image> [image...]"""
import json
import sys
import urllib.request

motif, images = sys.argv[1], sys.argv[2:]
for img in images:
    tags, page = set(), 1
    while True:
        url = (f"https://quay.io/api/v1/repository/openstack.kolla/{img}/tag/"
               f"?limit=100&page={page}&onlyActiveTags=true")
        d = json.load(urllib.request.urlopen(url, timeout=30))
        tags |= {t["name"] for t in d.get("tags", [])}
        if not d.get("has_additional") or page >= 20:
            break
        page += 1
    sel = sorted(t for t in tags if motif in t)
    print(f"{img}: {len(tags)} tags actifs, {len(sel)} contenant '{motif}' -> {sel[:30]}")
