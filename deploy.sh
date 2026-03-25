#!/bin/bash

set -euxo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Deploying Talos cluster with OpenTofu ==="

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

# Save Talos configuration
echo "Saving Talos configuration..."
tofu output -raw talos_config > ~/.talos/config

# Configure talosctl to point to the first control plane node for bootstrap
talosctl config endpoint "$CP_IP"
talosctl config node "$CP_IP"

# Bootstrap the cluster using the first control plane node
echo "Bootstrapping cluster..."
talosctl bootstrap

# Wait for the cluster to be ready
echo "Waiting for cluster to be ready..."
sleep 30

# Switch to VIP endpoint
echo "Switching to VIP endpoint..."
talosctl config endpoint "$VIP_IP"
talosctl config node "$VIP_IP"

# Create kubeconfig for the cluster
echo "Creating kubeconfig..."
talosctl kubeconfig

echo "=== Deployment complete! ==="
echo "Cluster endpoint: $(tofu output -raw cluster_endpoint)"
echo "VIP IP: $VIP_IP"
echo ""
echo "You can now use kubectl to interact with your cluster:"
echo "kubectl get nodes"