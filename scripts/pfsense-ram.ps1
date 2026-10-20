# Réduction de la RAM de pfSense (3104 -> 1536 Mo). À lancer APRÈS l'arrêt de pfSense
# par l'utilisateur depuis sa console (option 6 « Halt system ») : pas de VMware Tools.
$ErrorActionPreference = 'Stop'
$vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$pf = "C:\Users\ldard\OneDrive - Efrei\Documents\Virtual Machines\FreeBSD\FreeBSD.vmx"
$cible = 1536

if ((& $vmrun list) -match [regex]::Escape($pf)) { throw "pfSense est encore allumé : l'arrêter depuis sa console (option 6) avant." }

$avant = (Select-String -Path $pf -Pattern '^memsize').Line
& $vmrun snapshot $pf "avant-ram-1536" | Out-Null
(Get-Content $pf) -replace '^memsize = .*', "memsize = `"$cible`"" | Set-Content -Encoding ascii $pf
$apres = (Select-String -Path $pf -Pattern '^memsize').Line
"pfSense : $avant -> $apres (snapshot avant-ram-1536)"

& $vmrun start $pf nogui
$t0 = Get-Date
while (-not (Test-Connection 192.168.100.1 -Count 1 -Quiet)) {
  if (((Get-Date) - $t0).TotalSeconds -gt 300) { throw "192.168.100.1 ne répond pas après 300 s" }
  Start-Sleep 5
}
"192.168.100.1 répond après {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds
ssh -o BatchMode=yes jacques1@192.168.100.40 "ping -c2 -W2 192.168.100.1 | tail -1; ping -c2 -W2 8.8.8.8 | tail -1; getent hosts archive.ubuntu.com | head -1"
