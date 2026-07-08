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

# Bootstrap the cluster using the first control plane node (idempotent).
# We attempt the bootstrap unconditionally and treat an already-bootstrapped
# node as success: a second bootstrap returns "etcd data directory is not empty"
# / "AlreadyExists". Relying on `talosctl health` here was flaky - it can report
# unhealthy on a bootstrapped-but-still-settling cluster, causing a spurious
# re-bootstrap that then aborts the whole script under `set -e`.
echo "Bootstrapping cluster..."
if bootstrap_err=$(talosctl bootstrap 2>&1); then
    echo "Cluster bootstrapped"
else
    if echo "$bootstrap_err" | grep -qiE "already ?exists|not empty"; then
        echo "Cluster is already bootstrapped"
    else
        echo "$bootstrap_err" >&2
        exit 1
    fi
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
    # Right after bootstrap the apiserver serving cert can be briefly not-yet-valid
    # due to clock skew between the bastion and the control plane ("certificate ...
    # is before ..."), which makes a single `talosctl kubeconfig` fail. Retry until
    # it succeeds; --force overwrites any stale context from a previous cluster.
    until talosctl kubeconfig --force; do
        echo "  kubeconfig generation failed (apiserver not ready / clock skew), retrying in 10s..."
        sleep 10
    done
fi

# Workers place their EPHEMERAL volume (/var, incl. /var/lib/containerd) on the
# large secondary disk vdb (see talos.tf) so large container images fit.
# OpenStack ships that disk pre-formatted, so Talos cannot claim it until it is
# wiped once; until then the worker EPHEMERAL volume stays "failed" and the node
# never becomes Ready. Wipe vdb on every worker so Talos provisions EPHEMERAL.
echo "Wiping secondary disk (vdb) on workers for the EPHEMERAL volume..."
for wip in $(tofu output -json worker_ips | jq -r '.[]') $(tofu output -json bigworker_ips | jq -r '.[]'); do
    echo "  waiting for Talos API on worker $wip..."
    until talosctl -n "$wip" version &> /dev/null; do sleep 5; done
    echo "  wiping vdb on $wip"
    talosctl -n "$wip" wipe disk vdb || true
done

# Wait for cluster to be fully ready. First wait for every node to register:
# "kubectl wait nodes --all" errors out immediately with "no matching resources
# found" if it runs before any kubelet has registered.
expected_nodes=$(( $(tofu output -json controlplane_ips | jq 'length') + $(tofu output -json worker_ips | jq 'length') + $(tofu output -json bigworker_ips | jq 'length') ))
echo "Waiting for $expected_nodes nodes to register..."
until [ "$(kubectl get nodes --no-headers 2>/dev/null | wc -l)" -ge "$expected_nodes" ]; do
    echo "  $(kubectl get nodes --no-headers 2>/dev/null | wc -l)/$expected_nodes nodes registered..."
    sleep 10
done
echo "Waiting for all nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=600s

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