#!/bin/bash

# Pre-install steps before executing openedx-install.sh

set -e

echo '---'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh
echo "Pre-install steps for ${APPNAME} in namespace ${NAMESPACE}"

export LB_IP=$(docker network inspect k3d-${CLUSTERNAME} | jq -r ".[].Containers[] | select(.Name == \"k3d-${CLUSTERNAME}-serverlb\") | .IPv4Address | split(\"/\")[0]")
export BACKUPS_LB_IP=$(docker network inspect k3d-${CLUSTERNAME} | jq -r ".[].Containers[] | select(.Name == \"k3d-${BACKUPS_CLUSTERNAME}-serverlb\") | .IPv4Address | split(\"/\")[0]")

echo "Load balancer IP address detected: ${LB_IP}, backups LB IP: ${BACKUPS_LB_IP}"

kubectl config use-context k3d-${BACKUPS_CLUSTERNAME}
helmfile -f ${SCRIPT_DIR}/helmfile-backups.yaml.gotmpl --environment dev sync

kubectl config use-context k3d-${CLUSTERNAME}
helmfile -f ${SCRIPT_DIR}/helmfile.yaml.gotmpl --environment dev sync
