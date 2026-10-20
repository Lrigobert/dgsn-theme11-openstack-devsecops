# Surveillance RAM hôte + controller pendant le cycle P4 (tmux "p4" sur VM1).
# S'arrête quand le fichier d'état distant contient un marqueur de fin.
# Si l'hôte passe sous le seuil, la SEULE action est de détruire les instances OpenStack P4 :
#   arrêt du cycle P4 sur VM1 (session tmux p4 + playbook site.yml), puis terraform destroy.
# GARDE-FOU : ce script ne contient et ne doit contenir aucune commande vmrun ni action sur
# les VM VMware (controller, VM1, pfSense, VM4) : il ne fait que lire leur RAM.
param(
  [double] $SeuilGo = 3,
  [string] $StatusFile = '~/dgsn/logs/p4/status.txt',
  [string] $FinRegex = 'P4_FULL_DONE|P4_FULL_FAIL',
  [string] $Sortie = 'C:\DGSN-Theme11\docs\preuves\phase4\ram-watch.txt',
  [int] $MaxMinutes = 30
)
# Action de repli figée (non paramétrable)
$Repli = "tmux kill-session -t p4 2>/dev/null; pkill -f 'ansible-playboo[k] site.yml'; bash ~/dgsn/scripts/p4-cycle.sh destroy"
$t0 = Get-Date; $minH = 99; $lignes = @()
while (((Get-Date) - $t0).TotalMinutes -lt $MaxMinutes) {
  $h = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes / 1KB
  $vmx = (Get-Process vmware-vmx | Sort-Object WorkingSet64 -Descending | Select-Object -First 1).WorkingSet64 / 1GB
  $c = ssh -o BatchMode=yes -o ConnectTimeout=5 jacques1@192.168.100.40 "awk '/MemAvailable/ {print int(`$2/1024)}' /proc/meminfo; cat /sys/kernel/mm/ksm/pages_sharing" 2>$null
  $ksm = if ($c.Count -ge 2) { [int]$c[1] * 4 / 1024 } else { 0 }
  if ($h -lt $minH) { $minH = $h }
  $lignes += "{0} hote={1:N1}Go vmx_controller={2:N1}Go controller_dispo={3}Mo ksm={4:N0}Mo" -f (Get-Date -Format HH:mm:ss), $h, $vmx, $c[0], $ksm
  if ($h -lt $SeuilGo) {
    $lignes += "ALERTE hote {0:N1} Go < seuil {1} Go : arret du cycle P4 + terraform destroy (aucune action VMware)" -f $h, $SeuilGo
    $lignes += ssh -o BatchMode=yes jacques1@192.168.100.10 $Repli 2>&1
    break
  }
  $st = ssh -o BatchMode=yes -o ConnectTimeout=5 jacques1@192.168.100.10 "cat $StatusFile 2>/dev/null" 2>$null
  if (($st -join "`n") -match $FinRegex) { $lignes += $st; break }
  Start-Sleep 15
}
$lignes += "MIN hote {0:N1} Go (seuil {1} Go)" -f $minH, $SeuilGo
$lignes | Set-Content -Encoding utf8 $Sortie
$lignes | Select-Object -Last 12
