## 5. Tableau des métriques du sujet

| # | Métrique | Objectif | Mesuré | Statut |
|---|---|---|---|---|
| 1 | Terraform apply + configuration Ansible (5 instances) | < 10 min | **141 s** (re-apply 157 s) | ✅ |
| 2 | Pipeline DevSecOps complet | < 8 min | **133 s** (56 s avec Vault et caches) | ✅ |
| 3 | Conformité CIS après remédiation (2 instances) | > 85 % | **91,0 %** (67,4 % avant) | ✅ |
| 4 | Métriques temps réel dans Grafana | ≥ 10 | **28** (16 panneaux) | ✅ |
| 5 | Temps de reprise après arrêt d'un nœud | < 30 s | **1,7 s** | ✅ |

Détail, mesures complémentaires et preuves : `docs/tableau-metriques.md`.

### Statut des phases
| Phase | Statut | Preuve principale |
|---|---|---|
| P1 Préparation du controller | ✅ PASS | `preuves/phase1/03`, `05` |
| P2 OpenStack 2025.1 | ✅ PASS | `preuves/phase2/06-p2-test.txt` |
| P3 RBAC Keystone | ✅ PASS | `preuves/phase3/02-p3-test.txt` |
| P4 Terraform + Ansible | ✅ PASS | `preuves/phase4/43-*` |
| P5 GitLab DevSecOps | ✅ PASS | `preuves/phase5/10`, `20`, `21` |
| P6 Vault + TLS | ✅ PASS | `preuves/phase6/04`, `10`, `12` |
| P7 Supervision | ✅ PASS | `preuves/phase7/07`, `08` |
| P8 OpenSCAP CIS + Fail2Ban | ✅ PASS | `preuves/phase8/01`, `02`, rapports HTML |
| P9 Charge / résilience / restauration | ✅ PASS | `preuves/phase9/` |
| P10 Livrables + vérification finale | voir section « Vérification finale » | `docs/journal.md` |

<!-- SECTION_DIMENSIONNEMENT -->

<!-- SECTIONS_7_10 -->

## 10. Conclusion

Le Thème 11 a été **réalisé et testé de bout en bout** sur un lab volontairement contraint : un cloud privé
OpenStack 2025.1 chiffré, cloisonné par direction métier, entièrement décrit en code, alimenté par une chaîne
DevSecOps qui **bloque** le code vulnérable et ne manipule **aucun secret** en clair, supervisé, conforme au CIS
à 91 % et capable de survivre à la perte brutale d'un nœud en moins de 2 secondes.

Les **cinq métriques du sujet sont atteintes**, avec des marges importantes malgré l'émulation qemu. Les écarts
(version 2025.1, all-in-one, instances réduites, k3s, Vault mono-nœud) sont tous **assumés, mesurés et justifiés**,
et chacun s'accompagne d'une recommandation pour la production.

Au-delà des chiffres, le projet a mis en évidence des enseignements directement utiles à la DGSN :
- la sécurité se **vérifie** (tests de refus, audits, scans) plutôt qu'elle ne se déclare ;
- les incidents réels rencontrés (jeton exposé, secrets hérités par clonage, service saturé) montrent l'intérêt
  de l'automatisation, de la traçabilité et des images de référence ;
- un cloud privé souverain se **dimensionne** : les réglages par défaut supposent des serveurs dédiés, et
  l'ingénierie de capacité fait partie de la sécurité (disponibilité).

## Annexes
- **A. Journal horodaté** de toutes les opérations et tests : `docs/journal.md`.
- **B. Preuves** par phase : `docs/preuves/phase1` à `phase9` (sorties de commandes, rapports HTML OpenSCAP, rapports
  Semgrep/Trivy, export et capture Grafana, sondes CSV du failover).
- **C. Code** : `kolla/` (globals, inventaire, certificats publics), `terraform/` (p4, p5, p8, p9), `ansible/`
  (p4, p8, p9, KSM), `gitlab/` (gitlab.rb, application, pipeline, Vault), `monitoring/`, `scripts/`.
- **D. Reprise du lab** : `docs/guide-reprise.md` ; **démonstration** : `docs/demo.md`.
- **E. Notes détaillées** : `docs/rapport-notes/` (écarts, dimensionnement, sécurité P6).
