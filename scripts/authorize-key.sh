#!/usr/bin/env bash
# Usage : authorize-key.sh <fichier .pub>  — ajoute la clé publique à ~/.ssh/authorized_keys
# (idempotent ; retire les BOM UTF-8 et CR éventuellement introduits par Windows).
set -euo pipefail
key=$(sed 's/^\xEF\xBB\xBF//; s/\r$//' "$1")
mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys
sed -i 's/^\xEF\xBB\xBF//; s/\r$//' ~/.ssh/authorized_keys
grep -qxF "$key" ~/.ssh/authorized_keys || echo "$key" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "cles: $(grep -c '^ssh-' ~/.ssh/authorized_keys)  ok: $(grep -cxF "$key" ~/.ssh/authorized_keys)"
