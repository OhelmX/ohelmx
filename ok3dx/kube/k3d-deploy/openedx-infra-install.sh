#!/bin/bash

set -e

echo '---'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh
echo "Installing helm charts for ${APPNAME}-infra in namespace ${NAMESPACE}"

export LB_IP=$(docker network inspect ${NETWORK} | jq -r ".[].Containers[] | select(.Name == \"k3d-${CLUSTERNAME}-serverlb\") | .IPv4Address | split(\"/\")[0]")
export GATEWAY_IP=$(docker network inspect ${NETWORK} | jq -r ".[].IPAM.Config[0].Gateway")
export BACKUPS_LB_IP=$(docker network inspect ${NETWORK} | jq -r ".[].Containers[] | select(.Name == \"k3d-${BACKUPS_CLUSTERNAME}-serverlb\") | .IPv4Address | split(\"/\")[0]")
export MINIO_HOST=files.${LOCALHOST_NAME}
export BACKUPS_HOST=backups.${LOCALHOST_NAME}

echo "Load balancer IP address detected: ${LB_IP}, backups LB IP: ${BACKUPS_LB_IP}"

helmfile --kubeconfig ${KUBECONFIG} --kube-context ${MAIN_CONTEXT} --environment dev \
  -f ${SCRIPT_DIR}/../helmfile/helmfile-cluster-infra.yaml.gotmpl sync --include-transitive-needs

echo '---'
echo "Helm charts installed for ${APPNAME}-infra in namespace ${NAMESPACE}"
