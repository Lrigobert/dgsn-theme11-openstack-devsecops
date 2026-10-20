# Écarts au sujet (à intégrer au rapport)

## E1 — OpenStack 2025.1 Epoxy au lieu de 2024.1 Caracal (2026-10-18)
- **Constat** : au déploiement, `kolla-ansible pull` échoue (404). L'API quay.io ne liste plus aucun tag 2024.1, 2024.2 ni jammy pour les images Kolla. Seules 2025.1 et 2025.2 sont publiées (ubuntu-noble, debian-bookworm, rocky).
- **Alternatives étudiées** : (A) reconstruire les images 2024.1 avec kolla-build 18.8.0 (sources encore disponibles) ; (B) passer en 2025.1.
- **Choix** : (B). Une version en fin de vie ne reçoit plus de correctifs de sécurité, ce qui est incompatible avec le Security by Design exigé pour une infrastructure DGSN. Reconstruire des images EOL reporterait le problème. 2025.1 est une version SLURP maintenue.
- **Conséquences** : hôte controller migré en Ubuntu 24.04 (exigence de Kolla-Ansible 2025.1) ; Kolla-Ansible 20.x ; collections Ansible alignées sur 2025.1.

## E2 — Poste de déploiement VM1 resté en Ubuntu 22.04
- Kolla-Ansible 2025.1 n'accepte que Ubuntu 24.04 comme **hôte OpenStack**. VM1 ne fait que piloter Ansible (aucun conteneur) ; Kolla-Ansible 20.6.0 y fonctionne (Python 3.10, ansible-core 2.17).
- Seul le contrôle d'OS du groupe `deployment` (localhost) est désactivé dans l'inventaire ; controller reste vérifié.
- Recommandation production : poste de déploiement dédié en 24.04, durci, avec accès bastion.

## E3 — Instances réduites (flavor dgsn.p4 : 1 vCPU, 512 Mo, 5 Go) et services applicatifs de démonstration
- Le nœud unique (10 Go, qemu sans virtualisation imbriquée) ne peut héberger 5 instances « m1.small » (2 Go).
- Les services web/app sont des serveurs HTTP Python confinés par systemd (DynamicUser, ProtectSystem=strict) au lieu de nginx/PostgreSQL, pour tenir le temps de démarrage sous émulation.
- La mesure < 10 min porte sur l'infrastructure complète (réseau, routeur, 4 groupes de sécurité, 5 ports, 5 instances, 3 IP flottantes) + configuration Ansible.
