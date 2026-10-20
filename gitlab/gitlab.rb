# /etc/gitlab/gitlab.rb — GitLab CE en mode économe (VM 4 Go + 4 Go de swap), lab DGSN Thème 11.
# Aucun secret ici : le mot de passe root initial est généré par GitLab dans
# /etc/gitlab/initial_root_password (root:600) sur la VM gitlab.

external_url 'http://192.168.100.50'
registry_external_url 'http://192.168.100.50:5050'   # TLS en phase 6

# --- Empreinte mémoire réduite (doc GitLab « Running GitLab in a memory-constrained environment ») ---
puma['worker_processes'] = 0                 # mode single (pas de workers forkés)
puma['min_threads'] = 4
puma['max_threads'] = 4
sidekiq['concurrency'] = 5                   # défaut : 20
gitlab_rails['env'] = {
  'MALLOC_CONF' => 'dirty_decay_ms:1000,muzzy_decay_ms:1000'
}
gitaly['env'] = {
  'MALLOC_CONF' => 'dirty_decay_ms:1000,muzzy_decay_ms:1000',
  'GITALY_COMMAND_SPAWN_MAX_PARALLEL' => '2'
}
postgresql['shared_buffers'] = '128MB'
postgresql['max_worker_processes'] = 4

# Supervision interne désactivée (Prometheus, Alertmanager, exporters) : supervision en P7 sur VM4
prometheus_monitoring['enable'] = false
alertmanager['enable'] = false
node_exporter['enable'] = false
redis_exporter['enable'] = false
postgres_exporter['enable'] = false
gitlab_exporter['enable'] = false

# Composants non utilisés
gitlab_kas['enable'] = false
gitlab_pages['enable'] = false
mattermost['enable'] = false
letsencrypt['enable'] = false
gitlab_rails['usage_ping_enabled'] = false
gitlab_rails['gitlab_email_enabled'] = false
gitlab_rails['incoming_email_enabled'] = false
