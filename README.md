# Thème 11 — Cloud privé OpenStack sécurisé et DevSecOps (DGSN)

Projet de fin d'études (Licence Réseaux et Systèmes Informatiques, option Cybersécurité).
Cloud privé souverain pour la Délégation Générale à la Sûreté Nationale (Cameroun), réalisé et testé sur un lab VMware.

## Architecture
- OpenStack 2025.1 (Kolla-Ansible) : Keystone, Glance, Nova, Neutron, Placement, Horizon — TLS 1.3
- Infrastructure as Code : Terraform + Ansible
- DevSecOps : GitLab CE, Semgrep (SAST), Trivy (dépendances + images), HashiCorp Vault
- Supervision : Prometheus + Grafana ; conformité : OpenSCAP (CIS) + Fail2Ban ; résilience : k3s

## Résultats
| Métrique | Objectif | Mesuré |
|---|---|---|
| 5 instances (Terraform + Ansible) | < 10 min | 141 s |
| Pipeline DevSecOps complet | < 8 min | 133 s |
| Conformité CIS | > 85 % | 91,0 % |
| Métriques Grafana | ≥ 10 | 28 |
| Reprise après panne d'un nœud | < 30 s | 1,7 s |

## Structure
`kolla/` · `terraform/` · `ansible/` · `gitlab/` · `monitoring/` · `scripts/` · `docs/` (rapport, journal, preuves, démo, guide de reprise)

> Lab pédagogique : configurations adaptées à un environnement contraint, à ne pas réutiliser tel quel en production.
