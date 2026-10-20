# Phase 6 — Gestion des secrets et chiffrement des flux (notes pour le rapport)

## PKI interne
- CA racine « DGSN Lab Root CA » (ECDSA P-384, 10 ans) créée sur le poste d'administration (VM1) ; clé privée
  en 600, jamais copiée ailleurs. Certificats serveurs ECDSA P-256, 397 jours, EKU serverAuth, SAN IP + DNS :
  `openstack.dgsn.lab` (VIP .45, .40) et `vault.dgsn.lab` (.50).
- Production DGSN : racine hors ligne + CA intermédiaire (ou moteur PKI de Vault), clés en HSM,
  renouvellement automatisé (ACME interne ou Vault PKI), révocation (CRL/OCSP).

## TLS OpenStack (Kolla)
- `kolla_enable_tls_external` et `kolla_enable_tls_internal` (VIP unique → les deux sont imposés), CA copiée
  dans tous les conteneurs. Endpoints du catalogue : 10/10 en `https://`.
- Vérifié (scripts/p6-tls-check.sh) : TLS 1.3 sur Horizon, Keystone, Nova, Neutron, Glance, Placement ;
  HTTP en clair refusé ; TLS 1.1 refusé.
- Difficultés rencontrées (utiles au rapport) : ProxySQL exige `proxysql-cert.pem`/`proxysql-key.pem` et une
  CA nommée `root.crt` ; échec de prechecks si l'horloge NTP n'est pas encore synchronisée après démarrage.

## Vault
- Vault 2.2.0, nœud unique (stockage intégré Raft), écoute HTTPS uniquement (TLS ≥ 1.2), audit fichier activé.
- Initialisation lab : 1 part / seuil 1, clé et jeton root dans /root/.dgsn (600) sur la VM gitlab.
  **Écart assumé au lab** ; production : Shamir 3/5 détenu par des agents distincts ou auto-unseal HSM,
  révocation du jeton root après configuration, cluster Raft 3 ou 5 nœuds.
- Secrets : `kv/ci/demo-app/openstack` (application credential Keystone du projet dgsn-ops : rôle member,
  non « unrestricted », expiration 30 j, rotation par scripts/p6-appcred.sh) et `kv/ci/demo-app/deploy-ssh`.
- Authentification de la CI : JWT/OIDC GitLab (`id_tokens`, audience `https://vault.dgsn.lab`). Rôle
  `ci-demo-app` lié aux claims `project_path=dgsn/demo-app`, `ref=main`, `ref_type=branch`, `ref_protected=true` ;
  politique en lecture seule sur `kv/data/ci/demo-app/*` ; jeton Vault de 10 min, sans politique par défaut.
- Plus aucune variable secrète dans GitLab (DEPLOY_SSH_KEY supprimée ; reste APP_HOST, non secret).

## mTLS — réalisé / perspective
| Flux | État |
|---|---|
| Clients → API OpenStack (haproxy) | TLS serveur (authentification du serveur), pas de certificat client |
| haproxy → services OpenStack | clair sur le réseau de gestion (`kolla_enable_tls_backend` non activé) |
| CI → Vault | TLS serveur + authentification forte par JWT signé (pas de certificat client) |
| Admin → Vault | listener configuré avec `tls_client_ca_file` : certificat client DGSN **vérifié s'il est présenté**, non exigé |
| RabbitMQ / MariaDB internes | non chiffrés (réseau de gestion isolé) |

Perspective DGSN : `kolla_enable_tls_backend` + TLS RabbitMQ/MariaDB, mTLS exigé sur Vault pour les accès
d'administration (`tls_require_and_verify_client_cert`), maillage de services (certificats SPIFFE/SPIRE ou Vault PKI
à courte durée) pour un mTLS généralisé entre composants.
