resource "openstack_networking_secgroup_v2" "talos" {
  name        = var.cluster_name
  description = "Security group for Talos cluster ${var.cluster_name}"
}

# Talos API: Required for talosctl (bootstrap, upgrade, dashboard)
resource "openstack_networking_secgroup_rule_v2" "talos_api" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 50000
  port_range_max    = 50000
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.talos.id
}

# Kubernetes API: Required for kubectl and cluster interaction
resource "openstack_networking_secgroup_rule_v2" "kubernetes_api" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.talos.id
}

# Allow all TCP traffic within the fink subnet
resource "openstack_networking_secgroup_rule_v2" "internal_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "10.180.15.0/24"
  security_group_id = openstack_networking_secgroup_v2.talos.id
}

# Allow all UDP traffic within the fink subnet (required for DNS and VXLAN/CNI)
resource "openstack_networking_secgroup_rule_v2" "internal_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  remote_ip_prefix  = "10.180.15.0/24"
  security_group_id = openstack_networking_secgroup_v2.talos.id
}

# Allow ICMP (Ping) for network diagnostics and troubleshooting
resource "openstack_networking_secgroup_rule_v2" "internal_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "10.180.15.0/24"
  security_group_id = openstack_networking_secgroup_v2.talos.id
}

# VRRP Protocol (112): Essential for the Virtual IP failover mechanism
resource "openstack_networking_secgroup_rule_v2" "vrrp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "112"
  remote_ip_prefix  = "10.180.15.0/24"
  security_group_id = openstack_networking_secgroup_v2.talos.id
}

# ICMP for general connectivity
resource "openstack_networking_secgroup_rule_v2" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  security_group_id = openstack_networking_secgroup_v2.talos.id
}

