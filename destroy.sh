#!/bin/bash

set -euxo pipefail

echo "=== Destroying Talos cluster ==="

# Destroy the infrastructure
echo "Destroying infrastructure with OpenTofu..."
tofu destroy -auto-approve

echo "=== Cluster destroyed! ==="