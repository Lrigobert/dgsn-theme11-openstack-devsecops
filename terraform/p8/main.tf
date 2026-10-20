terraform {
  required_version = ">= 1.6"
  required_providers {
    openstack = { source = "terraform-provider-openstack/openstack", version = "~> 3.0" }
  }
}
# Authentification par variables OS_* (projet dgsn-ops) ; aucun identifiant dans ce dépôt.
provider "openstack" {}

variable "names" {
  type    = list(string)
  default = ["scap-1", "scap-2"]
}

data "openstack_networking_network_v2" "ext" { name = "public1" }
data "openstack_images_image_v2" "img" {
  name        = "debian-12"
  most_recent = true
}

resource "openstack_compute_keypair_v2" "kp" {
  name       = "dgsn-p8-admin"
  public_key = file(pathexpand("~/.ssh/id_ed25519.pub"))
}

resource "openstack_networking_network_v2" "net" { name = "dgsn-p8-net" }
resource "openstack_networking_subnet_v2" "subnet" {
  name            = "dgsn-p8-subnet"
  network_id      = openstack_networking_network_v2.net.id
  cidr            = "10.80.0.0/24"
  dns_nameservers = ["1.1.1.1", "9.9.9.9"]
}
resource "openstack_networking_router_v2" "router" {
  name                = "dgsn-p8-router"
  external_network_id = data.openstack_networking_network_v2.ext.id
}
resource "openstack_networking_router_interface_v2" "rif" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

resource "openstack_networking_secgroup_v2" "sg" {
  name        = "dgsn-p8-sg"
  description = "P8 conformité : SSH depuis l'administration (VM1) et la supervision (VM4, test Fail2Ban)"
}
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  for_each          = toset(["192.168.100.10/32", "192.168.100.30/32"])
  security_group_id = openstack_networking_secgroup_v2.sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value
}

resource "openstack_networking_port_v2" "port" {
  for_each           = toset(var.names)
  name               = each.key
  network_id         = openstack_networking_network_v2.net.id
  security_group_ids = [openstack_networking_secgroup_v2.sg.id]
  fixed_ip { subnet_id = openstack_networking_subnet_v2.subnet.id }
}

resource "openstack_compute_instance_v2" "vm" {
  for_each    = toset(var.names)
  name        = each.key
  image_id    = data.openstack_images_image_v2.img.id
  flavor_name = "dgsn.app"
  key_pair    = openstack_compute_keypair_v2.kp.name
  user_data   = "#cloud-config\nhostname: ${each.key}\nssh_pwauth: false\npackage_update: false\nruncmd:\n  - [ sh, -c, 'date -Is > /var/lib/dgsn-cloud-init-done' ]\n"
  metadata    = { role = "conformite", projet = "dgsn-theme11" }
  network { port = openstack_networking_port_v2.port[each.key].id }
}

resource "openstack_networking_floatingip_v2" "fip" {
  for_each   = toset(var.names)
  pool       = "public1"
  port_id    = openstack_networking_port_v2.port[each.key].id
  depends_on = [openstack_networking_router_interface_v2.rif]
}

output "ips" {
  value = { for k, v in openstack_networking_floatingip_v2.fip : k => v.address }
}
