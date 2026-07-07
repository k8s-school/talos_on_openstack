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
    }),
    # Place the EPHEMERAL volume (/var, including /var/lib/containerd and
    # /var/lib/kubelet) on the large secondary disk (vdb, the OpenStack
    # ephemeral disk) instead of the small root disk. Large container images
    # (e.g. fink-broker, ~14 GB unpacked) otherwise fill the ~17 GB root /var
    # and drivers get evicted with "no space left on device".
    #
    # Workers only: control planes keep EPHEMERAL on the root disk so etcd is
    # not placed on an ephemeral disk. "!system_disk" matches vdb (the only
    # non-install disk on a worker); "grow" makes EPHEMERAL fill it.
    #
    # NOTE: a VolumeConfig only applies when the volume is first provisioned.
    # New workers get this automatically; existing workers must have their
    # EPHEMERAL volume wiped and reboot (see "Enlarging worker /var" in
    # README.md).
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "VolumeConfig"
      name       = "EPHEMERAL"
      provisioning = {
        diskSelector = {
          match = "!system_disk"
        }
        grow = true
      }
    })
  ]
}