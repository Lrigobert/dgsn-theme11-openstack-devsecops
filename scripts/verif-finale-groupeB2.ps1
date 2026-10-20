# Vérification finale — groupe B, reprise après le redémarrage effectif de gitlab (Vault scellé attendu).
$ErrorActionPreference = 'Continue'
ssh -o BatchMode=yes jacques1@192.168.100.50 "echo -n 'démarrage gitlab : '; uptime -s"
"--- Vault (attendu : scellé après redémarrage, puis descellé par le script)"
ssh -o BatchMode=yes jacques1@192.168.100.50 "sudo env VAULT_ADDR=https://127.0.0.1:8200 VAULT_CACERT=/opt/vault/tls/dgsn-root-ca.crt vault status -format=json 2>/dev/null | jq -c '{sealed}'; sudo bash ~/dgsn/p6-vault-unseal.sh"
$t0 = Get-Date
do { Start-Sleep 15; $c = ssh -o BatchMode=yes jacques1@192.168.100.50 "curl -s -o /dev/null -w '%{http_code}' http://192.168.100.50/users/sign_in" 2>$null } while ($c -ne '200' -and ((Get-Date)-$t0).TotalSeconds -lt 900)
"GitLab HTTP $c après {0:N0} s" -f ((Get-Date)-$t0).TotalSeconds
ssh -o BatchMode=yes jacques1@192.168.100.50 "sudo gitlab-runner verify 2>&1 | grep -oE 'is (valid|not valid)'"
"--- Pipeline complet (main, Vault)"
ssh -o BatchMode=yes jacques1@192.168.100.50 "sudo rm -rf /home/jacques1/dgsn/p5-reports/v2-corrige; sudo bash ~/dgsn/p5-push-run.sh v2-corrige 'vérification finale : pipeline après redémarrage effectif et descellement de Vault'"
ssh -o BatchMode=yes jacques1@192.168.100.50 "sudo bash ~/dgsn/p6-log-audit.sh /home/jacques1/dgsn/p5-reports/v2-corrige | tail -3"
ssh -o BatchMode=yes jacques1@192.168.100.10 "bash ~/dgsn/scripts/p6-tls-check.sh | grep -E '8200|P6_TLS'"
curl.exe -s http://192.168.100.220/health; ""
"VERIF_B2_DONE"
