#!/usr/bin/env python3
"""Génère le dashboard Grafana « DGSN Thème 11 — Cloud privé OpenStack » (16 panneaux, datasource uid dgsn-prom)."""
import json
import sys

DS = {"type": "prometheus", "uid": "dgsn-prom"}
NODES = 'job=~"dgsn-node-mtls|node-vm1-ansible|node-vm4-grafana"'
panels, pid, y = [], 1, 0


def add(kind, title, targets, w, h, x, unit=None, desc="", extra=None):
    global pid
    p = {"id": pid, "type": kind, "title": title, "description": desc, "datasource": DS,
         "gridPos": {"x": x, "y": y, "w": w, "h": h},
         "targets": [{"refId": chr(65 + i), "expr": e, "legendFormat": l, "datasource": DS} for i, (e, l) in enumerate(targets)],
         "fieldConfig": {"defaults": {"unit": unit or "short"}, "overrides": []},
         "options": {}}
    if kind == "stat":
        p["options"] = {"reduceOptions": {"calcs": ["lastNotNull"]}, "colorMode": "background", "graphMode": "area", "textMode": "value_and_name"}
    if extra:
        p["fieldConfig"]["defaults"].update(extra)
    panels.append(p)
    pid += 1


def row(title):
    global pid, y
    panels.append({"id": pid, "type": "row", "title": title, "collapsed": False, "gridPos": {"x": 0, "y": y, "w": 24, "h": 1}, "panels": []})
    pid += 1
    y += 1


thr_up = {"thresholds": {"mode": "absolute", "steps": [{"color": "red", "value": None}, {"color": "green", "value": 1}]}}

row("OpenStack 2025.1 — plan de contrôle")
add("stat", "Services OpenStack disponibles (1 = up)",
    [("openstack_nova_up", "Nova"), ("openstack_neutron_up", "Neutron"), ("openstack_glance_up", "Glance"),
     ("openstack_identity_up", "Keystone"), ("openstack_placement_up", "Placement")], 10, 5, 0, extra=thr_up)
add("stat", "Agents Nova up", [("sum(openstack_nova_agent_state)", "up"), ("count(openstack_nova_agent_state)", "total")], 4, 5, 10)
add("stat", "Agents Neutron vivants", [("sum(openstack_neutron_agent_state)", "vivants"), ("count(openstack_neutron_agent_state)", "total")], 4, 5, 14)
add("stat", "Projets / utilisateurs Keystone", [("openstack_identity_projects", "projets"), ("openstack_identity_users", "utilisateurs")], 6, 5, 18)
y += 5

row("OpenStack — ressources")
add("stat", "Instances (total / ACTIVE)",
    [("openstack_nova_total_vms", "total"), ('count(openstack_nova_server_status{status="ACTIVE"}) or vector(0)', "ACTIVE")], 6, 5, 0)
add("stat", "vCPU utilisés (somme des projets)", [("sum(openstack_nova_limits_vcpus_used)", "vCPU")], 4, 5, 6)
add("stat", "RAM réservée par les instances", [("sum(openstack_nova_limits_memory_used) * 1024 * 1024", "RAM")], 4, 5, 10, unit="bytes")
add("stat", "IP flottantes (allouées)", [("openstack_neutron_floating_ips", "IP flottantes")], 4, 5, 14)
add("stat", "Images Glance", [("openstack_glance_images", "images")], 3, 5, 18)
add("stat", "Réseaux / routeurs / groupes de sécurité",
    [("openstack_neutron_networks", "réseaux"), ("openstack_neutron_routers", "routeurs"), ("openstack_neutron_security_groups", "secgroups")], 3, 5, 21)
y += 5
add("timeseries", "Placement : utilisation vs capacité (controller)",
    [('openstack_placement_resource_usage{resourcetype=~"VCPU|MEMORY_MB"}', "{{resourcetype}} utilisé"),
     ('openstack_placement_resource_total{resourcetype=~"VCPU|MEMORY_MB"}', "{{resourcetype}} capacité")], 24, 7, 0)
y += 7

row("Nœuds (node_exporter — mTLS pour controller et instances)")
add("timeseries", "CPU utilisé (%)",
    [(f'100 - avg by (vm) (rate(node_cpu_seconds_total{{mode="idle",{NODES}}}[2m])) * 100', "{{vm}}")], 12, 7, 0, unit="percent")
add("timeseries", "Mémoire utilisée (%)",
    [(f'100 * (1 - node_memory_MemAvailable_bytes{{{NODES}}} / node_memory_MemTotal_bytes{{{NODES}}})', "{{vm}}")], 12, 7, 12, unit="percent")
y += 7
add("timeseries", "Disque / utilisé (%)",
    [(f'100 * (1 - node_filesystem_avail_bytes{{mountpoint="/",{NODES}}} / node_filesystem_size_bytes{{mountpoint="/",{NODES}}})', "{{vm}}")], 8, 7, 0, unit="percent")
add("timeseries", "Réseau (octets/s, réception + émission)",
    [(f'sum by (vm) (rate(node_network_receive_bytes_total{{device!="lo",{NODES}}}[2m]))', "{{vm}} rx"),
     (f'-sum by (vm) (rate(node_network_transmit_bytes_total{{device!="lo",{NODES}}}[2m]))', "{{vm}} tx")], 8, 7, 8, unit="Bps")
add("timeseries", "Charge système (load 1 min)", [(f"node_load1{{{NODES}}}", "{{vm}}")], 8, 7, 16)

dash = {"uid": "dgsn-theme11", "title": "DGSN Thème 11 — Cloud privé OpenStack", "tags": ["dgsn", "openstack", "theme11"],
        "timezone": "browser", "schemaVersion": 39, "version": 1, "refresh": "30s",
        "time": {"from": "now-1h", "to": "now"}, "editable": False, "panels": panels}
json.dump(dash, sys.stdout, ensure_ascii=False, indent=2)
n = sum(len(p.get("targets", [])) for p in panels)
print(f"panneaux de données : {sum(1 for p in panels if p['type'] != 'row')}, requêtes : {n}", file=sys.stderr)
