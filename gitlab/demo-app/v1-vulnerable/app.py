"""Service de démonstration DGSN (Thème 11) — VERSION 1 VOLONTAIREMENT VULNÉRABLE.
Sert à prouver que le pipeline DevSecOps bloque le déploiement. Ne jamais utiliser en production.
"""
import subprocess

import yaml
from flask import Flask, request

app = Flask(__name__)


@app.route("/health")
def health():
    return {"status": "ok", "version": "1"}


@app.route("/diag")
def diag():
    # VULNÉRABLE (CWE-78) : injection de commande, paramètre utilisateur passé au shell
    host = request.args.get("host", "127.0.0.1")
    out = subprocess.check_output("ping -c 1 " + host, shell=True)
    return out


@app.route("/import", methods=["POST"])
def import_conf():
    # VULNÉRABLE (CWE-502) : désérialisation YAML non sûre
    data = yaml.load(request.data, Loader=yaml.Loader)
    return {"cles": list(data)}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
