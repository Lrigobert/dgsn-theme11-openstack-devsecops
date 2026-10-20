### P8 — Conformité CIS (OpenSCAP) et Fail2Ban — **PASS**
- 2 instances Debian 12 ; **SCAP Security Guide 0.1.82** (SHA512 vérifié), profil **CIS niveau 1 serveur**, scanner
  OpenSCAP 1.3 (celui d'Ubuntu 22.04, en 1.2, est trop ancien pour les datastreams récents).
- **Avant** : score XCCDF **67,90** — 223 règles conformes / 108 non conformes (**67,4 %**).
- **Remédiation Ansible** par le playbook officiel SSG (808 tâches, 1 709 s sous émulation). Le playbook officiel
  échouait sur des tâches inadaptées à l'environnement (exécution non root attendue, DNS externe transitoire, paquet
  `NetworkManager` inexistant sous Debian, service `named` absent) : approche retenue après 4 essais = **même
  playbook avec tolérance d'erreur par tâche**, chaque échec étant compté (10 par instance, tous des groupes système
  absents : gdm, sssd, syslog). Seule exclusion : la tâche *wireless* (bug du contenu SSG).
- **Après** : score **90,04** — 315 conformes / 31 non conformes (**91,0 %**, objectif > 85 % atteint) sur les 2 instances.
- Non-conformités restantes : 2 *high* → `no_empty_passwords_unix` **corrigée** par un complément Ansible (vérifiée
  *pass*) ; `grub2_password` **justifiée** (mot de passe GRUB = secret à injecter dans des images cloud démarrées sans
  interaction ; console contrôlée par Nova/Horizon). Les *medium* restantes concernent surtout PAM pour des comptes
  locaux non utilisés (authentification par clé), la journalisation distante (pas de collecteur dans le lab), la
  partition `/tmp` (non remédiable sur image cloud).
- **Fail2Ban** (jail sshd, backend systemd) : 5 tentatives depuis un attaquant simulé → **IP bannie**, port 22
  bloqué ; débannissement ; administration (liste blanche) intacte.
- Rapports HTML avant/après : `docs/preuves/phase8/scap-{1,2}-{avant,apres}-report.html`.

### P9 — Charge, résilience et restauration — **PASS**
- **Charge du plan de contrôle** : 8 instances créées en un seul appel (1,0 s) → **8/8 ACTIVE en 28 s**
  (17,1 instances/min), 0 erreur, suppression en 6 s.
- **Cluster k3s 3 nœuds** (1 serveur, 2 agents ; écart E8 : k3s au lieu de MicroK8s) : binaire vérifié SHA256,
  composants inutiles désactivés, **détection de panne accélérée** (grâce 10 s au lieu de 40 s, statut kubelet 2 s,
  tolérances de 5 s au lieu de 300 s). Application `whoami` 3 répliques (une par nœud), non root, rootfs en lecture
  seule, NodePort.
- **Charge applicative** (ab, 3 000 requêtes, 20 concurrents) : **127,8 req/s**, médiane 75 ms, p95 552 ms,
  0 erreur réelle.
- **Failover** : arrêt **brutal** d'un agent (`virsh destroy`, équivalent d'une coupure électrique), sonde HTTP
  horodatée toutes les 0,5 s : **1 seul échec sur 174 sondes, temps de reprise 1,7 s** (objectif < 30 s). Le nœud
  passe NotReady, le service continue sur 2 répliques ; la réplique de remplacement reste en attente à cause de la
  contrainte de répartition stricte (une par nœud) → en production : nœud de réserve ou `ScheduleAnyway`.
- **Restauration** : instance porteuse d'un fichier témoin → snapshot Glance (16 s, 1 Go) → suppression →
  restauration → témoin intact ; **RTO 61 s**.
- Incident traité : saturation du service de métadonnées (1 worker) lors de démarrages simultanés → **config drive**
  pour les instances du test (métadonnées sur disque local).
