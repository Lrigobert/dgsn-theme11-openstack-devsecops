# Phase 5 — création de la VM gitlab (clone complet de VM1) dans C:\VMs\gitlab.
# Pré-requis : RAM hôte suffisante (>= 4 Go + seuil). VM1 est arrêtée proprement pendant le clonage
# et la personnalisation (le clone démarre avec l'IP .10 de VM1), puis redémarrée.
# Aucune autre VM n'est touchée.
$ErrorActionPreference = 'Stop'
$vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$vm1 = "C:\Users\ldard\OneDrive - Efrei\Documents\Virtual Machines\Ubuntuserveur1\Ubuntuserveur1.vmx"
$dst = "C:\VMs\gitlab\gitlab.vmx"
function Wait-Ssh($ip, $sec = 300) {
  $t0 = Get-Date
  while (-not (Test-NetConnection $ip -Port 22 -WarningAction SilentlyContinue).TcpTestSucceeded) {
    if (((Get-Date) - $t0).TotalSeconds -gt $sec) { throw "SSH $ip injoignable après $sec s" }
    Start-Sleep 5
  }
}

if (Test-Path $dst) { "gitlab.vmx existe déjà : clonage sauté" } else {
  "== Arrêt propre de VM1 =="
  ssh -o BatchMode=yes jacques1@192.168.100.10 "sudo systemctl poweroff" 2>&1 | Out-Null
  $t0 = Get-Date; while ((& $vmrun list) -match [regex]::Escape($vm1)) { if (((Get-Date)-$t0).TotalSeconds -gt 180) { throw "VM1 ne s'arrête pas" }; Start-Sleep 3 }
  & $vmrun snapshot $vm1 "base-clone-gitlab"
  "== Clone complet =="
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  & $vmrun clone $vm1 $dst full -snapshot=base-clone-gitlab -cloneName=gitlab
  if ($LASTEXITCODE -ne 0) { throw "vmrun clone a échoué" }
  $c = Get-Content $dst
  $c = $c -replace '^memsize = .*', 'memsize = "4096"' -replace '^numvcpus = .*', 'numvcpus = "4"'
  $c = $c | Where-Object { $_ -notmatch '^sata0:1\.' }   # pas d'ISO d'installation
  $c += 'sata0:1.present = "FALSE"'
  $c | Set-Content -Encoding ascii $dst
  Select-String -Path $dst -Pattern '^(memsize|numvcpus|displayName)' | ForEach-Object Line
}

"== Premier démarrage du clone (IP .10 temporaire, VM1 arrêtée) =="
if (-not ((& $vmrun list) -match [regex]::Escape($dst))) { & $vmrun start $dst nogui }
ssh-keygen -R 192.168.100.10 2>&1 | Out-Null
Wait-Ssh 192.168.100.10
scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new -q C:\DGSN-Theme11\scripts\perso-vm.sh jacques1@192.168.100.10:/tmp/
ssh -o BatchMode=yes jacques1@192.168.100.10 "sed -i 's/\r$//' /tmp/perso-vm.sh; sudo bash /tmp/perso-vm.sh gitlab 192.168.100.50/24 4 && sudo systemctl reboot"
"== Attente de gitlab sur .50 =="
Start-Sleep 10
Wait-Ssh 192.168.100.50
ssh-keygen -R 192.168.100.10 2>&1 | Out-Null
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new jacques1@192.168.100.50 "hostname; ip -br a | grep ens; free -m | sed -n 2,3p; df -h / | tail -1"

"== Redémarrage de VM1 =="
& $vmrun start $vm1 nogui
Wait-Ssh 192.168.100.10
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new jacques1@192.168.100.10 "hostname"
"P5_GITLAB_VM_OK"
