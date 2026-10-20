terraform {
  required_version = ">= 1.6"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}

# Authentification par variables OS_* (projet dgsn-ops) ; aucun identifiant dans ce dépôt.
provider "openstack" {}

variable "deploy_public_key" {
  description = "Clé publique de déploiement de la CI (générée sur la VM gitlab)"
  type        = string
}

variable "admin_public_key_file" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

data "openstack_networking_network_v2" "ext" {
  name = "public1"
}

data "openstack_images_image_v2" "img" {
  name        = "debian-12"
  most_recent = true
}

resource "openstack_compute_keypair_v2" "kp" {
  name       = "dgsn-app-deploy"
  public_key = var.deploy_public_key
}

resource "openstack_networking_network_v2" "net" {
  name = "dgsn-app-net"
}

resource "openstack_networking_subnet_v2" "subnet" {
  name            = "dgsn-app-subnet"
  network_id      = openstack_networking_network_v2.net.id
  cidr            = "10.50.0.0/24"
  dns_nameservers = ["1.1.1.1", "9.9.9.9"]
}

resource "openstack_networking_router_v2" "router" {
  name                = "dgsn-app-router"
  external_network_id = data.openstack_networking_network_v2.ext.id
}

resource "openstack_networking_router_interface_v2" "rif" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

resource "openstack_networking_secgroup_v2" "sg" {
  name        = "dgsn-app-sg"
  description = "Application conteneurisée : HTTP public, SSH depuis la CI (gitlab) et le poste d'admin (VM1)"
}

locals {
  rules = {
    http      = { port = 80, cidr = "0.0.0.0/0", proto = "tcp" }
    ssh_ci    = { port = 22, cidr = "192.168.100.50/32", proto = "tcp" }
    ssh_admin = { port = 22, cidr = "192.168.100.10/32", proto = "tcp" }
    icmp      = { port = null, cidr = "192.168.100.0/24", proto = "icmp" }
    node_exp  = { port = 9100, cidr = "192.168.100.30/32", proto = "tcp" }   # P7 : supervision (VM4), mTLS
  }
}

resource "openstack_networking_secgroup_rule_v2" "r" {
  for_each          = local.rules
  security_group_id = openstack_networking_secgroup_v2.sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value.proto
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = each.value.cidr
}

resource "openstack_networking_port_v2" "port" {
  name               = "dgsn-app-1"
  network_id         = openstack_networking_network_v2.net.id
  security_group_ids = [openstack_networking_secgroup_v2.sg.id]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet.id
  }
}

resource "openstack_compute_instance_v2" "app" {
  name      = "dgsn-app-1"
  image_id  = data.openstack_images_image_v2.img.id
  flavor_name = "dgsn.app"   # 1 vCPU / 1 Go / 8 Go (Docker + application)
  key_pair  = openstack_compute_keypair_v2.kp.name
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    admin_key = trimspace(file(pathexpand(var.admin_public_key_file)))
  })
  metadata = { role = "app", projet = "dgsn-theme11" }
  network {
    port = openstack_networking_port_v2.port.id
  }
}

resource "openstack_networking_floatingip_v2" "fip" {
  pool       = "public1"
  port_id    = openstack_networking_port_v2.port.id
  depends_on = [openstack_networking_router_interface_v2.rif]
}

output "app_ip" {
  value = openstack_networking_floatingip_v2.fip.address
}
