## 7. Sécurité : synthèse et incidents traités

### 7.1 Mesures en place (défense en profondeur)
| Couche | Mesure | Preuve |
|---|---|---|
| Identité | Projets cloisonnés, rôles reader/member/admin, application credentials limitées (rôle member, non « unrestricted », expiration ; supervision : access rules GET-only) | P3, P6, P7 |
| Réseau | Groupes de sécurité au moindre privilège (bastion obligatoire, flux nommés web→app→db), nftables (CIS) sur les instances, réseaux tenants VXLAN isolés | P2, P4, P8 |
| Chiffrement | TLS 1.3 sur toutes les API OpenStack et Vault (CA interne), **mTLS** Prometheus → node_exporter | P6, P7 |
| Secrets | Vault (Raft, audit, TLS), CI par JWT lié à une branche protégée, 0 secret en variable CI ni dans les journaux | P6 |
| Chaîne logicielle | SAST (Semgrep), SCA (Trivy fs), scan d'image (Trivy), outils épinglés, dépôts APT signés, archives vérifiées (SHA256/SHA512) | P5, P7, P8 |
| Exécution | Conteneur non root, rootfs en lecture seule, `cap_drop=ALL`, `no-new-privileges` ; services systemd confinés | P4, P5 |
| Systèmes | Durcissement SSH (clés uniquement, root interdit), CIS niveau 1 (OpenSCAP), Fail2Ban | P1, P4, P8 |
| Traçabilité | Journal d'audit Vault (valeurs hachées HMAC), journaux de pipelines, `docs/journal.md` horodaté | P6 |

### 7.2 Part de mTLS réalisée
| Flux | État |
|---|---|
| Prometheus → node_exporter (controller, instances) | **mTLS exigé** (`RequireAndVerifyClientCert`, certificat client DGSN) |
| Administration → Vault | certificat client DGSN vérifié s'il est présenté (non exigé) |
| Clients/CI → API OpenStack, CI → Vault | TLS serveur + authentification forte (jeton Keystone, JWT signé) |
| haproxy → services OpenStack, RabbitMQ, MariaDB | non chiffrés (réseau de gestion isolé) — **perspective** |

### 7.3 Incidents de sécurité détectés et corrigés pendant le projet
1. **Fuite d'un jeton de runner** dans une sortie de commande (`gitlab-runner list`) : jeton masqué dans les
   preuves, **runner révoqué et recréé** (jeton exposé invalidé), scripts corrigés pour masquer systématiquement.
2. **Secrets hérités par clonage** : la VM gitlab, clonée du poste d'administration, contenait les mots de passe
   Kolla, les identifiants OpenStack et la clé SSH d'administration (accès sudo au controller). Supprimés et
   vérifiés ; un exporter en clair hérité a aussi été désactivé sur le controller.
3. **Mot de passe des VM communiqué en clair** dans la conversation de travail : non utilisé par l'automatisation
   (amorçage manuel par l'utilisateur) ; **changement recommandé**.

## 8. Limites et écarts au sujet

| # | Écart | Cause | Impact | Alternative DGSN |
|---|---|---|---|---|
| E1 | OpenStack **2025.1** au lieu de 2024.1 | 2024.1 en fin de vie, images retirées | positif (version maintenue) | rester sur les versions SLURP maintenues |
| E2 | VM1 (pilotage) en Ubuntu 22.04 | 2025.1 n'exige noble que sur les nœuds OpenStack | aucun | poste de déploiement 24.04 dédié et durci |
| E3 | Instances **réduites** (512 Mo–1 Go, 1 vCPU) | nœud unique 10 Go, qemu sans accélération | performances non représentatives | computes physiques KVM |
| E4 | **All-in-one** (contrôle + calcul sur un nœud) | RAM du lab | pas de HA du plan de contrôle | 3 contrôleurs HA + computes |
| E5 | Nova en **qemu** (émulation) | VBS actif sur l'hôte | lenteur (démarrages, scans) | KVM matériel |
| E6 | Allègement Kolla (1 worker, Heat/fluentd désactivés) | RAM | débit API limité (latence 5–19 ms mesurée) | workers par défaut sur contrôleurs dédiés |
| E7 | Vault nœud unique, descellement 1/1 local | lab | pas de HA, clé sur le serveur | cluster Raft 3/5 nœuds, Shamir 3/5 ou auto-unseal HSM |
| E8 | **k3s** au lieu de MicroK8s | empreinte mémoire | aucun sur l'objectif (API Kubernetes identiques) | k3s/RKE2 ou Kubernetes managé interne |
| E9 | Registre GitLab et GitLab en HTTP | TLS concentré sur OpenStack/Vault | flux CI en clair sur le réseau de gestion | TLS GitLab + registre (CA DGSN) |
| E10 | Lab exécuté par groupes de VM | RAM de l'hôte (31,4 Go) | vérification finale séquentielle | infrastructure dimensionnée |

Les mesures de temps (P4, P5, P9) sont obtenues **malgré** l'émulation qemu : sur du matériel avec KVM, elles
seraient nettement meilleures.

## 9. Recommandations pour la DGSN en production

1. **Haute disponibilité** : 3 nœuds de contrôle (Galera/RabbitMQ en quorum, haproxy/keepalived), computes séparés,
   réseau de gestion, de stockage et de tenants physiquement séparés.
2. **Stockage** : **Ceph** (RBD pour Cinder/Glance/Nova éphémère), réplication ×3, chiffrement au repos.
3. **PRA multi-site** : second site actif/passif, réplication Ceph (rbd-mirror), sauvegardes externalisées
   chiffrées, tests de restauration planifiés (RTO/RPO mesurés comme en P9).
4. **mTLS généralisé** : `kolla_enable_tls_backend`, TLS RabbitMQ/MariaDB, certificats courts émis par Vault PKI,
   rotation automatique ; maillage de services pour les applications.
5. **Secrets** : Vault en cluster, auto-unseal HSM, révocation du jeton root, rotation automatique des application
   credentials, politiques par projet métier.
6. **Identité** : fédération Keystone avec l'annuaire DGSN (LDAP/SAML/OIDC), MFA pour Horizon, rôles revus
   périodiquement, comptes de service par application credentials uniquement.
7. **Conformité continue** : scans OpenSCAP planifiés (CIS niveau 2 / ANSSI BP-28 « renforcé »), remédiation par
   Ansible en CI, images de référence durcies (golden images) au lieu du clonage.
8. **Chaîne logicielle** : SBOM et signature des images (cosign), politique d'admission (images signées seulement),
   miroirs internes des dépôts et registres (pas de dépendance directe à Internet).
9. **Supervision et SOC** : alerting (Alertmanager), centralisation des journaux (OpenSearch), corrélation SIEM,
   métriques de sécurité (échecs d'authentification, refus Vault, bannissements Fail2Ban).
10. **Exploitation** : mises à niveau SLURP annuelles testées en préproduction, capacity planning (le lab a montré
    que les réglages par défaut supposent des serveurs ≥ 64 Go).
