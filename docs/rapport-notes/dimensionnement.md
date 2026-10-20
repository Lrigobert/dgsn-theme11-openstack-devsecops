# Dimensionnement d'un cloud privé contraint (notes pour le rapport)

Contexte : un seul nœud controller/compute de 12 Go et 8 vCPU, virtualisé sous VMware
sans virtualisation imbriquée (VBS actif sur l'hôte) → Nova en émulation qemu (TCG) :
la RAM des instances est réellement consommée et le CPU est émulé.

## Incident déclencheur (P4, essai 1)
- 5 instances Debian 12 de 512 Mo lancées par Terraform : la 5e échoue (Nova API 408 via haproxy).
- Controller à 435 Mo disponibles, hôte Windows sous le seuil de 3 Go.
- Cause : la plateforme seule consommait ~8,8 Go (33 conteneurs) avec les réglages Kolla par défaut.

## Optimisations et gains mesurés
Mesures avec `scripts/mem-measure.sh`, 3 min après stabilisation, sans instance.

| # | Optimisation | Défaut Kolla 2025.1 | Réglage DGSN lab |
|---|---|---|---|
| O1 | Workers API (`openstack_service_workers`) | min(vCPU, 5) = 5 | 1 |
| O2 | Workers RPC (`openstack_service_rpc_workers`) | min(vCPU, 3) = 3 | 1 |
| O3 | Heat (orchestration) | activé | désactivé (Terraform le remplace) |
| O4 | fluentd (collecte de logs) | activé | désactivé (logs en fichiers ; supervision en P7) |
| O5 | MariaDB `innodb_buffer_pool_size` | 40 % de la RAM ≈ 4,7 Go | 256 Mo (kolla/config/galera.cnf) |
| O6 | memcached `-m` | 256 Mo | 128 Mo |

| Mesure | Avant (O1–O6) | Après | Gain |
|---|---|---|---|
| Conteneurs | 33 | 29 | −4 |
| Mémoire des conteneurs | 7 248 Mo | 4 114 Mo | **−3 134 Mo (−43 %)** |
| RAM disponible controller | 3 748 Mo | 7 505 Mo | **+3 757 Mo (×2)** |

Preuves : docs/preuves/phase4/10-mem-avant-allegement.txt, 12-mem-apres-allegement.txt.

## Non-régression
- P3 (RBAC) : 7/7 PASS après allègement.
- P2 : voir journal (test rendu autonome : instance cirros recréée à chaque exécution).

## KSM (déduplication mémoire des instances)
- Activé sur controller (ansible/ksm.yml) : pages_to_scan 1000, sleep 50 ms.
- 5 instances Debian 12 identiques (512 Mo) : **716 à 884 Mo économisés** en ~2 min (≈ 30 % de la RAM des invités).

## Budget mémoire de l'hôte (31,4 Go)
| Poste | Initial | Après optimisations |
|---|---|---|
| controller (memsize) | 12 288 Mo (processus VMware jusqu'à 14,6 Go) | **10 240 Mo** |
| pfSense | 3 104 Mo | **1 536 Mo** |
| VM4 (Prometheus/Grafana) | 4 096 Mo | suspendue jusqu'à P7 |
| VM1 (déploiement) | 4 096 Mo | **2 048 Mo** |
| Total VM allumées | 23,6 Go | **13,8 Go** (+ gitlab 4 Go en P5) |
| Empreinte hôte du processus VMware du controller | jusqu'à 14,6 Go (invité 12 Go) | 7,8 Go au démarrage, jusqu'à ~14,9 Go après pics d'instances (invité 10 Go, cache de fichiers inclus) |

Constat : VMware ne rend pas à l'hôte la mémoire libérée dans l'invité (pas de pression → pas de ballooning) ;
après un pic, seul un redémarrage de la VM ramène son empreinte au niveau de la charge réelle.

## Enseignements pour la DGSN (production)
- Les valeurs par défaut de Kolla visent des serveurs physiques (≥ 64 Go) : en production, garder plusieurs
  workers par API sur des contrôleurs dédiés (3 nœuds HA), séparés des computes.
- Ne jamais co-localiser contrôle et calcul sur un nœud contraint : la contention mémoire dégrade
  d'abord les API (408/503), donc la disponibilité du service.
- Dimensionner le buffer pool MariaDB sur la taille réelle des bases, pas sur la RAM de l'hôte
  quand des instances partagent le nœud.
- Réserver explicitement la mémoire de l'hôte (`reserved_host_memory_mb`) pour que Placement
  n'ordonnance pas d'instance dans la RAM des services.
