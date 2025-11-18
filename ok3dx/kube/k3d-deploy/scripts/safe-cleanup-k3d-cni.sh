#!/bin/bash

set -e

echo '---'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../../vars.sh

CLUSTER_NAME="${1}"

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

echo "Cleaning CNI state for cluster: $CLUSTER_NAME"
CLUSTER=k3d-$CLUSTER_NAME

# Best effort cleanup via API (timeout prevents hanging if cluster is broken)
echo "Attempting to drain resources via API (best effort)..."
if command -v timeout >/dev/null; then
    timeout 10s kubectl --context $CLUSTER delete pods --all --all-namespaces --force --grace-period=0 2>/dev/null || true
else
    kubectl --context $CLUSTER delete pods --all --all-namespaces --force --grace-period=0 2>/dev/null || true
fi

echo "Stopping cluster..."
k3d cluster stop ${CLUSTER_NAME}

echo "Cleaning internal state..."
# Use a temporary alpine container to modify the volumes of the stopped k3d nodes.
# This avoids 'docker exec' issues on stopped containers and fixes the quoting hell.
for NODE in $(docker ps -a --filter "name=${CLUSTER}" --format "{{.Names}}"); do
    echo "Processing node: $NODE"

    # We use 'alpine' to access the volumes.
    # We escape the inner quotes for the SQL command.
    docker run --rm --network $NETWORK --volumes-from "$NODE" alpine:3.19 sh -c "
        set -e
        # Clean CNI and Certs
        rm -rf /var/lib/cni/networks/cbr0/*
        rm -rf /var/lib/rancher/k3s/server/tls
        rm -rf /var/lib/rancher/k3s/agent/client-*
        rm -rf /var/lib/rancher/k3s/agent/*.kubeconfig
    "

    docker run --rm --network $NETWORK --volumes-from "$NODE" alpine/sqlite:3.49.2 \
      /var/lib/rancher/k3s/server/db/state.db \
      "DELETE FROM kine WHERE name LIKE '/registry/minions/%';" || true
    echo "Processed node: $NODE"
done

echo "Done! Start with: k3d cluster start ${CLUSTER_NAME}"
