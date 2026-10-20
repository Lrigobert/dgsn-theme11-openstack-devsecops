# Vérification finale — groupe B (DevSecOps) : socle + gitlab. Exécuté depuis l'hôte Windows.
# gitlab : reprise puis redémarrage complet de l'invité -> Vault scellé -> descellement -> GitLab -> runner ->
# pipeline complet (SAST/SCA/build/scan/push/preflight Vault/déploiement).
$ErrorActionPreference = 'Continue'
$vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"; $g = "C:\VMs\gitlab\gitlab.vmx"
function Wait-Ssh($ip, $sec = 600) { $t0 = Get-Date; while (-not (Test-NetConnection $ip -Port 22 -WarningAction SilentlyContinue).TcpTestSucceeded) { if (((Get-Date)-$t0).TotalSeconds -gt $sec) { return $false }; Start-Sleep 5 }; return $true }
"hôte avant : {0:N1} Go" -f ((Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes/1KB)
& $vmrun start $g nogui | Out-Null; "gitlab reprise : exit $LASTEXITCODE"
Wait-Ssh 192.168.100.50 | Out-Null
ssh -o BatchMode=yes jacques1@192.168.100.50 "sudo systemctl reboot" 2>&1 | Out-Null
Start-Sleep 20; $ok = Wait-Ssh 192.168.100.50; "gitlab redémarrée, SSH : $ok"
ssh -o BatchMode=yes jacques1@192.168.100.50 "sudo systemctl disable --now node-exporter.service 2>/dev/null; echo -n 'exporter en clair hérité (node-exporter.service) : '; systemctl is-enabled node-exporter.service 2>&1"
"--- Vault après redémarrage (attendu : scellé puis descellé)"
ssh -o BatchMode=yes jacques1@192.168.100.50 "sudo env VAULT_ADDR=https://127.0.0.1:8200 VAULT_CACERT=/opt/vault/tls/dgsn-root-ca.crt vault status -format=json 2>/dev/null | jq -c '{sealed}'; sudo bash ~/dgsn/p6-vault-unseal.sh"
"--- GitLab"
$t0 = Get-Date
do { Start-Sleep 15; $c = ssh -o BatchMode=yes jacques1@192.168.100.50 "curl -s -o /dev/null -w '%{http_code}' http://192.168.100.50/users/sign_in" 2>$null } while ($c -ne '200' -and ((Get-Date)-$t0).TotalSeconds -lt 900)
"GitLab HTTP $c après {0:N0} s" -f ((Get-Date)-$t0).TotalSeconds
ssh -o BatchMode=yes jacques1@192.168.100.50 "sudo gitlab-runner verify 2>&1 | grep -oE 'is (valid|not valid)'; sudo bash ~/dgsn/p6-ci-lint.sh /home/jacques1/dgsn/demo-app/common/.gitlab-ci.yml | head -1"
"--- Pipeline complet (main, Vault)"
ssh -o BatchMode=yes jacques1@192.168.100.50 "sudo rm -rf /home/jacques1/dgsn/p5-reports/v2-corrige; sudo bash ~/dgsn/p5-push-run.sh v2-corrige 'vérification finale : pipeline complet après redémarrage'"
ssh -o BatchMode=yes jacques1@192.168.100.50 "sudo bash ~/dgsn/p6-log-audit.sh /home/jacques1/dgsn/p5-reports/v2-corrige | tail -3"
curl.exe -s http://192.168.100.220/health; ""
"hôte après : {0:N1} Go" -f ((Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes/1KB)
"VERIF_B_DONE"
