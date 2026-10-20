# Tableau des métriques du sujet — Thème 11 DGSN

Les cinq métriques chiffrées du sujet, avec la valeur **mesurée sur le lab** et la preuve associée.
Contexte de mesure : nœud OpenStack unique de 10 Go en **émulation qemu** (sans virtualisation imbriquée) —
les valeurs seraient meilleures sur du matériel avec KVM.

| # | Métrique (sujet) | Objectif | Mesuré | Statut | Preuve |
|---|---|---|---|---|---|
| 1 | Provisionnement IaC : `terraform apply` + configuration Ansible de 5 instances (réseau, routeur, 4 groupes de sécurité, IP flottantes) | < 10 min | **141 s** (apply 23 s + Ansible 118 s) ; re-apply après destroy **157 s** | ✅ atteint (×3,8 de marge) | `docs/preuves/phase4/43-apply-1.txt`, `43-apply-2.txt` |
| 2 | Durée du pipeline DevSecOps complet (SAST, SCA, build, scan image, push, déploiement) | < 8 min | **133 s** (v2, P5) ; **56 s** avec Vault et caches chauds (P6) ; pipeline vulnérable bloqué en 88 s | ✅ atteint | `docs/preuves/phase5/20-pipeline-v2.txt`, `phase6/10-pipeline-vault-main.txt`, `phase5/10-pipeline-v1.txt` |
| 3 | Conformité CIS après remédiation Ansible (OpenSCAP, ≥ 2 instances) | > 85 % | **91,0 %** (score XCCDF 90,04) contre 67,4 % avant ; 2 instances ; 0 non-conformité *high* non justifiée | ✅ atteint | `docs/preuves/phase8/01-scores-avant-apres.txt`, rapports HTML `scap-*-{avant,apres}-report.html` |
| 4 | Supervision : métriques temps réel dans Grafana | ≥ 10 | **28 requêtes / 16 panneaux**, 28/28 alimentées | ✅ atteint | `monitoring/dgsn-dashboard.json`, `docs/preuves/phase7/07-grafana-metriques.txt`, `08-dashboard-grafana.png` |
| 5 | Résilience : temps de reprise après arrêt brutal d'un nœud (cluster 3 nœuds) | < 30 s | **1,7 s** (k3s 3 nœuds, `virsh destroy` d'un agent ; 1 échec sur 174 sondes à 0,5 s) | ✅ atteint | `docs/preuves/phase9/failover.txt`, `failover-sonde.csv` |

## Mesures complémentaires
| Mesure | Valeur | Preuve |
|---|---|---|
| Déploiement OpenStack 2025.1 (Kolla `deploy`) | 333 s | `docs/journal.md` (P2) |
| Instance cirros jusqu'à ACTIVE | 11–18 s | `docs/preuves/phase2/06-p2-test.txt` |
| Latence API avec 1 worker (moyenne sur 10 appels) | Keystone 9 ms, Nova 19 ms, Neutron 19 ms, Glance 5 ms, Placement 5 ms | `docs/preuves/phase4/15-api-latency-1worker.txt` |
| Gain mémoire de l'allègement Kolla | −3 134 Mo (−43 %) | `docs/rapport-notes/dimensionnement.md` |
| KSM sur 5 instances identiques | 716–892 Mo économisés | `docs/journal.md` (P4) |
| Endpoints chiffrés | 10/10 en TLS 1.3 vérifié | `docs/preuves/phase6/04-tls-check.txt` |
| Secrets en variables CI / dans les journaux | 0 / 0 | `docs/preuves/phase6/07`, `11` |
| Charge du plan de contrôle : 8 instances en un appel | 8/8 ACTIVE en 28 s (17,1 instances/min), 0 erreur | `docs/preuves/phase9/burst.txt` |
| Charge applicative (ab, 3000 requêtes, 20 concurrents) | 127,8 req/s ; médiane 75 ms ; p95 552 ms ; 0 erreur réelle | `docs/preuves/phase9/charge.txt` |
| Restauration depuis snapshot Glance (RTO) | snapshot 16 s ; RTO 61 s ; donnée témoin intacte | `docs/preuves/phase9/restore.txt` |
| Fail2Ban | IP attaquante bannie après 3 échecs ; port 22 bloqué | `docs/preuves/phase8/02-analyse-fail2ban.txt` |

**Bilan : 5 métriques sur 5 atteintes.**
