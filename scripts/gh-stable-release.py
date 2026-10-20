#!/usr/bin/env python3
"""Dernière version STABLE (ni pre-release ni draft) d'un dépôt GitHub + URL de l'archive linux/amd64 et du fichier de sommes.
Usage : gh-stable-release.py owner/repo"""
import json
import sys
import urllib.request

repo = sys.argv[1]
rels = json.load(urllib.request.urlopen(f"https://api.github.com/repos/{repo}/releases?per_page=30", timeout=30))
r = next(x for x in rels if not x["prerelease"] and not x["draft"] and "alpha" not in x["tag_name"] and "rc" not in x["tag_name"])
print(r["tag_name"])
for a in r["assets"]:
    n = a["name"]
    if ("linux" in n and "amd64" in n and n.endswith(".tar.gz")) or "checksums" in n or "sha256" in n.lower():
        print(n, a["browser_download_url"])
