terraform {
  required_version = ">= 1.6"
  required_providers {
    openstack = { source = "terraform-provider-openstack/openstack", version = "~> 3.0" }
  }
}
# Authentification par variables OS_* (projet dgsn-ops) ; aucun identifiant dans ce dépôt.
provider "openstack" {}

# Cluster k3s 3 nœuds : 1 serveur (plan de contrôle + charge) et 2 agents
variable "nodes" {
  type = map(string)
  default = {
    k3s-1 = "dgsn.app"    # serveur : 1 vCPU / 1 Go
    k3s-2 = "dgsn.k3s"    # agent   : 1 vCPU / 768 Mo
    k3s-3 = "dgsn.k3s"
  }
}

data "openstack_networking_network_v2" "ext" { name = "public1" }
data "openstack_images_image_v2" "img" {
  name        = "debian-12"
  most_recent = true
}
resource "openstack_compute_keypair_v2" "kp" {
  name       = "dgsn-p9-admin"
  public_key = file(pathexpand("~/.ssh/id_ed25519.pub"))
}
resource "openstack_networking_network_v2" "net" { name = "dgsn-p9-net" }
resource "openstack_networking_subnet_v2" "subnet" {
  name            = "dgsn-p9-subnet"
  network_id      = openstack_networking_network_v2.net.id
  cidr            = "10.90.0.0/24"
  dns_nameservers = ["1.1.1.1", "9.9.9.9"]
}
resource "openstack_networking_router_v2" "router" {
  name                = "dgsn-p9-router"
  external_network_id = data.openstack_networking_network_v2.ext.id
}
resource "openstack_networking_router_interface_v2" "rif" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

resource "openstack_networking_secgroup_v2" "sg" {
  name        = "dgsn-p9-sg"
  description = "Cluster k3s : trafic intra-cluster libre, SSH et NodePort depuis VM1"
}
# Intra-cluster (API 6443, kubelet 10250, flannel VXLAN 8472/udp) : membres du même groupe
resource "openstack_networking_secgroup_rule_v2" "intra" {
  for_each          = toset(["tcp", "udp", "icmp"])
  security_group_id = openstack_networking_secgroup_v2.sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value
  remote_group_id   = openstack_networking_secgroup_v2.sg.id
}
resource "openstack_networking_secgroup_rule_v2" "admin" {
  for_each          = { ssh = 22, nodeport = 30080 }
  security_group_id = openstack_networking_secgroup_v2.sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value
  port_range_max    = each.value
  remote_ip_prefix  = "192.168.100.10/32"
}

resource "openstack_networking_port_v2" "port" {
  for_each           = var.nodes
  name               = each.key
  network_id         = openstack_networking_network_v2.net.id
  security_group_ids = [openstack_networking_secgroup_v2.sg.id]
  fixed_ip { subnet_id = openstack_networking_subnet_v2.subnet.id }
}
resource "openstack_compute_instance_v2" "vm" {
  for_each    = var.nodes
  name        = each.key
  image_id    = data.openstack_images_image_v2.img.id
  flavor_name = each.value
  key_pair    = openstack_compute_keypair_v2.kp.name
  # Métadonnées sur disque local : évite la dépendance au service de métadonnées (1 worker, saturé lors
  # de démarrages simultanés — constat P9, voir rapport)
  config_drive = true
  user_data   = "#cloud-config\nhostname: ${each.key}\nssh_pwauth: false\npackage_update: false\nruncmd:\n  - [ sh, -c, 'date -Is > /var/lib/dgsn-cloud-init-done' ]\n"
  metadata    = { role = "k3s", projet = "dgsn-theme11" }
  network { port = openstack_networking_port_v2.port[each.key].id }
}
resource "openstack_networking_floatingip_v2" "fip" {
  for_each   = var.nodes
  pool       = "public1"
  port_id    = openstack_networking_port_v2.port[each.key].id
  depends_on = [openstack_networking_router_interface_v2.rif]
}

output "ips" {
  value = { for k, v in openstack_networking_floatingip_v2.fip : k => { public = v.address, private = openstack_networking_port_v2.port[k].all_fixed_ips[0] } }
}
