# Journal des tests — Thème 11


## 2026-10-18 11:29 — Vérification de l'état initial (avant phase 1)
- `vmrun list` : 3 VM allumées — FreeBSD (pfSense), Ubuntuserbveur4 (VM4), C:\VMs\controller\controller.vmx. VM1 éteinte. ✅
- RAM hôte : 31,4 Go total, 6,4 Go libres avec ces 3 VM.
- ping : 192.168.100.1 OK, 192.168.100.10 OK (= controller non personnalisé), 192.168.100.40 libre.
- TCP 22 sur .10 : ouvert. SSH par clé (`BatchMode=yes`) : **refusé** (clé non autorisée).
- controller.vmx : memsize=12288, numvcpus=8, vhv.enable=FALSE, ethernet0 hostonly (VMnet1), ethernet1 VMnet8, ethernet2 VMnet1 — conforme.
- Snapshots controller : 0 → lancement du snapshot `avant-phase1`.

## 2026-10-18 11:44 — Snapshot controller `avant-phase1`: terminé (exit 0). PASS

## 2026-10-18 11:56 — Amorçage SSH (fait manuellement par l'utilisateur)
- `ssh -o BatchMode=yes` + `sudo -n true` : controller (.10, serveurs1) SUDO_OK ; VM4 (.30, serveur4) SUDO_OK. **PASS**

## 2026-10-18 11:59 — P1 controller : personnalisation
- `scripts/p1-controller.sh` run 1 : growpart FAIL (bug `lsblk -no PKNAME` renvoyait 2 lignes) + `visudo -c` FAIL (fichier sudoers.d/jacques1 créé à l'amorçage en mode ≠ 0440). Corrigé (`lsblk -dno`, `chmod 440 sudoers.d/*`, marqueur d'idempotence machine-id/clés hôte).
- run 2 : `P1_SCRIPT_OK` — sda3 38→118 Go, LV / 116 Go. Preuves : docs/preuves/phase1/01..02.
- Reboot controller : SSH .40 joignable après 67 s ; .10 libéré.
- `scripts/p1-test.sh` : 13/13 critères PASS (hostname, .40 seule IP, ens37 DHCP, ens38 UP sans IP, 1 route défaut, cloud-init off, / 116 Go, hosts sans 127.0.1.1, machine-id 71ea…≠VM1, sudo NOPASSWD, pfSense, Internet, DNS). **PASS** (preuve : phase1/03-controller-test.txt)

## 2026-10-18 12:01 — VM1
- Snapshot `avant-p1-p2` (éteinte), memsize 4096→2048, `vmrun start nogui` : SSH .10 en 52 s. SSH par clé : refusé (VM1 jamais amorcée) → action utilisateur.

## 2026-10-18 12:18 — Test final P1 : SSH par clé (BatchMode) + sudo -n
- jacques1@192.168.100.40 -> controller SUDO_OK
- jacques1@192.168.100.10 -> serveurs1 SUDO_OK
- jacques4@192.168.100.30 -> serveur4 SUDO_OK
- **P1 : PASS — phase 1 terminée**

## 2026-10-18 12:23 — P2 préparation VM1
- `scripts/p2-setup-vm1.sh` : kolla-ansible **18.8.0** (série 2024.1) dans ~/kolla-venv, ansible-core <2.17, inventaire multinœud (181 groupes), passwords.yml généré sur VM1 [SECRET, non copié].
- Écart : branche `stable/2024.1` supprimée d'opendev (fin de maintenance Caracal) → `install-deps` FAIL. Collection kolla prise sur `unmaintained/2024.1` (kolla/requirements.yml) + `requirements-core.yml` (versions bornées). PASS.
- Clé VM1→controller (scripts/authorize-key.sh ; BOM PowerShell retiré). `ansible all -m ping` : controller + localhost SUCCESS. **PASS** (preuves/phase2/02).
- Snapshot controller `p1-ok-avant-kolla` (VM éteinte, instantané).
- bootstrap-servers essai 1 : FAIL en 1 s (module sysctl introuvable = collections core manquantes) → corrigé ; essai 2 lancé 12:23 dans tmux `kolla` sur VM1.

## 2026-10-18 12:25 — P2 Kolla : bootstrap-servers OK (58 s, failed=0, Docker 29.9.1) ; prechecks OK (38 s) ; pull en cours.

## 2026-10-18 12:27 — P2 pull : **FAIL — blocage**
- `kolla-ansible pull` : 404 sur quay.io/openstack.kolla/*:2024.1-ubuntu-jammy (`docker pull` manuel : not found).
- API quay.io (scripts/quay-tags.py) : 0 tag 2024.1, 0 tag 2024.2, 0 tag jammy. Disponibles : 2025.1 et 2025.2 en ubuntu-noble / debian-bookworm / rocky.
- Cause : OpenStack 2024.1 (Caracal) en fin de vie, images officielles retirées.
- Alternatives vérifiées : (A) construire les images 2024.1 avec kolla 18.8.0 (PyPI OK, tarballs unmaintained-2024.1 HTTP 200, UCA caracal HTTP 200) ; (B) passer en 2025.1 Epoxy (images officielles, hôte Ubuntu 24.04 requis).
- En attente de la décision utilisateur (changement de version = paramètre du sujet).

## 2026-10-18 12:55 — DÉCISION : passage à OpenStack 2025.1 Epoxy (écart au sujet)
- Décision utilisateur. Motif technique : images 2024.1 retirées de quay.io. Motif sécurité : 2024.1 (et Yoga/Zed) en fin de vie = plus de correctifs de sécurité, incompatible avec le Security by Design attendu par la DGSN.
- 2025.1 = version maintenue, SLURP (saut direct vers 2026.1 possible). Images officielles `2025.1-ubuntu-noble`.
- Conséquence : controller 22.04 → 24.04. CLAUDE.md mis à jour. **À reprendre dans le rapport (choix technologiques + écarts).**

## 2026-10-18 12:56 — Controller : revert snapshot `p1-ok-avant-kolla` (22.04 propre, sans Docker), lancement `scripts/p2-upgrade-noble.sh` (tmux `upgrade`).

## 2026-10-18 13:00 — P2 (2025.1) préparation
- VM1 : compatibilité vérifiée — kolla-ansible 20.6.0 exige Python ≥3.10 et ansible-core ≥2.17,<2.19 ; VM1 = Python 3.10.12 → ansible-core **2.17.14** (2.18 exige Python 3.11). VM1 reste poste de déploiement. Venv recréé, collections : core bornées (requirements-core.yml 20.6.0) + openstack.kolla `stable/2025.1` (kolla/requirements.yml). passwords.yml régénéré pour 2025.1 [SECRET, sur VM1]. **PASS** (preuves/phase2/01-setup-vm1-2025.1.txt)
- p2-deploy.sh : syntaxe 2025.1 `kolla-ansible <action> -i <inventaire>`.
- Images : 29/29 images requises présentes en `2025.1-ubuntu-noble` sur quay.io. **PASS** (preuves/phase2/03-images-noble.txt)
- Upgrade controller essai 1 : FAIL (do-release-upgrade : redémarrage requis après le dist-upgrade jammy, nouveau noyau). Script corrigé (détection reboot-required) ; reboot ; essai 2 en cours depuis 13:00.

## 2026-10-18 13:14 — Controller Ubuntu 24.04.5 (noyau 6.8.0-147, Python 3.12.3) : upgrade OK en 11 min. Non-régression `p1-test.sh` : 13/13 **PASS** (preuves/phase1/05). Snapshot `noble-avant-kolla`. Ansible ping VM1→controller OK. Lancement p2-deploy.sh (2025.1) dans tmux `kolla`.

## 2026-10-18 13:20 — P2 2025.1 : bootstrap OK (44 s). prechecks essai 1 FAIL : VM1 (localhost, groupe deployment, Ubuntu 22.04) refusée par le contrôle d'OS hôte (noble exigé). Correction ciblée : `prechecks_enable_host_os_checks=false` sur localhost seulement (VM1 ne fait tourner aucun conteneur ; controller reste contrôlé) — écart E2. prechecks essai 3 OK (39 s). pull en cours.

## 2026-10-18 16:03 — P2 OpenStack 2025.1 : déploiement et tests
- pull OK (306 s) ; **deploy OK (333 s, controller ok=407 failed=0)** ; post-deploy OK (3 s). Logs : VM1 ~/dgsn/logs/.
- post-deploy crée admin-openrc.sh en root:600 → p2-init.sh reprend la propriété (jacques1, 600 conservé).
- `p2-init.sh` (init-runonce, externe 192.168.100.0/24, pool .200-.230, gw .1) : P2_INIT_OK (preuves/phase2/05).
- `p2-test.sh` (66 s) : **P2_TEST_PASS** — services keystone/glance/nova/neutron/placement (+ heat activé par défaut) ; agents nova et neutron up ; Horizon http://192.168.100.45 HTTP 200 ; demo-net vxlan, public1 flat ; cirros ACTIVE en 18 s ; IP flottante 192.168.100.201 pingable depuis VM1 ; secgroup : 22 et 8080 ouverts, 8081 bloqué, contre-preuve 8081 ouvert après ajout de règle. (preuves/phase2/06-p2-test.txt)
- **P2 : PASS — phase 2 terminée.**

## 2026-10-18 16:07 — Snapshot `p2-openstack-ok` (controller éteint proprement en 101 s). Redémarrage : Horizon HTTP 200 en 45 s ; nova-api 503 pendant le démarrage puis services nova up + agents neutron alive en ~3 min ; 32 conteneurs Up ; p2-test-cirros ACTIVE. **PASS (reprise après redémarrage)**

## 2026-10-18 16:08 — P3 Keystone RBAC
- `p3-rbac.sh` : projets dgsn-identification / dgsn-pj / dgsn-ops ; dgsn-ops-admin=admin@dgsn-ops, dgsn-pj-member=member@dgsn-pj, dgsn-id-reader=reader@dgsn-identification. Mots de passe aléatoires sur VM1 uniquement (~/dgsn/secrets, 600) [SECRET]. (preuves/phase3/01)
- `p3-test.sh` : 7/7 — reader liste ses instances ; reader création d'instance **refusée 403** « Policy doesn't allow os_compute_api:servers:create » ; reader création réseau refusée 403 ; member crée un réseau dans son projet ; member → dgsn-identification refusé 401 ; member `user list` refusé ; admin liste les projets. **P3 : PASS — phase 3 terminée.** (preuves/phase3/02)

## 2026-10-18 18:40 — Bilan RAM avant P4/P5 (scripts/ram-check.sh, preuves/phase2/07)
- Hôte 31,4 Go : VM allumées 21,0 Go (controller 12, VM4 4, pfSense 3, VM1 2) ; applications Windows ~10 Go (Edge 3,0, Claude 2,3, Chrome 1,5, svchost 1,5, ChatGPT 0,65, Discord 0,36…). **Disponible : 1,9 Go** (< seuil de 3 Go fixé par la mission).
- Controller 11,6 Go : 8,8 Go utilisés par 33 conteneurs Kolla, **3,0 Go disponibles** pour les instances (qemu = RAM réellement consommée). Le processus VMware du controller (10,3 Go) peut encore croître de ~1,7 Go côté hôte.
- Conclusion : 5 instances m1.small (2 Go) impossibles ; GitLab (≥ 4–6 Go) impossible sans libérer de la RAM hôte. Proposition à l'utilisateur (voir réponse).

## 2026-10-18 19:03 — P4 essai 1 : **FAIL (saturation mémoire)**
- Prépa OK : Terraform 1.16.6 ; image debian-12 (SHA512 vérifié) ; flavor dgsn.p4 1 vCPU/512 Mo/5 Go (preuves/phase4/01). `terraform validate` OK.
- `terraform apply` : 4 instances créées en 22–31 s, la 5e échoue : Nova API 408 (haproxy) — controller à 435 Mo disponibles (11,5/11,9 Go), hôte à **2,9 Go** (< seuil 3 Go). Cause : 33 conteneurs Kolla (~8,8 Go, 5 workers par API) + 5 × (512 Mo + surcoût qemu) > 11,6 Go.
- Mesure de protection : `terraform destroy` (13 s, 33 ressources) → controller 4,8 Go disponibles ; hôte 2,8 Go (VMware conserve les 12 Go du controller).
- Arrêt conformément à la règle « < 3 Go → s'arrêter et proposer ». Proposition : réduire les workers Kolla + désactiver Heat (non requis par le sujet).

## 2026-10-18 22:07 — Allègement Kolla (dimensionnement contraint)
- Snapshot controller `avant-allegement`. globals : workers API 1 / RPC 1, enable_heat no, enable_fluentd no, memcached 128 Mo ; kolla/config/galera.cnf innodb_buffer_pool_size 256M (défaut 40 % RAM ≈ 4,7 Go).
- prechecks OK (20 s), **reconfigure OK (376 s, failed=0)** ; `p2-cleanup-disabled.sh` : conteneurs heat×3 + fluentd supprimés, services/utilisateurs/domaine Heat supprimés de Keystone. Vérifié : buffer pool 256M, memcached -m 128, workers = 1.
- **Mesure (mem-measure.sh, 3 min après stabilisation, 0 instance)** : conteneurs 33 → 29 ; mémoire conteneurs 7 248 → 4 114 Mo (**−3 134 Mo, −43 %**) ; RAM disponible controller 3 748 → 7 505 Mo (**+3 757 Mo**). (preuves/phase4/10, 12)
- Latence API avec 1 worker (api-latency.sh, 10 appels) : keystone 9 ms, nova 19 ms, neutron 19 ms, glance 5 ms, placement 5 ms → pas de dégradation, workers = 1 conservé. (preuves/phase4/15)
- Non-régression : **P3 7/7 PASS** ; **P2 PASS** après 3 corrections du *test* (pas de la plateforme) : instance recréée à chaque exécution (user-data au 1er boot), attente de sortie de l'état DELETED, sonde unique du port 8080 (busybox nc ne sert qu'une connexion). (preuves/phase4/13, 14)

## 2026-10-18 22:27 — KSM et pfSense
- KSM activé sur controller (ansible/ksm.yml, persistant tmpfiles.d) : run=1, pages_to_scan=1000, sleep 50 ms. Gain à mesurer pendant P4. (preuves/phase4/16)
- pfSense : arrêt propre par l'utilisateur (console, option 6 ; une première tentative avait suspendu la VM → reprise). `scripts/pfsense-ram.ps1` : snapshot `avant-ram-1536`, memsize 3104 → **1536 Mo**, redémarrage : .1 répond en 27 s ; controller → pfSense OK, Internet 44 ms, DNS OK. **PASS**. Hôte : 3,8 → **5,7 Go disponibles**. (preuves/phase4/17)

## 2026-10-18 22:32 — P4 essai 2 : **interrompu (seuil hôte)**
- Avant : controller 7 151 Mo disponibles (0 instance), hôte 5,7 Go.
- `terraform apply` : **24 s** (33 ressources) ; Ansible en cours (socle commun quasi terminé à 113 s) quand l'hôte passe à **2,8–2,9 Go** → arrêt (règle utilisateur), `terraform destroy` 14 s.
- Pendant le run : controller 11,2 Go utilisés / 620 Mo disponibles / swap 271 Mo ; **KSM : 183 452 pages partagées = 716 Mo économisés** sur 5 instances Debian identiques.
- Cause côté hôte : le processus VMware du controller passe de ~10 à **14,0 Go** (12 Go invité + ~2 Go de surcoût VMware pour 8 vCPU) dès que l'invité touche toute sa RAM, et ne la rend pas après destroy (hôte reste à 3,0 Go). La croissance est désormais plafonnée.
- Script destroy corrigé (attente de la sortie de l'état DELETED). (preuves/phase4/20–23)

## 2026-10-18 22:44 — P4 essai 3 (seuil hôte temporaire 2 Go)
- `p4-full.sh` (tmux p4) + `watch-ram.ps1 -SeuilGo 2`.
- **apply-1 : terraform apply 25 s + ansible-playbook 128 s (rc=0) = 153 s (2 min 33 s) < 600 s. PASS** ; 5 instances ACTIVE ; HTTP web-1/web-2 OK ; SSH direct vers web-1 refusé (bastion obligatoire). (preuves/phase4/31)
- Pendant les tests d'isolement : hôte **1,4 Go** (< 2 Go) → chien de garde : arrêt du cycle + terraform destroy → 0 instance. Aucune action sur les VM VMware (vérifié : 3 VM toujours allumées). (preuves/phase4/30)
- Pic controller : vmx 14,6 Go côté hôte ; invité 691 Mo disponibles au plus bas ; **KSM 884 Mo économisés** sur 5 instances.
- Cause du passage sous le seuil : applications hôte (Chrome rouvert 1,9 Go, LegionSpace 1,4 Go, Edge 2,6 Go).
- watch-ram.ps1 durci à la demande de l'utilisateur : repli figé = arrêt du cycle P4 + terraform destroy uniquement ; pkill restreint à `ansible-playbook site.yml` ; aucune commande vmrun (garde-fou documenté).

## 2026-10-18 22:51 — Controller 12 → 10 Go
- Avant : hôte 1,1 Go disponible, processus VMware controller 14,2 Go.
- Arrêt propre (69 s), snapshot `avant-10go`, memsize 12288 → **10240**, redémarrage : services nova up en 82 s ; KSM actif (persistant).
- Non-régression : **P2_TEST_PASS** (cirros ACTIVE en 17 s), **P3_TEST_PASS**. (preuves/phase4/41)
- Après : **hôte 9,4 Go disponibles** ; processus VMware controller 7,8 Go. (preuves/phase4/40)

## 2026-10-18 22:58 — **P4 Terraform : PASS — phase 4 terminée**
- Cycle complet `p4-full.sh` (controller 10 Go, chien de garde 2 Go, minimum hôte observé **4,6 Go**).
- apply-1 : terraform 23 s + Ansible 118 s = **141 s** ; apply-2 (re-apply après destroy) : 34 s + 123 s = **157 s** — objectif < 600 s atteint avec une marge ×3,8.
- Tests à chaque apply (10/10) : 5 instances ACTIVE ; HTTP web-1/web-2 ; SSH direct vers web refusé (bastion obligatoire) ; web→app:8080 autorisé ; bastion→app:8080 bloqué ; web→db:5432 bloqué.
- destroy-1 13 s, destroy-2 12 s, 0 instance restante. KSM : 892 Mo partagés au pic.
- Écart E3 documenté : flavor dgsn.p4 512 Mo / 1 vCPU (contrainte RAM, qemu sans accélération). (preuves/phase4/43-*)

## 2026-10-18 23:05 — P5 VM gitlab
- `p5-create-gitlab-vm.ps1` : arrêt propre VM1, snapshot VM1 `base-clone-gitlab`, clone complet → C:\VMs\gitlab (4 Go, 4 vCPU, ISO retirée), personnalisation `perso-vm.sh` (gitlab, .50, LV 38 Go, swap 4 Go, machine-id/clés hôte neufs), VM1 redémarrée. SSH par clé + sudo OK sur gitlab/VM1/controller (hérités de VM1, pas d'amorçage manuel). **PASS** (preuves/phase5/01)
- Avant : controller arrêté/redémarré pour rendre sa mémoire à l'hôte (14,9 Go → hôte 9,1 Go). Après gitlab : hôte 7,4 Go disponibles.
- Snapshot gitlab `perso-avant-gitlab` ; installation GitLab lancée (tmux gitlab).
- **Constat sécurité (hygiène de clonage)** : le clone gitlab avait hérité des secrets de VM1 (/etc/kolla/passwords.yml, ~/dgsn/secrets, clé SSH privée de VM1 → accès sudo au controller). `clone-hygiene.sh` : suppression ; vérifié : gitlab → controller « Permission denied ». **PASS**. Recommandation rapport : construire les VM depuis une image de référence (golden image) et jamais par clonage d'un poste d'administration. (preuves/phase5/02)

## 2026-10-18 23:13 — P5 GitLab installé
- `p5-install-gitlab.sh` (dépôts signés ; correctif : dépôt Runner sous le namespace runner/) : **GitLab CE 19.5.0 en 289 s**, Runner 19.5.0, Docker 29.1.3 ; /users/sign_in HTTP 200. Mode économe (puma single, sidekiq 5, supervision interne off) : 2 363 Mo utilisés + 450 Mo de swap sur 3 875 Mo. Hôte : 3,9 Go disponibles.

## 2026-10-18 23:16 — P5 CI : configuration + **incident de fuite de secret corrigé**
- `p5-ci-setup.sh` : PAT d'automatisation root (30 j, api) stocké dans /root/.dgsn (600) sur gitlab ; correctif : gitlab-rails tourne sous l'utilisateur git → jeton via stdout ; jetons orphelins révoqués à la création.
- **Incident** : `gitlab-runner list` a affiché le jeton d'authentification du runner (sortie de session et preuve). Actions : masquage dans la preuve ([SECRET]) ; **rotation** (`p5-runner-rotate.sh` : runner supprimé côté GitLab ⇒ jeton invalidé, désenregistrement local, nouvel enregistrement silencieux) ; script corrigé (masquage systématique des jetons). Vérifié : 0 occurrence `glrt-` dans le dépôt. Leçon pour le rapport : masquage des secrets dans les journaux de CI/outillage (Vault en P6).
- Runner dgsn-docker : exécuteur docker, socket hôte, concurrence 1. Projet dgsn/demo-app (id 1, privé). Clé de déploiement CI générée (/root/.dgsn, 600). (preuves/phase5/03, 04)

## 2026-10-19 01:07 — **P5 GitLab DevSecOps : PASS — phase 5 terminée**
- Runner : 1er essai bloqué (entrée locale du runner révoqué restée dans config.toml → job « stuck_pending_no_matching_runners ») ; correctif `gitlab-runner verify --delete` intégré à la rotation ; runner 2 valide/en ligne. (preuves/phase5/07)
- Instance cible dgsn-app-1 (Terraform p5, flavor dgsn.app 1 vCPU/1 Go) : apply 23 s, Docker prêt en 298 s via cloud-init (accès Internet sortant des instances via pfSense vérifié). IP 192.168.100.220. (preuves/phase5/05)
- Outils CI épinglés : semgrep 1.181.0, trivy 0.76.0, docker 29.9.1-cli.
- **Pipeline 2 (v1 vulnérable) : FAILED en 88 s — bloqué par Semgrep** : 6 findings (subprocess-injection ×3 ERROR, avoid-pyyaml-load ERROR, debug-enabled, bad_host) ; build/scan/push/deploy **non exécutés**. (preuves/phase5/10, 11)
- **Pipeline 3 (v2 corrigée) : SUCCESS en 133 s (< 480 s)** — semgrep 17 s (0 finding), trivy fs 27 s (0 HIGH/CRITICAL), build 30 s, trivy image 3 s (0 HIGH/CRITICAL, Alpine 3.24), push registre 3 s, déploiement OpenStack 54 s. (preuves/phase5/20, 22-*)
- Application : /health → v2 ; `/diag?host=127.0.0.1;id` → **HTTP 400** (injection neutralisée) ; conteneur healthy, rootfs en lecture seule, cap_drop=ALL, no-new-privileges, utilisateur app (uid 100). (preuves/phase5/21)
- Mesure : durée pipeline réussi = 133 s ; pipeline bloqué = 88 s (pull initial de l'image Semgrep inclus).

## 2026-10-19 01:36 — **P6 Vault + TLS : PASS — phase 6 terminée**
- PKI interne (`p6-pki.sh`, VM1) : CA « DGSN Lab Root CA » ECDSA P-384 ; certificats openstack (.45/.40) et vault (.50) ECDSA P-256, vérifiés. Seul le certificat public de la CA est versionné. (preuves/phase6/01)
- TLS Kolla (snapshot controller `p5-ok-avant-tls`) : essais 1–3 FAIL → causes : NTP non synchronisé juste après démarrage ; ProxySQL exige proxysql-cert.pem/proxysql-key.pem ; CA attendue sous le nom `root.crt` (ProxySQL arrêté entre-temps). **Essai 4 : reconfigure OK (472 s, failed=0)** ; post-deploy → admin-openrc en https + OS_CACERT.
- `p6-tls-check.sh` : **10/10 PASS** — TLS 1.3 vérifié par la CA DGSN sur :443/:5000/:8774/:9696/:9292/:8780 et Vault :8200 ; HTTP clair et TLS 1.1 refusés ; 10/10 endpoints du catalogue en https. (preuves/phase6/04)
- Non-régression en HTTPS : **P2_TEST_PASS** (Horizon HTTPS 200), **P3_TEST_PASS**. (preuves/phase6/05)
- Vault 2.2.0 sur gitlab : HTTPS, Raft, audit fichier, KV v2, auth JWT GitLab, politique lecture seule `kv/data/ci/demo-app/*`, rôle lié à dgsn/demo-app + main protégée, jeton 10 min. Init lab 1/1 (écart documenté). (preuves/phase6/02, 03)
- Application credential Keystone `ci-demo-app` (dgsn-ops, rôle member, non unrestricted, expire +30 j) → Vault ; fichiers temporaires détruits (shred) sur VM1, gitlab et Windows. Clé de déploiement → Vault. Variable CI `DEPLOY_SSH_KEY` **supprimée** (reste APP_HOST, non secret). (preuves/phase6/06, 07)
- **Pipeline 5 (main) : SUCCESS en 56 s** — 7 jobs dont openstack-preflight (Vault → application credential → jeton Keystone HTTPS → Nova : dgsn-app-1 ACTIVE) et déploiement avec clé SSH lue dans Vault. Audit des journaux : **0 secret** (ni secret d'application credential, ni jeton hvs., ni clé privée). Pipeline 4 : FAIL de syntaxe YAML (« : » dans une ligne) corrigé via l'API ci/lint. (preuves/phase6/10, 11)
- **Test négatif : pipeline 6 sur feature/test-vault → Vault refuse** (« claim "ref" does not match any associated bound claim values », HTTP 400) ; aucun déploiement. Audit Vault : 2 connexions acceptées, 1 refusée, valeurs sensibles hachées. (preuves/phase6/12, 13)
- mTLS : réalisé partiellement (Vault vérifie un certificat client DGSN s'il est présenté) ; reste en perspective (backend Kolla, RabbitMQ/MariaDB, mTLS exigé). Voir docs/rapport-notes/securite-p6.md.
- **Hôte en fin de phase : 0,7 Go disponible** (< 3 Go) : controller 10,0 Go, gitlab 5,8 Go, VM1 1,1, pfSense 0,5 ; applications Windows : Edge 2,8, Chrome 2,7 (rouvert), LegionSpace 0,8 (rouvert), compression mémoire 2,1. Arrêt avant P7, proposition à l'utilisateur.

## 2026-10-19 20:43 — Nouvelle consigne utilisateur : terminer P7–P10 en autonomie, seuil hôte 1,5 Go, réductions de RAM et suspensions de VM autorisées. gitlab suspendue (Vault descellé avant suspension), VM4 reprise. Processus LegionSpace arrêtés (autorisé). Hôte : 5,9 Go disponibles.

## 2026-10-19 20:55 — **P7 Supervision : PASS — phase 7 terminée**
- Existant VM4 conservé (Prometheus 2.31, Grafana 10.4.3, jobs VM1/VM3/VM4/VM5) ; ajouts isolés entre marqueurs DGSN-THEME11 ; sauvegarde prometheus.yml.avant-dgsn.
- **node_exporter en mTLS** (controller, dgsn-app-1) : certificats serveur + client Prometheus (EKU clientAuth) émis par la CA DGSN ; `RequireAndVerifyClientCert` ; sans certificat client → handshake refusé (000), HTTP clair → 400. Sur controller, l'exporter en clair hérité du clonage de VM1 (node-exporter.service) a été désactivé. Port 9100 ouvert sur dgsn-app-sg pour VM4 uniquement (Terraform). (preuves/phase7/01, 02)
- **openstack-exporter v1.7.0** (stable, SHA256 vérifié) sur VM4, écoute 127.0.0.1:9180, service systemd confiné ; 115 métriques ; nova/neutron/glance/keystone/placement up=1. (preuves/phase7/04)
- Credential de supervision : application credential admin **avec 5 access rules GET-only**, non unrestricted, 90 j. Preuve : GET réseaux 200, POST réseau 401, POST serveur 401. (preuves/phase7/03, 05)
- Prometheus : cibles dgsn-openstack, dgsn-node-mtls (controller, dgsn-app-1) **up**. (preuves/phase7/06)
- **Grafana : dashboard « DGSN Thème 11 » provisionné (16 panneaux, 28 requêtes, 28/28 avec données)** ; export JSON monitoring/dgsn-dashboard.json ; capture docs/preuves/phase7/08-dashboard-grafana.png (accès anonyme Viewer activé le temps de la capture headless puis désactivé : HTTP 401). (preuves/phase7/07, 08)
- Note hygiène : la VM gitlab (clone de VM1) porte aussi le node-exporter.service en clair hérité → à désactiver à son réveil.

## 2026-10-19 20:59 — P8 lancement : SSG v0.1.82 (SHA512 OK), profil cis_level1_server Debian 12 (oscap 1.3 requis : oscap 1.2.17 d'Ubuntu 22.04 trop ancien). 2 instances Debian 12 (dgsn.app 1 Go) ; remédiation par le playbook SSG officiel ; exclusion documentée des tâches nftables (pare-feu CIS via ufw, SSH pré-autorisé depuis VM1/VM4).

## 2026-10-19 23:03 — P8 : scan avant OK (251 s) — **score CIS 67,90 / taux 67,4 %** (223 pass, 108 fail) sur scap-1 et scap-2. Remédiation essai 1 FAIL (playbook SSG sans become → `--become`), essai 2 FAIL après 2132 s (DNS externe transitoire lors d'un apt ; vérifié rétabli) → essai 3.

## 2026-10-19 23:04 — Hôte 1,3 Go (< 1,5 Go) pendant la remédiation P8 → VM4 suspendue (autorisé ; P7 validée).

## 2026-10-19 23:09 — P8 remédiation essai 3 FAIL (227 s) : bug SSG (tâche wireless installe « NetworkManager », inexistant sous Debian) ; constat : le profil CIS Debian 12 retient nftables (chaînes en politique accept) et désinstalle ufw → hypothèse initiale ufw corrigée : nftables réintégré, préparation ufw supprimée, seule exclusion = wireless_disable_interfaces. Essai 4 lancé.

## 2026-10-19 23:16 — P8 remédiation essai 4 FAIL (385 s) : tâche SSG « disable named » sur service absent. Approche alternative (règle des 5 essais) : copie du playbook SSG officiel avec ignore_errors par tâche (808 tâches, scripts/p8-ssg-tolerant.py) — remédiation toujours par Ansible, échecs comptés. Essai 5 lancé.

## 2026-10-19 23:53 — **P8 OpenSCAP CIS + Fail2Ban : PASS — phase 8 terminée**
- 2 instances Debian 12 (scap-1, scap-2), SSG 0.1.82, profil cis_level1_server.
- **Avant : score 67,90 — 223 pass / 108 fail (67,4 %)** ; remédiation Ansible (playbook SSG officiel, version tolérante, 1709 s, 10 échecs tolérés/instance : groupes gdm/gdm3/sssd/syslog absents) ; **après : score 90,04 — 315 pass / 31 fail (91,0 %)** sur les deux instances (objectif > 85 % atteint). (preuves/phase8/01, rapports HTML scap-{1,2}-{avant,apres}-report.html)
- Non-conformités restantes : 2 high, 22 medium, 6 low, 1 unknown. Complément Ansible `complement.yml` : **no_empty_passwords_unix corrigée (pass)** ; seule high restante **grub2_password : justifiée** (mot de passe GRUB = secret à injecter dans des images cloud démarrant sans interaction ; console contrôlée par Nova/Horizon). Medium restantes principalement : faillock/pwhistory PAM (comptes locaux non utilisés, auth par clé), journal distant (pas de serveur de collecte dans le lab), chrony, partition /tmp (non remédiable sur image cloud). (preuves/phase8/02, 03)
- **Fail2Ban** (jail sshd, backend systemd, maxretry 3, VM1 en liste blanche) : 5 tentatives depuis le controller (attaquant simulé, règle secgroup temporaire) → **IP 192.168.100.40 bannie**, TCP 22 bloqué ; débannissement OK ; administration depuis VM1 intacte. (preuves/phase8/02)
- Correctifs en cours de phase : oscap 1.2 d'Ubuntu 22.04 trop ancien → Debian 12 (oscap 1.3) ; attente SSH ; /opt/ssg ; playbook SSG exécuté avec --become ; DNS transitoire ; bug SSG wireless (NetworkManager) exclu ; hypothèse ufw corrigée (profil = nftables, politique accept) ; approche tolérante après 4 échecs d'environnement.
- Instances P8 détruites (14 ressources).

## 2026-10-20 03:23 — P9 : rafale **8/8 ACTIVE en 28 s (17,1 instances/min)**, appel API 1,0 s, suppression 6 s : PASS. k3s essai 1 FAIL : instances bloquées dans cloud-init (service de métadonnées : BrokenPipe côté neutron-metadata-agent — nova_metadata à 1 worker saturé par les démarrages simultanés). Correctif : config_drive=true + attente SSH ; nœuds recréés.

## 2026-10-20 03:36 — P9 : k3s 3 nœuds Ready (v1.37.1+k3s1, 607 s), application 3 répliques (1/nœud) en 54 s. Failover essai 1 **invalide** (instance victime recherchée hors de son projet → virsh destroy non exécuté) : chaîne arrêtée avant restore/destroy, script corrigé (--all-projects, contrôle de l'arrêt). Relance depuis « charge ».

## 2026-10-20 03:42 — **P9 Charge / résilience / restauration : PASS — phase 9 terminée**
- **Charge plan de contrôle** : rafale de 8 instances (1 appel API, 1,0 s) → **8/8 ACTIVE en 28 s (17,1 instances/min)**, 0 ERROR, suppression 6 s. (preuves/phase9/burst.txt)
- **Cluster k3s v1.37.1+k3s1 3 nœuds** (MicroK8s écarté : empreinte mémoire — écart E8) sur instances Debian 12 (config drive), binaire vérifié SHA256, détection de panne accélérée (grâce 10 s, statut kubelet 2 s) ; application whoami v1.12.0 3 répliques (1/nœud, non root, rootfs lecture seule). (k3s.txt, app.txt)
- **Charge applicative** (ab, 3000 requêtes, 20 concurrents) : **127,8 req/s**, médiane 75 ms, p95 552 ms, p99 880 ms ; 0 erreur réelle (les « Failed » = 1111 *Length* : taille de réponse variable de whoami). (charge.txt)
- **Failover** : arrêt brutal (virsh destroy) de k3s-3, sonde horodatée 0,5 s : 38/38 OK avant ; après : **1 échec / 174**, **TEMPS DE REPRISE 1,7 s** (< 30 s) ; k3s-3 NotReady ; service assuré par 2 répliques ; réplique de remplacement Pending (contrainte de répartition stricte DoNotSchedule → recommandation : nœud de réserve ou ScheduleAnyway). Essai 1 invalide (victime non trouvée) écarté. (failover.txt, failover-sonde.csv)
- **Restauration** : snapshot Glance 16 s (1047 Mo) → suppression → restauration → témoin identique ; **RTO 61 s**. (restore.txt)
- Incident traité : service de métadonnées saturé (nova_metadata 1 worker) lors de démarrages simultanés → config drive pour les instances P9.
- Ressources P9 détruites (20) ; dgsn-app-1 redémarrée.

## 2026-10-20 04:21 — **VÉRIFICATION FINALE (par groupes de VM) : PASS**
Contrainte documentée : la RAM de l'hôte (31,4 Go) ne permet pas d'allumer toutes les VM ensemble ; vérification par groupes, chaque groupe après arrêt/démarrage des VM concernées. (preuves/verif-finale/)
- **Groupe A — socle (pfSense, controller, VM1)**, après arrêt propre (100 s) et redémarrage (OpenStack prêt en 77 s) :
  P1 13/13 PASS (critère d'IP adapté à la VIP keepalived .45 posée par Kolla) ; P2 PASS (68 s) ; P3 PASS ; P6 TLS OpenStack 9/9 PASS (Vault contrôlé en groupe B) ;
  P4 PASS (apply + Ansible **136 s**, destroy OK) ; P8 PASS (chaîne OpenSCAP : score de référence **reproduit à l'identique, 67,90**, sur instances neuves) ; P9 PASS (rafale 8/8 ACTIVE en 33 s).
- **Groupe B — DevSecOps (+ gitlab)** : redémarrage effectif de gitlab (02:12:21 ; un premier contrôle a porté sur l'ancien démarrage car l'arrêt de GitLab a pris plusieurs minutes) → **Vault scellé** → descellé par script → GitLab HTTP 200, runner valide → **pipeline 8 SUCCESS en 52 s** (7 jobs dont preflight Vault et déploiement) ; **0 secret** dans les journaux ; Vault TLS 1.3 vérifié → **P6 TLS 10/10** ; application v2 en ligne.
  Incident d'outillage corrigé : faux positif « FUITE_DETECTEE » de p6-log-audit.sh quand Vault était scellé (motif vide) → garde-fou ajouté.
  Hygiène : exporter en clair hérité désactivé sur gitlab.
- **Groupe C — supervision (+ VM4, gitlab suspendue)** : VM4 redémarrée ; prometheus, grafana-server, openstack-exporter actifs ; cibles dgsn-node-mtls (controller, dgsn-app-1) et dgsn-openstack **up** ; dashboard **28/28** requêtes avec données.
- **Conclusion : toutes les phases P1–P9 revalidées depuis un état redémarré.**

## 2026-10-20 04:21 — **P10 Livrables : PASS — projet terminé**
- docs/rapport.md (11 sections + annexes) et docs/rapport.docx (18 pages, sommaire Word, 4 figures Mermaid rendues) ; tableau-metriques.md (5/5 métriques atteintes) ; demo.md ; guide-reprise.md ; etat.md final.
- État laissé : pfSense, controller, VM1, VM4 allumées ; gitlab suspendue ; dgsn-app-1 ACTIVE.
