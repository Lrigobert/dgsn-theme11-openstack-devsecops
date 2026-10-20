#!/usr/bin/env bash
# Diagnostic CI (root sur gitlab) : raison d'échec des jobs du dernier pipeline, état du runner.
H="PRIVATE-TOKEN: $(cat /root/.dgsn/gitlab-pat)"; PID=$(cat /root/.dgsn/project-id); API=http://192.168.100.50/api/v4
PL=$(curl -s -H "$H" "$API/projects/$PID/pipelines?per_page=1" | python3 -c 'import sys,json; print(json.load(sys.stdin)[0]["id"])')
curl -s -H "$H" "$API/projects/$PID/pipelines/$PL/jobs" | python3 -c '
import sys,json
for j in json.load(sys.stdin):
    print(j["name"], j["status"], "failure_reason=%s" % j.get("failure_reason"), "runner=%s" % (j.get("runner") or {}).get("description"))'
echo "--- runners"
curl -s -H "$H" "$API/runners/all" | python3 -c 'import sys,json; [print(r["id"], r["description"], r["status"], "online=%s" % r.get("online")) for r in json.load(sys.stdin)]'
systemctl is-active gitlab-runner
gitlab-runner verify 2>&1 | sed -E 's/glrt-[A-Za-z0-9._-]+/[SECRET]/g' | tail -2
grep -E '^\s*(url|executor|image|pull_policy|network_mode)' /etc/gitlab-runner/config.toml
