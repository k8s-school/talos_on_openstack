# Control plane instances
resource "openstack_compute_instance_v2" "controlplane" {
  count           = var.control_plane_count
  name            = "talos-control-plane-${count.index + 1}"
  image_id        = data.openstack_images_image_v2.talos.id
  flavor_id       = data.openstack_compute_flavor_v2.controlplane_flavor.id
  key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = [openstack_networking_secgroup_v2.talos.name]
  user_data       = base64encode(data.talos_machine_configuration.controlplane.machine_configuration)

  network {
    uuid = data.openstack_networking_network_v2.network.id
  }

  depends_on = [
    openstack_networking_port_v2.vip
  ]
}

# Configure allowed address pairs for VIP on control plane nodes
resource "openstack_networking_port_v2" "controlplane" {
  count          = var.control_plane_count
  name           = "talos-control-plane-${count.index + 1}-port"
  network_id     = data.openstack_networking_network_v2.network.id
  admin_state_up = true

  allowed_address_pairs {
    ip_address = local.vip_ip
  }

  depends_on = [openstack_compute_instance_v2.controlplane]
}

# Associate ports with control plane instances
resource "openstack_compute_interface_attach_v2" "controlplane" {
  count       = var.control_plane_count
  instance_id = openstack_compute_instance_v2.controlplane[count.index].id
  port_id     = openstack_networking_port_v2.controlplane[count.index].id
}

# Worker instances
resource "openstack_compute_instance_v2" "worker" {
  count           = var.worker_count
  name            = "talos-worker-${count.index + 1}"
  image_id        = data.openstack_images_image_v2.talos.id
  flavor_id       = data.openstack_compute_flavor_v2.worker_flavor.id
  key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = [openstack_networking_secgroup_v2.talos.name]
  user_data       = base64encode(data.talos_machine_configuration.worker.machine_configuration)

  network {
    uuid = data.openstack_networking_network_v2.network.id
  }

  depends_on = [
    openstack_compute_instance_v2.controlplane
  ]
}