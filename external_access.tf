# Opt-in access from the cluster to services running outside it on other
# servers of the same OpenStack project (e.g. an HDFS cluster). Pods leave the
# cluster NATed behind the router's external IP, so each security group only
# allows that single address, on the declared TCP ports.
#
# The security group is attached to the target servers' ports *in addition* to
# the groups they already carry (enforce = false): their own security groups
# are left untouched, and a destroy only detaches what was attached here.
#
# An `apply` restores a deleted group, rule or attachment. Rules added by hand
# to the group are not tracked.

data "openstack_networking_router_v2" "egress" {
  count = length(var.external_access) > 0 ? 1 : 0
  name  = var.router_name
}

locals {
  egress_ip = length(var.external_access) > 0 ? data.openstack_networking_router_v2.egress[0].external_fixed_ip[0].ip_address : null

  # "<name>-<port>" => rule
  external_access_rules = merge([
    for name, access in var.external_access : {
      for port in access.ports : "${name}-${port}" => { access = name, port = port }
    }
  ]...)

  # "<name>-<ip>" => attachment
  external_access_targets = merge([
    for name, ips in var.external_access_targets : {
      for ip in ips : "${name}-${ip}" => { access = name, ip = ip }
    }
  ]...)
}

resource "openstack_networking_secgroup_v2" "external_access" {
  for_each    = var.external_access
  name        = each.key
  description = each.value.description
}

resource "openstack_networking_secgroup_rule_v2" "external_access" {
  for_each          = local.external_access_rules
  description       = "${each.value.access}: TCP ${each.value.port} from the ${var.cluster_name} egress (${var.router_name})"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = "${local.egress_ip}/32"
  security_group_id = openstack_networking_secgroup_v2.external_access[each.value.access].id
}

data "openstack_networking_port_v2" "external_access_target" {
  for_each = local.external_access_targets
  fixed_ip = each.value.ip
}

resource "openstack_networking_port_secgroup_associate_v2" "external_access" {
  for_each           = local.external_access_targets
  port_id            = data.openstack_networking_port_v2.external_access_target[each.key].id
  security_group_ids = [openstack_networking_secgroup_v2.external_access[each.value.access].id]
  enforce            = false
}
