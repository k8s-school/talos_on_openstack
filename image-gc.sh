#!/bin/bash

# Configure kubelet image garbage collection on all Talos nodes and, optionally,
# trigger an immediate one-shot cleanup of unused container images.
#
# Background
# ----------
# Talos delegates container-image garbage collection to the kubelet. There is no
# "talosctl image rm" command, so this is the supported way to clean images on
# Talos. By default the kubelet only prunes images under disk pressure
# (imageGCHighThresholdPercent, 85%). On a lightly loaded /var partition that
# threshold is never reached, so obsolete images accumulate indefinitely.
#
# A typical offender is the OLM "operatorhubio-catalog" CatalogSource: it
# re-pulls quay.io/operatorhubio/catalog:latest on every registryPoll interval
# and leaves the previous ~120 MB digest behind on the node running the pod.
#
# This script sets "imageMaximumGCAge" in the kubelet configuration of every
# node. With it, the kubelet prunes images that have been unused for longer than
# the given age, regardless of disk pressure. Images backing running containers
# are always protected and never removed.
#
# @author Fabrice Jammes

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Retention for unused images (kubelet imageMaximumGCAge). Images not used for
# longer than this are garbage collected even when the disk is not under pressure.
MAX_AGE="168h"

# One-shot immediate prune settings (see -p): a temporarily short age so the next
# kubelet GC cycle removes stale images now, then MAX_AGE is restored.
PRUNE_NOW="false"
PRUNE_AGE="3m"
PRUNE_WAIT="360" # seconds to wait for the kubelet GC cycle (~5 min period)

usage() {
    cat <<EOD
Usage: $(basename "$0") [options]

Configure kubelet image garbage collection on all Talos nodes.

Available options:
  -h              This message
  -a <duration>   imageMaximumGCAge to set on every node (default: $MAX_AGE)
  -p              Prune now: also trigger an immediate one-shot GC of unused
                  images (temporarily sets the age to $PRUNE_AGE, waits
                  ${PRUNE_WAIT}s for the kubelet GC cycle, then restores -a)
  -w <seconds>    Seconds to wait for the GC cycle in -p mode (default: $PRUNE_WAIT)

Requires a working talosctl configuration (endpoints) and a kubectl context
pointing at the Talos cluster.
EOD
}

while getopts ha:pw: c; do
    case $c in
        h) usage; exit 0 ;;
        a) MAX_AGE="$OPTARG" ;;
        p) PRUNE_NOW="true" ;;
        w) PRUNE_WAIT="$OPTARG" ;;
        \?) usage; exit 2 ;;
    esac
done

# Discover Talos node addresses from the Kubernetes API: the InternalIP of each
# node is its Talos node address.
mapfile -t NODES < <(kubectl get nodes \
    -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')

if [ "${#NODES[@]}" -eq 0 ]; then
    echo "ERROR: no nodes found. Is kubectl configured for the Talos cluster?" >&2
    exit 1
fi

NODE_CSV=$(IFS=,; echo "${NODES[*]}")
echo "Target nodes: $NODE_CSV"

# Apply a given imageMaximumGCAge to every node via a strategic-merge patch.
# Applying kubelet config only restarts the kubelet; it does not reboot the node.
apply_age() {
    local age="$1"
    local patch
    patch=$(mktemp)
    cat > "$patch" <<EOF
machine:
  kubelet:
    extraConfig:
      imageMaximumGCAge: $age
EOF
    echo "Setting imageMaximumGCAge=$age on all nodes..."
    talosctl -n "$NODE_CSV" patch machineconfig -p "@$patch"
    rm -f "$patch"
}

if [ "$PRUNE_NOW" == "true" ]; then
    echo "=== Immediate prune requested ==="
    apply_age "$PRUNE_AGE"
    echo "Waiting ${PRUNE_WAIT}s for the kubelet image GC cycle to remove unused images..."
    sleep "$PRUNE_WAIT"
fi

# Apply (or restore) the permanent retention policy.
apply_age "$MAX_AGE"

echo ""
echo "Done. Current kubelet imageMaximumGCAge per node:"
for ip in "${NODES[@]}"; do
    printf "  %-16s " "$ip"
    talosctl -n "$ip" read /etc/kubernetes/kubelet.yaml 2>/dev/null \
        | grep imageMaximumGCAge || echo "MISSING"
done
