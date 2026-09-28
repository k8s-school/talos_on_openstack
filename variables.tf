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
  description = "OpenStack network name"
  type        = string
  default     = "fink"
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
  description = "OpenStack router the cluster egresses through; its external IP is the source address allowed by external_access"
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