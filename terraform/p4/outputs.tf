output "floating_ips" {
  value = { for k, v in openstack_networking_floatingip_v2.fip : k => v.address }
}

output "private_ips" {
  value = { for k, v in openstack_networking_port_v2.port : k => v.all_fixed_ips[0] }
}
