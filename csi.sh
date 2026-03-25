#!/bin/bash

set -euxo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# Install Helm if not already present
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    HELM_INSTALLER="/tmp/get_helm.sh"
    curl -fsSL -o "$HELM_INSTALLER" https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 "$HELM_INSTALLER"
    "$HELM_INSTALLER"
    rm -f "$HELM_INSTALLER"
else
    echo "Helm is already installed: $(helm version --short)"
fi

NS="csi-system"

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NS" &> /dev/null; then
    echo "Creating namespace $NS..."
    kubectl create namespace "$NS"
else
    echo "Namespace $NS already exists"
fi

kubectl label namespace "$NS" \
  pod-security.kubernetes.io/enforce=privileged \
  --overwrite

# Create cloud-config secret if it doesn't exist
if ! kubectl get secret cloud-config -n "$NS" &> /dev/null; then
    echo "Creating cloud-config secret..."
    kubectl create secret generic cloud-config --from-file=cloud.conf=$DIR/cloud.conf -n "$NS"
else
    echo "cloud-config secret already exists"
fi


# Add Helm repo if not already present
if ! helm repo list | grep -q "^cpo"; then
    echo "Adding cloud-provider-openstack Helm repo..."
    helm repo add cpo https://kubernetes.github.io/cloud-provider-openstack
else
    echo "Helm repo 'cpo' already exists"
fi

helm repo update

CHART_VERSION="2.35.0"

# Install CSI driver if not already installed
if ! helm list -n "$NS" | grep -q "cinder-csi"; then
    echo "Installing cinder-csi..."
    helm install cinder-csi cpo/openstack-cinder-csi \
        --namespace "$NS" \
        --version "$CHART_VERSION" \
        -f $DIR/values.yaml
else
    echo "cinder-csi is already installed"
    echo "Use 'helm upgrade' if you want to update it"
fi
