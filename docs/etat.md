# État du projet — Thème 11 DGSN

_Dernière mise à jour : 2026-10-20 02:45_

## Statut : **PROJET TERMINÉ** — P1 à P10 validées, vérification finale par groupes PASS

| Phase | Statut | Mesure clé |
|---|---|---|
| P1 controller | PASS | 13/13 critères |
| P2 OpenStack 2025.1 | PASS | deploy 333 s, Horizon HTTPS 200 |
| P3 RBAC | PASS | reader refusé 403 |
| P4 Terraform + Ansible | PASS | 141 s / 157 s (vérif. finale 136 s) |
| P5 GitLab DevSecOps | PASS | v1 bloquée (Semgrep), v2 en 133 s |
| P6 Vault + TLS | PASS | pipeline Vault 52–56 s, 0 secret, TLS 10/10 |
| P7 Supervision | PASS | 28 métriques / 16 panneaux, mTLS |
| P8 OpenSCAP CIS + Fail2Ban | PASS | 67,4 % → 91,0 % |
| P9 Charge / résilience / restauration | PASS | reprise 1,7 s, RTO 61 s |
| P10 Livrables + vérification finale | PASS | groupes A, B, C |

## Livrables (docs/)
- `rapport.md` et `rapport.docx` (18 pages, sommaire, 4 figures), `tableau-metriques.md`, `demo.md`, `guide-reprise.md`,
  `journal.md`, `preuves/`, `rapport-notes/`, `figures/`.

## État du lab laissé
- Allumées : pfSense (1,5 Go), controller (10 Go), VM1 (2 Go), VM4 (4 Go). **gitlab suspendue** (Vault descellé avant
  suspension ; après un redémarrage : `sudo bash ~/dgsn/p6-vault-unseal.sh` sur gitlab).
- Instance OpenStack : dgsn-app-1 (application v2) ACTIVE. Aucune instance de test restante.
- Reprise : `docs/guide-reprise.md`.

## Points d'attention pour l'utilisateur
- **Changer le mot de passe des VM** (communiqué en clair dans la conversation de travail).
- Mot de passe root GitLab initial valable 24 h après installation : à changer à la première connexion.
- Vault : jeton root et clé de descellement dans `/root/.dgsn/vault-init.json` (gitlab) — en production : Shamir 3/5 + révocation du root.
- Snapshots VMware conservés (voir guide de reprise) ; aucun n'a été supprimé.
