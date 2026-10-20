# Guide de reprise du lab — Thème 11 DGSN

Ce guide permet de redémarrer tout ou partie du lab après un arrêt, et de vérifier qu'il fonctionne.
Aucun secret n'y figure : les emplacements des secrets sont indiqués, jamais leur valeur.

## 1. Contraintes à connaître
- **Hôte** : 31,4 Go de RAM. Les VM ne peuvent **pas toutes** tourner ensemble avec les applications Windows
  (navigateur, etc.). On travaille **par groupes** (section 3). Garder **≥ 1,5 Go** de RAM disponible sur l'hôte :
  ```powershell
  "{0:N1} Go" -f ((Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes/1KB)
  ```
- **VMware ne rend pas** à l'hôte la mémoire libérée dans une VM : après un pic (beaucoup d'instances), faire un
  **arrêt propre puis un démarrage** du controller (pas un simple reboot invité).
- Ne jamais démarrer : Ubuntuserveur3, Ubuntundestock, Windows 10 x64, GNS3, linux.

## 2. Inventaire
| VM | Fichier | RAM | IP | Rôle |
|---|---|---|---|---|
| pfSense | `…\Virtual Machines\FreeBSD\FreeBSD.vmx` | 1,5 Go | .1 | passerelle VMnet1 (sans VMware Tools : arrêt via la console, option 6) |
| controller | `C:\VMs\controller\controller.vmx` | 10 Go | .40 (VIP .45) | OpenStack 2025.1 |
| VM1 | `…\Virtual Machines\Ubuntuserveur1\Ubuntuserveur1.vmx` | 2 Go | .10 | déploiement, PKI, Terraform |
| gitlab | `C:\VMs\gitlab\gitlab.vmx` | 4 Go | .50 | GitLab, Runner, Vault |
| VM4 | `…\Virtual Machines\Ubuntuserbveur4\Ubuntuserbveur4.vmx` | 4 Go | .30 | Prometheus, Grafana |

```powershell
$vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
& $vmrun list
```

## 3. Groupes de démarrage
| Groupe | VM allumées | Usage |
|---|---|---|
| **Socle** (toujours) | pfSense, controller, VM1 | OpenStack, Terraform, tests P1–P4, P8, P9 |
| **DevSecOps** | socle + gitlab | P5, P6 (pipeline, Vault) |
| **Supervision** | socle + VM4 | P7 (gitlab suspendue) |

Ordre : **pfSense → controller → VM1 → (gitlab ou VM4)**. Arrêt dans l'ordre inverse.

## 4. Démarrage pas à pas
1. **pfSense** : `& $vmrun start "<FreeBSD.vmx>" nogui` ; attendre `Test-Connection 192.168.100.1`.
2. **controller** : `& $vmrun start C:\VMs\controller\controller.vmx nogui`.
   Attendre ~3 min (conteneurs Kolla), puis depuis VM1 :
   ```bash
   . ~/kolla-venv/bin/activate && . /etc/kolla/admin-openrc.sh && openstack compute service list
   ```
   Tous les services doivent être `up`. Les instances reviennent **SHUTOFF** : relancer l'application de démonstration :
   ```bash
   bash ~/dgsn/scripts/p5-app-start.sh
   ```
   Si un precheck/redéploiement Kolla échoue juste après le démarrage : attendre la synchronisation NTP
   (`timedatectl` → `System clock synchronized: yes`).
3. **VM1** : `& $vmrun start "<Ubuntuserveur1.vmx>" nogui`.
4. **gitlab** (groupe DevSecOps) : `& $vmrun start C:\VMs\gitlab\gitlab.vmx nogui` (reprise si suspendue).
   **Vault doit être descellé** après un redémarrage (après une simple reprise de suspension, il l'est déjà) :
   ```bash
   ssh jacques1@192.168.100.50 "sudo bash ~/dgsn/p6-vault-unseal.sh"     # attendu : "sealed":false
   ```
   GitLab met ~3 min à répondre (`http://192.168.100.50/users/sign_in` → 200).
5. **VM4** (groupe Supervision) : `& $vmrun start "<Ubuntuserbveur4.vmx>" nogui`.
   Prometheus : http://192.168.100.30:9090/targets (jobs `dgsn-*` up) ; Grafana : http://192.168.100.30:3000,
   dossier « DGSN Thème 11 ».

## 5. Vérifications rapides (depuis VM1)
| Contrôle | Commande | Attendu |
|---|---|---|
| Nœud controller | `bash /tmp/p1t.sh` (copier `scripts/p1-test.sh`) | `P1_CONTROLLER_PASS` |
| OpenStack | `bash ~/dgsn/scripts/p2-test.sh` | `P2_TEST_PASS` |
| RBAC | `bash ~/dgsn/scripts/p3-test.sh` | `P3_TEST_PASS` |
| TLS | `bash ~/dgsn/scripts/p6-tls-check.sh` | `P6_TLS_PASS` |
| IaC | `bash ~/dgsn/scripts/p4-cycle.sh apply` puis `destroy` | `P4_APPLY_PASS` |

## 6. Accès (emplacement des secrets, jamais leur valeur)
- Horizon : https://192.168.100.45 — `admin` ; mot de passe sur VM1 :
  `grep '^keystone_admin_password' /etc/kolla/passwords.yml` (CA à importer : `kolla/certificates/dgsn-root-ca.crt`).
- GitLab : http://192.168.100.50 — `root` ; mot de passe initial (24 h) : `sudo cat /etc/gitlab/initial_root_password`.
- Vault : https://192.168.100.50:8200 — jeton root et clé de descellement dans `/root/.dgsn/vault-init.json` (gitlab).
- Utilisateurs RBAC : `~/dgsn/secrets/p3-*.env` (VM1, 600).

## 7. Retour arrière (snapshots VMware)
| VM | Snapshots utiles |
|---|---|
| controller | `p2-openstack-ok`, `avant-allegement`, `avant-10go`, `p5-ok-avant-tls` (et antérieurs) |
| VM1 | `avant-p1-p2`, `base-clone-gitlab` |
| gitlab | `perso-avant-gitlab` |
| pfSense | `avant-ram-1536` |

Restauration (VM éteinte) : `& $vmrun revertToSnapshot <vmx> <nom>`.
