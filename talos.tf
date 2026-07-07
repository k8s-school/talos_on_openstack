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

# Generate dedicated big-worker configuration: same as a worker (PTP,
# EPHEMERAL on the secondary disk) plus a node label and taint so a specific
# workload (e.g. raw2science) can target these nodes and nothing else lands
# on them.
data "talos_machine_configuration" "bigworker" {
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
        # Label + taint so only tolerating/selecting pods schedule here.
        nodeLabels = {
          "fink.io/pool" = "raw2science"
        }
        # TODO(taint): machine.nodeTaints is applied by Talos's NodeApplyController
        # using the kubelet identity, but NodeRestriction forbids a node from
        # modifying its own taints ("node ... is not allowed to modify taints"),
        # so the taint below is NOT applied on a fresh bigworker (the label is).
        # Replace it with a kubelet register-with-taints arg, which is applied at
        # node registration (allowed by NodeRestriction), e.g.:
        #   kubelet = { extraArgs = { "register-with-taints" = "dedicated=raw2science:NoSchedule" } }
        # (the critical daemonsets - flannel, kube-proxy, cinder-csi - tolerate
        # all taints, so a NoSchedule taint is safe at registration).
        # Until then the taint must be applied manually:
        #   kubectl taint node <bigworker> dedicated=raw2science:NoSchedule
        nodeTaints = {
          dedicated = "raw2science:NoSchedule"
        }
      }
    }),
    # EPHEMERAL volume on the large secondary disk vdb (see the worker block).
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