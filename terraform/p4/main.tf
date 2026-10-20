data "openstack_networking_network_v2" "ext" {
  name = var.external_network
}

data "openstack_images_image_v2" "img" {
  name        = var.image
  most_recent = true
}

data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor
}

resource "openstack_compute_keypair_v2" "deploy" {
  name       = "${var.prefix}-deploy"
  public_key = file(pathexpand(var.ssh_public_key_file))
}

# ---------- Réseau ----------
resource "openstack_networking_network_v2" "net" {
  name = "${var.prefix}-net"
}

resource "openstack_networking_subnet_v2" "subnet" {
  name            = "${var.prefix}-subnet"
  network_id      = openstack_networking_network_v2.net.id
  cidr            = var.cidr
  ip_version      = 4
  dns_nameservers = ["1.1.1.1", "9.9.9.9"]
}

resource "openstack_networking_router_v2" "router" {
  name                = "${var.prefix}-router"
  external_network_id = data.openstack_networking_network_v2.ext.id
}

resource "openstack_networking_router_interface_v2" "rif" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

# ---------- Groupes de sécurité (moindre privilège, flux nommés) ----------
resource "openstack_networking_secgroup_v2" "sg" {
  for_each    = toset(["bastion", "web", "app", "db"])
  name        = "${var.prefix}-sg-${each.key}"
  description = "DGSN P4 - rôle ${each.key}"
}

locals {
  sg = { for k, v in openstack_networking_secgroup_v2.sg : k => v.id }
  rules = {
    bastion_ssh_admin = { sg = "bastion", port = 22, proto = "tcp", cidr = var.admin_cidr, from = null }
    bastion_icmp      = { sg = "bastion", port = null, proto = "icmp", cidr = var.admin_cidr, from = null }
    web_http          = { sg = "web", port = 80, proto = "tcp", cidr = "0.0.0.0/0", from = null }
    web_icmp          = { sg = "web", port = null, proto = "icmp", cidr = var.admin_cidr, from = null }
    web_ssh_bastion   = { sg = "web", port = 22, proto = "tcp", cidr = null, from = "bastion" }
    app_http_web      = { sg = "app", port = 8080, proto = "tcp", cidr = null, from = "web" }
    app_ssh_bastion   = { sg = "app", port = 22, proto = "tcp", cidr = null, from = "bastion" }
    db_pg_app         = { sg = "db", port = 5432, proto = "tcp", cidr = null, from = "app" }
    db_ssh_bastion    = { sg = "db", port = 22, proto = "tcp", cidr = null, from = "bastion" }
  }
}

resource "openstack_networking_secgroup_rule_v2" "r" {
  for_each          = local.rules
  security_group_id = local.sg[each.value.sg]
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value.proto
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = each.value.cidr
  remote_group_id   = each.value.from == null ? null : local.sg[each.value.from]
}

# ---------- Instances ----------
resource "openstack_networking_port_v2" "port" {
  for_each           = var.instances
  name               = "${var.prefix}-${each.key}"
  network_id         = openstack_networking_network_v2.net.id
  security_group_ids = [local.sg[each.value.role]]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet.id
  }
}

resource "openstack_compute_instance_v2" "vm" {
  for_each  = var.instances
  name      = "${var.prefix}-${each.key}"
  image_id  = data.openstack_images_image_v2.img.id
  flavor_id = data.openstack_compute_flavor_v2.flavor.id
  key_pair  = openstack_compute_keypair_v2.deploy.name
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    hostname = each.key
    role     = each.value.role
  })
  metadata = { role = each.value.role, projet = "dgsn-theme11" }

  network {
    port = openstack_networking_port_v2.port[each.key].id
  }
}

resource "openstack_networking_floatingip_v2" "fip" {
  for_each = { for k, v in var.instances : k => v if v.floating }
  pool     = var.external_network
  port_id  = openstack_networking_port_v2.port[each.key].id

  depends_on = [openstack_networking_router_interface_v2.rif]
}

# ---------- Inventaire Ansible généré ----------
resource "local_file" "inventory" {
  filename        = "${path.module}/../../ansible/p4/inventory.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/inventory.tftpl", {
    bastion = openstack_networking_floatingip_v2.fip["bastion-1"].address
    hosts = { for k, v in var.instances : k => {
      role = v.role
      ip   = openstack_networking_port_v2.port[k].all_fixed_ips[0]
    } }
  })
}

resource "local_file" "ssh_config" {
  filename        = "${path.module}/../../ansible/p4/ssh_config"
  file_permission = "0644"
  content = templatefile("${path.module}/ssh_config.tftpl", {
    bastion   = openstack_networking_floatingip_v2.fip["bastion-1"].address
    cidr_glob = replace(var.cidr, "0/24", "*")
  })
}
