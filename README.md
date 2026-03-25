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