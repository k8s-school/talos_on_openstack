locals {
  # Use the provided VIP IP or get the automatically assigned one from the port
  vip_ip = var.vip_ip != null ? var.vip_ip : openstack_networking_port_v2.vip.all_fixed_ips[0]

  # Taken from the subnet when the network is created, so that ports are only
  # created once the subnet exists
  network_id = var.create_network ? openstack_networking_subnet_v2.cluster[0].network_id : data.openstack_networking_network_v2.network[0].id

  router_name = coalesce(var.router_name, "${var.network_name}-router")
}
