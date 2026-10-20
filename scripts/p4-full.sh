#!/usr/bin/env bash
# Phase 4 — test complet : apply+Ansible+tests, destroy, re-apply+Ansible+tests, destroy final.
# À lancer dans tmux sur VM1 : tmux new -d -s p4 'bash ~/dgsn/scripts/p4-full.sh'
# Résultats : ~/dgsn/logs/p4/ (un fichier par étape) et ~/dgsn/logs/p4/status.txt
L=~/dgsn/logs/p4; mkdir -p "$L"; S=$L/status.txt; : > "$S"
step() {  # step <nom> <action p4-cycle>
  echo "$(date -Is) START $1" >> "$S"
  if bash ~/dgsn/scripts/p4-cycle.sh "$2" > "$L/$1.txt" 2>&1; then
    echo "$(date -Is) PASS  $1" >> "$S"
  else
    echo "$(date -Is) FAIL  $1" >> "$S"
    bash ~/dgsn/scripts/p4-cycle.sh destroy > "$L/destroy-apres-echec.txt" 2>&1
    echo "$(date -Is) P4_FULL_FAIL" >> "$S"; exit 1
  fi
}
step apply-1   apply
step destroy-1 destroy
step apply-2   apply
step destroy-2 destroy
echo "$(date -Is) P4_FULL_DONE" >> "$S"
