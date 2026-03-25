data "openstack_networking_network_v2" "network" {
  name = var.network_name
}

data "openstack_compute_flavor_v2" "controlplane_flavor" {
  name = var.controlplane_flavor_name
}

data "openstack_compute_flavor_v2" "worker_flavor" {
  name = var.worker_flavor_name
}

data "openstack_images_image_v2" "talos" {
  name        = "talos"
  most_recent = true
}