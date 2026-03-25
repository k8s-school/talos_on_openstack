#!/bin/bash

set -euo pipefail

# Configuration
TOFU_VERSION="1.8.4"
TALOS_VERSION="v1.12.6"
KUBECTL_VERSION="v1.35.0"

echo "=== Installing Prerequisites for Talos on OpenStack ==="

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Please don't run this script as root"
    exit 1
fi

# Update package list
echo "Updating package list..."
sudo apt update

# Install basic tools
echo "Installing basic tools (jq, unzip, curl, wget)..."
sudo apt install -y jq unzip curl wget python3-openstackclient

# Install OpenTofu
echo "Installing OpenTofu v${TOFU_VERSION}..."
if command -v tofu &> /dev/null; then
    echo "OpenTofu is already installed: $(tofu version)"
else
    TOFU_ZIP="/tmp/tofu_${TOFU_VERSION}_linux_amd64.zip"
    wget -O "$TOFU_ZIP" "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.zip"
    unzip "$TOFU_ZIP" -d /tmp/
    sudo mv /tmp/tofu /usr/local/bin/
    sudo chmod +x /usr/local/bin/tofu
    rm -f "$TOFU_ZIP"
    echo "OpenTofu installed: $(tofu version)"
fi

# Install talosctl
echo "Installing talosctl ${TALOS_VERSION}..."
if command -v talosctl &> /dev/null; then
    echo "talosctl is already installed: $(talosctl version --short --client)"
else
    TALOSCTL_BIN="/tmp/talosctl"
    curl -Lo "$TALOSCTL_BIN" "https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/talosctl-linux-amd64"
    chmod +x "$TALOSCTL_BIN"
    sudo mv "$TALOSCTL_BIN" /usr/local/bin/
    echo "talosctl installed: $(talosctl version --short --client)"
fi

# Install kubectl
echo "Installing kubectl ${KUBECTL_VERSION}..."
if command -v kubectl &> /dev/null; then
    echo "kubectl is already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    KUBECTL_BIN="/tmp/kubectl"
    curl -Lo "$KUBECTL_BIN" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x "$KUBECTL_BIN"
    sudo mv "$KUBECTL_BIN" /usr/local/bin/
    echo "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi

# Create .talos directory if it doesn't exist
if [ ! -d "$HOME/.talos" ]; then
    echo "Creating .talos directory..."
    mkdir -p "$HOME/.talos"
fi

echo ""
echo "=== Installation Complete ==="
echo "Installed versions:"
echo "- OpenTofu: $(tofu version)"
echo "- talosctl: $(talosctl version --short --client)"
echo "- kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo "- jq: $(jq --version)"
echo ""
echo "Next steps:"
echo "1. Source your OpenStack credentials: source ~/.novacreds/fink-openrc.sh"
echo "2. Create the Talos image in OpenStack (see README)"
echo "3. Configure your terraform.tfvars"
echo "4. Run ./deploy.sh"