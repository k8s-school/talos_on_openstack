# Existing network (CC-IN2P3): looked up by name, unless create_network
data "openstack_networking_network_v2" "network" {
  count = var.create_network ? 0 : 1
  name  = var.network_name
}

data "openstack_compute_flavor_v2" "controlplane_flavor" {
  name = var.controlplane_flavor_name
}

data "openstack_compute_flavor_v2" "worker_flavor" {
  name = var.worker_flavor_name
}

# Only looked up when the pool is used: its flavor may not exist on every cloud
data "openstack_compute_flavor_v2" "bigworker_flavor" {
  count = var.bigworker_count > 0 ? 1 : 0
  name  = var.bigworker_flavor_name
}

data "openstack_images_image_v2" "talos" {
  name        = var.talos_image_name
  most_recent = true
}
