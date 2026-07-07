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