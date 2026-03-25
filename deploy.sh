#!/bin/bash

set -euxo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Deploying Talos cluster with OpenTofu ==="

# Check if OpenStack credentials are sourced
if [ -z "$OS_AUTH_URL" ]; then
    echo "ERROR: OpenStack credentials not found!"
    echo "Please source your OpenStack credentials file:"
    echo "  source ~/.novacreds/fink-openrc.sh"
    echo "Or set the required environment variables (OS_AUTH_URL, OS_USERNAME, etc.)"
    exit 1
fi

echo "Using OpenStack credentials:"
echo "  Auth URL: $OS_AUTH_URL"
echo "  Project: $OS_PROJECT_NAME"
echo "  User: $OS_USERNAME"

# Initialize OpenTofu
echo "Initializing OpenTofu..."
tofu init

# Plan the deployment
echo "Planning deployment..."
tofu plan

# Apply the configuration
echo "Applying configuration..."
tofu apply -auto-approve

# Extract the first control plane IP for bootstrapping
CP_IP=$(tofu output -json controlplane_ips | jq -r '.[0]')
VIP_IP=$(tofu output -raw vip_ip)

echo "Control plane IP: $CP_IP"
echo "VIP IP: $VIP_IP"

# Backup existing Talos configuration if it exists
if [ -f ~/.talos/config ]; then
    echo "Backing up existing Talos configuration..."
    cp ~/.talos/config ~/.talos/config_$(date +%Y%m%d%H%M)
fi

# Save new Talos configuration
echo "Saving Talos configuration..."
tofu output -raw talos_config > ~/.talos/config

# Configure talosctl to point to the first control plane node for bootstrap
talosctl config endpoint "$CP_IP"
talosctl config node "$CP_IP"

# Bootstrap the cluster using the first control plane node (idempotent)
echo "Bootstrapping cluster..."
if talosctl health --wait-timeout=10s &> /dev/null; then
    echo "Cluster is already bootstrapped and healthy"
else
    echo "Bootstrapping cluster..."
    talosctl bootstrap
fi

# Wait for the cluster to be ready
echo "Waiting for cluster to be ready..."
sleep 30

# Switch to VIP endpoint
echo "Switching to VIP endpoint..."
talosctl config endpoint "$VIP_IP"
talosctl config node "$VIP_IP"

# Create kubeconfig for the cluster (idempotent)
echo "Creating kubeconfig..."
if kubectl cluster-info &> /dev/null; then
    echo "Kubeconfig already exists and cluster is accessible"
else
    echo "Generating kubeconfig..."
    talosctl kubeconfig
fi

# Wait for cluster to be fully ready
echo "Waiting for all nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install OpenStack CSI driver for storage
echo "Installing OpenStack CSI driver..."
if [ -f "$DIR/csi.sh" ]; then
    echo "Running CSI installation script..."
    bash "$DIR/csi.sh"
    echo "CSI driver installed successfully!"
else
    echo "Warning: CSI script not found at $DIR/csi.sh"
    echo "You may need to install the OpenStack CSI driver manually for persistent volumes"
fi

echo ""
echo "=== Deployment complete! ==="
echo "Cluster endpoint: $(tofu output -raw cluster_endpoint)"
echo "VIP IP: $VIP_IP"
echo ""
echo "Cluster status:"
kubectl get nodes
echo ""
echo "Available storage classes:"
kubectl get storageclass
echo ""
echo "Your Talos cluster is ready to use!"