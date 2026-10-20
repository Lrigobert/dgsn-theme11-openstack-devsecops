"""Service de démonstration DGSN (Thème 11) — VERSION 2 CORRIGÉE."""
import ipaddress
import subprocess

import yaml
from flask import Flask, abort, request

app = Flask(__name__)


@app.route("/health")
def health():
    return {"status": "ok", "version": "2"}


@app.route("/diag")
def diag():
    # Corrigé : entrée validée (adresse IP uniquement) et pas de shell
    try:
        host = str(ipaddress.ip_address(request.args.get("host", "127.0.0.1")))
    except ValueError:
        abort(400)
    out = subprocess.run(["ping", "-c", "1", host], capture_output=True, text=True, timeout=5, check=False)
    return {"code": out.returncode}


@app.route("/import", methods=["POST"])
def import_conf():
    # Corrigé : chargeur YAML sûr
    data = yaml.safe_load(request.data) or {}
    return {"cles": list(data)}


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8000)
