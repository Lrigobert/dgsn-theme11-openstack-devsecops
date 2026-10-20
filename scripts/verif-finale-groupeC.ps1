# Vérification finale — groupe C (supervision) : socle + VM4, gitlab suspendue. Exécuté depuis l'hôte Windows.
$ErrorActionPreference = 'Continue'
$vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
$g = "C:\VMs\gitlab\gitlab.vmx"; $vm4 = "C:\Users\ldard\OneDrive - Efrei\Documents\Virtual Machines\Ubuntuserbveur4\Ubuntuserbveur4.vmx"
function Wait-Ssh($ip, $sec = 300) { $t0 = Get-Date; while (-not (Test-NetConnection $ip -Port 22 -WarningAction SilentlyContinue).TcpTestSucceeded) { if (((Get-Date)-$t0).TotalSeconds -gt $sec) { return $false }; Start-Sleep 5 }; return $true }
& $vmrun suspend $g | Out-Null; "gitlab suspendue : exit $LASTEXITCODE"
& $vmrun start $vm4 nogui | Out-Null; "VM4 reprise : exit $LASTEXITCODE"
Wait-Ssh 192.168.100.30 | Out-Null
ssh -o BatchMode=yes jacques4@192.168.100.30 "sudo systemctl reboot" 2>&1 | Out-Null
Start-Sleep 20; "VM4 redémarrée, SSH : " + (Wait-Ssh 192.168.100.30)
scp -o BatchMode=yes -q C:\DGSN-Theme11\scripts\verif-vm4.sh C:\DGSN-Theme11\scripts\p7-grafana.sh jacques4@192.168.100.30:/tmp/
ssh -o BatchMode=yes jacques4@192.168.100.30 "mkdir -p /tmp/graf"
scp -o BatchMode=yes -q C:\DGSN-Theme11\monitoring\gen-dashboard.py C:\DGSN-Theme11\monitoring\grafana-provisioning.yaml jacques4@192.168.100.30:/tmp/graf/
ssh -o BatchMode=yes jacques4@192.168.100.30 "sed -i 's/\r$//' /tmp/verif-vm4.sh /tmp/p7-grafana.sh /tmp/graf/*; bash /tmp/verif-vm4.sh; sudo bash /tmp/p7-grafana.sh 2>&1 | grep -E 'requêtes avec données|database'"
"hôte : {0:N1} Go" -f ((Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes/1KB)
"VERIF_C_DONE"
