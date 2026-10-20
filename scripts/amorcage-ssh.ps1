# Amorçage d'une VM : autorise la clé SSH Windows et configure sudo NOPASSWD.
# À lancer UNE fois par VM, dans un terminal interactif : le mot de passe est
# demandé par ssh puis par sudo, et n'est jamais écrit dans un fichier.
# Usage : powershell -ExecutionPolicy Bypass -File scripts\amorcage-ssh.ps1 -Cible 192.168.100.10 -User jacques1
param(
    [Parameter(Mandatory)] [string] $Cible,
    [Parameter(Mandatory)] [string] $User
)

$pub = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub" -Raw
$pub = $pub.Trim()

$remote = @"
set -e
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
grep -qxF '$pub' ~/.ssh/authorized_keys || echo '$pub' >> ~/.ssh/authorized_keys
echo '$User ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-$User >/dev/null
sudo chmod 440 /etc/sudoers.d/90-$User
sudo visudo -c >/dev/null
echo AMORCAGE_OK
"@ -replace "`r", ""

ssh -t -o StrictHostKeyChecking=accept-new "$User@$Cible" $remote
