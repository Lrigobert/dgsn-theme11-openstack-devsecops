#!/usr/bin/env python3
"""Derniers tags semver stables d'images Docker Hub (pour épingler les outils CI).
Usage : hub-tags.py semgrep/semgrep aquasec/trivy library/docker"""
import json
import re
import sys
import urllib.request

for repo in sys.argv[1:]:
    url = f"https://hub.docker.com/v2/repositories/{repo}/tags?page_size=100&ordering=last_updated"
    tags = [t["name"] for t in json.load(urllib.request.urlopen(url, timeout=30))["results"]]
    semver = sorted({t for t in tags if re.fullmatch(r"v?\d+\.\d+\.\d+(-cli)?", t)},
                    key=lambda t: [int(x) for x in re.findall(r"\d+", t)], reverse=True)
    print(f"{repo}: {semver[:5]}")
