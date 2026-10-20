# Démonstration de soutenance — 10 minutes

**Pré-requis** (15 min avant) : groupe **Socle + DevSecOps** démarré (pfSense, controller, VM1, gitlab ; voir
`guide-reprise.md`), Vault descellé, application relancée (`p5-app-start.sh`). Ouvrir dans le navigateur :
Horizon (https://192.168.100.45), GitLab (http://192.168.100.50/dgsn/demo-app/-/pipelines), et la capture du
dashboard Grafana (`docs/preuves/phase7/08-dashboard-grafana.png`) ou Grafana en direct si VM4 est démarrée.
Terminal : une session SSH sur VM1 (`ssh jacques1@192.168.100.10`), puis
`. ~/kolla-venv/bin/activate && . /etc/kolla/admin-openrc.sh`.

| Min | Étape | Commande / action | Résultat attendu |
|---|---|---|---|
| 0:00 | **Contexte** (oral) | Schéma section 2 du rapport | Cloud privé souverain, cloisonné, automatisé, DevSecOps |
| 0:45 | **OpenStack opérationnel, chiffré** | `openstack service list` puis `openstack endpoint list -c "Service Name" -c URL \| head` | Keystone, Nova, Neutron, Glance, Placement ; toutes les URL en **https://** |
| 1:30 | **TLS vérifié** | `bash ~/dgsn/scripts/p6-tls-check.sh` | 10 lignes **PASS**, TLS 1.3, HTTP clair refusé |
| 2:15 | **Cloisonnement RBAC** | `bash ~/dgsn/scripts/p3-test.sh` | Le *reader* reçoit **403** « Policy doesn't allow os_compute_api:servers:create » |
| 3:15 | **Infrastructure as Code** | `time bash ~/dgsn/scripts/p4-cycle.sh apply` | 5 instances + réseau + 4 secgroups + Ansible en **~2 min 30** ; tests d'isolement PASS |
| 5:45 | (pendant l'apply) **Horizon** | Projet dgsn-ops → Topologie réseau | Bastion, web ×2, app, db sur 10.40.0.0/24 |
| 6:00 | **DevSecOps : blocage** | GitLab → pipeline de la v1 (#2) → job `semgrep-sast` | **Échoué** : injection de commande, `yaml.load` ; déploiement non exécuté |
| 6:45 | **DevSecOps : succès + Vault** | Pipeline #5 → job `openstack-preflight` puis `deploy-openstack` | « Vault : connexion acceptée », application credential, instance ACTIVE, déployé |
| 7:30 | **Refus Vault hors main** | Pipeline #6 (branche `feature/test-vault`) | « Vault : connexion REFUSÉE … claim "ref" » |
| 8:00 | **Application durcie** | `curl http://192.168.100.220/health` ; `curl -o /dev/null -w '%{http_code}\n' "http://192.168.100.220/diag?host=127.0.0.1;id"` | `{"status":"ok","version":"2"}` ; **400** |
| 8:30 | **Supervision** | Dashboard Grafana | 16 panneaux : services up, instances, vCPU/RAM, nœuds |
| 9:00 | **Conformité et résilience** (résultats) | Rapport section 5 + rapports HTML OpenSCAP | Score CIS avant/après ; failover k3s mesuré |
| 9:30 | **Nettoyage + conclusion** | `bash ~/dgsn/scripts/p4-cycle.sh destroy` | 0 instance restante ; recommandations DGSN |

**Plan B** (lab indisponible) : dérouler les mêmes étapes avec les preuves de `docs/preuves/phaseN/` (sorties
horodatées, rapports HTML, capture Grafana, journaux de pipelines).
