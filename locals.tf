locals {
  # Use the provided VIP IP or get the automatically assigned one from the port
  vip_ip = var.vip_ip != null ? var.vip_ip : openstack_networking_port_v2.vip.all_fixed_ips[0]
}