# Talos on OpenStack with OpenTofu

This project deploys a Talos Kubernetes cluster on OpenStack using OpenTofu with the OpenStack and Talos providers.

## Prerequisites

1. **OpenTofu**: Install OpenTofu (Terraform alternative)
2. **OpenStack CLI**: Configure your OpenStack credentials
3. **Talos CLI**: Install `talosctl`
4. **kubectl**: Install kubectl for cluster management
5. **jq**: For JSON processing in scripts

### Install Prerequisites

Run the prerequisites installation script:

```bash
./prereqs.sh
```

This script will install:
- **OpenTofu v1.8.4** (fixed version for stability)
- **talosctl v1.12.6**
- **kubectl v1.35.0**
- **jq** and **python3-openstackclient**

The script checks if tools are already installed and skips them if found.

## Setup

### 1. OpenStack Environment

Source your OpenStack credentials before running any OpenTofu commands:
```bash
source ~/.novacreds/fink-openrc.sh
```

This sets the required environment variables:
- `OS_AUTH_URL`: OpenStack authentication URL
- `OS_USERNAME`: Your username
- `OS_PASSWORD`: Your password
- `OS_PROJECT_NAME`: Project name
- `OS_USER_DOMAIN_NAME`: User domain
- `OS_PROJECT_DOMAIN_NAME`: Project domain

You can verify the credentials are loaded:
```bash
env | grep OS_
```

### 2. Create Talos Image

Create the Talos image in OpenStack:
```bash
curl -LO https://factory.talos.dev/image/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba/v1.12.5/openstack-amd64.raw.xz
xz -d openstack-amd64.raw.xz
openstack image create --public --disk-format raw --file openstack-amd64.raw talos
```

### 3. Configuration

Copy the example configuration and customize:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values:
- Network name
- Control plane and worker flavors
- Cluster sizing
- Optional: specific VIP IP address

## Deployment

### Initialize and Deploy

```bash
./deploy.sh
```

This script will:
1. Initialize OpenTofu
2. Plan the deployment
3. Apply the configuration
4. Bootstrap the Talos cluster
5. Configure talosctl and kubectl

### Manual Steps

If you prefer manual deployment:

```bash
# Initialize OpenTofu
tofu init

# Plan deployment
tofu plan

# Apply configuration
tofu apply

# Get first control plane IP
CP_IP=$(tofu output -json controlplane_ips | jq -r '.[0]')

# Save Talos config
tofu output -raw talos_config > ~/.talos/config

# Bootstrap cluster
talosctl config endpoint $CP_IP
talosctl config node $CP_IP
talosctl bootstrap

# Switch to VIP
VIP_IP=$(tofu output -raw vip_ip)
talosctl config endpoint $VIP_IP
talosctl config node $VIP_IP

# Get kubeconfig
talosctl kubeconfig
```

## Management

### Check Cluster Status

```bash
kubectl get nodes
talosctl health
```

### Access Cluster

The cluster will be accessible via:
- **Kubernetes API**: https://10.180.15.250:6443
- **Talos API**: 10.180.15.250:50000

### Scaling

To change the number of nodes, update the variables in `terraform.tfvars`:
```hcl
control_plane_count = 3
worker_count = 5
```

Then apply the changes:
```bash
tofu apply
```

## Node image garbage collection

Talos delegates container-image garbage collection to the kubelet, and there is
no `talosctl image rm` command. By default the kubelet only prunes images under
disk pressure (`imageGCHighThresholdPercent`, 85% of `/var`). On a lightly
loaded cluster that threshold is never reached, so obsolete images pile up on
the nodes forever.

A common offender is the OLM `operatorhubio-catalog` CatalogSource: it re-pulls
`quay.io/operatorhubio/catalog:latest` on every `registryPoll` interval and
leaves the previous ~120 MB digest behind on the node running the pod.

The `image-gc.sh` script fixes this by setting the kubelet
`imageMaximumGCAge` on every node. With it, the kubelet prunes images that have
been unused for longer than the configured age, regardless of disk pressure.
Images backing running containers are always protected.

```bash
# Set the retention policy on all nodes (default: 168h / 7 days).
# Applying kubelet config restarts the kubelet only; it does not reboot nodes.
./image-gc.sh

# Use a different retention (e.g. 48 hours).
./image-gc.sh -a 48h

# Also trigger an immediate one-shot cleanup now: the script temporarily lowers
# the age so the next kubelet GC cycle removes stale images, waits for that
# cycle (~5 min), then restores the retention policy.
./image-gc.sh -p

# Run ./image-gc.sh -h for all options.
```

The script discovers the node addresses from the Kubernetes API, so it needs a
working `kubectl` context and `talosctl` endpoints (both configured by
`deploy.sh`).

## Enlarging worker `/var` (EPHEMERAL on the secondary disk)

The OpenStack flavors give each node a small root disk (~17 GB usable for the
Talos EPHEMERAL volume, i.e. `/var`) **and** a large secondary ephemeral disk
(`/dev/vdb`, 40-80 GB) that Talos discovers but does not use. Container images
live under `/var/lib/containerd` on the small root `/var`, so a large image
(e.g. `fink-broker`, ~14 GB unpacked) can fill it and get pods evicted with
`no space left on device` / `low on resource: ephemeral-storage`.

`talos.tf` therefore pins the **worker** EPHEMERAL volume onto `vdb` with a
`VolumeConfig` (control planes are left on the root disk to keep etcd off an
ephemeral disk):

```yaml
apiVersion: v1alpha1
kind: VolumeConfig
name: EPHEMERAL
provisioning:
  diskSelector:
    match: "!system_disk"   # the non-install disk, i.e. vdb
  grow: true                # fill the whole disk
```

A `VolumeConfig` is only honored **when the volume is first provisioned**, so:

- **New clusters / new workers**: the worker machine config already carries the
  `VolumeConfig`. Note that the OpenStack secondary disk ships pre-formatted, so
  Talos cannot claim it until it is wiped once (`talosctl wipe disk vdb`); a
  fresh worker therefore needs that one-time wipe before EPHEMERAL lands on
  `vdb` and the kubelet turns Ready.
- **Existing workers**: the volume is already on the root disk and must be
  re-provisioned. Do it **one worker at a time** and validate on the first one
  before rolling to the rest.

### Migrate an existing worker (recommended: recreate via OpenTofu)

The most deterministic way is to recreate the instance so it boots with the new
config. Worker state (HDFS/Kafka) lives on Cinder PVCs and survives.

```bash
kubectl drain <k8s-node> --ignore-daemonsets --delete-emptydir-data --force
tofu taint 'openstack_compute_instance_v2.worker[<index>]'   # 0-based
tofu apply
# Wait for the node to rejoin, then:
kubectl uncordon <k8s-node>
```

### Alternative: live wipe without reprovisioning

If you prefer not to recreate the VM, push the config and wipe only the
EPHEMERAL volume so Talos rebuilds it on `vdb`:

```bash
NODE=<worker-ip>
K8SNODE=<k8s-node>

# 1. Store the VolumeConfig on the node
talosctl -n "$NODE" patch mc -p '{"apiVersion":"v1alpha1","kind":"VolumeConfig","name":"EPHEMERAL","provisioning":{"diskSelector":{"match":"!system_disk"},"grow":true}}'

# 2. Drain and wipe the current EPHEMERAL, then reboot
kubectl drain "$K8SNODE" --ignore-daemonsets --delete-emptydir-data --force
talosctl -n "$NODE" reset --graceful=false --reboot --system-labels-to-wipe EPHEMERAL

# 3. IMPORTANT: the OpenStack secondary disk (vdb) ships pre-formatted (xfs,
#    label "ephemeral0"), so after reboot EPHEMERAL provisioning FAILS with
#    "1 have wrong format". Wipe vdb so Talos can claim it:
talosctl -n "$NODE" wipe disk vdb
# Talos then provisions EPHEMERAL on vdb automatically; kubelet turns Ready.

kubectl uncordon "$K8SNODE"
```

If EPHEMERAL stays `failed`, check the reason with:

```bash
talosctl -n "$NODE" get volumestatus EPHEMERAL -o yaml | grep -E 'phase|errorMessage'
```

### Verify

After the worker is back, confirm EPHEMERAL now lives on `vdb` and `/var` is
large:

```bash
talosctl -n "$NODE" get discoveredvolumes | grep EPHEMERAL
talosctl -n "$NODE" mounts | awk '$NF=="/var"'   # SIZE column should be ~vdb size
```

## Cleanup

To destroy the cluster:
```bash
./destroy.sh
```

Or manually:
```bash
tofu destroy
```

## Architecture

The deployment creates:

### OpenStack Resources
- Security group with appropriate rules
- SSH key pair
- Virtual IP port
- Control plane instances (3 by default)
- Worker instances (2 by default)
- Network ports with VIP allowed-address-pairs

### Talos Configuration
- Machine secrets for cluster security
- Control plane configuration with VIP and PTP
- Worker configuration with PTP
- Client configuration for talosctl

### High Availability
- 3 control plane nodes with shared VIP (10.180.15.250)
- VRRP protocol for VIP failover
- PTP time synchronization

## Troubleshooting

### Check OpenStack Resources
```bash
openstack server list
openstack port list
openstack security group list
```

### Check Talos Health
```bash
talosctl health
talosctl logs
```

### Check Kubernetes
```bash
kubectl get nodes
kubectl get pods -A
```

## Customization

The deployment can be customized by modifying:
- `variables.tf`: Default values
- `terraform.tfvars`: Your specific configuration
- `talos.tf`: Talos machine configurations
- Individual `.tf` files for specific resources