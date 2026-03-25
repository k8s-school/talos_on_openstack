# Generate Talos machine secrets
resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

# Generate Talos client configuration
data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [local.vip_ip]
}

# Generate control plane configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.vip_ip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets

  config_patches = [
    # VIP configuration
    yamlencode({
      machine = {
        network = {
          interfaces = [{
            interface = "eth0"
            dhcp      = true
            vip = {
              ip = local.vip_ip
            }
          }]
        }
      }
    }),
    # PTP configuration
    yamlencode({
      machine = {
        time = {
          servers = ["/dev/ptp0"]
        }
        kernel = {
          modules = [{
            name = "ptp_kvm"
          }]
        }
      }
    })
  ]
}

# Generate worker configuration
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.vip_ip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets

  config_patches = [
    # PTP configuration for workers
    yamlencode({
      machine = {
        time = {
          servers = ["/dev/ptp0"]
        }
        kernel = {
          modules = [{
            name = "ptp_kvm"
          }]
        }
      }
    })
  ]
}