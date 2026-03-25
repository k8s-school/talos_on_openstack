output "talos_config" {
  description = "Talos client configuration"
  value       = talos_client_configuration.cluster.talos_config
  sensitive   = true
}

output "controlplane_ips" {
  description = "Control plane node IP addresses"
  value       = openstack_compute_instance_v2.controlplane[*].access_ip_v4
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value       = openstack_compute_instance_v2.worker[*].access_ip_v4
}

output "vip_ip" {
  description = "Virtual IP address"
  value       = local.vip_ip
}

output "cluster_endpoint" {
  description = "Cluster endpoint URL"
  value       = "https://${local.vip_ip}:6443"
}

output "controlplane_machine_config" {
  description = "Control plane machine configuration"
  value       = talos_machine_configuration.controlplane.machine_configuration
  sensitive   = true
}

output "worker_machine_config" {
  description = "Worker machine configuration"
  value       = talos_machine_configuration.worker.machine_configuration
  sensitive   = true
}