# Dedicated network, subnet and router, created when create_network = true
# (IJCLab). Otherwise the cluster joins the existing network_name (CC-IN2P3).
resource "openstack_networking_network_v2" "cluster" {
  count          = var.create_network ? 1 : 0
  name           = var.network_name
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "cluster" {
  count           = var.create_network ? 1 : 0
  name            = "${var.network_name}-subnet"
  network_id      = openstack_networking_network_v2.cluster[0].id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

data "openstack_networking_network_v2" "external" {
  count = var.create_network ? 1 : 0
  name  = var.external_network_name
}

resource "openstack_networking_router_v2" "cluster" {
  count               = var.create_network ? 1 : 0
  name                = local.router_name
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external[0].id
}

resource "openstack_networking_router_interface_v2" "cluster" {
  count     = var.create_network ? 1 : 0
  router_id = openstack_networking_router_v2.cluster[0].id
  subnet_id = openstack_networking_subnet_v2.cluster[0].id
}

# Create VIP port
resource "openstack_networking_port_v2" "vip" {
  name           = "${var.cluster_name}-vip-port"
  network_id     = local.network_id
  admin_state_up = true

  # Only specify IP address if provided, otherwise let OpenStack choose
  dynamic "fixed_ip" {
    for_each = var.vip_ip != null ? [var.vip_ip] : []
    content {
      ip_address = fixed_ip.value
    }
  }
}
