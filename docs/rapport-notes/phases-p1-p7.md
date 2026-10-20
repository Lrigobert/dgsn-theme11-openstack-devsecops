## 4. Mise en œuvre et résultats par phase

Chaque phase suit la même méthode : planifier, sécuriser (snapshot), construire en code, tester, corriger en boucle,
prouver (journal + preuves), mettre à jour l'état. Les commandes exactes sont dans `scripts/` ; les sorties dans
`docs/preuves/phaseN/`.

### P1 — Préparation du nœud controller — **PASS**
- Clone de VM1 personnalisé par `scripts/p1-controller.sh` (idempotent) : hostname, IP .40 statique (ens33), NAT en
  DHCP (ens37), 3ᵉ interface sans IP pour Neutron (ens38), cloud-init réseau désactivé, disque étendu
  (growpart + pvresize + lvextend : `/` à 116 Go), **nouveau machine-id et nouvelles clés hôte SSH**, sudo sans mot de passe.
- Puis migration Ubuntu 22.04 → **24.04.5** (`scripts/p2-upgrade-noble.sh`, non interactif, 11 min) exigée par
  Kolla 2025.1.
- Test `scripts/p1-test.sh` : **13/13 critères PASS**, rejoué après la migration (13/13). SSH par clé + sudo
  vérifiés sur controller, VM1 et VM4.
- Incidents corrigés : `lsblk -no PKNAME` renvoyant deux lignes (growpart en échec) → `lsblk -dno` ; fichier sudoers
  créé à l'amorçage avec de mauvais droits.

### P2 — OpenStack 2025.1 avec Kolla-Ansible — **PASS**
- Kolla-Ansible 20.6.0 dans un venv sur VM1 (ansible-core 2.17, compatible Python 3.10 de VM1), inventaire
  multinœud, `globals.yml` versionné, mots de passe générés sur VM1 uniquement.
- Déroulé : bootstrap-servers 44 s, prechecks 39 s, pull 306 s, **deploy 333 s** (407 tâches, 0 échec),
  post-deploy, `init-runonce` adapté (réseau externe 192.168.100.0/24, pool .200–.230).
- Test `scripts/p2-test.sh` : services Keystone/Glance/Nova/Neutron/Placement enregistrés, agents up, **Horizon
  HTTP 200**, réseau tenant **VXLAN** et externe **flat**, instance cirros **ACTIVE en 11–18 s**, **IP flottante
  pingable** depuis VM1, groupe de sécurité prouvé (ports 22/8080 ouverts, 8081 bloqué, puis ouvert après ajout de
  la règle : contre-preuve).
- Écarts : E1 (2025.1 au lieu de 2024.1), E2 (VM1 reste en 22.04 : exemption du contrôle d'OS pour le seul hôte de
  pilotage). Incidents : branche `stable/2024.1` supprimée, collections Ansible manquantes, prechecks NTP.

### P3 — Cloisonnement Keystone (RBAC) — **PASS**
- Projets `dgsn-identification`, `dgsn-pj`, `dgsn-ops` ; un utilisateur par rôle (reader, member, admin) ; mots de
  passe aléatoires stockés sur VM1 uniquement.
- Test `scripts/p3-test.sh` (7/7) : le **reader ne peut pas créer d'instance** — refus prouvé :
  `403 Policy doesn't allow os_compute_api:servers:create` — ni de réseau (403) ; le member travaille dans son projet
  mais ne peut ni accéder à `dgsn-identification` (401) ni lister les utilisateurs ; l'admin administre.

### P4 — Infrastructure as Code (Terraform + Ansible) — **PASS**
- `terraform/p4` : réseau 10.40.0.0/24 + routeur, **4 groupes de sécurité cloisonnés** (bastion, web, app, db),
  5 ports, **5 instances** Debian 12 avec cloud-init (durcissement SSH), 3 IP flottantes, inventaire et `ssh_config`
  Ansible générés. Accès SSH **uniquement via le bastion** (ProxyJump).
- `ansible/p4/site.yml` : bannière légale, durcissement SSH, sysctl réseau, services de démonstration confinés par
  systemd (DynamicUser, ProtectSystem=strict).
- **Mesures** : apply 23 s + Ansible 118 s = **141 s** ; après destroy (13 s), re-apply 34 s + 123 s = **157 s**
  (objectif < 600 s, marge ×3,8). Tests d'isolement à chaque apply (10/10) : SSH direct vers web refusé,
  web→app:8080 autorisé, bastion→app bloqué, web→db:5432 bloqué.
- Écart E3 : flavor réduite (1 vCPU / 512 Mo) ; atteinte après un travail de dimensionnement (section 6).

### P5 — GitLab CE et pipeline DevSecOps — **PASS**
- VM gitlab (4 Go + 4 Go de swap) clonée de VM1 puis **nettoyée des secrets hérités** (constat de sécurité) ;
  GitLab CE 19.5 en mode économe (Puma single, Sidekiq 5, supervision interne désactivée) installé en 289 s ;
  runner Docker (concurrence 1).
- Pipeline : Semgrep → Trivy fs → build → Trivy image → push registre → déploiement automatique sur une instance
  OpenStack (`dgsn-app-1`, Docker installé par cloud-init).
- **Application volontairement vulnérable (v1)** : pipeline **bloqué en 88 s par Semgrep** — 6 findings dont injection
  de commande (`subprocess` + `shell=True`, CWE-78) et désérialisation YAML (`yaml.load`, CWE-502) ; aucune étape
  suivante exécutée.
- **Version corrigée (v2)** : pipeline **réussi en 133 s** (objectif < 480 s) ; 0 finding, 0 CVE HIGH/CRITICAL
  (dépendances et image Alpine 3.24) ; application déployée, injection neutralisée (`/diag?host=127.0.0.1;id` → 400),
  conteneur durci (rootfs en lecture seule, `cap_drop=ALL`, `no-new-privileges`, utilisateur non root).
- Rapports Semgrep/Trivy sauvegardés (`docs/preuves/phase5/`).

### P6 — Vault, application credentials et TLS — **PASS**
- PKI interne (CA ECDSA P-384), certificats serveurs OpenStack et Vault.
- **TLS Kolla interne + externe** : `scripts/p6-tls-check.sh` 10/10 — TLS 1.3 vérifié sur Horizon, Keystone, Nova,
  Neutron, Glance, Placement et Vault ; HTTP clair et TLS 1.1 refusés ; 10/10 endpoints en https.
- **Vault** (Raft, HTTPS, audit) : application credential Keystone de la CI (rôle member, non « unrestricted »,
  30 j) et clé SSH de déploiement. La CI s'authentifie par **JWT GitLab** (rôle lié à `dgsn/demo-app` + `main`
  protégée, jeton 10 min) ; variable `DEPLOY_SSH_KEY` supprimée.
- **Pipeline Vault réussi en 56 s**, **0 secret** dans les journaux ; **refus prouvé** depuis une branche non protégée
  (`claim "ref" does not match`). Audit Vault : 2 connexions acceptées, 1 refusée.
- mTLS : voir section 7.

### P7 — Supervision Prometheus / Grafana — **PASS**
- Stack existante de VM4 conservée ; ajouts isolés et sauvegardés.
- **openstack-exporter 1.7.0** (SHA256 vérifié, écoute locale) avec une **application credential en lecture seule
  par access rules (GET uniquement)** — preuve : GET 200, POST réseau 401, POST serveur 401.
- **node_exporter en mTLS** sur controller et instance (certificat client Prometheus exigé ; sans certificat :
  handshake refusé).
- **Dashboard Grafana provisionné : 16 panneaux, 28 requêtes, 28/28 alimentées** (services OpenStack, agents,
  projets, instances, vCPU/RAM, IP flottantes, images, réseaux, Placement, CPU/mémoire/disque/réseau/charge de
  4 nœuds). Export : `monitoring/dgsn-dashboard.json` ; capture : `docs/preuves/phase7/08-dashboard-grafana.png`.
