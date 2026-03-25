# Create VIP port
resource "openstack_networking_port_v2" "vip" {
  name           = "${var.cluster_name}-vip-port"
  network_id     = data.openstack_networking_network_v2.network.id
  admin_state_up = true

  # Only specify IP address if provided, otherwise let OpenStack choose
  dynamic "fixed_ip" {
    for_each = var.vip_ip != null ? [var.vip_ip] : []
    content {
      ip_address = fixed_ip.value
    }
  }
}