#!/usr/bin/env bash
# Phase 2 — déploiement OpenStack 2025.1 (Kolla-Ansible 20.x) depuis VM1. À lancer dans tmux :
#   tmux new -d -s kolla 'bash ~/dgsn/scripts/p2-deploy.sh [etape_de_depart]'
# Étapes : bootstrap prechecks pull deploy postdeploy. Journal : ~/dgsn/logs/
set -uo pipefail
. ~/kolla-venv/bin/activate
INV=~/dgsn/inventory/multinode
LOG=~/dgsn/logs; mkdir -p "$LOG"
STATUS="$LOG/status.txt"
ETAPES=(bootstrap prechecks pull deploy postdeploy)
START=${1:-bootstrap}

run() {  # run <nom> <commande...>
  local name=$1; shift
  local t0=$(date +%s)
  echo "$(date -Is) START $name" | tee -a "$STATUS"
  if "$@" > "$LOG/$name.log" 2>&1; then
    echo "$(date -Is) OK    $name ($(( $(date +%s) - t0 )) s)" | tee -a "$STATUS"
  else
    echo "$(date -Is) FAIL  $name ($(( $(date +%s) - t0 )) s) — voir $LOG/$name.log" | tee -a "$STATUS"
    exit 1
  fi
}

# Reconfiguration seule (changement de globals.yml / config) : prechecks puis reconfigure
if [ "$START" = reconfigure ]; then
  run prechecks   kolla-ansible prechecks -i "$INV"
  run reconfigure kolla-ansible reconfigure -i "$INV"
  echo "$(date -Is) P2_RECONFIGURE_DONE" | tee -a "$STATUS"; exit 0
fi

go=0
for e in "${ETAPES[@]}"; do
  [ "$e" = "$START" ] && go=1
  [ $go = 1 ] || continue
  case $e in
    # Syntaxe kolla-ansible 2025.1 : action d'abord, puis -i <inventaire>
    bootstrap)  run bootstrap  kolla-ansible bootstrap-servers -i "$INV" ;;
    prechecks)  run prechecks  kolla-ansible prechecks -i "$INV" ;;
    pull)       run pull       kolla-ansible pull -i "$INV" ;;
    deploy)     run deploy     kolla-ansible deploy -i "$INV" ;;
    postdeploy) run postdeploy kolla-ansible post-deploy -i "$INV" ;;
  esac
done
echo "$(date -Is) P2_DEPLOY_DONE" | tee -a "$STATUS"
