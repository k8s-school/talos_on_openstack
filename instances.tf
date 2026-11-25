# Create ports for control plane with VIP allowed address pairs
resource "openstack_networking_port_v2" "controlplane" {
  count          = var.control_plane_count
  name           = "${var.cluster_name}-control-plane-${count.index + 1}-port"
  network_id     = local.network_id
  admin_state_up = true
  security_group_ids = [openstack_networking_secgroup_v2.talos.id]

  allowed_address_pairs {
    ip_address = local.vip_ip
  }

  depends_on = [openstack_networking_port_v2.vip]
}

# Control plane instances
resource "openstack_compute_instance_v2" "controlplane" {
  count           = var.control_plane_count
  name            = "${var.cluster_name}-control-plane-${count.index + 1}"
  image_id        = data.openstack_images_image_v2.talos.id
  flavor_id       = data.openstack_compute_flavor_v2.controlplane_flavor.id
  user_data       = base64encode(data.talos_machine_configuration.controlplane.machine_configuration)

  network {
    port = openstack_networking_port_v2.controlplane[count.index].id
  }

  # With create_network, boot only once the router gives the nodes egress
  depends_on = [openstack_networking_router_interface_v2.cluster]
}

# Create ports for workers
resource "openstack_networking_port_v2" "worker" {
  count          = var.worker_count
  name           = "${var.cluster_name}-worker-${count.index + 1}-port"
  network_id     = local.network_id
  admin_state_up = true
  security_group_ids = [openstack_networking_secgroup_v2.talos.id]
}

# Worker instances
resource "openstack_compute_instance_v2" "worker" {
  count           = var.worker_count
  name            = "${var.cluster_name}-worker-${count.index + 1}"
  image_id        = data.openstack_images_image_v2.talos.id
  flavor_id       = data.openstack_compute_flavor_v2.worker_flavor.id
  user_data       = base64encode(data.talos_machine_configuration.worker.machine_configuration)

  network {
    port = openstack_networking_port_v2.worker[count.index].id
  }

  depends_on = [
    openstack_compute_instance_v2.controlplane
  ]
}

# Create ports for the dedicated big-worker pool
resource "openstack_networking_port_v2" "bigworker" {
  count          = var.bigworker_count
  name           = "${var.cluster_name}-bigworker-${count.index + 1}-port"
  network_id     = local.network_id
  admin_state_up = true
  security_group_ids = [openstack_networking_secgroup_v2.talos.id]
}

# Big-worker instances (labeled/tainted for a dedicated workload, e.g. raw2science)
resource "openstack_compute_instance_v2" "bigworker" {
  count           = var.bigworker_count
  name            = "${var.cluster_name}-bigworker-${count.index + 1}"
  image_id        = data.openstack_images_image_v2.talos.id
  flavor_id       = data.openstack_compute_flavor_v2.bigworker_flavor[0].id
  user_data       = base64encode(data.talos_machine_configuration.bigworker.machine_configuration)

  network {
    port = openstack_networking_port_v2.bigworker[count.index].id
  }

  depends_on = [
    openstack_compute_instance_v2.controlplane
  ]
}
# Secondary disk of workers and big workers, for clouds whose flavors have no
# ephemeral disk (IJCLab): talos.tf puts the EPHEMERAL volume (/var) on the
# non-install disk, vdb, which an ephemeral flavor provides at CC-IN2P3.
locals {
  data_volume_nodes = var.worker_volume_size > 0 ? merge(
    { for s in openstack_compute_instance_v2.worker : s.name => s.id },
    { for s in openstack_compute_instance_v2.bigworker : s.name => s.id },
  ) : {}
}

resource "openstack_blockstorage_volume_v3" "data" {
  for_each = var.worker_volume_size > 0 ? toset(concat(
    [for i in range(var.worker_count) : "${var.cluster_name}-worker-${i + 1}"],
    [for i in range(var.bigworker_count) : "${var.cluster_name}-bigworker-${i + 1}"],
  )) : toset([])
  name = "${each.key}-data"
  size = var.worker_volume_size
}

resource "openstack_compute_volume_attach_v2" "data" {
  for_each    = openstack_blockstorage_volume_v3.data
  instance_id = local.data_volume_nodes[each.key]
  volume_id   = each.value.id
}
