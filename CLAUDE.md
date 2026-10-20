# Projet : Thème 11 — Cloud privé OpenStack + DevSecOps pour la DGSN
Objectif : réaliser et TESTER le Thème 11 sur le lab VMware local, et produire le livrable (TD/rapport) avec preuves (sorties de commandes, mesures).

## Lab (hôte Windows 11, 24 cœurs, 32 Go RAM, ~400 Go libres sur C:)
- vmrun : "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
- VMs existantes : C:\Users\ldard\OneDrive - Efrei\Documents\Virtual Machines\
  - FreeBSD\FreeBSD.vmx = pfSense 192.168.100.1 (passerelle VMnet1), garder allumée
  - Ubuntuserveur1\Ubuntuserveur1.vmx = VM1 "serveurs1" 192.168.100.10, user jacques1 : poste de déploiement (Ansible/Kolla/Terraform)
  - Ubuntuserbveur4\Ubuntuserbveur4.vmx = VM4 192.168.100.30, user jacques4 : Prometheus :9090 + Grafana :3000
  - Ubuntuserveur3, Ubuntundestock, Windows 10 x64, GNS3, linux : NE PAS démarrer, NE PAS modifier
- Nouvelle VM : C:\VMs\controller\controller.vmx (clone de VM1, 12 Go RAM, 8 vCPU, disque agrandi à 120 Go, vhv.enable="FALSE")
  - NIC ens33 = VMnet1 (gestion), ens37 = NAT VMnet8 192.168.232.0/24 (Internet), 3e NIC = VMnet1 sans IP (externe Neutron)
- Clé SSH Windows : %USERPROFILE%\.ssh\id_ed25519 (pas encore autorisée partout)

## État actuel (à vérifier en premier)
- Hyper-V désactivé dans bcdedit mais VBS encore actif => pas de virtualisation imbriquée => Nova en mode qemu pour l'instant.
- controller est démarré mais PAS personnalisé : il a encore l'IP 192.168.100.10 et le hostname serveurs1.
  VM1 doit rester ÉTEINTE tant que controller n'a pas l'IP 192.168.100.40.

## Version OpenStack : 2025.1 Epoxy (écart au sujet, décidé le 2026-10-18)
- Cible initiale 2024.1 Caracal abandonnée : fin de vie, images Kolla retirées de quay.io (aucun tag 2024.1/2024.2/jammy).
- 2024.1, et a fortiori Yoga/Zed, en fin de vie = plus de correctifs de sécurité : incompatible avec le Security by Design attendu pour la DGSN.
- 2025.1 Epoxy : version maintenue et SLURP (mise à niveau directe vers 2026.1). Images officielles 2025.1-ubuntu-noble.
- Conséquence : controller migré en Ubuntu 24.04 (noble), seul Ubuntu hôte supporté par Kolla-Ansible 2025.1.

## Architecture cible
- controller 192.168.100.40 (Ubuntu 24.04) : OpenStack 2025.1 via Kolla-Ansible déployé depuis VM1, VIP 192.168.100.45 (haproxy/keepalived),
  Keystone, Glance, Nova (qemu), Neutron OVS, Placement, Horizon. Cinder LVM plus tard.
- Réseau externe Neutron flat sur la 3e NIC (VMnet1) : IP flottantes 192.168.100.200-230, gateway 192.168.100.1
- Inventaire Kolla écrit pour être multinœud (ajouter compute2 192.168.100.41 plus tard = 1 ligne)
- Plus tard : gitlab 192.168.100.50 (GitLab CE + Runner + Vault)

## Phases et critères d'acceptation
1. Personnaliser controller : hostname controller, IP .40 sur ens33 (DHCP désactivé), ens37 en DHCP, 3e NIC sans IP, cloud-init réseau désactivé, growpart+pvresize+lvextend (vérifier lsblk avant), nouveau machine-id, nouvelles clés hôte SSH, sudo NOPASSWD pour jacques1, /etc/hosts sans 127.0.1.1. Puis redémarrer VM1.
2. Kolla-Ansible 2025.1 (série 20.x) dans un venv sur VM1, inventaire, globals.yml, kolla-genpwd, bootstrap-servers, prechecks, deploy (dans tmux), post-deploy, init-runonce avec réseau externe 192.168.100.0/24.
   Test : openstack service list ; Horizon http://192.168.100.45 répond ; instance cirros ACTIVE avec IP flottante pingable.
3. Keystone RBAC : projets dgsn-identification, dgsn-pj, dgsn-ops ; rôles admin/member/reader ; test d'accès refusé.
4. Terraform (provider openstack) : 5 instances + groupes de sécurité + cloud-init, temps mesuré (< 10 min).
5. GitLab CE + runner ; pipeline Semgrep, Trivy fs, build, Trivy image, deploy ; temps mesuré (< 8 min) ; montrer un échec puis un succès.
6. Vault pour les secrets OpenStack de la CI.
7. Prometheus/Grafana sur VM4 : openstack-exporter + node-exporter, au moins 10 métriques.
8. OpenSCAP profil CIS sur les instances : score avant/après remédiation Ansible (> 85 %).
9. Résilience : MicroK8s 3 nœuds sur instances, arrêt d'un nœud, failover mesuré (< 30 s).
10. Rapport : architecture, commandes, résultats mesurés, limites, recommandations DGSN.

## Règles
- Snapshot vmrun avant toute étape risquée.
- Jamais de mot de passe, clé ou secret dans les fichiers, le dépôt ou le rapport.
- Si une commande demande un mot de passe : s'arrêter et me dire exactement quoi taper moi-même.
- Nouvelles VM dans C:\VMs, jamais dans OneDrive. Ne pas dépasser ~29 Go de RAM de VM allumées.
- Longs déploiements dans tmux sur VM1.
- Scripts/configs dans C:\DGSN-Theme11 (ansible\, kolla\, terraform\, gitlab\, docs\).
- Consigner chaque test (commande, sortie résumée, horodatage) dans docs\journal.md.
- Une phase n'est terminée qu'après son test réussi.
