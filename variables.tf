variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
  default     = "fink-cluster"
}


variable "vip_ip" {
  description = "Virtual IP address for the cluster (if not specified, will find an available IP automatically)"
  type        = string
  default     = null
}

variable "network_name" {
  description = "OpenStack network name: an existing network, or the one to create when create_network = true"
  type        = string
  default     = "fink"
}

variable "create_network" {
  description = "Create a dedicated network, subnet and router (named network_name, router_name), instead of using an existing network"
  type        = bool
  default     = false
}

variable "subnet_cidr" {
  description = "CIDR of the cluster subnet: allowed by the internal security group rules, and used for the subnet when create_network = true"
  type        = string
  default     = "10.180.15.0/24"
}

variable "external_network_name" {
  description = "External network the created router uses as gateway (create_network = true only)"
  type        = string
  default     = "public"
}

variable "dns_nameservers" {
  description = "DNS servers of the created subnet (create_network = true only); empty uses the cloud default"
  type        = list(string)
  default     = []
}

variable "controlplane_flavor_name" {
  description = "OpenStack flavor for control plane instances"
  type        = string
  default     = "m1.small"
}

variable "worker_flavor_name" {
  description = "OpenStack flavor for worker instances"
  type        = string
  default     = "m1.medium"
}

variable "bigworker_flavor_name" {
  description = "OpenStack flavor for the dedicated big-worker pool (e.g. memory-heavy Spark jobs like raw2science)"
  type        = string
  default     = "fink.m2.xlarge.1"
}


variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "bigworker_count" {
  description = "Number of dedicated big-worker nodes (labeled/tainted for a specific workload)"
  type        = number
  default     = 0
}

variable "bigworker_node_labels" {
  description = "Node labels of the big-worker pool, so a workload can target it"
  type        = map(string)
  default     = {}
}

variable "bigworker_taint" {
  description = "Taint of the big-worker pool (key=value:Effect), keeps other pods off it; empty for none"
  type        = string
  default     = ""
}

variable "router_name" {
  description = "OpenStack router the cluster egresses through (its external IP is the source address allowed by external_access); with create_network, the router to create, default <network_name>-router"
  type        = string
  default     = null
}

variable "external_access" {
  description = "Security groups opening services outside the cluster to its egress IP: name => one ingress rule per TCP port"
  type = map(object({
    description = string
    rules = list(object({
      port        = number
      description = string
    }))
  }))
  default = {}
}

variable "external_access_targets" {
  description = "IPs of the servers each external_access security group is attached to: name => IPs (kept out of git)"
  type        = map(list(string))
  default     = {}
}


variable "talos_image_name" {
  description = "Glance image the nodes boot from (e.g. talos-v1.12.5); changing it replaces the nodes"
  type        = string
  default     = "talos"
}

variable "talos_version" {
  description = "Talos version"
  type        = string
  default     = "v1.12.5"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.35.0"
}